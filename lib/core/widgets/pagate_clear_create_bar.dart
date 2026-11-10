import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'pagate_primary_button.dart';

// ═══════════════════════════════════════════════════════════════════════
// PAR LIMPIAR / CREAR
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/diseno/variantes-cabal.html, componente 4.
//
// Pie fijo de un formulario: Limpiar (secundario, en el oscuro) y la acción
// principal (en la greda), en proporción 1 : 1,4. Con letra grande se apilan
// con la acción arriba, para que ninguna etiqueta se corte.
// ═══════════════════════════════════════════════════════════════════════

/// Pie de formulario con Limpiar y la acción principal.
class PagateClearCreateBar extends StatelessWidget {
  final String createLabel;
  final VoidCallback? onCreate;
  final VoidCallback? onClear;
  final String clearLabel;
  final bool isLoading;

  const PagateClearCreateBar({
    super.key,
    required this.createLabel,
    required this.onCreate,
    required this.onClear,
    this.clearLabel = 'Limpiar',
    this.isLoading = false,
  });

  @override
  Widget build(final BuildContext context) {
    final limpiar = PagatePrimaryButton.secondary(
      label: clearLabel,
      onPressed: isLoading ? null : onClear,
    );
    final crear = PagatePrimaryButton(
      label: createLabel,
      onPressed: onCreate,
      isLoading: isLoading,
    );
    final apilar = MediaQuery.textScalerOf(context).scale(1) >= 1.3;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        border: Border(
          top: BorderSide(
            color: AppPalette.hairline,
            width: AppSizes.borderHairline,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: apilar
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    crear,
                    const SizedBox(height: AppSpacing.x2),
                    limpiar,
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 5, child: limpiar),
                    const SizedBox(width: AppSpacing.x3),
                    Expanded(flex: 7, child: crear),
                  ],
                ),
        ),
      ),
    );
  }
}
