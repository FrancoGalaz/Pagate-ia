import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════════════════════
// MONEDA — ÚNICA FUENTE DE VERDAD PARA FORMATEAR Y LEER DINERO
// ═══════════════════════════════════════════════════════════════════════
// Propósito: reemplazar las seis implementaciones de moneda que convivían
// en la app (`_money` de finanzas_tab, las dos `_fmt` de home_tab más una
// copia en línea, `_fmt` de financial_charts y `_fmt` de
// pdf_report_service), cada una con su propio criterio de abreviatura y de
// signo. Ninguna pantalla vuelve a formatear dinero a mano.
//
// Reglas del sistema visual (docs/DISENO-v2.md, "Tipografía" y "Plan de
// migración", paso 0):
//   · Nunca se abrevia una cifra, salvo en los ejes de un gráfico.
//   · El signo negativo es U+2212 MINUS SIGN (−), no el guion ASCII: el
//     guion mide 840/2000 em en Manrope y el minus 1080/2000, así que el
//     guion hunde la columna de montos.
//   · Los ingresos llevan `+` explícito y el signo va antes del símbolo.
// ═══════════════════════════════════════════════════════════════════════

/// Peso chileno: sin decimales, miles separados por punto.
const String kCurrencyClp = 'CLP';

/// Dólar estadounidense: dos decimales, miles separados por coma.
const String kCurrencyUsd = 'USD';

/// Moneda que se asume cuando la pantalla todavía no tiene el perfil del
/// usuario a mano.
///
/// El modelo acepta `CLP | USD` (docs/ARQUITECTURA.md) pero hoy ninguna
/// pantalla propaga `profile.currency` hasta sus filas. Mientras eso sea
/// así, este valor mantiene el comportamiento actual (todo en pesos) sin
/// inventar una moneda distinta. Propagarlo es decisión de producto
/// pendiente: ver docs/DISENO-v2.md, "¿Se mantiene la moneda configurable?".
const String kFallbackCurrency = kCurrencyClp;

/// U+2212 MINUS SIGN.
const String _minusSign = '−';

/// Formateadores creados una sola vez: construir un [NumberFormat] cuesta
/// parsear el patrón, y estas funciones se llaman dentro de `build`.
///
/// `customPattern` no es cosmético. Verificado en intl 0.20.2: el mapa
/// `numberFormatSymbols` no tiene entrada `es_CL`, así que `verifiedLocale`
/// cae al idioma corto `es`, cuyo `CURRENCY_PATTERN` es `#,##0.00 ¤`
/// — es decir, pone el símbolo DESPUÉS del número (`1.234.567 $`). Chile
/// escribe `$1.234.567`. El patrón explícito `¤#,##0` fija el símbolo
/// delante y conserva de `es` lo único que se necesita: punto como
/// separador de miles y coma como decimal.
final NumberFormat _clpFormat = NumberFormat.currency(
  locale: 'es_CL',
  symbol: r'$',
  decimalDigits: 0,
  customPattern: '¤#,##0',
);

/// `en_US` sí existe en el mapa de símbolos y su patrón ya es `¤#,##0.00`.
final NumberFormat _usdFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: r'$',
  decimalDigits: 2,
);

/// Abreviatura para los ejes de los gráficos: `$23,8 mil`.
///
/// `NumberFormat.compactCurrency` no acepta `customPattern`, y el patrón
/// compacto de `es` también deja el símbolo al final (`23,8 mil $`). Por eso
/// se compone: número compacto de `es` más el símbolo delante.
final NumberFormat _clpCompact = NumberFormat.compact(locale: 'es_CL');

final NumberFormat _usdCompact = NumberFormat.compactCurrency(
  locale: 'en_US',
  symbol: r'$',
);

/// Solo se aceptan dígitos y separadores; cualquier letra invalida la
/// entrada. Se declara una vez porque se usa en cada pulsación de tecla.
final RegExp _onlyNumericChars = RegExp(r'^[0-9.,]+$');
final RegExp _anyDigit = RegExp('[0-9]');

bool _isUsd(final String currency) => currency.toUpperCase() == kCurrencyUsd;

int _decimalDigits(final String currency) => _isUsd(currency) ? 2 : 0;

/// Redondea al número de decimales que la moneda va a mostrar.
///
/// Se hace ANTES de decidir el signo para que `-0,4` en pesos no salga como
/// `−$0`: lo que se muestra es `$0`, así que el signo no corresponde.
///
/// Un valor no finito (NaN o infinito, que puede llegar de un documento de
/// Firestore corrupto) se trata como 0 en vez de reventar: `num.round()`
/// lanza `UnsupportedError` sobre NaN.
num _quantize(final num value, final int decimals) {
  if (!value.isFinite) return 0;
  if (decimals == 0) return value.round();
  final factor = _pow10(decimals);
  return (value * factor).round() / factor;
}

