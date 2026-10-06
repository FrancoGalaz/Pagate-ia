import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
// PAGATE — DESIGN TOKENS (Single Source of Truth)
// ═══════════════════════════════════════════════════════════════════════
// Every visual constant lives here. No hardcoded values in widgets.
// Naming convention: semantic purpose, NOT visual appearance.
// ═══════════════════════════════════════════════════════════════════════

/// Unified color palette for Pagate.
///
/// Based on the Brand Manual:
/// 1. Verde Esmeralda #006B5F — confianza, estabilidad, orden
/// 2. Coral Cálido #FF735C — cercanía, creatividad, energía
/// 3. Azul Noche #16213E — soporte, legibilidad, solidez
/// 4. Gris Niebla #F3F4F6 — fondos, superficies, equilibrio
/// 5. Gris Texto #6B7280 — texto secundario, información
///
/// Organized by semantic role so that every screen consumes the same
/// tokens regardless of whether the app is in light or dark mode.
class AppColors {
  AppColors._(); // Prevent instantiation

  // ─── Brand Identity ───────────────────────────────────────────────
  static const Color brand = Color(0xFF006B5F);
  static const Color brandLight = Color(0xFFE6F2F0);
  static const Color brandDark = Color(0xFF005A50);
  static const Color brandSubtle = Color(0xFFF0F7F6);

  static const Color accent = Color(0xFFFF735C);
  static const Color accentLight = Color(0xFFFFF0ED);
  static const Color accentDark = Color(0xFFE85D47);

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
  static const Color background = Color(0xFFF3F4F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF8FAFC);
  static const Color surfaceTertiary = Color(0xFFF1F5F9);

  // ─── Backgrounds (Dark theme) ─────────────────────────────────────
  static const Color backgroundDark = Color(0xFF16213E);
  static const Color surfaceDark = Color(0xFF1F283E);
  static const Color surfaceDarkElevated = Color(0xFF2A3550);
  static const Color surfaceDarkSecondary = Color(0xFF3A4A6B);
  static const Color borderDark = Color(0xFF3A4A6B);

  // ─── Text (Light theme) ───────────────────────────────────────────
  static const Color textPrimary = Color(0xFF16213E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFFCBD5E1);
  static const Color textOnBrand = Color(0xFFFFFFFF);
  static const Color textLink = Color(0xFF006B5F);

  // ─── Text (Dark theme) ────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textTertiaryDark = Color(0xFF64748B);

  // ─── Borders & Dividers ───────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderFocus = Color(0xFF006B5F);
  static const Color borderError = Color(0xFFEF4444);

  // ─── Glassmorphism (Dark theme overlays) ──────────────────────────
  static const Color glass = Color(0x1AFFFFFF);
  static const Color glassStrong = Color(0x33FFFFFF);

  // ─── Shadows ──────────────────────────────────────────────────────
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowMedium = Color(0x14000000);
  static const Color shadowBrand = Color(0x40006B5F);

  // ─── Gradient Presets ─────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF006B5F), Color(0xFF005A50)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1F283E), Color(0xFF16213E)],
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

// ════════════════════════════════════════════════════════════════════════
// PALETA DEL SISTEMA VISUAL v2 — "Cartola"
// ════════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, sección "Color". Tema claro único.
//
// Vive en una clase aparte de [AppColors] A PROPÓSITO y solo durante la
// migración. El paso 1 del plan añade los tokens nuevos EN PARALELO a los
// viejos para que este commit no cambie ni un píxel: cinco nombres chocan
// con los de [AppColors] con un valor distinto (textPrimary, textSecondary,
// textDisabled, border y warning), y repintarlos aquí cambiaría la app
// entera de golpe. El paso 3 reapunta [AppColors] a estos valores, que es el
// commit cuyo trabajo es justamente ese, y el paso 9 colapsa las dos clases
// en una.
//
// Cada ratio de contraste del comentario está calculado con la fórmula de
// luminancia relativa de WCAG 2.1 y verificado por par de uso real: los tres
// números son contra `surface` #FFFFFF, `canvas` #F6F7F8 y `sunken` #F1F3F5.
// Umbral AA: 4,5:1 texto normal; 3:1 texto grande, objetos gráficos y bordes
// (1.4.11).
// ════════════════════════════════════════════════════════════════════════

class AppPalette {
  AppPalette._();

