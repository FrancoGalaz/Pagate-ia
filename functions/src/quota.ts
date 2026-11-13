/**
 * Cuotas de la IA: reserva, devolución y tope global.
 *
 * Hay DOS cuotas independientes y dos gastos distintos:
 *   - el asistente (`chat`), contadores `chatCountLifetime` / `chatCountDay`;
 *   - el lector de boletas (`scanReceipt`), contadores `scanCountLifetime` /
 *     `scanCountDay`.
 *
 * Son separadas a propósito: leer tres boletas no puede dejar a nadie sin
 * asistente, ni al revés. Lo único que comparten es el tope GLOBAL del día, que
 * es el freno de gasto del dueño y por tanto tiene que frenar TODO el gasto.
 *
 * Está separado de `chat.ts` y de `scan.ts` para poder probarlo contra el
 * emulador sin montar una llamada `onCall` completa.
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
 *   - plan `pro`: cuota DIARIA de 300 mensajes. OJO con lo que `pro` es HOY: un
 *     valor del campo `plan` que solo escribe el backend, o el dueño a mano en
 *     la consola. NO se puede comprar: el proyecto no tiene `in_app_purchase`
 *     ni ninguna integración de facturación. Sirve para que el dueño abra la
 *     mano con una cuenta concreta, no es un producto. Por eso ningún texto que
 *     lea el usuario lo ofrece (ver `freeQuotaExhaustedMessage`).
 *   - lector de boletas: 40 lecturas DE POR VIDA en free
 *     (`scanCountLifetime`) y 200 al día en pro (`scanCountDay`), con el mismo
 *     razonamiento. Agotarlas no rompe la función: el teléfono ya ordenó la
 *     lista sin conexión, así que solo se pierde la calidad del ordenado.
 *   - tope GLOBAL diario de llamadas con interruptor, en `system/aiConfig`, que
 *     el dueño puede cambiar desde la consola de Firestore sin desplegar nada.
 *     Es el freno de mano: si algo se descontrola, se corta todo el gasto de IA
 *     editando un documento. Cuenta `calls` (chat) MÁS `scanCalls` (lector),
 *     porque es el freno del gasto y el gasto es la suma de los dos.
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
 *
 * ---------------------------------------------------------------------------
 * QUÉ CUESTA CADA LECTURA DE BOLETA
 * ---------------------------------------------------------------------------
 * Por boleta leída, el dueño paga:
 *   - 1 invocación de Cloud Functions (`scanReceipt`, 256 MiB, hasta 60 s).
 *   - Firestore: 4 lecturas de documento (perfil, `meta/usage`, `aiConfig`,
 *     contador global) y 2 escrituras. Despreciable.
 *   - OpenRouter: el texto del OCR, con tope de `MAX_SCAN_TEXT_CHARS` = 8.000
 *     caracteres, más el prompt del lector; del orden de 2.400 tokens de
 *     entrada en el peor caso, y hasta `SCAN_MAX_TOKENS` = 1.500 de salida.
 *   - Y NADA de visión ni de almacenamiento: la imagen no sale del teléfono.
 *     El reconocimiento de texto corre en el dispositivo con ML Kit, gratis y
 *     sin conexión; a este backend solo llega el texto. Por eso no hay Firebase
 *     Storage en el proyecto.
 */

import { HttpsError } from 'firebase-functions/v2/https';
import type { DocumentData, Firestore } from 'firebase-admin/firestore';
import { FieldValue } from 'firebase-admin/firestore';

export type Plan = 'free' | 'pro';

/** Mensajes totales (no diarios) que incluye el plan free. */
export const FREE_LIFETIME_QUOTA = 25;

/** Mensajes diarios del plan pro. */
export const PRO_DAILY_QUOTA = 300;

