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

/**
 * Día más alto que usan las listas de movimientos de abajo. Es el horizonte del
 * «plan» de un mes completo y sirve para comprimirlo (ver [diaEfectivo]).
 */
const DIA_PLAN_MAXIMO = 28;

/**
 * Día real que se le asigna a un movimiento.
 *
 * En los meses ya cerrados el día va tal cual. En el **mes en curso** no puede
 * ir tal cual: solo han pasado los días que han pasado, y un movimiento con
 * fecha futura no es el registro de nada. Sembrando el día 6 con el plan
 * completo, la cartola mostraba ventas del día 24 que todavía no habían
 * ocurrido: eso no puede salir en una captura de la tienda ni verlo un revisor
 * de Play.
 *
 * Así que el plan de [DIA_PLAN_MAXIMO] días se comprime en los días ya vividos
 * del mes. Con `ceil` para repartirlos en vez de amontonarlos al principio, y
 * de forma monótona: si un movimiento iba antes que otro, sigue yendo antes.
 *
 * Caso límite: sembrando el día 1, el mes entero cae en el día 1. Es poco
 * vistoso y es lo único correcto: no hay otro día donde ponerlo.
 */
function diaEfectivo(mesesAtras, dia) {
  if (mesesAtras > 0) return dia;
  const hoy = HOY.getDate();
  const comprimido = Math.ceil((dia * hoy) / DIA_PLAN_MAXIMO);
  return Math.max(1, Math.min(hoy, comprimido));
}

