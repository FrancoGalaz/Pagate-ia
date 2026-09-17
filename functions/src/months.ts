import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { AggregateField, FieldValue, getFirestore } from 'firebase-admin/firestore';
import { REGION } from './config';

const MONTH_KEY_RE = /^\d{4}-\d{2}$/;

/**
 * Recalcula `users/{uid}/months/{monthKey}` a partir de las transacciones del
 * mes. Idempotente: siempre escribe el estado derivado completo. Si el mes
 * queda sin transacciones, deja los totales en 0 (no borra el documento).
 */
export async function recalcMonth(uid: string, monthKey: string): Promise<void> {
  const db = getFirestore();
  const transactions = db.collection(`users/${uid}/transactions`);

  const aggregateFor = (type: 'income' | 'expense') =>
    transactions
      .where('type', '==', type)
      .where('monthKey', '==', monthKey)
      .aggregate({
        total: AggregateField.sum('amount'),
        count: AggregateField.count(),
      })
      .get();

  const [income, expense] = await Promise.all([aggregateFor('income'), aggregateFor('expense')]);
  const incomeData = income.data();
  const expenseData = expense.data();

  await db.doc(`users/${uid}/months/${monthKey}`).set({
    totalIncome: Number(incomeData.total ?? 0),
    totalExpenses: Number(expenseData.total ?? 0),
    transactionCount: Number(incomeData.count ?? 0) + Number(expenseData.count ?? 0),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

function monthKeyOf(data: FirebaseFirestore.DocumentData | undefined): string | undefined {
  const key = data?.monthKey;
  return typeof key === 'string' && MONTH_KEY_RE.test(key) ? key : undefined;
}

export const onTransactionWritten = onDocumentWritten(
  {
    document: 'users/{uid}/transactions/{txId}',
    region: REGION,
    memory: '256MiB',
  },
  async (event) => {
    const uid = event.params.uid;
    const before = event.data?.before;
    const after = event.data?.after;

    const keys = new Set<string>();
    const beforeKey = before?.exists ? monthKeyOf(before.data()) : undefined;
    const afterKey = after?.exists ? monthKeyOf(after.data()) : undefined;
    if (beforeKey) keys.add(beforeKey);
    if (afterKey) keys.add(afterKey);

    if (keys.size === 0) {
      logger.warn('Transacción sin monthKey válido; no se recalcula ningún mes', {
        uid,
        txId: event.params.txId,
      });
      return;
    }

    await Promise.all([...keys].map((key) => recalcMonth(uid, key)));
    logger.info('Meses recalculados', { uid, months: [...keys] });
  },
);
