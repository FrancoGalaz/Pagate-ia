// ═══════════════════════════════════════════════════════════════════════
// NOMBRES DE MES — ÚNICA FUENTE DE VERDAD
// ═══════════════════════════════════════════════════════════════════════
// Propósito: unificar las cinco tablas de nombres de mes que convivían en
// la app, cada una con su propia capitalización y su propio formato de
// fecha:
//   · finances_summary_entity.dart  → `_monthNames`  ('Enero')
//   · home_tab.dart                 → `months`       ('Ene', con un '' de
//                                                     relleno en el índice 0)
//   · finanzas_tab.dart             → `_months`      ('ene')
//   · transaction_form_sheet.dart   → `_months`      ('ene')
//   · pdf_report_service.dart       → `months`       ('enero')
// El resultado era que la misma fecha se leía "12 Oct, 2026" en Inicio y
// "12 oct" en Finanzas.
//
// Por qué una tabla a mano y no `DateFormat('MMMM', 'es')`: los símbolos de
// fecha de `intl` solo se registran si se importa
// `date_symbol_data_local.dart` y se llama a `initializeDateFormatting`.
// Sin eso, el único locale disponible es `en_US` y los meses saldrían en
// inglés. Los símbolos de NÚMERO (los que usa `currency_formatter.dart`) sí
// vienen cargados de fábrica, de ahí la diferencia de criterio entre los dos
// archivos. Cuando el paso 8 de la migración añada `flutter_localizations`
// se puede reevaluar; hoy una tabla de doce cadenas es más barata y no
// depende del orden de arranque.
// ═══════════════════════════════════════════════════════════════════════

/// Nombres completos en minúscula. Índice 0 = enero.
///
/// En minúscula porque en español los meses no se capitalizan; quien
/// necesite inicial mayúscula usa [monthNameCapitalized].
const List<String> kMonthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Abreviaturas de tres letras en minúscula. Índice 0 = enero.
const List<String> kMonthAbbreviations = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

bool _isValidMonth(final int month) => month >= 1 && month <= 12;

/// `10` → `'octubre'`. Devuelve cadena vacía si el mes está fuera de rango.
String monthName(final int month) =>
    _isValidMonth(month) ? kMonthNames[month - 1] : '';

/// `10` → `'Octubre'`. Para títulos, donde la mayúscula inicial es de la
/// frase y no del mes.
String monthNameCapitalized(final int month) {
  final name = monthName(month);
  if (name.isEmpty) return name;
  return '${name[0].toUpperCase()}${name.substring(1)}';
}

/// `10` → `'oct'`. Devuelve cadena vacía si el mes está fuera de rango.
String monthAbbreviation(final int month) =>
    _isValidMonth(month) ? kMonthAbbreviations[month - 1] : '';

/// Metadato de una fila de movimiento: `'12 oct'`.
///
/// Es el formato que manda el sistema visual para la segunda línea de una
/// fila (docs/DISENO-v2.md, componente 7): sin año, porque la lista ya está
/// filtrada por mes.
String formatDayMonth(final DateTime date) =>
    '${date.day} ${monthAbbreviation(date.month)}';

/// `'12 oct 2026'`. Para fechas fuera del mes en curso, donde el año importa.
String formatDayMonthYear(final DateTime date) =>
    '${date.day} ${monthAbbreviation(date.month)} ${date.year}';

/// `'12 de octubre de 2026'`. Para el pie del informe en PDF y textos
/// corridos.
String formatLongDate(final DateTime date) =>
    '${date.day} de ${monthName(date.month)} de ${date.year}';

/// Convierte `'2026-10'` en `'Octubre 2026'`. Si la clave no tiene el
/// formato `yyyy-MM` la devuelve tal cual.
String monthLabelFromMonthKey(final String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final month = int.tryParse(parts[1]);
  if (month == null || !_isValidMonth(month)) return monthKey;
  return '${monthNameCapitalized(month)} ${parts[0]}';
}

/// Etiqueta corta de un selector de periodo: `'oct 26'`.
///
/// El mes en curso no se etiqueta con su nombre sino con "Este mes"; eso lo
/// decide el componente, no este formateador.
String shortMonthLabelFromMonthKey(final String monthKey) {
  final parts = monthKey.split('-');
  if (parts.length != 2) return monthKey;
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[0]);
  if (month == null || year == null || !_isValidMonth(month)) return monthKey;
  final shortYear = (year % 100).toString().padLeft(2, '0');
  return '${monthAbbreviation(month)} $shortYear';
}
