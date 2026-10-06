/**
 * Callable `chat`: el asistente financiero.
 *
 * Orden del flujo y por qué: se reserva cuota ANTES de llamar al modelo (si no,
 * se podrían lanzar llamadas en paralelo sin tope) y se deshace todo lo escrito
 * si el modelo falla (si no, un fallo de OpenRouter le cobraba cuota al usuario
 * y dejaba un mensaje suelto con `messageCount` desincronizado).
 *
 * Las cuotas, el tope global y el detalle de qué cuesta cada llamada están en
 * `quota.ts`.
 *
 * La lógica vive en `handleChat`, con sus dependencias (Firestore, la llamada al
 * modelo, la clave, el modelo y el reloj) inyectadas, y `chat` es solo la
 * envoltura `onCall` que las resuelve. No es arquitectura decorativa: sin esa
 * separación la función insignia no se podía probar sin una clave de OpenRouter
 * ni sin salir a la red, y así estuvo MUERTA con los tests en verde (el por qué
 * está en `test/chat.test.ts`).
 */

import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions/v2';
import {
  FieldPath,
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentData,
  type DocumentReference,
  type Firestore,
  type QueryDocumentSnapshot,
} from 'firebase-admin/firestore';
import { ENFORCE_APP_CHECK, OPENROUTER_API_KEY, OPENROUTER_MODEL, REGION, callableCors } from './config';
import { askOpenRouter, type ChatMessage, type OpenRouterResult } from './openrouter';
import {
  buildSystemPrompt,
  type DocType,
  type InventoryCounts,
  type MonthContext,
  type Plan,
  type ProfileContext,
  type TransactionContext,
} from './prompt';
import { dayKeyOf, planOf, refundChatQuota, reserveChatQuota } from './quota';

export const MAX_MESSAGE_CHARS = 2000;

/**
 * Mensajes de la conversación que se reenvían al modelo en cada turno.
 *
 * Era 20. El historial viaja completo en cada llamada, así que este número
 * multiplica los tokens de entrada de toda la conversación: con 20, el mensaje
 * número 20 pagaba otra vez por los 19 anteriores. Con 6 el asistente conserva
 * el hilo inmediato (tres intercambios) y el coste por mensaje deja de crecer
 * con la longitud de la conversación.
 */
export const HISTORY_LIMIT = 6;

export const RECENT_TRANSACTIONS_LIMIT = 10;
const OPENROUTER_TIMEOUT_MS = 30_000;
const CONVERSATION_ID_RE = /^[A-Za-z0-9_-]{1,128}$/;
const TITLE_MAX = 60;

export interface ChatRequest {
  conversationId?: string;
  message: string;
}

export interface ChatResponse {
  conversationId: string;
  reply: string;
}

// Reexportado para no romper a quien ya lo importaba desde aquí; la
// implementación vive en quota.ts, que es donde está la zona horaria.
export { dayKeyOf };

/**
 * Lo único que la llamada necesita del `CallableRequest` de Cloud Functions.
 *
 * Es un subconjunto estructural a propósito: el `CallableRequest` real encaja
 * aquí sin conversiones, y un test puede construir una llamada con un objeto
 * plano, sin montar un token de Authentication ni uno de App Check.
 */
export interface ChatCall {
  auth?: { uid: string } | null;
  app?: unknown;
  data: unknown;
}

/** Dependencias de `handleChat`. Todas inyectables para poder probarlo. */
export interface ChatDeps {
  db: Firestore;
  /**
   * Llamada al modelo. En los tests se sustituye por un doble, así que el flujo
   * se ejercita completo sin salir a la red ni gastar tokens.
   */
  ask: (opts: {
    apiKey: string;
    model: string;
    messages: ChatMessage[];
    timeoutMs?: number;
  }) => Promise<OpenRouterResult>;
  apiKey: string;
  model: string;
  /** Si hay que exigir App Check (en producción, el parámetro `ENFORCE_APP_CHECK`). */
  enforceAppCheck: boolean;
  /** Reloj. Fija el mes en curso y el día de la cuota; por defecto, ahora. */
  now?: Date;
}

