import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
// PÁGATE-IA — DESIGN TOKENS (Single Source of Truth)
// ═══════════════════════════════════════════════════════════════════════
// Every visual constant lives here. No hardcoded values in widgets.
// Naming convention: semantic purpose, NOT visual appearance.
// ═══════════════════════════════════════════════════════════════════════

/// Unified color palette for Págate-IA.
///
/// Organized by semantic role so that every screen consumes the same
/// tokens regardless of whether the app is in light or dark mode.
class AppColors {
  AppColors._(); // Prevent instantiation

  // ─── Brand Identity ───────────────────────────────────────────────
  static const Color brand = Color(0xFF00C2B8);
  static const Color brandLight = Color(0xFFE0F9F7);
  static const Color brandDark = Color(0xFF00A89F);
  static const Color brandSubtle = Color(0xFFE6FAFA);

  static const Color accent = Color(0xFFF97316);
  static const Color accentLight = Color(0xFFFFEDD5);
  static const Color accentDark = Color(0xFFEA580C);

  // ─── Semantic / Feedback ──────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ─── Backgrounds (Light theme) ────────────────────────────────────
  static const Color background = Color(0xFFF6F8F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF8FAFC);
  static const Color surfaceTertiary = Color(0xFFF1F5F9);

  // ─── Backgrounds (Dark theme) ─────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0B0D14);
  static const Color surfaceDark = Color(0xFF141720);
  static const Color surfaceDarkElevated = Color(0xFF1C2030);
  static const Color surfaceDarkSecondary = Color(0xFF252D42);
  static const Color borderDark = Color(0xFF252D42);

  // ─── Text (Light theme) ───────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);
  static const Color textOnBrand = Color(0xFFFFFFFF);
  static const Color textLink = Color(0xFF00C2B8);

  // ─── Text (Dark theme) ────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // ─── Borders & Dividers ───────────────────────────────────────────
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderFocus = Color(0xFF00C2B8);
  static const Color borderError = Color(0xFFEF4444);

  // ─── Glassmorphism (Dark theme overlays) ──────────────────────────
  static const Color glass = Color(0x1AFFFFFF);
  static const Color glassStrong = Color(0x33FFFFFF);

  // ─── Shadows ──────────────────────────────────────────────────────
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMedium = Color(0x14000000);
  static const Color shadowBrand = Color(0x4000C2B8);

  // ─── Gradient Presets ─────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C2B8), Color(0xFF00A89F)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF141720), Color(0xFF0B0D14)],
  );

  static LinearGradient fadeToBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      background.withValues(alpha: 0.0),
      background,
    ],
  );

  static LinearGradient fadeToWhite = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      surface.withValues(alpha: 0.0),
      surface,
    ],
  );
}

/// Standardized spacing scale based on a 4-point grid.
///
/// Usage: `SizedBox(height: AppSpacing.md)` or
///        `EdgeInsets.all(AppSpacing.lg)`
class AppSpacing {
  AppSpacing._();

  static const double xxxs = 2.0;
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double xxxxl = 48.0;
  static const double section = 56.0;
  static const double hero = 64.0;

  /// Screen horizontal padding — consistent across all screens.
  static const double screenHorizontal = 24.0;

  /// Screen padding as EdgeInsets.
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
  );
}

/// Standardized border radii.
///
/// Every component must use one of these values — no magic numbers.
class AppRadius {
  AppRadius._();

  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double pill = 100.0;

  // Pre-built BorderRadius for convenience
  static final BorderRadius xsBorder = BorderRadius.circular(xs);
  static final BorderRadius smBorder = BorderRadius.circular(sm);
  static final BorderRadius mdBorder = BorderRadius.circular(md);
  static final BorderRadius lgBorder = BorderRadius.circular(lg);
  static final BorderRadius xlBorder = BorderRadius.circular(xl);
  static final BorderRadius xxlBorder = BorderRadius.circular(xxl);
  static final BorderRadius pillBorder = BorderRadius.circular(pill);
}

/// Standardized icon sizes.
class AppIconSize {
  AppIconSize._();

  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 28.0;
  static const double xl = 32.0;
  static const double xxl = 36.0;
  static const double hero = 48.0;
}

/// Standardized interactive element sizes.
class AppSizes {
  AppSizes._();

  // Heights
  static const double buttonHeight = 56.0;
  static const double inputHeight = 56.0;
  static const double chipHeight = 36.0;
  static const double progressBarHeight = 8.0;

  // Widths
  static const double backButtonSize = 40.0;
  static const double avatarSmall = 32.0;
  static const double avatarMedium = 48.0;
  static const double avatarLarge = 72.0;
  static const double avatarHero = 120.0;

  // Icon containers
  static const double iconContainerSmall = 32.0;
  static const double iconContainerMedium = 48.0;
  static const double iconContainerLarge = 72.0;

  // Border widths
  static const double borderThin = 1.0;
  static const double borderNormal = 1.5;
  static const double borderThick = 2.0;
}

/// Pre-built shadow presets.
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 20,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 40,
      offset: Offset(0, 20),
    ),
  ];

  static List<BoxShadow> brand = [
    BoxShadow(
      color: AppColors.brand.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> brandStrong = [
    BoxShadow(
      color: AppColors.brand.withValues(alpha: 0.40),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Animation durations — consistent motion across the app.
class AppDurations {
  AppDurations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration emphasis = Duration(milliseconds: 700);
}

/// Animation curves — consistent easing across the app.
class AppCurves {
  AppCurves._();

  static const Curve standard = Curves.easeInOut;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  static const Curve emphasis = Curves.easeInOutCubicEmphasized;
  static const Curve bounce = Curves.elasticOut;
}
