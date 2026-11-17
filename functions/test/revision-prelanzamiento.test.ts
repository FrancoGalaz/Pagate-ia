/**
 * Tests de la revisión prelanzamiento (docs/REVISION-PRELANZAMIENTO.md).
 *
 * Cada uno demostró un hallazgo de la revisión fallando antes del arreglo, y
 * se queda como regresión.
 */

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { logger } from 'firebase-functions/v2';
import { checkDeleteAccountCaller, deleteUserData } from '../src/account';
import { checkDeleteChatHistoryCaller } from '../src/chatHistory';
import { handleChat } from '../src/chat';
import { OpenRouterError } from '../src/openrouter';
import { FREE_LIFETIME_SCAN_QUOTA } from '../src/quota';
import { handleScanReceipt, type ScanCall, type ScanDeps } from '../src/scan';
import { waitlistDocId } from '../src/waitlist';
import { adminDb, seedAiConfig, wipeAiSystem, wipeUser } from './helpers/admin';

const UID = 'revision-uid';
const NOW = new Date('2026-11-16T15:00:00Z');
const RAIZ = join(__dirname, '..', '..');

beforeEach(async () => {
  await wipeUser(adminDb(), UID);
  await wipeAiSystem(adminDb());
  await seedAiConfig(adminDb());
});

// Hallazgo 1.1: gasto ilimitado de OpenRouter con `scanReceipt`.
describe('scanReceipt: una salida truncada no puede salir gratis', () => {
  it('no deja hacer más llamadas al modelo que las lecturas de la cuota', async () => {
    // El JSON cortado a mitad es lo que devuelve el modelo cuando la boleta es
    // larga y la respuesta choca con `max_tokens`. El texto de entrada lo
    // controla quien llama, así que lo provoca a voluntad.
    const truncado = '{"items":[{"name":"Arcilla gres 25 kg","quantity":2,"unit":"sacos","unitPri';
    let llamadasAlModelo = 0;
    const deps: ScanDeps = {
      db: adminDb(),
      ask: async () => {
        llamadasAlModelo += 1;
        return { text: truncado, usage: { promptTokens: 2400, completionTokens: 1500, totalTokens: 3900 } };
      },
      apiKey: 'clave-de-prueba',
      model: 'modelo-de-prueba',
      enforceAppCheck: false,
      now: NOW,
    };
    const llamada: ScanCall = {
      auth: { uid: UID, token: { email_verified: true } },
      app: {},
      data: { text: 'BOLETA\n' + '1 ARTICULO LARGO 9.990\n'.repeat(300) },
    };

    const intentos = FREE_LIFETIME_SCAN_QUOTA + 10;
    for (let i = 0; i < intentos; i += 1) {
      await handleScanReceipt(llamada, deps).catch(() => undefined);
    }

    // Cada llamada al modelo se pagó (2.400 + 1.500 tokens). Hoy se hacen las
    // 50, porque cada fallo de parseo devuelve la lectura.
    expect(llamadasAlModelo).toBeLessThanOrEqual(FREE_LIFETIME_SCAN_QUOTA);
  });
});

// Hallazgo 3.1: la página de eliminación promete borrar la inscripción en la
// lista de espera y `deleteAccount` no la toca.
describe('deleteAccount: borra la inscripción en la lista de espera', () => {
  it('no deja waitlist/{hash del correo} tras borrar los datos de la cuenta', async () => {
    const db = adminDb();
    const correo = 'artesana@example.com';
    const inscripcion = db.collection('waitlist').doc(waitlistDocId(correo));
    await inscripcion.set({ name: 'Juana', email: correo, source: 'landing' });
    await db.doc(`users/${UID}`).set({ name: 'Juana', currency: 'CLP' });

    // Es todo lo que el callable borra de Firestore: después solo elimina el
    // usuario de Authentication. El correo es el del token, que puede venir
    // con mayúsculas: la lista de espera lo guarda normalizado.
    const quedo = await deleteUserData(db, UID, {
      email: ' Artesana@Example.com ',
      email_verified: true,
    });

    const queda = (await inscripcion.get()).exists;
    await inscripcion.delete();
    expect(queda, 'el nombre y el correo siguen en waitlist/ después del borrado').toBe(false);
    expect(quedo).toEqual([]);
  });

  it('no toca la inscripción de otro correo', async () => {
    const db = adminDb();
    const ajena = db.collection('waitlist').doc(waitlistDocId('otra@example.com'));
    await ajena.set({ name: 'Otra', email: 'otra@example.com', source: 'landing' });

    await deleteUserData(db, UID, { email: 'artesana@example.com', email_verified: true });

    const sigue = (await ajena.get()).exists;
    await ajena.delete();
    expect(sigue).toBe(true);
  });
});

