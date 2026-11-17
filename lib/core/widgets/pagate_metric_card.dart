import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_text.dart';

// ═══════════════════════════════════════════════════════════════════════
// TARJETA DE MÉTRICA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/diseno/variantes-cabal.html, componente 2.
//
// Monto en 800 y una etiqueta debajo. El ingreso va en verde con flecha
// hacia arriba; el gasto, en el oscuro con flecha hacia abajo y el «−» que
// ya trae el monto. El color nunca es la única señal: la flecha y la
// etiqueta dicen lo mismo.
// ═══════════════════════════════════════════════════════════════════════

/// Tono de una [PagateMetricCard].
enum PagateMetricTone { neutral, income, expense }

/// Cifra destacada con su etiqueta, en una tarjeta blanca.
class PagateMetricCard extends StatelessWidget {
  /// Ya formateado, con signo si corresponde.
  final String value;
  final String label;
  final PagateMetricTone tone;

  const PagateMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.tone = PagateMetricTone.neutral,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final esIngreso = tone == PagateMetricTone.income;
    final flecha = switch (tone) {
      PagateMetricTone.income => Icons.arrow_upward_rounded,
      PagateMetricTone.expense => Icons.arrow_downward_rounded,
      PagateMetricTone.neutral => null,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.x3 + 2),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadius.r16Border,
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sin `maxLines`: con letra grande el monto baja de línea entero en
          // vez de cortarse.
          Text(
            value,
            style: AppText.weight(
              AppText.amountField,
              800,
            ).copyWith(color: esIngreso ? AppPalette.moneyIn : AppPalette.ink),
          ),
          const SizedBox(height: AppSpacing.x1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (flecha != null) ...[
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: esIngreso
                        ? AppPalette.moneyInSurface
                        : AppPalette.sunken,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    flecha,
                    size: AppIconSize.xs - 2,
                    color: esIngreso ? AppPalette.moneyIn : AppPalette.ink,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