/**
 * Lecturas de boleta que ordena el modelo, en total, en el plan free.
 *
 * ---------------------------------------------------------------------------
 * DE DÓNDE SALE EL 40, CON LA ARITMÉTICA A LA VISTA
 * ---------------------------------------------------------------------------
 * Una lectura manda al modelo el texto del OCR (tope `MAX_SCAN_TEXT_CHARS` =
 * 8.000 caracteres, del orden de 2.400 tokens contando el prompt) y recibe
 * hasta `SCAN_MAX_TOKENS` = 1.500 tokens de JSON. Es decir que el peor caso de
 * una lectura es del orden de la MITAD de tokens de entrada que el peor caso de
 * un mensaje del asistente (~6.000) y algo más de salida (1.500 contra 1.024).
 *
 * Con eso, 40 lecturas cuestan aproximadamente lo mismo que los 25 mensajes de
 * chat del plan free, y 40 boletas son varios meses de compras de un artesano
 * que se abastece cada semana.
 *
 * NO se escribe aquí ninguna tarifa en dinero: los precios de OpenRouter
 * cambian y una cifra fija en un comentario envejece mal. `scan.ts` registra en
 * Cloud Logging los tokens REALES de cada lectura (`scan.usage`) para que el
 * dueño los multiplique por la tarifa vigente de su modelo. Si quiere apretar,
 * `freeLifetimeScanQuota` de `system/aiConfig` lo cambia sin desplegar.
 *
 * Es DE POR VIDA y no diaria por el mismo motivo que la del chat: el registro
 * es abierto, así que una cuota diaria es un grifo que se reabre cada día por
 * cada cuenta nueva.
 *
 * Y agotarla NO rompe la función: el cliente ya tiene en pantalla la lista que
 * ordenó él solo en el teléfono, así que lo único que se pierde es la calidad
 * del ordenado. Por eso el cliente trata `resource-exhausted` del lector como
 * información y no como error.
 */
export const FREE_LIFETIME_SCAN_QUOTA = 40;

/** Lecturas de boleta diarias del plan pro. */
export const PRO_DAILY_SCAN_QUOTA = 200;

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
  /** Lecturas de boleta de por vida del plan free. */
  freeLifetimeScanQuota: number;
  /** Lecturas de boleta al día del plan pro. */
  proDailyScanQuota: number;
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
    freeLifetimeScanQuota: positiveInt(data?.freeLifetimeScanQuota, FREE_LIFETIME_SCAN_QUOTA),
    proDailyScanQuota: positiveInt(data?.proDailyScanQuota, PRO_DAILY_SCAN_QUOTA),
    globalDailyCapEnabled: data?.globalDailyCapEnabled === true,
    globalDailyCap: positiveInt(data?.globalDailyCap, DEFAULT_GLOBAL_DAILY_CAP),
  };
}

export function planOf(profile: DocumentData | undefined): Plan {
  return profile?.plan === 'pro' ? 'pro' : 'free';
}

/**
 * Lo que lee el usuario del plan free cuando se le acaban los mensajes.
 *
 * POR QUÉ CAMBIÓ. Decía «Usaste los 25 mensajes incluidos en el plan gratuito.
 * Cambia a Pro para seguir conversando con el asistente», y eso era falso y
 * además un problema de política:
 *
 *   1. NO HAY PLAN PRO QUE COMPRAR. En el proyecto no existe `in_app_purchase`
 *      ni ninguna integración de facturación: no hay ni un botón que lleve a
 *      pagar. Se le pedía al usuario una acción imposible.
 *   2. Anunciar dentro de la app un plan de pago que no pasa por la facturación
 *      de Google Play incumple su política de pagos. Un aviso así, con el plan
 *      sin implementar, es un motivo de rechazo gratuito.
 *   3. «incluidos en el plan gratuito» sugiere que hay otro plan con más
 *      mensajes disponible. No lo hay.
 *
 * El texto nuevo dice solo lo que es cierto: los mensajes eran un total, no una
 * cuota diaria, así que no se renuevan, y el resto de la app sigue funcionando.
 * No promete nada ni invita a comprar nada. El día que exista una compra real
 * dentro de la app, este es el sitio donde se menciona, y no antes.
 *
 * El número viene de `system/aiConfig` (el dueño puede cambiarlo sin
 * desplegar), así que la frase está escrita para ser correcta con cualquier
 * valor, incluido 1: por eso no lleva artículo delante del número.
 */
export function freeQuotaExhaustedMessage(quota: number): string {
  return (
    'Ya usaste todos los mensajes del asistente: tu cuenta incluye ' +
    `${quota} en total, no por día, así que no se renuevan mañana. ` +
    'El resto de la app sigue funcionando igual.'
  );
}

