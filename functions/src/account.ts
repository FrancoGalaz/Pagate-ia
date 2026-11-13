/**
 * Borrado de cuenta (P-07).
 *
 * Google Play exige, desde la política de eliminación de datos de 2023, que toda
 * app que permita crear una cuenta ofrezca dos caminos para borrarla: uno dentro
 * de la app y una URL pública accesible sin instalarla. Este archivo cubre el
 * lado servidor del primero: el callable `deleteAccount`.
 *
 * El borrado va en este orden, y el orden importa:
 *   1. primero los datos de Firestore (`users/{uid}` y todo su árbol),
 *   2. después el usuario de Authentication.
 * Al revés, si el paso de datos fallara, quedarían documentos huérfanos sin
 * ninguna sesión capaz de volver a pedir su borrado: inaccesibles y eternos.
 * En este orden, un fallo deja la cuenta viva y el usuario puede reintentar.
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { ENFORCE_APP_CHECK, REGION, callableCors } from './config';

export interface DeleteAccountResponse {
  ok: true;
  uid: string;
  /** `true` si también se borró el usuario de Authentication. */
  authDeleted: boolean;
  /** Momento en que terminó el borrado, en ISO 8601 UTC. */
  deletedAt: string;
}

/**
 * Antigüedad máxima del inicio de sesión que se considera "reciente". No se usa
 * para rechazar: se registra, para que el día que el dueño quiera endurecer el
 * flujo (pedir reautenticación antes de borrar) ya haya datos de cuántas
 * llamadas llegan con una sesión vieja.
 */
const RECENT_LOGIN_SECONDS = 5 * 60;

/**
 * Borra `users/{uid}` y todo su árbol de subcolecciones.
 *
 * `recursiveDelete` recorre `inventory`, `transactions`, `fixedExpenses`,
 * `months`, `meta` y `conversations/{id}/messages` sin que haya que enumerarlas:
 * descubre las subcolecciones en tiempo de ejecución, así que una colección
 * nueva queda cubierta sin tocar este archivo.
 *
 * Después verifica que no quedó nada. La verificación no es decorativa:
 * `recursiveDelete` usa un `BulkWriter` que reintenta por su cuenta y resuelve
 * sin lanzar aunque algún lote quede atrás, así que sin comprobarlo no se puede
 * afirmar que el borrado fue completo.
 *
 * @returns las rutas que quedaron con documentos (vacío si el borrado fue total).
 */
export async function deleteUserData(db: Firestore, uid: string): Promise<string[]> {
  const userRef = db.doc(`users/${uid}`);
  await db.recursiveDelete(userRef);

  const leftovers: string[] = [];
  if ((await userRef.get()).exists) leftovers.push(userRef.path);
  for (const col of await userRef.listCollections()) {
    const snap = await col.limit(1).get();
    if (!snap.empty) leftovers.push(col.path);
  }
  return leftovers;
}

/** Lo que `checkDeleteAccountCaller` necesita de la llamada. */
export interface DeleteAccountCaller {
  auth?: { uid: string } | null;
  app?: unknown;
}

/**
 * Comprueba sesión y App Check antes de borrar nada, y devuelve el `uid`.
 *
 * Recibe el interruptor como parámetro (y no lee `ENFORCE_APP_CHECK`) para que
 * los tests puedan probar los dos valores sin desplegar, igual que `chat` y
 * `scanReceipt`.
 */
export function checkDeleteAccountCaller(request: DeleteAccountCaller, enforceAppCheck: boolean): string {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión para eliminar tu cuenta.');
  }
  // App Check, igual que en `chat`. No es simetría decorativa: este callable es
  // DESTRUCTIVO e irreversible, así que es el que más interesa que solo se
  // pueda invocar desde la app de verdad. Sin esta comprobación, `chat` (que
  // solo gasta cuota) estaba mejor protegido que el borrado de la cuenta.
  // Se comprueba a mano, no con la opción `enforceAppCheck` del callable,
  // porque el parámetro `ENFORCE_APP_CHECK` se resuelve en despliegue y así
  // los callables comparten exactamente el mismo interruptor.
  if (enforceAppCheck && !request.app) {
    throw new HttpsError('unauthenticated', 'Se requiere una verificación válida de App Check.');
  }
  return request.auth.uid;
}

export const deleteAccount = onCall<void, Promise<DeleteAccountResponse>>(
  {
    region: REGION,
    memory: '256MiB',
    // El borrado recursivo de una cuenta con mucho historial puede tardar; 60 s
    // (el valor de `chat`) se queda corto.
    timeoutSeconds: 300,
    // Tope de gasto: un usuario borra su cuenta una vez, no hace falta escalar.
    maxInstances: 2,
    cors: callableCors(),
  },
  async (request) => {
    const uid = checkDeleteAccountCaller(request, ENFORCE_APP_CHECK.value());

    const authTime = request.auth?.token?.auth_time;
    const sessionAgeSeconds =
      typeof authTime === 'number' ? Math.max(0, Math.floor(Date.now() / 1000 - authTime)) : null;

    logger.info('deleteAccount.inicio', {
      uid,
      sessionAgeSeconds,
      recentLogin: sessionAgeSeconds !== null && sessionAgeSeconds <= RECENT_LOGIN_SECONDS,
    });

    const db = getFirestore();

    let leftovers: string[];
    try {
      leftovers = await deleteUserData(db, uid);
    } catch (err) {
      logger.error('deleteAccount.datos.error', { uid, error: String(err) });
      throw new HttpsError('internal', 'No se pudieron borrar tus datos. Intenta de nuevo en unos minutos.');
    }
    if (leftovers.length > 0) {
      logger.error('deleteAccount.datos.incompleto', { uid, leftovers });
      throw new HttpsError('internal', 'El borrado quedó incompleto. Intenta de nuevo en unos minutos.');
    }

    // Los datos ya no están. Si el borrado en Authentication falla, se informa,
    // pero no se revierte nada: la cuenta queda sin datos y el usuario puede
    // reintentar para que desaparezca también la credencial.
    let authDeleted = false;
    try {
      await getAuth().deleteUser(uid);
      authDeleted = true;
    } catch (err) {
      const code = (err as { code?: string } | null)?.code;
      if (code === 'auth/user-not-found') {
        // Ya no existía (doble llamada, o borrado desde consola): es el estado
        // final que se quería, no un error.
        authDeleted = true;
      } else {
        logger.error('deleteAccount.auth.error', { uid, error: String(err) });
        throw new HttpsError(
          'internal',
          'Tus datos se borraron, pero no se pudo cerrar la cuenta. Intenta de nuevo en unos minutos.',
        );
      }
    }

    const deletedAt = new Date().toISOString();
    logger.info('deleteAccount.fin', { uid, authDeleted, deletedAt });
    return { ok: true, uid, authDeleted, deletedAt };
  },
);
