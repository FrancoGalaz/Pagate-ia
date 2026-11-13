import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// BARRA DE NAVEGACIÓN INFERIOR
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 13.
//
// SE USA `NavigationBar` DE MATERIAL 3, no un `Row` montado a mano. Lo que
// había era un `Container` con cinco `GestureDetector`: TalkBack no sabía
// que eran pestañas, ni cuál estaba activa, ni cuántas había. Material trae
// el rol de pestaña, el estado seleccionado, el anuncio "2 de 5" y el alto
// mínimo de fábrica, y todo eso es exactamente lo que faltaba.
//
// QUÉ SE BORRÓ:
//   · El indicador de 3 dp pintado con el degradado de marca sobre la
//     pestaña
//     activa. No hay degradados en el sistema.
//   · El `AnimatedSwitcher` del icono. Un cambio de pestaña tiene que
//     sentirse instantáneo.
//   · La variante `compact` por debajo de 380 dp, que escondía las
//     etiquetas. Un icono sin etiqueta no se entiende, y además es una de
//     las cosas que el informe previo al lanzamiento de Play revisa.
//
// EL ESTADO ACTIVO SE COMUNICA CON TRES SEÑALES: color de marca, relleno
// del icono y peso de la etiqueta. Ninguna de las tres es solo color, que es
// lo que pide WCAG 1.4.1.
// ═══════════════════════════════════════════════════════════════════════

/// Un destino de la barra.
class PagateNavItem {
  /// Icono en reposo: contorno, en `textMuted` (5,31:1).
  final IconData icon;

  /// Icono activo: relleno, en `brand` (6,43:1).
  final IconData activeIcon;

  final String label;

  const PagateNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Barra de pestañas inferior del sistema.
///
/// El `SafeArea` inferior lo pone `NavigationBar` por su cuenta, así que la
/// barra no se come el gesto de inicio de Android.
class PagateBottomNav extends StatelessWidget {
  final List<PagateNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  const PagateBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  @override
  Widget build(final BuildContext context) => DecoratedBox(
        // Una línea de 1 dp separa la barra del contenido. Sin sombra: el
        // sistema solo la usa en la hoja modal, el menú y el snackbar.
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppPalette.border,
              width: AppSizes.borderHairline,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: onSelected,

          // Todo lo demás (fondo, alto 56, indicador transparente, etiquetas
          // siempre visibles, estilos de icono y de texto) lo pone
          // `navigationBarTheme`. Ni un estilo en línea.
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon),
                label: item.label,

                // El `tooltip` por defecto repite la etiqueta, que ya está
                // visible debajo del icono, y en móvil aparece al mantener
                // pulsado sin aportar nada.
                tooltip: '',
              ),
          ],
        ),
      );
}
