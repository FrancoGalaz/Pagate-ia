// Emparejar lo leído con lo que ya está en el inventario.
//
// Lo que se prueba aquí es sobre todo lo que NO hace: no empareja por
// parecido. Un parecido mal resuelto suma stock al material equivocado, y
// eso no se ve; una ficha duplicada sí se ve y se borra.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/receipt_scan/data/parsers/item_name_matcher.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/scanned_line_item.dart';

InventoryItemEntity _ficha(
  final String id,
  final String name, {
  final int stock = 4,
  final double price = 18990,
  final InventoryItemType type = InventoryItemType.material,
}) =>
    InventoryItemEntity(
      id: id,
      name: name,
      type: type,
      price: price,
      stock: stock,
      minStock: 1,
      unit: 'sacos',
    );

ScannedLineItem _leido(final String name) =>
    ScannedLineItem(name: name, rawQuantity: 2, unit: 'sacos', unitPrice: 19490);

void main() {
  group('normalizeForMatch', () {
    test('quita tildes, signos y espacios de más', () {
      expect(normalizeForMatch('  Arcilla  Grés, 25kg. '), 'arcilla gres 25kg');
    });

    test('la eñe y la diéresis caen a su letra base', () {
      expect(normalizeForMatch('Piñón Müller'), 'pinon muller');
    });

    test('dos escrituras del mismo nombre dan la misma cadena', () {
      expect(
        normalizeForMatch('ARCILLA GRES 25K'),
        normalizeForMatch('Arcilla gres 25k'),
      );
    });
  });

  group('emparejarConInventario', () {
    test('igualdad exacta normalizada: empareja y propone sumar stock', () {
      final r = emparejarConInventario(
        [_leido('Arcilla gres 25k')],
        [_ficha('a1', 'ARCILLA GRES 25K', stock: 4)],
      );

      final item = r.single;
      expect(item.matches, isTrue);
      expect(item.matchedItemId, 'a1');
      expect(item.matchedName, 'ARCILLA GRES 25K');
      expect(item.matchedStock, 4);
      expect(item.action, ScanAction.sumarStock);
      expect(item.stockResultante, 6);
    });

    test('un nombre PARECIDO no empareja', () {
      final r = emparejarConInventario(
        [_leido('Arcilla gres')],
        [_ficha('a1', 'Arcilla gres 25 kg')],
      );

      expect(r.single.matches, isFalse);
      expect(r.single.action, ScanAction.crearFicha);
    });

    test('empareja también contra un PRODUCTO, no solo materiales', () {
      final r = emparejarConInventario(
        [_leido('Taza de greda')],
        [_ficha('p1', 'Taza de greda', type: InventoryItemType.product)],
      );

      expect(r.single.matchedItemId, 'p1');
    });

    test('con dos fichas del mismo nombre gana el id menor, siempre', () {
      // Determinismo: el orden del stream de Firestore no está garantizado,
      // así que sin criterio fijo la misma boleta sumaría a una ficha
      // distinta en cada lectura.
      final inventario = [
        _ficha('zzz', 'Arcilla gres'),
        _ficha('aaa', 'Arcilla gres'),
      ];

      expect(
        emparejarConInventario([_leido('Arcilla gres')], inventario)
            .single
            .matchedItemId,
        'aaa',
      );
      expect(
        emparejarConInventario(
          [_leido('Arcilla gres')],
          inventario.reversed.toList(),
        ).single.matchedItemId,
        'aaa',
      );
    });

    test('el precio de la ficha viaja para poder comparar, sin aplicarse', () {
      final r = emparejarConInventario(
        [_leido('Arcilla gres')],
        [_ficha('a1', 'Arcilla gres', price: 18990)],
      );

      final item = r.single;
      expect(item.matchedPrice, 18990);
      expect(item.unitPrice, 19490, reason: 'el de la boleta no se toca');
      expect(item.precioDifiere, isTrue);
      expect(
        item.updatePrice,
        isFalse,
        reason: 'sobrescribir el precio de venta con uno de compra rompe las '
            'finanzas del usuario en silencio',
      );
    });

    test('inventario vacío: todo se propone como ficha nueva', () {
      final r = emparejarConInventario([_leido('Caolín')], const []);
      expect(r.single.matches, isFalse);
    });

    test('una lista vacía se devuelve tal cual', () {
      expect(emparejarConInventario(const [], [_ficha('a', 'x')]), isEmpty);
    });
  });
}
