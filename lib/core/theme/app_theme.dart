import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import 'app_text.dart';

// ═══════════════════════════════════════════════════════════════════════
// PÁGATE-IA — UNIFIED THEME
// ═══════════════════════════════════════════════════════════════════════
// All Material theme configuration lives here. Screens should NEVER
// override theme styles inline — instead, consume tokens from
// AppColors, AppSpacing, AppRadius, etc.
// ═══════════════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  /// Font family name — matches the family registered in pubspec.yaml.
  static const String _fontFamily = 'Manrope';

  // ─── Tipografía ───────────────────────────────────────
  // La escala vive en `app_text.dart`. Este archivo ya no construye ningún
  // `TextStyle` de texto corrido: si lo hiciera, ese estilo no heredaría
  // `fontVariations` y volvería a dibujarse en ExtraLight.

  static TextTheme get _baseTextTheme => AppText.theme;

  // ─── Light Theme ──────────────────────────────────────────────────

  static ThemeData get lightTheme {
    final textTheme = _baseTextTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,

      // Raíz de la familia: lo que construya su propio `TextStyle` sin
      // pasar por el `textTheme` (fl_chart, tooltips de la plataforma) cae
      // aquí en vez de caer en Roboto.
      fontFamily: kFontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.brand,
        onPrimary: AppColors.textOnBrand,
        primaryContainer: AppColors.brandLight,
        onPrimaryContainer: AppColors.brandDark,
        secondary: AppColors.accent,
        onSecondary: AppColors.textOnBrand,
        secondaryContainer: AppColors.accentLight,
        onSecondaryContainer: AppColors.accentDark,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        error: AppColors.error,
        onError: AppColors.textOnBrand,
        errorContainer: AppColors.errorLight,
        outline: AppColors.border,
        outlineVariant: AppColors.borderLight,
      ),

      // Typography
      textTheme: textTheme,

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.textSecondary,
          size: AppIconSize.md,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlBorder,
          side: const BorderSide(
            color: AppColors.borderLight,
            width: AppSizes.borderThin,
          ),
        ),
      ),

      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSecondary,
        border: OutlineInputBorder(
          borderRadius: AppRadius.xxlBorder,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.xxlBorder,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.xxlBorder,
          borderSide: const BorderSide(
            color: AppColors.borderFocus,
            width: AppSizes.borderNormal,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.xxlBorder,
          borderSide: const BorderSide(
            color: AppColors.borderError,
            width: AppSizes.borderThin,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.xxlBorder,
          borderSide: const BorderSide(
            color: AppColors.borderError,
            width: AppSizes.borderNormal,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: AppColors.textTertiary,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.error,
        ),
      ),

      // Elevated Button (Primary action)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.textOnBrand,
          disabledBackgroundColor: AppColors.textDisabled,
          disabledForegroundColor: AppColors.surface,
          elevation: 0,
          minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.pillBorder,
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Outlined Button (Secondary action)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(double.infinity, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          side: const BorderSide(
            color: AppColors.border,
            width: AppSizes.borderThin,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.pillBorder,
          ),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button (Tertiary action)
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceTertiary,
        selectedColor: AppColors.brandLight,
        disabledColor: AppColors.surfaceTertiary,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBorder,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: AppSizes.borderThin,
        space: 0,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.textDisabled,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.xlBorder,
        ),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.brand,
        inactiveTrackColor: AppColors.borderLight,
        trackHeight: AppSizes.progressBarHeight,
        thumbColor: AppColors.brand,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 14,
          elevation: 4,
        ),
        overlayColor: AppColors.brand.withValues(alpha: 0.15),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: AppColors.surfaceTertiary,
        linearMinHeight: AppSizes.progressBarHeight,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.surface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdBorder,
        ),
      ),
    );
  }
}
