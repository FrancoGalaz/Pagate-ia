#!/usr/bin/env node
/**
 * Siembra la cuenta de demostración de Págate-IA en los emuladores de Firebase.
 *
 * Para qué sirve:
 *  - Capturas de la ficha de Google Play con datos que se ven reales.
 *  - Que el equipo de revisión de Play pueda entrar y evaluar algo: con el
 *    registro abierto un revisor puede crearse una cuenta, pero llega a un
 *    panel vacío donde no hay nada que revisar.
 *  - Probar a mano los flujos de la app sin teclear treinta movimientos.
 *
 * IMPORTANTE: escribe SOLO contra los emuladores. Antes de inicializar el SDK
 * comprueba que FIRESTORE_EMULATOR_HOST y FIREBASE_AUTH_EMULATOR_HOST estén
 * definidos y aborta si faltan. Es la única salvaguarda real contra volcar
 * datos de mentira en el proyecto de producción, porque el Admin SDK no pasa
 * por firestore.rules y escribiría sin pedir permiso.
 *
 * Uso (el detalle está en scripts/README.md):
 *
 *   # 1. En otra terminal, con los emuladores arriba:
 *   ./scripts/dev.sh
 *
 *   # 2. Aquí:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
 *   GCLOUD_PROJECT=pagate-17211 \
 *   node scripts/seed-demo.js
 *
 * Es idempotente: el uid y los ids de documento son fijos y las subcolecciones
 * se vacían antes de escribir, así que volver a ejecutarlo deja exactamente el
 * mismo estado en vez de duplicar nada.
 */

'use strict';

const path = require('node:path');
const { createRequire } = require('node:module');

const REPO_ROOT = path.resolve(__dirname, '..');

