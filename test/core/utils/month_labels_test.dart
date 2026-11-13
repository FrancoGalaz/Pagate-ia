import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/utils/month_labels.dart';

/// Comprueba que la tabla única de meses cubre los cinco formatos que antes
/// vivían repartidos por la app, y que ninguno de los helpers revienta con
/// un mes fuera de rango o una clave mal formada.
void main() {
  test('las dos tablas tienen los doce meses', () {
    expect(kMonthNames, hasLength(12));
    expect(kMonthAbbreviations, hasLength(12));
    expect(kMonthNames.toSet(), hasLength(12));
    expect(kMonthAbbreviations.toSet(), hasLength(12));
  });

  test('los meses van en minúscula y las abreviaturas en tres letras', () {
    for (final name in kMonthNames) {
      expect(name, name.toLowerCase());
    }
    for (final abbreviation in kMonthAbbreviations) {
      expect(abbreviation.length, 3);
    }
  });

  test('monthName y monthAbbreviation usan base 1', () {
    expect(monthName(1), 'enero');
    expect(monthName(10), 'octubre');
    expect(monthName(12), 'diciembre');
    expect(monthAbbreviation(1), 'ene');
    expect(monthAbbreviation(9), 'sep');
  });

  test('monthNameCapitalized sube solo la primera letra', () {
    expect(monthNameCapitalized(10), 'Octubre');
    expect(monthNameCapitalized(9), 'Septiembre');
  });

  test('un mes fuera de rango devuelve cadena vacía y no lanza', () {
    expect(monthName(0), '');
    expect(monthName(13), '');
    expect(monthAbbreviation(-1), '');
    expect(monthNameCapitalized(99), '');
  });

  test('los tres formatos de fecha', () {
    final date = DateTime(2026, 10, 12);
    expect(formatDayMonth(date), '12 oct');
    expect(formatDayMonthYear(date), '12 oct 2026');
    expect(formatLongDate(date), '12 de octubre de 2026');
  });

  test('monthLabelFromMonthKey convierte yyyy-MM en "Octubre 2026"', () {
    expect(monthLabelFromMonthKey('2026-10'), 'Octubre 2026');
    expect(monthLabelFromMonthKey('2025-03'), 'Marzo 2025');
  });

  test('una clave inválida se devuelve tal cual', () {
    expect(monthLabelFromMonthKey('2026'), '2026');
    expect(monthLabelFromMonthKey('2026-13'), '2026-13');
    expect(monthLabelFromMonthKey('abc-xx'), 'abc-xx');
    expect(shortMonthLabelFromMonthKey('2026'), '2026');
  });

  test('shortMonthLabelFromMonthKey da la etiqueta del selector', () {
    expect(shortMonthLabelFromMonthKey('2026-10'), 'oct 26');
    expect(shortMonthLabelFromMonthKey('2005-01'), 'ene 05');
  });
}
