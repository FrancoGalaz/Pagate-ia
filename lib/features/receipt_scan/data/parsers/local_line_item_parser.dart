// ═══════════════════════════════════════════════════════════════════════
// DE TEXTO A ARTÍCULOS, SIN RED Y SIN CUOTA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: el apartado B del encargo del lector de boletas.
//
// POR QUÉ EXISTE SI YA HAY UN MODELO QUE LO HACE MEJOR. Porque es el único
// camino que funciona sin conexión y sin cuota, y porque nunca saca nada
// del teléfono. Si la función dependiera del modelo, se caería en una
// feria sin señal, que es justo donde un artesano compra y necesita anotar.
//
// Y POR QUÉ NO BASTA ELLA SOLA. ML Kit devuelve líneas con su caja, y de
// ahí se saca la columna de precios de una boleta bien impresa; en una
// boleta térmica chilena la descripción se parte en dos líneas y la columna
// de la derecha se mezcla con la del medio. Esta heurística saca cantidad y
// precio razonablemente y destroza el nombre. Por eso el modelo va encima,
// y por eso cuando no está se AVISA en vez de disimular.
//
// NO SE ESCRIBE OTRO LECTOR DE DINERO. `parseCurrencyInput` de
// `core/utils/currency_formatter.dart` dice en su propio docstring que es
// la única fuente de verdad, y ya resuelve el caso chileno: con `'18.990'`
// hay un punto y la cola mide 3, así que el punto es de miles y devuelve
// 18990. Un segundo lector aquí reabriría el defecto de `150.000` guardado
// como 150 pesos.
// ═══════════════════════════════════════════════════════════════════════

import 'dart:math' as math;

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/receipt_reading.dart';
import '../../domain/entities/scanned_line_item.dart';
import '../../domain/repositories/receipt_scan_repository.dart';

/// Tope de artículos. El mismo que el esquema del backend.
const int kMaxArticulosPorBoleta = 40;

/// Tope de caracteres del nombre que produce la heurística.
const int kMaxNombreArticulo = 120;

// ─── Las expresiones, declaradas una vez ───────────────────────────────

/// Monto en formato chileno. `18.990`, `$18.990`, `1.234.567`, `990`,
/// `12.500,50`.
///
/// `(?<!\d)` evita partir un número largo por la mitad: sin él, `1234567`
/// daría el monto `234567`.
///
/// LA GUARDA DE LA DERECHA RECHAZA TAMBIÉN LAS LETRAS, y eso sale de mirar
/// una boleta de verdad en el emulador: en `OXIDO DE COBRE 250G` el `250`
/// es el gramaje, no un precio, y contarlo como monto dejaba el artículo
/// llamado "OXIDO DE COBRE G". Con la letra en la guarda, `250G` se queda
/// entero dentro del nombre.
///
/// La alternativa de 3 a 9 dígitos sin puntos es deliberada: con 1 o 2
/// dígitos un monto suelto es indistinguible de una cantidad, y en una
/// boleta chilena no hay precios de un dígito.
final RegExp _tokenDeDinero = RegExp(
  r'(?<!\d)\$?\s?(\d{1,3}(?:\.\d{3})+|\d{3,9})(?:,(\d{1,2}))?'
  r'(?![0-9A-Za-zÁÉÍÓÚÜÑáéíóúüñ])',
);

/// Cantidad al principio de la línea, con su unidad opcional.
///
/// El orden de la alternancia no importa gracias al retroceso del motor:
/// sobre `UNIDADES` prueba `UN`, el `\b` falla porque sigue una letra, y
/// acaba casando `UNIDADES?`. Comprobado en
/// `local_line_item_parser_test.dart`.
final RegExp _tokenDeCantidad = RegExp(
  r'^(\d{1,4})(?:[,.](\d{1,3}))?\s*'
  r'(UN|UNID|UNIDADES?|U|KG|KILOS?|GR|GRS|LT|LTS|LITROS?|MT|MTS|METROS?'
  r'|CJ|CAJAS?|SACOS?|PZA|PZAS|PIEZAS?|ROLLOS?|PLIEGOS?|BOLSAS?)?\b',
);