/**
 * Lo que lee el usuario del plan free cuando se le acaban las lecturas de
 * boleta.
 *
 * Mismas tres restricciones que `freeQuotaExhaustedMessage`, y por los mismos
 * motivos: no menciona ningún plan de pago (no existe ninguno que comprar, y
 * anunciarlo dentro de la app incumpliría la política de pagos de Google Play),
 * no manda a volver mañana (la cuota es un total, no se renueva) y está escrita
 * para leerse bien con cualquier número, incluido 1, porque el dueño lo cambia
 * desde `system/aiConfig` sin desplegar.
 *
 * Y dice la verdad sobre lo que PASA AHORA, que es lo que diferencia este texto
 * del del chat: la lectura no se perdió. El teléfono ya ordenó la lista él solo,
 * sin conexión y sin coste, y esa lista está en pantalla. Lo único que falta es
 * el repaso del modelo, que ordena mejor. Por eso el cliente muestra este
 * mensaje en una franja informativa y deja seguir, en vez de tratarlo como un
 * error que corta el flujo.
 */
export function freeScanQuotaExhaustedMessage(quota: number): string {
  return (
    'Ya usaste todas las lecturas de boleta que ordena la IA: tu cuenta incluye ' +
    `${quota} en total, no por día, así que no se renuevan mañana. ` +
    'Esta lista la ordenó tu teléfono, así que revísala con más cuidado antes de guardar.'
  );
}

export interface QuotaReservation {
  /** Perfil leído dentro de la transacción (evita una lectura extra). */
  profile: DocumentData | undefined;
  plan: Plan;
  dayKey: string;
  /** Unidades consumidas tras esta reserva, por si se quieren mostrar. */
  usedLifetime: number;
  usedDay: number;
  limits: AiLimits;
}

/**
 * Lo que distingue a las dos cuotas. Todo lo demás —la transacción, el orden de
 * las comprobaciones, el tope global y el cuidado con el cambio de día— es
 * idéntico y vive una sola vez, en `reserve` y `refund`.
 *
 * NO son dos funciones copiadas. La parte delicada es el manejo del cambio de
 * día (ver el comentario de `reserve`), y dos copias de eso se desincronizan.
 */
interface QuotaKind {
  /** Campo del contador diario en `users/{uid}/meta/usage`. */
  dayField: 'chatCountDay' | 'scanCountDay';
  /** Campo del contador de por vida en `users/{uid}/meta/usage`. */
  lifetimeField: 'chatCountLifetime' | 'scanCountLifetime';
  /** El contador diario de LA OTRA cuota, que comparte `dayKey` con esta. */
  otherDayField: 'chatCountDay' | 'scanCountDay';
  /** Campo del contador global del día en `system/aiUsage/days/{dayKey}`. */
  globalField: 'calls' | 'scanCalls';
  freeLimitOf(limits: AiLimits): number;
  proLimitOf(limits: AiLimits): number;
  /** Mensaje del tope global del dueño. */
  globalCapMessage: string;
  freeExhaustedMessage(quota: number): string;
  proExhaustedMessage(quota: number): string;
}

const CHAT_QUOTA: QuotaKind = {
  dayField: 'chatCountDay',
  lifetimeField: 'chatCountLifetime',
  otherDayField: 'scanCountDay',
  globalField: 'calls',
  freeLimitOf: (l) => l.freeLifetimeQuota,
  proLimitOf: (l) => l.proDailyQuota,
  globalCapMessage:
    'El asistente está temporalmente fuera de servicio por alcanzar el tope de uso del día. Intenta mañana.',
  freeExhaustedMessage: freeQuotaExhaustedMessage,
  proExhaustedMessage: (q) => `Alcanzaste el límite de ${q} mensajes del día. Vuelve mañana.`,
};

