/**
 * Tests del callable `scanReceipt`, el lector de boletas.
 *
 * ---------------------------------------------------------------------------
 * POR QUÉ ESTE ARCHIVO NACE CON LA FUNCIÓN
 * ---------------------------------------------------------------------------
 * `chat` se escribió sin un solo test y estuvo MUERTA con la suite entera en
 * verde: una consulta que Firestore no admite mataba todas las llamadas, y
 * encima cada intento le gastaba al usuario del plan free uno de sus mensajes
 * de por vida. El por qué está en `test/chat.test.ts`. No se repite aquí: el
 * camino feliz, la cuota, el rollback y la salida basura del modelo se prueban
 * desde el primer commit.
 *
 * ---------------------------------------------------------------------------
 * CÓMO SE PRUEBA SIN RED Y SIN CLAVE
 * ---------------------------------------------------------------------------
 * Se ejercita `handleScanReceipt`, el cuerpo del callable con las dependencias
 * inyectadas. Firestore es el EMULADOR DE VERDAD (la cuota es una transacción,
 * y un doble de Firestore se traga los errores de transacción sin pestañear) y
 * la llamada al modelo es un doble: no se sale a la red, no se gastan tokens y
 * no hace falta `OPENROUTER_API_KEY`.
 *
 * El reloj se fija (`NOW`) porque el día de la cuota se deriva de él.
 */