int _pow10(final int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

/// Formatea un monto como `$1.234.567` (CLP) o `$1,234,567.89` (USD).
///
/// Los negativos salen con U+2212: `formatCurrency(-320, currency: 'CLP')`
/// devuelve `−$320`.
String formatCurrency(final num value, {required final String currency}) {
  final usd = _isUsd(currency);
  final rounded = _quantize(value, _decimalDigits(currency));
  final digits = (usd ? _usdFormat : _clpFormat).format(rounded.abs());
  return rounded < 0 ? '$_minusSign$digits' : digits;
}

/// Formatea un monto con signo explícito: `+$12.400` / `−$3.150`.
///
/// Es el formato de la columna de montos de una fila de movimiento, donde el
/// signo es la señal que distingue un ingreso de un gasto. El cero sale sin
/// signo.
String formatSigned(final num value, {required final String currency}) {
  final rounded = _quantize(value, _decimalDigits(currency));
  final digits = formatCurrency(rounded.abs(), currency: currency);
  if (rounded == 0) return digits;
  return '${rounded < 0 ? _minusSign : '+'}$digits';
}

/// Abrevia un monto. **Único uso permitido: los ejes y los rótulos de un
/// gráfico**, donde no cabe la cifra completa. Cualquier otro sitio usa
/// [formatCurrency].
String formatCompactCurrency(
  final num value, {
  required final String currency,
}) {
  final usd = _isUsd(currency);
  final abs = value.isFinite ? value.abs() : 0;
  final digits = usd ? _usdCompact.format(abs) : '\$${_clpCompact.format(abs)}';
  return value.isFinite && value < 0 ? '$_minusSign$digits' : digits;
}

/// Lee lo que el usuario escribe en un campo de monto y devuelve el número
/// real, o `null` si no hay número válido.
///
/// Es la mitad que faltaba del contrato. Hasta ahora los formularios hacían
/// `double.tryParse(texto.replaceAll(',', '.'))`, y con eso `"150.000"`
/// —ciento cincuenta mil pesos escritos como los escribe cualquiera en
/// Chile— se guardaba como **150**. El defecto estaba en
/// `transaction_form_sheet`, `finanzas_tab`, `setup_inicial_screen`,
/// `editar_perfil_screen` e `inventario_tab`.
///
/// Criterio, en orden:
///   1. Se descartan símbolo de moneda, espacios (incluidos los duros) y se
///      normaliza U+2212 a `-`.
///   2. Si quedan caracteres que no sean dígito, `.`, `,` o `-`, no es un
///      número: `null`.
///   3. Si aparecen los dos separadores, el **último** del texto es el
///      decimal y el otro es de miles (`1.234,56` → 1234.56;
///      `1,234.56` → 1234.56).
///   4. Si solo hay comas: una sola coma es decimal (convención chilena);
///      varias son separadores de miles.
///   5. Si solo hay puntos: son de miles si hay más de uno o si el último
///      grupo tiene exactamente 3 dígitos (`150.000` → 150000). Si no, el
///      punto es decimal (`150.5` → 150.5, `150.50` → 150.5).
///
/// Contrapartida asumida del punto 5: `"150.000"` no se puede leer como
/// "ciento cincuenta dólares con cero centavos". En un campo de dinero de
/// una app chilena, tres dígitos tras un punto son miles.
double? parseCurrencyInput(final String raw) {
  var text = raw
      .replaceAll(' ', '')
      .replaceAll(' ', '')
      .replaceAll(' ', '')
      .replaceAll(r'$', '')
      .replaceAll(_minusSign, '-')
      .trim();
  if (text.isEmpty) return null;

  var negative = false;
  if (text.startsWith('-')) {
    negative = true;
    text = text.substring(1);
  }
  if (text.isEmpty) return null;

  if (!_onlyNumericChars.hasMatch(text)) return null;
  if (!text.contains(_anyDigit)) return null;

  final lastDot = text.lastIndexOf('.');
  final lastComma = text.lastIndexOf(',');
  final dots = text.split('.').length - 1;
  final commas = text.split(',').length - 1;

  String? decimalSeparator;
  if (lastDot >= 0 && lastComma >= 0) {
    decimalSeparator = lastDot > lastComma ? '.' : ',';
  } else if (commas == 1) {
    decimalSeparator = ',';
  } else if (dots == 1) {
    final tail = text.substring(lastDot + 1);
    decimalSeparator = tail.length == 3 ? null : '.';
  }

  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '.' || char == ',') {
      if (char == decimalSeparator && i == text.lastIndexOf(char)) {
        buffer.write('.');
      }
      continue;
    }
    buffer.write(char);
  }

  final value = double.tryParse(buffer.toString());
  if (value == null || !value.isFinite) return null;
  return negative ? -value : value;
}
