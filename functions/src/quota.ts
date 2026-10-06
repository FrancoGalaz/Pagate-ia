/**
 * Cuotas del asistente de IA: reserva, devolución y tope global.
 *
 * Está separado de `chat.ts` para poder probarlo contra el emulador sin montar
 * una llamada `onCall` completa.
 *
 * ---------------------------------------------------------------------------
 * POR QUÉ LA CUOTA DEL PLAN FREE ES DE POR VIDA Y NO DIARIA
 * ---------------------------------------------------------------------------
 * La versión anterior daba 30 mensajes DIARIOS al plan free. Como el registro
 * es abierto (correo y contraseña, sin verificación obligatoria), cada cuenta
 * nueva era un grifo que se reabría cada día: 30 llamadas diarias por cuenta,
 * multiplicadas por tantas cuentas como alguien quisiera crear, y todas
 * facturadas al dueño. Un límite diario solo acota el caudal por cuenta; no
 * acota el total.
 *
 * Ahora:
 *   - plan `free`: 25 mensajes DE POR VIDA (campo `chatCountLifetime`). Crear
 *     otra cuenta sigue siendo posible, pero ya no reabre el grifo: cuesta
 *     registrarse otra vez por cada 25 mensajes.
 *   - plan `pro`: se mantiene la cuota DIARIA de 300 mensajes, porque ahí hay
 *     un pago detrás que cubre el consumo.
 *   - tope GLOBAL diario de llamadas con interruptor, en `system/aiConfig`, que
 *     el dueño puede cambiar desde la consola de Firestore sin desplegar nada.
 *     Es el freno de mano: si algo se descontrola, se corta todo el gasto de IA
 *     editando un documento.
 *
 * ---------------------------------------------------------------------------
 * QUÉ CUESTA CADA LLAMADA AL ASISTENTE
 * ---------------------------------------------------------------------------
 * Por mensaje enviado por el usuario, el dueño paga:
 *   - 1 invocación de Cloud Functions (`chat`, 256 MiB, hasta 60 s).
 *   - Firestore: ~6 lecturas de documento + 3 consultas (últimas 10
 *     transacciones, 2 `count()` de inventario, últimos mensajes) y ~5
 *     escrituras (mensaje del usuario, respuesta, conversación, `meta/usage`,
 *     contador global).
 *   - OpenRouter: tokens de entrada = system prompt (tope duro de
 *     `MAX_PROMPT_CHARS` = 12.000 caracteres) + hasta `HISTORY_LIMIT` = 6
 *     mensajes de hasta `MAX_MESSAGE_CHARS` = 2.000 caracteres cada uno. En el
 *     peor caso son ~24.000 caracteres de entrada, que a razón aproximada de 4
 *     caracteres por token son del orden de 6.000 tokens de entrada, más hasta
 *     1.024 tokens de salida (`maxTokens`).
 *
 * El precio en dinero de esos tokens depende del modelo que esté en
 * `OPENROUTER_MODEL` y lo fija OpenRouter, así que no se escribe aquí ninguna
 * cifra inventada: `chat.ts` registra en Cloud Logging los tokens REALES de
 * cada llamada (`chat.usage`) para que el dueño los multiplique por la tarifa
 * vigente de su modelo.
 *
 * El recorte de `HISTORY_LIMIT` de 20 a 6 es el ajuste de coste más grande de
 * este cambio: el historial se reenvía completo en cada mensaje, así que su
 * tamaño multiplica los tokens de entrada de toda la conversación.
 */

import { HttpsError } from 'firebase-functions/v2/https';
import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { FieldValue } from 'firebase-admin/firestore';

export type Plan = 'free' | 'pro';

/** Mensajes totales (no diarios) que incluye el plan free. */
export const FREE_LIFETIME_QUOTA = 25;

/** Mensajes diarios del plan pro. */
export const PRO_DAILY_QUOTA = 300;

/** Tope global de llamadas al día cuando el interruptor está activo. */
export const DEFAULT_GLOBAL_DAILY_CAP = 2_000;

