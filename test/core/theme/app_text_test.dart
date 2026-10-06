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
        AppText.displayLarge: 700,
        AppText.displayMedium: 700,
        AppText.displaySmall: 700,
        AppText.headlineLarge: 700,
        AppText.headlineMedium: 700,
        AppText.headlineSmall: 600,
        AppText.titleLarge: 600,
        AppText.titleMedium: 600,
        AppText.titleSmall: 600,
        AppText.bodyLarge: 400,
        AppText.bodyMedium: 400,
        AppText.bodySmall: 400,
        AppText.labelLarge: 600,
        AppText.labelMedium: 600,
        AppText.labelSmall: 600,
        AppText.amountRow: 600,
        AppText.amountSmall: 600,
        AppText.amountField: 600,
      };

      expected.forEach((final style, final weight) {
        expect(wght(style), weight.toDouble(),
            reason: 'el eje wght no está en ${style.fontSize} dp');
        expect(style.fontWeight, FontWeight.values[(weight ~/ 100) - 1]);
        expect(style.fontFamily, kFontFamily);
      });
    });

    test('ningún slot pasa de w700: el w800 entero sale del sistema', () {
      for (final style in [
        AppText.displayLarge,
        AppText.displayMedium,
        AppText.displaySmall,
        AppText.headlineLarge,
      ]) {
        expect(wght(style)! <= 700, isTrue);
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
      expect(wght(textTheme.titleLarge), 600);
      expect(wght(textTheme.displayLarge), 700);
      expect(wght(textTheme.bodyMedium), 400);
      expect(textTheme.displayLarge?.leadingDistribution,
          TextLeadingDistribution.even);
      expect(textTheme.displayLarge?.fontFeatures?.first,
          const FontFeature.tabularFigures());
    });
  });
}