  // ─── Superficies ──────────────────────────────────────
  /// Fondo del `Scaffold` en todas las pantallas.
  static const Color canvas = Color(0xFFF6F7F8);

  /// Secciones, filas, campos, barra inferior, hoja modal.
  static const Color surface = Color(0xFFFFFFFF);

  /// Pista de barra de progreso, campo deshabilitado, encabezado agrupador.
  static const Color sunken = Color(0xFFF1F3F5);

  /// Bloques del esqueleto de carga.
  static const Color skeleton = Color(0xFFEAECF0);

  /// Velo detrás de hoja modal y diálogo: #101828 al 40%.
  static const Color scrim = Color(0x66101828);

  // ─── Texto ────────────────────────────────────────────
  /// 17,75 / 16,55 / 15,95 — AAA en las tres superficies.
  ///
  /// Tinta, no azul noche: el azul #16213E teñía de marca cada cifra.
  static const Color textPrimary = Color(0xFF101828);

  /// 7,69 / 7,17 / 6,91 — AAA. El #6B7280 anterior daba 4,39 sobre el fondo
  /// de la app y fallaba AA.
  static const Color textSecondary = Color(0xFF475467);

  /// 5,31 / 4,95 / 4,77 — AA en las tres superficies. Metadatos,
  /// placeholders y etiquetas no seleccionadas de la barra inferior.
  ///
  /// Sustituye a `textTertiary` #9CA3AF, que daba 2,54 sobre blanco y 2,31
  /// sobre el fondo: era un fallo de AA repetido en 17 sitios.
  static const Color textMuted = Color(0xFF636C7A);

  /// 2,58 sobre blanco. **Nunca texto informativo**: solo controles
  /// deshabilitados, que WCAG 1.4.3 exime.
  static const Color textDisabled = Color(0xFF98A2B3);

  /// 6,43 sobre [brand].
  static const Color textOnBrand = Color(0xFFFFFFFF);

  // ─── Líneas ─────────────────────────────────────────
  /// Divisor entre filas de una lista, a sangre completa (sin `indent`).
  /// Decorativo: 1.4.11 no aplica porque la separación también la da el
  /// espaciado.
  static const Color hairline = Color(0xFFEDEFF2);

  /// Contorno de sección, borde superior de la barra inferior, borde de
  /// botón secundario. Decorativo.
  static const Color border = Color(0xFFE4E7EC);

  /// 3,63 / 3,39 / 3,27 — cumple 1.4.11 en las tres superficies.
  ///
  /// Contorno de campo, casilla e interruptor: componentes cuyo límite es el
  /// único indicador, y por eso necesitan 3:1. Es la diferencia que no
  /// existía: el tema dejaba `border` y `enabledBorder` en `BorderSide.none`
  /// sobre un relleno que contra el blanco de la tarjeta daba 1,05:1 — un
  /// campo literalmente invisible.
  static const Color borderField = Color(0xFF7E8794);

  /// Borde de foco, 1,5 dp. Mismo valor que [brand].
  static const Color borderFocus = brand;

  // ─── Marca ────────────────────────────────────────────
  /// 6,43 / 5,99 / 5,78 — AA como texto, icono y relleno. Acción primaria,
  /// selección, foco, enlace y relleno de progreso.
  static const Color brand = Color(0xFF006B5F);

  /// Blanco encima 8,14. Estado presionado del primario.
  static const Color brandPressed = Color(0xFF005A50);

  /// [brand] encima 5,61; [textPrimary] encima 15,48.
  static const Color brandSurface = Color(0xFFE6F2F0);

