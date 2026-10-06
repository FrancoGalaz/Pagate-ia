/**
 * Tests de firestore.rules contra el emulador de Firestore.
 * Se ejecutan con: npm test  (firebase emulators:exec --only firestore "vitest run")
 *
 * Dos cosas que cambian respecto a la versión anterior y conviene tener claras
 * al leer este archivo:
 *
 * 1. Las marcas de tiempo se escriben con `serverTimestamp()`, no con
 *    `Timestamp.now()`. Las reglas exigen `updatedAt == request.time`, así que
 *    un timestamp del cliente ya no vale. Hay un test que lo comprueba.
 * 2. Toda consulta de colección lleva `limit()`. Las reglas exigen
 *    `request.query.limit <= 200`, y en una consulta sin `.limit()` ese valor es
 *    `null`, lo que deniega la operación. También hay un test de eso.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-pagate';
const ALICE = 'alice';
const BOB = 'bob';

/** Tope de documentos por consulta que imponen las reglas. */
const MAX_LIST = 200;

/** Tope superior de los campos de dinero (1e12) y de las unidades (1e9). */
const MAX_MONEY = 1_000_000_000_000;
const MAX_COUNT = 1_000_000_000;

let env: RulesTestEnvironment;

function emulatorHost(): { host: string; port: number } {
  const raw = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
  const [host, port] = raw.split(':');
  return { host, port: Number(port) };
}

/** Marcas de tiempo del servidor: es lo único que aceptan las reglas. */
function stamps() {
  return { createdAt: serverTimestamp(), updatedAt: serverTimestamp() };
}

function validProfile() {
  return {
    name: 'Alice',
    businessName: 'Taller Alice',
    businessType: 'Tejidos',
    currency: 'CLP',
    monthlyGoal: 500000,
    avatarInitials: 'AL',
    ...stamps(),
  };
}

function validTransaction() {
  return {
    title: 'Venta bufanda',
    description: 'Bufanda de lana',
    amount: 12000,
    type: 'income',
    category: 'Ventas',
    date: Timestamp.now(),
    monthKey: '2026-09',
    ...stamps(),
  };
}

function validInventoryItem() {
  return {
    name: 'Lana merino',
    type: 'material',
    price: 3500,
    stock: 10,
    minStock: 2,
    unit: 'ovillo',
    supplier: null,
    code: 'LM-01',
    ...stamps(),
  };
}

function validFixedExpense() {
  return { name: 'Arriendo', amount: 200000, ...stamps() };
}

function aliceDb(): Firestore {
  return env.authenticatedContext(ALICE).firestore() as unknown as Firestore;
}

function bobDb(): Firestore {
  return env.authenticatedContext(BOB).firestore() as unknown as Firestore;
}

function anonDb(): Firestore {
  return env.unauthenticatedContext().firestore() as unknown as Firestore;
}

/** Consulta de colección acotada, como la que exigen las reglas. */
function listOf(db: Firestore, path: string[], n: number = MAX_LIST) {
  const [first, ...rest] = path;
  return getDocs(query(collection(db, first, ...rest), limit(n)));
}

async function seed(fn: (db: Firestore) => Promise<void>) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore() as unknown as Firestore);
  });
}

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8'),
      ...emulatorHost(),
    },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

afterAll(async () => {
  await env.cleanup();
});

