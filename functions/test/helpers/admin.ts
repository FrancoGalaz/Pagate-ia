/**
 * Ayudas para los tests que usan el Admin SDK contra el emulador de Firestore.
 *
 * El emulador lo levanta `npm test` (firebase emulators:exec), que exporta
 * `FIRESTORE_EMULATOR_HOST`; sin esa variable el Admin SDK intentaría hablar con
 * Firestore de verdad, así que se falla rápido y con un mensaje claro.
 */

import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

export const TEST_PROJECT_ID = 'demo-pagate';

export function adminDb(): Firestore {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST no está definido. Estos tests necesitan el emulador: usa `npm --prefix functions test`.',
    );
  }
  if (getApps().length === 0) {
    initializeApp({ projectId: TEST_PROJECT_ID });
  }
  return getFirestore();
}

/** Deja el árbol de un usuario vacío entre tests. */
export async function wipeUser(db: Firestore, uid: string): Promise<void> {
  await db.recursiveDelete(db.doc(`users/${uid}`));
}

/** Deja la configuración y los contadores globales del asistente vacíos. */
export async function wipeAiSystem(db: Firestore): Promise<void> {
  await db.recursiveDelete(db.doc('system/aiConfig'));
  await db.recursiveDelete(db.doc('system/aiUsage'));
}
