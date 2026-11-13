// El estado de una lectura, de la foto al lote de escritura.
//
// LO QUE MÁS IMPORTA AQUÍ es lo que se escribe en el inventario: es la
// única parte de esta función que toca los datos del usuario, y los datos
// que la alimentan son los MENOS fiables de la app (los propuso un
// reconocimiento de texto y un modelo). Hay un test por cada decisión que
// cambia lo guardado.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_document.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_reading.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/scanned_line_item.dart';
import 'package:pagate_ia/features/receipt_scan/domain/repositories/receipt_scan_repository.dart';
import 'package:pagate_ia/features/receipt_scan/presentation/providers/receipt_scan_provider.dart';

import '../inventory/fake_inventory_repository.dart';
import 'fake_receipt_scan_repository.dart';

const ReceiptDocument _foto = ReceiptDocument(
  path: '/tmp/boleta.jpg',
  mimeType: 'image/jpeg',
  source: ReceiptScanSource.camara,
);

const ReceiptDocument _pdf = ReceiptDocument(
  path: '/tmp/boleta.pdf',
  mimeType: 'application/pdf',
  source: ReceiptScanSource.compartido,
);

ReceiptReading _lectura(final List<String> lineas) => ReceiptReading(
      lines: [
        for (var i = 0; i < lineas.length; i++)
          OcrLine(text: lineas[i], top: i * 20, left: 24),
      ],
      rawText: lineas.join('\n'),
    );

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

/// Las seis líneas de la boleta de prueba, en el orden en que se imprimen.
const List<String> _seisArticulos = [
  '2 SACOS ARCILLA GRES 18.990',
  '1 KG ESMALTE TRANSPARENTE 12.500',
  '4 UN PINCEL CHINO 2.490',
  '3 KG CAOLIN BLANCO 3.400',
  '1 UN OXIDO DE COBRE 7.900',
  '6 PLIEGOS PAPEL DE LIJA 890',
];