/** Devuelve un Date en el mes indicado (0 = el actual) y el día pedido. */
function enMes(mesesAtras, dia, hora = 12) {
  const base = new Date(HOY.getFullYear(), HOY.getMonth() - mesesAtras, 1);
  const diaPedido = diaEfectivo(mesesAtras, dia);
  // Si el día pedido no existe en ese mes (31 en febrero), se recorta al último
  // día real en vez de desbordar al mes siguiente y romper el monthKey.
  const ultimoDia = new Date(base.getFullYear(), base.getMonth() + 1, 0).getDate();
  return new Date(
    base.getFullYear(),
    base.getMonth(),
    Math.min(diaPedido, ultimoDia),
    hora,
  );
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
  // 'Cerámica' con mayúscula y tilde, igual que en `kBusinessTypes`
  // (lib/features/user_profile/domain/entities/user_profile_entity.dart). El
  // selector de "Editar perfil" marca por igualdad exacta, así que cualquier
  // otra grafia dejaría el rubro de la cuenta demo sin marcar en la pantalla.
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

// ---------------------------------------------------------------------------
// Categorías y campos del contrato C-3
// ---------------------------------------------------------------------------

/**
 * Categorías válidas, copiadas de `incomeCategories` y `expenseCategories`
 * (lib/features/finances/presentation/widgets/transaction_form_sheet.dart).
 *
 * Están aquí para que [validarDatos] falle si alguien siembra una categoría que
 * la app ya no ofrece. Hasta ahora este script usaba las genéricas viejas
 * ('Venta', 'Materiales', 'Servicios', 'Arriendo', 'Otro'): se siguen leyendo,
 * porque la categoría es texto libre, pero el gráfico «En qué se te va el mes»
 * las pinta tal cual y el formulario de edición no las sabe preseleccionar, así
 * que en una captura de la tienda salían las etiquetas de una versión anterior.
 */
const CATEGORIAS_INGRESO = [
  'Venta en feria',
  'Venta por Instagram',
  'Pedido personalizado',
  'Venta a tienda',
  'Otro ingreso',
];

const CATEGORIAS_GASTO = [
  'Insumos y materiales',
  'Arriendo del taller',
  'Gas y electricidad',
  'Envíos',
  'Comisión de plataforma',
  'Herramientas',
  'Difusión',
  'Otro gasto',
];

/**
 * Valores exactos que acepta `docType` (contrato C-3). Coinciden con
 * `TransactionDocType.wire` y con `validDocType()` de `firestore.rules`.
 */
const DOC_TYPES = ['boleta_venta', 'boleta_honorarios', 'sin_documento'];

/**
 * Tasa con la que se calcula la comisión de Mercado Pago de la demostración.
 *
 * El 3,19 % es la cifra que circula para Chile en 2026 y `docs/FICHA-PLAY.md`
 * §3 la deja marcada como **NO verificada en la fuente**: la página de costos
 * de Mercado Pago se renderiza con JavaScript y no devuelve ninguna cifra a un
 * cliente de texto (vuelto a comprobar el 6 de octubre de 2026: responde 200 y
 * en el HTML no aparece ningún porcentaje).
 *
 * Por eso aquí no se afirma que esa sea la comisión real de nadie: es el número
 * que la usuaria de la demostración anotó en su venta. Se calcula en el script
 * en vez de escribirse a mano para que cuadre con el monto y sea reproducible.
 * La app nunca aplica una tasa por su cuenta: `platformFee` es siempre lo que
 * teclea el usuario (`transaction_form_sheet.dart`).
 */
const TASA_MERCADO_PAGO = 0.0319;

/** Comisión de Mercado Pago sobre un cobro, en pesos redondeados. */
function comisionMercadoPago(monto) {
  return Math.round(monto * TASA_MERCADO_PAGO);
}

/**
 * Movimientos de los últimos tres meses.
 * `[mesesAtras, día, tipo, categoría, título, monto, descripción, extra?]`
 *
 * `extra` es opcional y solo tiene sentido en los ingresos. Lleva los dos campos
 * del contrato C-3:
 *  - `docType`: uno de [DOC_TYPES]. Con qué documento se respaldó el ingreso.
 *  - `comisionMP`: `true` para que el script calcule la comisión del medio de
 *    pago sobre el monto y la guarde en `platformFee`.
 *
 * Los dos son OPCIONALES en Firestore y a propósito solo se rellenan en el mes
 * en curso: los meses cerrados quedan SIN el campo. Es el caso real de los
 * movimientos registrados antes del contrato C-3, y de paso deja sembrada la
 * prueba de que la app los sigue leyendo (caen en `TransactionDocType.fallback`,
 * que es 'sin_documento').
 *
 * Sin días de la semana en las descripciones: antes decían «Domingo» y «Sábado
 * en la mañana» sobre fechas que, al anclarse a «hoy», caen en el día que caigan.
 */
const MOVIMIENTOS = [
  // ---- Mes actual ----
  // Seis de los siete ingresos de este mes llevan `extra`: es lo que hace
  // visible el valor hora neto, porque dos de ellos tienen comisión de Mercado
  // Pago y la pantalla puede decir cuánto se quedó el medio de pago en vez de
  // callarlo. El séptimo, la feria, se deja SIN el campo a propósito: se cobró
  // en efectivo y no se emitió nada, que es el caso del campo ausente.
  [0, 3, 'expense', 'Insumos y materiales', 'Arcilla de gres 25 kg', 48000, 'Dos sacos, proveedor Santa Elena'],
  [0, 4, 'income', 'Venta por Instagram', 'Set de 6 tazas de gres', 78000, 'Pedido por mensaje directo, envío a Ñuñoa', { docType: 'sin_documento' }],
  [0, 5, 'expense', 'Arriendo del taller', 'Arriendo taller Independencia', 320000, ''],
  [0, 7, 'income', 'Venta por Instagram', 'Pocillos ramen x 8', 96000, 'Cliente habitual, cobrado con link de pago', { docType: 'boleta_venta', comisionMP: true }],
  [0, 9, 'expense', 'Gas y electricidad', 'Balón de gas 45 kg', 62000, 'Para la quema de bizcocho'],
  [0, 11, 'income', 'Otro ingreso', 'Taller de torno (4 personas)', 160000, 'Tres horas en el taller', { docType: 'boleta_honorarios' }],
  [0, 12, 'income', 'Venta a tienda', 'Pedido tienda Nativa', 186000, '12 tazas y 6 pocillos, cobrado con link de pago', { docType: 'boleta_venta', comisionMP: true }],
  [0, 14, 'expense', 'Insumos y materiales', 'Esmalte transparente 5 L', 72000, ''],
  [0, 16, 'income', 'Pedido personalizado', 'Macetero grande esmaltado', 65000, 'Encargo para terraza', { docType: 'sin_documento' }],
  [0, 18, 'expense', 'Gas y electricidad', 'Cuenta de luz del taller', 54500, 'Mes con dos quemas'],
  [0, 19, 'income', 'Otro ingreso', 'Clase de esmaltes en escuela de oficios', 150000, 'Pagado por transferencia, sin comisión', { docType: 'boleta_honorarios' }],
  [0, 21, 'income', 'Venta en feria', 'Feria Barrio Italia', 245000, 'Se vendió casi todo lo que llevé'],
  [0, 21, 'expense', 'Difusión', 'Stand Feria Barrio Italia', 55000, ''],
  [0, 24, 'expense', 'Insumos y materiales', 'Caolín 20 kg', 29000, ''],

  // ---- Mes anterior ----
  [1, 2, 'expense', 'Arriendo del taller', 'Arriendo taller Independencia', 320000, ''],
  [1, 4, 'income', 'Venta a tienda', 'Pedido Café Lastarria', 420000, '36 tazas y 12 platos, entrega en dos tandas'],
  [1, 6, 'expense', 'Insumos y materiales', 'Arcilla de gres 25 kg', 96000, 'Cuatro sacos por el pedido del café'],
  [1, 8, 'expense', 'Herramientas', 'Set de estecas y vaciadores', 34900, ''],
  [1, 10, 'income', 'Venta por Instagram', 'Jarrón línea Atacama', 120000, ''],
  [1, 12, 'expense', 'Gas y electricidad', 'Balón de gas 45 kg', 62000, ''],
  [1, 15, 'income', 'Venta a tienda', 'Tienda Ñam (consignación)', 188000, 'Liquidación de las piezas dejadas hace dos meses'],
  [1, 17, 'expense', 'Gas y electricidad', 'Cuenta de luz del taller', 61200, ''],
  [1, 19, 'expense', 'Envíos', 'Flete de pedido a Valparaíso', 18000, ''],
  [1, 22, 'income', 'Pedido personalizado', 'Vajilla por encargo', 310000, 'Matrimonio, 12 puestos'],
  [1, 24, 'expense', 'Insumos y materiales', 'Óxido de cobalto 500 g', 54000, 'Rinde para todo el semestre'],
  [1, 27, 'expense', 'Envíos', 'Bolsas y papel de embalaje', 21500, ''],
  [1, 28, 'income', 'Venta por Instagram', 'Plato llano 26 cm x 6', 101400, ''],

  // ---- Hace dos meses ----
  // El mes de la resistencia del horno (89.000) y de la mantención del torno
  // (45.000): cierra en positivo, pero por poco. Es lo que de verdad le pasa a
  // un taller, y verlo es justo para lo que sirve la app.
  [2, 3, 'expense', 'Arriendo del taller', 'Arriendo taller Independencia', 320000, ''],
  [2, 5, 'expense', 'Herramientas', 'Repuesto de resistencia del horno', 89000, 'Se cortó la resistencia del fondo'],
  [2, 6, 'income', 'Venta en feria', 'Feria Persa Bío Bío', 135000, ''],
  [2, 9, 'expense', 'Insumos y materiales', 'Engobe blanco 10 kg', 38000, ''],
  [2, 12, 'income', 'Pedido personalizado', 'Set 6 tazas y bandeja', 89900, 'Regalo corporativo'],
  [2, 14, 'expense', 'Gas y electricidad', 'Cuenta de luz del taller', 48700, ''],
  [2, 16, 'expense', 'Herramientas', 'Mantención del torno', 45000, 'Cambio de correa y rodamientos'],
  [2, 19, 'income', 'Venta a tienda', 'Maceteros x 4 (vivero)', 115600, ''],
  [2, 21, 'income', 'Venta a tienda', 'Tienda Pueblo Nuevo (consignación)', 145000, 'Liquidación de piezas dejadas en consignación'],
  [2, 23, 'expense', 'Gas y electricidad', 'Balón de gas 45 kg', 62000, ''],
  [2, 26, 'income', 'Otro ingreso', 'Taller de esmaltes (6 personas)', 210000, ''],
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

/**
 * Gastos fijos mensuales. `[id, nombre, monto]`
 *
 * Son la REFERENCIA de lo que se paga todos los meses, y por eso no pueden
 * repetir un movimiento que ya está en la cartola.
 *
 * Lo que estaba mal: el arriendo del taller aparecía en los dos sitios, como
 * transacción de 320.000 cada mes y otra vez como gasto fijo de 320.000. En la
 * pantalla de Inicio las dos cifras salen una debajo de la otra ('Gastos' y
 * 'Gastos fijos', `home_tab.dart`), así que quien sumara pagaba el arriendo dos
 * veces. En una captura de la tienda eso es un dato que no cuadra.
 *
 * Se quedó donde se ve de verdad: en la cartola, con su fecha, y contado en el
 * balance del mes, que es la cifra grande de la pantalla. Aquí quedan solo los
 * cargos recurrentes que la usuaria NO anota uno por uno porque se pagan por
 * descuento automático. [validarDatos] vigila que no vuelvan a solaparse.
 */
const GASTOS_FIJOS = [
  ['internet-telefono', 'Internet y teléfono', 29990],
  ['contadora', 'Contadora (mensual)', 45000],
  ['seguro-taller', 'Seguro del taller', 28500],
];

// ---------------------------------------------------------------------------
// Comprobaciones previas
// ---------------------------------------------------------------------------

/** Totales por mes derivados de [MOVIMIENTOS]. Se usan dos veces: aquí y al
 * escribir los agregados, siempre con la misma fórmula. */
function totalesPorMes() {
  const totales = new Map();
  for (const [mesesAtras, dia, tipo, , , monto, , extra] of MOVIMIENTOS) {
    const monthKey = monthKeyDe(enMes(mesesAtras, dia));
    const acumulado = totales.get(monthKey) || {
      totalIncome: 0,
      totalExpenses: 0,
      transactionCount: 0,
      comisiones: 0,
    };
    if (tipo === 'income') acumulado.totalIncome += monto;
    else acumulado.totalExpenses += monto;
    if (extra && extra.comisionMP) {
      acumulado.comisiones += comisionMercadoPago(monto);
    }
    acumulado.transactionCount += 1;
    totales.set(monthKey, acumulado);
  }
  return totales;
}

/**
 * Comprueba los datos ANTES de escribir nada.
 *
 * Hay tres cosas que estos datos tienen que cumplir siempre: que los gastos
 * fijos no dupliquen transacciones, que los campos del contrato C-3 sean
 * válidos y que ningún mes cierre en rojo. Comprobarlas a ojo una vez no sirve,
 * porque las listas de arriba se van a seguir editando y lo que sale de aquí
 * acaba en una captura de la tienda; así que el script las exige en cada
 * ejecución y aborta antes de tocar Firestore.
 */
function validarDatos() {
  const errores = [];

  // 1. Ningún gasto fijo puede repetir un gasto que ya está en la cartola. Se
  //    mira por nombre contenido en el título y también por monto exacto: el
  //    arriendo duplicado coincidía en las dos cosas.
  const gastosDelMes = MOVIMIENTOS.filter(
    ([meses, , tipo]) => meses === 0 && tipo === 'expense',
  );
  for (const [, nombre, monto] of GASTOS_FIJOS) {
    const choque = gastosDelMes.find(
      ([, , , , titulo, montoTx]) =>
        montoTx === monto ||
        titulo.toLowerCase().includes(nombre.toLowerCase()),
    );
    if (choque) {
      errores.push(
        `El gasto fijo "${nombre}" (${monto}) duplica la transacción ` +
          `"${choque[4]}" (${choque[5]}). Los gastos fijos son la referencia ` +
          'mensual: no pueden volver a contar un movimiento real del mes.',
      );
    }
  }

  // 2. Categorías, tipos y campos del contrato C-3.
  MOVIMIENTOS.forEach(([, , tipo, categoria, titulo, monto, , extra], indice) => {
    const validas = tipo === 'income' ? CATEGORIAS_INGRESO : CATEGORIAS_GASTO;
    if (!validas.includes(categoria)) {
      errores.push(
        `Movimiento ${indice} ("${titulo}"): la categoría "${categoria}" no ` +
          'está entre las que ofrece la app.',
      );
    }
    if (!extra) return;
    if (tipo !== 'income') {
      errores.push(
        `Movimiento ${indice} ("${titulo}"): docType y platformFee solo ` +
          'tienen sentido en un ingreso.',
      );
    }
    if (extra.docType && !DOC_TYPES.includes(extra.docType)) {
      errores.push(
        `Movimiento ${indice} ("${titulo}"): docType "${extra.docType}" no ` +
          'es uno de los tres valores del contrato C-3.',
      );
    }
    if (extra.comisionMP) {
      const comision = comisionMercadoPago(monto);
      // Mismo tope que `validPlatformFee()` en firestore.rules.
      if (!(comision > 0 && comision <= monto)) {
        errores.push(
          `Movimiento ${indice} ("${titulo}"): la comisión ${comision} no ` +
            `cabe en el monto ${monto}.`,
        );
      }
    }
  });

  // 3. Ningún mes puede cerrar en rojo. Es dato de una ficha de tienda: un mes
  //    negativo en el selector es lo primero que se ve y no es lo que el
  //    producto quiere mostrar.
  for (const [monthKey, t] of totalesPorMes()) {
    const saldo = t.totalIncome - t.totalExpenses;
    if (saldo <= 0) {
      errores.push(
        `El mes ${monthKey} cierra con saldo ${saldo}. La cuenta de ` +
          'demostración no puede sembrar un mes en rojo.',
      );
    }
  }

  if (errores.length > 0) {
    throw new Error(
      'Los datos de demostración no son coherentes:\n  - ' +
        errores.join('\n  - '),
    );
  }
}

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
 * Subcolecciones que el sembrado deja EXACTAMENTE como las escribe este script.
 *
 * Las cuatro primeras las escribe el script. Las tres últimas no las escribe
 * nadie aquí, y por eso tenían que entrar en la lista: son las que el emulador
 * acumula mientras se prueba la app a mano, y lo que quedaba dentro NO era dato
 * de demostración.
 *
 * Comprobado en el emulador antes de ampliar la lista (6 de octubre de 2026):
 *  - `conversations/` tenía una conversación con un único mensaje del usuario y
 *    `messageCount: 0`: una pregunta que el asistente nunca respondió.
 *  - `meta/usage` tenía `chatCountLifetime: 1`, o sea un mensaje de los 25 del
 *    plan free ya gastado. La cuenta que se le entrega al revisor de Play tiene
 *    que llegar con los 25 sin gastar, y esto es lo único que los devuelve.
 *  - `aiReports/` estaba vacía. Se limpia igual: es donde caen los reportes de
 *    respuestas de la IA, y una prueba a mano deja uno dentro.
 */
const SUBCOLECCIONES = [
  'transactions',
  'inventory',
  'fixedExpenses',
  'months',
  'conversations',
  'aiReports',
  'meta',
];

/**
 * Vacía una subcolección del usuario demo. Sin esto, editar las listas de
 * arriba dejaría documentos huérfanos de la ejecución anterior.
 *
 * Borra en RECURSIVO, no con un lote de deletes sobre los documentos de primer
 * nivel. Dos razones, las dos reales:
 *  - `conversations/{id}/messages/` es una subcolección: borrar el documento
 *    padre con un `batch.delete()` deja los mensajes dentro, alcanzables por
 *    ruta y contados por cualquier lectura que los pida.
 *  - un lote de Firestore admite 500 operaciones. Con 38 movimientos sobraba
 *    sitio, pero el tope no estaba comprobado en ninguna parte y las listas de
 *    arriba se siguen editando.
 *
 * Devuelve cuántos documentos de primer nivel había, solo para el informe de
 * consola; el borrado no depende de esa cuenta.
 */
async function limpiarSubcoleccion(nombre) {
  const coleccion = db.collection(`users/${DEMO_UID}/${nombre}`);
  const snapshot = await coleccion.get();
  if (snapshot.empty) return 0;
  await db.recursiveDelete(coleccion);
  return snapshot.size;
}

async function sembrar() {
  // Antes de tocar Firestore: si los datos no cuadran, no se siembra nada.
  validarDatos();

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

  for (const nombre of SUBCOLECCIONES) {
    const borrados = await limpiarSubcoleccion(nombre);
    if (borrados > 0) console.log(`Limpieza: ${borrados} documentos en ${nombre}`);
  }

  const lote = db.batch();
  const totalesDelPeriodo = totalesPorMes();

  // ---- Transacciones ----
  MOVIMIENTOS.forEach(
    (
      [mesesAtras, dia, tipo, categoria, titulo, monto, descripcion, extra],
      indice,
    ) => {
      const fecha = enMes(mesesAtras, dia);
      const monthKey = monthKeyDe(fecha);
      // Id estable y ordenable, para que reejecutar no duplique movimientos.
      const id = `demo-${String(indice).padStart(3, '0')}`;
      const documento = {
        title: titulo,
        description: descripcion,
        amount: monto,
        type: tipo,
        category: categoria,
        date: Timestamp.fromDate(fecha),
        monthKey,
        createdAt: Timestamp.fromDate(fecha),
        updatedAt: Timestamp.fromDate(fecha),
      };

      // Contrato C-3: los dos campos son OPCIONALES y solo se escriben cuando
      // el movimiento los trae. Nunca `null`: `firestore.rules` no lo acepta a
      // propósito, para que «sin documento» tenga una sola representación
      // (el valor 'sin_documento' o el campo ausente, que se lee igual).
      if (extra && extra.docType) documento.docType = extra.docType;
      if (extra && extra.comisionMP) {
        documento.platformFee = comisionMercadoPago(monto);
      }

      lote.set(db.doc(`users/${DEMO_UID}/transactions/${id}`), documento);
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
  // functions/src/months.ts (suma del monto por tipo, suma de las comisiones de
  // los ingresos y conteo total) porque este script actúa como backend: si el
  // emulador de Functions está arriba, el trigger se dispara igual y llega al
  // mismo resultado, así que las dos escrituras convergen en vez de pelearse.
  //
  // Esa convergencia es exactamente lo que se rompió. `months/*` tenía tres
  // campos cuando se escribió este bloque; el contrato C-3 le añadió un cuarto,
  // `totalPlatformFees`, y aquí se seguía escribiendo sin él. Como el orden
  // entre el `set()` de este lote y el recálculo del trigger no está
  // garantizado, la última escritura podía ser la de tres campos, y entonces el
  // agregado del mes se quedaba SIN las comisiones: el valor hora neto de la
  // cuenta demo salía igual al bruto y nadie lo notaba, porque la cifra que
  // falta no se ve, se ve una que cuadra con otra cosa. Comprobado en el
  // emulador: los tres `months/*` estaban sin el campo.
  for (const [monthKey, totales] of totalesDelPeriodo) {
    lote.set(db.doc(`users/${DEMO_UID}/months/${monthKey}`), {
      totalIncome: totales.totalIncome,
      totalExpenses: totales.totalExpenses,
      totalPlatformFees: totales.comisiones,
      transactionCount: totales.transactionCount,
      updatedAt: ahora,
    });
  }

  await lote.commit();

  // Mismo umbral que InventoryItemEntity.status: <=, no <.
  const bajoMinimo = INVENTARIO.filter(([, , , , stock, minimo]) => stock <= minimo);
  console.log(`Transacciones: ${MOVIMIENTOS.length}`);
  console.log(`Inventario: ${INVENTARIO.length} ítems (${bajoMinimo.length} en alerta de stock)`);
  const totalFijos = GASTOS_FIJOS.reduce((suma, [, , monto]) => suma + monto, 0);
  console.log(
    `Gastos fijos: ${GASTOS_FIJOS.length} ` +
      `(${totalFijos.toLocaleString('es-CL')} CLP al mes, sin duplicar ` +
      'ninguna transacción de la cartola)',
  );
  const conDocType = MOVIMIENTOS.filter(([, , , , , , , e]) => e && e.docType);
  const conComision = MOVIMIENTOS.filter(([, , , , , , , e]) => e && e.comisionMP);
  console.log(
    `Contrato C-3: ${conDocType.length} ingresos con docType, ` +
      `${conComision.length} con comisión del medio de pago`,
  );
  console.log('');
  for (const [monthKey, t] of [...totalesDelPeriodo].sort()) {
    const saldo = t.totalIncome - t.totalExpenses;
    console.log(
      `  ${monthKey}  ingresos ${t.totalIncome.toLocaleString('es-CL')}` +
        `  gastos ${t.totalExpenses.toLocaleString('es-CL')}` +
        `  saldo ${saldo.toLocaleString('es-CL')}` +
        `  comisiones ${t.comisiones.toLocaleString('es-CL')}` +
        `  (${t.transactionCount} movimientos)`,
    );
  }
  const agregados = await comprobarAgregados(totalesDelPeriodo);

  console.log('');
  // No dice «Listo» cuando no lo está: la cuenta existe y se puede abrir, pero
  // con los agregados mal no sirve para una captura de la tienda ni para el
  // revisor, que es para lo que se siembra.
  console.log(
    agregados
      ? `Listo. Entra con ${DEMO_EMAIL} / ${DEMO_PASSWORD}`
      : `SEMBRADO INCOMPLETO (los agregados de months/ están mal). La cuenta ` +
          `${DEMO_EMAIL} / ${DEMO_PASSWORD} se abre, pero no la uses para capturas.`,
  );
  console.log('Panel de los emuladores: http://localhost:4000/firestore');
  return agregados;
}

/**
 * Vuelve a LEER `months/*` de Firestore y lo compara con lo que se sembró.
 *
 * Por qué no sobra, habiéndolos escrito tres líneas más arriba: en este mes
 * concreto el documento se escribe DOS veces, y no desde aquí. El lote de este
 * script escribe una versión, y el trigger `onTransactionWritten` recalcula el
 * mes por cada una de las 38 transacciones que acaba de ver nacer. Quién
 * commitea último no está en manos del script, así que «lo escribí» no
 * demuestra «quedó escrito»: lo único que lo demuestra es leerlo de vuelta.
 *
 * Y por eso no basta con UNA lectura correcta: la primera versión de esta
 * comprobación daba verde en el primer intento, y lo daba porque leía antes de
 * que el trigger escribiera. Con una compilación anterior del trigger —que es el
 * caso que esta comprobación existe para cazar— habría leído los cuatro campos
 * del lote de este script, dicho «correcto», y el trigger habría dejado tres
 * campos cuatro segundos después. Un verde mintiendo sobre lo que acababa de
 * sembrar.
 *
 * Así que lo que se exige es un estado ESTABLE: [LECTURAS_ESTABLES] lecturas
 * correctas seguidas, separadas un segundo. Medido en el emulador, el trigger
 * tarda unos 4 s en terminar sus recálculos desde que se commitean las
 * transacciones, así que la ventana de estabilidad lo cubre con margen.
 *
 * Devuelve `true` si los cuatro campos de los tres meses coinciden con lo
 * sembrado. No lanza: la siembra ya ocurrió, y lo útil es decir qué quedó mal.
 */
async function comprobarAgregados(totalesDelPeriodo) {
  const INTENTOS = 20;
  const ESPERA_MS = 1000;
  const LECTURAS_ESTABLES = 6;

  const esperados = new Map(
    [...totalesDelPeriodo].map(([monthKey, t]) => [
      monthKey,
      {
        totalIncome: t.totalIncome,
        totalExpenses: t.totalExpenses,
        totalPlatformFees: t.comisiones,
        transactionCount: t.transactionCount,
      },
    ]),
  );

  let diferencias = [];
  let correctasSeguidas = 0;
  for (let intento = 1; intento <= INTENTOS; intento += 1) {
    const snapshot = await db.collection(`users/${DEMO_UID}/months`).get();
    const leidos = new Map(snapshot.docs.map((doc) => [doc.id, doc.data()]));
    diferencias = [];

    for (const [monthKey, esperado] of esperados) {
      const real = leidos.get(monthKey);
      if (!real) {
        diferencias.push(`${monthKey}: el documento no existe`);
        continue;
      }
      for (const [campo, valor] of Object.entries(esperado)) {
        if (real[campo] === undefined) {
          diferencias.push(`${monthKey}.${campo}: falta el campo`);
        } else if (real[campo] !== valor) {
          diferencias.push(`${monthKey}.${campo}: ${real[campo]}, se esperaba ${valor}`);
        }
      }
    }
    for (const monthKey of leidos.keys()) {
      if (!esperados.has(monthKey)) {
        diferencias.push(`${monthKey}: mes de sobra, no lo siembra este script`);
      }
    }

    if (diferencias.length === 0) {
      correctasSeguidas += 1;
      if (correctasSeguidas >= LECTURAS_ESTABLES) {
        console.log('');
        console.log(
          `Agregados comprobados LEYÉNDOLOS de Firestore: ${esperados.size} meses ` +
            `con los cuatro campos correctos en ${LECTURAS_ESTABLES} lecturas ` +
            `seguidas (${intento} en total, ${LECTURAS_ESTABLES - 1} s estables).`,
        );
        for (const [monthKey, real] of [...leidos].sort()) {
          console.log(
            `  months/${monthKey}  totalIncome ${real.totalIncome}` +
              `  totalExpenses ${real.totalExpenses}` +
              `  totalPlatformFees ${real.totalPlatformFees}` +
              `  transactionCount ${real.transactionCount}`,
          );
        }
        return true;
      }
    } else {
      // Una lectura mala tira por tierra la racha: lo que se exige es que el
      // estado correcto se MANTENGA, no que haya aparecido alguna vez.
      correctasSeguidas = 0;
    }

    if (intento < INTENTOS) {
      await new Promise((resolve) => setTimeout(resolve, ESPERA_MS));
    }
  }

  console.error('');
  console.error(
    `Los agregados de months/ NO cuadran después de ${INTENTOS} lecturas ` +
      `(${(INTENTOS * ESPERA_MS) / 1000} s). Las transacciones sí se sembraron; ` +
      'lo que está mal es el agregado, y la app y el asistente leen de ahí:',
  );
  if (diferencias.length === 0) {
    // La última lectura era correcta, pero la racha nunca llegó a
    // [LECTURAS_ESTABLES]: algo sigue reescribiendo los agregados. Decirlo así
    // y no «no cuadran» a secas, porque el síntoma es distinto.
    console.error(
      `  - la última lectura era correcta, pero nunca hubo ${LECTURAS_ESTABLES} ` +
        'seguidas: algo está reescribiendo months/ sin parar.',
    );
  }
  diferencias.forEach((d) => console.error(`  - ${d}`));
  console.error(
    'Causa más probable: el emulador de Functions corre una compilación ' +
      'anterior de functions/src/months.ts. Reconstruye con ' +
      '`npm --prefix functions run build` y vuelve a sembrar.',
  );
  return false;
}

sembrar().then(
  (agregadosCorrectos) => process.exit(agregadosCorrectos ? 0 : 1),
  (error) => {
    console.error('Falló la siembra:', error);
    process.exit(1);
  },
);
