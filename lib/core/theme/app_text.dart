import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
// TIPOGRAFÍA — ÚNICA FUENTE DE VERDAD
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, sección "Tipografía".
//
// ARREGLA EL DEFECTO RAÍZ DEL ASPECTO DE LA APP. Verificado en el binario
// `assets/fonts/Manrope[wght].ttf` (165.420 bytes):
//   · `name` ID 1 es literalmente "Manrope ExtraLight" y
//     `OS/2.usWeightClass` = 200.
//   · `fvar` declara UN solo eje, `wght`, con min 200, **default 200** y
//     max 800.
//   · `pubspec.yaml` registra la fuente con un único asset y sin campo
//     `weight:`, así que la familia entra al motor como una sola cara
//     ExtraLight.
//   · En todo `lib/` había **0 usos de `fontVariations`** (grep verificado
//     antes de este archivo) frente a 121 `fontWeight`.
// Consecuencia: ningún w600 ni w700 del tema estaba seleccionando un peso
// real del eje. El eje solo se mueve con `fontVariations`, y es lo que hace
// este helper. Es la causa más probable de que la app se viera blanda con
// una escala que sobre el papel era razonable.
//
// REGLA DURA: nadie construye un `TextStyle` a mano. Los quince slots de
// Material 3 salen de aquí, y los montos de fila usan [AppText.amountRow],
// [AppText.amountSmall] o [AppText.amountField].
// ═══════════════════════════════════════════════════════════════════════

/// Nombre de la familia, igual al declarado en `pubspec.yaml`.
const String kFontFamily = 'Manrope';

/// Construye un estilo del sistema.
///
/// [size] y [lh] van en dp; [lh] se convierte al multiplicador que espera
/// Flutter. [w] es el peso en el eje `wght` de la fuente variable.
///
/// `leadingDistribution: even` **no es opcional**. Manrope declara en
/// `hhea`/`OS/2` ascent 2132 + descent 600 = 2732/2000 = **1,366 em de caja
/// intrínseca**. Cualquier `height` por debajo de ~1,37 —y la cifra héroe va
/// en 1,05— hace que Flutter reparta el leading de forma asimétrica y
/// descentre la línea. Es el detalle que hace que una cifra de 40 dp se vea
/// "colgada".
///
/// `fontWeight` se conserva junto a `fontVariations` a propósito: si un
/// glifo cae en la fuente de respaldo del sistema (que no tiene eje `wght`),
/// recibe negrita sintética en vez de quedarse en pelo.
///
/// `FontFeature.slashedZero()` no se especifica en ninguna parte del
/// sistema: la tabla `GSUB` de este binario no expone la feature `zero`, así
/// que sería un no-op.
TextStyle _t(
  final double size,
  final int w,
  final double lh,
  final double ls, {
  final bool tab = false,
}) =>
    TextStyle(
      fontFamily: kFontFamily,
      fontSize: size,
      height: lh / size,
      letterSpacing: ls,
      fontWeight: FontWeight.values[(w ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w.toDouble())],
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: tab ? const [FontFeature.tabularFigures()] : null,
    );

/// Escala tipográfica del sistema.
class AppText {
  AppText._();

  // ─── Los quince slots de Material 3 ───────────────────────────────
  // Se respetan los quince nombres para que los ~130
  // `Theme.of(context).textTheme.*` que ya existen sigan funcionando sin
  // tocar una pantalla.
  //
  // CIFRAS TABULARES: la familia `display*` es la familia NUMÉRICA. Los tres
  // llevan `tnum` y nunca se usan para texto; los `headline*` son títulos y
  // nunca llevan `tnum`. Así se evita el problema de las cifras tabulares en
  // prosa (dejan huecos feos) sin tener que decidirlo en cada pantalla.
  //
  // Verificado glifo a glifo: por defecto los dígitos de Manrope son
  // PROPORCIONALES (el `1` mide 716/2000 em y el `9` mide 1240/2000, un 73%
  // de diferencia), y por eso toda columna de montos bailaba. La sustitución
  // GSUB de `tnum` (lookup 21, tipo 1) lleva los diez dígitos a los glifos
  // 551-560, todos con avance 1240/2000 = 0,620 em. La tabla `HVAR`
  // confirma que ese avance NO varía con el peso.