void main() {
  late FakeInventoryRepository inventarioFalso;
  late InventoryProvider inventario;
  late FakeReceiptScanRepository lector;
  late ReceiptScanProvider provider;

  setUp(() {
    inventarioFalso = FakeInventoryRepository();
    inventario = InventoryProvider(repository: inventarioFalso);
    lector = FakeReceiptScanRepository();
    provider = ReceiptScanProvider(repository: lector, inventory: inventario);
  });

  tearDown(() async {
    provider.dispose();
    inventario.dispose();
    await inventarioFalso.cerrar();
  });

  group('lectura', () {
    test('una boleta normal acaba en revisión con sus artículos', () async {
      lector.lectura = _lectura([
        'CERAMICAS DEL SUR LTDA',
        '2 SACOS ARCILLA GRES 18.990',
        '1 KG ESMALTE TRANSPARENTE 12.500',
        'TOTAL 50.480',
      ]);

      await provider.procesar(_foto);

      expect(provider.phase, ReceiptScanPhase.revisando);
      expect(provider.items, hasLength(2));
      expect(provider.seleccionados, 2);
      expect(provider.degradation, ScanDegradation.ninguna);
    });

    test('sin texto: fase sinTexto, no una lista vacía', () async {
      lector.lectura = ReceiptReading.vacia;

      await provider.procesar(_foto);

      expect(provider.phase, ReceiptScanPhase.sinTexto);
    });

    test('un error de lectura conserva su mensaje y su pista', () async {
      lector.errorDeLectura = const ReceiptScanException(
        'pdf-protegido',
        'No pude abrir ese PDF.',
        hint: 'Saca una foto de la boleta impresa.',
      );

      await provider.procesar(_pdf);

      expect(provider.phase, ReceiptScanPhase.errorDeLectura);
      expect(provider.errorMessage, 'No pude abrir ese PDF.');
      expect(provider.errorHint, 'Saca una foto de la boleta impresa.');
    });

    test('el origen PDF se declara al backend por el documento', () async {
      // Y no por el número de páginas: un PDF de una página sigue siendo un
      // PDF.
      lector.lectura = _lectura(['1 UN GREDA 18.990']);

      await provider.procesar(_pdf);

      expect(lector.pdfDeclarado, isTrue);
    });

    test('la lista LOCAL se publica antes de que el modelo contesta',
        () async {
      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      lector.retrasoDelModelo = const Duration(milliseconds: 50);
      lector.estructurada = const StructuredReceipt(
        items: [
          ScannedLineItem(
            name: 'Arcilla gres',
            rawQuantity: 2,
            unit: 'sacos',
            unitPrice: 18990,
          ),
        ],
        degradation: ScanDegradation.ninguna,
      );

      final futuro = provider.procesar(_foto);
      // Deja correr los microtasks de la lectura local sin esperar al
      // modelo.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        provider.phase,
        ReceiptScanPhase.revisando,
        reason: 'si el modelo tarda, la lista local ya tiene que estar en '
            'pantalla',
      );
      expect(provider.items.single.name, 'Arcilla gres');

      await futuro;
      expect(provider.items.single.name, 'Arcilla gres');
    });

    test('el modelo con lista vacía NO borra la local', () async {
      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      lector.estructurada = const StructuredReceipt(
        items: [],
        degradation: ScanDegradation.modeloVacio,
      );

      await provider.procesar(_foto);

      expect(provider.items, hasLength(1));
      expect(provider.degradation, ScanDegradation.modeloVacio);
    });

    test('la confianza baja se traslada al estado', () async {
      lector.lectura = const ReceiptReading(
        lines: [
          OcrLine(text: '2 SACOS ARCILLA 18.990', confidence: 0.2),
        ],
        rawText: '2 SACOS ARCILLA 18.990',
      );

      await provider.procesar(_foto);

      expect(provider.confianzaBaja, isTrue);
    });

    test('sin confianza informada NO se afirma que salió mal', () async {
      lector.lectura = _lectura(['2 SACOS ARCILLA 18.990']);

      await provider.procesar(_foto);

      expect(provider.confianzaBaja, isFalse);
    });
  });

  group('revisión', () {
    setUp(() async {
      lector.lectura = _lectura([
        '2 SACOS ARCILLA GRES 18.990',
        '1 KG ESMALTE TRANSPARENTE 12.500',
      ]);
      await provider.procesar(_foto);
    });

    test('desmarcar baja el recuento y excluye del guardado', () async {
      provider.alternar(0, valor: false);

      expect(provider.seleccionados, 1);

      await provider.guardar();

      expect(inventarioFalso.loteNuevos, hasLength(1));
      expect(inventarioFalso.loteNuevos.single.name, 'Esmalte transparente');
    });

    test('sin nada marcado no se guarda nada', () async {
      provider.alternar(0, valor: false);
      provider.alternar(1, valor: false);

      expect(await provider.guardar(), isFalse);
      expect(inventarioFalso.lotes, 0);
    });

    test('corregir el nombre vuelve a buscar la ficha que ya existe',
        () async {
      // El caso corriente, y el que creaba duplicados: el OCR saca un
      // nombre sucio que no empareja con nada, el usuario lo corrige al
      // nombre bueno, y ese nombre bueno SÍ es una ficha que ya tiene.
      inventarioFalso.emitir([_ficha('c1', 'Caolín', stock: 18)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(['3 KG CAOLIN BLANCO 10.20O 3.400']);
      await provider.procesar(_foto);
      expect(provider.items.single.matches, isFalse);

      provider.reemplazar(0, provider.items[0].copyWith(name: 'Caolin'));

      expect(provider.items.single.matchedItemId, 'c1');
      expect(provider.items.single.action, ScanAction.sumarStock);

      await provider.guardar();
      expect(inventarioFalso.loteNuevos, isEmpty);
      expect(inventarioFalso.loteStocks.single, {'c1': 21});
    });

    test('corregir OTRA cosa NO deshace el "crear ficha nueva" elegido',
        () async {
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', stock: 4)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);
      provider.reemplazar(
        0,
        provider.items[0].copyWith(action: ScanAction.crearFicha),
      );
      provider.reemplazar(0, provider.items[0].copyWith(unitPrice: 19490));

      expect(provider.items.single.action, ScanAction.crearFicha);
    });

    test('la corrección del usuario es la que se guarda', () async {
      provider.reemplazar(
        0,
        provider.items[0].copyWith(
          name: 'Arcilla gres 25 kg',
          unitPrice: 19490,
          rawQuantity: 3,
          code: 'GR-25',
          supplier: 'Cerámicas del Sur',
          type: InventoryItemType.product,
        ),
      );
      provider.alternar(1, valor: false);

      await provider.guardar();

      final guardado = inventarioFalso.loteNuevos.single;
      expect(guardado.name, 'Arcilla gres 25 kg');
      expect(guardado.price, 19490);
      expect(guardado.stock, 3);
      expect(guardado.code, 'GR-25');
      expect(guardado.supplier, 'Cerámicas del Sur');
      expect(guardado.type, InventoryItemType.product);
      expect(guardado.minStock, 1, reason: 'igual que el formulario manual');
    });
  });

  group('guardado', () {
    test('todo en UN solo lote, no una escritura por artículo', () async {
      lector.lectura = _lectura([
        for (var i = 0; i < 12; i++) '1 UN MATERIAL ${i + 100} 1.990',
      ]);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(inventarioFalso.loteNuevos, hasLength(12));
      expect(
        inventarioFalso.lotes,
        1,
        reason: 'media boleta guardada es peor que ninguna',
      );
      expect(inventarioFalso.agregados, isEmpty);
    });

    test('una ficha que ya existe suma al stock en vez de duplicarse',
        () async {
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', stock: 4)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);

      expect(provider.items.single.matches, isTrue);
      await provider.guardar();

      expect(inventarioFalso.loteNuevos, isEmpty);
      expect(inventarioFalso.loteStocks.single, {'a1': 6});
    });

    test('dos líneas de la misma boleta a la misma ficha se ACUMULAN',
        () async {
      // Sin acumular, la segunda sobrescribía a la primera y se perdía
      // material que el usuario sí compró.
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', stock: 4)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura([
        '2 SACOS ARCILLA GRES 18.990',
        '3 SACOS ARCILLA GRES 18.990',
      ]);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(inventarioFalso.loteStocks.single, {'a1': 9});
    });

    test('"crear ficha nueva" sobre una coincidencia no toca el stock',
        () async {
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', stock: 4)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);
      provider.reemplazar(
        0,
        provider.items[0].copyWith(action: ScanAction.crearFicha),
      );

      await provider.guardar();

      expect(inventarioFalso.loteStocks.single, isEmpty);
      expect(inventarioFalso.loteNuevos, hasLength(1));
    });

    test('el precio guardado NO se sobrescribe si el usuario no lo aprobó',
        () async {
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', price: 18990)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 19.490']);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(
        inventarioFalso.lotePrecios.single,
        isEmpty,
        reason: 'el precio guardado de un producto es a cuánto lo VENDE el '
            'usuario',
      );
    });

    test('con el interruptor encendido sí se sobrescribe', () async {
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', price: 18990)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 19.490']);
      await provider.procesar(_foto);
      provider.reemplazar(0, provider.items[0].copyWith(updatePrice: true));

      await provider.guardar();

      expect(inventarioFalso.lotePrecios.single, {'a1': 19490});
    });

    test('un fallo al guardar conserva la lista revisada y lo dice', () async {
      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);
      inventarioFalso.errorAlGuardar = StateError('sin red');

      expect(await provider.guardar(), isFalse);

      expect(provider.phase, ReceiptScanPhase.revisando);
      expect(provider.items, hasLength(1));
      expect(provider.saveError, isNotNull);
    });

    test('una cantidad fraccionaria entra como entero hacia arriba', () async {
      lector.lectura = _lectura(['2,5 KG CAOLIN 3.400']);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(inventarioFalso.loteNuevos.single.stock, 3);
    });
  });

  // ─── El recuento y la pestaña de destino ───────────────────────────
  //
  // LOS DOS DEFECTOS QUE SE VIERON EN PANTALLA DE GOLPE: al confirmar seis
  // artículos el aviso decía "6 artículos agregados al inventario" cuando
  // en el inventario entraron CINCO fichas (la sexta fue stock sumado a una
  // que ya existía), y la app devolvía al usuario a la pestaña Productos,
  // que seguía vacía porque los seis eran materiales.
  group('el recuento y la pestaña de destino', () {
    test('cinco altas y una actualización NO son seis altas', () async {
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', stock: 4)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(_seisArticulos);
      await provider.procesar(_foto);

      expect(provider.seleccionados, 6, reason: 'seis líneas marcadas');

      await provider.guardar();

      expect(provider.altas, 5);
      expect(provider.actualizadas, 1);
      expect(
        provider.mensajeDeLoGuardado,
        'Agregué 5 fichas nuevas y le sumé stock a 1 que ya tenías.',
      );
    });

    test('solo altas: el recuento es el de siempre', () async {
      lector.lectura = _lectura(_seisArticulos);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(provider.altas, 6);
      expect(provider.actualizadas, 0);
      expect(
        provider.mensajeDeLoGuardado,
        '6 artículos agregados al inventario.',
      );
    });

    test('una sola alta va en singular', () async {
      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(
        provider.mensajeDeLoGuardado,
        '1 artículo agregado al inventario.',
      );
    });

    test('solo actualizaciones: no se dice que se agregó nada', () async {
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', stock: 4)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(provider.altas, 0);
      expect(
        provider.mensajeDeLoGuardado,
        'Le sumé stock a 1 ficha que ya tenías.',
      );
    });

    test('dos líneas a la misma ficha cuentan UNA actualización', () async {
      // Se cuentan FICHAS, no líneas: decir dos sería contar un documento
      // que no existe.
      inventarioFalso.emitir([_ficha('a1', 'ARCILLA GRES', stock: 4)]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura([
        '2 SACOS ARCILLA GRES 18.990',
        '3 SACOS ARCILLA GRES 18.990',
      ]);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(provider.actualizadas, 1);
      expect(provider.altas, 0);
    });

    test('antes de guardar no hay ni mensaje ni pestaña de destino',
        () async {
      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);

      expect(provider.mensajeDeLoGuardado, isNull);
      expect(provider.tipoDeLoGuardado, isNull);
    });

    test('un guardado fallido no deja un recuento de algo que no entró',
        () async {
      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);
      inventarioFalso.errorAlGuardar = StateError('sin red');

      expect(await provider.guardar(), isFalse);

      expect(provider.altas, 0);
      expect(provider.actualizadas, 0);
      expect(provider.mensajeDeLoGuardado, isNull);
      expect(provider.tipoDeLoGuardado, isNull);
    });

    test('seis materiales llevan a la pestaña de Materiales', () async {
      lector.lectura = _lectura(_seisArticulos);
      await provider.procesar(_foto);

      await provider.guardar();

      expect(provider.tipoDeLoGuardado, InventoryItemType.material);
    });

    test('si el usuario los marcó como productos, lleva a Productos',
        () async {
      lector.lectura = _lectura([
        '2 SACOS ARCILLA GRES 18.990',
        '1 KG ESMALTE TRANSPARENTE 12.500',
      ]);
      await provider.procesar(_foto);
      for (var i = 0; i < provider.items.length; i++) {
        provider.reemplazar(
          i,
          provider.items[i].copyWith(type: InventoryItemType.product),
        );
      }

      await provider.guardar();

      expect(provider.tipoDeLoGuardado, InventoryItemType.product);
    });

    test('sumar stock a una ficha de PRODUCTO lleva a Productos', () async {
      // El tipo que manda es el de la ficha GUARDADA, no el que propuso el
      // escáner: si el usuario tiene «Arcilla gres» como producto porque la
      // revende, el stock sube en Productos y ahí hay que llevarlo.
      inventarioFalso.emitir([
        _ficha('p1', 'ARCILLA GRES', type: InventoryItemType.product),
      ]);
      await Future<void>.delayed(Duration.zero);

      lector.lectura = _lectura(['2 SACOS ARCILLA GRES 18.990']);
      await provider.procesar(_foto);

      expect(provider.items.single.matchedType, InventoryItemType.product);
      await provider.guardar();

      expect(provider.tipoDeLoGuardado, InventoryItemType.product);
    });

    test('con empate manda el primer artículo de la boleta', () async {
      // Criterio determinista: sin uno, la misma lectura llevaría a una
      // pestaña distinta cada vez según el orden del recorrido.
      lector.lectura = _lectura([
        '2 SACOS ARCILLA GRES 18.990',
        '1 KG ESMALTE TRANSPARENTE 12.500',
      ]);
      await provider.procesar(_foto);
      provider.reemplazar(
        0,
        provider.items[0].copyWith(type: InventoryItemType.product),
      );

      await provider.guardar();

      expect(provider.tipoDeLoGuardado, InventoryItemType.product);
    });
  });
}