function parseInput(data: unknown): { message: string; conversationId?: string } {
  if (typeof data !== 'object' || data === null) {
    throw new HttpsError('invalid-argument', 'Se esperaba un objeto con el campo message.');
  }
  const { message, conversationId } = data as Record<string, unknown>;

  if (typeof message !== 'string') {
    throw new HttpsError('invalid-argument', 'El campo message debe ser un texto.');
  }
  const trimmed = message.trim();
  if (trimmed.length === 0) {
    throw new HttpsError('invalid-argument', 'El mensaje no puede estar vacío.');
  }
  if (trimmed.length > MAX_MESSAGE_CHARS) {
    throw new HttpsError('invalid-argument', `El mensaje supera los ${MAX_MESSAGE_CHARS} caracteres.`);
  }

  if (conversationId !== undefined && conversationId !== null) {
    if (typeof conversationId !== 'string' || !CONVERSATION_ID_RE.test(conversationId)) {
      throw new HttpsError('invalid-argument', 'conversationId inválido.');
    }
    return { message: trimmed, conversationId };
  }
  return { message: trimmed };
}

function toProfileContext(data: DocumentData | undefined): ProfileContext | null {
  if (!data) return null;
  const rate = data.hourlyRate;
  return {
    name: typeof data.name === 'string' ? data.name : undefined,
    businessName: typeof data.businessName === 'string' ? data.businessName : undefined,
    businessType: typeof data.businessType === 'string' ? data.businessType : undefined,
    currency: typeof data.currency === 'string' ? data.currency : undefined,
    monthlyGoal: typeof data.monthlyGoal === 'number' ? data.monthlyGoal : undefined,
    plan: planOf(data) as Plan,
    hourlyRate:
      typeof rate === 'object' && rate !== null
        ? {
            desiredMonthlySalary: typeof rate.desiredMonthlySalary === 'number' ? rate.desiredMonthlySalary : undefined,
            availableHoursPerMonth:
              typeof rate.availableHoursPerMonth === 'number' ? rate.availableHoursPerMonth : undefined,
            hourlyValue: typeof rate.hourlyValue === 'number' ? rate.hourlyValue : undefined,
          }
        : null,
  };
}

/**
 * Lo único que `toMonthContext` necesita de un documento de `months/*`.
 *
 * Hace falta porque el documento puede llegar de una lectura por id
 * (`DocumentSnapshot`) o del recorrido de la colección
 * (`QueryDocumentSnapshot`), y `latestMonthDoc` usa los dos caminos.
 */
export interface MonthDoc {
  id: string;
  data(): DocumentData | undefined;
}

/**
 * El mes más reciente CON MOVIMIENTOS de `users/{uid}/months`.
 *
 * ---------------------------------------------------------------------------
 * POR QUÉ NO ES UNA SOLA CONSULTA DESCENDENTE
 * ---------------------------------------------------------------------------
 * Aquí había esto, y mataba TODAS las llamadas al asistente:
 *
 *     months.orderBy(FieldPath.documentId(), 'desc').limit(1).get()
 *
 * Los ids de `months/*` son `yyyy-MM`, que ordena cronológicamente, así que
 * pedir el id más alto parece la forma natural de pedir "el último mes".
 * Firestore no lo admite. Comprobado contra el emulador, con tres meses
 * sembrados, la consulta vuelve con:
 *
 *     9 FAILED_PRECONDITION: Firestore does not support descending key scans
 *
 * Y como estaba dentro del `Promise.all` que arma el contexto del prompt, no
 * había camino que la esquivara: MORÍA toda llamada al asistente y el usuario
 * leía "Ocurrió un error con el asistente" en cada mensaje. El cliente ya se
 * había topado con lo mismo en `finances_firebase_datasource.dart`.
 *
 * Alternativas descartadas, y por qué:
 *
 *   - `orderBy(documentId()).limitToLast(1)`: lanza EXACTAMENTE el mismo error.
 *     `limitToLast` invierte el orden de la consulta que viaja al servidor, así
 *     que por debajo vuelve a ser un escaneo de claves descendente. Verificado
 *     contra el emulador, no supuesto.
 *   - `orderBy('updatedAt', 'desc').limit(1)`: Firestore sí lo admite, porque es
 *     un campo normal y no la clave, pero responde a otra pregunta. `updatedAt`
 *     es cuándo se RECALCULÓ el mes, no de qué mes se trata: basta con corregir
 *     hoy una transacción de marzo de 2024 para que ese mes pase a ser el más
 *     "reciente" y el asistente hable de él como si fuera el mes en curso.
 *   - Guardar el `monthKey` como campo del documento y ordenar por él
 *     descendente: sería correcto y de una sola lectura, pero `orderBy` sobre un
 *     campo EXCLUYE los documentos que no lo tienen, así que todos los
 *     `months/*` escritos antes del cambio quedarían invisibles y el asistente
 *     diría "no hay meses con movimientos" teniendo los datos delante, hasta que
 *     alguien volviera a tocar una transacción de cada mes. Un dato que
 *     desaparece en silencio es peor que una lectura de más.
 *
 * ---------------------------------------------------------------------------
 * LO QUE SE HACE
 * ---------------------------------------------------------------------------
 *   1. Lectura directa de `months/{mes en curso}`: una lectura de documento por
 *      id, sin consulta, sin orden y sin índice. Es el caso normal (alguien que
 *      registró algo este mes) y de aquí no se pasa.
 *   2. Si ese documento no existe, se recorre la colección ASCENDENTE (el único
 *      orden por clave que Firestore permite) y se toma el ÚLTIMO. Cuesta tantas
 *      lecturas como meses con movimientos tenga la cuenta, y se paga solo en el
 *      caso que lo necesita: el mes tranquilo, la temporada baja, el usuario que
 *      vuelve. `months.ts` BORRA los meses que se quedan sin movimientos, así
 *      que no hay documentos en cero inflando ese recorrido.
 *
 * Devuelve `undefined` si la cuenta no tiene ningún mes con movimientos, que es
 * el caso que `prompt.ts` traduce a "No hay meses con movimientos registrados
 * todavía".
 */
