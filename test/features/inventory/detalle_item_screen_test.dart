// PROPÓSITO
// ---------
// La ficha de un ítem, sin Firebase. Tres cosas que antes no se podían
// comprobar porque no existían:
//
// · QUE LAS LÍNEAS DE PROVEEDOR Y CÓDIGO SE DIBUJEN. El código para
//   pintarlas estaba escrito, pero los dos campos valían `null` siempre
//   porque ningún formulario los escribía, así que esas dos ramas nunca se
//   ejecutaban en la app de verdad.
//
// · QUE DESDE LA FICHA SE PUEDA EDITAR. `updateItem` no tenía ni un
//   llamador en la interfaz.
//
// · QUE LA FICHA SE REFRESQUE AUNQUE EL BUSCADOR ESTÉ FILTRANDO. La
//   pantalla busca la versión vigente en `allItems` y no en `items`; con
//   `items` bastaba con haber buscado algo para que la ficha se quedara con
//   los valores viejos justo después de confirmar un cambio.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/pages/detalle_item_screen.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:pagate_ia/features/inventory/presentation/widgets/item_form_sheet.dart';

import 'fake_inventory_repository.dart';

const _ficha = InventoryItemEntity(
  id: 'item-1',
  name: 'Greda 25 kg',
  type: InventoryItemType.material,
  price: 18990,
  stock: 4,
  minStock: 2,
  unit: 'sacos',
  supplier: 'Cerámicas del Sur',
  code: 'GR-25',
);

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
    final InventoryItemEntity item = _ficha,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChangeNotifierProvider<InventoryProvider>.value(
          value: provider,
          child: DetalleItemScreen(item: item),
        ),
      ),
    );
    repository.emitir([item]);
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el proveedor y el código de la ficha', (
    final tester,
  ) async {
    await montar(tester);

    expect(find.text('Código GR-25'), findsOneWidget);
    expect(find.text('Proveedor'), findsOneWidget);
    expect(find.text('Cerámicas del Sur'), findsOneWidget);
  });

  testWidgets('una ficha sin proveedor no dibuja la línea vacía', (
    final tester,
  ) async {
    await montar(
      tester,
      item: const InventoryItemEntity(
        id: 'item-2',
        name: 'Taza de greda',
        type: InventoryItemType.product,
        price: 12500,
        stock: 6,
        minStock: 2,
        unit: 'piezas',
      ),
    );

    expect(find.text('Proveedor'), findsNothing);
    expect(find.textContaining('Código'), findsNothing);
  });

  testWidgets('el botón de editar abre la hoja con la ficha cargada', (
    final tester,
  ) async {
    await montar(tester);

    expect(find.text('Editar ficha'), findsOneWidget);
    await tester.tap(find.text('Editar ficha'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemFormSheet), findsOneWidget);
    expect(find.text('Editar material'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
  });

  testWidgets('la ficha se refresca aunque el buscador esté filtrando', (
    final tester,
  ) async {
    await montar(tester);

    // El usuario había buscado algo que ya no coincide con la ficha: así
    // queda fuera de `items` y solo sigue estando en `allItems`.
    provider.search('zzz');
    await tester.pump();
    expect(provider.items, isEmpty);

    repository.emitir([
      _ficha.copyWith(name: 'Greda roja 25 kg', price: 21500),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.text('Greda roja 25 kg'),
      findsOneWidget,
      reason: 'confirmar un cambio y seguir mostrando el valor viejo es '
          'peor que no confirmar nada',
    );
    expect(find.text(r'$21.500'), findsOneWidget);
  });
}