/**
 * Zona horaria con la que se calcula el día de la cuota. En UTC, un usuario en
 * Chile veía reiniciarse su cuota a las 20:00 o 21:00 hora local, es decir a
 * media tarde.
 */
export const QUOTA_TIME_ZONE = 'America/Santiago';

/** Documento de configuración que el dueño edita a mano, sin desplegar. */
export const AI_CONFIG_DOC = 'system/aiConfig';

/** Contador global por día: `system/aiUsage/days/{yyyy-MM-dd}`. */
export const AI_USAGE_DOC = 'system/aiUsage';
export const AI_USAGE_DAYS = 'days';

/** Clave del día ('yyyy-MM-dd') en la zona horaria de la cuota. */
export function dayKeyOf(date: Date = new Date()): string {
  // 'en-CA' formatea como yyyy-MM-dd, que es exactamente la clave que queremos.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: QUOTA_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

/** Límites efectivos, tras aplicar `system/aiConfig` sobre los valores base. */
export interface AiLimits {
  freeLifetimeQuota: number;
  proDailyQuota: number;
  globalDailyCapEnabled: boolean;
  globalDailyCap: number;
}

function positiveInt(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.floor(value) : fallback;
}

/**
 * Interpreta `system/aiConfig`. Cualquier campo ausente o malformado cae al
 * valor por defecto, para que un documento a medio editar no deje el asistente
 * sin límites ni lo bloquee por accidente.
 */
export function parseAiLimits(data: DocumentData | undefined): AiLimits {
  return {
    freeLifetimeQuota: positiveInt(data?.freeLifetimeQuota, FREE_LIFETIME_QUOTA),
    proDailyQuota: positiveInt(data?.proDailyQuota, PRO_DAILY_QUOTA),
    globalDailyCapEnabled: data?.globalDailyCapEnabled === true,
    globalDailyCap: positiveInt(data?.globalDailyCap, DEFAULT_GLOBAL_DAILY_CAP),
  };
}

export function planOf(profile: DocumentData | undefined): Plan {
  return profile?.plan === 'pro' ? 'pro' : 'free';
}

export interface QuotaReservation {
  /** Perfil leído dentro de la transacción (evita una lectura extra). */
  profile: DocumentData | undefined;
  plan: Plan;
  dayKey: string;
  /** Mensajes consumidos tras esta reserva, por si se quiere mostrar. */
  usedLifetime: number;
  usedDay: number;
  limits: AiLimits;
}

/**
 * Reserva un mensaje de cuota de forma atómica.
 *
 * Reserva primero y cobra después: si OpenRouter falla, `refundChatQuota`
 * devuelve el mensaje. Hacerlo al revés (llamar al modelo y después cobrar)
 * dejaría la puerta abierta a lanzar llamadas en paralelo sin límite.
 *
 * @throws HttpsError('resource-exhausted') si no queda cuota.
 */
export async function reserveChatQuota(
  db: Firestore,
  uid: string,
  now: Date = new Date(),
): Promise<QuotaReservation> {
  const dayKey = dayKeyOf(now);
  const userRef = db.doc(`users/${uid}`);
  const usageRef = db.doc(`users/${uid}/meta/usage`);
  const configRef = db.doc(AI_CONFIG_DOC);
  const globalRef = db.doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(dayKey);

  return db.runTransaction(async (tx) => {
    const [userSnap, usageSnap, configSnap, globalSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(usageRef),
      tx.get(configRef),
      tx.get(globalRef),
    ]);

    const profile = userSnap.data();
    const plan = planOf(profile);
    const limits = parseAiLimits(configSnap.data());
    const usage = usageSnap.data();

    // El contador diario solo vale si corresponde al día en curso.
    const usedDay =
      usage?.dayKey === dayKey && typeof usage.chatCountDay === 'number' && usage.chatCountDay > 0
        ? Math.floor(usage.chatCountDay)
        : 0;
    const usedLifetime =
      typeof usage?.chatCountLifetime === 'number' && usage.chatCountLifetime > 0
        ? Math.floor(usage.chatCountLifetime)
        : 0;
    const globalCalls = typeof globalSnap.data()?.calls === 'number' ? Math.floor(globalSnap.data()!.calls) : 0;

    // Freno de mano del dueño: se evalúa antes de la cuota del usuario para que
    // el mensaje de error diga la verdad sobre qué límite se alcanzó.
    if (limits.globalDailyCapEnabled && globalCalls >= limits.globalDailyCap) {
      throw new HttpsError(
        'resource-exhausted',
        'El asistente está temporalmente fuera de servicio por alcanzar el tope de uso del día. Intenta mañana.',
      );
    }

    if (plan === 'free' && usedLifetime >= limits.freeLifetimeQuota) {
      throw new HttpsError(
        'resource-exhausted',
        `Usaste los ${limits.freeLifetimeQuota} mensajes incluidos en el plan gratuito. Cambia a Pro para seguir conversando con el asistente.`,
      );
    }
    if (plan === 'pro' && usedDay >= limits.proDailyQuota) {
      throw new HttpsError(
        'resource-exhausted',
        `Alcanzaste el límite de ${limits.proDailyQuota} mensajes del día. Vuelve mañana.`,
      );
    }

    // Ambos contadores suben siempre: el diario sirve al plan pro y el de por
    // vida al free, y mantenerlos los dos al día evita sorpresas si el usuario
    // cambia de plan.
    //
    // `{ merge: true }` no es opcional. `meta/usage` es el único documento de
    // `meta/` y mañana puede llevar más campos (marca del último uso, consumo de
    // tokens, avisos ya mostrados). Un `set` sin merge BORRA todo lo que no esté
    // en este objeto, así que cada mensaje del asistente se llevaría por delante
    // cualquier otro campo del documento. `refundChatQuota` ya escribía con
    // merge: la diferencia entre las dos escrituras del mismo documento era el
    // olvido, no una decisión.
    tx.set(
      usageRef,
      { dayKey, chatCountDay: usedDay + 1, chatCountLifetime: usedLifetime + 1 },
      { merge: true },
    );
    tx.set(
      globalRef,
      { calls: globalCalls + 1, dayKey, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );

    return { profile, plan, dayKey, usedLifetime: usedLifetime + 1, usedDay: usedDay + 1, limits };
  });
}

/**
 * Devuelve el mensaje reservado cuando la llamada falla por algo que no es
 * culpa del usuario (OpenRouter caído, timeout). Sin esto, un fallo del
 * proveedor le gastaba cuota igual.
 *
 * Nunca lanza: si la devolución falla, el error se registra arriba y la
 * respuesta al usuario sigue siendo la del fallo original.
 */
export async function refundChatQuota(db: Firestore, uid: string, dayKey: string): Promise<void> {
  const usageRef = db.doc(`users/${uid}/meta/usage`);
  const globalRef = db.doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(dayKey);

  await db.runTransaction(async (tx) => {
    const [usageSnap, globalSnap] = await Promise.all([tx.get(usageRef), tx.get(globalRef)]);
    const usage = usageSnap.data();
    if (usage) {
      const day = typeof usage.chatCountDay === 'number' ? Math.floor(usage.chatCountDay) : 0;
      const lifetime = typeof usage.chatCountLifetime === 'number' ? Math.floor(usage.chatCountLifetime) : 0;
      tx.set(
        usageRef,
        {
          // Solo se descuenta del día si el contador sigue siendo del mismo día.
          chatCountDay: usage.dayKey === dayKey ? Math.max(0, day - 1) : day,
          chatCountLifetime: Math.max(0, lifetime - 1),
        },
        { merge: true },
      );
    }
    const calls = typeof globalSnap.data()?.calls === 'number' ? Math.floor(globalSnap.data()!.calls) : 0;
    if (calls > 0) {
      tx.set(globalRef, { calls: calls - 1 }, { merge: true });
    }
  });
}
