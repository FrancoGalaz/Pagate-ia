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
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
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

/**
 * Emulador contra el que corren estos tests. Lo levanta `npm test`
 * (`firebase emulators:exec --config ../firebase.test.json`, puerto 8181) y
 * exporta `FIRESTORE_EMULATOR_HOST`.
 *
 * NO HAY VALOR POR DEFECTO, y es a propósito. Antes caía a `127.0.0.1:8080`,
 * que es el puerto del emulador de DESARROLLO, el que tiene los datos de
 * demostración. Estos tests llaman a `clearFirestore()` en cada `beforeEach`:
 * lanzar `vitest` a mano, sin `npm test`, apuntaba un borrado en bucle contra
 * ese emulador. Lo único que salvaba los datos era que el `projectId` de los
 * tests (`demo-pagate`) no es el del emulador de desarrollo
 * (`pagate-17211`), porque `clearFirestore()` borra por proyecto. Es un margen
 * demasiado fino para dejarlo en pie: ahora falla rápido, igual que
 * `test/helpers/admin.ts`.
 */
function emulatorHost(): { host: string; port: number } {
  const raw = process.env.FIRESTORE_EMULATOR_HOST;
  if (!raw) {
    throw new Error(
      'FIRESTORE_EMULATOR_HOST no está definido. Estos tests borran la base en cada caso: ' +
        'usa `npm --prefix functions test`, que levanta su propio emulador en el puerto 8181.',
    );
  }
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

/**
 * Contrato C-3: `docType` y `platformFee` en `users/{uid}/transactions/{txId}`.
 *
 * Los dos son opcionales. La prueba que de verdad importa es la última: un
 * documento escrito ANTES de este contrato, sin ninguno de los dos campos, tiene
 * que seguir pudiendo leerse y actualizarse. Si eso se rompiera, la app dejaría
 * de poder editar el historial que el usuario ya tiene registrado.
 */
describe('C-3: docType y platformFee en transactions', () => {
  const txs = () => collection(aliceDb(), 'users', ALICE, 'transactions');

  it('acepta una transacción sin docType ni platformFee', async () => {
    const tx = validTransaction();
    expect('docType' in tx).toBe(false);
    expect('platformFee' in tx).toBe(false);
    await assertSucceeds(addDoc(txs(), tx));
  });

  it('acepta los tres docType del contrato', async () => {
    for (const docType of ['boleta_venta', 'boleta_honorarios', 'sin_documento']) {
      await assertSucceeds(addDoc(txs(), { ...validTransaction(), docType }));
    }
  });

  it('rechaza un docType fuera del conjunto', async () => {
    for (const docType of ['factura', 'boleta', 'BOLETA_VENTA', 'boleta_venta ', '']) {
      await assertFails(addDoc(txs(), { ...validTransaction(), docType }));
    }
  });

  it('rechaza docType que no es texto, incluido null', async () => {
    // `null` se rechaza a propósito: "sin documento" se dice omitiendo el campo
    // o con 'sin_documento', no con un tercer valor que signifique lo mismo.
    for (const docType of [null, 1, true, ['boleta_venta']]) {
      await assertFails(addDoc(txs(), { ...validTransaction(), docType }));
    }
  });

  it('acepta platformFee entre 0 y amount, incluidos los extremos', async () => {
    for (const platformFee of [0, 1, 4580, 12000]) {
      await assertSucceeds(addDoc(txs(), { ...validTransaction(), amount: 12000, platformFee }));
    }
  });

  it('rechaza platformFee negativo', async () => {
    await assertFails(addDoc(txs(), { ...validTransaction(), platformFee: -1 }));
  });

  it('rechaza platformFee mayor que amount: el neto derivado sería negativo', async () => {
    await assertFails(addDoc(txs(), { ...validTransaction(), amount: 12000, platformFee: 12001 }));
    await assertFails(addDoc(txs(), { ...validTransaction(), amount: 12000, platformFee: 99999 }));
  });

  it('rechaza platformFee que no es número, incluidos null e Infinity', async () => {
    for (const platformFee of [null, '382', true, Number.POSITIVE_INFINITY, Number.NaN]) {
      await assertFails(addDoc(txs(), { ...validTransaction(), platformFee }));
    }
  });

  it('acepta los dos campos juntos', async () => {
    await assertSucceeds(
      addDoc(txs(), {
        ...validTransaction(),
        amount: 45000,
        docType: 'boleta_venta',
        platformFee: 1436,
      }),
    );
  });

  it('un documento viejo sin los campos nuevos se sigue pudiendo actualizar', async () => {
    // Se siembra con las reglas desactivadas para que sea exactamente un
    // documento de antes del contrato C-3.
    await seed((db) => setDoc(doc(db, 'users', ALICE, 'transactions', 'viejo'), validTransaction()));

    // Edición que no toca los campos nuevos: sigue funcionando.
    await assertSucceeds(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 'viejo'), {
        amount: 20000,
        updatedAt: serverTimestamp(),
      }),
    );

    // Y se le pueden añadir los campos nuevos sin reescribir el resto.
    await assertSucceeds(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 'viejo'), {
        docType: 'boleta_honorarios',
        platformFee: 0,
        updatedAt: serverTimestamp(),
      }),
    );

    // Pero el tope sigue vigente en update: 20.000 es el amount que quedó.
    await assertFails(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'transactions', 'viejo'), {
        platformFee: 20001,
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

/**
 * P-12: users/{uid}/aiReports, los reportes de respuestas del asistente.
 *
 * POR QUÉ IMPORTA: la política de Google Play para apps con IA generativa exige
 * un mecanismo dentro de la app para marcar contenido ofensivo o dañino. El
 * botón existía en la pestaña de IA y la escritura se DENEGABA, porque no había
 * `match` para esta ruta y el catch-all del final la rechazaba. Estos tests son
 * la prueba de que el botón funciona, no de que esté dibujado.
 *
 * Los campos son exactamente los que escribe `AiProvider.reportMessage`.
 */
describe('P-12: users/{uid}/aiReports', () => {
  const reports = (db: Firestore = aliceDb()) => collection(db, 'users', ALICE, 'aiReports');

  function validReport() {
    return {
      messageId: 'msg123',
      conversationId: 'conv123',
      reason: 'ofensivo',
      comment: 'La respuesta trataba mal a la persona.',
      reportedText: 'Texto de la respuesta del asistente.',
      ...stamps(),
    };
  }

  it('el dueño crea un reporte completo', async () => {
    await assertSucceeds(addDoc(reports(), validReport()));
  });

  it('acepta el reporte mínimo: sin conversationId y sin comment', async () => {
    // Es el caso real del mensaje de bienvenida, que no pertenece a ninguna
    // conversación guardada: el cliente omite los dos campos.
    await assertSucceeds(
      addDoc(reports(), {
        messageId: 'bienvenida',
        reason: 'otro',
        reportedText: 'Hola, soy tu asistente financiero.',
        ...stamps(),
      }),
    );
  });

  it('acepta los cuatro motivos del contrato', async () => {
    for (const reason of ['ofensivo', 'incorrecto', 'peligroso', 'otro']) {
      await assertSucceeds(addDoc(reports(), { ...validReport(), reason }));
    }
  });

  it('rechaza un motivo fuera del conjunto', async () => {
    for (const reason of ['spam', 'OFENSIVO', 'ofensivo ', '', null, 1, ['otro']]) {
      await assertFails(addDoc(reports(), { ...validReport(), reason }));
    }
  });

  // Un test por campo obligatorio, y no un bucle dentro de un solo `it`: si
  // falta la validación de uno, el informe dice cuál.
  for (const field of ['messageId', 'reason', 'reportedText', 'createdAt', 'updatedAt']) {
    it(`rechaza el reporte sin ${field}`, async () => {
      const data: Record<string, unknown> = validReport();
      delete data[field];
      await assertFails(addDoc(reports(), data));
    });
  }

  it('rechaza messageId vacío o que no es texto', async () => {
    for (const messageId of ['', null, 42, { id: 'x' }]) {
      await assertFails(addDoc(reports(), { ...validReport(), messageId }));
    }
  });

  it('rechaza conversationId nulo o vacío: ausente es la única forma de decir "sin conversación"', async () => {
    for (const conversationId of [null, '', 7]) {
      await assertFails(addDoc(reports(), { ...validReport(), conversationId }));
    }
  });

  it('acepta comment y reportedText en el tope y los rechaza por encima', async () => {
    await assertSucceeds(
      addDoc(reports(), { ...validReport(), comment: 'c'.repeat(1000), reportedText: 'r'.repeat(2000) }),
    );
    await assertFails(addDoc(reports(), { ...validReport(), comment: 'c'.repeat(1001) }));
    await assertFails(addDoc(reports(), { ...validReport(), reportedText: 'r'.repeat(2001) }));
  });

  it('acepta reportedText vacío: un mensaje sin texto también se puede reportar', async () => {
    await assertSucceeds(addDoc(reports(), { ...validReport(), reportedText: '' }));
  });

  it('rechaza un campo desconocido', async () => {
    await assertFails(addDoc(reports(), { ...validReport(), severidad: 'alta' }));
  });

  it('exige marcas de tiempo del servidor', async () => {
    await assertFails(addDoc(reports(), { ...validReport(), updatedAt: Timestamp.now() }));
    await assertFails(
      addDoc(reports(), {
        ...validReport(),
        createdAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')),
      }),
    );
  });

  it('el dueño lee sus reportes, de uno en uno y en lista acotada', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE, 'aiReports', 'r1'), validReport()));
    await assertSucceeds(getDoc(doc(aliceDb(), 'users', ALICE, 'aiReports', 'r1')));
    await assertSucceeds(listOf(aliceDb(), ['users', ALICE, 'aiReports'], 50));
    // El tope de la regla `list` también vale aquí.
    await assertFails(getDocs(query(collection(aliceDb(), 'users', ALICE, 'aiReports'), limit(201))));
    await assertFails(getDocs(collection(aliceDb(), 'users', ALICE, 'aiReports')));
  });

  it('NO puede modificar ni borrar un reporte ya enviado', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE, 'aiReports', 'r1'), validReport()));
    await assertFails(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'aiReports', 'r1'), {
        reason: 'otro',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(doc(aliceDb(), 'users', ALICE, 'aiReports', 'r1'), {
        comment: 'ya no me importa',
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(deleteDoc(doc(aliceDb(), 'users', ALICE, 'aiReports', 'r1')));
  });

  it('otro usuario no lee ni escribe los reportes ajenos', async () => {
    await seed((db) => setDoc(doc(db, 'users', ALICE, 'aiReports', 'r1'), validReport()));
    await assertFails(getDoc(doc(bobDb(), 'users', ALICE, 'aiReports', 'r1')));
    await assertFails(listOf(bobDb(), ['users', ALICE, 'aiReports'], 10));
    await assertFails(addDoc(reports(bobDb()), validReport()));
  });

  it('sin autenticación no se puede reportar nada', async () => {
    await assertFails(addDoc(reports(anonDb()), validReport()));
    await assertFails(listOf(anonDb(), ['users', ALICE, 'aiReports'], 10));
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
