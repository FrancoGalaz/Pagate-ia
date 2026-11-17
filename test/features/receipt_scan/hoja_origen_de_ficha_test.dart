// LA HOJA DE "DE DÓNDE SALE LA FICHA", CON SUS CUATRO ENTRADAS.
//
// Sin cámara, sin selector nativo y sin Firebase: el repositorio se inyecta
// y dice qué "eligió" el usuario.
//
// LO QUE SE COMPRUEBA ES QUE CADA FILA LLAMA A LO QUE DICE SU RÓTULO. Es el
// defecto más fácil de colar al añadir una cuarta fila a un `switch`: la
// fila nueva dice "buscar el archivo en el teléfono" y abre la galería, y
// nadie se da cuenta hasta que un usuario no encuentra su PDF.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_document.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_reading.dart';
import 'package:pagate_ia/features/receipt_scan/presentation/widgets/hoja_origen_de_ficha.dart';
import 'package:provider/provider.dart';

import '../inventory/fake_inventory_repository.dart';
import 'fake_receipt_scan_repository.dart';

const ReceiptDocument _pdfDeDescargas = ReceiptDocument(
  path: '/cache/boleta_octubre.pdf',
  mimeType: 'application/pdf',
  source: ReceiptScanSource.archivo,
);

Future<FakeReceiptScanRepository> _montar(final WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(400, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final inv = FakeInventoryRepository();
  final inventario = InventoryProvider(repository: inv);
  addTearDown(inventario.dispose);
  addTearDown(inv.cerrar);
  inv.emitir(const []);

  final lector = FakeReceiptScanRepository(
    lectura: const ReceiptReading(
      lines: [OcrLine(text: '2 SACOS ARCILLA GRES 18.990')],
      rawText: '2 SACOS ARCILLA GRES 18.990',
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ChangeNotifierProvider<InventoryProvider>.value(
          value: inventario,
          child: HojaOrigenDeFicha(
            tipo: InventoryItemType.material,
            repositorio: lector,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return lector;
}

void main() {
  testWidgets('ofrece las CUATRO formas de crear una ficha', (
    final tester,
  ) async {
    await _montar(tester);

    expect(find.text('Escribir la ficha a mano'), findsOneWidget);
    expect(find.text('Tomar una foto de la boleta'), findsOneWidget);
    expect(find.text('Elegir una imagen de la galería'), findsOneWidget);
    expect(find.text('Buscar el archivo en el teléfono'), findsOneWidget);
  });

  testWidgets('la fila nueva dice que acepta un PDF, que es lo que la '
      'galería NO puede dar', (final tester) async {
    await _montar(tester);

    expect(
      find.text('Un PDF o una imagen, por ejemplo en Descargas'),
      findsOneWidget,
    );
    // Y la de la galería sigue sin prometerlo: `image_picker` no tiene
    // ninguna API que devuelva un PDF.
    expect(find.textContaining('PDF de la galería'), findsNothing);
  });

  testWidgets('buscar el archivo abre el selector de DOCUMENTOS', (
    final tester,
  ) async {
    final lector = await _montar(tester);
    lector.documentoDelSelectorDeArchivos = _pdfDeDescargas;

    await tester.tap(find.text('Buscar el archivo en el teléfono'));
    await tester.pumpAndSettle();

    expect(
      lector.entradasUsadas,
      ['archivo'],
      reason: 'ni la cámara ni la galería: el selector de documentos',
    );
  });

  testWidgets('el archivo elegido alimenta la MISMA tubería de lectura', (
    final tester,
  ) async {
    final lector = await _montar(tester);
    lector.documentoDelSelectorDeArchivos = _pdfDeDescargas;

    await tester.tap(find.text('Buscar el archivo en el teléfono'));
    await tester.pumpAndSettle();

    // La pantalla de revisión de siempre, con el artículo de siempre: la
    // entrada nueva no estrena ningún camino propio.
    expect(find.text('Revisar la boleta'), findsOneWidget);
    expect(find.text('Arcilla gres'), findsOneWidget);
    expect(lector.documentoLeido, _pdfDeDescargas);
    expect(
      lector.pdfDeclarado,
      isTrue,
      reason: 'un PDF se declara como PDF al backend',
    );
  });

  testWidgets('cancelar el selector no abre nada ni dice nada', (
    final tester,
  ) async {
    final lector = await _montar(tester);
    lector.documentoDelSelectorDeArchivos = null;

    await tester.tap(find.text('Buscar el archivo en el teléfono'));
    await tester.pumpAndSettle();

    expect(lector.entradasUsadas, ['archivo']);
    expect(lector.lecturas, 0);
    expect(find.text('Revisar la boleta'), findsNothing);
  });

  testWidgets('las otras dos filas siguen llamando a lo suyo', (
    final tester,
  ) async {
    final lector = await _montar(tester);

    await tester.tap(find.text('Tomar una foto de la boleta'));
    await tester.pumpAndSettle();
    expect(lector.entradasUsadas, ['camara']);
  });

  testWidgets('la fila de la galería llama a la galería', (
    final tester,
  ) async {
    final lector = await _montar(tester);

    await tester.tap(find.text('Elegir una imagen de la galería'));
    await tester.pumpAndSettle();
    expect(lector.entradasUsadas, ['galeria']);
  });
}
