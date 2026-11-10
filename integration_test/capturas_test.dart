// Capturas de todas las pantallas, contra los emuladores de Firebase, en el
// emulador de Android. No corre con `flutter test`: se lanza con
// `scripts/capturas.sh`, que usa `flutter drive` y el driver de
// `test_driver/integration_test.dart` para guardar los PNG en la máquina.
//
// Cada pantalla se captura una vez. Si su contenido es más alto que la
// pantalla, se captura además cada tramo del scroll (`_p2`, `_p3`, …).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagate_ia/core/config/env.dart';
import 'package:pagate_ia/core/config/firebase_bootstrap.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/features/auth/presentation/widgets/bootstrap_error_app.dart';
import 'package:pagate_ia/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:pagate_ia/features/dashboard/presentation/pages/eliminar_cuenta_screen.dart';
import 'package:pagate_ia/features/finances/data/datasources/finances_firebase_datasource.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/hourly_value/data/datasources/hourly_rate_local_datasource.dart';
import 'package:pagate_ia/features/hourly_value/data/models/hourly_rate_model.dart';
import 'package:pagate_ia/features/inventory/data/datasources/inventory_firebase_datasource.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:pagate_ia/features/receipt_scan/data/parsers/local_line_item_parser.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_document.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_reading.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/scanned_line_item.dart';
import 'package:pagate_ia/features/receipt_scan/domain/repositories/receipt_scan_repository.dart';
import 'package:pagate_ia/features/receipt_scan/presentation/pages/lectura_boleta_screen.dart';
import 'package:pagate_ia/features/receipt_scan/presentation/widgets/hoja_origen_de_ficha.dart';
import 'package:pagate_ia/features/user_profile/data/datasources/user_profile_firebase_datasource.dart';
import 'package:pagate_ia/features/user_profile/data/models/user_profile_model.dart';
import 'package:pagate_ia/main.dart';
import 'package:provider/provider.dart';

