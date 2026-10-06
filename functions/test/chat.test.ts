/**
 * Tests del callable `chat`, el asistente: la función insignia de la app.
 *
 * ---------------------------------------------------------------------------
 * POR QUÉ ESTE ARCHIVO NO EXISTÍA Y POR QUÉ ESO FUE CARO
 * ---------------------------------------------------------------------------
 * `chat` era la única función del backend sin un solo test. Mientras tanto la
 * suite entera estaba en verde y la función estaba MUERTA: la consulta que arma
 * el contexto del prompt pedía `months` ordenado por id de documento de forma
 * DESCENDENTE, y Firestore responde a eso con
 * `9 FAILED_PRECONDITION: Firestore does not support descending key scans`.
 * Como la consulta vivía dentro del `Promise.all` del contexto, moría TODA
 * llamada al asistente: en pantalla, "Ocurrió un error con el asistente" en
 * cada mensaje. Y encima cada intento le gastaba al usuario del plan free uno
 * de sus 25 mensajes de por vida, porque el error se lanzaba después de
 * reservar la cuota y antes del único `try` que la devolvía.
 *
 * Ningún test habría tenido que inventar nada raro para verlo: basta con llamar
 * a la función. Eso es lo que hace este archivo.
 *
 * ---------------------------------------------------------------------------
 * CÓMO SE PRUEBA SIN RED Y SIN CLAVE
 * ---------------------------------------------------------------------------
 * Se ejercita `handleChat`, que es el cuerpo del callable con las dependencias
 * inyectadas (Firestore, la llamada al modelo, la clave, el modelo y el reloj).
 * Firestore es el EMULADOR DE VERDAD, que es el único que reproduce el fallo de
 * arriba; un doble de Firestore lo habría tragado sin pestañear. La llamada al
 * modelo es un doble: no se sale a la red, no se gastan tokens y no hace falta
 * `OPENROUTER_API_KEY`.
 *
 * El reloj se fija (`NOW`) porque el mes en curso y el día de la cuota se
 * derivan de él: sin fijarlo, los tests del contexto mensual cambiarían de
 * resultado el día 1 de cada mes.
 */

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import type { HttpsError } from 'firebase-functions/v2/https';
import {
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { addDoc, collection as clientCollection, serverTimestamp } from 'firebase/firestore';
import { FieldValue, Timestamp, type DocumentReference, type Firestore } from 'firebase-admin/firestore';
import {
  MAX_MESSAGE_CHARS,
  currentMonthKey,
  handleChat,
  latestMonthDoc,
  type ChatCall,
  type ChatDeps,
} from '../src/chat';
import { FREE_LIFETIME_QUOTA, PRO_DAILY_QUOTA, freeQuotaExhaustedMessage } from '../src/quota';
import { TEST_PROJECT_ID, adminDb, wipeAiSystem, wipeUser } from './helpers/admin';

const UID = 'asistente-uid';
const OTHER = 'ajeno-uid';

/**
 * Reloj fijo de los tests. En `America/Santiago` (la zona de la cuota) son las
 * 09:00 del 15 de septiembre de 2026, así que el mes en curso es `2026-09` y el
 * día de la cuota `2026-09-15`, lejos de cualquier límite de mes o de día.
 */
const NOW = new Date('2026-09-15T12:00:00Z');
const MES = '2026-09';
const DIA = '2026-09-15';

const RESPUESTA = 'Este mes vendiste más de lo que gastaste.';

/** Llamadas que recibió el doble del modelo, para poder mirar el prompt. */
interface Llamada {
  apiKey: string;
  model: string;
  messages: Array<{ role: string; content: string }>;
}

interface Modelo {
  llamadas: Llamada[];
  ask: ChatDeps['ask'];
}

/** Doble del modelo que responde bien y guarda lo que se le pasó. */
function modeloQueResponde(texto = RESPUESTA): Modelo {
  const llamadas: Llamada[] = [];
  return {
    llamadas,
    ask: async (opts) => {
      llamadas.push({ apiKey: opts.apiKey, model: opts.model, messages: opts.messages });
      return { text: texto, usage: { promptTokens: 100, completionTokens: 20, totalTokens: 120 } };
    },
  };
}

/** Doble del modelo que falla, como OpenRouter caído o con la clave mal. */
function modeloQueFalla(mensaje = 'HTTP 503: upstream caído'): Modelo {
  const llamadas: Llamada[] = [];
  return {
    llamadas,
    ask: async (opts) => {
      llamadas.push({ apiKey: opts.apiKey, model: opts.model, messages: opts.messages });
      throw new Error(mensaje);
    },
  };
}

function deps(modelo: Modelo, extra: Partial<ChatDeps> = {}): ChatDeps {
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
 * del parámetro y el test pasaría creyendo haber probado lo contrario (ocurrió:
 * el test de App Check daba por bueno un rechazo que nunca llegó a pedirse).
 */
function llamada(data: unknown, uid: string | null = UID, app: unknown = {}): ChatCall {
  return { auth: uid === null ? null : { uid }, app, data };
}

/** Comprueba que la promesa falla con un `HttpsError` del código indicado. */
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

async function seedPerfil(uid = UID, extra: Record<string, unknown> = {}): Promise<void> {
  await adminDb()
    .doc(`users/${uid}`)
    .set({ name: 'Franco', businessName: 'Greda Austral', currency: 'CLP', plan: 'free', ...extra });
}

async function seedMes(monthKey: string, totals: Record<string, unknown> = {}, uid = UID): Promise<void> {
  await adminDb()
    .doc(`users/${uid}/months/${monthKey}`)
    .set({
      totalIncome: 300_000,
      totalExpenses: 120_000,
      totalPlatformFees: 9_000,
      transactionCount: 4,
      updatedAt: FieldValue.serverTimestamp(),
      ...totals,
    });
}

async function usage(uid = UID): Promise<Record<string, unknown> | undefined> {
  return (await adminDb().doc(`users/${uid}/meta/usage`).get()).data();
}

async function callesGlobales(dayKey = DIA): Promise<number> {
  const snap = await adminDb().doc(`system/aiUsage/days/${dayKey}`).get();
  const calls = snap.data()?.calls;
  return typeof calls === 'number' ? calls : 0;
}

async function conversaciones(uid = UID): Promise<number> {
  return (await adminDb().collection(`users/${uid}/conversations`).get()).size;
}

async function mensajesDe(convId: string, uid = UID): Promise<Array<{ role: string; text: string }>> {
  const snap = await adminDb()
    .collection(`users/${uid}/conversations/${convId}/messages`)
    .orderBy('createdAt')
    .get();
  return snap.docs.map((d) => ({ role: d.data().role as string, text: d.data().text as string }));
}

/** El system prompt que recibió el modelo en su primera llamada. */
function systemPrompt(modelo: Modelo): string {
  expect(modelo.llamadas.length, 'el modelo no recibió ninguna llamada').toBeGreaterThan(0);
  const primero = modelo.llamadas[0].messages[0];
  expect(primero.role).toBe('system');
  return primero.content;
}

/** El valor del renglón `- Mes:` del bloque de datos del prompt. */
function mesDelPrompt(modelo: Modelo): string | undefined {
  return /^- Mes: (\S+)$/m.exec(systemPrompt(modelo))?.[1];
}

describe('handleChat (callable chat)', () => {
  beforeEach(async () => {
    const db = adminDb();
    await wipeUser(db, UID);
    await wipeUser(db, OTHER);
    await wipeAiSystem(db);
  });

  // ─────────────────────────────────────────────────────────────────────────
  // El camino feliz. Es el test que faltaba: con él, el fallo de la consulta
  // descendente no habría llegado nunca a una rama.
  // ─────────────────────────────────────────────────────────────────────────
  describe('camino feliz', () => {
    it('responde, guarda los dos mensajes y cobra un mensaje de cuota', async () => {
      await seedPerfil();
      await seedMes(MES);
      const modelo = modeloQueResponde();

      const res = await handleChat(llamada({ message: '¿Cómo vamos este mes?' }), deps(modelo));

      expect(res.reply).toBe(RESPUESTA);
      expect(res.conversationId).toBeTruthy();
      expect(await mensajesDe(res.conversationId)).toEqual([
        { role: 'user', text: '¿Cómo vamos este mes?' },
        { role: 'assistant', text: RESPUESTA },
      ]);

      const conv = (await adminDb().doc(`users/${UID}/conversations/${res.conversationId}`).get()).data();
      expect(conv?.title).toBe('¿Cómo vamos este mes?');
      expect(conv?.messageCount).toBe(2);

      expect(await usage()).toMatchObject({ dayKey: DIA, chatCountDay: 1, chatCountLifetime: 1 });
      expect(await callesGlobales()).toBe(1);
    });

    it('pasa al modelo la clave, el modelo y el mensaje del usuario', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      await handleChat(llamada({ message: 'Hola' }), deps(modelo));

      expect(modelo.llamadas).toHaveLength(1);
      expect(modelo.llamadas[0].apiKey).toBe('clave-de-prueba');
      expect(modelo.llamadas[0].model).toBe('modelo-de-prueba');
      // system + el mensaje del usuario.
      expect(modelo.llamadas[0].messages.map((m) => m.role)).toEqual(['system', 'user']);
      expect(modelo.llamadas[0].messages[1].content).toBe('Hola');
    });

    it('reutiliza una conversación existente y acumula el historial', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      const primera = await handleChat(llamada({ message: 'Primera' }), deps(modelo));
      const segunda = await handleChat(
        llamada({ message: 'Segunda', conversationId: primera.conversationId }),
        deps(modelo),
      );

      expect(segunda.conversationId).toBe(primera.conversationId);
      expect(await conversaciones()).toBe(1);
      expect((await mensajesDe(primera.conversationId)).map((m) => m.text)).toEqual([
        'Primera',
        RESPUESTA,
        'Segunda',
        RESPUESTA,
      ]);
      const conv = (await adminDb().doc(`users/${UID}/conversations/${primera.conversationId}`).get()).data();
      expect(conv?.messageCount).toBe(4);

      // El segundo turno le manda al modelo el historial anterior, no solo el
      // mensaje nuevo.
      expect(modelo.llamadas[1].messages.map((m) => m.role)).toEqual([
        'system',
        'user',
        'assistant',
        'user',
      ]);
      expect(modelo.llamadas[1].messages.at(-1)?.content).toBe('Segunda');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // EL FALLO QUE MATABA LA FUNCIÓN. Estos son los tests de regresión.
  // ─────────────────────────────────────────────────────────────────────────
  describe('contexto del prompt: la consulta del mes (regresión del key scan)', () => {
    it('NO lanza con varios meses sembrados, que es lo que mataba toda llamada', async () => {
      await seedPerfil();
      // Catorce meses a caballo de dos años: con uno solo, una consulta mal
      // ordenada puede "acertar" por casualidad.
      for (const mes of [
        '2025-08', '2025-09', '2025-10', '2025-11', '2025-12',
        '2026-01', '2026-02', '2026-03', '2026-04', '2026-05',
        '2026-06', '2026-07', '2026-08', MES,
      ]) {
        await seedMes(mes);
      }
      const modelo = modeloQueResponde();

      // Antes esto no devolvía una respuesta mala: reventaba con
      // `9 FAILED_PRECONDITION: Firestore does not support descending key scans`.
      const res = await handleChat(llamada({ message: '¿Cuánto facturé?' }), deps(modelo));

      expect(res.reply).toBe(RESPUESTA);
      expect(mesDelPrompt(modelo)).toBe(MES);
    });

    it('cuenta al asistente el mes en curso cuando tiene movimientos', async () => {
      await seedPerfil();
      await seedMes('2026-07', { totalIncome: 1 });
      await seedMes(MES, { totalIncome: 777_000, totalExpenses: 100_000, totalPlatformFees: 7_000 });
      const modelo = modeloQueResponde();

      await handleChat(llamada({ message: 'Resumen' }), deps(modelo));

      const prompt = systemPrompt(modelo);
      expect(mesDelPrompt(modelo)).toBe(MES);
      // Bruto, comisiones y neto, que es el contrato C-3.
      expect(prompt).toContain('$777.000');
      expect(prompt).toContain('$7.000');
      expect(prompt).toContain('$770.000');
    });

    it('cae al mes más reciente con movimientos cuando el mes en curso está vacío', async () => {
      // El caso real de la temporada baja: `months.ts` BORRA los meses sin
      // movimientos, así que el mes en curso no tiene documento.
      await seedPerfil();
      await seedMes('2026-06', { totalIncome: 111 });
      await seedMes('2026-08', { totalIncome: 222_000 });
      const modelo = modeloQueResponde();

      await handleChat(llamada({ message: 'Resumen' }), deps(modelo));

      expect(mesDelPrompt(modelo)).toBe('2026-08');
      expect(systemPrompt(modelo)).toContain('$222.000');
    });

    it('con una cuenta sin meses, lo dice en vez de fallar', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      const res = await handleChat(llamada({ message: 'Hola' }), deps(modelo));

      expect(res.reply).toBe(RESPUESTA);
      expect(systemPrompt(modelo)).toContain('No hay meses con movimientos registrados todavía.');
    });

    it('mete en el prompt las transacciones recientes y el inventario', async () => {
      await seedPerfil();
      await seedMes(MES);
      const db = adminDb();
      await db.doc(`users/${UID}/transactions/t1`).set({
        title: 'Set de tazas',
        amount: 45_000,
        type: 'income',
        category: 'Ventas',
        monthKey: MES,
        date: Timestamp.fromDate(NOW),
        docType: 'boleta_venta',
        platformFee: 1_350,
      });
      await db.doc(`users/${UID}/inventory/i1`).set({ name: 'Taza', type: 'product', price: 9_000, stock: 4 });
      await db.doc(`users/${UID}/inventory/i2`).set({ name: 'Greda', type: 'material', price: 3_000, stock: 9 });
      const modelo = modeloQueResponde();

      await handleChat(llamada({ message: 'Resumen' }), deps(modelo));

      const prompt = systemPrompt(modelo);
      expect(prompt).toContain('Set de tazas');
      expect(prompt).toContain('Greda Austral');
      expect(prompt).toMatch(/[Pp]roductos.*1/);
      expect(prompt).toMatch(/[Mm]ateriales.*1/);
    });
  });

  describe('latestMonthDoc', () => {
    const userRef = (uid = UID): DocumentReference => adminDb().doc(`users/${uid}`);

    it('sin ningún mes devuelve undefined', async () => {
      expect(await latestMonthDoc(userRef(), NOW)).toBeUndefined();
    });

    it('devuelve el mes en curso cuando existe', async () => {
      await seedMes('2026-03');
      await seedMes(MES);
      expect((await latestMonthDoc(userRef(), NOW))?.id).toBe(MES);
    });

    it('devuelve el último mes anterior cuando el mes en curso no existe', async () => {
      await seedMes('2025-11');
      await seedMes('2026-02');
      expect((await latestMonthDoc(userRef(), NOW))?.id).toBe('2026-02');
    });

    it('cruza el cambio de año en el orden correcto', async () => {
      // `yyyy-MM` ordena cronológicamente como texto: 2026-01 va después de
      // 2025-12. Es la propiedad de la que depende el recorrido ascendente.
      await seedMes('2025-12');
      await seedMes('2026-01');
      expect((await latestMonthDoc(userRef(), NOW))?.id).toBe('2026-01');
    });

    it('no mira los meses de otro usuario', async () => {
      await seedMes('2026-08', {}, OTHER);
      expect(await latestMonthDoc(userRef(), NOW)).toBeUndefined();
      expect((await latestMonthDoc(userRef(OTHER), NOW))?.id).toBe('2026-08');
    });

    it('currentMonthKey da el mes de la zona horaria de la cuota', async () => {
      expect(currentMonthKey(NOW)).toBe(MES);
      // 23:30 del 31 de diciembre en Chile sigue siendo diciembre, aunque en
      // UTC ya sea enero.
      expect(currentMonthKey(new Date('2027-01-01T02:30:00Z'))).toBe('2026-12');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Autenticación y App Check.
  // ─────────────────────────────────────────────────────────────────────────
  describe('autenticación', () => {
    it('sin sesión se rechaza y no se escribe ni se gasta nada', async () => {
      const modelo = modeloQueResponde();
      const err = await falla('unauthenticated', handleChat(llamada({ message: 'Hola' }, null), deps(modelo)));
      expect(err.message).toContain('iniciar sesión');

      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
      expect(await conversaciones()).toBe(0);
      expect(await callesGlobales()).toBe(0);
    });

    it('con App Check exigido, una llamada sin token se rechaza', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      const err = await falla(
        'unauthenticated',
        handleChat(llamada({ message: 'Hola' }, UID, null), deps(modelo, { enforceAppCheck: true })),
      );
      expect(err.message).toContain('App Check');
      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();

      // Con token sí pasa: el interruptor no bloquea a la app de verdad.
      await handleChat(llamada({ message: 'Hola' }, UID, {}), deps(modelo, { enforceAppCheck: true }));
      expect(modelo.llamadas).toHaveLength(1);
    });

    it('con App Check apagado (el valor de hoy), una llamada sin token pasa', async () => {
      // `ENFORCE_APP_CHECK` está en `false` hasta que App Check se configure en
      // consola. Si este test empieza a fallar es que el interruptor cambió, y
      // entonces hay que revisar que la app mande el token.
      await seedPerfil();
      const modelo = modeloQueResponde();
      await handleChat(llamada({ message: 'Hola' }, UID, null), deps(modelo, { enforceAppCheck: false }));
      expect(modelo.llamadas).toHaveLength(1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Validación de la entrada. Va ANTES de reservar cuota: una entrada mala no
  // le puede costar al usuario uno de sus mensajes.
  // ─────────────────────────────────────────────────────────────────────────
  describe('validación del mensaje', () => {
    it(`acepta el mensaje de ${MAX_MESSAGE_CHARS} caracteres y rechaza el de uno más`, async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      await handleChat(llamada({ message: 'a'.repeat(MAX_MESSAGE_CHARS) }), deps(modelo));
      expect(modelo.llamadas).toHaveLength(1);

      const err = await falla(
        'invalid-argument',
        handleChat(llamada({ message: 'a'.repeat(MAX_MESSAGE_CHARS + 1) }), deps(modelo)),
      );
      expect(err.message).toContain(String(MAX_MESSAGE_CHARS));
      // Solo la llamada válida llegó al modelo.
      expect(modelo.llamadas).toHaveLength(1);
    });

    it('un mensaje demasiado largo NO gasta cuota ni deja nada escrito', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();

      await falla(
        'invalid-argument',
        handleChat(llamada({ message: 'a'.repeat(MAX_MESSAGE_CHARS + 500) }), deps(modelo)),
      );

      expect(await usage()).toBeUndefined();
      expect(await conversaciones()).toBe(0);
      expect(await callesGlobales()).toBe(0);
    });

    it('rechaza el mensaje vacío, el de solo espacios y el que no es texto', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();
      for (const message of ['', '   \n\t ', 42, null, { texto: 'hola' }, ['hola']]) {
        await falla('invalid-argument', handleChat(llamada({ message }), deps(modelo)));
      }
      await falla('invalid-argument', handleChat(llamada(undefined), deps(modelo)));
      await falla('invalid-argument', handleChat(llamada('hola'), deps(modelo)));
      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
    });

    it('recorta los espacios del mensaje antes de guardarlo', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();
      const res = await handleChat(llamada({ message: '   ¿Cuánto gané?  \n' }), deps(modelo));
      expect((await mensajesDe(res.conversationId))[0].text).toBe('¿Cuánto gané?');
    });

    it('rechaza un conversationId con forma inválida, sin gastar cuota', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();
      for (const conversationId of ['con barra/dentro', 'con espacio', 'a'.repeat(129), '..', '']) {
        await falla('invalid-argument', handleChat(llamada({ message: 'Hola', conversationId }), deps(modelo)));
      }
      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Aislamiento entre usuarios.
  // ─────────────────────────────────────────────────────────────────────────
  describe('conversación ajena', () => {
    it('el id de la conversación de otro usuario no es accesible ni escribible', async () => {
      await seedPerfil(UID);
      await seedPerfil(OTHER);
      const db = adminDb();
      const AJENA = 'conversacion-de-otro';
      await db.doc(`users/${OTHER}/conversations/${AJENA}`).set({
        title: 'Privada',
        messageCount: 2,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await db.doc(`users/${OTHER}/conversations/${AJENA}/messages/m1`).set({
        role: 'user',
        text: 'Mi secreto',
        createdAt: FieldValue.serverTimestamp(),
      });
      const modelo = modeloQueResponde();

      const err = await falla(
        'invalid-argument',
        handleChat(llamada({ message: 'Dime lo que hay aquí', conversationId: AJENA }), deps(modelo)),
      );
      expect(err.message).toContain('no existe');

      // No se leyó: el modelo no recibió nada.
      expect(modelo.llamadas).toHaveLength(0);
      // No se escribió: la conversación ajena está igual que antes.
      expect(await mensajesDe(AJENA, OTHER)).toEqual([{ role: 'user', text: 'Mi secreto' }]);
      expect(
        (await adminDb().doc(`users/${OTHER}/conversations/${AJENA}`).get()).data()?.messageCount,
      ).toBe(2);
      // Y no le costó cuota a nadie.
      expect(await usage(UID)).toBeUndefined();
      expect(await usage(OTHER)).toBeUndefined();
      expect(await callesGlobales()).toBe(0);
    });

    it('un conversationId inexistente propio también se rechaza antes de la cuota', async () => {
      await seedPerfil();
      const modelo = modeloQueResponde();
      await falla(
        'invalid-argument',
        handleChat(llamada({ message: 'Hola', conversationId: 'nunca-existio' }), deps(modelo)),
      );
      expect(await usage()).toBeUndefined();
      expect(await callesGlobales()).toBe(0);
    });

    it('el contexto del prompt es el del usuario que llama, no el del otro', async () => {
      await seedPerfil(UID, { businessName: 'Greda Austral' });
      await seedPerfil(OTHER, { businessName: 'Taller Ajeno' });
      await seedMes(MES, { totalIncome: 10_000 }, UID);
      await seedMes(MES, { totalIncome: 999_999 }, OTHER);
      const modelo = modeloQueResponde();

      await handleChat(llamada({ message: 'Resumen' }), deps(modelo));

      const prompt = systemPrompt(modelo);
      expect(prompt).toContain('Greda Austral');
      expect(prompt).not.toContain('Taller Ajeno');
      expect(prompt).toContain('$10.000');
      expect(prompt).not.toContain('999.999');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Cuota. El detalle de por qué la del plan free es de por vida está en
  // `quota.ts`; aquí se comprueba que `chat` la respeta de verdad.
  // ─────────────────────────────────────────────────────────────────────────
  describe('cuota', () => {
    it('agotada la cuota DE POR VIDA del plan free, no se llama al modelo', async () => {
      await seedPerfil(UID, { plan: 'free' });
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        .set({ dayKey: DIA, chatCountDay: 0, chatCountLifetime: FREE_LIFETIME_QUOTA });
      const modelo = modeloQueResponde();

      const err = await falla('resource-exhausted', handleChat(llamada({ message: 'Hola' }), deps(modelo)));
      expect(err.message).toBe(freeQuotaExhaustedMessage(FREE_LIFETIME_QUOTA));
      // No promete un plan Pro que no existe (política de pagos de Play).
      expect(err.message).not.toMatch(/\bPro\b/);

      expect(modelo.llamadas).toHaveLength(0);
      expect(await conversaciones()).toBe(0);
      // El contador no sube por encima del tope.
      expect((await usage())?.chatCountLifetime).toBe(FREE_LIFETIME_QUOTA);
      expect(await callesGlobales()).toBe(0);
    });

    it('la cuota de por vida NO se reinicia al cambiar el día', async () => {
      await seedPerfil(UID, { plan: 'free' });
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        // Contador diario de otro día: el de por vida sigue agotado.
        .set({ dayKey: '2026-09-01', chatCountDay: 0, chatCountLifetime: FREE_LIFETIME_QUOTA });
      const modelo = modeloQueResponde();

      await falla('resource-exhausted', handleChat(llamada({ message: 'Hola' }), deps(modelo)));
      expect(modelo.llamadas).toHaveLength(0);
    });

    it('con un mensaje restante responde, y el siguiente ya no', async () => {
      await seedPerfil(UID, { plan: 'free' });
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        .set({ dayKey: DIA, chatCountDay: 0, chatCountLifetime: FREE_LIFETIME_QUOTA - 1 });
      const modelo = modeloQueResponde();

      await handleChat(llamada({ message: 'El último' }), deps(modelo));
      expect((await usage())?.chatCountLifetime).toBe(FREE_LIFETIME_QUOTA);

      await falla('resource-exhausted', handleChat(llamada({ message: 'Uno más' }), deps(modelo)));
      expect(modelo.llamadas).toHaveLength(1);
    });

    it('el plan pro tiene cuota diaria, no de por vida', async () => {
      await seedPerfil(UID, { plan: 'pro' });
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        // Muy por encima del tope del free, pero el plan es pro.
        .set({ dayKey: DIA, chatCountDay: 1, chatCountLifetime: FREE_LIFETIME_QUOTA * 10 });
      const modelo = modeloQueResponde();

      await handleChat(llamada({ message: 'Hola' }), deps(modelo));
      expect(modelo.llamadas).toHaveLength(1);

      // Y su tope diario sí lo frena.
      await adminDb()
        .doc(`users/${UID}/meta/usage`)
        .set({ dayKey: DIA, chatCountDay: PRO_DAILY_QUOTA, chatCountLifetime: 0 });
      await falla('resource-exhausted', handleChat(llamada({ message: 'Hola' }), deps(modelo)));
      expect(modelo.llamadas).toHaveLength(1);
    });

    it('el freno de mano global corta el asistente sin tocar la cuota del usuario', async () => {
      await seedPerfil();
      const db = adminDb();
      await db.doc('system/aiConfig').set({ globalDailyCapEnabled: true, globalDailyCap: 2 });
      await db.doc(`system/aiUsage/days/${DIA}`).set({ calls: 2, dayKey: DIA });
      const modelo = modeloQueResponde();

      const err = await falla('resource-exhausted', handleChat(llamada({ message: 'Hola' }), deps(modelo)));
      expect(err.message).toContain('tope de uso del día');
      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toBeUndefined();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Fallos del servidor: no los paga el usuario.
  // ─────────────────────────────────────────────────────────────────────────
  describe('fallo de OpenRouter', () => {
    it('NO consume cuota y no deja la conversación a medias', async () => {
      await seedPerfil();
      await seedMes(MES);
      const modelo = modeloQueFalla();

      const err = await falla('internal', handleChat(llamada({ message: 'Hola' }), deps(modelo)));
      expect(err.message).toContain('No se pudo obtener una respuesta');
      // Se llegó a llamar al modelo: el fallo es suyo, no del flujo.
      expect(modelo.llamadas).toHaveLength(1);

      // La cuota vuelve a cero: reintentar no le cuesta un mensaje.
      expect(await usage()).toMatchObject({ chatCountDay: 0, chatCountLifetime: 0 });
      expect(await callesGlobales()).toBe(0);
      // Y no queda ni la conversación ni el mensaje huérfano.
      expect(await conversaciones()).toBe(0);
    });

    it('en una conversación que ya existía, borra el mensaje pero no la conversación', async () => {
      await seedPerfil();
      const bueno = modeloQueResponde();
      const primera = await handleChat(llamada({ message: 'Primera' }), deps(bueno));
      expect((await usage())?.chatCountLifetime).toBe(1);

      const malo = modeloQueFalla();
      await falla(
        'internal',
        handleChat(llamada({ message: 'Segunda', conversationId: primera.conversationId }), deps(malo)),
      );

      // La conversación sigue, con solo los dos mensajes del turno que sí salió.
      expect(await conversaciones()).toBe(1);
      expect((await mensajesDe(primera.conversationId)).map((m) => m.text)).toEqual(['Primera', RESPUESTA]);
      const conv = (await adminDb().doc(`users/${UID}/conversations/${primera.conversationId}`).get()).data();
      expect(conv?.messageCount).toBe(2);
      // Y la cuota del turno fallido se devolvió: queda la del turno bueno.
      expect(await usage()).toMatchObject({ chatCountDay: 1, chatCountLifetime: 1 });
      expect(await callesGlobales()).toBe(1);
    });

    it('un fallo no deja al usuario sin poder reintentar', async () => {
      await seedPerfil();
      await falla('internal', handleChat(llamada({ message: 'Hola' }), deps(modeloQueFalla())));

      const bueno = modeloQueResponde();
      const res = await handleChat(llamada({ message: 'Hola' }), deps(bueno));
      expect(res.reply).toBe(RESPUESTA);
      expect((await usage())?.chatCountLifetime).toBe(1);
    });
  });

  describe('fallo al leer el contexto', () => {
    /**
     * Firestore de verdad, pero con la colección `months` del usuario rota.
     *
     * El `userRef` que `handleChat` pide es el PRIMERO con esa ruta (antes que
     * el de `reserveChatQuota`), así que romper solo esa primera entrega deja
     * intacto todo lo que el SDK usa por dentro: la referencia envuelta no sale
     * nunca de `handleChat`, que solo le llama a `.collection(...)`.
     */
    function dbConMesesRotos(uid: string): Firestore {
      const db = adminDb();
      let yaEntregado = false;
      return new Proxy(db, {
        get(target, prop, receiver) {
          if (prop === 'doc') {
            return (path: string) => {
              const ref = target.doc(path);
              if (path !== `users/${uid}` || yaEntregado) return ref;
              yaEntregado = true;
              return {
                collection: (name: string) => {
                  if (name === 'months') throw new Error('months caído (simulado)');
                  return ref.collection(name);
                },
              };
            };
          }
          const valor = Reflect.get(target, prop, receiver);
          return typeof valor === 'function' ? valor.bind(target) : valor;
        },
      }) as Firestore;
    }

    it('devuelve la cuota y limpia lo escrito, igual que el fallo del modelo', async () => {
      // Esta red no existía: el fallo de la consulta descendente se lanzaba
      // aquí, fuera de todo `try`, y cada intento le gastaba al usuario del
      // plan free uno de sus mensajes de por vida en una función que nunca
      // respondía.
      await seedPerfil();
      const modelo = modeloQueResponde();

      const err = await falla(
        'internal',
        handleChat(llamada({ message: 'Hola' }), deps(modelo, { db: dbConMesesRotos(UID) })),
      );
      expect(err.message).toContain('contexto');

      expect(modelo.llamadas).toHaveLength(0);
      expect(await usage()).toMatchObject({ chatCountDay: 0, chatCountLifetime: 0 });
      expect(await callesGlobales()).toBe(0);
      expect(await conversaciones()).toBe(0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // P-12: reportar una respuesta del asistente.
  // ─────────────────────────────────────────────────────────────────────────
  describe('reportar una respuesta del asistente (P-12)', () => {
    /**
     * POR QUÉ ESTE TEST ESTÁ AQUÍ Y NO SOLO EN `rules.test.ts`.
     *
     * El botón «Reportar respuesta» es un requisito de la política de IA
     * generativa de Google Play, y solo se dibuja debajo de un mensaje REAL del
     * asistente. Mientras el asistente estuvo muerto, ese mensaje no existía
     * nunca, así que el botón no se vio funcionar ni una vez. `rules.test.ts`
     * comprueba la forma del documento con ids inventados; esto cierra el
     * círculo con los ids que acaba de producir `handleChat` y con el texto
     * exacto que respondió el modelo, pasando por las reglas de verdad y como
     * el usuario autenticado, no con el Admin SDK (que se las salta).
     */
    let env: RulesTestEnvironment;

    beforeAll(async () => {
      const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '').split(':');
      if (!host) {
        throw new Error('FIRESTORE_EMULATOR_HOST no está definido: usa `npm --prefix functions test`.');
      }
      env = await initializeTestEnvironment({
        projectId: TEST_PROJECT_ID,
        firestore: { rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8'), host, port: Number(port) },
      });
    });

    afterAll(async () => {
      await env.cleanup();
    });

    it('un mensaje real del asistente se puede reportar y el reporte queda guardado', async () => {
      await seedPerfil();
      await seedMes(MES);
      const modelo = modeloQueResponde('Deberías subir los precios un 20%.');

      const res = await handleChat(llamada({ message: '¿Subo los precios?' }), deps(modelo));

      // El mensaje del asistente, con el id que le puso Firestore.
      const msgs = await adminDb()
        .collection(`users/${UID}/conversations/${res.conversationId}/messages`)
        .orderBy('createdAt')
        .get();
      const asistente = msgs.docs[1];
      expect(asistente.data().role).toBe('assistant');
      expect(asistente.data().text).toBe('Deberías subir los precios un 20%.');

      // Exactamente los campos de `AiProvider.reportMessage`, escritos por el
      // usuario autenticado y sometidos a `firestore.rules`.
      const clientDb = env.authenticatedContext(UID).firestore();
      await assertSucceeds(
        addDoc(clientCollection(clientDb, 'users', UID, 'aiReports'), {
          messageId: asistente.id,
          conversationId: res.conversationId,
          reason: 'incorrecto',
          comment: 'El 20% se lo inventó.',
          reportedText: asistente.data().text,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      );

      const reportes = await adminDb().collection(`users/${UID}/aiReports`).get();
      expect(reportes.size).toBe(1);
      expect(reportes.docs[0].data()).toMatchObject({
        messageId: asistente.id,
        conversationId: res.conversationId,
        reason: 'incorrecto',
        reportedText: 'Deberías subir los precios un 20%.',
      });
    });

    it('también se puede reportar el mensaje de bienvenida, que no tiene conversación', async () => {
      // El cliente omite `conversationId` en ese caso (elemento null-aware en
      // `reportMessage`); si las reglas lo exigieran, el reporte se denegaría.
      const clientDb = env.authenticatedContext(UID).firestore();
      await assertSucceeds(
        addDoc(clientCollection(clientDb, 'users', UID, 'aiReports'), {
          messageId: 'bienvenida',
          reason: 'otro',
          reportedText: 'Hola, soy tu asistente financiero.',
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        }),
      );
      expect((await adminDb().collection(`users/${UID}/aiReports`).get()).size).toBe(1);
    });
  });
});