describe('users/{uid}', () => {
  it('el dueño lee su perfil', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), validProfile()));
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE)));
  });

  it('no puede leer el perfil ajeno', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), validProfile()));
    await assertFails(getDoc(doc(bobDb(), 'users', ALICE)));
  });

  it('no se puede consultar la colección /users', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), validProfile()));
    await assertFails(getDocs(query(collection(aliceDb(), 'users'), limit(10))));
  });

  it('crea un perfil válido', async () => {
    await assertSucceeds(setDoc(doc(aliceDb(), 'users', ALICE), validProfile()));
  });

  it('crea perfil con hourlyRate válido', async () => {
    await assertSucceeds(
      setDoc(doc(aliceDb(), 'users', ALICE), {
        ...validProfile(),
        hourlyRate: { desiredMonthlySalary: 600000, availableHoursPerMonth: 120, hourlyValue: 5000 },
      }),
    );
  });

  it('no puede escribir plan al crear', async () => {
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), plan: 'pro' }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), plan: 'free' }));
  });

  it('no puede cambiar plan al actualizar', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), { ...validProfile(), plan: 'free' }));
    await assertFails(updateDoc(doc(aliceDb(), 'users', ALICE), { plan: 'pro', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(aliceDb(), 'users', ALICE), { name: 'Alicia', updatedAt: serverTimestamp() }));
  });

  it('rechaza campos desconocidos y tipos incorrectos', async () => {
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), extra: 1 }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), monthlyGoal: -1 }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), name: '' }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), createdAt: 'hoy' }));
  });

  it('solo acepta moneda CLP o USD', async () => {
    await assertSucceeds(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), currency: 'USD' }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), currency: 'MXN' }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), currency: 'EUR' }));
  });

  it('no puede escribir el perfil de otro', async () => {
    await assertFails(setDoc(doc(bobDb(), 'users', ALICE), validProfile()));
  });

  // ---------- S-02: delete de users/{uid} denegado ----------

  it('NO puede borrar su documento de usuario (eso lo hace el callable deleteAccount)', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), validProfile()));
    await assertFails(deleteDoc(doc(aliceDb(), 'users', ALICE)));
  });
});

// ---------- S-02: createdAt inmutable y updatedAt == request.time ----------

describe('S-02: marcas de tiempo', () => {
  it('rechaza updatedAt puesto por el cliente en vez del servidor', async () => {
    await assertFails(
      setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), updatedAt: Timestamp.now() }),
    );
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), {
        ...validTransaction(),
        updatedAt: Timestamp.now(),
      }),
    );
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'inventory'), {
        ...validInventoryItem(),
        updatedAt: Timestamp.now(),
      }),
    );
  });

  it('rechaza createdAt antedatado al crear', async () => {
    await assertFails(
      setDoc(doc(aliceDb(), 'users', ALICE), {
        ...validProfile(),
        createdAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')),
      }),
    );
  });

  it('createdAt es inmutable en update', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), validProfile()));
    // Reescribir createdAt con una marca nueva: denegado.
    await assertFails(
      updateDoc(doc(aliceDb(), 'users', ALICE), { createdAt: serverTimestamp(), updatedAt: serverTimestamp() }),
    );
    // Reescribirlo con una fecha inventada: denegado.
    await assertFails(
      updateDoc(doc(aliceDb(), 'users', ALICE), {
        createdAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')),
        updatedAt: serverTimestamp(),
      }),
    );
    // Dejarlo como estaba: permitido.
    await assertSucceeds(updateDoc(doc(aliceDb(), 'users', ALICE), { name: 'Alicia', updatedAt: serverTimestamp() }));
  });

  it('un update sin refrescar updatedAt se deniega', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), validProfile()));
    await assertFails(updateDoc(doc(aliceDb(), 'users', ALICE), { name: 'Alicia' }));
  });

  it('createdAt inmutable también en transactions e inventory', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE, 'transactions', 't1'), validTransaction());
      await setDoc(doc(db, 'users', ALICE, 'inventory', 'i1'), validInventoryItem());
    });
    await assertFails(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 't1'), {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'inventory', 'i1'), {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 't1'), {
        amount: 15000,
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

// ---------- S-02: topes numéricos superiores ----------

describe('S-02: topes numéricos', () => {
  it('amount acepta hasta 1e12 y rechaza por encima', async () => {
    const col = collection(aliceDb(), 'users', ALICE, 'transactions');
    await assertSucceeds(addDoc(col, { ...validTransaction(), amount: MAX_MONEY }));
    await assertFails(addDoc(col, { ...validTransaction(), amount: MAX_MONEY + 1 }));
    await assertFails(addDoc(col, { ...validTransaction(), amount: 1e300 }));
  });

  it('amount rechaza Infinity y NaN, que antes contaminaban los agregados', async () => {
    const col = collection(aliceDb(), 'users', ALICE, 'transactions');
    await assertFails(addDoc(col, { ...validTransaction(), amount: Number.POSITIVE_INFINITY }));
    await assertFails(addDoc(col, { ...validTransaction(), amount: Number.NaN }));
  });

  it('price y stock del inventario tienen tope', async () => {
    const col = collection(aliceDb(), 'users', ALICE, 'inventory');
    await assertSucceeds(addDoc(col, { ...validInventoryItem(), price: MAX_MONEY, stock: MAX_COUNT }));
    await assertFails(addDoc(col, { ...validInventoryItem(), price: MAX_MONEY + 1 }));
    await assertFails(addDoc(col, { ...validInventoryItem(), stock: MAX_COUNT + 1 }));
    await assertFails(addDoc(col, { ...validInventoryItem(), minStock: MAX_COUNT + 1 }));
    await assertFails(addDoc(col, { ...validInventoryItem(), price: Number.POSITIVE_INFINITY }));
  });

  it('monthlyGoal del perfil tiene tope', async () => {
    await assertSucceeds(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), monthlyGoal: MAX_MONEY }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), monthlyGoal: MAX_MONEY + 1 }));
    await assertFails(
      setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), monthlyGoal: Number.POSITIVE_INFINITY }),
    );
  });

  it('el gasto fijo tiene tope', async () => {
    const col = collection(aliceDb(), 'users', ALICE, 'fixedExpenses');
    await assertSucceeds(addDoc(col, { ...validFixedExpense(), amount: MAX_MONEY }));
    await assertFails(addDoc(col, { ...validFixedExpense(), amount: MAX_MONEY + 1 }));
  });

  it('hourlyRate tiene tope en sus tres campos', async () => {
    for (const field of ['desiredMonthlySalary', 'availableHoursPerMonth', 'hourlyValue']) {
      await assertFails(
        setDoc(doc(aliceDb(), 'users', ALICE), {
          ...validProfile(),
          hourlyRate: { [field]: MAX_MONEY + 1 },
        }),
      );
    }
  });
});

