import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/utils/currency_formatter.dart';

/// Verifica el contrato de moneda del sistema visual (docs/DISENO-v2.md,
/// paso 0 de la migración): cifras completas, separador de miles chileno,
/// signo U+2212 y lectura del formato que el usuario realmente escribe.
void main() {
  const minus = '−';

  group('formatCurrency en CLP', () {
    test('escribe la cifra completa con punto de miles y sin decimales', () {
      expect(formatCurrency(1234567, currency: kCurrencyClp), r'$1.234.567');
      expect(formatCurrency(1500, currency: kCurrencyClp), r'$1.500');
      expect(formatCurrency(320, currency: kCurrencyClp), r'$320');
      expect(formatCurrency(0, currency: kCurrencyClp), r'$0');
    });

    test('no abrevia: lo que reemplazó al "\$1234.6K" de Inicio', () {
      final formatted = formatCurrency(1234567.89, currency: kCurrencyClp);
      expect(formatted, r'$1.234.568');
      expect(formatted.contains('K'), isFalse);
    });

    test('pone el símbolo delante del número, no detrás', () {
      // intl 0.20.2 no tiene símbolos para es_CL y cae a es, cuyo patrón de
      // moneda deja el símbolo al final ("1.234 $"). El formateador fija un
      // patrón propio justamente para evitarlo.
      expect(formatCurrency(1234, currency: kCurrencyClp).startsWith(r'$'),
          isTrue);
      expect(formatCurrency(1234, currency: kCurrencyClp).contains(' '),
          isFalse);
    });

    test('el negativo usa U+2212 MINUS SIGN, no el guion ASCII', () {
      final formatted = formatCurrency(-320, currency: kCurrencyClp);
      expect(formatted, '$minus\$320');
      expect(formatted.startsWith(minus), isTrue);
      expect(formatted.contains('-'), isFalse);
    });

    test('un valor que redondea a cero no lleva signo', () {
      expect(formatCurrency(-0.4, currency: kCurrencyClp), r'$0');
    });

    test('un valor no finito se trata como cero en vez de lanzar', () {
      expect(formatCurrency(double.nan, currency: kCurrencyClp), r'$0');
      expect(formatCurrency(double.infinity, currency: kCurrencyClp), r'$0');
    });
  });

  group('formatCurrency en USD', () {
    test('usa dos decimales y coma de miles', () {
      expect(formatCurrency(1234567.89, currency: kCurrencyUsd),
          r'$1,234,567.89');
      expect(formatCurrency(5, currency: kCurrencyUsd), r'$5.00');
    });

    test('acepta el código en minúscula', () {
      expect(formatCurrency(5, currency: 'usd'), r'$5.00');
    });
  });

  group('formatSigned', () {
    test('los ingresos llevan + explícito y el signo va antes del símbolo',
        () {
      expect(formatSigned(12400, currency: kCurrencyClp), r'+$12.400');
    });

    test('los gastos empiezan por U+2212', () {
      final formatted = formatSigned(-3150, currency: kCurrencyClp);
      expect(formatted, '$minus\$3.150');
      expect(formatted.codeUnitAt(0), 0x2212);
    });

    test('el cero no lleva signo', () {
      expect(formatSigned(0, currency: kCurrencyClp), r'$0');
    });
  });

  group('formatCompactCurrency', () {
    test('abrevia en español para los ejes de los gráficos', () {
      final formatted = formatCompactCurrency(23800, currency: kCurrencyClp);
      expect(formatted.startsWith(r'$'), isTrue);
      expect(formatted.contains('mil'), isTrue);
      expect(formatted.contains('K'), isFalse);
    });

    test('en USD mantiene la abreviatura inglesa', () {
      expect(formatCompactCurrency(23800, currency: kCurrencyUsd), r'$23.8K');
    });
  });

  group('parseCurrencyInput', () {
    test('lee el formato chileno: "150.000" son ciento cincuenta mil', () {
      // Este es el defecto que bloqueaba la publicación: double.tryParse
      // devolvía 150 y la app guardaba mil veces menos de lo escrito.
      expect(parseCurrencyInput('150.000'), 150000);
      expect(parseCurrencyInput('800.000'), 800000);
      expect(parseCurrencyInput('1.234.567'), 1234567);
    });

    test('la coma sola es decimal', () {
      expect(parseCurrencyInput('150,5'), 150.5);
      expect(parseCurrencyInput('0,75'), 0.75);
    });

    test('con los dos separadores manda el último', () {
      expect(parseCurrencyInput('1.234,56'), 1234.56);
      expect(parseCurrencyInput('1,234.56'), 1234.56);
    });

    test('un punto con menos de tres decimales se lee como decimal', () {
      expect(parseCurrencyInput('150.5'), 150.5);
      expect(parseCurrencyInput('150.50'), 150.5);
    });

    test('ignora el símbolo, los espacios y el signo U+2212', () {
      expect(parseCurrencyInput(r' $ 1.500 '), 1500);
      expect(parseCurrencyInput('${minus}1.500'), -1500);
      expect(parseCurrencyInput('-1.500'), -1500);
      expect(parseCurrencyInput('1 500'), 1500);
    });

    test('rechaza lo que no es un número', () {
      expect(parseCurrencyInput(''), isNull);
      expect(parseCurrencyInput('   '), isNull);
      expect(parseCurrencyInput('abc'), isNull);
      expect(parseCurrencyInput('1.000 pesos'), isNull);
      expect(parseCurrencyInput('-'), isNull);
      expect(parseCurrencyInput('.'), isNull);
    });

    test('ida y vuelta: lo que se formatea se vuelve a leer igual', () {
      for (final value in [0, 320, 1500, 150000, 1234567]) {
        final text = formatCurrency(value, currency: kCurrencyClp);
        expect(parseCurrencyInput(text), value,
            reason: 'no se pudo releer "$text"');
      }
    });
  });
}
