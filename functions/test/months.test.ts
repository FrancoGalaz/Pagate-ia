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
import { monthKeyOf, recalcMonth } from '../src/months';
import { adminDb, wipeUser } from './helpers/admin';

const UID = 'agregados';
const MONTH = '2026-09';

async function addTx(
  id: string,
  amount: number,
  type: 'income' | 'expense',
  monthKey: string = MONTH,
  /**
   * Comision del medio de pago. `undefined` deja el campo AUSENTE, que es lo
   * que escribe el cliente cuando no hubo comision (cobro en efectivo o por
   * transferencia): el modelo borra el campo en vez de guardar un 0.
   */
  platformFee?: number,
): Promise<void> {
  await adminDb()
    .doc(`users/${UID}/transactions/${id}`)
    .set({
      title: `Movimiento ${id}`,
      amount,
      type,
      category: 'Ventas',
      date: Timestamp.now(),
      monthKey,
      ...(platformFee === undefined ? {} : { platformFee }),
    });
}

async function month(monthKey: string = MONTH): Promise<Record<string, unknown> | undefined> {
  return (await adminDb().doc(`users/${UID}/months/${monthKey}`).get()).data();
}

/**
 * `monthKeyOf` es la puerta de entrada del trigger: solo recalcula los meses
 * cuya clave pasa por aquí. Es una función pura, así que no necesita emulador.
 */
