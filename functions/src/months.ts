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
  /** Suma de `amount` de los ingresos del mes. BRUTO: lo que cobró. */
  totalIncome: number;
  totalExpenses: number;
  /**
   * Suma de `platformFee` de los INGRESOS del mes: lo que se quedaron los
   * medios de pago.
   *
   * POR QUÉ ESTÁ AQUÍ (decisión del contrato C-3, ver `docs/ARQUITECTURA.md`).
   * `months/*` es el único sitio del que el cliente y el asistente sacan el
   * resumen de un mes, y hasta ahora solo tenía el bruto. El neto chileno
   * (`totalIncome - totalPlatformFees`) no se podía derivar de él: había que
   * recorrer las transacciones del mes, que es justo lo que el agregado existe
   * para evitar, y encima el cliente solo puede leer 200 por consulta (el tope
   * de `firestore.rules`), así que el mes 201 habría salido mal sin avisar.
   *
   * Lo que se guarda es el OPERANDO, no el neto. El principio de C-3 («el neto
   * no se guarda, se deriva») se mantiene intacto: un neto guardado se puede
   * contradecir con sus propios operandos, mientras que esto es una suma más,
   * del mismo tipo que `totalIncome` y recalculada igual de cero en cada pasada.
   *
   * Solo cuenta los ingresos: una comisión del medio de pago sobre un gasto no
   * significa nada, y `firestore.rules` la rechaza desde el mismo cambio.
   */
  totalPlatformFees: number;
  transactionCount: number;
}

/**
 * Convierte el resultado de una agregación en un número usable.
 *
 * `sum()` devuelve 0 cuando no hay valores y se salta los que no son números,
 * pero puede devolver `Infinity` o `NaN` si algún documento los tiene. Las
 * reglas lo impiden al cliente; el Admin SDK (sembrado de datos, migraciones) no
 * pasa por ellas. Un `Infinity` en `months/*` es permanente: nada vuelve a
 * recalcular el mes hasta la siguiente escritura, y mientras tanto la app y el
 * asistente muestran "∞".
 */
function finiteSum(value: unknown): number {
  const n = Number(value ?? 0);
  return Number.isFinite(n) ? n : 0;
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
 * Desde el contrato C-3 también suma `totalPlatformFees` (las comisiones de los
 * medios de pago sobre los ingresos del mes), para que el neto del mes se pueda
 * derivar del agregado en vez de recorriendo las transacciones. El por qué está
 * en `MonthTotals`.
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

  const monthTransactions = (type: 'income' | 'expense') =>
    transactions.where('type', '==', type).where('monthKey', '==', monthKey);

  const aggregateFor = (type: 'income' | 'expense') =>
    monthTransactions(type).aggregate({
      total: AggregateField.sum('amount'),
      count: AggregateField.count(),
    });

  /**
   * Las comisiones van en su PROPIA agregación, y esto NO es una redundancia
   * que se pueda "simplificar" metiendo `fees` en la agregación de arriba.
   *
   * Comprobado contra el emulador: en una agregación COMBINADA, un
   * `sum('platformFee')` restringe el conjunto entero a los documentos que
   * TIENEN ese campo. Con dos ingresos de 100 y 50, y solo el primero con
   * comisión, `{ total: sum('amount'), fees: sum('platformFee'), count: count() }`
   * devolvía `{ total: 100, fees: 7, count: 1 }`: el ingreso de 50 desaparecía
   * del total y de la cuenta. Y como `platformFee` es OPCIONAL, lo normal es que
   * la mayoría de los ingresos no lo tengan, así que los totales del mes
   * habrían contado solo las ventas con comisión.
   *
   * En consulta propia el comportamiento es el correcto: devuelve 0 cuando
   * ningún documento tiene el campo y la suma de los que sí lo tienen en caso
   * contrario. Cuesta una agregación más por recálculo; los totales correctos no
   * son negociables.
   */
  const feesAggregate = () =>
    monthTransactions('income').aggregate({ fees: AggregateField.sum('platformFee') });

  return db.runTransaction(async (tx) => {
    const [income, expense, fees] = await Promise.all([
      tx.get(aggregateFor('income')),
      tx.get(aggregateFor('expense')),
      tx.get(feesAggregate()),
    ]);
    const incomeData = income.data();
    const expenseData = expense.data();
    const feesData = fees.data();

    const totalIncome = finiteSum(incomeData.total);
    // Acotado a [0, totalIncome]. Por documento, las reglas ya garantizan
    // `0 <= platformFee <= amount`, así que la suma nunca puede pasarse del
    // bruto... siempre que las escrituras pasen por las reglas. El Admin SDK no
    // pasa, y un `totalPlatformFees` mayor que `totalIncome` daría un neto
    // negativo, que es una cifra falsa, no un dato incómodo.
    const totalPlatformFees = Math.min(Math.max(finiteSum(feesData.fees), 0), totalIncome);

    const totals: MonthTotals = {
      totalIncome,
      totalExpenses: finiteSum(expenseData.total),
      totalPlatformFees,
      transactionCount: finiteSum(incomeData.count) + finiteSum(expenseData.count),
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
