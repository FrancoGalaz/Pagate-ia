/**
 * Agregados mensuales: `users/{uid}/months/{yyyy-MM}`.
 *
 * El cliente nunca escribe estos documentos; los calcula el trigger
 * `onTransactionWritten` a partir de las transacciones del mes.
 */

import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions/v2';
import { AggregateField, FieldValue, getFirestore, type Firestore } from 'firebase-admin/firestore';
import { REGION } from './config';

/**
 * Forma de una clave de mes: `yyyy-MM` con el mes acotado a 01-12.
 *
 * El regex anterior era `^\d{4}-\d{2}$`, que aceptaba `2026-00` y de `2026-13`
 * a `2026-99`. Esas claves no son meses, y el trigger las trataba como tales:
 * creaba `months/2026-00` y la app lo listaba como un mes más. `firestore.rules`
 * ya rechaza esas claves al escribir la transacción, así que aquí el regex no es
 * redundante: es la segunda mitad de la misma validación, y la que cubre los
 * documentos escritos por el Admin SDK (sembrado de datos, migraciones), que no
 * pasan por las reglas.
 */
const MONTH_KEY_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

export interface MonthTotals {
  totalIncome: number;
  totalExpenses: number;
  transactionCount: number;
}

/**
 * Recalcula `users/{uid}/months/{monthKey}` a partir de las transacciones del
 * mes. Idempotente: siempre deriva el estado completo, nunca acumula.
 *
 * Lectura y escritura van DENTRO de una transacción (S-03). Antes se leían las
 * agregaciones con `Promise.all` y se escribía después con un `set()` suelto:
 * con dos escrituras seguidas sobre el mismo mes (el caso normal: dos gastos
 * uno detrás de otro), las dos invocaciones del trigger se solapaban y la que
 * había leído el estado más viejo podía commitear la última, dejando los totales
 * mal de forma permanente, porque nada vuelve a recalcular ese mes hasta la
 * siguiente escritura en él.
 *
 * `Transaction.get()` acepta una consulta de agregación en firebase-admin 14.4.0
 * (`@google-cloud/firestore` 9.2.0) y el emulador la resuelve: verificado antes
 * de elegir este enfoque en lugar de incrementos por delta. La agregación dentro
 * de la transacción además toma un bloqueo pesimista sobre los documentos que
 * coinciden, que es justo lo que hace falta para que dos recálculos del mismo
 * mes se serialicen.
 *
 * Si el mes queda sin transacciones, el documento se BORRA en vez de quedarse en
 * ceros: un mes en cero hacía que `chat.ts` eligiera como "último mes" un
 * documento vacío y le contara al asistente que el negocio no facturó nada.
 *
 * @returns los totales escritos, o `null` si el mes se borró por quedar vacío.
 */
export async function recalcMonth(
  uid: string,
  monthKey: string,
  db: Firestore = getFirestore(),
): Promise<MonthTotals | null> {
  const transactions = db.collection(`users/${uid}/transactions`);
  const monthRef = db.doc(`users/${uid}/months/${monthKey}`);

  const aggregateFor = (type: 'income' | 'expense') =>
    transactions
      .where('type', '==', type)
      .where('monthKey', '==', monthKey)
      .aggregate({
        total: AggregateField.sum('amount'),
        count: AggregateField.count(),
      });

  return db.runTransaction(async (tx) => {
    const [income, expense] = await Promise.all([
      tx.get(aggregateFor('income')),
      tx.get(aggregateFor('expense')),
    ]);
    const incomeData = income.data();
    const expenseData = expense.data();

    const totals: MonthTotals = {
      totalIncome: Number(incomeData.total ?? 0),
      totalExpenses: Number(expenseData.total ?? 0),
      transactionCount: Number(incomeData.count ?? 0) + Number(expenseData.count ?? 0),
    };

    if (totals.transactionCount === 0) {
      tx.delete(monthRef);
      return null;
    }

    tx.set(monthRef, { ...totals, updatedAt: FieldValue.serverTimestamp() });
    return totals;
  });
}

/**
 * Devuelve el `monthKey` del documento si es una clave de mes válida, o
 * `undefined` si falta, no es texto o no es un mes real.
 *
 * Exportada solo para poder probarla: es la puerta por la que `monthKey` entra
 * al trigger.
 */
export function monthKeyOf(data: FirebaseFirestore.DocumentData | undefined): string | undefined {
  const key = data?.monthKey;
  return typeof key === 'string' && MONTH_KEY_RE.test(key) ? key : undefined;
}

export const onTransactionWritten = onDocumentWritten(
  {
    document: 'users/{uid}/transactions/{txId}',
    region: REGION,
    memory: '256MiB',
    // Tope de gasto: limita el escalado del trigger ante ráfagas de escrituras.
    maxInstances: 10,
    // Sin reintento, un fallo transitorio (contención de la transacción, cold
    // start que se pasa de plazo, error de red en la agregación) perdía el
    // evento y dejaba el mes mal para siempre. `recalcMonth` es idempotente,
    // así que reintentar es seguro.
    retry: true,
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

    // En serie, no en paralelo: dos recálculos simultáneos del mismo usuario
    // compiten por los mismos documentos y provocan reintentos de transacción
    // sin ganar nada (son dos meses como máximo).
    for (const key of keys) {
      await recalcMonth(uid, key);
    }
    logger.info('Meses recalculados', { uid, months: [...keys] });
  },
);