const SCAN_QUOTA: QuotaKind = {
  dayField: 'scanCountDay',
  lifetimeField: 'scanCountLifetime',
  otherDayField: 'chatCountDay',
  globalField: 'scanCalls',
  freeLimitOf: (l) => l.freeLifetimeScanQuota,
  proLimitOf: (l) => l.proDailyScanQuota,
  // El tope global es el mismo freno para los dos gastos, pero el texto nombra
  // la función que el usuario acaba de usar: decirle que "el asistente" está
  // fuera de servicio cuando lo que hizo fue fotografiar una boleta no le
  // explica nada.
  globalCapMessage:
    'El lector de boletas está temporalmente fuera de servicio por alcanzar el tope de uso de IA del día. ' +
    'Esta lista la ordenó tu teléfono, así que revísala con más cuidado antes de guardar.',
  freeExhaustedMessage: freeScanQuotaExhaustedMessage,
  proExhaustedMessage: (q) => `Alcanzaste el límite de ${q} lecturas de boleta del día. Vuelve mañana.`,
};

function counterOf(data: DocumentData | undefined, field: string): number {
  const value = data?.[field];
  return typeof value === 'number' && value > 0 ? Math.floor(value) : 0;
}

/**
 * Gasto de IA del día en total: mensajes del asistente MÁS lecturas de boleta.
 *
 * El tope global es el freno de gasto del dueño, así que tiene que frenar todo
 * el gasto, no solo el del chat. Los dos campos se guardan por separado para
 * que el registro (y un mensaje de error) puedan decir cuál de las dos cosas se
 * disparó, pero el límite se evalúa sobre la suma.
 */
function globalTotalOf(data: DocumentData | undefined): number {
  return counterOf(data, 'calls') + counterOf(data, 'scanCalls');
}

/**
 * Reserva una unidad de cuota de forma atómica.
 *
 * Reserva primero y cobra después: si OpenRouter falla, el `refund` de la misma
 * cuota la devuelve. Hacerlo al revés (llamar al modelo y después cobrar)
 * dejaría la puerta abierta a lanzar llamadas en paralelo sin límite.
 *
 * ---------------------------------------------------------------------------
 * LA TRAMPA DEL `dayKey` COMPARTIDO
 * ---------------------------------------------------------------------------
 * `users/{uid}/meta/usage` tiene UN solo campo `dayKey`, y los dos contadores
 * diarios (`chatCountDay` y `scanCountDay`) se interpretan contra él: un
 * contador diario solo vale si `dayKey` es el día en curso.
 *
 * Eso significa que escribir `dayKey` por una de las dos cuotas AVALA también
 * el contador de la otra. Si al cambiar el día una lectura de boleta
 * escribiera `{ dayKey: hoy, scanCountDay: 1 }` sin tocar `chatCountDay`, el
 * `chatCountDay: 300` de AYER pasaría a leerse como el de HOY y un usuario pro
 * se quedaría sin asistente sin haber escrito un solo mensaje. Lo mismo al
 * revés.
 *
 * Por eso, cuando el día cambia, se reinician LOS DOS contadores diarios en la
 * misma escritura. Es la razón de que esto sea una función compartida y no dos
 * copias: en dos copias, este detalle se arregla en una y se olvida en la otra.
 *
 * @throws HttpsError('resource-exhausted') si no queda cuota.
 */