// ---------- S-02: read separado en get y list ----------

describe('S-02: list acotado a 200 documentos', () => {
  const COLECCIONES: string[][] = [
    ['users', ALICE, 'transactions'],
    ['users', ALICE, 'inventory'],
    ['users', ALICE, 'fixedExpenses'],
    ['users', ALICE, 'months'],
    ['users', ALICE, 'conversations'],
    ['users', ALICE, 'conversations', 'c1', 'messages'],
    ['users', ALICE, 'meta'],
  ];

  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE), validProfile());
      await setDoc(doc(db, 'users', ALICE, 'transactions', 't1'), validTransaction());
      await setDoc(doc(db, 'users', ALICE, 'inventory', 'i1'), validInventoryItem());
      await setDoc(doc(db, 'users', ALICE, 'fixedExpenses', 'f1'), validFixedExpense());
      await setDoc(doc(db, 'users', ALICE, 'months', '2026-09'), {
        totalIncome: 1,
        totalExpenses: 0,
        transactionCount: 1,
        updatedAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'users', ALICE, 'conversations', 'c1'), {
        title: 'Hola',
        messageCount: 1,
        ...stamps(),
      });
      await setDoc(doc(db, 'users', ALICE, 'conversations', 'c1', 'messages', 'm1'), {
        role: 'user',
        text: 'Hola',
        createdAt: serverTimestamp(),
      });
      await setDoc(doc(db, 'users', ALICE, 'meta', 'usage'), {
        dayKey: '2026-09-29',
        chatCountDay: 1,
        chatCountLifetime: 1,
      });
    });
  });

  it('permite list con limit de 200 o menos', async () => {
    for (const path of COLECCIONES) {
      await assertSucceeds(listOf(aliceDb(), path, 1));
      await assertSucceeds(listOf(aliceDb(), path, MAX_LIST));
    }
  });

  it('deniega list con limit mayor que 200', async () => {
    for (const path of COLECCIONES) {
      await assertFails(listOf(aliceDb(), path, MAX_LIST + 1));
      await assertFails(listOf(aliceDb(), path, 10_000));
    }
  });

  it('deniega list sin limit explícito (request.query.limit es null)', async () => {
    for (const path of COLECCIONES) {
      const [first, ...rest] = path;
      await assertFails(getDocs(collection(aliceDb(), first, ...rest)));
    }
  });

  it('get de documento individual sigue funcionando sin limit', async () => {
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 't1')));
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'months', '2026-09')));
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'meta', 'usage')));
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'conversations', 'c1', 'messages', 'm1')));
  });

  it('el limit no le sirve a un usuario ajeno', async () => {
    for (const path of COLECCIONES) {
      await assertFails(listOf(bobDb(), path, 10));
    }
  });
});