// firebase-admin ya es dependencia de functions/; se reutiliza esa instalación
// en lugar de añadir un node_modules más al repositorio solo para este script.
//
// Se importan los submódulos y no el paquete raíz: firebase-admin 14 eliminó la
// API con espacios de nombres (admin.auth(), admin.firestore()) y el raíz solo
// exporta ya initializeApp y compañía.
let initializeApp;
let getAuth;
let getFirestore;
let Timestamp;
try {
  const requireFromFunctions = createRequire(
    path.join(REPO_ROOT, 'functions', 'package.json'),
  );
  ({ initializeApp } = requireFromFunctions('firebase-admin/app'));
  ({ getAuth } = requireFromFunctions('firebase-admin/auth'));
  ({ getFirestore, Timestamp } = requireFromFunctions('firebase-admin/firestore'));
} catch (error) {
  console.error(
    'No se pudo cargar firebase-admin desde functions/.\n' +
      'Instala antes las dependencias del backend:\n' +
      '  npm --prefix functions ci\n',
  );
  console.error(error.message);
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Salvaguarda: emuladores obligatorios
// ---------------------------------------------------------------------------

const REQUIRED_ENV = ['FIRESTORE_EMULATOR_HOST', 'FIREBASE_AUTH_EMULATOR_HOST'];
const missing = REQUIRED_ENV.filter((name) => !process.env[name]);
if (missing.length > 0) {
  console.error(
    'Este script solo puede escribir en los emuladores.\n' +
      `Faltan estas variables de entorno: ${missing.join(', ')}\n\n` +
      'Ejemplo:\n' +
      '  FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \\\n' +
      '  FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \\\n' +
      '  GCLOUD_PROJECT=pagate-17211 \\\n' +
      '  node scripts/seed-demo.js\n',
  );
  process.exit(1);
}

const PROJECT_ID =
  process.env.GCLOUD_PROJECT || process.env.FIREBASE_PROJECT_ID || 'pagate-17211';

const app = initializeApp({ projectId: PROJECT_ID });
const auth = getAuth(app);
const db = getFirestore(app);

// ---------------------------------------------------------------------------
// Credenciales de la cuenta de demostración
// ---------------------------------------------------------------------------

// uid fijo: hace el script idempotente y mantiene estable la ruta users/{uid}
// para poder inspeccionarla en el panel del emulador.
const DEMO_UID = 'demo-pagate-cl';
const DEMO_EMAIL = 'demo@pagate.cl';
const DEMO_PASSWORD = 'PagateDemo2026';

// ---------------------------------------------------------------------------
// Fechas
//
// Todo se ancla a "hoy" para que el panel siempre muestre el mes en curso con
// movimiento, sin tener que reescribir el script cada mes. enMes(0) es el mes
// actual, enMes(1) el anterior, enMes(2) el de antes.
// ---------------------------------------------------------------------------

const HOY = new Date();

/** Devuelve un Date en el mes indicado (0 = el actual) y el día pedido. */
function enMes(mesesAtras, dia, hora = 12) {
  const base = new Date(HOY.getFullYear(), HOY.getMonth() - mesesAtras, 1);
  // Si el día pedido no existe en ese mes (31 en febrero), se recorta al último
  // día real en vez de desbordar al mes siguiente y romper el monthKey.
  const ultimoDia = new Date(base.getFullYear(), base.getMonth() + 1, 0).getDate();
  return new Date(base.getFullYear(), base.getMonth(), Math.min(dia, ultimoDia), hora);
}

/** monthKey 'yyyy-MM' derivado de la fecha, igual que lo hace el cliente. */
function monthKeyDe(fecha) {
  const mes = String(fecha.getMonth() + 1).padStart(2, '0');
  return `${fecha.getFullYear()}-${mes}`;
}

// ---------------------------------------------------------------------------
// Datos: taller de cerámica en Santiago
//
// Los montos son pesos chilenos de mercado: arcilla de gres en torno a 1.900
// $/kg, balón de gas de 45 kg cerca de 62.000, arriendo de un taller chico en
// Independencia alrededor de 320.000. Los saldos mensuales salen de sumar los
// movimientos; no hay ninguna cifra puesta para que el resultado "cuadre".
// ---------------------------------------------------------------------------

const PERFIL = {
  name: 'Camila Rojas',
  businessName: 'Greda Austral',
  // OJO: 'Cerámica' no está en kBusinessTypes
  // (lib/features/user_profile/domain/entities/user_profile_entity.dart:12-20),
  // que solo lista oficios metalmecánicos y de construcción. El modelo acepta
  // cualquier string y la pantalla de perfil lo muestra tal cual, pero el
  // selector de "editar perfil" no lo mostrará marcado. Queda reportado: el
  // arreglo es de lib/, que no es este carril.
  businessType: 'Cerámica',
  currency: 'CLP',
  monthlyGoal: 1200000,
  avatarInitials: 'CR',
  plan: 'free',
  hourlyRate: {
    desiredMonthlySalary: 900000,
    availableHoursPerMonth: 120,
    // 900.000 / 120 = 7.500, que es exactamente la fórmula de
    // HourlyRateEntity.hourlyValue. Se guarda ya calculado porque el cliente lo
    // lee del documento en vez de recalcularlo.
    hourlyValue: 7500,
  },
};

/**
 * Movimientos de los últimos tres meses.
 * [mesesAtras, día, tipo, categoría, título, monto, descripción]
 *
 * Las categorías son las seis de transactionCategories
 * (lib/features/finances/presentation/widgets/transaction_form_sheet.dart:15-22):
 * Venta, Materiales, Herramientas, Servicios, Arriendo y Otro. Usar cualquier
 * otra dejaría movimientos que el formulario de edición no sabría preseleccionar.
 */
const MOVIMIENTOS = [
  // ---- Mes actual ----
  [0, 3, 'expense', 'Materiales', 'Arcilla de gres 25 kg', 48000, 'Dos sacos, proveedor Santa Elena'],
  [0, 4, 'income', 'Venta', 'Set de 6 tazas de gres', 78000, 'Pedido por Instagram, envío a Ñuñoa'],
  [0, 5, 'expense', 'Arriendo', 'Arriendo taller Independencia', 320000, ''],
  [0, 7, 'income', 'Venta', 'Pocillos ramen x 8', 96000, 'Cliente habitual, segunda compra'],
  [0, 9, 'expense', 'Servicios', 'Balón de gas 45 kg', 62000, 'Para la quema de bizcocho'],
  [0, 11, 'income', 'Venta', 'Taller de torno (4 personas)', 160000, 'Sábado en la mañana, 3 horas'],
  [0, 14, 'expense', 'Materiales', 'Esmalte transparente 5 L', 72000, ''],
  [0, 16, 'income', 'Venta', 'Macetero grande esmaltado', 65000, 'Encargo para terraza'],
  [0, 18, 'expense', 'Servicios', 'Cuenta de luz del taller', 54500, 'Mes con dos quemas'],
  [0, 21, 'income', 'Venta', 'Feria Barrio Italia', 245000, 'Domingo, buen día de ventas'],
  [0, 21, 'expense', 'Otro', 'Stand Feria Barrio Italia', 55000, ''],
  [0, 24, 'expense', 'Materiales', 'Caolín 20 kg', 29000, ''],

  // ---- Mes anterior ----
  [1, 2, 'expense', 'Arriendo', 'Arriendo taller Independencia', 320000, ''],
  [1, 4, 'income', 'Venta', 'Pedido Café Lastarria', 420000, '36 tazas y 12 platos, entrega en dos tandas'],
  [1, 6, 'expense', 'Materiales', 'Arcilla de gres 25 kg', 96000, 'Cuatro sacos por el pedido del café'],
  [1, 8, 'expense', 'Herramientas', 'Set de estecas y vaciadores', 34900, ''],
  [1, 10, 'income', 'Venta', 'Jarrón línea Atacama', 120000, ''],
  [1, 12, 'expense', 'Servicios', 'Balón de gas 45 kg', 62000, ''],
  [1, 15, 'income', 'Venta', 'Tienda Ñam (consignación)', 188000, 'Liquidación de las piezas dejadas en marzo'],
  [1, 17, 'expense', 'Servicios', 'Cuenta de luz del taller', 61200, ''],
  [1, 19, 'expense', 'Otro', 'Flete de pedido a Valparaíso', 18000, ''],
  [1, 22, 'income', 'Venta', 'Vajilla por encargo', 310000, 'Matrimonio, 12 puestos'],
  [1, 24, 'expense', 'Materiales', 'Óxido de cobalto 500 g', 54000, 'Rinde para todo el semestre'],
  [1, 27, 'expense', 'Otro', 'Bolsas y papel de embalaje', 21500, ''],
  [1, 28, 'income', 'Venta', 'Plato llano 26 cm x 6', 101400, ''],

  // ---- Hace dos meses ----
  [2, 3, 'expense', 'Arriendo', 'Arriendo taller Independencia', 320000, ''],
  [2, 5, 'expense', 'Herramientas', 'Repuesto de resistencia del horno', 89000, 'Se cortó la resistencia del fondo'],
  [2, 6, 'income', 'Venta', 'Feria Persa Bío Bío', 135000, ''],
  [2, 9, 'expense', 'Materiales', 'Engobe blanco 10 kg', 38000, ''],
  [2, 12, 'income', 'Venta', 'Set 6 tazas y bandeja', 89900, 'Regalo corporativo'],
  [2, 14, 'expense', 'Servicios', 'Cuenta de luz del taller', 48700, ''],
  [2, 16, 'expense', 'Herramientas', 'Mantención del torno', 45000, 'Cambio de correa y rodamientos'],
  [2, 19, 'income', 'Venta', 'Maceteros x 4 (vivero)', 115600, ''],
  [2, 23, 'expense', 'Servicios', 'Balón de gas 45 kg', 62000, ''],
  [2, 26, 'income', 'Venta', 'Taller de esmaltes (6 personas)', 210000, ''],
];

/**
 * Inventario. Cuatro ítems quedan en alerta a propósito, para que la pantalla
 * de inventario muestre el estado "Bajo" en las capturas sin teñirla entera.
 *
 * OJO con el umbral: la app marca "Bajo" con `stock <= minStock`
 * (lib/features/inventory/domain/entities/inventory_item_entity.dart:52), no
 * con `<`. Un ítem con stock igual al mínimo YA aparece en alerta, así que los
 * que deben salir en verde llevan al menos una unidad de margen.
 * [id, nombre, tipo, precio, stock, mínimo, unidad, proveedor, código]
 */
const INVENTARIO = [
  ['taza-gres-300', 'Taza de gres esmaltada 300 ml', 'product', 14900, 24, 10, 'unidad', null, 'TZ-300'],
  ['pocillo-ramen', 'Pocillo ramen 900 ml', 'product', 22900, 6, 8, 'unidad', null, 'PR-900'],
  ['macetero-20', 'Macetero esmaltado 20 cm', 'product', 28900, 11, 6, 'unidad', null, 'MC-20'],
  ['plato-llano-26', 'Plato llano 26 cm', 'product', 16900, 3, 12, 'unidad', null, 'PL-26'],
  ['jarron-atacama', 'Jarrón línea Atacama', 'product', 54900, 4, 3, 'unidad', null, 'JA-01'],
  ['set-6-bandeja', 'Set 6 tazas y bandeja', 'product', 89900, 4, 2, 'set', null, 'ST-06'],
  ['arcilla-gres', 'Arcilla de gres chilena', 'material', 1920, 75, 50, 'kg', 'Cerámica Santa Elena', null],
  ['caolin', 'Caolín', 'material', 1450, 18, 25, 'kg', 'Minerales Illapel', null],
  ['esmalte-transparente', 'Esmalte transparente brillante', 'material', 14400, 4, 3, 'litro', 'Esmaltes del Sur', null],
  ['oxido-cobalto', 'Óxido de cobalto', 'material', 108000, 2, 1, 'kg', 'Esmaltes del Sur', null],
  ['balon-gas-45', 'Balón de gas 45 kg', 'material', 62000, 3, 1, 'balón', 'Abastible', null],
  ['caja-30', 'Caja de cartón 30x30', 'material', 690, 40, 60, 'unidad', 'Embalajes Maipú', null],
];

/** Gastos fijos mensuales. [id, nombre, monto] */
const GASTOS_FIJOS = [
  ['arriendo-taller', 'Arriendo taller', 320000],
  ['internet-telefono', 'Internet y teléfono', 29990],
  ['contadora', 'Contadora (mensual)', 45000],
  ['seguro-taller', 'Seguro del taller', 28500],
];

// ---------------------------------------------------------------------------
// Siembra
// ---------------------------------------------------------------------------

async function crearUsuarioAuth() {
  try {
    await auth.getUser(DEMO_UID);
    // Ya existe de una ejecución anterior: se reescriben las credenciales por
    // si cambió la contraseña, en vez de fallar.
    await auth.updateUser(DEMO_UID, {
      email: DEMO_EMAIL,
      password: DEMO_PASSWORD,
      displayName: PERFIL.name,
      emailVerified: true,
    });
    return 'actualizado';
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await auth.createUser({
      uid: DEMO_UID,
      email: DEMO_EMAIL,
      password: DEMO_PASSWORD,
      displayName: PERFIL.name,
      emailVerified: true,
    });
    return 'creado';
  }
}

/**
 * Vacía una subcolección del usuario demo. Sin esto, editar las listas de
 * arriba dejaría documentos huérfanos de la ejecución anterior.
 */
async function limpiarSubcoleccion(nombre) {
  const snapshot = await db.collection(`users/${DEMO_UID}/${nombre}`).get();
  if (snapshot.empty) return 0;
  const lote = db.batch();
  snapshot.docs.forEach((doc) => lote.delete(doc.ref));
  await lote.commit();
  return snapshot.size;
}

async function sembrar() {
  const estadoAuth = await crearUsuarioAuth();
  console.log(`Auth: usuario ${DEMO_EMAIL} ${estadoAuth} (uid ${DEMO_UID})`);

  const ahora = Timestamp.now();
  // La cuenta se creó hace tres meses: es lo coherente con el historial.
  const creadoEl = Timestamp.fromDate(enMes(3, 1, 9));

  await db.doc(`users/${DEMO_UID}`).set({
    ...PERFIL,
    createdAt: creadoEl,
    updatedAt: ahora,
  });
  console.log(
    `Perfil: ${PERFIL.name} · ${PERFIL.businessName} · ` +
      `meta ${PERFIL.monthlyGoal.toLocaleString('es-CL')} CLP · ` +
      `valor hora ${PERFIL.hourlyRate.hourlyValue.toLocaleString('es-CL')} CLP`,
  );

  for (const nombre of ['transactions', 'inventory', 'fixedExpenses', 'months']) {
    const borrados = await limpiarSubcoleccion(nombre);
    if (borrados > 0) console.log(`Limpieza: ${borrados} documentos en ${nombre}`);
  }

  const lote = db.batch();
  const totalesPorMes = new Map();

  // ---- Transacciones ----
  MOVIMIENTOS.forEach(
    ([mesesAtras, dia, tipo, categoria, titulo, monto, descripcion], indice) => {
      const fecha = enMes(mesesAtras, dia);
      const monthKey = monthKeyDe(fecha);
      // Id estable y ordenable, para que reejecutar no duplique movimientos.
      const id = `demo-${String(indice).padStart(3, '0')}`;
      lote.set(db.doc(`users/${DEMO_UID}/transactions/${id}`), {
        title: titulo,
        description: descripcion,
        amount: monto,
        type: tipo,
        category: categoria,
        date: Timestamp.fromDate(fecha),
        monthKey,
        createdAt: Timestamp.fromDate(fecha),
        updatedAt: Timestamp.fromDate(fecha),
      });

      const acumulado = totalesPorMes.get(monthKey) ||
        { totalIncome: 0, totalExpenses: 0, transactionCount: 0 };
      if (tipo === 'income') acumulado.totalIncome += monto;
      else acumulado.totalExpenses += monto;
      acumulado.transactionCount += 1;
      totalesPorMes.set(monthKey, acumulado);
    },
  );

  // ---- Inventario ----
  INVENTARIO.forEach(
    ([id, nombre, tipo, precio, stock, minimo, unidad, proveedor, codigo]) => {
      lote.set(db.doc(`users/${DEMO_UID}/inventory/${id}`), {
        name: nombre,
        type: tipo,
        price: precio,
        stock,
        minStock: minimo,
        unit: unidad,
        supplier: proveedor,
        code: codigo,
        createdAt: creadoEl,
        updatedAt: ahora,
      });
    },
  );

  // ---- Gastos fijos ----
  GASTOS_FIJOS.forEach(([id, nombre, monto]) => {
    lote.set(db.doc(`users/${DEMO_UID}/fixedExpenses/${id}`), {
      name: nombre,
      amount: monto,
      createdAt: creadoEl,
      updatedAt: ahora,
    });
  });

  // ---- Agregados mensuales ----
  // En producción los escribe el trigger onTransactionWritten y el cliente
  // nunca los toca. Aquí se calculan con la MISMA fórmula que
  // functions/src/months.ts (suma del monto por tipo y conteo total) porque
  // este script actúa como backend: si el emulador de Functions está arriba, el
  // trigger se dispara igual y llega al mismo resultado, así que las dos
  // escrituras convergen en vez de pelearse.
  for (const [monthKey, totales] of totalesPorMes) {
    lote.set(db.doc(`users/${DEMO_UID}/months/${monthKey}`), {
      ...totales,
      updatedAt: ahora,
    });
  }

  await lote.commit();

  // Mismo umbral que InventoryItemEntity.status: <=, no <.
  const bajoMinimo = INVENTARIO.filter(([, , , , stock, minimo]) => stock <= minimo);
  console.log(`Transacciones: ${MOVIMIENTOS.length}`);
  console.log(`Inventario: ${INVENTARIO.length} ítems (${bajoMinimo.length} en alerta de stock)`);
  console.log(`Gastos fijos: ${GASTOS_FIJOS.length}`);
  console.log('');
  for (const [monthKey, t] of [...totalesPorMes].sort()) {
    const saldo = t.totalIncome - t.totalExpenses;
    console.log(
      `  ${monthKey}  ingresos ${t.totalIncome.toLocaleString('es-CL')}` +
        `  gastos ${t.totalExpenses.toLocaleString('es-CL')}` +
        `  saldo ${saldo.toLocaleString('es-CL')}` +
        `  (${t.transactionCount} movimientos)`,
    );
  }
  console.log('');
  console.log(`Listo. Entra con ${DEMO_EMAIL} / ${DEMO_PASSWORD}`);
  console.log('Panel de los emuladores: http://localhost:4000/firestore');
}

sembrar().then(
  () => process.exit(0),
  (error) => {
    console.error('Falló la siembra:', error);
    process.exit(1);
  },
);
