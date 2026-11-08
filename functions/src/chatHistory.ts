/**
 * Borrado del historial del asistente: el callable `deleteChatHistory`.
 *
 * Borra `users/{uid}/conversations` y sus `messages`. No toca nada más:
 *   - `meta/usage` se queda: ahí vive `chatCountLifetime`, el tope de por vida
 *     del plan free. Si se reiniciara con el historial, borrarlo sería una
 *     forma de tener mensajes gratis sin fin.
 *   - `aiReports` se queda: los reportes de respuestas se conservan para
 *     mejorar la calidad hasta que se elimina la cuenta (`deleteAccount`).
 *
 * Va por callable porque las reglas niegan toda escritura del cliente en
 * `conversations/**`.
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { ENFORCE_APP_CHECK, REGION, callableCors } from './config';

export interface DeleteChatHistoryResponse {
  ok: true;
  /** Momento en que terminó el borrado, en ISO 8601 UTC. */
  deletedAt: string;
}

/**
 * Borra `users/{uid}/conversations` con todo su árbol.
 *
 * @returns las rutas que quedaron con documentos (vacío si el borrado fue total).
 */
export async function deleteChatHistoryData(db: Firestore, uid: string): Promise<string[]> {
  const conversations = db.collection(`users/${uid}/conversations`);
  await db.recursiveDelete(conversations);

  // `listDocuments` incluye las conversaciones sin documento que aún tienen
  // mensajes colgando: así no se escapa un `messages` huérfano.
  const leftovers: string[] = [];
  for (const conv of await conversations.listDocuments()) {
    if ((await conv.get()).exists) leftovers.push(conv.path);
    for (const col of await conv.listCollections()) {
      if (!(await col.limit(1).get()).empty) leftovers.push(col.path);
    }
  }
  return leftovers;
}

/** Lo que `checkDeleteChatHistoryCaller` necesita de la llamada. */
export interface DeleteChatHistoryCaller {
  auth?: { uid: string } | null;
  app?: unknown;
}

/** Sesión y App Check, igual que `deleteAccount`. Devuelve el `uid`. */
export function checkDeleteChatHistoryCaller(
  request: DeleteChatHistoryCaller,
  enforceAppCheck: boolean,
): string {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión para borrar tu historial.');
  }
  if (enforceAppCheck && !request.app) {
    throw new HttpsError('unauthenticated', 'Se requiere una verificación válida de App Check.');
  }
  return request.auth.uid;
}

export const deleteChatHistory = onCall<void, Promise<DeleteChatHistoryResponse>>(
  {
    region: REGION,
    memory: '256MiB',
    timeoutSeconds: 120,
    maxInstances: 2,
    cors: callableCors(),
  },
  async (request) => {
    const uid = checkDeleteChatHistoryCaller(request, ENFORCE_APP_CHECK.value());

    let leftovers: string[];
    try {
      leftovers = await deleteChatHistoryData(getFirestore(), uid);
    } catch (err) {
      logger.error('deleteChatHistory.error', { uid, error: String(err) });
      throw new HttpsError('internal', 'No se pudo borrar tu historial. Intenta de nuevo en unos minutos.');
    }
    if (leftovers.length > 0) {
      logger.error('deleteChatHistory.incompleto', { uid, leftovers });
      throw new HttpsError('internal', 'El borrado quedó incompleto. Intenta de nuevo en unos minutos.');
    }

    const deletedAt = new Date().toISOString();
    logger.info('deleteChatHistory.fin', { uid, deletedAt });
    return { ok: true, deletedAt };
  },
);
