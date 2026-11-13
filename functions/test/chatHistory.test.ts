/**
 * Tests del borrado del historial del asistente contra el emulador de Firestore.
 */

import { beforeEach, describe, expect, it } from 'vitest';
import { FieldValue } from 'firebase-admin/firestore';
import { checkDeleteChatHistoryCaller, deleteChatHistoryData } from '../src/chatHistory';
import { adminDb, wipeUser } from './helpers/admin';

const UID = 'con-historial';
const OTHER = 'otro-usuario';

async function seed(uid: string): Promise<void> {
  const db = adminDb();
  const batch = db.batch();
  batch.set(db.doc(`users/${uid}`), { name: 'Usuario', plan: 'free' });
  batch.set(db.doc(`users/${uid}/meta/usage`), { dayKey: '2026-11-08', chatCountDay: 3, chatCountLifetime: 12 });
  batch.set(db.doc(`users/${uid}/conversations/c1`), { title: 'Hola', messageCount: 2 });
  batch.set(db.doc(`users/${uid}/conversations/c1/messages/m1`), { role: 'user', text: 'Hola' });
  batch.set(db.doc(`users/${uid}/conversations/c1/messages/m2`), { role: 'assistant', text: 'Qué tal' });
  batch.set(db.doc(`users/${uid}/conversations/c2`), { title: 'Precios', messageCount: 1 });
  batch.set(db.doc(`users/${uid}/conversations/c2/messages/m1`), { role: 'user', text: '¿Cuánto cobro?' });
  // Mensaje huérfano: su conversación no tiene documento.
  batch.set(db.doc(`users/${uid}/conversations/sin-doc/messages/m1`), { role: 'user', text: 'Huérfano' });
  batch.set(db.doc(`users/${uid}/aiReports/r1`), {
    messageId: 'm2',
    conversationId: 'c1',
    reason: 'incorrecto',
    reportedText: 'Qué tal',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.doc(`users/${uid}/transactions/t1`), { title: 'Venta', amount: 9000, type: 'income' });
  await batch.commit();
}

describe('deleteChatHistoryData', () => {
  beforeEach(async () => {
    const db = adminDb();
    await wipeUser(db, UID);
    await wipeUser(db, OTHER);
  });

  it('borra conversaciones y mensajes, incluidos los huérfanos', async () => {
    const db = adminDb();
    await seed(UID);
    expect((await db.collection(`users/${UID}/conversations`).get()).size).toBe(2);

    expect(await deleteChatHistoryData(db, UID)).toEqual([]);

    expect((await db.collection(`users/${UID}/conversations`).get()).empty).toBe(true);
    for (const conv of ['c1', 'c2', 'sin-doc']) {
      const msgs = await db.collection(`users/${UID}/conversations/${conv}/messages`).get();
      expect(msgs.empty, `quedaron mensajes en ${conv}`).toBe(true);
    }
    expect(await db.collection(`users/${UID}/conversations`).listDocuments()).toEqual([]);
  });

  it('no toca el contador de cuota, los reportes ni el resto de la cuenta', async () => {
    const db = adminDb();
    await seed(UID);

    await deleteChatHistoryData(db, UID);

    const usage = (await db.doc(`users/${UID}/meta/usage`).get()).data();
    expect(usage).toEqual({ dayKey: '2026-11-08', chatCountDay: 3, chatCountLifetime: 12 });
    expect((await db.collection(`users/${UID}/aiReports`).get()).size).toBe(1);
    expect((await db.doc(`users/${UID}`).get()).exists).toBe(true);
    expect((await db.collection(`users/${UID}/transactions`).get()).size).toBe(1);
  });

  it('no toca el historial de otro usuario', async () => {
    const db = adminDb();
    await seed(UID);
    await seed(OTHER);

    await deleteChatHistoryData(db, UID);

    expect((await db.collection(`users/${OTHER}/conversations`).get()).size).toBe(2);
    expect((await db.collection(`users/${OTHER}/conversations/c1/messages`).get()).size).toBe(2);
  });

  it('sin historial no falla', async () => {
    expect(await deleteChatHistoryData(adminDb(), 'sin-nada')).toEqual([]);
  });
});

describe('checkDeleteChatHistoryCaller (sesión y App Check)', () => {
  it('sin sesión se rechaza', () => {
    expect(() => checkDeleteChatHistoryCaller({ auth: null, app: {} }, false)).toThrow(
      expect.objectContaining({ code: 'unauthenticated' }),
    );
  });

  it('con App Check exigido, una llamada sin token se rechaza', () => {
    expect(() => checkDeleteChatHistoryCaller({ auth: { uid: UID }, app: undefined }, true)).toThrow(
      expect.objectContaining({ code: 'unauthenticated', message: expect.stringContaining('App Check') }),
    );
  });

  it('con App Check exigido y token, pasa y devuelve el uid', () => {
    expect(checkDeleteChatHistoryCaller({ auth: { uid: UID }, app: {} }, true)).toBe(UID);
  });

  it('con App Check apagado, una llamada sin token pasa', () => {
    expect(checkDeleteChatHistoryCaller({ auth: { uid: UID }, app: undefined }, false)).toBe(UID);
  });
});
