// Widget test de InventarioTab, sin Firebase.
//
// Especificación: docs/diseno/variantes-cabal.html, pantalla «inventario».
// Lo que comprueba: la cabecera con los totales, el selector segmentado,
// la búsqueda por nombre o código, la píldora de stock (carmesí solo para
// alertas) y el hueco final para que el + no tape la última fila.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/pages/inventario_tab.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';

import 'fake_inventory_repository.dart';

InventoryItemEntity _ficha(
  final String nombre, {
  final InventoryItemType tipo = InventoryItemType.product,
  final int stock = 5,
  final int minimo = 3,
  final String? codigo,
}) =>
    InventoryItemEntity(
      id: 'id-$nombre',
      name: nombre,
      type: tipo,
      price: 19500,
      stock: stock,
      minStock: minimo,
      unit: 'unidades',
      code: codigo,
    );

final _fichas = [
  _ficha('Macetero mediano', codigo: 'MAC-01'),
  _ficha('Bowl de ramen', stock: 0),
  _ficha('Taza esmaltada', stock: 2),
  _ficha('Greda 25 kg', tipo: InventoryItemType.material, stock: 9),
];

void main() {
  late FakeInventoryRepository repository;
  late InventoryProvider provider;

  setUp(() {
    repository = FakeInventoryRepository();
    provider = InventoryProvider(repository: repository);
  });

  tearDown(() async {
    provider.dispose();
    await repository.cerrar();
  });

  Future<void> montar(
    final WidgetTester tester, {
    final List<InventoryItemEntity>? fichas,
    final double textScale = 1.0,
  }) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: ChangeNotifierProvider<InventoryProvider>.value(
            value: provider,
            child: const Scaffold(body: InventarioTab()),
          ),
        ),
      ),
    );
    repository.emitir(fichas ?? _fichas);
    await tester.pumpAndSettle();
  }

  /// La píldora de stock de una fila.
  Container pildora(final WidgetTester tester, final String texto) =>
      tester.widget<Container>(
        find.ancestor(of: find.text(texto), matching: find.byType(Container))
            .first,
      );

  testWidgets('la cabecera dice cuánto hay de cada tipo', (
    final tester,
  ) async {
    await montar(tester);

    expect(find.text('Inventario'), findsOneWidget);
    expect(find.text('3 productos · 1 material'), findsOneWidget);
  });

  testWidgets('el tipo se elige en un segmentado, no en chips', (
    final tester,
  ) async {
    await montar(tester);

    expect(find.byType(PagateChip), findsNothing);
    expect(find.byType(PagateSegmented<InventoryItemType>), findsOneWidget);

    await tester.tap(find.text('Materiales'));
    // `pump` y no `pumpAndSettle`: al cambiar de tipo la lista vuelve a
    // cargar y el esqueleto se anima hasta que el stream emite.
    await tester.pump();
    expect(provider.activeTab, InventoryItemType.material);
  });

  testWidgets('busca por nombre o por código', (final tester) async {
    await montar(tester);

    expect(find.text('Buscar por nombre o código'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'mac-01');
    await tester.pumpAndSettle();

    expect(find.text('Macetero mediano'), findsOneWidget);
    expect(find.text('Bowl de ramen'), findsNothing);
  });

  testWidgets('el stock va en una píldora; el carmesí, solo en alertas', (
    final tester,
  ) async {
    await montar(tester);

    // Normal: el precio y el mínimo abajo, el stock en el suave.
    expect(find.text(r'$19.500 · mínimo 3'), findsWidgets);
    final normal = pildora(tester, '5 unidades');
    expect((normal.decoration! as BoxDecoration).color, AppPalette.sunken);
    expect(
      tester.widget<Text>(find.text('5 unidades')).style!.color,
      AppPalette.ink,
    );

    // Sin stock: lo dice la píldora, en carmesí.
    final sinStock = pildora(tester, 'Sin stock');
    expect(
      (sinStock.decoration! as BoxDecoration).color,
      AppPalette.dangerSurface,
    );
    expect(
      tester.widget<Text>(find.text('Sin stock')).style!.color,
      AppPalette.danger,
    );

    // Bajo el mínimo: en carmesí, y dicho con palabras, no solo con color.
    expect(find.text(r'$19.500 · bajo el mínimo (3)'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('2 unidades')).style!.color,
      AppPalette.danger,
    );
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets('con letra $escala el + no tapa la última fila', (
      final tester,
    ) async {
      final muchas = [
        for (var i = 1; i <= 20; i++) _ficha('Pieza número $i', stock: 10),
      ];
      await montar(tester, fichas: muchas, textScale: escala);

      await tester.scrollUntilVisible(
        find.text('Pieza número 20'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      // Hasta el fondo: es ahí donde el + caía encima de la fila.
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();

      final ultima = find.ancestor(
        of: find.text('Pieza número 20'),
        matching: find.byType(PagateDataRow),
      );
      expect(
        tester.getBottomLeft(ultima).dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.byType(FloatingActionButton)).dy,
        ),
      );
    });
  }

  testWidgets('con letra 2,0 no desborda', (final tester) async {
    await montar(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
  });
}
