// La pantalla de revisión, montada sin Firebase ni plugins.
//
// LO QUE SE COMPRUEBA AQUÍ ES LA HONESTIDAD DE LA PANTALLA: que la frase
// que dice "lo que no aparezca no lo leí" está SIEMPRE, que una lectura
// degradada lo admite con palabras y no solo con un color, que el recuento
// del botón es el real, y que un error de guardado se queda escrito dentro
// de la pantalla en vez de irse en un aviso flotante.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_document.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_reading.dart';
import 'package:pagate_ia/features/receipt_scan/domain/repositories/receipt_scan_repository.dart';
import 'package:pagate_ia/features/receipt_scan/presentation/pages/lectura_boleta_screen.dart';
import 'package:pagate_ia/features/receipt_scan/presentation/providers/receipt_scan_provider.dart';
import 'package:provider/provider.dart';

import '../inventory/fake_inventory_repository.dart';
import 'fake_receipt_scan_repository.dart';

const ReceiptDocument _foto = ReceiptDocument(
  path: '/tmp/boleta.jpg',
  mimeType: 'image/jpeg',
  source: ReceiptScanSource.camara,
);

ReceiptReading _lectura(final List<String> lineas) => ReceiptReading(
      lines: [
        for (var i = 0; i < lineas.length; i++)
          OcrLine(text: lineas[i], top: i * 20, left: 24),
      ],
      rawText: lineas.join('\n'),
    );

const List<String> _boletaDeGreda = [
  'CERAMICAS DEL SUR LTDA',
  '2 SACOS ARCILLA GRES 18.990',
  '1 KG ESMALTE TRANSPARENTE 12.500',
  '4 UN PINCEL CHINO 2.490',
  'TOTAL 60.940',
];