export async function latestMonthDoc(
  userRef: DocumentReference,
  now: Date = new Date(),
): Promise<MonthDoc | undefined> {
  const months = userRef.collection('months');

  const current = await months.doc(currentMonthKey(now)).get();
  if (current.exists) return current;

  const all = await months.orderBy(FieldPath.documentId()).get();
  return all.docs.at(-1);
}

/**
 * Clave `yyyy-MM` del mes en curso.
 *
 * Se deriva de `dayKeyOf` para heredar la zona horaria de la cuota
 * (`America/Santiago`) en vez de declarar otra: en UTC, a fin de mes, el mes en
 * curso habría cambiado varias horas antes para un usuario en Chile. Un
 * desajuste de zona en el límite del mes no produce un dato falso, solo hace que
 * `latestMonthDoc` caiga al recorrido ascendente, que responde lo mismo.
 */
export function currentMonthKey(now: Date = new Date()): string {
  return dayKeyOf(now).slice(0, 7);
}

function toMonthContext(doc: MonthDoc | undefined): MonthContext | null {
  if (!doc) return null;
  const d = doc.data() ?? {};
  return {
    monthKey: doc.id,
    totalIncome: typeof d.totalIncome === 'number' ? d.totalIncome : 0,
    totalExpenses: typeof d.totalExpenses === 'number' ? d.totalExpenses : 0,
    // Ausente en los `months/*` escritos antes del contrato C-3: se lee como 0,
    // y entonces el neto del mes coincide con el bruto, que es la verdad para un
    // mes en el que no se registró ninguna comisión.
    totalPlatformFees: typeof d.totalPlatformFees === 'number' ? d.totalPlatformFees : 0,
    transactionCount: typeof d.transactionCount === 'number' ? d.transactionCount : 0,
  };
}

/** Valores de `docType` que admite el contrato C-3. */
const DOC_TYPES: readonly string[] = ['boleta_venta', 'boleta_honorarios', 'sin_documento'];

/**
 * Valida `docType` contra el conjunto cerrado en vez de pasar el texto tal cual.
 * Un `docType` escrito por el Admin SDK no pasa por `firestore.rules`, y de aquí
 * sale directo al prompt del asistente.
 */
function toDocType(value: unknown): DocType | undefined {
  return typeof value === 'string' && DOC_TYPES.includes(value) ? (value as DocType) : undefined;
}

function toTransactionContext(doc: QueryDocumentSnapshot): TransactionContext {
  const d = doc.data();
  const type = d.type === 'expense' ? 'expense' : 'income';
  return {
    title: typeof d.title === 'string' ? d.title : '',
    amount: typeof d.amount === 'number' ? d.amount : 0,
    type,
    category: typeof d.category === 'string' ? d.category : '',
    date: d.date instanceof Timestamp ? d.date.toDate() : null,
    // Los dos campos del contrato C-3, y solo en los ingresos: en un gasto el
    // contrato no los acepta, así que ni se leen.
    docType: type === 'income' ? toDocType(d.docType) : undefined,
    platformFee: type === 'income' && typeof d.platformFee === 'number' ? d.platformFee : undefined,
  };
}

