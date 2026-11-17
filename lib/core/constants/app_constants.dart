import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
// PAGATE — DESIGN TOKENS (Single Source of Truth)
// ═══════════════════════════════════════════════════════════════════════
// Every visual constant lives here. No hardcoded values in widgets.
// Naming convention: semantic purpose, NOT visual appearance.
// ═══════════════════════════════════════════════════════════════════════

/// Tokens de color que consumen las pantallas.
///
/// Capa de compatibilidad sobre [AppPalette], la paleta del tema claro
/// único. No define ningún color propio: cada token de aquí apunta al de la
/// paleta que le corresponde, y queda solo para los seis archivos que
/// todavía no se han migrado (los cuenta `grep -rn "AppColors\." lib/`).
///
/// LOS OCHO ALIAS DEL TEMA OSCURO YA NO ESTÁN. Eran el interruptor del paso
/// 3 del plan de migración (docs/DISENO-v2.md): conservaban su nombre y
/// devolvían el color claro equivalente, para que las 251 referencias de 21
/// pantallas siguieran compilando mientras los pasos 6 y 7 las reescribían.
/// Mentían a propósito —un token llamado "oscuro" devolviendo blanco— y por
/// eso el plan exige borrarlos en cuanto no quede ninguna referencia: desde
/// este commit, cualquier uso superviviente es un error de compilación y no
/// un aviso que se pueda ignorar.
///
/// Con ellos se van los presets de sombra vacíos, los cuatro degradados
/// planos y los tokens que quedaron sin un solo consumidor: el coral, el
/// azul (que no existe en la paleta v2 y no cumplía AA como texto), las dos
/// líneas de cristal y las tres tintas de sombra.
class AppColors {
  AppColors._();

  // ─── Marca ────────────────────────────────────────────
  static const Color brand = AppPalette.brand;

  /// Renombrado a `AppPalette.brandSurface`; mismo valor.
  static const Color brandLight = AppPalette.brandSurface;

  // ─── Estado y dinero ────────────────────────────────────
  /// Era #10B981 (2,54 sobre blanco, fallaba AA). Ahora el verde dinero.
  static const Color success = AppPalette.moneyIn;
  static const Color successLight = AppPalette.moneyInSurface;

  /// Era #F59E0B (2,15 sobre blanco).
  static const Color warning = AppPalette.warning;
  static const Color warningLight = AppPalette.warningSurface;

  /// Era #EF4444 (3,76 como texto, fallaba AA). Ahora #A32019 (7,56).
  static const Color error = AppPalette.danger;
  static const Color errorLight = AppPalette.dangerSurface;

  // ─── Superficies ──────────────────────────────────────
  static const Color background = AppPalette.canvas;
  static const Color surface = AppPalette.surface;
  static const Color surfaceSecondary = AppPalette.sunken;
  static const Color surfaceTertiary = AppPalette.sunken;

  // ─── Texto ────────────────────────────────────────────
  static const Color textPrimary = AppPalette.textPrimary;
  static const Color textSecondary = AppPalette.textSecondary;

  /// Era #9CA3AF (2,54 sobre blanco): un fallo de AA repetido en 17 sitios.
  static const Color textTertiary = AppPalette.textMuted;

  static const Color textDisabled = AppPalette.textDisabled;
  static const Color textOnBrand = AppPalette.textOnBrand;
  static const Color textLink = AppPalette.brand;

  // ─── Bordes y divisores ─────────────────────────────────
  static const Color border = AppPalette.border;
  static const Color borderLight = AppPalette.hairline;
  static const Color borderFocus = AppPalette.borderFocus;
  static const Color borderError = AppPalette.danger;
}

// ════════════════════════════════════════════════════════════════════════
// PALETA — Variante A «Greda y carbón»
// ════════════════════════════════════════════════════════════════════════
// Especificación: docs/diseno/variantes-cabal.html. Contraste comprobado en
// docs/diseno/contraste.py. Tema claro único.
//
// Dos colores con roles fijos:
//   · ACCIÓN (greda, [brand]): SOLO la acción principal de cada pantalla,
//     el FAB y los enlaces de «ir a». Nunca directo sobre la cabecera
//     oscura (2,7:1): ahí va dentro de una tarjeta blanca.
//   · OSCURO (carbón, [ink] = [textPrimary]): títulos, íconos, pestaña
//     activa, botones secundarios, progreso y montos de gasto.
// Dinero: ingreso en verde ([moneyIn]); gasto en el oscuro con «−»
// ([moneyOut]); el carmesí ([danger]) es SOLO para alertas (sin stock, stock
// bajo) y acciones destructivas (Borrar).
//
// Los tres números de cada comentario son el contraste WCAG 2.1 contra
// `surface` #FFFFFF, `canvas` #FBF6F2 y `sunken` #F4EEE9. Umbral AA: 4,5:1
// texto normal; 3:1 texto grande, objetos gráficos y bordes (1.4.11).
// ════════════════════════════════════════════════════════════════════════