// Hallazgo 2.1, segunda parte: las reglas ya niegan el acceso del cliente a
// una cuenta borrada, pero un token que siga vivo todavía podía llamar a los
// callables y recrear `meta/usage` y una conversación bajo ese uid.
describe('cuenta borrada: los callables de IA la rechazan', () => {
  const auth = { uid: UID, token: { email_verified: true } };

  async function marcarBorrada(): Promise<void> {
    await adminDb().doc(`deletedUsers/${UID}`).set({ deletedAt: new Date() });
  }

  async function nadaEscrito(): Promise<void> {
    const db = adminDb();
    expect((await db.doc(`users/${UID}/meta/usage`).get()).exists).toBe(false);
    expect((await db.collection(`users/${UID}/conversations`).get()).size).toBe(0);
  }

  it('chat no responde ni escribe nada bajo el uid borrado', async () => {
    await marcarBorrada();
    let llamadas = 0;
    const err = await handleChat(
      { auth, app: {}, data: { message: 'hola' } },
      {
        db: adminDb(),
        ask: async () => {
          llamadas += 1;
          return { text: 'hola', usage: null };
        },
        apiKey: 'clave',
        model: 'modelo',
        enforceAppCheck: false,
        now: NOW,
      },
    ).catch((e: unknown) => e);

    await adminDb().doc(`deletedUsers/${UID}`).delete();
    expect((err as { code?: string }).code).toBe('unauthenticated');
    expect(llamadas).toBe(0);
    await nadaEscrito();
  });

  it('scanReceipt tampoco', async () => {
    await marcarBorrada();
    let llamadas = 0;
    const err = await handleScanReceipt(
      { auth, app: {}, data: { text: 'BOLETA' } },
      {
        db: adminDb(),
        ask: async () => {
          llamadas += 1;
          return { text: '{"items":[]}', usage: null };
        },
        apiKey: 'clave',
        model: 'modelo',
        enforceAppCheck: false,
        now: NOW,
      },
    ).catch((e: unknown) => e);

    await adminDb().doc(`deletedUsers/${UID}`).delete();
    expect((err as { code?: string }).code).toBe('unauthenticated');
    expect(llamadas).toBe(0);
    await nadaEscrito();
  });
});

// Hallazgo 1.1, segunda parte: la cuota se devolvía ante CUALQUIER error del
// proveedor, también cuando ya había cobrado la llamada (respondió 200 con el
// texto vacío, o se cortó por plazo con la generación en marcha).
describe('cuota: no se devuelve si el proveedor ya cobró', () => {
  const auth = { uid: UID, token: { email_verified: true } };
  const base = { db: adminDb(), apiKey: 'clave', model: 'modelo', enforceAppCheck: false, now: NOW };

  async function usados(campo: string): Promise<unknown> {
    return (await adminDb().doc(`users/${UID}/meta/usage`).get()).data()?.[campo];
  }

  const vacia = new OpenRouterError('El modelo devolvió una respuesta vacía', 200);
  const plazo = new OpenRouterError('Tiempo de espera agotado (30000 ms)', undefined, true);
  const caido = new OpenRouterError('HTTP 503: upstream caído', 503);

  for (const [nombre, error, esperado] of [
    ['respuesta vacía con 200: se cobró', vacia, 1],
    ['plazo agotado: pudo cobrarse', plazo, 1],
    ['proveedor caído (503): no se cobró', caido, 0],
  ] as const) {
    it(`chat, ${nombre}`, async () => {
      await handleChat(
        { auth, app: {}, data: { message: 'hola' } },
        {
          ...base,
          ask: async () => {
            throw error;
          },
        },
      ).catch(() => undefined);

      expect(await usados('chatCountLifetime')).toBe(esperado);
      // En los tres casos la conversación queda limpia: sin pregunta huérfana.
      expect((await adminDb().collection(`users/${UID}/conversations`).get()).size).toBe(0);
    });

    it(`scanReceipt, ${nombre}`, async () => {
      await handleScanReceipt(
        { auth, app: {}, data: { text: 'BOLETA' } },
        {
          ...base,
          ask: async () => {
            throw error;
          },
        },
      ).catch(() => undefined);

      expect(await usados('scanCountLifetime')).toBe(esperado);
    });
  }
});