  // ─── Dinero ─────────────────────────────────────────
  // Regla de aplicación, estrecha a propósito: el color del dinero se aplica
  // SOLO al monto de una fila de movimiento y al balance cuando es negativo.
  // Nunca a un fondo, nunca a un círculo de icono, nunca a las filas de
  // Ingresos/Gastos del resumen. Un gasto corriente no es un error.

  /// 6,63 / 6,18 / 5,96 — AA. Monto de un ingreso.
  ///
  /// Sustituye a `success` #10B981, que daba 2,54 sobre blanco.
  static const Color moneyIn = Color(0xFF0B6A47);

  /// 7,56 / 7,05 / 6,80; blanco encima 7,56. Monto de salida.
  ///
  /// Sustituye a `error` #EF4444 como texto, que daba 3,76 y no cumplía AA.
  static const Color moneyOut = Color(0xFFA32019);

  /// [moneyIn] encima 5,77; [textPrimary] encima 15,45.
  static const Color moneyInSurface = Color(0xFFE6F2EC);

  // ─── Estado ─────────────────────────────────────────
  /// Error de formulario, acción destructiva, balance negativo.
  /// Mismo valor que [moneyOut]; token aparte por semántica.
  static const Color danger = moneyOut;

  /// [danger] encima 6,49; [textPrimary] encima 15,24. Fondo del
  /// deslizar-para-eliminar y del bloque de error.
  static const Color dangerSurface = Color(0xFFFBEAE8);

  /// 5,43 / 5,06 / 4,88 — AA. Stock bajo.
  ///
  /// Sustituye a `warning` #F59E0B, que daba 2,15 sobre blanco y 1,93 sobre
  /// su propio fondo claro.
  static const Color warning = Color(0xFFB54708);

  /// [warning] encima 4,81; [textPrimary] encima 15,72.
  static const Color warningSurface = Color(0xFFFBF0DC);

  // ─── Series de datos ──────────────────────────────────
  /// 3,63 sobre blanco y 3,27 sobre [sunken] — cumple 1.4.11 como objeto
  /// gráfico. Mismo valor que [borderField].
  ///
  /// Es la única serie extra del sistema: las barras de categoría usan
  /// [brand] sobre pista [sunken] y esta para la fila "Otros". No hay rampa
  /// de diez colores porque el texto blanco de 11 dp dentro de una porción
  /// fallaba el contraste en 9 de los 10 colores que había.
  static const Color seriesOther = borderField;
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

  // ─── Escala v2: rejilla de 4, nueve pasos, un uso por valor ───────
  // docs/DISENO-v2.md, "Espaciado". Nueve pasos en vez de doce para que
  // nadie pueda elegir dos veces el mismo hueco. Convive con la escala
  // anterior hasta que el paso 6 migre las pantallas.

  /// 0 — filas pegadas a un divisor.
  static const double x0 = 0.0;

  /// 4 — entre la línea de título y la de metadato dentro de una fila.
  static const double x1 = 4.0;

  /// 8 — entre etiqueta y campo; entre elementos de un grupo apretado.
  static const double x2 = 8.0;

  /// 12 — padding vertical de fila compacta; hueco entre dos botones.
  static const double x3 = 12.0;

  /// 16 — margen lateral de pantalla, padding horizontal de toda fila,
  /// padding de hoja modal, hueco entre secciones hermanas.
  static const double x4 = 16.0;

  /// 20 — entre la cifra héroe y la línea de contexto.
  static const double x5 = 20.0;

  /// 24 — aire entre bloques distintos de una pantalla.
  static const double x6 = 24.0;

  /// 32 — aire antes del bloque de acciones del pie.
  static const double x8 = 32.0;

  /// 40 — aire superior del titular de Bienvenida. Ningún espacio vertical
  /// de la app supera este valor.
  static const double x10 = 40.0;