class AppPalette {
  AppPalette._();

  // ─── Superficies ──────────────────────────────────────
  /// Fondo del `Scaffold`: greda muy pálida.
  static const Color canvas = Color(0xFFFBF6F2);

  /// Tarjetas, listas, campos, barra inferior, hoja modal.
  static const Color surface = Color(0xFFFFFFFF);

  /// Pista de progreso y del selector segmentado, campo deshabilitado,
  /// fondo de los íconos de fila.
  static const Color sunken = Color(0xFFF4EEE9);

  /// Bloques del esqueleto de carga.
  static const Color skeleton = Color(0xFFECE4DE);

  /// Velo detrás de hoja modal y diálogo: el oscuro al 40%.
  static const Color scrim = Color(0x662E2622);

  // ─── Texto ────────────────────────────────────────────
  /// 14,83 / 13,81 / 12,89 — AAA. Carbón cálido: el color oscuro del
  /// sistema.
  static const Color textPrimary = Color(0xFF2E2622);

  /// Alias de rol: lo oscuro que no es texto (pestaña activa, progreso,
  /// contorno del secundario, cabecera de Inicio).
  static const Color ink = textPrimary;

  /// 6,34 / 5,91 / 5,51 — AA.
  static const Color textSecondary = Color(0xFF6A5D55);

  /// 5,38 / 5,01 / 4,67 — AA. Metadatos, placeholders y pestañas inactivas.
  static const Color textMuted = Color(0xFF756860);

  /// 2,62 sobre blanco. **Nunca texto informativo**: solo controles
  /// deshabilitados, que WCAG 1.4.3 exime.
  static const Color textDisabled = Color(0xFFA99E97);

  /// 5,45 sobre [brand]; 14,83 sobre [ink].
  static const Color textOnBrand = Color(0xFFFFFFFF);

  /// 11,02 sobre [ink]. Texto secundario dentro de la cabecera oscura.
  static const Color textOnInkMuted = Color(0xFFE8DCD3);

  // ─── Líneas ─────────────────────────────────────────
  /// Divisor entre filas de una lista. Decorativo.
  static const Color hairline = Color(0xFFF0E9E4);

  /// Contorno decorativo (borde superior de la barra inferior).
  static const Color border = Color(0xFFE8DFD8);

  /// 3,88 / 3,61 / 3,37 — cumple 1.4.11. Contorno de campo, casilla e
  /// interruptor.
  static const Color borderField = Color(0xFF8C7F77);

  /// Borde de foco: el oscuro, no la acción.
  static const Color borderFocus = ink;

  // ─── Acción (greda) ───────────────────────────────────
  /// 5,45 / 5,08 / 4,74 — AA como texto y relleno. Solo la acción principal.
  static const Color brand = Color(0xFFB04A26);

  /// Blanco encima 6,93. Estado presionado del primario.
  static const Color brandPressed = Color(0xFF963F20);

  /// [brand] encima 4,73; [textPrimary] encima 12,88.
  static const Color brandSurface = Color(0xFFF7EDE9);

  // ─── Dinero ─────────────────────────────────────────
  /// 6,48 / 6,04 / 5,63 — AA. Monto de un ingreso. El verde es SOLO para
  /// ingresos.
  static const Color moneyIn = Color(0xFF1D6B45);

  /// Monto de un gasto: el oscuro, con signo «−». Un gasto corriente no es
  /// una alerta.
  static const Color moneyOut = ink;

  /// [moneyIn] encima 5,59.
  static const Color moneyInSurface = Color(0xFFE8F0EC);

