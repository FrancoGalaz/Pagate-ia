/**
 * Tests de la revisión prelanzamiento (docs/REVISION-PRELANZAMIENTO.md).
 *
 * LOS TRES FALLAN HOY A PROPÓSITO: cada uno demuestra un hallazgo de la
 * revisión y no arregla nada. Pasan a verde cuando se corrija el código que
 * señalan; hasta entonces `npm test` queda en rojo por este archivo.
 */

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { beforeEach, describe, expect, it } from 'vitest';
import { deleteUserData } from '../src/account';
import { FREE_LIFETIME_SCAN_QUOTA } from '../src/quota';
import { handleScanReceipt, type ScanCall, type ScanDeps } from '../src/scan';
import { waitlistDocId } from '../src/waitlist';
import { adminDb, wipeAiSystem, wipeUser } from './helpers/admin';

const UID = 'revision-uid';
const NOW = new Date('2026-11-16T15:00:00Z');
const RAIZ = join(__dirname, '..', '..');

beforeEach(async () => {
  await wipeUser(adminDb(), UID);
  await wipeAiSystem(adminDb());
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
    // usuario de Authentication.
    await deleteUserData(db, UID);

    const queda = (await inscripcion.get()).exists;
    await inscripcion.delete();
    expect(queda, 'el nombre y el correo siguen en waitlist/ después del borrado').toBe(false);
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
