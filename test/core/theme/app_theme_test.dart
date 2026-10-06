import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';

/// Blinda el contrato del tema claro único (docs/DISENO-v2.md, paso 4).
///
/// Lo que se comprueba aquí es lo que no se ve en una captura: que el campo
/// tiene un borde real, que el botón deshabilitado es legible, que no hay
/// sombra en ningún sitio y que el radio del sistema no se escapa de 16 dp.
void main() {
  final theme = AppTheme.lightTheme;

  Color? resolve(final WidgetStateProperty<Color?>? property,
          final Set<WidgetState> states) =>
      property?.resolve(states);

  double radiusOf(final OutlinedBorder? shape) {
    final border = shape as RoundedRectangleBorder?;
    final radius = border?.borderRadius as BorderRadius?;
    return radius?.topLeft.x ?? -1;
  }

  group('tema claro único', () {
    test('no existe darkTheme', () {
      // El getter se borró en el paso 3. Si alguien lo reintroduce, este
      // test no compila, que es exactamente el aviso que se quiere.
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppPalette.canvas);
    });

    test('la familia se declara en la raíz', () {
      expect(theme.textTheme.titleLarge?.fontFamily, 'Manrope');
    });

    test('Material 3 sin tinte de elevación', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.surfaceTint, Colors.transparent);
    });

    test('sin onda circular en ningún control', () {
      expect(theme.splashFactory, NoSplash.splashFactory);
      expect(theme.splashColor, Colors.transparent);
      expect(theme.highlightColor, Colors.transparent);
    });
  });

  group('campo de formulario', () {
    test('tiene un borde visible, no BorderSide.none', () {
      // El defecto que arregla: `border` y `enabledBorder` estaban en
      // `BorderSide.none` sobre un relleno gris que daba 1,05:1 contra el
      // blanco de la tarjeta. El campo era invisible.
      final input = theme.inputDecorationTheme;
      for (final border in [input.border, input.enabledBorder]) {
        final side = (border as OutlineInputBorder?)?.borderSide;
        expect(side, isNotNull);
        expect(side!.style, BorderStyle.solid);
        expect(side.width, greaterThan(0));
        expect(side.color, AppPalette.borderField);
      }
    });

    test('el relleno es blanco para que el placeholder cumpla AA', () {
      expect(theme.inputDecorationTheme.fillColor, AppPalette.surface);
      expect(theme.inputDecorationTheme.hintStyle?.color,
          AppPalette.textMuted);
    });

    test('radio 8 en los cinco borders, no 32', () {
      final input = theme.inputDecorationTheme;
      for (final border in [
        input.border,
        input.enabledBorder,
        input.focusedBorder,
        input.errorBorder,
        input.focusedErrorBorder,
      ]) {
        final shape = border as OutlineInputBorder?;
        expect((shape?.borderRadius)?.topLeft.x, AppRadius.r8);
      }
    });

    test('el foco solo cambia color y grosor, nunca el padding', () {
      final input = theme.inputDecorationTheme;
      final reposo = input.enabledBorder as OutlineInputBorder?;
      final foco = input.focusedBorder as OutlineInputBorder?;
      expect(foco?.borderSide.color, AppPalette.brand);
      expect(foco?.borderSide.width, AppSizes.borderEmphasis);
      expect(reposo?.borderRadius, foco?.borderRadius);
    });
  });

  group('botón primario', () {
    final style = theme.elevatedButtonTheme.style!;

    test('alto 48 y radio 12, no 56 y 100', () {
      final size = style.minimumSize?.resolve(const {});
      expect(size?.height, AppSizes.buttonHeight);
      expect(size?.height, 48);
      expect(radiusOf(style.shape?.resolve(const {})), AppRadius.r12);
    });

    test('cero elevación y cero sombra', () {
      expect(style.elevation?.resolve(const {}), 0);
      expect(style.shadowColor?.resolve(const {}), Colors.transparent);
    });

    test('presionado da el color exacto del sistema, no un matiz', () {
      expect(
        resolve(style.backgroundColor, const {WidgetState.pressed}),
        AppPalette.brandPressed,
      );
    });

    test('deshabilitado es legible: sunken con texto textMuted', () {
      // Antes: relleno #CBD5E1 con texto blanco encima, 1,48:1.
      expect(
        resolve(style.backgroundColor, const {WidgetState.disabled}),
        AppPalette.sunken,
      );
      expect(
        resolve(style.foregroundColor, const {WidgetState.disabled}),
        AppPalette.textMuted,
      );
    });

    test('el texto sale del textTheme, no de un TextStyle a mano', () {
      // No se comparan los objetos enteros: `ThemeData` normaliza el
      // `textTheme` al construirse y le añade `debugLabel` y `decoration`,
      // así que el estilo que se lee de vuelta nunca es identico al que se
      // pasó. Lo que importa es que lleve las variaciones de la fuente: si
      // alguien escribiera el estilo a mano, `fontVariations` vendría vacío.
      final label = style.textStyle?.resolve(const {});
      final esperado = theme.textTheme.labelLarge;
      expect(label?.fontSize, esperado?.fontSize);
      expect(label?.fontWeight, esperado?.fontWeight);
      expect(label?.fontFamily, esperado?.fontFamily);
      expect(label?.fontVariations, esperado?.fontVariations);
      expect(label?.fontVariations, isNotEmpty);
    });
  });

  group('botón secundario y de texto', () {
    test('el secundario lleva borde de 1 dp y fondo blanco', () {
      final style = theme.outlinedButtonTheme.style!;
      final side = style.side?.resolve(const {});
      expect(side?.color, AppPalette.border);
      expect(side?.width, AppSizes.borderHairline);
      expect(resolve(style.backgroundColor, const {}), AppPalette.surface);
      expect(radiusOf(style.shape?.resolve(const {})), AppRadius.r12);
    });

    test('el de texto mide 40 pero con caja táctil de 48', () {
      final style = theme.textButtonTheme.style!;
      expect(style.minimumSize?.resolve(const {})?.height, 40);
      expect(style.tapTargetSize, MaterialTapTargetSize.padded);
      expect(resolve(style.foregroundColor, const {}), AppPalette.brand);
      expect(
        resolve(style.backgroundColor, const {WidgetState.pressed}),
        AppPalette.brandSurface,
      );
    });

    test('el control de solo icono tiene caja de 48', () {
      final style = theme.iconButtonTheme.style!;
      final size = style.minimumSize?.resolve(const {});
      expect(size?.width, AppSizes.minTouchTarget);
      expect(size?.height, AppSizes.minTouchTarget);
    });
  });

  group('superficies, líneas y sombras', () {
    test('el divisor va a sangre completa', () {
      expect(theme.dividerTheme.indent, 0);
      expect(theme.dividerTheme.endIndent, 0);
      expect(theme.dividerTheme.color, AppPalette.hairline);
    });

    test('las tres superficies elevadas no llevan elevación', () {
      expect(theme.bottomSheetTheme.elevation, 0);
      expect(theme.bottomSheetTheme.modalElevation, 0);
      expect(theme.dialogTheme.elevation, 0);
      expect(theme.snackBarTheme.elevation, 0);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.navigationRailTheme.elevation, 0);
    });

    test('la hoja modal es el único radio de 16 del sistema', () {
      final shape = theme.bottomSheetTheme.shape as RoundedRectangleBorder?;
      final radius = shape?.borderRadius as BorderRadius?;
      expect(radius?.topLeft.x, AppRadius.r16);
      expect(radius?.bottomLeft.x, AppRadius.r0);
    });

    test('ningún radio del tema pasa de 16 dp', () {
      final radios = <double>[
        radiusOf(theme.elevatedButtonTheme.style?.shape?.resolve(const {})),
        radiusOf(theme.outlinedButtonTheme.style?.shape?.resolve(const {})),
        radiusOf(theme.textButtonTheme.style?.shape?.resolve(const {})),
        radiusOf(theme.iconButtonTheme.style?.shape?.resolve(const {})),
        radiusOf(theme.dialogTheme.shape as OutlinedBorder?),
        radiusOf(theme.snackBarTheme.shape as OutlinedBorder?),
      ];
      for (final radio in radios) {
        expect(radio, greaterThanOrEqualTo(0));
        expect(radio, lessThanOrEqualTo(AppRadius.r16));
      }
    });

    test('el título de la barra va a la izquierda', () {
      expect(theme.appBarTheme.centerTitle, isFalse);
      final titulo = theme.appBarTheme.titleTextStyle;
      expect(titulo?.fontSize, theme.textTheme.headlineMedium?.fontSize);
      expect(titulo?.fontVariations, isNotEmpty);
    });

    test('la barra de progreso mide 6 dp sobre pista sunken', () {
      expect(theme.progressIndicatorTheme.linearMinHeight, 6);
      expect(theme.progressIndicatorTheme.linearTrackColor,
          AppPalette.sunken);
    });
  });

  group('esquema de color', () {
    test('el borde delineado cumple 1.4.11, no es la línea decorativa', () {
      expect(theme.colorScheme.outline, AppPalette.borderField);
      expect(theme.colorScheme.outlineVariant, AppPalette.hairline);
    });

    test('el error es el rojo que cumple AA', () {
      expect(theme.colorScheme.error, AppPalette.danger);
      expect(theme.colorScheme.onError, AppPalette.textOnBrand);
    });

    test('no queda rastro del coral: el secundario es la marca', () {
      expect(theme.colorScheme.secondary, AppPalette.brand);
    });
  });
}
