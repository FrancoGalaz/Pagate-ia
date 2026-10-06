// PROPÓSITO
// ---------
// El provider del inventario, sin Firebase. Lo que se comprueba aquí es lo
// que el formulario delega en él:
//
// · Que los dos campos opcionales se normalicen: recortados, y lo vacío
//   convertido en `null`. Un `''` guardado en Firestore haría que la ficha
//   pintase "Código" seguido de nada.
// · Que `updateItem` valide lo mismo que `addItem`. Hasta que la ficha se
//   pudo editar, ese método no tenía ni un llamador en la interfaz, así que
//   sus datos no pasaban por ninguna comprobación.
// · Que el buscador encuentre por código, que es el único motivo por el que
//   un código sirve para algo.

import 'package:flutter_test/flutter_test.dart';

import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';

import 'fake_inventory_repository.dart';

const _greda = InventoryItemEntity(
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

const _esmalte = InventoryItemEntity(
  id: 'item-2',
  name: 'Esmalte transparente',
  type: InventoryItemType.material,
  price: 7990,
  stock: 3,
  minStock: 1,
  unit: 'litros',
  code: 'ES-10',
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

  group('addItem', () {
    test('recorta el proveedor y el código', () async {
      await provider.addItem(
        name: '  Greda 25 kg  ',
        type: InventoryItemType.material,
        price: 18990,
        stock: 4,
        minStock: 2,
        unit: 'sacos',
        supplier: '  Cerámicas del Sur  ',
        code: '  GR-25  ',
      );

      final guardada = repository.agregados.single;
      expect(guardada.name, 'Greda 25 kg');
      expect(guardada.supplier, 'Cerámicas del Sur');
      expect(guardada.code, 'GR-25');
    });

    test('convierte en null lo que solo tiene espacios', () async {
      await provider.addItem(
        name: 'Greda 25 kg',
        type: InventoryItemType.material,
        price: 18990,
        stock: 4,
        minStock: 2,
        unit: 'sacos',
        supplier: '   ',
        code: '',
      );

      final guardada = repository.agregados.single;
      expect(guardada.supplier, isNull);
      expect(guardada.code, isNull);
    });
  });

  group('updateItem', () {
    test('guarda la ficha normalizada', () async {
      await provider.updateItem(
        _greda.copyWith(name: '  Greda roja  ', unit: '   '),
      );

      final guardada = repository.actualizados.single;
      expect(guardada.id, 'item-1');
      expect(guardada.name, 'Greda roja');
      expect(
        guardada.unit,
        'unidades',
        reason: 'misma regla que en el alta: sin unidad, "unidades"',
      );
    });

    test('rechaza una ficha sin id', () {
      expect(
        () => provider.updateItem(_greda.copyWith(id: '')),
        throwsArgumentError,
      );
      expect(repository.actualizados, isEmpty);
    });

    test('rechaza un nombre vacío', () {
      expect(
        () => provider.updateItem(_greda.copyWith(name: '   ')),
        throwsArgumentError,
      );
    });

    test('rechaza un precio negativo', () {
      expect(
        () => provider.updateItem(_greda.copyWith(price: -1)),
        throwsArgumentError,
      );
    });

    test('rechaza un stock negativo', () {
      expect(
        () => provider.updateItem(_greda.copyWith(stock: -1)),
        throwsArgumentError,
      );
    });
  });

  group('buscador', () {
    test('encuentra por código, no solo por nombre', () async {
      repository.emitir([_greda, _esmalte]);
      await Future<void>.delayed(Duration.zero);

      provider.search('gr-25');
      expect(provider.items.map((final i) => i.id), ['item-1']);

      provider.search('ES-10');
      expect(provider.items.map((final i) => i.id), ['item-2']);

      provider.search('esmalte');
      expect(provider.items.map((final i) => i.id), ['item-2']);
    });
  });
}
