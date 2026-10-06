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
  type QueryDocumentSnapshot,
} from 'firebase-admin/firestore';
import { ENFORCE_APP_CHECK, OPENROUTER_API_KEY, OPENROUTER_MODEL, REGION, callableCors } from './config';
import { askOpenRouter, type ChatMessage } from './openrouter';
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

function toMonthContext(doc: QueryDocumentSnapshot | undefined): MonthContext | null {
  if (!doc) return null;
  const d = doc.data();
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
  async (request) => {
    // 1. Autenticación y App Check.
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión para usar el asistente.');
    }
    if (ENFORCE_APP_CHECK.value() && !request.app) {
      throw new HttpsError('unauthenticated', 'Se requiere una verificación válida de App Check.');
    }
    const uid = request.auth.uid;
    const { message, conversationId } = parseInput(request.data);

    const db = getFirestore();
    const userRef = db.doc(`users/${uid}`);
    const conversations = userRef.collection('conversations');

    // Si se indicó conversación, debe existir (antes de consumir cuota).
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
    const reservation = await reserveChatQuota(db, uid);

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
    const [monthSnap, txSnap, productCount, materialCount, historySnap] = await Promise.all([
      userRef.collection('months').orderBy(FieldPath.documentId(), 'desc').limit(1).get(),
      userRef.collection('transactions').orderBy('date', 'desc').limit(RECENT_TRANSACTIONS_LIMIT).get(),
      userRef.collection('inventory').where('type', '==', 'product').count().get(),
      userRef.collection('inventory').where('type', '==', 'material').count().get(),
      messages.orderBy('createdAt', 'desc').limit(HISTORY_LIMIT).get(),
    ]);

    const inventory: InventoryCounts = {
      products: productCount.data().count,
      materials: materialCount.data().count,
    };
    const systemPrompt = buildSystemPrompt({
      profile: toProfileContext(reservation.profile),
      latestMonth: toMonthContext(monthSnap.docs[0]),
      recentTransactions: txSnap.docs.map(toTransactionContext),
      inventory,
    });

    const history = toHistory(historySnap.docs);
    if (history.length === 0 || history[history.length - 1].id !== userMsgRef.id) {
      history.push({ id: userMsgRef.id, role: 'user', content: message });
    }
    const llmMessages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      ...history.map(({ role, content }) => ({ role, content })),
    ];

    // 6. OpenRouter.
    const model = OPENROUTER_MODEL.value();
    let reply: string;
    try {
      const result = await askOpenRouter({
        apiKey: OPENROUTER_API_KEY.value(),
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
        historyMessages: history.length,
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
  },
);