describe('monthKeyOf', () => {
  it('acepta los doce meses reales', () => {
    for (const mm of ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12']) {
      expect(monthKeyOf({ monthKey: `2026-${mm}` })).toBe(`2026-${mm}`);
    }
  });

  it('rechaza el mes 00 y los meses 13 a 99', () => {
    // Era el agujero del regex anterior (`^\d{4}-\d{2}$`): con él, el cliente
    // podía fabricar hasta 10.000 documentos distintos en months/ y la app los
    // mostraba como meses reales.
    for (const key of ['2026-00', '2026-13', '2026-19', '2026-20', '2026-42', '2026-99']) {
      expect(monthKeyOf({ monthKey: key }), key).toBeUndefined();
    }
  });

  it('rechaza claves mal formadas', () => {
    for (const key of ['2026-9', '26-09', '2026/09', '2026-091', '02026-09', 'septiembre', '', ' 2026-09']) {
      expect(monthKeyOf({ monthKey: key }), JSON.stringify(key)).toBeUndefined();
    }
  });

  it('rechaza lo que no es texto y el documento sin campo', () => {
    expect(monthKeyOf(undefined)).toBeUndefined();
    expect(monthKeyOf({})).toBeUndefined();
    expect(monthKeyOf({ monthKey: null })).toBeUndefined();
    expect(monthKeyOf({ monthKey: 202609 })).toBeUndefined();
  });
});

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
    expect(totals).toEqual({
      totalIncome: 100_000,
      totalExpenses: 35_000,
      totalPlatformFees: 0,
      transactionCount: 3,
    });
    expect(await month()).toMatchObject({ totalIncome: 100_000, totalExpenses: 35_000, transactionCount: 3 });
  });

  it('ignora las transacciones de otros meses', async () => {
    const db = adminDb();
    await addTx('t1', 100_000, 'income', MONTH);
    await addTx('t2', 999_999, 'income', '2026-10');

    expect(await recalcMonth(UID, MONTH, db)).toEqual({
      totalIncome: 100_000,
      totalExpenses: 0,
      totalPlatformFees: 0,
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
    const expected = {
      totalIncome: 17_000,
      totalExpenses: 2_000,
      totalPlatformFees: 0,
      transactionCount: 3,
    };
    expect(a).toEqual(expected);
    expect(b).toEqual(expected);
    expect(await month()).toMatchObject(expected);
  });

  /**
   * C-3: totalPlatformFees, la suma de las comisiones de los medios de pago.
   *
   * POR QUE ESTA EN EL AGREGADO: es el operando que le faltaba a months/* para
   * poder derivar el neto del mes sin recorrer las transacciones. El neto sigue
   * SIN guardarse.
   */
  describe('totalPlatformFees (C-3)', () => {
    it('suma las comisiones de los ingresos del mes', async () => {
      const db = adminDb();
      await addTx('t1', 100_000, 'income', MONTH, 3_500);
      await addTx('t2', 50_000, 'income', MONTH, 1_750);

      expect(await recalcMonth(UID, MONTH, db)).toEqual({
        totalIncome: 150_000,
        totalExpenses: 0,
        totalPlatformFees: 5_250,
        transactionCount: 2,
      });
      // El neto del mes se DERIVA del agregado: 150.000 - 5.250.
      const doc = await month();
      expect(Number(doc!.totalIncome) - Number(doc!.totalPlatformFees)).toBe(144_750);
    });

    it('vale 0 cuando ningun ingreso tiene comision', async () => {
      // Es el caso de un taller que cobra en efectivo y por transferencia: el
      // cliente ni escribe el campo.
      const db = adminDb();
      await addTx('t1', 100_000, 'income');
      expect((await recalcMonth(UID, MONTH, db))!.totalPlatformFees).toBe(0);
    });

    it('mezcla ingresos con y sin comision sin perder ninguno', async () => {
      // ESTE ES EL TEST QUE IMPORTA, y el que caza el error de meter el
      // sum('platformFee') en la misma agregacion que el total y la cuenta: en
      // agregacion combinada, ese sum restringe el conjunto a los documentos
      // que TIENEN el campo, asi que aqui habria devuelto totalIncome 100.000 y
      // transactionCount 1, perdiendo el ingreso de 40.000. Y como platformFee
      // es opcional, lo normal es que la mayoria de los ingresos no lo tenga.
      const db = adminDb();
      await addTx('t1', 100_000, 'income', MONTH, 3_500);
      await addTx('t2', 40_000, 'income');
      expect(await recalcMonth(UID, MONTH, db)).toEqual({
        totalIncome: 140_000,
        totalExpenses: 0,
        totalPlatformFees: 3_500,
        transactionCount: 2,
      });
    });

    it('ignora la comision escrita en un gasto', async () => {
      // firestore.rules la rechaza desde el contrato C-3, pero el Admin SDK no
      // pasa por las reglas (sembrado de datos, migraciones) y una comision en
      // un gasto no significa nada: no puede ensuciar el neto de los ingresos.
      const db = adminDb();
      await addTx('t1', 100_000, 'income', MONTH, 3_500);
      await addTx('t2', 20_000, 'expense', MONTH, 9_999);
      expect(await recalcMonth(UID, MONTH, db)).toEqual({
        totalIncome: 100_000,
        totalExpenses: 20_000,
        totalPlatformFees: 3_500,
        transactionCount: 2,
      });
    });

    it('ignora las comisiones de otros meses', async () => {
      const db = adminDb();
      await addTx('t1', 100_000, 'income', MONTH, 3_500);
      await addTx('t2', 80_000, 'income', '2026-10', 7_777);
      expect((await recalcMonth(UID, MONTH, db))!.totalPlatformFees).toBe(3_500);
    });

    it('no deja que la suma de comisiones pase del bruto', async () => {
      // Por documento las reglas garantizan platformFee <= amount, asi que esto
      // solo se puede escribir con el Admin SDK. Un neto negativo seria una
      // cifra falsa.
      const db = adminDb();
      await addTx('t1', 10_000, 'income', MONTH, 999_999);
      expect(await recalcMonth(UID, MONTH, db)).toEqual({
        totalIncome: 10_000,
        totalExpenses: 0,
        totalPlatformFees: 10_000,
        transactionCount: 1,
      });
    });

    it('no deja que una comision negativa infle el neto', async () => {
      const db = adminDb();
      await addTx('t1', 10_000, 'income', MONTH, -5_000);
      expect((await recalcMonth(UID, MONTH, db))!.totalPlatformFees).toBe(0);
    });

    it('un Infinity escrito por el Admin SDK no envenena el mes', async () => {
      // Sin el filtro de finitud, months/* se quedaba con Infinity para
      // siempre: nada vuelve a recalcular el mes hasta la siguiente escritura
      // en el, y mientras tanto la app y el asistente muestran una cifra que no
      // es un numero.
      const db = adminDb();
      await addTx('t1', 10_000, 'income', MONTH, Number.POSITIVE_INFINITY);
      const totals = await recalcMonth(UID, MONTH, db);
      expect(totals!.totalPlatformFees).toBe(0);
      expect(Number.isFinite(totals!.totalIncome)).toBe(true);
    });
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