/// Palabras de cabecera y de pie que NUNCA son un artículo.
///
/// `TOTAL`, `SUBTOTAL`, `IVA` y `NETO` están aquí a propósito aunque lleven
/// un monto al lado: son el resumen de la boleta, no mercadería. Dejarlos
/// pasar metería "Total" como un material de $37.980 en el inventario.
final RegExp _ruido = RegExp(
  r'(R\.?U\.?T|GIRO|FOLIO|S\.?I\.?I|TIMBRE|BOLETA|FACTURA|TOTAL|SUBTOTAL'
  r'|IVA|NETO|EXENTO|VUELTO|EFECTIVO|TARJETA|DEBITO|CREDITO|GRACIAS'
  r'|FECHA|HORA|CAJA|CAJER)',
  caseSensitive: false,
);

/// La fila de encabezado de la tabla de artículos.
///
/// Exige DOS palabras de columna, no una: con una sola, un artículo
/// llamado "CAJA DE PRECIO ESPECIAL" cortaría la boleta por la mitad.
///
/// Para qué sirve: todo lo que está POR ENCIMA de esta fila es cabecera de
/// la boleta —nombre del local, RUT, giro, dirección, folio, fecha— y no
/// puede ser mercadería. Sin esto, `AV. LOS ALERCES 1842 - PUERTO VARAS`
/// entraba al inventario como un material de 1.842 pesos, porque `1842`
/// casa con el patrón de dinero y la dirección no está en la lista de
/// ruido. Visto en emulator-5554 con una boleta de verdad.
///
/// Si una boleta NO tiene fila de encabezado, no se descarta nada: la
/// regla solo puede quitar lo que está antes de algo que existe.
final RegExp _encabezadoDeColumnas = RegExp(
  r'(CANT|CANTIDAD|DESCRIPCI|DETALLE|ART[IÍ]CULO|PRODUCTO|GLOSA)'
  r'.*'
  r'(DESCRIPCI|DETALLE|P\.?\s?UNIT|PRECIO|TOTAL|VALOR|IMPORTE|MONTO)',
  caseSensitive: false,
);

/// Solo una fecha: `12/10/2026`, `12-10-26`, `12.10.2026`.
final RegExp _soloFecha = RegExp(r'^\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}$');

/// Solo una hora: `14:32`, `14:32:05`.
final RegExp _soloHora = RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$');

final RegExp _letras = RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]');
final RegExp _espaciosRepetidos = RegExp(r'\s+');

/// Basura de los extremos del nombre, que queda al quitar los montos: el
/// `x` de "2 x 18.990", el guion de separación de columnas, el punto medio.
final RegExp _bordesABorrar = RegExp(r'^[\s\-–—x×*·.:,|/]+|[\s\-–—x×*·:,|/]+$');

/// Unidad escrita como la escribe la app: en plural y en minúscula.
///
/// El mapa es el contrato con el inventario, no una traducción libre: son
/// las unidades que `item_form_sheet.dart` sugiere y que la ficha dibuja
/// junto al stock ("4 sacos"). Si no hay token, `unidades`.
const Map<String, String> _unidades = {
  'UN': 'unidades',
  'U': 'unidades',
  'UNID': 'unidades',
  'UNIDAD': 'unidades',
  'UNIDADES': 'unidades',
  'KG': 'kg',
  'KILO': 'kg',
  'KILOS': 'kg',
  'GR': 'gr',
  'GRS': 'gr',
  'LT': 'litros',
  'LTS': 'litros',
  'LITRO': 'litros',
  'LITROS': 'litros',
  'MT': 'metros',
  'MTS': 'metros',
  'METRO': 'metros',
  'METROS': 'metros',
  'CJ': 'cajas',
  'CAJA': 'cajas',
  'CAJAS': 'cajas',
  'SACO': 'sacos',
  'SACOS': 'sacos',
  'PZA': 'piezas',
  'PZAS': 'piezas',
  'PIEZA': 'piezas',
  'PIEZAS': 'piezas',
  'ROLLO': 'rollos',
  'ROLLOS': 'rollos',
  'PLIEGO': 'pliegos',
  'PLIEGOS': 'pliegos',
  'BOLSA': 'bolsas',
  'BOLSAS': 'bolsas',
};

/// Sangría máxima, en píxeles de la imagen, para que una línea sin precio
/// cuente como continuación del nombre de la anterior.
const double _toleranciaDeSangria = 12;

/// Tolerancia, en pesos, al comprobar `cantidad × unitario ≈ total`.
///
/// Dos pesos y no cero porque el redondeo del punto de venta y el del OCR
/// no coinciden siempre al peso exacto.
const double _toleranciaDeTotal = 2;

