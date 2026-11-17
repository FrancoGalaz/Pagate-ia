import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// SECCIÓN — NO ES UNA TARJETA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 6.
//
// EL CAMBIO DE FONDO: en móvil la sección va A SANGRE, con radio 0 y solo
// una línea arriba y otra abajo. Una lista de filas blancas separada del
// lienzo por dos líneas se lee como una cartola bancaria; la misma lista
// metida en una caja de radio 32 con sombra se lee como una plantilla, y
// además pierde 32 dp de ancho útil por fila.
//
// QUÉ SE BORRÓ:
//   · El radio de 32 dp como forma por defecto.
//   · La sombra pequeña del tema anterior, y con ella la rama
//     `Theme.of(context).brightness == Brightness.dark`: ningún widget del
//     sistema vuelve a decidir su propio brillo, porque el tema es único.
//   · El padding de 24 por los cuatro lados: en móvil las filas traen el
//     suyo (16 horizontal) y la sección solo aporta 4 dp verticales.
//
// EN ESCRITORIO (≥720 dp) sí vuelve el radio 12, el margen lateral y el
// borde en los cuatro lados, porque ahí la sección no ocupa el ancho de la
// ventana y necesita un límite.
// ═══════════════════════════════════════════════════════════════════════

/// Bloque blanco que agrupa filas o campos.
///
/// Prohibido anidar una sección dentro de otra: dos niveles de jerarquía por
/// pantalla es el máximo del sistema.
class PagateSectionCard extends StatelessWidget {
  final Widget child;

  /// Relleno interior. Si se omite, el sistema decide según el ancho: en
  /// móvil 4 dp verticales y 0 horizontales (las filas traen el suyo); en
  /// escritorio 4 verticales también, con el margen lateral fuera.
  final EdgeInsetsGeometry? padding;

  /// Margen exterior; por defecto 16 dp a cada lado. `EdgeInsets.zero`
  /// cuando el padre ya trae ese margen (la lista de un formulario).
  final EdgeInsetsGeometry margin;

  const PagateSectionCard({
    super.key,
    required this.child,
    this.padding,
    this.margin = const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
  });

  /// Breakpoint único de la app, el mismo que decide rail contra barra
  /// inferior.
  static const double _desktopBreakpoint = 720;

  @override
  Widget build(final BuildContext context) {
    final esEscritorio =
        MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

    final decoracion = esEscritorio
        ? BoxDecoration(
            color: AppPalette.surface,
            borderRadius: AppRadius.r12Border,
            border: Border.all(
              color: AppPalette.border,
              width: AppSizes.borderHairline,
            ),
          )
        // Variante A: en móvil la sección es una tarjeta blanca de radio
        // 16 con sombra suave, separada 16 dp de los bordes de la pantalla.
        : BoxDecoration(
            color: AppPalette.surface,
            borderRadius: AppRadius.r16Border,
            boxShadow: AppShadows.level1,
          );

    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding ??
          const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      decoration: decoracion,

      // `antiAlias` para que una fila con fondo presionado no se salga del
      // radio en escritorio.
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