/// Desde el emulador de Android, la máquina es 10.0.2.2.
const _host = '10.0.2.2';
const _proyecto = 'pagate-17211';
const _clave = 'clave-123456';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capturas de todas las pantallas', (final tester) async {
    expect(
      Env.isDev,
      isTrue,
      reason: 'correr con --dart-define=PAGATE_ENV=dev',
    );
    await bootstrapFirebase();
    await FirebaseAuth.instance.signOut();
    await binding.convertFlutterSurfaceToImage();

    final c = _Capturador(tester, binding);
    final correo = 'camila${DateTime.now().millisecondsSinceEpoch}@taller.cl';

    // ─── Error de arranque ─────────────────────────────────────────────
    await tester.pumpWidget(
      BootstrapErrorApp(
        error: StateError('sin conexión'),
        onRetry: () {},
        mostrarDetalle: false,
      ),
    );
    await c.capturar('error_arranque');

    // ─── Bienvenida y registro ─────────────────────────────────────────
    await tester.pumpWidget(const PagateIAApp());
    await c.esperar(find.text('Crear cuenta'));
    await c.capturar('bienvenida');

    await c.tocar(find.text('Crear cuenta'));
    await c.esperar(find.text('Camila Rojas'));
    final campos = find.byType(EditableText);
    await tester.enterText(campos.at(0), 'Camila Rojas');
    await tester.enterText(campos.at(1), correo);
    await tester.enterText(campos.at(2), _clave);
    await c.capturar('registro');

    await c.tocar(find.text('Crear cuenta').last);
    await c.esperar(find.text('Nombre de tu taller'));
    await c.capturar('onboarding');

    // ─── Datos de ejemplo ──────────────────────────────────────────────
    // Primero solo el perfil: una cuenta recién creada, sin movimientos ni
    // valor hora, que ve «Primeros pasos».
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _sembrarPerfil(uid);
    await c.esperar(find.byType(DashboardScreen));
    await c.esperar(find.text('Primeros pasos'));
    await c.capturar('inicio_primeros_pasos');

    await _sembrar(uid);
    await c.esperar(find.textContaining('60.500'));
    await c.capturar('inicio_aviso_verificar_correo');

    // Verifica el correo en el emulador y vuelve a entrar: así los
    // providers del usuario se crean de nuevo y el chat carga la
    // conversación sembrada.
    await _verificarCorreo(uid);
    final auth = tester
        .element(find.byType(DashboardScreen))
        .read<FirebaseAuthService>();
    final cierre = auth.cerrarSesion();
    await tester.pump();
    await cierre;

    // ─── Login ─────────────────────────────────────────────────────────
    await c.esperar(find.textContaining('¿Ya tienes cuenta?'));
    await c.tocar(find.textContaining('¿Ya tienes cuenta?'));
    await c.esperar(find.text('Iniciar sesión'));
    final login = find.byType(EditableText);
    await tester.enterText(login.at(0), correo);
    await tester.enterText(login.at(1), _clave);
    await c.capturar('login');
    await c.tocar(find.text('Iniciar sesión').last);
    await c.esperar(find.byType(DashboardScreen));

    // ─── Las cinco pestañas ────────────────────────────────────────────
    await c.esperar(find.text('Inicio'));
    await c.capturar('inicio');

    // ─── Registrar movimiento (la hoja que abre «+ Ingreso») ──────────
    await c.tocar(find.text('+ Ingreso'));
    await c.esperar(find.text('Título'));
    await c.capturar('registrar_movimiento');
    Navigator.of(tester.element(find.text('Título'))).pop();
    await c.asentar();

    for (final (pestana, nombre) in [
      ('Finanzas', 'finanzas'),
      ('Inventario', 'inventario'),
      ('IA', 'ia_chat'),
      ('Perfil', 'perfil'),
    ]) {
      await c.tocar(find.text(pestana).last);
      await c.asentar();
      if (nombre == 'ia_chat') {
        await c.esperar(find.textContaining('esmalte'));
      }
      await c.capturar(nombre);
      if (nombre == 'finanzas') {
        // El mismo selector, con «Año»: la suma del año y un mes por fila.
        await c.tocar(find.text('Año'));
        await c.asentar();
        await c.capturar('finanzas_anio');
        await c.tocar(find.text('Este mes'));
        await c.asentar();
      }
    }

    // ─── Lector de boletas, fase de revisión ───────────────────────────
    final contexto = tester.element(find.byType(DashboardScreen));
    abrirLecturaDeBoleta(
      contexto,
      documento: const ReceiptDocument(
        path: '/boleta-de-ejemplo.jpg',
        mimeType: 'image/jpeg',
        source: ReceiptScanSource.camara,
      ),
      inventario: contexto.read<InventoryProvider>(),
      repositorio: _BoletaDeEjemplo(),
    ).ignore();
    await c.esperar(find.textContaining('Arcilla gres'));
    await c.capturar('lector_boletas_revision');
    Navigator.of(tester.element(find.byType(LecturaBoletaScreen))).pop();
    await c.asentar();

    // ─── Configuración y sus confirmaciones ────────────────────────────
    await c.tocar(find.text('Configuración'));
    await c.esperar(find.text('Negocio'));
    await c.capturar('configuracion');

    final borrar = find.text('Borrar historial del asistente');
    await tester.scrollUntilVisible(borrar, 300);
    await c.tocar(borrar);
    await c.esperar(find.text('¿Borrar el historial?'));
    await c.capturar('confirmar_borrar_historial');
    await c.tocar(find.text('Cancelar'));
    await c.asentar();

    final eliminar = find.text('Eliminar cuenta');
    await tester.scrollUntilVisible(eliminar, 300);
    await c.tocar(eliminar);
    await c.esperar(find.byType(EliminarCuentaScreen));
    await c.capturar('eliminar_cuenta');
    // Con letra grande el campo queda fuera de la ListView y no existe hasta
    // que se llega a él.
    final confirmacion = find.descendant(
      of: find.byType(EliminarCuentaScreen),
      matching: find.byType(EditableText),
    );
    await tester.scrollUntilVisible(
      confirmacion,
      200,
      scrollable: find
          .descendant(
            of: find.byType(EliminarCuentaScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(confirmacion, 'ELIMINAR');
    await c.capturar('eliminar_cuenta_confirmada');
  });
}

/// Toma las capturas con un número correlativo y recorre el scroll.
class _Capturador {
  _Capturador(this.tester, this.binding);

  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  var _n = 0;