async function reserve(
  kind: QuotaKind,
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
    const sameDay = usage?.dayKey === dayKey;
    const usedDay = sameDay ? counterOf(usage, kind.dayField) : 0;
    const usedLifetime = counterOf(usage, kind.lifetimeField);
    const globalTotal = globalTotalOf(globalSnap.data());

    // Freno de mano del dueño: se evalúa antes de la cuota del usuario para que
    // el mensaje de error diga la verdad sobre qué límite se alcanzó.
    if (limits.globalDailyCapEnabled && globalTotal >= limits.globalDailyCap) {
      throw new HttpsError('resource-exhausted', kind.globalCapMessage);
    }

    if (plan === 'free' && usedLifetime >= kind.freeLimitOf(limits)) {
      throw new HttpsError('resource-exhausted', kind.freeExhaustedMessage(kind.freeLimitOf(limits)));
    }
    if (plan === 'pro' && usedDay >= kind.proLimitOf(limits)) {
      throw new HttpsError('resource-exhausted', kind.proExhaustedMessage(kind.proLimitOf(limits)));
    }

    // Ambos contadores de esta cuota suben siempre: el diario sirve al plan pro
    // y el de por vida al free, y mantenerlos los dos al día evita sorpresas si
    // el usuario cambia de plan.
    //
    // `{ merge: true }` no es opcional. `meta/usage` es el único documento de
    // `meta/` y ahora lleva más campos que nunca (los dos contadores del chat,
    // los dos del lector, la clave del día). Un `set` sin merge BORRA todo lo
    // que no esté en este objeto, así que cada llamada se llevaría por delante
    // los contadores de la otra cuota. `refund` ya escribía con merge: la
    // diferencia entre las dos escrituras del mismo documento era el olvido, no
    // una decisión.
    const update: Record<string, unknown> = {
      dayKey,
      [kind.dayField]: usedDay + 1,
      [kind.lifetimeField]: usedLifetime + 1,
    };
    // Había un contador de OTRO día y lo estamos avalando al escribir el
    // `dayKey` de hoy: se reinicia también el contador diario de la otra cuota.
    // Ver el comentario de cabecera.
    //
    // Solo si el documento EXISTÍA. Si no existe no hay contador viejo que
    // invalidar, y escribir un `0` en el campo de la otra cuota sería tocar un
    // campo que no es de esta función.
    if (usage !== undefined && !sameDay) update[kind.otherDayField] = 0;
    tx.set(usageRef, update, { merge: true });

    tx.set(
      globalRef,
      {
        [kind.globalField]: counterOf(globalSnap.data(), kind.globalField) + 1,
        dayKey,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { profile, plan, dayKey, usedLifetime: usedLifetime + 1, usedDay: usedDay + 1, limits };
  });
}

/**
 * Devuelve la unidad reservada cuando la llamada falla por algo que no es culpa
 * del usuario (OpenRouter caído, timeout). Sin esto, un fallo del proveedor le
 * gastaba cuota igual.
 *
 * Nunca lanza: si la devolución falla, el error se registra arriba y la
 * respuesta al usuario sigue siendo la del fallo original.
 */
async function refund(kind: QuotaKind, db: Firestore, uid: string, dayKey: string): Promise<void> {
  const usageRef = db.doc(`users/${uid}/meta/usage`);
  const globalRef = db.doc(AI_USAGE_DOC).collection(AI_USAGE_DAYS).doc(dayKey);

  await db.runTransaction(async (tx) => {
    const [usageSnap, globalSnap] = await Promise.all([tx.get(usageRef), tx.get(globalRef)]);
    const usage = usageSnap.data();
    if (usage) {
      const day = counterOf(usage, kind.dayField);
      const lifetime = counterOf(usage, kind.lifetimeField);
      tx.set(
        usageRef,
        {
          // Solo se descuenta del día si el contador sigue siendo del mismo día.
          [kind.dayField]: usage.dayKey === dayKey ? Math.max(0, day - 1) : day,
          [kind.lifetimeField]: Math.max(0, lifetime - 1),
        },
        { merge: true },
      );
    }
    const calls = counterOf(globalSnap.data(), kind.globalField);
    if (calls > 0) {
      tx.set(globalRef, { [kind.globalField]: calls - 1 }, { merge: true });
    }
  });
}

/** Reserva un mensaje del asistente. */
export function reserveChatQuota(db: Firestore, uid: string, now: Date = new Date()): Promise<QuotaReservation> {
  return reserve(CHAT_QUOTA, db, uid, now);
}

/** Devuelve un mensaje del asistente reservado que no se llegó a usar. */
export function refundChatQuota(db: Firestore, uid: string, dayKey: string): Promise<void> {
  return refund(CHAT_QUOTA, db, uid, dayKey);
}

/**
 * Reserva una lectura de boleta.
 *
 * Es una cuota aparte de la del chat, con sus propios contadores: leer tres
 * boletas no puede dejar al usuario sin asistente.
 */
export function reserveScanQuota(db: Firestore, uid: string, now: Date = new Date()): Promise<QuotaReservation> {
  return reserve(SCAN_QUOTA, db, uid, now);
}

/** Devuelve una lectura de boleta reservada que el modelo no llegó a ordenar. */
export function refundScanQuota(db: Firestore, uid: string, dayKey: string): Promise<void> {
  return refund(SCAN_QUOTA, db, uid, dayKey);
}
