import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import 'app_text.dart';

// ═══════════════════════════════════════════════════════════════════════
// TEMA — CLARO ÚNICO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, con la paleta y los radios de la
// variante A (docs/diseno/variantes-cabal.html).
//
// Toda la configuración de Material vive aquí y ninguna pantalla sobreescribe
// estilos del tema en línea: consume tokens de AppPalette, AppSpacing,
// AppRadius y AppSizes.
//
// REGLA DURA DE ESTE ARCHIVO: ningún `TextStyle` se construye desde cero.
// Cada estilo de componente sale de `textTheme.loQueSea?.copyWith(...)`. Si
// se escribiera a mano, ese estilo no heredaría `fontVariations` y volvería a
// dibujarse en ExtraLight, dejando el paso 2 a medias. Los seis `fontSize`
// sueltos que quedaban (los otros cuatro vivían dentro del `darkTheme`
// borrado en el paso 3) están convertidos.
//
// NO EXISTE `darkTheme`. El tema es claro y único: ningún widget vuelve a
// decidir su propio brillo.
//
// Qué se borró de la versión anterior, y por qué: `cardTheme` (ningún `Card`
// de Material en toda la app, solo widgets propios), `chipTheme` (ningún
// `Chip`; `PagateChipSelector` dibuja el suyo), `sliderTheme` (ningún
// `Slider`) y `bottomNavigationBarTheme` (la nav está montada a mano). Eran
// cuatro bloques de configuración que no pintaban nada.
// ═══════════════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  /// La escala vive en `app_text.dart`, teñida con la tinta del sistema.
  static TextTheme get _textTheme => AppText.theme.apply(
        bodyColor: AppPalette.textPrimary,
        displayColor: AppPalette.textPrimary,
      );

  /// Resuelve un color por estado del control.
  ///
  /// Se usa `WidgetStateProperty` en vez de `styleFrom` porque `styleFrom`
  /// aplica el color presionado como una capa al 10% de opacidad, y el
  /// sistema pide un color exacto (`brandPressed`), no un matiz.
  static WidgetStateProperty<Color?> _byState({
    required final Color normal,
    final Color? pressed,
    final Color? disabled,
  }) =>
      WidgetStateProperty.resolveWith((final states) {
        if (states.contains(WidgetState.disabled)) return disabled ?? normal;
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return pressed ?? normal;
        }
        return normal;
      });

  /// Contorno de campo.
  ///
  /// El foco y el error solo cambian color y grosor; el `contentPadding` no
  /// se mueve, así que el campo no cambia de tamaño al enfocarse y el texto
  /// no salta.
  static OutlineInputBorder _fieldBorder(
    final Color color,
    final double width,
  ) =>
      OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.r10)),
        borderSide: BorderSide(color: color, width: width),
      );

  static const RoundedRectangleBorder _shapeR8 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.r8)),
  );

  /// Botones: radio 10.
  static const RoundedRectangleBorder _shapeR10 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.r10)),
  );

  /// Diálogos: radio 20.
  static const RoundedRectangleBorder _shapeR20 = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadius.r20)),
  );

  static ThemeData get lightTheme {
    final textTheme = _textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Raíz de la familia: lo que construya su propio `TextStyle` sin pasar
      // por el `textTheme` (fl_chart, tooltips de la plataforma) cae aquí en
      // vez de caer en Roboto.
      fontFamily: kFontFamily,
      textTheme: textTheme,

      scaffoldBackgroundColor: AppPalette.canvas,
      canvasColor: AppPalette.canvas,

      // Fuera la onda circular de Material. El estado presionado se comunica
      // con un cambio de fondo, que es instantáneo y legible; el splash de
      // color es lo único "de plantilla" que quedaría. Cada botón define su
      // propio color presionado más abajo.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: AppPalette.sunken,

      colorScheme: const ColorScheme.light(
        primary: AppPalette.brand,
        onPrimary: AppPalette.textOnBrand,
        primaryContainer: AppPalette.brandSurface,
        onPrimaryContainer: AppPalette.brand,

        // El secundario es el oscuro: títulos, íconos, pestaña activa y
        // botones secundarios. La greda queda solo para la acción principal.
        secondary: AppPalette.ink,
        onSecondary: AppPalette.textOnBrand,
        secondaryContainer: AppPalette.sunken,
        onSecondaryContainer: AppPalette.ink,

        // El verde dinero, disponible sin salirse del esquema.
        tertiary: AppPalette.moneyIn,
        onTertiary: AppPalette.textOnBrand,
        tertiaryContainer: AppPalette.moneyInSurface,
        onTertiaryContainer: AppPalette.moneyIn,

        surface: AppPalette.surface,
        onSurface: AppPalette.textPrimary,
        surfaceContainerLowest: AppPalette.surface,
        surfaceContainerLow: AppPalette.canvas,
        surfaceContainer: AppPalette.sunken,
        surfaceContainerHigh: AppPalette.sunken,
        surfaceContainerHighest: AppPalette.skeleton,
        onSurfaceVariant: AppPalette.textSecondary,

        error: AppPalette.danger,
        onError: AppPalette.textOnBrand,
        errorContainer: AppPalette.dangerSurface,
        onErrorContainer: AppPalette.danger,

        // `outline` es el borde de los componentes delineados y por 1.4.11
        // necesita 3:1, así que va a `borderField` y no a la línea
        // decorativa.
        outline: AppPalette.borderField,
        outlineVariant: AppPalette.hairline,

        scrim: AppPalette.scrim,
        shadow: AppPalette.scrim,

        // Mata el tinte de elevación de Material 3: una superficie blanca se
        // queda blanca aunque el widget declare elevación.
        surfaceTint: Colors.transparent,
      ),

      // ─── Barra superior ───────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppPalette.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,

        // A la izquierda. Lo único centrado del sistema es el contenido de un
        // botón.
        centerTitle: false,
        titleSpacing: AppSpacing.x4,

        // Lienzo claro, iconos de la barra de estado oscuros.
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.headlineMedium,
        iconTheme: const IconThemeData(
          color: AppPalette.ink,
          size: AppIconSize.md,
        ),
      ),

      iconTheme: const IconThemeData(
        color: AppPalette.ink,
        size: AppIconSize.md,
      ),

      // ─── Campo de formulario ──────────────────────────────────────
      // Reemplaza por completo al bloque anterior, que dejaba `border` y
      // `enabledBorder` en `BorderSide.none` sobre un relleno gris que contra
      // el blanco de la tarjeta daba 1,05:1 — un campo invisible.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        // Blanco, no gris: es lo que permite que el placeholder cumpla AA. El
        // campo se distingue por su contorno, que da 3,63:1.
        fillColor: AppPalette.surface,
        constraints: const BoxConstraints(minHeight: AppSizes.inputHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x3,
        ),
        border: _fieldBorder(AppPalette.borderField, AppSizes.borderField),
        enabledBorder:
            _fieldBorder(AppPalette.borderField, AppSizes.borderField),
        focusedBorder: _fieldBorder(AppPalette.ink, AppSizes.borderEmphasis),
        errorBorder: _fieldBorder(AppPalette.danger, AppSizes.borderField),
        focusedErrorBorder:
            _fieldBorder(AppPalette.danger, AppSizes.borderEmphasis),
        disabledBorder:
            _fieldBorder(AppPalette.hairline, AppSizes.borderHairline),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppPalette.textMuted,
        ),
        labelStyle: textTheme.titleSmall?.copyWith(
          color: AppPalette.textSecondary,
        ),
        floatingLabelStyle: textTheme.titleSmall?.copyWith(
          color: AppPalette.ink,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: AppPalette.danger,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: AppPalette.textMuted,
        ),
        prefixStyle: textTheme.bodyLarge?.copyWith(
          color: AppPalette.textMuted,
        ),
        suffixStyle: textTheme.bodyLarge?.copyWith(
          color: AppPalette.textMuted,
        ),
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppPalette.ink,
        selectionColor: AppPalette.brandSurface,
        selectionHandleColor: AppPalette.ink,
      ),

      // ─── Botón primario ──────────────────────────────────────────
      // Alto 48 (era 56), radio 12 (era 100) y cero sombra. Deshabilitado
      // pasa a fondo `sunken` con texto `textMuted` (4,77): antes era un
      // relleno #CBD5E1 con texto blanco encima, 1,48:1, ilegible.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: _byState(
            normal: AppPalette.brand,
            pressed: AppPalette.brandPressed,
            disabled: AppPalette.sunken,
          ),
          foregroundColor: _byState(
            normal: AppPalette.textOnBrand,
            disabled: AppPalette.textMuted,
          ),
          iconColor: _byState(
            normal: AppPalette.textOnBrand,
            disabled: AppPalette.textMuted,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, AppSizes.buttonHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          ),
          shape: const WidgetStatePropertyAll(_shapeR10),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          splashFactory: NoSplash.splashFactory,
        ),
      ),

      // ─── Botón secundario ────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: _byState(
            normal: AppPalette.surface,
            pressed: AppPalette.sunken,
            disabled: AppPalette.surface,
          ),
          foregroundColor: _byState(
            normal: AppPalette.textPrimary,
            disabled: AppPalette.textMuted,
          ),
          side: WidgetStateProperty.resolveWith((final states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(
                color: AppPalette.hairline,
                width: AppSizes.borderHairline,
              );
            }
            // Contorno de 1,5 en el oscuro: el secundario es del oscuro, no
            // de la greda.
            return const BorderSide(
              color: AppPalette.ink,
              width: AppSizes.borderEmphasis,
            );
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(
            Size(double.infinity, AppSizes.buttonHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          ),
          shape: const WidgetStatePropertyAll(_shapeR10),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          splashFactory: NoSplash.splashFactory,
        ),
      ),

      // ─── Botón de texto ──────────────────────────────────────────
      // Alto visible 40, caja táctil 48 por `tapTargetSize: padded`.
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          backgroundColor: _byState(
            normal: Colors.transparent,
            pressed: AppPalette.brandSurface,
            disabled: Colors.transparent,
          ),
          foregroundColor: _byState(
            normal: AppPalette.brand,
            disabled: AppPalette.textMuted,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.x2),
          ),
          shape: const WidgetStatePropertyAll(_shapeR8),
          textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
          tapTargetSize: MaterialTapTargetSize.padded,
          splashFactory: NoSplash.splashFactory,
        ),
      ),

      // ─── Control de solo icono ───────────────────────────────────
      // Caja de 48 obligatoria aunque el icono mida 24: es lo que marca el
      // informe previo al lanzamiento de Google Play.
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: _byState(
            normal: AppPalette.ink,
            disabled: AppPalette.textDisabled,
          ),
          backgroundColor: _byState(
            normal: Colors.transparent,
            pressed: AppPalette.sunken,
            disabled: Colors.transparent,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSizes.minTouchTarget, AppSizes.minTouchTarget),
          ),
          iconSize: const WidgetStatePropertyAll(AppIconSize.md),
          shape: const WidgetStatePropertyAll(_shapeR8),
          splashFactory: NoSplash.splashFactory,
        ),
      ),

      // ─── Divisor ─────────────────────────────────────────────────
      // A sangre completa: sin `indent` ni `endIndent`. Es lo que hace que
      // una lista se lea como cartola y no como tarjetas apiladas.
      dividerTheme: const DividerThemeData(
        color: AppPalette.hairline,
        thickness: AppSizes.borderHairline,
        space: 0,
        indent: 0,
        endIndent: 0,
      ),

      // ─── Hoja modal ──────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surface,
        modalBackgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.r20TopBorder),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: AppPalette.borderField,
        dragHandleSize: Size(32, 4),
        modalBarrierColor: AppPalette.scrim,
      ),

      // ─── Diálogo ─────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: _shapeR20,
        barrierColor: AppPalette.scrim,
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppPalette.textSecondary,
        ),
      ),

      // ─── Snackbar ────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppPalette.surface,
        ),
        actionTextColor: AppPalette.textOnInkMuted,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: _shapeR8,
      ),

      // ─── Barra de progreso ───────────────────────────────────────
      // 6 dp de alto, relleno en el oscuro sobre pista `sunken` (12,89:1).
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppPalette.ink,
        linearTrackColor: AppPalette.sunken,
        linearMinHeight: AppSizes.progressBarHeight,
        circularTrackColor: Colors.transparent,
      ),

      // ─── Rail de navegación (escritorio) ─────────────────────────
      // No existía en ninguno de los dos temas, y por eso el rail de
      // `dashboard_screen` se estilizaba en línea con ocho colores oscuros.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        useIndicator: true,
        indicatorColor: AppPalette.sunken,
        indicatorShape: _shapeR8,
        selectedIconTheme: const IconThemeData(
          color: AppPalette.ink,
          size: AppIconSize.md,
        ),
        unselectedIconTheme: const IconThemeData(
          color: AppPalette.textMuted,
          size: AppIconSize.md,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppPalette.ink,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppPalette.textMuted,
        ),
      ),

      // ─── Barra de navegación inferior (Material 3) ───────────────
      // La app todavía monta su nav a mano con un `GestureDetector`; esto
      // deja el tema listo para que el paso 5c la sustituya por
      // `NavigationBar` sin un solo estilo en línea.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 56,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (final states) => IconThemeData(
            size: AppIconSize.md,
            color: states.contains(WidgetState.selected)
                ? AppPalette.ink
                : AppPalette.textMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (final states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppPalette.ink
                : AppPalette.textMuted,
          ),
        ),
      ),

      // ─── Tooltip ─────────────────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppPalette.textPrimary,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.r8)),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: AppPalette.surface,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x1,
        ),
        waitDuration: AppDurations.fast,
      ),

      // ─── Fila de lista ───────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: AppPalette.surface,
        selectedTileColor: AppPalette.sunken,
        selectedColor: AppPalette.ink,
        iconColor: AppPalette.textMuted,
        textColor: AppPalette.textPrimary,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: AppPalette.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x3,
        ),
        minVerticalPadding: AppSpacing.x3,
        horizontalTitleGap: AppSpacing.x3,
        shape: const RoundedRectangleBorder(),
      ),
    );
  }
}
