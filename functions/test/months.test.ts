/**
 * Tests de los agregados mensuales (S-03) contra el emulador de Firestore.
 *
 * Lo que se quiere demostrar: que `recalcMonth` da el total correcto cuando dos
 * recálculos del mismo mes se solapan (que es lo que pasa cuando el usuario
 * registra dos movimientos seguidos y el trigger se dispara dos veces), y que un
 * mes que se queda sin movimientos desaparece en vez de quedar en ceros.
 */

import { beforeEach, describe, expect, it } from 'vitest';
import { Timestamp } from 'firebase-admin/firestore';
import { recalcMonth } from '../src/months';
import { adminDb, wipeUser } from './helpers/admin';

const UID = 'agregados';
const MONTH = '2026-09';

async function addTx(
  id: string,
  amount: number,
  type: 'income' | 'expense',
  monthKey: string = MONTH,
): Promise<void> {
  await adminDb().doc(`users/${UID}/transactions/${id}`).set({
    title: `Movimiento ${id}`,
    amount,
    type,
    category: 'Ventas',
    date: Timestamp.now(),
    monthKey,
  });
}

async function month(monthKey: string = MONTH): Promise<Record<string, unknown> | undefined> {
  return (await adminDb().doc(`users/${UID}/months/${monthKey}`).get()).data();
}

describe('recalcMonth', () => {
  beforeEach(async () => {
    await wipeUser(adminDb(), UID);
  });

  it('suma ingresos y gastos del mes', async () => {
    const db = adminDb();
    await addTx('t1', 100_000, 'income');
    await addTx('t2', 30_000, 'expense');
    await addTx('t3', 5_000, 'expense');

    const totals = await recalcMonth(UID, MONTH, db);
    expect(totals).toEqual({ totalIncome: 100_000, totalExpenses: 35_000, transactionCount: 3 });
    expect(await month()).toMatchObject({ totalIncome: 100_000, totalExpenses: 35_000, transactionCount: 3 });
  });

  it('ignora las transacciones de otros meses', async () => {
    const db = adminDb();
    await addTx('t1', 100_000, 'income', MONTH);
    await addTx('t2', 999_999, 'income', '2026-10');

    expect(await recalcMonth(UID, MONTH, db)).toEqual({
      totalIncome: 100_000,
      totalExpenses: 0,
      transactionCount: 1,
    });
  });

  it('dos escrituras seguidas dejan el total correcto', async () => {
    const db = adminDb();

    // Primera escritura y su recálculo.
    await addTx('t1', 10_000, 'income');
    await recalcMonth(UID, MONTH, db);
    expect(await month()).toMatchObject({ totalIncome: 10_000, transactionCount: 1 });

    // Segunda escritura y su recálculo: el total acumulado tiene que ser el de
    // las dos, no el de la última.
    await addTx('t2', 7_000, 'income');
    await recalcMonth(UID, MONTH, db);
    expect(await month()).toMatchObject({ totalIncome: 17_000, totalExpenses: 0, transactionCount: 2 });
  });

  it('dos recálculos solapados del mismo mes convergen al total correcto', async () => {
    const db = adminDb();
    await addTx('t1', 10_000, 'income');
    await addTx('t2', 7_000, 'income');
    await addTx('t3', 2_000, 'expense');

    // Es el escenario del hallazgo: dos invocaciones del trigger a la vez. Con
    // la lectura y la escritura dentro de la transacción, las dos se serializan
    // y ninguna puede commitear un estado viejo.
    const [a, b] = await Promise.all([recalcMonth(UID, MONTH, db), recalcMonth(UID, MONTH, db)]);
    const expected = { totalIncome: 17_000, totalExpenses: 2_000, transactionCount: 3 };
    expect(a).toEqual(expected);
    expect(b).toEqual(expected);
    expect(await month()).toMatchObject(expected);
  });

  it('borra el documento del mes cuando se queda sin movimientos', async () => {
    const db = adminDb();
    await addTx('t1', 10_000, 'income');
    await recalcMonth(UID, MONTH, db);
    expect(await month()).toBeDefined();

    await db.doc(`users/${UID}/transactions/t1`).delete();
    expect(await recalcMonth(UID, MONTH, db)).toBeNull();
    expect((await db.doc(`users/${UID}/months/${MONTH}`).get()).exists).toBe(false);
  });

  it('no crea el documento de un mes que nunca tuvo movimientos', async () => {
    const db = adminDb();
    expect(await recalcMonth(UID, '2030-01', db)).toBeNull();
    expect((await db.doc(`users/${UID}/months/2030-01`).get()).exists).toBe(false);
  });

  it('al cambiar el monthKey de una transacción, los dos meses quedan bien', async () => {
    const db = adminDb();
    await addTx('t1', 10_000, 'income', '2026-09');
    await recalcMonth(UID, '2026-09', db);

    // El usuario corrige la fecha: la transacción pasa a octubre.
    await db.doc(`users/${UID}/transactions/t1`).set({ monthKey: '2026-10' }, { merge: true });
    await recalcMonth(UID, '2026-09', db);
    await recalcMonth(UID, '2026-10', db);

    expect((await db.doc(`users/${UID}/months/2026-09`).get()).exists).toBe(false);
    expect(await month('2026-10')).toMatchObject({ totalIncome: 10_000, transactionCount: 1 });
  });
});
