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

import 'package:pagate_ia/core/constants/firestore_limits.dart';
import 'package:pagate_ia/features/receipt_scan/data/parsers/local_line_item_parser.dart';

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

  // ─── El presupuesto del lote ──────────────────────────────────────
  //
  // EL RIESGO QUE ESTO FIJA, anotado por el verificador. El datasource
  // manda UN `WriteBatch` sin trocear, y un lote de Firestore admite
  // `FirestoreLimits.maxBatchWrites` operaciones. Hoy no se puede pasar
  // porque el lector topa la boleta en 40 artículos, pero ese tope vive en
  // `local_line_item_parser.dart` y el 500 vivía en un comentario del
  // datasource: NADA ataba las dos cifras. Subir el tope compilaba, pasaba
  // los tests y reventaba en producción con la boleta entera sin guardar.
  //
  // No se trocea el lote: trocear perdería la atomicidad, que es lo que
  // impide el estado de "media boleta guardada" (el usuario no sabe qué
  // mitad le falta y volver a leer la boleta duplicaría la otra). Se cuenta
  // y se para antes de abrir el lote.
  group('presupuesto del lote de una boleta', () {
    InventoryItemEntity ficha(final int i) => InventoryItemEntity(
          id: '',
          name: 'Material $i',
          type: InventoryItemType.material,
          price: 1990,
          stock: 1,
          minStock: 1,
          unit: 'unidades',
        );

    test('un lote dentro del presupuesto entra entero', () async {
      await provider.applyScannedItems(
        nuevos: [
          for (var i = 0; i < FirestoreLimits.maxBatchWrites; i++) ficha(i),
        ],
        stocksFinales: const {},
        preciosNuevos: const {},
      );

      expect(repository.lotes, 1);
      expect(repository.loteNuevos, hasLength(FirestoreLimits.maxBatchWrites));
    });

    test('una operación de más se rechaza con un mensaje propio', () async {
      // Un error con mensaje es peor que guardar, pero mucho mejor que el
      // fallo opaco del servidor que salía antes.
      expect(
        () => provider.applyScannedItems(
          nuevos: [
            for (var i = 0; i <= FirestoreLimits.maxBatchWrites; i++) ficha(i),
          ],
          stocksFinales: const {},
          preciosNuevos: const {},
        ),
        throwsArgumentError,
      );
      expect(repository.lotes, 0, reason: 'no se manda nada a medias');
    });

    test('las altas y las actualizaciones cuentan en el MISMO presupuesto',
        () async {
      // Son operaciones del mismo lote: contar solo las altas dejaba pasar
      // 500 altas más 500 actualizaciones.
      expect(
        () => provider.applyScannedItems(
          nuevos: [
            for (var i = 0; i < FirestoreLimits.maxBatchWrites; i++) ficha(i),
          ],
          stocksFinales: const {'x1': 3},
          preciosNuevos: const {},
        ),
        throwsArgumentError,
      );
      expect(repository.lotes, 0);
    });

    test('stock y precio de la MISMA ficha son una sola operación', () async {
      // El datasource junta las dos en un `update`: dos `update` sobre el
      // mismo documento en el mismo lote es un error de Firestore.
      await provider.applyScannedItems(
        nuevos: [
          for (var i = 0; i < FirestoreLimits.maxBatchWrites - 1; i++)
            ficha(i),
        ],
        stocksFinales: const {'x1': 3},
        preciosNuevos: const {'x1': 1990},
      );

      expect(repository.lotes, 1);
    });

    test('el tope de artículos por boleta cabe en el presupuesto', () {
      // Es la otra mitad del atado: si alguien sube
      // `kMaxArticulosPorBoleta` por encima de lo que cabe, este test se
      // pone rojo antes de que lo haga un usuario.
      expect(
        kMaxArticulosPorBoleta * 2,
        lessThanOrEqualTo(FirestoreLimits.maxBatchWrites),
        reason: 'una boleta llena son como mucho `tope` fichas nuevas más '
            '`tope` actualizaciones, y todo va en un solo lote',
      );
    });
  });
}