describe('users/{uid}/transactions', () => {
  it('crea una transacción válida', async () => {
    await assertSucceeds(addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), validTransaction()));
  });

  it('rechaza amount <= 0', async () => {
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), { ...validTransaction(), amount: 0 }),
    );
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), { ...validTransaction(), amount: -5 }),
    );
  });

  it('rechaza type inválido', async () => {
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), { ...validTransaction(), type: 'transfer' }),
    );
  });

  it('rechaza monthKey mal formado', async () => {
    for (const monthKey of ['2026-9', '26-09', '2026/09', 'septiembre', '']) {
      await assertFails(
        addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), { ...validTransaction(), monthKey }),
      );
    }
  });

  it('rechaza meses fuera de 01-12, con los que se fabricaban meses inexistentes', async () => {
    for (const monthKey of ['2026-00', '2026-13', '2026-99']) {
      await assertFails(
        addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), { ...validTransaction(), monthKey }),
      );
    }
    for (const monthKey of ['2026-01', '2026-09', '2026-12']) {
      await assertSucceeds(
        addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), { ...validTransaction(), monthKey }),
      );
    }
  });

  it('rechaza campo desconocido', async () => {
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), { ...validTransaction(), userId: ALICE }),
    );
  });

  it('rechaza date que no es timestamp', async () => {
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'transactions'), { ...validTransaction(), date: '2026-09-01' }),
    );
  });

  it('actualiza y borra su propia transacción', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE, 'transactions', 't1'), validTransaction()));
    await assertSucceeds(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 't1'), {
        amount: 15000,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(deleteDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 't1')));
  });

  it('otro usuario no lee ni escribe transacciones ajenas', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE, 'transactions', 't1'), validTransaction()));
    await assertFails(getDoc(doc(bobDb(), 'users', ALICE, 'transactions', 't1')));
    await assertFails(listOf(bobDb(), ['users', ALICE, 'transactions'], 10));
    await assertFails(addDoc(collection(bobDb(), 'users', ALICE, 'transactions'), validTransaction()));
  });
});

describe('users/{uid}/inventory y fixedExpenses', () => {
  it('crea un ítem de inventario válido', async () => {
    await assertSucceeds(addDoc(collection(aliceDb(), 'users', ALICE, 'inventory'), validInventoryItem()));
  });

  it('rechaza stock negativo, type inválido y campo extra', async () => {
    const col = collection(aliceDb(), 'users', ALICE, 'inventory');
    await assertFails(addDoc(col, { ...validInventoryItem(), stock: -1 }));
    await assertFails(addDoc(col, { ...validInventoryItem(), type: 'service' }));
    await assertFails(addDoc(col, { ...validInventoryItem(), userId: ALICE }));
  });

  it('crea gasto fijo válido y rechaza amount <= 0', async () => {
    const col = collection(aliceDb(), 'users', ALICE, 'fixedExpenses');
    await assertSucceeds(addDoc(col, validFixedExpense()));
    await assertFails(addDoc(col, { ...validFixedExpense(), amount: 0 }));
  });
});

