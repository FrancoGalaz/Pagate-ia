/**
 * Tests del borrado de cuenta (P-07) contra el emulador de Firestore.
 *
 * Se prueba `deleteUserData`, que es la parte del callable que borra datos. El
 * borrado del usuario de Authentication (`getAuth().deleteUser`) no se cubre
 * aquí porque `npm test` levanta solo el emulador de Firestore; queda anotado en
 * el informe.
 */

import { beforeEach, describe, expect, it } from 'vitest';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { checkDeleteAccountCaller, deleteUserData } from '../src/account';
import { adminDb, wipeUser } from './helpers/admin';

const UID = 'borrame';
const OTHER = 'intacto';

/** Siembra un usuario con un documento en cada subcolección del contrato. */
async function seedFullUser(uid: string): Promise<void> {
  const db = adminDb();
  const batch = db.batch();
  batch.set(db.doc(`users/${uid}`), {
    name: 'Usuario de prueba',
    currency: 'CLP',
    plan: 'free',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.doc(`users/${uid}/inventory/i1`), { name: 'Lana', type: 'material', price: 1000, stock: 2 });
  batch.set(db.doc(`users/${uid}/inventory/i2`), { name: 'Gorro', type: 'product', price: 9000, stock: 1 });
  batch.set(db.doc(`users/${uid}/transactions/t1`), {
    title: 'Venta',
    amount: 9000,
    type: 'income',
    monthKey: '2026-09',
    date: Timestamp.now(),
  });
  batch.set(db.doc(`users/${uid}/fixedExpenses/f1`), { name: 'Arriendo', amount: 200000 });
  batch.set(db.doc(`users/${uid}/months/2026-09`), { totalIncome: 9000, totalExpenses: 0, transactionCount: 1 });
  batch.set(db.doc(`users/${uid}/meta/usage`), { dayKey: '2026-09-29', chatCountDay: 3, chatCountLifetime: 12 });
  batch.set(db.doc(`users/${uid}/conversations/c1`), { title: 'Hola', messageCount: 2 });
  batch.set(db.doc(`users/${uid}/conversations/c1/messages/m1`), { role: 'user', text: 'Hola' });
  batch.set(db.doc(`users/${uid}/conversations/c1/messages/m2`), { role: 'assistant', text: 'Qué tal' });
  // aiReports (P-12). Va aquí porque el borrado de cuenta tiene que ser
  // COMPLETO: la política de eliminación de datos de Google Play no admite que
  // una subcolección sobreviva, y los reportes son la única que el cliente crea
  // y después no puede borrar por su cuenta, así que si `recursiveDelete` no los
  // alcanzara no habría ninguna otra vía para quitarlos.
  batch.set(db.doc(`users/${uid}/aiReports/r1`), {
    messageId: 'm2',
    conversationId: 'c1',
    reason: 'incorrecto',
    reportedText: 'Qué tal',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
}

describe('deleteUserData', () => {
  beforeEach(async () => {
    const db = adminDb();
    await wipeUser(db, UID);
    await wipeUser(db, OTHER);
  });

  it('no deja ningún documento bajo users/{uid}', async () => {
    const db = adminDb();
    await seedFullUser(UID);

    // Comprobación previa: la siembra existe de verdad.
    expect((await db.doc(`users/${UID}`).get()).exists).toBe(true);
    expect((await db.collection(`users/${UID}/conversations/c1/messages`).get()).size).toBe(2);
    expect((await db.collection(`users/${UID}/aiReports`).get()).size).toBe(1);

    const leftovers = await deleteUserData(db, UID);
    expect(leftovers).toEqual([]);

    expect((await db.doc(`users/${UID}`).get()).exists).toBe(false);
    for (const path of [
      `users/${UID}/inventory`,
      `users/${UID}/transactions`,
      `users/${UID}/fixedExpenses`,
      `users/${UID}/aiReports`,
      `users/${UID}/months`,
      `users/${UID}/meta`,
      `users/${UID}/conversations`,
      `users/${UID}/conversations/c1/messages`,
    ]) {
      const snap = await db.collection(path).get();
      expect(snap.empty, `quedaron documentos en ${path}`).toBe(true);
    }
    expect(await db.doc(`users/${UID}`).listCollections()).toEqual([]);
  });

  it('no toca los datos de otros usuarios', async () => {
    const db = adminDb();
    await seedFullUser(UID);
    await seedFullUser(OTHER);

    await deleteUserData(db, UID);

    expect((await db.doc(`users/${OTHER}`).get()).exists).toBe(true);
    expect((await db.collection(`users/${OTHER}/transactions`).get()).size).toBe(1);
    expect((await db.collection(`users/${OTHER}/conversations/c1/messages`).get()).size).toBe(2);
    expect((await db.collection(`users/${OTHER}/aiReports`).get()).size).toBe(1);
  });

  it('es idempotente: borrar dos veces no falla', async () => {
    const db = adminDb();
    await seedFullUser(UID);
    expect(await deleteUserData(db, UID)).toEqual([]);
    expect(await deleteUserData(db, UID)).toEqual([]);
  });

  it('no falla sobre una cuenta que nunca escribió nada', async () => {
    const db = adminDb();
    expect(await deleteUserData(db, 'cuenta-vacia')).toEqual([]);
  });
});

describe('checkDeleteAccountCaller (sesión y App Check)', () => {
  it('con App Check exigido, una llamada sin token se rechaza', () => {
    expect(() => checkDeleteAccountCaller({ auth: { uid: UID }, app: undefined }, true)).toThrow(
      expect.objectContaining({ code: 'unauthenticated', message: expect.stringContaining('App Check') }),
    );
  });

  it('con App Check exigido, una llamada con token pasa y devuelve el uid', () => {
    expect(checkDeleteAccountCaller({ auth: { uid: UID }, app: {} }, true)).toBe(UID);
  });

  it('con App Check apagado (el valor de hoy), una llamada sin token pasa', () => {
    expect(checkDeleteAccountCaller({ auth: { uid: UID }, app: undefined }, false)).toBe(UID);
  });
});
