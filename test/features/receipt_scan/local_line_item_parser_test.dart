// La heurística local, probada sobre texto escrito a mano.
//
// Sin Firebase y sin plugins, como manda AGENTS.md: toda la lógica que
// convierte texto en artículos vive por debajo de la frontera de ML Kit, así
// que se le pueden escribir las líneas y comprobar qué saca.
//
// Los casos no son inventados: son las formas en que de verdad imprime una
// boleta un punto de venta chileno, incluida la que la especificación tenía
// mal (`500 GR HARINA 1.200`).

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/receipt_scan/data/parsers/local_line_item_parser.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_reading.dart';

/// Construye una lectura con las líneas en orden, una debajo de otra.
ReceiptReading _lectura(
  final List<String> lineas, {
  final List<double>? sangrias,
}) =>
    ReceiptReading(
      lines: [
        for (var i = 0; i < lineas.length; i++)
          OcrLine(
            text: lineas[i],
            top: i * 20,
            left: sangrias == null ? 24 : sangrias[i],
          ),
      ],
      rawText: lineas.join('\n'),
    );

void main() {
  group('una línea de artículo', () {
    test('cantidad, unidad, descripción y un solo monto', () {
      final r = parseLineasDeBoleta(
        _lectura(['2 SACOS ARCILLA GRES 25K 18.990']),
      );

      expect(r.items, hasLength(1));
      final item = r.items.single;
      // Caja de frase, con la medida intacta: ver `item_name_case.dart`.
      expect(item.name, 'Arcilla gres 25K');
      expect(item.rawQuantity, 2);
      expect(item.unit, 'sacos');
      expect(item.unitPrice, 18990);
      // El total de línea queda a la vista: es el dato que delata si el
      // monto único se leyó como unitario o como total.
      expect(item.lineTotal, 37980);
      expect(
        item.ambiguous,
        isTrue,
        reason: 'un solo monto en la línea tiene que marcarse',
      );
    });

    test('con unitario y total, el unitario gana y NO queda ambiguo', () {
      final r = parseLineasDeBoleta(
        _lectura(['3 KG ESMALTE TRANSPARENTE 12.500 37.500']),
      );

      final item = r.items.single;
      expect(item.unitPrice, 12500);
      expect(item.rawQuantity, 3);
      expect(item.unit, 'kg');
      expect(item.ambiguous, isFalse);
    });

    test('unitario y total iguales con cantidad 1 tampoco es ambiguo', () {
      // Comparar los candidatos por VALOR en vez de por índice saltaba los
      // dos y marcaba este caso como ambiguo sin serlo.
      final r = parseLineasDeBoleta(_lectura(['1 UN PINCEL CHINO 990 990']));

      final item = r.items.single;
      expect(item.unitPrice, 990);
      expect(item.ambiguous, isFalse);
    });

    test('el monto con separador de miles no se lee como 18 pesos', () {
      // Es el defecto que `parseCurrencyInput` existe para evitar: con
      // `double.tryParse`, "18.990" valdría 18,99.
      final r = parseLineasDeBoleta(_lectura(['1 UN GREDA 18.990']));
      expect(r.items.single.unitPrice, 18990);
    });

    test('cantidad delante del precio: el 500 no se cuenta como monto', () {
      // LA LÍNEA QUE LA ESPECIFICACIÓN LEÍA MAL. Buscando los montos antes
      // que la cantidad, "500" casaba con el patrón de dinero y el artículo
      // salía como "GR HARINA" a 500 pesos.
      final r = parseLineasDeBoleta(_lectura(['500 GR HARINA SILICE 1.200']));

      final item = r.items.single;
      expect(item.name, 'Harina silice');
      expect(item.rawQuantity, 500);
      expect(item.unit, 'gr');
      expect(item.unitPrice, 1200);
    });

    test('sin cantidad al principio se asume 1', () {
      final r = parseLineasDeBoleta(_lectura(['OXIDO DE COBRE 7.900']));

      final item = r.items.single;
      // `Oxido` y no `Óxido`: el reconocimiento no trajo la tilde y no se
      // inventa (`item_name_case.dart`).
      expect(item.name, 'Oxido de cobre');
      expect(item.rawQuantity, 1);
      expect(item.unit, 'unidades');
      expect(item.unitPrice, 7900);
    });

    test('una línea que es solo un monto no produce artículo', () {
      final r = parseLineasDeBoleta(_lectura(['18.990']));
      expect(r.items, isEmpty);
    });

    test('cantidad fraccionaria se conserva y redondea hacia arriba', () {
      final r = parseLineasDeBoleta(_lectura(['2,5 KG CAOLIN 3.400']));

      final item = r.items.single;
      expect(item.rawQuantity, 2.5);
      expect(item.tieneCantidadFraccionaria, isTrue);
      expect(
        item.quantity,
        3,
        reason: 'hacia arriba: hacia abajo perdería material comprado',
      );
    });

    test('UNIDADES casa entera y no se parte en UN', () {
      final r = parseLineasDeBoleta(_lectura(['4 UNIDADES TORNO PEQUENO 990']));

      final item = r.items.single;
      expect(item.unit, 'unidades');
      expect(item.name, 'Torno pequeno');
      expect(item.rawQuantity, 4);
    });
  });

  group('ruido de cabecera y de pie', () {
    test('no entran como artículos aunque lleven monto', () {
      final r = parseLineasDeBoleta(
        _lectura([
          'CERAMICAS DEL SUR LTDA',
          'R.U.T. 76.543.210-K',
          'GIRO: VENTA DE MATERIALES',
          'BOLETA ELECTRONICA N 1.234',
          'FECHA 06/10/2026',
          '2 SACOS ARCILLA GRES 18.990 37.980',
          'SUBTOTAL 37.980',
          'IVA 19% 7.216',
          'TOTAL 45.196',
          'GRACIAS POR SU COMPRA',
        ]),
      );

      expect(r.items, hasLength(1));
      expect(r.items.single.name, 'Arcilla gres');
      expect(
        r.items.map((final i) => i.name),
        isNot(contains('TOTAL')),
        reason: 'el total de la boleta no es mercadería',
      );
    });

    test('una fecha sola y una hora sola se descartan', () {
      final r = parseLineasDeBoleta(_lectura(['12/10/2026', '14:32']));
      expect(r.items, isEmpty);
    });

    test('una línea con menos de tres letras se descarta', () {
      final r = parseLineasDeBoleta(_lectura(['N 1.234']));
      expect(r.items, isEmpty);
    });
  });

  group('nombre partido en dos líneas', () {
    test('se pega al artículo anterior si la sangría coincide', () {
      final r = parseLineasDeBoleta(
        _lectura(
          ['2 SACOS ARCILLA GRES 18.990', 'PARA ALTA TEMPERATURA'],
          sangrias: [24, 28],
        ),
      );

      expect(r.items, hasLength(1));
      expect(r.items.single.name, 'Arcilla gres para alta temperatura');
    });

    test('NO se pega si la sangría es de otra columna', () {
      final r = parseLineasDeBoleta(
        _lectura(
          ['2 SACOS ARCILLA GRES 18.990', 'DESPACHO A DOMICILIO'],
          sangrias: [24, 300],
        ),
      );

      expect(r.items.single.name, 'Arcilla gres');
    });
  });

  group('orden y topes', () {
    test('las líneas se ordenan por su caja, no por el orden del bloque', () {
      // ML Kit agrupa en bloques y los bloques no vienen en orden de
      // lectura: sin ordenar, la continuación llegaría antes del nombre.
      final r = parseLineasDeBoleta(
        const ReceiptReading(
          lines: [
            OcrLine(text: 'DE ALTA TEMPERATURA', top: 40, left: 24),
            OcrLine(text: '2 SACOS ARCILLA 18.990', top: 20, left: 24),
          ],
          rawText: 'x',
        ),
      );

      expect(r.items.single.name, 'Arcilla de alta temperatura');
    });

    test('corta en 40 artículos y lo dice', () {
      final r = parseLineasDeBoleta(
        _lectura([
          for (var i = 0; i < 45; i++) '1 UN MATERIAL NUMERO ${i + 100} 1.990',
        ]),
      );

      expect(r.items, hasLength(kMaxArticulosPorBoleta));
      expect(
        r.truncated,
        isTrue,
        reason: 'recortar en silencio haría creer que la boleta no tenía más',
      );
    });

    test('un nombre larguísimo se recorta a 120 caracteres', () {
      final largo = 'MATERIAL ${'MUY ' * 60}LARGO';
      final r = parseLineasDeBoleta(_lectura(['1 UN $largo 1.990']));

      expect(r.items.single.name.length, lessThanOrEqualTo(120));
    });

    test('una lectura vacía no revienta', () {
      final r = parseLineasDeBoleta(ReceiptReading.vacia);
      expect(r.items, isEmpty);
      expect(r.truncated, isFalse);
    });
  });

  // ─── El proveedor ─────────────────────────────────────────────────
  //
  // EL DEFECTO: por el camino local el campo "Proveedor" quedaba SIEMPRE
  // vacío, aunque la primera línea de la boleta diga el nombre del local.
  // El servidor sí lo devolvía, así que sin red —que es justo cuando el
  // camino local importa— el usuario tecleaba a mano un dato impreso
  // arriba.
  //
  // Y LA OTRA MITAD, QUE ES LA QUE IMPORTA MÁS: cuando NO se puede
  // afirmar, queda vacío. Una ficha con el proveedor «Boleta electronica»
  // es peor que una con el proveedor vacío, porque el usuario no revisa un
  // campo que ya parece relleno.
  group('el proveedor', () {
    test('una razón social con forma societaria se extrae', () {
      final r = parseLineasDeBoleta(
        _lectura([
          'CERAMICAS DEL SUR LTDA',
          'R.U.T. 76.543.210-K',
          'CANT DESCRIPCION P.UNIT',
          '2 SACOS ARCILLA GRES 18.990',
        ]),
      );

      expect(r.items.single.supplier, 'Ceramicas del sur Ltda');
    });

    test('es el MISMO para todos los artículos del documento', () {
      // La boleta la emite un solo local.
      final r = parseLineasDeBoleta(
        _lectura([
          'INSUMOS AUSTRALES SPA',
          'CANT DESCRIPCION P.UNIT',
          '2 SACOS ARCILLA GRES 18.990',
          '1 KG ESMALTE TRANSPARENTE 12.500',
        ]),
      );

      expect(r.items, hasLength(2));
      for (final item in r.items) {
        expect(item.supplier, 'Insumos australes SpA');
      }
    });

    test('con encabezado de columnas basta la primera línea limpia', () {
      // Con encabezado se sabe dónde acaba la cabecera, así que la primera
      // línea sin dígitos y sin ruido es el nombre del local.
      final r = parseLineasDeBoleta(
        _lectura([
          'FERRETERIA EL MARTILLO',
          'R.U.T. 76.543.210-K',
          'CANT DESCRIPCION P.UNIT',
          '2 UN MARTILLO 8.990',
        ]),
      );

      expect(r.items.single.supplier, 'Ferreteria el martillo');
    });

    test('SIN encabezado se exige la forma societaria', () {
      // Sin encabezado no se sabe dónde acaba la cabecera, y adivinar con
      // la primera línea de una boleta de estructura desconocida es justo
      // inventar.
      final sinForma = parseLineasDeBoleta(
        _lectura(['INSUMOS DEL TALLER', '2 UN MARTILLO 8.990']),
      );
      expect(sinForma.items.single.supplier, isNull);

      final conForma = parseLineasDeBoleta(
        _lectura(['INSUMOS AUSTRALES SPA', '2 UN MARTILLO 8.990']),
      );
      expect(conForma.items.single.supplier, 'Insumos australes SpA');
    });

    test('el rótulo del documento NO se cuela como proveedor', () {
      final r = parseLineasDeBoleta(
        _lectura([
          'BOLETA ELECTRONICA N 0004827',
          'CANT DESCRIPCION P.UNIT',
          '2 UN MARTILLO 8.990',
        ]),
      );

      expect(
        r.items.single.supplier,
        isNull,
        reason: 'un proveedor llamado «Boleta electronica» es peor que vacío',
      );
    });

    test('la dirección del local tampoco', () {
      // Lleva un monto dentro (`1842`), y eso la descarta.
      final r = parseLineasDeBoleta(
        _lectura([
          'AV. LOS ALERCES 1842 - PUERTO VARAS',
          'CANT DESCRIPCION P.UNIT',
          '2 UN MARTILLO 8.990',
        ]),
      );

      expect(r.items.single.supplier, isNull);
    });

    test('ni el giro, ni el RUT, ni la fecha', () {
      final r = parseLineasDeBoleta(
        _lectura([
          'GIRO: VENTA DE MATERIALES PARA CERAMICA',
          'R.U.T. 76.432.198-5',
          'FECHA 06/10/2026 HORA 11:42',
          'CANT DESCRIPCION P.UNIT',
          '2 UN MARTILLO 8.990',
        ]),
      );

      expect(r.items.single.supplier, isNull);
    });

    test('no se busca el proveedor dentro de la lista de artículos', () {
      // Sin tope de cabecera, un artículo de más abajo con una forma
      // societaria en el nombre pasaría a ser el proveedor.
      final r = parseLineasDeBoleta(
        _lectura([
          for (var i = 0; i < 8; i++) 'LINEA DE RELLENO NUMERO ${i + 1}',
          'DISTRIBUIDORA LOS ROBLES LTDA',
          '2 UN MARTILLO 8.990',
        ]),
      );

      expect(r.items.last.supplier, isNull);
    });
  });
}
