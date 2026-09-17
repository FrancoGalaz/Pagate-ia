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
import { ENFORCE_APP_CHECK, OPENROUTER_API_KEY, OPENROUTER_MODEL, REGION } from './config';
import { askOpenRouter, type ChatMessage } from './openrouter';
import {
  buildSystemPrompt,
  type InventoryCounts,
  type MonthContext,
  type Plan,
  type ProfileContext,
  type TransactionContext,
} from './prompt';

export const MAX_MESSAGE_CHARS = 2000;
export const HISTORY_LIMIT = 20;
export const RECENT_TRANSACTIONS_LIMIT = 10;
export const DAILY_QUOTA: Record<Plan, number> = { free: 30, pro: 300 };
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

/** Clave del día en UTC ('yyyy-MM-dd'). */
export function dayKeyOf(date: Date = new Date()): string {
  return date.toISOString().slice(0, 10);
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

function planOf(profile: DocumentData | undefined): Plan {
  return profile?.plan === 'pro' ? 'pro' : 'free';
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
    plan: planOf(data),
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
    transactionCount: typeof d.transactionCount === 'number' ? d.transactionCount : 0,
  };
}

function toTransactionContext(doc: QueryDocumentSnapshot): TransactionContext {
  const d = doc.data();
  return {
    title: typeof d.title === 'string' ? d.title : '',
    amount: typeof d.amount === 'number' ? d.amount : 0,
    type: d.type === 'expense' ? 'expense' : 'income',
    category: typeof d.category === 'string' ? d.category : '',
    date: d.date instanceof Timestamp ? d.date.toDate() : null,
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
    const usageRef = db.doc(`users/${uid}/meta/usage`);
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

    // 2. Cuota diaria en transacción.
    const dayKey = dayKeyOf();
    const profileData = await db.runTransaction(async (tx) => {
      const [userSnap, usageSnap] = await Promise.all([tx.get(userRef), tx.get(usageRef)]);
      const profile = userSnap.data();
      const plan = planOf(profile);
      const usage = usageSnap.data();
      const used =
        usage?.dayKey === dayKey && typeof usage.chatCountDay === 'number' && usage.chatCountDay > 0
          ? usage.chatCountDay
          : 0;
      const limit = DAILY_QUOTA[plan];
      if (used >= limit) {
        throw new HttpsError(
          'resource-exhausted',
          `Alcanzaste el límite diario de ${limit} mensajes del plan ${plan}. Vuelve mañana.`,
        );
      }
      tx.set(usageRef, { dayKey, chatCountDay: used + 1 });
      return profile;
    });

    // 3 y 4. Crear conversación si hace falta y guardar el mensaje del usuario.
    const messages = convRef.collection('messages');
    const userMsgRef = messages.doc();
    const batchIn = db.batch();
    if (!conversationId) {
      batchIn.set(convRef, {
        title: titleFrom(message),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        messageCount: 0,
      });
    }
    batchIn.set(userMsgRef, { role: 'user', text: message, createdAt: FieldValue.serverTimestamp() });
    await batchIn.commit();

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
      profile: toProfileContext(profileData),
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
    let reply: string;
    try {
      reply = await askOpenRouter({
        apiKey: OPENROUTER_API_KEY.value(),
        model: OPENROUTER_MODEL.value(),
        messages: llmMessages,
        timeoutMs: OPENROUTER_TIMEOUT_MS,
      });
    } catch (err) {
      logger.error('OpenRouter falló', { uid, conversationId: convRef.id, error: String(err) });
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
