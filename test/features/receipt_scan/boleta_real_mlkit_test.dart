// LA FORMA QUE ML KIT DEVUELVE DE VERDAD.
//
// ═══ POR QUÉ EXISTE ESTE ARCHIVO ═══
//
// Los otros tests del parser le pasaban una línea por fila de la boleta.
// ML Kit NO devuelve eso: una `TextLine` es un trozo de texto seguido, y
// en una boleta con columnas el hueco entre ellas basta para que cada
// columna salga como su propia línea. Con los 87 tests en verde, la
// pantalla de revisión en emulator-5554 mostraba TRES falsos positivos de
// la cabecera y NINGUNO de los seis artículos de la boleta.
//
// Las coordenadas de abajo no están inventadas: son las que imprimió
// `debugPrint` en emulator-5554 leyendo una boleta chilena real de un
// proveedor de cerámica, copiadas una a una del logcat. Incluidos sus
// errores de reconocimiento, que también son datos: `O6/10/2026` con la
// letra O, `10.20O` y `TIMBRE ELECTRONICo`.
//
// Si alguien vuelve a tocar el reensamblado de filas, este archivo es el
// que se pone rojo.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/receipt_scan/data/parsers/local_line_item_parser.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_reading.dart';

/// `top | left | texto`, tal cual salió del dispositivo. El alto de línea
/// medido fue de unos 20 px, y la separación entre filas de 34.
const List<(double, double, String)> _crudo = [
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

final ReceiptReading _boletaReal = ReceiptReading(
  lines: [
    for (final (top, left, texto) in _crudo)
      OcrLine(text: texto, top: top, left: left, height: 20),
  ],
  rawText: _crudo.map((final l) => l.$3).join('\n'),
);

void main() {
  test('salen los seis artículos de la boleta y ninguno más', () {
    final r = parseLineasDeBoleta(_boletaReal);

    expect(
      r.items.map((final i) => i.name).toList(),
      [
        // CAJA DE FRASE, NO LA MAYÚSCULA DE LA BOLETA. La boleta se imprime
        // entera en mayúsculas y así entraban los nombres al inventario,
        // al lado de las fichas que escribió el usuario. Lo que NO se toca
        // son las medidas y los códigos (`25K`, `N6`, `250G`, `10.20O`), ni
        // se inventa la tilde de `Óxido`, que el reconocimiento no trajo.
        // Las reglas están en `item_name_case.dart`.
        'Arcilla gres 25K',
        'Esmalte transparente',
        'Pincel chino N6',
        'Caolin blanco 10.20O',
        'Oxido de cobre 250G',
        'Papel de lija',
      ],
    );
  });

  test('cantidades y unidades, cada una de su columna', () {
    final r = parseLineasDeBoleta(_boletaReal);

    expect(
      r.items.map((final i) => '${i.quantity} ${i.unit}').toList(),
      ['2 sacos', '1 kg', '4 unidades', '3 kg', '1 unidades', '6 pliegos'],
    );
  });

  test('los precios son los UNITARIOS, no los totales de línea', () {
    // Es la diferencia que más dinero cambia: tomar `37.980` como precio
    // del saco en vez de `18.990` duplica el costo del material.
    final r = parseLineasDeBoleta(_boletaReal);

    expect(
      r.items.map((final i) => i.unitPrice).toList(),
      [18990.0, 12500.0, 2490.0, 3400.0, 7900.0, 890.0],
    );
  });

  test('cuando hay unitario y total confirmados NO se marca ambigüedad', () {
    final r = parseLineasDeBoleta(_boletaReal);
    final porNombre = {for (final i in r.items) i.name: i};

    expect(porNombre['Arcilla gres 25K']!.ambiguous, isFalse);
    expect(porNombre['Pincel chino N6']!.ambiguous, isFalse);

    // En esta fila el OCR leyó `10.20O` con una letra O, así que el total
    // de línea no se pudo leer como número y solo quedó un monto. Eso SÍ es
    // ambiguo, y se dice.
    expect(porNombre['Caolin blanco 10.20O']!.ambiguous, isTrue);
  });

  test('la dirección del local NO entra al inventario', () {
    // `AV. LOS ALERCES 1842` casa con el patrón de dinero y no está en la
    // lista de ruido: lo que la deja fuera es que está por encima del
    // encabezado de columnas.
    final r = parseLineasDeBoleta(_boletaReal);

    expect(
      r.items
          .map((final i) => i.name.toUpperCase())
          .where((final n) => n.contains('ALERCES')),
      isEmpty,
    );
  });

  test('ni el total, ni el IVA, ni el efectivo, ni el vuelto', () {
    final r = parseLineasDeBoleta(_boletaReal);
    // En mayúsculas para comparar: los nombres ya salen en caja de frase.
    final nombres =
        r.items.map((final i) => i.name.toUpperCase()).join(' | ');

    for (final prohibido in [
      'TOTAL',
      'NETO',
      'IVA',
      'EFECTIVO',
      'VUELTO',
      'GRACIAS',
      'TIMBRE',
      'R.U.T',
      'BOLETA',
    ]) {
      expect(nombres, isNot(contains(prohibido)));
    }
  });

  test('el gramaje de un artículo se queda en su nombre', () {
    // `250G` es el gramaje, no un precio. Contarlo como monto dejaba el
    // artículo llamado "OXIDO DE COBRE G".
    final r = parseLineasDeBoleta(_boletaReal);

    expect(
      r.items.map((final i) => i.name),
      contains('Oxido de cobre 250G'),
    );
  });

  test('nada se corta: seis artículos no es una lista truncada', () {
    expect(parseLineasDeBoleta(_boletaReal).truncated, isFalse);
  });

  test('el proveedor sale de la cabecera, con su forma social', () {
    // EL DEFECTO: por el camino local este campo quedaba SIEMPRE vacío,
    // aunque la primera línea de la boleta diga «CERAMICAS DEL SUR LTDA».
    // El servidor sí lo devolvía, así que sin red —que es cuando el camino
    // local importa— el usuario tecleaba a mano un dato impreso arriba.
    final r = parseLineasDeBoleta(_boletaReal);

    expect(r.items, isNotEmpty);
    for (final item in r.items) {
      expect(
        item.supplier,
        'Ceramicas del sur Ltda',
        reason: 'la boleta la emite un solo local: es el mismo para todos',
      );
    }
  });

  test('ni la dirección ni el RUT se cuelan como proveedor', () {
    // «AV. LOS ALERCES 1842» y «R.U.T. 76.432.198-5» están en la misma
    // cabecera y las dos tienen más letras que el mínimo. Lo que las deja
    // fuera es el monto y el filtro de ruido.
    final proveedor = parseLineasDeBoleta(_boletaReal).items.first.supplier;

    expect(proveedor, isNot(contains('ALERCES')));
    expect(proveedor, isNot(contains('76.432')));
    expect(proveedor, isNot(contains('GIRO')));
  });
}
