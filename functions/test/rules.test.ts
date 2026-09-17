/**
 * Tests de firestore.rules contra el emulador de Firestore.
 * Se ejecutan con: npm test  (firebase emulators:exec --only firestore "vitest run")
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
  setDoc,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';

const PROJECT_ID = 'demo-pagate';
const ALICE = 'alice';
const BOB = 'bob';

let env: RulesTestEnvironment;

function emulatorHost(): { host: string; port: number } {
  const raw = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
  const [host, port] = raw.split(':');
  return { host, port: Number(port) };
}

function now() {
  return Timestamp.now();
}

function validProfile() {
  return {
    name: 'Alice',
    businessName: 'Taller Alice',
    businessType: 'Tejidos',
    currency: 'CLP',
    monthlyGoal: 500000,
    avatarInitials: 'AL',
    createdAt: now(),
    updatedAt: now(),
  };
}

function validTransaction() {
  return {
    title: 'Venta bufanda',
    description: 'Bufanda de lana',
    amount: 12000,
    type: 'income',
    category: 'Ventas',
    date: now(),
    monthKey: '2026-09',
    createdAt: now(),
    updatedAt: now(),
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
    createdAt: now(),
    updatedAt: now(),
  };
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

  it('no puede cambiar plan al actualizar, pero sí repetir el valor previo', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), { ...validProfile(), plan: 'free' }));
    await assertFails(updateDoc(doc(aliceDb(), 'users', ALICE), { plan: 'pro' }));
    await assertSucceeds(updateDoc(doc(aliceDb(), 'users', ALICE), { name: 'Alicia', updatedAt: now() }));
    await assertSucceeds(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), plan: 'free' }));
  });

  it('rechaza campos desconocidos y tipos incorrectos', async () => {
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), extra: 1 }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), monthlyGoal: -1 }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), name: '' }));
    await assertFails(setDoc(doc(aliceDb(), 'users', ALICE), { ...validProfile(), createdAt: 'hoy' }));
  });

  it('no puede escribir el perfil de otro', async () => {
    await assertFails(setDoc(doc(bobDb(), 'users', ALICE), validProfile()));
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
      updateDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 't1'), { amount: 15000, updatedAt: now() }),
    );
    await assertSucceeds(deleteDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 't1')));
  });

  it('otro usuario no lee ni escribe transacciones ajenas', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE, 'transactions', 't1'), validTransaction()));
    await assertFails(getDoc(doc(bobDb(), 'users', ALICE, 'transactions', 't1')));
    await assertFails(getDocs(collection(bobDb(), 'users', ALICE, 'transactions')));
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
    await assertSucceeds(addDoc(col, { name: 'Arriendo', amount: 200000, createdAt: now(), updatedAt: now() }));
    await assertFails(addDoc(col, { name: 'Arriendo', amount: 0, createdAt: now(), updatedAt: now() }));
  });
});

describe('colecciones solo backend', () => {
  it('el dueño lee months pero no escribe', async () => {
    await seed((db) =>
      setDoc(doc(db, 'users', ALICE, 'months', '2026-09'), {
        totalIncome: 1,
        totalExpenses: 0,
        transactionCount: 1,
        updatedAt: now(),
      }),
    );
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'months', '2026-09')));
    await assertFails(
      setDoc(doc(aliceDb(), 'users', ALICE, 'months', '2026-10'), {
        totalIncome: 999,
        totalExpenses: 0,
        transactionCount: 1,
        updatedAt: now(),
      }),
    );
    await assertFails(updateDoc(doc(aliceDb(), 'users', ALICE, 'months', '2026-09'), { totalIncome: 999 }));
  });

  it('el dueño lee conversaciones y mensajes pero no escribe', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', ALICE, 'conversations', 'c1'), {
        title: 'Hola',
        createdAt: now(),
        updatedAt: now(),
        messageCount: 1,
      });
      await setDoc(doc(db, 'users', ALICE, 'conversations', 'c1', 'messages', 'm1'), {
        role: 'user',
        text: 'Hola',
        createdAt: now(),
      });
    });
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'conversations', 'c1')));
    await assertSucceeds(getDocs(collection(aliceDb(), 'users', ALICE, 'conversations', 'c1', 'messages')));
    await assertFails(
      addDoc(collection(aliceDb(), 'users', ALICE, 'conversations', 'c1', 'messages'), {
        role: 'assistant',
        text: 'inyectado',
        createdAt: now(),
      }),
    );
    await assertFails(
      setDoc(doc(aliceDb(), 'users', ALICE, 'conversations', 'c2'), {
        title: 'x',
        createdAt: now(),
        updatedAt: now(),
        messageCount: 0,
      }),
    );
  });

  it('el dueño lee meta/usage pero no la modifica', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE, 'meta', 'usage'), { dayKey: '2026-09-17', chatCountDay: 3 }));
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'meta', 'usage')));
    await assertFails(updateDoc(doc(aliceDb(), 'users', ALICE, 'meta', 'usage'), { chatCountDay: 0 }));
  });

  it('waitlist no es accesible ni autenticado', async () => {
    await assertFails(addDoc(collection(aliceDb(), 'waitlist'), { name: 'x', email: 'x@x.cl', source: 'test' }));
    await assertFails(getDocs(collection(aliceDb(), 'waitlist')));
  });
});

describe('sin autenticación', () => {
  it('no lee ni escribe nada', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE), validProfile()));
    await assertFails(getDoc(doc(anonDb(), 'users', ALICE)));
    await assertFails(setDoc(doc(anonDb(), 'users', ALICE), validProfile()));
    await assertFails(addDoc(collection(anonDb(), 'users', ALICE, 'transactions'), validTransaction()));
    await assertFails(getDocs(collection(anonDb(), 'users', ALICE, 'months')));
    await assertFails(addDoc(collection(anonDb(), 'waitlist'), { name: 'x', email: 'x@x.cl' }));
  });
});