import { describe, expect, it, beforeEach } from 'vitest';
import type { HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { OpenRouterError } from '../src/openrouter';
import {
  DEFAULT_UNIT,
  MAX_SCAN_ITEMS,
  MAX_SCAN_TEXT_CHARS,
  SCAN_LIMITS,
  SCAN_MAX_TOKENS,
  SCAN_RESPONSE_FORMAT,
  SCAN_TEMPERATURE,
  handleScanReceipt,
  parseModelOutput,
  parseScanInput,
  type ScanCall,
  type ScanDeps,
  type ScanReceiptItem,
} from '../src/scan';
import {
  AI_CONFIG_DOC,
  AI_USAGE_DAYS,
  AI_USAGE_DOC,
  FREE_LIFETIME_SCAN_QUOTA,
  PRO_DAILY_SCAN_QUOTA,
  freeScanQuotaExhaustedMessage,
} from '../src/quota';
import { adminDb, wipeAiSystem, wipeUser } from './helpers/admin';

const UID = 'lector-uid';

/** 09:00 del 15 de septiembre de 2026 en `America/Santiago`. */
const NOW = new Date('2026-09-15T12:00:00Z');
const DIA = '2026-09-15';

/** Texto de una boleta chilena, tal como lo devuelve un OCR de papel térmico. */
const BOLETA = [
  'FERRETERIA EL GRES LTDA',
  'R.U.T. 76.543.210-K',
  'BOLETA ELECTRONICA N 445566',
  '2 SACOS ARCILLA GRES 25K 18.990',
  '1 ESMALTE TRANSPARENTE 12.500',
  'TOTAL 50.480',
  'GRACIAS POR SU COMPRA',
].join('\n');

const ITEMS_OK = [
  { name: 'Arcilla gres 25 kg', quantity: 2, unit: 'sacos', unitPrice: 18990, code: 'ARC-25' },
  { name: 'Esmalte transparente', quantity: 1, unit: 'unidades', unitPrice: 12500, code: null },
];

function salidaOk(extra: Record<string, unknown> = {}): string {
  return JSON.stringify({
    items: ITEMS_OK,
    supplier: 'Ferreteria El Gres Ltda',
    documentNumber: '445566',
    total: 50480,
    ...extra,
  });
}

/** Llamadas que recibió el doble del modelo, para poder mirar lo que se pidió. */
interface Llamada {
  apiKey: string;
  model: string;
  messages: Array<{ role: string; content: string }>;
  temperature?: number;
  maxTokens?: number;
  responseFormat?: unknown;
}

interface Modelo {
  llamadas: Llamada[];
  ask: ScanDeps['ask'];
}

/** Doble que responde con el texto dado y guarda lo que se le pasó. */
function modeloQueResponde(texto: string = salidaOk()): Modelo {
  const llamadas: Llamada[] = [];
  return {
    llamadas,
    ask: async (opts) => {
      llamadas.push({ ...opts });
      return { text: texto, usage: { promptTokens: 900, completionTokens: 300, totalTokens: 1200 } };
    },
  };
}

/** Doble que falla, como OpenRouter caído o con la clave mal. */
function modeloQueFalla(error: Error = new OpenRouterError('HTTP 503: upstream caído', 503)): Modelo {
  const llamadas: Llamada[] = [];
  return {
    llamadas,
    ask: async (opts) => {
      llamadas.push({ ...opts });
      throw error;
    },
  };
}

function deps(modelo: Modelo, extra: Partial<ScanDeps> = {}): ScanDeps {
  return {
    db: adminDb(),
    ask: modelo.ask,
    apiKey: 'clave-de-prueba',
    model: 'modelo-de-prueba',
    enforceAppCheck: false,
    now: NOW,
    ...extra,
  };
}

/**
 * Arma una llamada. `app` se pasa como `null` para decir "sin token de App
 * Check", y NO como `undefined`: un `undefined` activaría el valor por defecto
 * del parámetro y el test pasaría creyendo haber probado lo contrario.
 */
function llamada(data: unknown, uid: string | null = UID, app: unknown = {}): ScanCall {
  return { auth: uid === null ? null : { uid, token: { email_verified: true } }, app, data };
}

async function falla(code: string, promesa: Promise<unknown>): Promise<HttpsError> {
  try {
    await promesa;
  } catch (err) {
    const httpsError = err as HttpsError;
    expect(httpsError.code, `código inesperado: ${httpsError.message}`).toBe(code);
    return httpsError;
  }
  throw new Error(`se esperaba un HttpsError '${code}', pero no lanzó nada`);
}

async function seedPerfil(plan: 'free' | 'pro' = 'free'): Promise<void> {
  await adminDb()
    .doc(`users/${UID}`)
    .set({ name: 'Franco', businessName: 'Greda Austral', currency: 'CLP', plan });
}

async function usage(): Promise<Record<string, unknown> | undefined> {
  return (await adminDb().doc(`users/${UID}/meta/usage`).get()).data();
}

async function contadorGlobal(campo: 'calls' | 'scanCalls', dayKey = DIA): Promise<number> {
  const snap = await adminDb().doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(dayKey).get();
  const value = snap.data()?.[campo];
  return typeof value === 'number' ? value : 0;
}

describe('parseScanInput', () => {
  it('acepta el texto en el tope y rechaza el de un carácter más', () => {
    const tope = 'x'.repeat(MAX_SCAN_TEXT_CHARS);
    expect(parseScanInput({ text: tope }).text).toHaveLength(MAX_SCAN_TEXT_CHARS);
    expect(() => parseScanInput({ text: `${tope}y` })).toThrow(/vacío o es demasiado largo/);
  });

  it('rechaza el vacío, el de solo espacios y lo que no es texto', () => {
    for (const malo of [{ text: '' }, { text: '   \n\t ' }, { text: 42 }, { text: null }, {}, null, 'hola']) {
      expect(() => parseScanInput(malo), `debía rechazar ${JSON.stringify(malo)}`).toThrow();
    }
  });

  it('recorta los espacios del texto', () => {
    expect(parseScanInput({ text: '  1 PAN 990  ' }).text).toBe('1 PAN 990');
  });

  it('acepta los dos orígenes y descarta en silencio cualquier otro', () => {
    // `source` solo matiza el prompt y el registro: una pista mal escrita no
    // puede costar la lectura entera.
    expect(parseScanInput({ text: 'x', source: 'photo' }).source).toBe('photo');
    expect(parseScanInput({ text: 'x', source: 'pdf' }).source).toBe('pdf');
    expect(parseScanInput({ text: 'x', source: 'camara' }).source).toBeUndefined();
    expect(parseScanInput({ text: 'x', source: 7 }).source).toBeUndefined();
    expect(parseScanInput({ text: 'x' }).source).toBeUndefined();
  });
});

describe('parseModelOutput: el backend NO se cree lo que devuelve el modelo', () => {
  function items(json: unknown): ScanReceiptItem[] {
    return parseModelOutput(JSON.stringify(json)).response.items;
  }

  const base = { name: 'Arcilla', quantity: 1, unit: 'sacos', unitPrice: 1000, code: null };

  it('acepta una respuesta buena entera', () => {
    const { response } = parseModelOutput(salidaOk());
    expect(response).toEqual({
      items: ITEMS_OK,
      supplier: 'Ferreteria El Gres Ltda',
      documentNumber: '445566',
      total: 50480,
      truncated: false,
    });
  });

  it('descarta el artículo sin nombre, no la respuesta entera', () => {
    const res = parseModelOutput(
      JSON.stringify({ items: [{ ...base, name: '  ' }, base], supplier: null, documentNumber: null, total: null }),
    );
    expect(res.response.items).toHaveLength(1);
    expect(res.rejected).toEqual(['nombre-vacio']);
  });

  it('descarta las cantidades fuera de rango y las no finitas', () => {
    for (const quantity of [0, -3, SCAN_LIMITS.maxQuantity + 1, 'dos', null, undefined]) {
      expect(items({ items: [{ ...base, quantity }] }), `cantidad ${String(quantity)}`).toEqual([]);
    }
    // El límite inferior y el superior exactos SÍ entran.
    expect(items({ items: [{ ...base, quantity: SCAN_LIMITS.minQuantity }] })).toHaveLength(1);
    expect(items({ items: [{ ...base, quantity: SCAN_LIMITS.maxQuantity }] })).toHaveLength(1);
  });

  it('conserva una cantidad fraccionaria sin redondearla', () => {
    // `2,5 kg` es legítimo en una boleta. El inventario guarda enteros, pero el
    // redondeo lo hace el cliente DELANTE del usuario: redondear aquí le
    // cambiaría el número en silencio.
    expect(items({ items: [{ ...base, quantity: 2.5 }] })[0].quantity).toBe(2.5);
  });

  it('descarta los precios fuera de rango, el 0 y los no finitos', () => {
    for (const unitPrice of [0, -100, SCAN_LIMITS.maxUnitPrice + 1, Infinity, NaN, '18.990', null]) {
      expect(items({ items: [{ ...base, unitPrice }] }), `precio ${String(unitPrice)}`).toEqual([]);
    }
    expect(items({ items: [{ ...base, unitPrice: SCAN_LIMITS.minUnitPrice }] })).toHaveLength(1);
    expect(items({ items: [{ ...base, unitPrice: SCAN_LIMITS.maxUnitPrice }] })).toHaveLength(1);
  });

  it('una unidad vacía o rara NO descarta el artículo: cae en la de por defecto', () => {
    expect(items({ items: [{ ...base, unit: '' }] })[0].unit).toBe(DEFAULT_UNIT);
    expect(items({ items: [{ ...base, unit: null }] })[0].unit).toBe(DEFAULT_UNIT);
    expect(items({ items: [{ ...base, unit: 'SACOS' }] })[0].unit).toBe('sacos');
  });

  it('recorta los campos de texto a su tope y aplana lo que traiga marcado', () => {
    const res = items({
      items: [{ ...base, name: `## ${'a'.repeat(300)}`, code: 'c'.repeat(100) }],
    });
    expect(res[0].name.length).toBeLessThanOrEqual(SCAN_LIMITS.nameChars);
    expect(res[0].name).not.toContain('#');
    expect(res[0].code).toHaveLength(SCAN_LIMITS.codeChars);
  });

  it('descarta las entradas de la lista que no son objetos', () => {
    const res = parseModelOutput(
      JSON.stringify({ items: ['texto', 42, null, base], supplier: null, documentNumber: null, total: null }),
    );
    expect(res.response.items).toHaveLength(1);
    expect(res.rejected).toEqual(['no-es-objeto', 'no-es-objeto', 'no-es-objeto']);
  });

  it(`recorta en ${MAX_SCAN_ITEMS} artículos y lo declara con truncated`, () => {
    const muchos = Array.from({ length: MAX_SCAN_ITEMS + 5 }, (_, i) => ({ ...base, name: `Item ${i}` }));
    const { response } = parseModelOutput(
      JSON.stringify({ items: muchos, supplier: null, documentNumber: null, total: null }),
    );
    expect(response.items).toHaveLength(MAX_SCAN_ITEMS);
    expect(response.truncated).toBe(true);
  });

  it('normaliza supplier, documentNumber y total, y el total fuera de rango a null', () => {
    const { response } = parseModelOutput(
      JSON.stringify({ items: [], supplier: '   ', documentNumber: 999, total: -5 }),
    );
    expect(response.supplier).toBeNull();
    expect(response.documentNumber).toBeNull();
    expect(response.total).toBeNull();
  });

  it('acepta el JSON envuelto en una valla de código markdown', () => {
    // Algunos proveedores la ponen aunque se les pida `json_schema`. Quitarla
    // no adivina nada: el contenido es el mismo que mandaron.
    const { response } = parseModelOutput(`\`\`\`json\n${salidaOk()}\n\`\`\``);
    expect(response.items).toHaveLength(2);
  });

  it('una salida IRRECUPERABLE lanza, y no se inventa una lista vacía', () => {
    for (const basura of [
      'Hola, aquí va tu boleta ordenada:',
      '{ roto',
      '[]',
      '"solo un texto"',
      'null',
      JSON.stringify({ articulos: [] }),
      JSON.stringify({ items: 'dos sacos' }),
    ]) {
      expect(() => parseModelOutput(basura), `debía lanzar con ${basura}`).toThrow();
    }
  });
});

describe('handleScanReceipt (callable scanReceipt)', () => {
  beforeEach(async () => {
    const db = adminDb();
    await wipeUser(db, UID);
    await wipeAiSystem(db);
  });

  // ─────────────────────────────────────────────────────────────────────────
  describe('camino feliz', () => {
    it('devuelve los artículos y cobra UNA lectura de la cuota del lector', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      const res = await handleScanReceipt(llamada({ text: BOLETA, source: 'photo' }), deps(modelo));

      expect(res.items).toEqual(ITEMS_OK);
      expect(res.supplier).toBe('Ferreteria El Gres Ltda');
      expect(res.documentNumber).toBe('445566');
      expect(res.total).toBe(50480);
      expect(res.truncated).toBe(false);

      expect(await usage()).toMatchObject({ dayKey: DIA, scanCountDay: 1, scanCountLifetime: 1 });
      expect(await contadorGlobal('scanCalls')).toBe(1);
    });

    it('le pide al modelo salida estructurada, temperatura 0 y el tope de tokens', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      await handleScanReceipt(llamada({ text: BOLETA }), deps(modelo));

      expect(modelo.llamadas).toHaveLength(1);
      const l = modelo.llamadas[0];
      expect(l.apiKey).toBe('clave-de-prueba');
      expect(l.model).toBe('modelo-de-prueba');
      expect(l.temperature).toBe(SCAN_TEMPERATURE);
      expect(l.maxTokens).toBe(SCAN_MAX_TOKENS);
      // Sin esto el modelo devuelve un párrafo y la función no sirve de nada.
      expect(l.responseFormat).toBe(SCAN_RESPONSE_FORMAT);
    });

    it('le manda al modelo el TEXTO y nada más: la imagen no sale del teléfono', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      // El cliente no tiene por dónde mandar una imagen, pero si alguien
      // añadiera un campo así, no puede acabar en la llamada al modelo.
      await handleScanReceipt(
        llamada({ text: BOLETA, source: 'photo', imageBase64: 'iVBORw0KGgo=' }),
        deps(modelo),
      );

      const bruto = JSON.stringify(modelo.llamadas[0]);
      expect(bruto).not.toContain('iVBORw0KGgo=');
      expect(bruto).not.toContain('imageBase64');
      // Y el texto de la boleta sí viajó.
      expect(modelo.llamadas[0].messages.at(-1)?.content).toContain('ARCILLA GRES');
    });

    it('la cuota del lector NO toca la del asistente', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      await handleScanReceipt(llamada({ text: BOLETA }), deps(modelo));
      await handleScanReceipt(llamada({ text: BOLETA }), deps(modelo));

      const u = await usage();
      expect(u).toMatchObject({ scanCountLifetime: 2, scanCountDay: 2 });
      // Ni un mensaje del asistente consumido, ni el contador global del chat.
      expect(u?.chatCountLifetime).toBeUndefined();
      expect(u?.chatCountDay).toBeUndefined();
      expect(await contadorGlobal('calls')).toBe(0);
    });

    it('una lista vacía es una respuesta, no un error', async () => {
      await seedPerfil();
      // La foto no era una boleta de compra.
      const modelo = modeloQueResponde(
        JSON.stringify({ items: [], supplier: null, documentNumber: null, total: null }),
      );

      const res = await handleScanReceipt(llamada({ text: 'ESTACIONAMIENTO 2 HORAS' }), deps(modelo));

      expect(res.items).toEqual([]);
      // Y SÍ consume la lectura: el texto lo controla entero quien llama, así
      // que devolver la cuota ante una respuesta vacía sería una vía para
      // hacer llamadas al modelo sin límite a costa del dueño.
      expect(await usage()).toMatchObject({ scanCountLifetime: 1 });
    });

    it('una salida con TODO basura dentro de la lista acaba en items vacío, sin reventar', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde(
        JSON.stringify({
          items: [
            { name: '', quantity: 1, unit: 'u', unitPrice: 1000, code: null },
            { name: 'Sin precio', quantity: 1, unit: 'u', unitPrice: -1, code: null },
            'esto no es un artículo',
            null,
          ],
          supplier: null,
          documentNumber: null,
          total: null,
        }),
      );

      const res = await handleScanReceipt(llamada({ text: BOLETA }), deps(modelo));
      expect(res.items).toEqual([]);
      expect(res.truncated).toBe(false);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  describe('autenticación', () => {
    it('sin sesión se rechaza y no se escribe ni se gasta nada', async () => {
      const modelo = modeloQueResponde();

      const err = await falla('unauthenticated', handleScanReceipt(llamada({ text: BOLETA }, null), deps(modelo)));
      expect(err.message).toBe('Inicia sesión para leer boletas.');

      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
      expect(await contadorGlobal('scanCalls')).toBe(0);
    });

    it('con App Check exigido, una llamada sin token se rechaza sin gastar cuota', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      await falla(
        'unauthenticated',
        handleScanReceipt(llamada({ text: BOLETA }, UID, null), deps(modelo, { enforceAppCheck: true })),
      );

      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
    });

    it('con el correo sin verificar se rechaza sin gastar cuota', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      await falla(
        'failed-precondition',
        handleScanReceipt(
          { auth: { uid: UID, token: { email_verified: false } }, app: {}, data: { text: BOLETA } },
          deps(modelo),
        ),
      );

      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
      expect(await contadorGlobal('scanCalls')).toBe(0);
    });

    it('con App Check apagado (el valor de hoy), una llamada sin token pasa', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      const res = await handleScanReceipt(
        llamada({ text: BOLETA }, UID, null),
        deps(modelo, { enforceAppCheck: false }),
      );
      expect(res.items).toHaveLength(2);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  describe('validación de la entrada', () => {
    it('un texto vacío se rechaza ANTES de la cuota y sin llamar al modelo', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      const err = await falla('invalid-argument', handleScanReceipt(llamada({ text: '   ' }), deps(modelo)));
      expect(err.message).toBe('El texto de la boleta está vacío o es demasiado largo.');

      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
      expect(await contadorGlobal('scanCalls')).toBe(0);
    });

    it('un texto enorme se rechaza sin gastar una lectura', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      await falla(
        'invalid-argument',
        handleScanReceipt(llamada({ text: 'x'.repeat(MAX_SCAN_TEXT_CHARS + 1) }), deps(modelo)),
      );

      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
    });

    it(`acepta el texto de ${MAX_SCAN_TEXT_CHARS} caracteres justos`, async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      const res = await handleScanReceipt(
        llamada({ text: 'ARCILLA 1.000\n'.repeat(Math.floor(MAX_SCAN_TEXT_CHARS / 14)) }),
        deps(modelo),
      );
      expect(res.items).toHaveLength(2);
    });

    it('un cuerpo que no es un objeto se rechaza', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();
      await falla('invalid-argument', handleScanReceipt(llamada('1 PAN 990'), deps(modelo)));
      await falla('invalid-argument', handleScanReceipt(llamada(null), deps(modelo)));
      expect(modelo.llamadas).toHaveLength(0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  describe('cuota', () => {
    it('agotada la cuota DE POR VIDA del plan free, no se llama al modelo', async () => {
      await seedPerfil('free');
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        .set({ dayKey: DIA, scanCountLifetime: FREE_LIFETIME_SCAN_QUOTA });
      const modelo = modeloQueResponde();

      const err = await falla('resource-exhausted', handleScanReceipt(llamada({ text: BOLETA }), deps(modelo)));
      // El mensaje del servidor es la única fuente del texto que ve el usuario.
      expect(err.message).toBe(freeScanQuotaExhaustedMessage(FREE_LIFETIME_SCAN_QUOTA));

      expect(modelo.llamadas).toHaveLength(0);
      expect(await contadorGlobal('scanCalls')).toBe(0);
    });

    it('agotar las lecturas deja INTACTOS los mensajes del asistente', async () => {
      // El test que impide que la separación de cuotas se rompa en silencio.
      await seedPerfil('free');
      await adminDb().doc(AI_CONFIG_DOC).set({ freeLifetimeScanQuota: 2 });
      const modelo = modeloQueResponde();

      await handleScanReceipt(llamada({ text: BOLETA }), deps(modelo));
      await handleScanReceipt(llamada({ text: BOLETA }), deps(modelo));
      await falla('resource-exhausted', handleScanReceipt(llamada({ text: BOLETA }), deps(modelo)));

      const u = await usage();
      expect(u).toMatchObject({ scanCountLifetime: 2 });
      expect(u?.chatCountLifetime ?? 0).toBe(0);
      expect(await contadorGlobal('calls')).toBe(0);
    });

    it('el plan pro tiene cuota diaria de lecturas, no de por vida', async () => {
      await seedPerfil('pro');
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        .set({ dayKey: '2000-01-01', scanCountDay: 999, scanCountLifetime: 99_999 });
      const modelo = modeloQueResponde();

      // Con 99.999 lecturas históricas, un pro sigue pudiendo leer.
      const res = await handleScanReceipt(llamada({ text: BOLETA }), deps(modelo));
      expect(res.items).toHaveLength(2);
      expect(await usage()).toMatchObject({ dayKey: DIA, scanCountDay: 1 });

      // Al llegar al tope del día, se corta.
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        .set({ dayKey: DIA, scanCountDay: PRO_DAILY_SCAN_QUOTA }, { merge: true });
      const err = await falla('resource-exhausted', handleScanReceipt(llamada({ text: BOLETA }), deps(modelo)));
      expect(err.message).toMatch(/lecturas de boleta del día/i);
    });

    it('el freno de mano global cuenta los DOS gastos y corta el lector', async () => {
      await seedPerfil();
      await adminDb().doc(AI_CONFIG_DOC).set({ globalDailyCapEnabled: true, globalDailyCap: 3 });
      // Dos mensajes del asistente y una lectura ya hacen 3.
      await adminDb().doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(DIA).set({ calls: 2, scanCalls: 1 });
      const modelo = modeloQueResponde();

      const err = await falla('resource-exhausted', handleScanReceipt(llamada({ text: BOLETA }), deps(modelo)));
      // Y el texto nombra el lector, que es lo que el usuario acaba de usar.
      expect(err.message).toMatch(/lector de boletas/i);
      expect(modelo.llamadas).toHaveLength(0);
    });

    it('respeta una cuota de lecturas reconfigurada por el dueño sin desplegar', async () => {
      await seedPerfil();
      await adminDb().doc(AI_CONFIG_DOC).set({ freeLifetimeScanQuota: 1 });
      const modelo = modeloQueResponde();

      await handleScanReceipt(llamada({ text: BOLETA }), deps(modelo));
      const err = await falla('resource-exhausted', handleScanReceipt(llamada({ text: BOLETA }), deps(modelo)));
      // El texto se arma con el valor reconfigurado, no con el default.
      expect(err.message).toBe(freeScanQuotaExhaustedMessage(1));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  describe('fallos del proveedor: la lectura se devuelve', () => {
    it('OpenRouter caído NO le gasta una lectura al usuario', async () => {
      await seedPerfil();
      const modelo = modeloQueFalla();

      const err = await falla('unavailable', handleScanReceipt(llamada({ text: BOLETA }), deps(modelo)));
      expect(err.message).toBe('El lector no responde. Intenta de nuevo.');

      expect(modelo.llamadas).toHaveLength(1);
      expect(await usage()).toMatchObject({ scanCountDay: 0, scanCountLifetime: 0 });
      expect(await contadorGlobal('scanCalls')).toBe(0);
    });

    it('el plazo agotado se distingue, y tampoco gasta', async () => {
      await seedPerfil();
      const modelo = modeloQueFalla(new OpenRouterError('Tiempo de espera agotado (40000 ms)'));

      await falla('deadline-exceeded', handleScanReceipt(llamada({ text: BOLETA }), deps(modelo)));
      expect(await usage()).toMatchObject({ scanCountLifetime: 0 });
    });

    it('con una sola lectura restante, un fallo no deja al usuario sin poder reintentar', async () => {
      await seedPerfil();
      await adminDb().doc(AI_CONFIG_DOC).set({ freeLifetimeScanQuota: 1 });

      await falla('unavailable', handleScanReceipt(llamada({ text: BOLETA }), deps(modeloQueFalla())));

      // Y ahora, con el proveedor de vuelta, la lectura sigue disponible.
      const res = await handleScanReceipt(llamada({ text: BOLETA }), deps(modeloQueResponde()));
      expect(res.items).toHaveLength(2);
    });

    it('una salida irrecuperable del modelo devuelve la lectura y responde internal', async () => {
      await seedPerfil();
      // El modelo ignoró el esquema y contestó en prosa.
      const modelo = modeloQueResponde('Claro, aquí tienes los artículos de la boleta: dos sacos de arcilla.');

      const err = await falla('internal', handleScanReceipt(llamada({ text: BOLETA }), deps(modelo)));
      expect(err.message).toBe('No pude ordenar la boleta.');

      expect(await usage()).toMatchObject({ scanCountDay: 0, scanCountLifetime: 0 });
      expect(await contadorGlobal('scanCalls')).toBe(0);
    });

    it('un fallo del lector no toca los contadores del asistente', async () => {
      await seedPerfil();
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        .set({ dayKey: DIA, chatCountDay: 4, chatCountLifetime: 9, updatedAt: FieldValue.serverTimestamp() });

      await falla('unavailable', handleScanReceipt(llamada({ text: BOLETA }), deps(modeloQueFalla())));

      expect(await usage()).toMatchObject({ chatCountDay: 4, chatCountLifetime: 9 });
    });
  });
});