/// Monta la pantalla con sus dos providers y espera a que acabe de leer.
Future<
    ({
      FakeReceiptScanRepository lector,
      FakeInventoryRepository inv,
      InventoryProvider inventario,
    })> _montar(
  final WidgetTester tester, {
  final ReceiptReading? lectura,
  final ReceiptScanException? error,
  final StructuredReceipt? estructurada,
  final List<InventoryItemEntity> inventario = const [],
  final String? avisoDeEntrada,
}) async {
  tester.view
    ..physicalSize = const Size(400, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final inv = FakeInventoryRepository();
  final inventoryProvider = InventoryProvider(repository: inv);
  addTearDown(inventoryProvider.dispose);
  addTearDown(inv.cerrar);

  inv.emitir(inventario);
  await tester.pump();

  final lector = FakeReceiptScanRepository(
    lectura: lectura ?? _lectura(_boletaDeGreda),
    errorDeLectura: error,
    estructurada: estructurada,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<InventoryProvider>.value(
            value: inventoryProvider,
          ),
          ChangeNotifierProvider<ReceiptScanProvider>(
            create: (final _) => ReceiptScanProvider(
              repository: lector,
              inventory: inventoryProvider,
            ),
          ),
        ],
        child: LecturaBoletaScreen(
          documento: _foto,
          avisoDeEntrada: avisoDeEntrada,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (lector: lector, inv: inv, inventario: inventoryProvider);
}

void main() {
  testWidgets('la lista propuesta sale con una fila por artículo', (
    final tester,
  ) async {
    await _montar(tester);

    expect(find.text('Revisar la boleta'), findsOneWidget);
    // En caja de frase: la boleta llega en mayúsculas y los nombres entran
    // al inventario escritos como los escribiría el usuario.
    expect(find.text('Arcilla gres'), findsOneWidget);
    expect(find.text('Esmalte transparente'), findsOneWidget);
    expect(find.text('Pincel chino'), findsOneWidget);
    // El total de la boleta no es mercadería.
    expect(find.text('TOTAL'), findsNothing);
  });

  testWidgets('la cifra de la fila es cantidad por precio unitario', (
    final tester,
  ) async {
    await _montar(tester);

    // Sin abreviar y con el separador de miles chileno.
    expect(find.text(r'2 × $18.990'), findsOneWidget);
    expect(find.text(r'4 × $2.490'), findsOneWidget);
  });

  testWidgets('la frase de que lo no leído no aparece está SIEMPRE', (
    final tester,
  ) async {
    await _montar(tester);

    expect(
      find.textContaining('Lo que no aparezca en esta lista no lo leí'),
      findsOneWidget,
    );
  });

  testWidgets('el botón lleva el recuento vivo y se deshabilita con cero', (
    final tester,
  ) async {
    await _montar(tester);

    expect(find.text('Guardar 3 artículos'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Guardar 2 artículos'), findsOneWidget);

    for (final casilla in find.byType(Checkbox).evaluate().skip(0).toList()) {
      final widget = casilla.widget as Checkbox;
      if (widget.value ?? false) {
        await tester.tap(find.byWidget(widget));
        await tester.pumpAndSettle();
      }
    }

    expect(find.text('Guardar artículos'), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Guardar artículos'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('una lectura degradada lo dice con palabras, no con un color', (
    final tester,
  ) async {
    await _montar(
      tester,
      estructurada: const StructuredReceipt(
        items: [],
        degradation: ScanDegradation.modeloFallo,
      ),
    );

    expect(
      find.textContaining('Ordené la lista yo sola, sin el asistente'),
      findsOneWidget,
    );
  });

  testWidgets('con la cuota agotada se muestra el mensaje DEL SERVIDOR', (
    final tester,
  ) async {
    await _montar(
      tester,
      estructurada: const StructuredReceipt(
        items: [],
        degradation: ScanDegradation.sinCuota,
        serverMessage: 'Usaste las 40 lecturas de boleta de tu plan.',
      ),
    );

    // El cliente no sabe cuántas lecturas eran ni en qué plan está el
    // usuario: solo el servidor lo sabe, así que se muestra su texto.
    expect(
      find.text('Usaste las 40 lecturas de boleta de tu plan.'),
      findsOneWidget,
    );
    // Y la lista sigue en pie: la cuota agotada es información, no un error.
    expect(find.text('Arcilla gres'), findsOneWidget);
    expect(find.text('Guardar 3 artículos'), findsOneWidget);
  });

  testWidgets('el aviso de la entrada compartida se muestra', (
    final tester,
  ) async {
    await _montar(
      tester,
      avisoDeEntrada: 'Llegaron 3 archivos. Leí el primero.',
    );

    expect(find.text('Llegaron 3 archivos. Leí el primero.'), findsOneWidget);
  });

  testWidgets('sin texto: lo dice y ofrece teclear, sin fingir una lista', (
    final tester,
  ) async {
    await _montar(tester, lectura: ReceiptReading.vacia);

    expect(find.text('No pude leer nada de esa imagen'), findsOneWidget);
    expect(find.textContaining('Prueba con más luz'), findsOneWidget);
    expect(find.text('Escribir la ficha a mano'), findsOneWidget);
    expect(find.text('Probar con otra foto'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('un PDF protegido muestra su propio mensaje y su pista', (
    final tester,
  ) async {
    await _montar(
      tester,
      error: const ReceiptScanException(
        'pdf-protegido',
        'No pude abrir ese PDF. Puede estar protegido con contraseña.',
        hint: 'Saca una foto de la boleta impresa.',
      ),
    );

    expect(
      find.textContaining('Puede estar protegido con contraseña'),
      findsOneWidget,
    );
    expect(find.text('Saca una foto de la boleta impresa.'), findsOneWidget);
  });

  testWidgets('una ficha que ya existe anuncia el stock resultante', (
    final tester,
  ) async {
    await _montar(
      tester,
      inventario: const [
        InventoryItemEntity(
          id: 'a1',
          name: 'Arcilla gres',
          type: InventoryItemType.material,
          price: 18990,
          stock: 4,
          minStock: 1,
          unit: 'sacos',
        ),
      ],
    );

    expect(find.text('Ya existe · stock 4 → 6'), findsOneWidget);
  });

  testWidgets('un error al guardar se queda escrito dentro de la pantalla', (
    final tester,
  ) async {
    final montaje = await _montar(tester);
    montaje.inv.errorAlGuardar = StateError('sin red');

    await tester.tap(find.text('Guardar 3 artículos'));
    await tester.pumpAndSettle();

    // Dentro de la pantalla y no en un aviso flotante: el flotante lo
    // pinta el Scaffold y se va en segundos, y este error hay que poder
    // volver a leerlo con el botón que falló a la vista.
    expect(find.textContaining('No se pudieron guardar'), findsOneWidget);
    // Y la lista revisada no se pierde.
    expect(find.text('Arcilla gres'), findsOneWidget);
    expect(find.text('Guardar 3 artículos'), findsOneWidget);
  });

  testWidgets('el botón atrás no descarta la lista sin preguntar', (
    final tester,
  ) async {
    await _montar(tester);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar la lectura?'), findsOneWidget);

    await tester.tap(find.text('Seguir revisando'));
    await tester.pumpAndSettle();

    expect(find.text('Arcilla gres'), findsOneWidget);
  });

  testWidgets('guardar escribe en el inventario y cierra la pantalla', (
    final tester,
  ) async {
    final montaje = await _montar(tester);

    await tester.tap(find.text('Guardar 3 artículos'));
    await tester.pumpAndSettle();

    expect(montaje.inv.lotes, 1);
    expect(montaje.inv.loteNuevos, hasLength(3));
    expect(find.text('Revisar la boleta'), findsNothing);
  });

  // ─── El aterrizaje después de confirmar ──────────────────────────
  //
  // DOS DEFECTOS QUE SE VIERON JUNTOS EN emulator-5554. El aviso decía
  // "6 artículos agregados al inventario" cuando cinco fueron altas y una
  // fue stock sumado a una ficha que ya existía; y la app devolvía al
  // usuario a la pestaña Productos, vacía, porque los seis eran materiales.
  // Confirmar seis cosas y aterrizar en una lista vacía de ellas.

  testWidgets('el aviso dice la verdad: altas y stock sumado por separado', (
    final tester,
  ) async {
    final montaje = await _montar(
      tester,
      inventario: const [
        InventoryItemEntity(
          id: 'a1',
          name: 'Arcilla gres',
          type: InventoryItemType.material,
          price: 18990,
          stock: 4,
          minStock: 1,
          unit: 'sacos',
        ),
      ],
    );

    await tester.tap(find.text('Guardar 3 artículos'));
    // Dos pumps y no `pumpAndSettle`: el aviso flotante VIVE una animación
    // de tres segundos, así que asentar el árbol lo deja ya retirado y el
    // texto no se encuentra nunca. Es el patrón de
    // `test/core/utils/app_feedback_test.dart`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // Dos fichas nuevas y una que sube de stock: en el inventario entran
    // DOS fichas, no tres.
    expect(montaje.inv.loteNuevos, hasLength(2));
    expect(montaje.inv.loteStocks.single, {'a1': 6});
    expect(
      find.text('Agregué 2 fichas nuevas y le sumé stock a 1 que ya tenías.'),
      findsOneWidget,
      reason: 'tres líneas confirmadas no son tres altas',
    );

    // Se deja morir el aviso: su tiempo de vida es una animación, no un
    // `Timer`, y `pumpAndSettle` la resuelve.
    await tester.pumpAndSettle();
  });

  testWidgets('sin ninguna coincidencia el aviso es el recuento simple', (
    final tester,
  ) async {
    await _montar(tester);

    await tester.tap(find.text('Guardar 3 artículos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('3 artículos agregados al inventario.'),
      findsOneWidget,
    );

    await tester.pumpAndSettle();
  });

  testWidgets('al confirmar materiales se cambia a la pestaña Materiales', (
    final tester,
  ) async {
    final montaje = await _montar(tester);

    expect(
      montaje.inventario.activeTab,
      InventoryItemType.product,
      reason: 'la pestaña abre en Productos, que es de donde viene el usuario',
    );

    await tester.tap(find.text('Guardar 3 artículos'));
    await tester.pumpAndSettle();

    expect(
      montaje.inventario.activeTab,
      InventoryItemType.material,
      reason: 'los tres artículos de la boleta son materiales',
    );
  });

  testWidgets('un guardado que falla NO mueve al usuario de pestaña', (
    final tester,
  ) async {
    final montaje = await _montar(tester);
    montaje.inv.errorAlGuardar = StateError('sin red');

    await tester.tap(find.text('Guardar 3 artículos'));
    await tester.pumpAndSettle();

    expect(montaje.inventario.activeTab, InventoryItemType.product);
  });

  testWidgets('no desborda con el ajuste de fuente Grande de Android', (
    final tester,
  ) async {
    // 1,3x es el ajuste "Grande", el más común fuera del 100%, y el que ya
    // reventó la pantalla de Inicio una vez.
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final inv = FakeInventoryRepository();
    final inventoryProvider = InventoryProvider(repository: inv);
    addTearDown(inventoryProvider.dispose);
    addTearDown(inv.cerrar);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(1.3),
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<InventoryProvider>.value(
                value: inventoryProvider,
              ),
              ChangeNotifierProvider<ReceiptScanProvider>(
                create: (final _) => ReceiptScanProvider(
                  repository: FakeReceiptScanRepository(
                    lectura: _lectura(_boletaDeGreda),
                  ),
                  inventory: inventoryProvider,
                ),
              ),
            ],
            child: const LecturaBoletaScreen(documento: _foto),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
