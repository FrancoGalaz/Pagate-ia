import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// CHIP DE FILTRO Y DE SELECCIÓN
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 10.
//
// TRES COSAS QUE CAMBIAN Y POR QUÉ:
//
// 1. SE VA LA OPACIDAD. La versión anterior pintaba `brand` al 15% y un
//    borde al 40%. Un color con alfa no tiene ratio de contraste
//    comprobable: depende de lo que haya debajo. Ahora son dos colores
//    planos del sistema, `brandSurface` #E6F2F0 con `brand` encima, que da
//    5,61:1 verificado.
//
// 2. SE VA LA ANIMACIÓN. El `AnimatedContainer` de 200 ms hacía que un
//    cambio de selección se sintiera lento. Una selección tiene que ser
//    instantánea; las únicas animaciones del sistema son la pulsación de
//    fila, la hoja modal y el pulso del esqueleto.
//
// 3. SE VA EL `GestureDetector`. Era uno de los diecinueve que la app usaba
//    como botón: TalkBack no sabía que era un control, ni que estaba
//    seleccionado, ni que pertenecía a un grupo. Ahora es `ChoiceChip`, que
//    trae el rol, el estado y la exclusividad mutua de fábrica.
//
// ALTO 32 CON CAJA TÁCTIL 48: `materialTapTargetSize: padded` añade el
// relleno invisible. El píxel visible mide 32, el área que responde al dedo
// mide 48, que es lo que marca el informe previo al lanzamiento de Google
// Play.
// ═══════════════════════════════════════════════════════════════════════

/// Grupo de chips seleccionables, en `Wrap` con 8 dp de separación.
///
/// Soporta selección única y múltiple. La API pública no cambia respecto de
/// la versión anterior, así que las cuatro pantallas que ya lo usan mejoran
/// sin editarse.
class PagateChipSelector extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// Solo cambia la semántica que se expone al lector de pantalla: con
  /// selección única los chips se anuncian como grupo mutuamente excluyente.
  final bool allowMultiple;

  /// Opciones que se dibujan apagadas y no responden. Útil cuando una
  /// categoría no aplica al tipo de movimiento elegido.
  final Set<String> disabled;

  const PagateChipSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.allowMultiple = false,
    this.disabled = const {},
  });

  @override
  Widget build(final BuildContext context) => Wrap(
        spacing: AppSpacing.x2,
        runSpacing: AppSpacing.x2,
        children: [
          for (final option in options)
            PagateChip(
              label: option,
              isSelected: selected.contains(option),
              isEnabled: !disabled.contains(option),
              exclusive: !allowMultiple,
              onSelected: () => onToggle(option),
            ),
        ],
      );
}

/// Un chip suelto. Se expone porque el selector de periodo y los filtros de
/// inventario necesitan el mismo píxel sin el `Wrap` alrededor.
class PagateChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isEnabled;

  /// `true` dibuja un [ChoiceChip] (elegir uno de varios) y `false` un
  /// [FilterChip] (marcar varios).
  ///
  /// NO es cosmético: los dos se ven exactamente igual porque reciben los
  /// mismos colores, pero anuncian cosas distintas. `ChoiceChip` se lee como
  /// una opción de un grupo excluyente y `FilterChip` como una casilla
  /// marcable. Dejar el rol en manos de Material es lo que permite borrar el
  /// `GestureDetector` anterior, que no anunciaba ninguno de los dos.
  final bool exclusive;

  final VoidCallback onSelected;

  const PagateChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.isEnabled = true,
    this.exclusive = true,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    final Color foreground;
    final Color background;
    final Color borderColor;
    if (!isEnabled) {
      foreground = AppPalette.textDisabled;
      background = AppPalette.sunken;
      borderColor = AppPalette.border;
    } else if (isSelected) {
      foreground = AppPalette.brand;
      background = AppPalette.brandSurface;
      borderColor = AppPalette.brand;
    } else {
      foreground = AppPalette.textSecondary;
      background = AppPalette.surface;
      borderColor = AppPalette.border;
    }

    final etiqueta = Text(label);
    final estilo = theme.textTheme.labelMedium?.copyWith(color: foreground);
    final onSelectedCallback =
        isEnabled ? (final bool _) => onSelected() : null;
    final borde = BorderSide(color: borderColor, width: AppSizes.borderHairline);
    const forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.r8)),
    );
    const relleno = EdgeInsets.symmetric(horizontal: AppSpacing.x3);

    // Lo que convierte 32 dp visibles en 48 dp táctiles. La onda de Material
    // no hace falta apagarla aquí: el tema ya fija `splashFactory: NoSplash`
    // para toda la app.
    const areaTactil = MaterialTapTargetSize.padded;

    // `showCheckmark: false` porque el chip ya se distingue por color y por
    // borde, y el check desplaza la etiqueta al seleccionar.
    return exclusive
        ? ChoiceChip(
            label: etiqueta,
            selected: isSelected,
            onSelected: onSelectedCallback,
            labelStyle: estilo,
            labelPadding: EdgeInsets.zero,
            padding: relleno,
            showCheckmark: false,
            backgroundColor: background,
            selectedColor: background,
            disabledColor: background,
            side: borde,
            shape: forma,
            shadowColor: Colors.transparent,
            selectedShadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pressElevation: 0,
            materialTapTargetSize: areaTactil,
          )
        : FilterChip(
            label: etiqueta,
            selected: isSelected,
            onSelected: onSelectedCallback,
            labelStyle: estilo,
            labelPadding: EdgeInsets.zero,
            padding: relleno,
            showCheckmark: false,
            backgroundColor: background,
            selectedColor: background,
            disabledColor: background,
            side: borde,
            shape: forma,
            shadowColor: Colors.transparent,
            selectedShadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            pressElevation: 0,
            materialTapTargetSize: areaTactil,
          );
  }
}