/// Convierte el texto de una lectura en artículos propuestos.
///
/// Nunca lanza. Ante cualquier cosa inesperada devuelve menos artículos, no
/// un error: la pantalla de revisión ya sabe decir "no pude leer nada" y
/// ofrecer teclear.
LocalParse parseLineasDeBoleta(final ReceiptReading lectura) {
  final lineas = _desdeElEncabezado(_filasDeLaBoleta(_ordenadas(lectura.lines)));
  final items = <ScannedLineItem>[];
  var truncado = false;

  // Sangría de la última línea que SÍ produjo un artículo, para decidir si
  // la siguiente es la continuación de su nombre.
  double? sangriaDelUltimo;

  for (final linea in lineas) {
    final texto = linea.text.replaceAll(_espaciosRepetidos, ' ').trim();
    if (texto.isEmpty) continue;

    final todosLosMontos = _tokenDeDinero.allMatches(texto).toList();

    // EL ORDEN IMPORTA Y FUE UN DEFECTO. La cantidad se busca PRIMERO y los
    // montos se filtran a lo que quede detrás de ella. Al revés —que es lo
    // que decía la especificación— la línea `500 GR HARINA 1.200` salía
    // como "GR HARINA" a 500 pesos: el `500` de la cantidad también casa
    // con el patrón de dinero (`\d{3,9}`), así que se contaba dos veces.
    // Comprobado con un test que falla con el orden anterior.
    final cantidad = _cantidadInicial(texto);
    var montos = cantidad == null
        ? todosLosMontos
        : todosLosMontos.where((final m) => m.start >= cantidad.fin).toList();

    // Si al apartar la cantidad no queda ni un monto, el número del
    // principio NO era una cantidad: era el precio. Se descarta la lectura
    // de cantidad y se vuelve a mirar la línea entera.
    final cant = montos.isEmpty ? null : cantidad;
    if (montos.isEmpty) montos = todosLosMontos;

    // ─── Paso 8: nombre partido en dos líneas ──────────────────────────
    // Una línea sin dinero y sin cantidad inicial, con la misma sangría que
    // la anterior y justo detrás de un artículo, es la segunda mitad de su
    // nombre. Es el caso corriente de una boleta térmica de 40 columnas.
    if (todosLosMontos.isEmpty && cantidad == null) {
      if (items.isNotEmpty &&
          sangriaDelUltimo != null &&
          (linea.left - sangriaDelUltimo).abs() < _toleranciaDeSangria &&
          !_esRuido(texto)) {
        final anterior = items.removeLast();
        items.add(
          anterior.copyWith(
            name: _recortar('${anterior.name} $texto'),
          ),
        );
      }
      continue;
    }

    // ─── Paso 2: ruido de cabecera y pie ───────────────────────────────
    if (_esRuido(texto)) {
      sangriaDelUltimo = null;
      continue;
    }

    if (montos.isEmpty) {
      // Hay cantidad pero no precio: no es una línea de artículo utilizable
      // (podría ser "2 PAGINAS" de un pie). Se descarta en silencio en vez
      // de inventar un precio de cero.
      sangriaDelUltimo = null;
      continue;
    }

    final nombre = _nombreDeLaLinea(texto, montos, cant);
    if (nombre.isEmpty || !_letras.hasMatch(nombre)) {
      sangriaDelUltimo = null;
      continue;
    }

    final unidades = cant?.valor ?? 1;
    final precio = _precioUnitario(montos, unidades);
    if (precio == null) {
      sangriaDelUltimo = null;
      continue;
    }

    if (items.length >= kMaxArticulosPorBoleta) {
      truncado = true;
      break;
    }

    items.add(
      ScannedLineItem(
        name: nombre,
        rawQuantity: unidades,
        unit: cant?.unidad ?? 'unidades',
        unitPrice: precio.valor,
        ambiguous: precio.ambiguo,
      ),
    );
    sangriaDelUltimo = linea.left;
  }

  return LocalParse(items: items, truncated: truncado);
}

// ─── Piezas internas ───────────────────────────────────────────────────