  // ─── Alerta (carmesí) ───────────────────────────────
  /// 7,38 / 6,87 / 6,41; blanco encima 7,38. Error de formulario, alerta de
  /// stock y acción destructiva (botón Borrar). Nada más.
  static const Color danger = Color(0xFFA3213F);

  /// [danger] encima 6,25; [textPrimary] encima 12,56.
  static const Color dangerSurface = Color(0xFFF6E9EC);

  /// Stock bajo: es una alerta, así que usa el carmesí. Un naranja quedaría
  /// demasiado cerca de la greda de la acción.
  static const Color warning = danger;

  static const Color warningSurface = dangerSurface;

  // ─── Series de datos ──────────────────────────────────
  /// 3,88 sobre blanco — cumple 1.4.11 como objeto gráfico. Mismo valor que
  /// [borderField]. Fila "Otros" de las barras de categoría.
  static const Color seriesOther = borderField;
}

/// Sombras del sistema: dos niveles suaves en un negro cálido.
class AppShadows {
  AppShadows._();

  /// Tarjetas, listas y segmento activo del selector.
  static const List<BoxShadow> level1 = [
    BoxShadow(color: Color(0x0F140E0A), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0F140E0A), offset: Offset(0, 2), blurRadius: 8),
  ];

  /// Tarjeta superpuesta de Inicio, FAB y diálogos.
  static const List<BoxShadow> level2 = [
    BoxShadow(color: Color(0x14140E0A), offset: Offset(0, 4), blurRadius: 12),
    BoxShadow(color: Color(0x14140E0A), offset: Offset(0, 12), blurRadius: 32),
  ];
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
  /// Era 32. Pasa al radio por defecto del sistema: `xxlBorder` estaba
  /// cableado en los cinco borders del `inputDecorationTheme`, así que esta
  /// línea quita de golpe los campos de radio 32 de toda la app.
  static const double xxl = r12;

  /// Era 100. Pasa al radio por defecto: `pillBorder` lo usaban el botón
  /// elevado y el delineado del tema, es decir el botón principal de cada
  /// pantalla. Los botones pastilla son la firma visual que hay que borrar.
  static const double pill = r12;

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

  // ─── Variante A (docs/diseno/variantes-cabal.html) ──────────────

  /// 10 — campo de formulario y botón.
  static const double r10 = 10.0;

  /// 20 — diálogo y borde superior de la hoja modal.
  static const double r20 = 20.0;

  /// 24 — borde inferior de la cabecera de Inicio.
  static const double r24 = 24.0;

  /// Píldora: selector segmentado y chips de estado.
  static const double full = 999.0;

  static final BorderRadius r10Border = BorderRadius.circular(r10);
  static final BorderRadius r16Border = BorderRadius.circular(r16);
  static final BorderRadius fullBorder = BorderRadius.circular(full);

  /// Solo el borde superior de la hoja modal.
  static const BorderRadius r20TopBorder = BorderRadius.vertical(
    top: Radius.circular(r20),
  );

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
  /// 48, no 56. Lo consume el tema (minimumSize del primario y del
  /// secundario) y PagatePrimaryButton. Es el valor del sistema v2, y junto
  /// con el radio 12 es el cambio que mas transforma la sensacion de la app.
  static const double buttonHeight = 48.0;

  /// 48, no 56. Alto minimo del campo de formulario.
  static const double inputHeight = 48.0;

  /// Sigue en 36 a proposito: el sistema lo baja a 32 pero con
  /// `MaterialTapTargetSize.padded` alrededor, y eso es trabajo del
  /// componente (paso 5), no del tema. Bajarlo aqui sin el padding dejaria
  /// el chip de mes de Finanzas con una caja tactil de 32.
  static const double chipHeight = 36.0;

  /// 6, no 8. Barra de progreso y de categoria.
  static const double progressBarHeight = 6.0;

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

/// Las tres —y únicas tres— sombras del sistema.
///
/// Regla entera (docs/DISENO-v2.md, "Sombras"): hay sombra **solo** cuando el
/// sistema coloca una superficie encima del contenido y el usuario puede
/// volver atrás de ella. Todo lo demás —tarjeta, sección, fila, botón, FAB,
/// barra inferior, barra superior, chip, avatar, gráfico— no lleva sombra
/// jamás: se separa con 1 px de borde o con fondo visible.
///
/// Sustituye a los siete presets de sombra del tema anterior, que incluían
/// dos glows verdes de
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