  /// Screen horizontal padding — consistent across all screens.
  ///
  /// El sistema v2 lo baja a [x4] = 16, pero ese cambio mueve 48 sitios y
  /// pertenece al paso que rediseña las pantallas, no a este.
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

  // ─── Escala v2: cinco valores, ninguno por encima de 16 ──────────
  // docs/DISENO-v2.md, "Radios". Los botones pastilla de 56 dp y los campos
  // de radio 32 son la firma visual que hay que borrar: 82 de los 99 usos de
  // radio de la app eran de 20 dp para arriba.

  /// 0 — secciones a sangre en móvil, divisores, filas de lista, barra
  /// inferior.
  static const double r0 = 0.0;

  /// 4 — bloque de esqueleto, barra de progreso, asa de la hoja modal,
  /// insignia.
  static const double r4 = 4.0;

  /// 8 — campo de formulario, chip, ítem del selector de periodo, avatar
  /// cuadrado, contenedor de icono.
  static const double r8 = 8.0;

  /// 12 — **valor por defecto**: botón, sección con contorno (solo
  /// ≥720 dp), diálogo.
  static const double r12 = 12.0;

  /// 16 — únicamente el borde superior de la hoja modal. Radio máximo del
  /// sistema.
  static const double r16 = 16.0;

  static final BorderRadius r4Border = BorderRadius.circular(r4);
  static final BorderRadius r8Border = BorderRadius.circular(r8);
  static final BorderRadius r12Border = BorderRadius.circular(r12);

  /// Solo el borde superior de la hoja modal; abajo va a 0.
  static const BorderRadius r16TopBorder = BorderRadius.vertical(
    top: Radius.circular(r16),
  );

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

  /// Área táctil mínima, obligatoria aunque el píxel visible mida menos.
  ///
  /// El informe previo al lanzamiento de Google Play marca "touch target
  /// size" de forma explícita, y la app tiene hoy once controles por debajo
  /// (botón de volver 40, chip 35, pestaña CLP/USD 40, y el botón de cerrar
  /// del banner del chat, que mide ~16×16).
  static const double minTouchTarget = 48.0;

  // ─── Grosores v2: tres valores, bien repartidos ─────────────────
  /// 1,0 — divisor, contorno de sección, borde de botón secundario. El 90%
  /// de los casos.
  static const double borderHairline = 1.0;

  /// 1,0 — mismo grosor que [borderHairline], distinto color
  /// (`AppPalette.borderField`): es el contorno de campo, casilla e
  /// interruptor, el único con obligación de 3:1.
  static const double borderField = 1.0;

  /// 1,5 — solo foco y error, dibujado hacia adentro para que el campo no
  /// cambie de tamaño al enfocarse y el texto no salte.
  static const double borderEmphasis = 1.5;

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

/// Las tres —y únicas tres— sombras del sistema.
///
/// Regla entera (docs/DISENO-v2.md, "Sombras"): hay sombra **solo** cuando el
/// sistema coloca una superficie encima del contenido y el usuario puede
/// volver atrás de ella. Todo lo demás —tarjeta, sección, fila, botón, FAB,
/// barra inferior, barra superior, chip, avatar, gráfico— no lleva sombra
/// jamás: se separa con 1 px de borde o con fondo visible.
///
/// Sustituye a [AppShadows], cuyos siete presets incluían dos glows verdes de
/// marca (el de debajo del CTA de toda la app y el del 40% bajo la tarjeta de
/// balance).
class AppElevation {
  AppElevation._();

  /// Hoja modal, además del velo.
  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x1A101828),
      blurRadius: 16,
      offset: Offset(0, 2),
    ),
  ];

  /// Menú desplegable y `PopupMenu`.
  static const List<BoxShadow> menu = [
    BoxShadow(
      color: Color(0x1A101828),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// `SnackBar` flotante.
  static const List<BoxShadow> snackbar = [
    BoxShadow(
      color: Color(0x1F101828),
      blurRadius: 8,
      offset: Offset(0, 2),
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