function toHistory(docs: QueryDocumentSnapshot[]): Array<ChatMessage & { id: string }> {
  return docs
    .slice()
    .reverse()
    .filter((doc) => {
      const d = doc.data();
      return (d.role === 'user' || d.role === 'assistant') && typeof d.text === 'string';
    })
    .map((doc) => ({ id: doc.id, role: doc.data().role as 'user' | 'assistant', content: doc.data().text as string }));
}

function titleFrom(message: string): string {
  const oneLine = message.replace(/\s+/g, ' ').trim();
  return oneLine.length > TITLE_MAX ? `${oneLine.slice(0, TITLE_MAX - 1)}…` : oneLine;
}

/**
 * Cuerpo del callable `chat`, con las dependencias inyectadas.
 *
 * Exportado para `test/chat.test.ts`: es la única forma de ejercitar el flujo
 * completo (auth, App Check, validación, cuota, escrituras, contexto, historial
 * y rollback) contra el emulador sin una clave de OpenRouter y sin red.
 */
export async function handleChat(request: ChatCall, deps: ChatDeps): Promise<ChatResponse> {
  // 1. Autenticación y App Check.
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión para usar el asistente.');
  }
  if (deps.enforceAppCheck && !request.app) {
    throw new HttpsError('unauthenticated', 'Se requiere una verificación válida de App Check.');
  }
  const uid = request.auth.uid;
  const { message, conversationId } = parseInput(request.data);

  const { db } = deps;
  const now = deps.now ?? new Date();
  const userRef = db.doc(`users/${uid}`);
  const conversations = userRef.collection('conversations');

  // Si se indicó conversación, debe existir (antes de consumir cuota). La ruta
  // cuelga de `users/{uid}`, así que el id de la conversación de otra persona
  // simplemente no existe aquí: no hay forma de leerla ni de escribir en ella.
  let convRef: DocumentReference;
  if (conversationId) {
    convRef = conversations.doc(conversationId);
    const convSnap = await convRef.get();
    if (!convSnap.exists) {
      throw new HttpsError('invalid-argument', 'La conversación indicada no existe.');
    }
  } else {
    convRef = conversations.doc();
  }

  // 2. Cuota: de por vida en el plan free, diaria en pro, más el tope global.
  const reservation = await reserveChatQuota(db, uid, now);

  // 3 y 4. Crear conversación si hace falta y guardar el mensaje del usuario.
  const messages = convRef.collection('messages');
  const userMsgRef = messages.doc();
  const createdConversation = !conversationId;
  const batchIn = db.batch();
  if (createdConversation) {
    batchIn.set(convRef, {
      title: titleFrom(message),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      messageCount: 0,
    });
  }
  batchIn.set(userMsgRef, { role: 'user', text: message, createdAt: FieldValue.serverTimestamp() });
  await batchIn.commit();

  // Deshace lo escrito en este turno. Se usa cuando el fallo no es imputable
  // al usuario: la conversación queda como estaba y la cuota se devuelve, así
  // que reintentar no le cuesta un mensaje.
  const rollback = async (reason: string) => {
    try {
      const batch = db.batch();
      batch.delete(userMsgRef);
      if (createdConversation) batch.delete(convRef);
      await batch.commit();
      await refundChatQuota(db, uid, reservation.dayKey);
    } catch (err) {
      logger.error('chat.rollback.error', { uid, reason, error: String(err) });
    }
  };

  // 5. Contexto para el system prompt + historial.
  //
  // El mes sale de `latestMonthDoc` y no de una consulta escrita aquí: el por
  // qué, y el error que mataba la función, están en el comentario de esa
  // función. Si este bloque vuelve a lanzar, no responde ni una sola llamada al
  // asistente.
  //
  // VA DENTRO DE UN try CON ROLLBACK, y esto lo enseñó el fallo de la consulta
  // descendente: el error se lanzaba AQUÍ, después de reservar la cuota y de
  // guardar el mensaje del usuario, pero antes del único `try` que había (el de
  // OpenRouter). Resultado medido contra el emulador con el código anterior: la
  // llamada moría, `meta/usage` quedaba en `chatCountLifetime: 1` y la
  // conversación con su mensaje huérfano se quedaba en Firestore. Es decir que
  // cada intento le gastaba al usuario del plan free uno de sus 25 mensajes DE
  // POR VIDA en una función que nunca respondía. Que el fallo concreto esté
  // arreglado no vuelve seguro dejar este tramo sin red: cualquier error de
  // Firestore aquí (contención, plazo agotado) le cobraría igual.
  let systemPrompt: string;
  let llmMessages: ChatMessage[];
  let historyCount: number;
  try {
    const [monthDoc, txSnap, productCount, materialCount, historySnap] = await Promise.all([
      latestMonthDoc(userRef, now),
      userRef.collection('transactions').orderBy('date', 'desc').limit(RECENT_TRANSACTIONS_LIMIT).get(),
      userRef.collection('inventory').where('type', '==', 'product').count().get(),
      userRef.collection('inventory').where('type', '==', 'material').count().get(),
      messages.orderBy('createdAt', 'desc').limit(HISTORY_LIMIT).get(),
    ]);

    const inventory: InventoryCounts = {
      products: productCount.data().count,
      materials: materialCount.data().count,
    };
    systemPrompt = buildSystemPrompt({
      profile: toProfileContext(reservation.profile),
      latestMonth: toMonthContext(monthDoc),
      recentTransactions: txSnap.docs.map(toTransactionContext),
      inventory,
    });

    const history = toHistory(historySnap.docs);
    if (history.length === 0 || history[history.length - 1].id !== userMsgRef.id) {
      history.push({ id: userMsgRef.id, role: 'user', content: message });
    }
    historyCount = history.length;
    llmMessages = [
      { role: 'system', content: systemPrompt },
      ...history.map(({ role, content }) => ({ role, content })),
    ];
  } catch (err) {
    logger.error('chat.contexto.error', { uid, conversationId: convRef.id, error: String(err) });
    await rollback('contexto');
    throw new HttpsError('internal', 'No se pudo preparar el contexto del asistente. Intenta de nuevo.');
  }

  // 6. OpenRouter.
  const { model } = deps;
  let reply: string;
  try {
    const result = await deps.ask({
      apiKey: deps.apiKey,
      model,
      messages: llmMessages,
      timeoutMs: OPENROUTER_TIMEOUT_MS,
    });
    reply = result.text;
    // Tokens reales de la llamada: es el único dato con el que el dueño puede
    // calcular el gasto y montar una alerta. Sin esto el coste es invisible.
    logger.info('chat.usage', {
      uid,
      model,
      plan: reservation.plan,
      promptTokens: result.usage?.promptTokens ?? null,
      completionTokens: result.usage?.completionTokens ?? null,
      totalTokens: result.usage?.totalTokens ?? null,
      systemPromptChars: systemPrompt.length,
      historyMessages: historyCount,
    });
  } catch (err) {
    logger.error('OpenRouter falló', { uid, conversationId: convRef.id, error: String(err) });
    await rollback('openrouter');
    throw new HttpsError('internal', 'No se pudo obtener una respuesta del asistente. Intenta de nuevo.');
  }

  // 7. Guardar respuesta y actualizar contadores.
  const batchOut = db.batch();
  batchOut.set(messages.doc(), { role: 'assistant', text: reply, createdAt: FieldValue.serverTimestamp() });
  batchOut.update(convRef, {
    messageCount: FieldValue.increment(2),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await batchOut.commit();

  // 8.
  return { conversationId: convRef.id, reply };
}

export const chat = onCall<ChatRequest, Promise<ChatResponse>>(
  {
    region: REGION,
    secrets: [OPENROUTER_API_KEY],
    timeoutSeconds: 60,
    memory: '256MiB',
    // Tope de gasto: evita escalado descontrolado ante abuso o picos.
    maxInstances: 5,
    cors: callableCors(),
  },
  // Los parámetros y el secreto se resuelven AQUÍ, en la envoltura: así
  // `handleChat` no depende de Secret Manager ni de `defineString`, y por eso se
  // puede probar contra el emulador.
  (request) =>
    handleChat(request, {
      db: getFirestore(),
      ask: askOpenRouter,
      apiKey: OPENROUTER_API_KEY.value(),
      model: OPENROUTER_MODEL.value(),
      enforceAppCheck: ENFORCE_APP_CHECK.value(),
    }),
);