/// Ordena por `top` y, a igual `top`, por `left`.
///
/// ML Kit agrupa en bloques y los bloques no vienen en orden de lectura, así
/// que sin esto la continuación de un nombre podía llegar antes que el
/// nombre.
List<OcrLine> _ordenadas(final List<OcrLine> lineas) {
  final copia = [...lineas];
  copia.sort((final a, final b) {
    final porArriba = a.top.compareTo(b.top);
    return porArriba != 0 ? porArriba : a.left.compareTo(b.left);
  });
  return copia;
}

/// Reensambla las FILAS de la boleta a partir de los trozos de ML Kit.
///
/// ═══ EL DEFECTO QUE ARREGLA, Y CÓMO SE ENCONTRÓ ═══
///
/// Una `TextLine` de ML Kit NO es una línea de la boleta: es un trozo de
/// texto seguido. En una boleta con columnas, el hueco entre ellas basta
/// para que cada columna salga como su propia `TextLine`. Medido en
/// emulator-5554 sobre una boleta de verdad, la fila
///
///     2 SACOS    ARCILLA GRES 25K     18.990    37.980
///
/// llegó como CUATRO líneas con el mismo `top` (297, 297, 297, 294) y
/// `left` distintos (51, 195, 514, 639).
///
/// Consecuencia, que es lo que se vio en pantalla: ninguno de los seis
/// artículos de la boleta salió. "ARCILLA GRES 25K" no tenía monto, así que
/// se descartaba; "18.990" no tenía nombre, así que también. Lo único que
/// entró fueron tres falsos positivos de la cabecera y del pie.
///
/// Los 87 tests estaban en verde mientras tanto, porque todos le daban al
/// parser una línea por fila: la forma que ML Kit NO devuelve. Por eso esta
/// función existe y por eso la prueba de verdad fue mirar la pantalla.
///
/// Criterio: dos trozos son de la misma fila si sus `top` se diferencian en
/// menos de la mitad del alto de su texto. Relativo al alto y no en píxeles
/// absolutos, porque una foto de 3000 px de ancho y una de 1000 no tienen
/// la misma escala. Dentro de la fila se ordenan por `left`, que es el
/// orden de lectura.
List<OcrLine> _filasDeLaBoleta(final List<OcrLine> ordenadas) {
  if (ordenadas.isEmpty) return const [];

  final filas = <List<OcrLine>>[];
  var actual = <OcrLine>[ordenadas.first];
  var referencia = ordenadas.first.top;
  var altoDeLaFila = ordenadas.first.height;

  for (final linea in ordenadas.skip(1)) {
    final tolerancia = _toleranciaVertical(altoDeLaFila, linea.height);
    if ((linea.top - referencia).abs() <= tolerancia) {
      actual.add(linea);
      if (linea.height > altoDeLaFila) altoDeLaFila = linea.height;
    } else {
      filas.add(actual);
      actual = [linea];
      referencia = linea.top;
      altoDeLaFila = linea.height;
    }
  }
  filas.add(actual);

  return [
    for (final fila in filas)
      () {
        fila.sort((final a, final b) => a.left.compareTo(b.left));
        return OcrLine(
          text: fila.map((final l) => l.text).join(' '),
          confidence: _confianzaDeLaFila(fila),
          top: fila.first.top,
          // La sangría de la fila es la del trozo MÁS A LA IZQUIERDA: es la
          // que compara el paso 8 para decidir si una fila sin precio es la
          // continuación del nombre de la anterior.
          left: fila.first.left,
          height: fila.map((final l) => l.height).reduce(math.max),
        );
      }(),
  ];
}

/// Cuánto puede variar el `top` de dos trozos de la misma fila.
///
/// Medio alto de texto, con un suelo de 6 px para el caso de que ML Kit no
/// informe el alto (o de un test que escriba las líneas a mano sin él).
double _toleranciaVertical(final double altoA, final double altoB) {
  final alto = math.max(altoA, altoB);
  return math.max(alto * 0.5, 6);
}

double? _confianzaDeLaFila(final List<OcrLine> fila) {
  var suma = 0.0;
  var cuantas = 0;
  for (final linea in fila) {
    final c = linea.confidence;
    if (c != null && c.isFinite) {
      suma += c;
      cuantas++;
    }
  }
  return cuantas == 0 ? null : suma / cuantas;
}

/// Descarta todo lo que está por encima del encabezado de columnas.
///
/// Devuelve [filas] tal cual si no hay encabezado: la regla solo puede
/// quitar lo que está antes de algo que existe.
List<OcrLine> _desdeElEncabezado(final List<OcrLine> filas) {
  for (var i = 0; i < filas.length; i++) {
    if (_encabezadoDeColumnas.hasMatch(filas[i].text)) {
      return filas.sublist(i + 1);
    }
  }
  return filas;
}