  /// 40/700, tabular. La cifra que ES la pantalla: el balance del mes en
  /// Inicio. Una por app.
  static final TextStyle displayLarge = _t(40, 700, 42, -1.0, tab: true);

  /// 32/700, tabular. Cifra principal de Finanzas, titular de Bienvenida, y
  /// la caída de [displayLarge] cuando la cifra no cabe.
  static final TextStyle displayMedium = _t(32, 700, 35, -0.6, tab: true);

  /// 24/700, tabular. Total de sección (gastos fijos, valor hora).
  static final TextStyle displaySmall = _t(24, 700, 28, -0.3, tab: true);

  /// 24/700. Titular de pantalla sin barra (Bienvenida).
  static final TextStyle headlineLarge = _t(24, 700, 30, -0.3);

  /// 20/700. Título de pantalla en la barra ("Finanzas", "Inventario").
  static final TextStyle headlineMedium = _t(20, 700, 26, -0.2);

  /// 18/600. Título de hoja modal y de diálogo.
  static final TextStyle headlineSmall = _t(18, 600, 24, 0);

  /// 16/600. Encabezado de sección ("Movimientos", "Gastos fijos").
  static final TextStyle titleLarge = _t(16, 600, 22, 0);

  /// 15/600. Título de fila de movimiento, nombre de ítem.
  static final TextStyle titleMedium = _t(15, 600, 21, 0);

  /// 14/600. Etiqueta de campo y de fila de dato.
  static final TextStyle titleSmall = _t(14, 600, 20, 0);

  /// 16/400. Texto dentro de campos; párrafo principal.
  static final TextStyle bodyLarge = _t(16, 400, 23, 0);

  /// 14/400. Texto corriente, descripciones, estados vacíos.
  static final TextStyle bodyMedium = _t(14, 400, 20, 0);

  /// 13/400. Metadato (`12 oct · Materiales`) y texto legal.
  ///
  /// Sube de 12 a 13 dp porque a 12/400 en gris la fecha y la categoría de
  /// cada movimiento eran ilegibles.
  static final TextStyle bodySmall = _t(13, 400, 18, 0);

  /// 15/600. Texto de botón primario y secundario.
  static final TextStyle labelLarge = _t(15, 600, 18, 0);

  /// 13/600. Chip, botón de texto, ítem del selector de periodo.
  static final TextStyle labelMedium = _t(13, 600, 16, 0.1);

  /// 11/600. **Única versalita del sistema**: línea guía sobre la cifra
  /// héroe y etiqueta de la barra inferior. Máximo una por sección.
  ///
  /// Es el único nivel donde sobrevive el tracking positivo: el 0,5/0,6 de
  /// labelLarge y labelMedium hinchaba los botones y desaparece.
  static final TextStyle labelSmall = _t(11, 600, 13, 0.6);

  // ─── Montos de fila ───────────────────────────────────────────────
  // Fuera del TextTheme a propósito: un monto dentro de una fila no puede
  // robarle el slot a un título.
  //
  // PROHIBIDO fijar el ancho de la columna de monto con un `SizedBox`. Medí
  // que `−$1.234.567` a 17 dp ocupa 100,0 dp en w200 y 103,9 dp en w700,
  // porque el `$` y el punto de millar SÍ varían con el peso aunque los
  // dígitos no; y un ancho fijo además no escala con `textScaler`, que es
  // justo lo que hace desbordar Inicio al 130%. El monto va en un `Text`
  // con `textAlign: TextAlign.right` y el título en `Expanded`: con `tnum`
  // eso basta para que la columna no baile.

  /// 16/600 tabular. Monto de fila de movimiento y de fila de dato.
  static final TextStyle amountRow = _t(16, 600, 20, 0, tab: true);

  /// 14/600 tabular. Monto secundario (gasto fijo, stock "2 de 6 un.").
  static final TextStyle amountSmall = _t(14, 600, 19, 0, tab: true);

  /// 20/600 tabular. Valor escrito en un campo de monto.
  static final TextStyle amountField = _t(20, 600, 24, 0, tab: true);

  /// El `TextTheme` que consume `ThemeData`.
  ///
  /// Se expone como getter y no como constante porque los estilos llevan
  /// `fontVariations`, que no es `const`.
  static TextTheme get theme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