// Hallazgo 5.3: el rechazo de App Check tiene que decirle al usuario qué hacer.
describe('App Check: el rechazo es accionable', () => {
  const sinToken = { auth: { uid: UID, token: { email_verified: true } }, app: undefined };
  const deps = {
    db: adminDb(),
    ask: async () => ({ text: 'hola', usage: null }),
    apiKey: 'clave',
    model: 'modelo',
    enforceAppCheck: true,
    now: NOW,
  };
  const ESPERADO = 'No pudimos verificar la app. Instálala o actualízala desde Google Play.';

  it('chat, scanReceipt, deleteAccount y deleteChatHistory dicen lo mismo', async () => {
    const mensajes = [
      await handleChat({ ...sinToken, data: { message: 'hola' } }, deps).catch((e: Error) => e.message),
      await handleScanReceipt({ ...sinToken, data: { text: 'BOLETA' } }, deps).catch(
        (e: Error) => e.message,
      ),
      (() => {
        try {
          checkDeleteAccountCaller(sinToken, true);
          return 'no lanzó';
        } catch (e) {
          return (e as Error).message;
        }
      })(),
      (() => {
        try {
          checkDeleteChatHistoryCaller(sinToken, true);
          return 'no lanzó';
        } catch (e) {
          return (e as Error).message;
        }
      })(),
    ];
    expect(mensajes).toEqual([ESPERADO, ESPERADO, ESPERADO, ESPERADO]);
  });
});

// Hallazgo 3.3: los registros no llevan texto del modelo ni del proveedor. La
// política dice que solo guardan fecha, función invocada y errores.
describe('registros del servidor: sin texto del modelo', () => {
  const SECRETO = 'FERRETERIA EL GRES RUT 76.543.210-K';
  const auth = { uid: UID, token: { email_verified: true } };
  const base = { db: adminDb(), apiKey: 'clave', model: 'modelo', enforceAppCheck: false, now: NOW };

  /** Corre la llamada y devuelve todo lo que se mandó a `logger.error`. */
  async function registrado(llamada: () => Promise<unknown>): Promise<string> {
    const espia = vi.spyOn(logger, 'error').mockImplementation(() => undefined);
    try {
      await llamada().catch(() => undefined);
      expect(espia).toHaveBeenCalled();
      return JSON.stringify(espia.mock.calls);
    } finally {
      espia.mockRestore();
    }
  }

  it('scanReceipt no registra la salida del modelo cuando no es JSON', async () => {
    const log = await registrado(() =>
      handleScanReceipt(
        { auth, app: {}, data: { text: 'BOLETA' } },
        { ...base, ask: async () => ({ text: `${SECRETO} no es json`, usage: null }) },
      ),
    );
    expect(log).not.toContain('FERRETERIA');
    expect(log).toContain(UID);
  });

  it('scanReceipt no registra el cuerpo del error del proveedor', async () => {
    const log = await registrado(() =>
      handleScanReceipt(
        { auth, app: {}, data: { text: 'BOLETA' } },
        {
          ...base,
          ask: async () => {
            throw new OpenRouterError(`HTTP 400: ${SECRETO}`, 400);
          },
        },
      ),
    );
    expect(log).not.toContain('FERRETERIA');
    expect(log).toContain('400');
  });

  it('chat no registra el cuerpo del error del proveedor', async () => {
    const log = await registrado(() =>
      handleChat(
        { auth, app: {}, data: { message: 'hola' } },
        {
          ...base,
          ask: async () => {
            throw new OpenRouterError(`HTTP 400: ${SECRETO}`, 400);
          },
        },
      ),
    );
    expect(log).not.toContain('FERRETERIA');
    expect(log).toContain('400');
  });
});

// Hallazgo 3.2: la política dice que el texto de las boletas "hoy no sale" del
// teléfono mientras el backend ya exporta el callable que lo manda a OpenRouter.
describe('política de privacidad: el lector de boletas en servidor', () => {
  it('declara el envío del texto si scanReceipt se despliega con el backend', () => {
    const index = readFileSync(join(RAIZ, 'functions', 'src', 'index.ts'), 'utf8');
    const legal = readFileSync(join(RAIZ, 'landing', 'src', 'content', 'legal-meta.ts'), 'utf8');

    const seDespliega = /export\s*\{\s*scanReceipt\s*\}/.test(index);
    const declarado = /ordenadoDeBoletasEnServidor:\s*true/.test(legal);

    expect(seDespliega && !declarado, 'index.ts exporta scanReceipt y la política dice que no está activo').toBe(
      false,
    );
  });
});