bool _esRuido(final String texto) {
  if (_soloFecha.hasMatch(texto)) return true;
  if (_soloHora.hasMatch(texto)) return true;
  if (_letras.allMatches(texto).length < 3) return true;
  return _ruido.hasMatch(texto);
}

class _Cantidad {
  final double valor;
  final String? unidad;
  final int fin;

  const _Cantidad(this.valor, this.unidad, this.fin);
}

/// Cantidad al principio de la línea, o `null`.
///
/// Devuelve también dónde acaba, porque quien llama necesita descartar los
/// montos que caen dentro de ese tramo: el `500` de `500 GR HARINA 1.200`
/// casa con el patrón de dinero y sin eso se contaría dos veces.
_Cantidad? _cantidadInicial(final String texto) {
  final m = _tokenDeCantidad.firstMatch(texto);
  if (m == null) return null;

  final entero = m.group(1);
  if (entero == null) return null;
  final decimales = m.group(2);
  final valor = double.tryParse(
    decimales == null ? entero : '$entero.$decimales',
  );
  if (valor == null || valor <= 0) return null;

  final token = m.group(3)?.toUpperCase();
  return _Cantidad(valor, token == null ? null : _unidades[token], m.end);
}

/// El nombre: lo que queda al quitar la cantidad inicial y todos los montos.
String _nombreDeLaLinea(
  final String texto,
  final List<RegExpMatch> montos,
  final _Cantidad? cantidad,
) {
  // Se construye por rangos y no con `replaceAll` para no borrar por
  // casualidad un número que forme parte del nombre ("GRES 25K"): solo se
  // quitan los tramos exactos que el motor marcó como monto.
  final fuera = <List<int>>[
    if (cantidad != null) [0, cantidad.fin],
    for (final m in montos) [m.start, m.end],
  ];

  final buffer = StringBuffer();
  for (var i = 0; i < texto.length; i++) {
    final dentroDeUnMonto = fuera.any(
      (final rango) => i >= rango[0] && i < rango[1],
    );
    if (!dentroDeUnMonto) buffer.write(texto[i]);
  }

  return _recortar(buffer.toString().replaceAll(_espaciosRepetidos, ' '));
}

String _recortar(final String bruto) {
  var texto = bruto.replaceAll(_espaciosRepetidos, ' ').trim();
  texto = texto.replaceAll(_bordesABorrar, '').trim();
  if (texto.length > kMaxNombreArticulo) {
    texto = texto.substring(0, kMaxNombreArticulo).trim();
  }
  return texto;
}

class _Precio {
  final double valor;
  final bool ambiguo;

  const _Precio(this.valor, {this.ambiguo = false});
}

/// Decide cuál de los montos de la línea es el PRECIO POR UNIDAD.
///
/// Criterio, en orden:
///   · Un solo monto → es el precio unitario, y se marca ambiguo. Es la
///     decisión del paso 7 de la especificación y la que más se puede
///     equivocar, así que se dice en pantalla: `2 × $18.990 = $37.980`
///     deja la consecuencia a la vista antes de guardar.
///   · Varios montos → el que cumpla `cantidad × p ≈ último` es el
///     unitario. Si ninguno lo cumple, el primero, marcado ambiguo.
_Precio? _precioUnitario(final List<RegExpMatch> montos, final double cant) {
  final valores = <double>[];
  for (final m in montos) {
    final valor = parseCurrencyInput(m.group(0) ?? '');
    if (valor != null && valor > 0) valores.add(valor);
  }
  if (valores.isEmpty) return null;
  if (valores.length == 1) return _Precio(valores.first, ambiguo: true);

  // Se recorre POR ÍNDICE y no por valor: con `[990, 990]` —cantidad 1,
  // unitario y total iguales— comparar por valor saltaba los dos candidatos
  // y el artículo salía marcado como ambiguo sin serlo.
  final ultimo = valores.last;
  for (var i = 0; i < valores.length - 1; i++) {
    if ((cant * valores[i] - ultimo).abs() <= _toleranciaDeTotal) {
      return _Precio(valores[i]);
    }
  }
  return _Precio(valores.first, ambiguo: true);
}
