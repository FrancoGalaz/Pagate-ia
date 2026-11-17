import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/theme/app_text.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';

/// Blinda el arreglo del defecto raíz: Manrope es una fuente variable cuyo
/// peso por defecto es 200 (ExtraLight), así que un `fontWeight` sin
/// `fontVariations` no selecciona ningún peso real del eje `wght`.
///
/// Si alguien vuelve a construir la escala con `TextStyle` a secas, o si
/// `TextTheme.apply` dejara de propagar los campos de fuente variable, estos
/// tests fallan antes de que el problema llegue a una pantalla.
void main() {
  double? wght(final TextStyle? style) {
    final variations = style?.fontVariations;
    if (variations == null) return null;
    for (final variation in variations) {
      if (variation.axis == 'wght') return variation.value;
    }
    return null;
  }

  group('AppText', () {
    test('cada slot mueve el eje wght y coincide con su fontWeight', () {
      final expected = <TextStyle, int>{
        AppText.displayLarge: 800,
        AppText.displayMedium: 800,
        AppText.displaySmall: 800,
        AppText.headlineLarge: 800,
        AppText.headlineMedium: 800,
        AppText.headlineSmall: 800,
        AppText.titleLarge: 800,
        AppText.titleMedium: 600,
        AppText.titleSmall: 600,
        AppText.bodyLarge: 400,
        AppText.bodyMedium: 400,
        AppText.bodySmall: 400,
        AppText.labelLarge: 600,
        AppText.labelMedium: 600,
        AppText.labelSmall: 600,
        AppText.amountRow: 800,
        AppText.amountSmall: 700,
        AppText.amountField: 600,
      };

      expected.forEach((final style, final weight) {
        expect(wght(style), weight.toDouble(),
            reason: 'el eje wght no está en ${style.fontSize} dp');
        expect(style.fontWeight, FontWeight.values[(weight ~/ 100) - 1]);
        expect(style.fontFamily, kFontFamily);
      });
    });

    test('variante A: títulos y cifras en w800, el cuerpo no pasa de w600', () {
      // docs/diseno/variantes-cabal.html: la jerarquía la dan los títulos y
      // las cifras en 800; el texto corriente se queda liviano.
      for (final style in [
        AppText.displayLarge,
        AppText.headlineMedium,
        AppText.titleLarge,
        AppText.amountRow,
      ]) {
        expect(wght(style), 800);
      }
      for (final style in [
        AppText.bodyLarge,
        AppText.bodyMedium,
        AppText.titleMedium,
        AppText.labelLarge,
      ]) {
        expect(wght(style)! <= 600, isTrue);
      }
    });

    test('todo el sistema reparte el leading de forma simétrica', () {
      // Manrope declara 1,366 em de caja intrínseca; sin `even` una cifra de
      // 40 dp con height 1,05 se dibuja descentrada.
      for (final style in [
        AppText.displayLarge,
        AppText.bodyMedium,
        AppText.labelSmall,
        AppText.amountRow,
      ]) {
        expect(style.leadingDistribution, TextLeadingDistribution.even);
      }
    });

    test('la familia display y los montos llevan cifras tabulares', () {
      for (final style in [
        AppText.displayLarge,
        AppText.displayMedium,
        AppText.displaySmall,
        AppText.amountRow,
        AppText.amountSmall,
        AppText.amountField,
      ]) {
        expect(style.fontFeatures, isNotNull);
        expect(style.fontFeatures!.first, const FontFeature.tabularFigures());
      }
    });

    test('los títulos NO llevan cifras tabulares', () {
      // Las cifras tabulares en prosa dejan huecos; la regla es que `tnum`
      // vive solo en la familia numérica.
      for (final style in [
        AppText.headlineLarge,
        AppText.headlineMedium,
        AppText.titleLarge,
        AppText.bodyMedium,
      ]) {
        expect(style.fontFeatures, isNull);
      }
    });

    test('weight() mueve el eje wght, no solo el fontWeight', () {
      // EL DEFECTO QUE CIERRA: `copyWith(fontWeight:)` no toca
      // `fontVariations`, y en una fuente variable gana `fontVariations`. Un
      // `titleLarge.copyWith(fontWeight: w800)` seguía dibujándose en 600.
      // Pasaba en 81 sitios de 26 archivos.
      final conCopyWith =
          AppText.titleMedium.copyWith(fontWeight: FontWeight.w800);
      expect(
        wght(conCopyWith),
        600,
        reason: 'copyWith no debería haber movido el eje: por eso existe '
            'AppText.weight',
      );

      final conHelper = AppText.weight(AppText.titleMedium, 800);
      expect(wght(conHelper), 800);
      expect(conHelper.fontWeight, FontWeight.w800);
    });

    test('weight() conserva todo lo demás del estilo', () {
      final base = AppText.amountRow.copyWith(color: const Color(0xFF101828));
      final movido = AppText.weight(base, 700);

      expect(movido.fontSize, base.fontSize);
      expect(movido.height, base.height);
      expect(movido.letterSpacing, base.letterSpacing);
      expect(movido.color, base.color);
      expect(movido.fontFamily, kFontFamily);
      expect(movido.leadingDistribution, TextLeadingDistribution.even);
      // Las cifras tabulares del monto no se pueden perder al cambiar el peso.
      expect(movido.fontFeatures?.first, const FontFeature.tabularFigures());
    });

    test('weight() acepta los siete pesos del eje de Manrope', () {
      for (final w in [200, 300, 400, 500, 600, 700, 800]) {
        final estilo = AppText.weight(AppText.bodyMedium, w);
        expect(wght(estilo), w.toDouble(), reason: 'wght $w');
        expect(estilo.fontWeight, FontWeight.values[(w ~/ 100) - 1]);
      }
    });

    test('la altura de línea se traduce de dp a multiplicador', () {
      expect(AppText.displayLarge.fontSize, 40);
      expect(AppText.displayLarge.height, closeTo(42 / 40, 0.0001));
      expect(AppText.bodySmall.fontSize, 13);
      expect(AppText.bodySmall.height, closeTo(18 / 13, 0.0001));
    });
  });

  group('AppTheme.lightTheme', () {
    test('declara la familia en la raíz, no solo en el textTheme', () {
      // Sin esto, fl_chart y los tooltips de la plataforma construyen su
      // propio TextStyle y caen en Roboto.
      expect(AppTheme.lightTheme.textTheme.titleLarge?.fontFamily,
          kFontFamily);
    });

    test('apply() no se come las variaciones de la fuente', () {
      // `TextTheme.apply` reconstruye cada estilo para teñirlo; si dejara de
      // propagar `fontVariations`, toda la app volvería a ExtraLight sin que
      // nada más fallara.
      final textTheme = AppTheme.lightTheme.textTheme;
      expect(wght(textTheme.titleLarge), 800);
      expect(wght(textTheme.displayLarge), 800);
      expect(wght(textTheme.bodyMedium), 400);
      expect(textTheme.displayLarge?.leadingDistribution,
          TextLeadingDistribution.even);
      expect(textTheme.displayLarge?.fontFeatures?.first,
          const FontFeature.tabularFigures());
    });
  });
}