  /// `pumpAndSettle` con tope: si hay una animación infinita (un spinner),
  /// se conforma con unos cuadros.
  Future<void> asentar() async {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
    } on FlutterError {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  /// Toca [finder] después de llevarlo a la pantalla: con letra grande
  /// muchos botones quedan debajo del scroll y el toque no les llega.
  Future<void> tocar(final Finder finder) async {
    await tester.ensureVisible(finder);
    await asentar();
    await tester.tap(finder);
  }

  /// Espera a que aparezca [finder] (datos de Firestore, navegación).
  Future<void> esperar(final Finder finder) async {
    final limite = DateTime.now().add(const Duration(seconds: 30));
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(limite)) {
        throw TestFailure('No apareció: $finder');
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    await asentar();
  }

  Future<void> capturar(final String pantalla) async {
    _n++;
    final base = '${_n.toString().padLeft(2, '0')}_$pantalla';
    FocusManager.instance.primaryFocus?.unfocus();
    await asentar();
    await binding.takeScreenshot(base);

    final scroll = _scrollPrincipal();
    if (scroll == null) return;
    final p = scroll.position;
    var parte = 2;
    while (p.pixels < p.maxScrollExtent - 1) {
      p.jumpTo(
        math.min(p.pixels + p.viewportDimension * 0.85, p.maxScrollExtent),
      );
      await asentar();
      await binding.takeScreenshot('${base}_p$parte');
      parte++;
    }
    p.jumpTo(0);
    await asentar();
  }

  /// El scroll vertical con más contenido fuera de la pantalla, si hay.
  ScrollableState? _scrollPrincipal() {
    ScrollableState? mejor;
    var mayor = 1.0;
    for (final e in find.byType(Scrollable).evaluate()) {
      final s = (e as StatefulElement).state as ScrollableState;
      final p = s.position;
      if (p.axis != Axis.vertical || !p.hasContentDimensions) continue;
      if (p.maxScrollExtent > mayor) {
        mayor = p.maxScrollExtent;
        mejor = s;
      }
    }
    return mejor;
  }
}

// ─── Datos de ejemplo ────────────────────────────────────────────────────

Future<void> _sembrarPerfil(final String uid) => UserProfileFirebaseDatasource(
  firestore: FirebaseFirestore.instance,
  userId: uid,
).saveProfile(
  const UserProfileModel(
    id: '',
    name: 'Camila Rojas',
    businessName: 'Greda Austral',
    businessType: 'Cerámica',
    currency: 'CLP',
    monthlyGoal: 900000,
    isPro: false,
    avatarInitials: 'CR',
  ),
);

Future<void> _sembrar(final String uid) async {
  final db = FirebaseFirestore.instance;

  await HourlyRateLocalDataSource(firestore: db, userId: uid).saveHourlyRate(
    const HourlyRateModel(
      desiredMonthlySalary: 850000,
      availableHoursPerMonth: 120,
    ),
  );

  final finanzas = FinancesFirebaseDataSource(firestore: db, userId: uid);
  final hoy = DateTime.now();
  DateTime dia(final int mesesAtras, final int d) =>
      DateTime(hoy.year, hoy.month - mesesAtras, math.min(d, 28), 12);
  final movimientos = [
    // Mes anterior.
    (
      'Feria del Parque Forestal',
      186000,
      'Venta en feria',
      1,
      5,
      TransactionDocType.boletaVenta,
      0,
    ),
    (
      'Tazas por Instagram',
      64000,
      'Venta por Instagram',
      1,
      9,
      TransactionDocType.sinDocumento,
      2240,
    ),
    ('Arcilla gres 4 sacos', -75960, 'Insumos y materiales', 1, 10, null, 0),
    ('Arriendo del taller', -220000, 'Arriendo del taller', 1, 1, null, 0),
    (
      'Juego de platos a pedido',
      145000,
      'Pedido personalizado',
      1,
      18,
      TransactionDocType.boletaHonorarios,
      0,
    ),
    ('Gas del horno', -38500, 'Gas y electricidad', 1, 21, null, 0),
    ('Envíos Starken', -12400, 'Envíos', 1, 24, null, 0),
    // Mes actual.
    ('Arriendo del taller', -220000, 'Arriendo del taller', 0, 1, null, 0),
    (
      'Tienda Raíces, consignación',
      210000,
      'Venta a tienda',
      0,
      3,
      TransactionDocType.boletaVenta,
      0,
    ),
    ('Esmaltes y óxidos', -46300, 'Insumos y materiales', 0, 4, null, 0),
    (
      'Feria de Providencia',
      132500,
      'Venta en feria',
      0,
      6,
      TransactionDocType.boletaVenta,
      0,
    ),
    (
      'Maceteros por Instagram',
      48000,
      'Venta por Instagram',
      0,
      7,
      TransactionDocType.sinDocumento,
      1680,
    ),
    ('Pinceles y lija', -15800, 'Herramientas', 0, 7, null, 0),
    ('Publicidad en Instagram', -20000, 'Difusión', 0, 8, null, 0),
    ('Electricidad del taller', -27900, 'Gas y electricidad', 0, 8, null, 0),
  ];
  for (final (titulo, monto, categoria, mes, d, doc, comision) in movimientos) {
    await finanzas.addTransaction(
      FinancesTransactionEntity(
        id: '',
        title: titulo,
        description: '',
        amount: monto.abs().toDouble(),
        type: monto > 0 ? TransactionType.income : TransactionType.expense,
        date: dia(mes, d),
        category: categoria,
        docType: doc ?? TransactionDocType.fallback,
        platformFee: comision.toDouble(),
      ),
    );
  }
  // Los gráficos de Finanzas leen months/, que escribe el trigger
  // onTransactionWritten del emulador de Functions.
  final meses = db.collection('users/$uid/months').limit(12);
  final limite = DateTime.now().add(const Duration(seconds: 60));
  while ((await meses.get()).docs.length < 2) {
    if (DateTime.now().isAfter(limite)) {
      throw TestFailure(
        'No aparecieron los resúmenes de months/: '
        '¿está corriendo el emulador de Functions?',
      );
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  await finanzas.addFixedExpense(name: 'Arriendo del taller', amount: 220000);
  await finanzas.addFixedExpense(name: 'Internet', amount: 24990);

  final inventario = InventoryFirebaseDataSource(firestore: db, userId: uid);
  final items = [
    (
      'Arcilla gres 25 kg',
      InventoryItemType.material,
      18990,
      3,
      4,
      'sacos',
      'Cerámicas del Sur',
    ),
    (
      'Esmalte transparente',
      InventoryItemType.material,
      12500,
      2,
      2,
      'kg',
      'Cerámicas del Sur',
    ),
    (
      'Óxido de cobre 250 g',
      InventoryItemType.material,
      7900,
      1,
      2,
      'un',
      null,
    ),
    ('Caolín blanco', InventoryItemType.material, 3400, 6, 3, 'kg', null),
    ('Pincel chino N6', InventoryItemType.material, 2490, 8, 4, 'un', null),
    (
      'Taza esmaltada azul',
      InventoryItemType.product,
      16000,
      14,
      6,
      'un',
      null,
    ),
    ('Plato de postre', InventoryItemType.product, 12000, 22, 8, 'un', null),
    ('Macetero mediano', InventoryItemType.product, 24000, 5, 4, 'un', null),
    ('Bowl de ramen', InventoryItemType.product, 19500, 0, 3, 'un', null),
    ('Set de 4 vasos', InventoryItemType.product, 38000, 3, 2, 'set', null),
  ];
  for (final (nombre, tipo, precio, stock, minimo, unidad, proveedor)
      in items) {
    await inventario.addItem(
      InventoryItemEntity(
        id: '',
        name: nombre,
        type: tipo,
        price: precio.toDouble(),
        stock: stock,
        minStock: minimo,
        unit: unidad,
        supplier: proveedor,
      ),
    );
  }

  await _sembrarConversacion(uid);
}

/// La conversación la escribe solo el backend (las reglas niegan al
/// cliente), así que se crea por REST con el token `owner` del emulador.
Future<void> _sembrarConversacion(final String uid) async {
  final base = 'users/$uid/conversations/ejemplo';
  final ahora = DateTime.now().toUtc();
  String ts(final int minutos) =>
      ahora.subtract(Duration(minutes: minutos)).toIso8601String();

  await _firestoreOwner(base, {
    'createdAt': {'timestampValue': ts(30)},
    'updatedAt': {'timestampValue': ts(1)},
  });
  final mensajes = [
    (
      'user',
      '¿Me alcanza con lo que vendí este mes para comprar esmalte nuevo?',
      30,
    ),
    (
      'assistant',
      'Este mes llevas \$390.500 en ingresos y \$330.000 en gastos, así que te '
          'quedan unos \$60.500. Un kilo de esmalte transparente te costó '
          '\$12.500 la última vez: te alcanza, y aún te quedaría margen para '
          'los envíos de fin de mes.',
      29,
    ),
    ('user', '¿Qué producto me deja más por hora de trabajo?', 5),
    (
      'assistant',
      'Con tu valor hora de \$7.083, el set de 4 vasos (\$38.000) es el que más '
          'rinde si te toma menos de 5 horas hacerlo. El bowl de ramen está sin '
          'stock y suele venderse bien en ferias.',
      4,
    ),
  ];
  for (var i = 0; i < mensajes.length; i++) {
    final (rol, texto, minutos) = mensajes[i];
    await _firestoreOwner('$base/messages/m$i', {
      'role': {'stringValue': rol},
      'text': {'stringValue': texto},
      'createdAt': {'timestampValue': ts(minutos)},
    });
  }
}

Future<void> _firestoreOwner(
  final String ruta,
  final Map<String, Object> campos,
) => _owner(
  'PATCH',
  'http://$_host:8080/v1/projects/$_proyecto/databases/(default)/documents/$ruta',
  {'fields': campos},
);

/// Marca el correo como verificado en el emulador de Auth.
Future<void> _verificarCorreo(final String uid) => _owner(
  'POST',
  'http://$_host:9099/identitytoolkit.googleapis.com/v1/projects/$_proyecto/accounts:update',
  {'localId': uid, 'emailVerified': true},
);

Future<void> _owner(
  final String metodo,
  final String url,
  final Map<String, Object> cuerpo,
) async {
  final cliente = HttpClient();
  try {
    final req = await cliente.openUrl(metodo, Uri.parse(url));
    req.headers
      ..set('Authorization', 'Bearer owner')
      ..contentType = ContentType.json;
    req.write(jsonEncode(cuerpo));
    final res = await req.close();
    final texto = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 300) {
      throw StateError('$metodo $url → ${res.statusCode}: $texto');
    }
  } finally {
    cliente.close();
  }
}

// ─── Boleta de ejemplo ───────────────────────────────────────────────────

/// Devuelve la boleta real de `test/features/receipt_scan/
/// boleta_real_mlkit_test.dart` en vez de leer un archivo, y usa la misma
/// heurística local que la app. No llama al callable.
class _BoletaDeEjemplo implements ReceiptScanRepository {
  static const List<(double, double, String)> _crudo = [
    (43, 51, 'CERAMICAS DEL SUR LTDA'),
    (80, 52, 'R.U.T. 76.432.198-5'),
    (106, 51, 'GIRO: VENTA DE MATERIALES PARA CERAMICA'),
    (132, 50, 'AV. LOS ALERCES 1842 - PUERTO VARAS'),
    (167, 51, 'BOLETA ELECTRONICA N 0004827'),
    (192, 51, 'FECHA O6/10/2026 HORA 11:42 CAJA O2'),
    (251, 51, 'CANT DESCRIPCION'),
    (297, 51, '2 SACOS'),
    (331, 52, '1 KG'),
    (365, 50, '4 UN'),
    (399, 52, '3 KG'),
    (433, 51, '1 UN'),
    (467, 51, '6 PLIEGOS'),
    (648, 52, 'EFECTIVO'),
    (674, 50, 'VUELTO'),
    (297, 195, 'ARCILLA GRES 25K'),
    (331, 197, 'ESMALTE TRANSPARENTE'),
    (365, 197, 'PINCEL CHINO N6'),
    (399, 196, 'CAOLIN BLANCO'),
    (433, 196, 'OXIDO DE COBRE 250G'),
    (251, 391, 'P.UNIT'),
    (467, 197, 'PAPEL DE LIJA 400'),
    (706, 51, 'GRACIAS POR SU COMPRA'),
    (648, 293, '100.000'),
    (674, 337, '183'),
    (734, 51, 'TIMBRE ELECTRONICo SII - RES. 80 DE 2014'),
    (527, 431, 'NETO'),
    (249, 500, 'TOTAL'),
    (595, 431, 'TOTAL'),
    (297, 514, '18.990'),
    (560, 432, 'IVA 19%'),
    (331, 515, '12.500'),
    (365, 526, '2.490'),
    (399, 527, '3.400'),
    (433, 527, '7.900'),
    (467, 550, '890'),
    (294, 639, '37.980'),
    (331, 640, '12.500'),
    (365, 651, '9.960'),
    (399, 639, '10.20O'),
    (433, 651, '7.900'),
    (467, 652, '5.340'),
    (527, 639, '83.88'),
    (561, 639, '15.937'),
    (591, 633, '99.817'),
  ];

  @override
  Future<ReceiptReading> leer(final ReceiptDocument documento) async =>
      ReceiptReading(
        lines: [
          for (final (top, left, texto) in _crudo)
            OcrLine(text: texto, top: top, left: left, height: 20),
        ],
        rawText: _crudo.map((final l) => l.$3).join('\n'),
      );

  @override
  LocalParse parseLocal(final ReceiptReading lectura) =>
      parseLineasDeBoleta(lectura);

  @override
  Future<StructuredReceipt> structure({
    required final ReceiptReading lectura,
    required final List<ScannedLineItem> local,
    required final bool esPdf,
  }) async =>
      StructuredReceipt(items: local, degradation: ScanDegradation.ninguna);

  @override
  Future<ReceiptDocument?> tomarFoto() async => null;

  @override
  Future<ReceiptDocument?> elegirImagen() async => null;

  @override
  Future<ReceiptDocument?> elegirDocumento() async => null;
}