describe('colecciones solo backend', () => {
  it('el dueño lee months pero no escribe', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users', ALICE, 'months', '2026-09'), {
        totalIncome: 1,
        totalExpenses: 0,
        transactionCount: 1,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'months', '2026-09')));
    await assertFails(
      setDoc(doc(aliceDb(), 'users', ALICE, 'months', '2026-10'), {
        totalIncome: 999,
        totalExpenses: 0,
        transactionCount: 1,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(updateDoc(doc(aliceDb(), 'users', ALICE, 'months', '2026-09'), { totalIncome: 999 }));
    await assertFails(deleteDoc(doc(aliceDb(), 'users', ALICE, 'months', '2026-09')));
  });

  it('el dueño lee conversaciones y mensajes pero no escribe', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE, 'conversations', 'c1'), {
        title: 'Hola',
        messageCount: 1,
        ...stamps(),
      });
      await setDoc(doc(db, 'users', ALICE, 'conversations', 'c1', 'messages', 'm1'), {
        role: 'user',
        text: 'Hola',
        createdAt: serverTimestamp(),
      });
    });
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'conversations', 'c1')));
    await assertSucceeds(listOf(aliceDb(), ['users', ALICE, 'conversations', 'c1', 'messages'], 50));
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'conversations', 'c1', 'messages'), {
        role: 'assistant',
        text: 'inyectado',
        createdAt: serverTimestamp(),
      }),
    );
    await assertFails(
      setDoc(doc(aliceDb(), 'users', ALICE, 'conversations', 'c2'), {
        title: 'x',
        messageCount: 0,
        ...stamps(),
      }),
    );
  });

  it('el dueño lee meta/usage pero no la modifica', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users', ALICE, 'meta', 'usage'), {
        dayKey: '2026-09-17',
        chatCountDay: 3,
        chatCountLifetime: 20,
      }),
    );
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'meta', 'usage')));
    await assertFails(updateDoc(doc(aliceDb(), 'users', ALICE, 'meta', 'usage'), { chatCountDay: 0 }));
    await assertFails(updateDoc(doc(aliceDb(), 'users', ALICE, 'meta', 'usage'), { chatCountLifetime: 0 }));
  });

  it('waitlist no es accesible ni autenticado', async () => {
    await assertFails(addDoc(collection(aliceDb(), 'waitlist'), { name: 'x', email: 'x@x.cl', source: 'test' }));
    await assertFails(listOf(aliceDb(), ['waitlist'], 10));
  });

  it('la configuración y los contadores globales del asistente no son accesibles', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'system', 'aiConfig'), { globalDailyCapEnabled: false, globalDailyCap: 2000 });
      await setDoc(doc(db, 'system', 'aiUsage', 'days', '2026-09-29'), { calls: 7 });
    });
    await assertFails(getDoc(doc(aliceDb(), 'system', 'aiConfig')));
    await assertFails(setDoc(doc(aliceDb(), 'system', 'aiConfig'), { globalDailyCapEnabled: false }));
    await assertFails(getDoc(doc(aliceDb(), 'system', 'aiUsage', 'days', '2026-09-29')));
    await assertFails(
      setDoc(doc(aliceDb(), 'system', 'aiUsage', 'days', '2026-09-29'), { calls: 0 }),
    );
  });
});

describe('sin autenticación', () => {
  it('no lee ni escribe nada', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), validProfile()));
    await assertFails(getDoc(doc(anonDb(), 'users', ALICE)));
    await assertFails(setDoc(doc(anonDb(), 'users', ALICE), validProfile()));
    await assertFails(addDoc(collection(anonDb(), 'users', ALICE, 'transactions'), validTransaction()));
    await assertFails(listOf(anonDb(), ['users', ALICE, 'months'], 10));
    await assertFails(addDoc(collection(anonDb(), 'waitlist'), { name: 'x', email: 'x@x.cl' }));
  });
});
