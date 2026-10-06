import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/month_labels.dart';
import '../../../../core/widgets/pagate_label.dart';
import '../../../finances/presentation/providers/finances_provider.dart';
import '../../domain/usecases/calculate_net_hourly_value.dart';
import '../bloc/hourly_rate_provider.dart';

/// PROPÓSITO
/// ---------
/// Muestra el valor hora **neto** del mes en pantalla: lo que de verdad le
/// quedó al usuario por hora, descontadas las comisiones del medio de pago
/// que registró (contrato C-3).
///
/// Es el contrapunto honesto del valor hora *objetivo* que configura arriba:
/// ese es una meta, este es un hecho. Las horas salen de la configuración del
/// propio usuario y los ingresos de lo que registró; la app no supone nada.
///
/// Mide, no asesora: ni una palabra sobre impuestos, declaraciones o precios
/// recomendados.
class NetHourlyValueSection extends StatelessWidget {
  const NetHourlyValueSection({super.key});

  static const CalculateNetHourlyValue _useCase = CalculateNetHourlyValue();

  @override
  Widget build(final BuildContext context) {
    final rate = context.watch<HourlyRateProvider>().currentRate;
    // Sin configuración no hay horas por las que dividir: no se muestra una
    // cifra inventada, simplemente no hay sección.
    if (rate == null) return const SizedBox.shrink();

    final finances = context.watch<FinancesProvider>();
    final theme = Theme.of(context);

    // Principio 5 de docs/ARQUITECTURA.md: un fallo de lectura no se disfraza
    // de "no tienes ingresos".
    final error = finances.error;
    if (error != null) {
      return _Bloque(
        children: [
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.error,
            ),
          ),
          TextButton(
            onPressed: finances.retry,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    // Mientras no llegó el primer snapshot del mes no se pinta un 0 que
    // después cambiaría solo.
    if (finances.isLoadingTransactions) return const SizedBox.shrink();

    final mes = _nombreDelMes(finances.summary.monthKey);
    final neto = _useCase.execute(
      transactions: finances.transactions,
      availableHoursPerMonth: rate.availableHoursPerMonth,
    );

    if (!neto.hasIncome) {
      return _Bloque(
        children: [
          PagateLabel('Lo que te quedó por hora en $mes', isUppercase: true),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Registra tus ingresos del mes y aquí aparece lo que te quedó '
            'por cada hora de trabajo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    final horas = _formatearHoras(neto.availableHoursPerMonth);

    return _Bloque(
      children: [
        PagateLabel('Lo que te quedó por hora en $mes', isUppercase: true),
        const SizedBox(height: AppSpacing.xs),
        Text(
          formatCurrency(neto.netHourlyValue, currency: kFallbackCurrency),
          style: theme.textTheme.displaySmall?.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // La línea sobria que exige el contrato: el usuario tiene que saber
        // que la cifra YA tiene descontadas las comisiones, y cuánto fue.
        Text(
          neto.hasPlatformFees
              ? 'Ya descuenta ${formatCurrency(neto.platformFees, currency: kFallbackCurrency)} '
                  'de comisiones del medio de pago que registraste, sobre las '
                  '$horas que configuraste.'
              : 'Sobre las $horas que configuraste. No registraste comisiones '
                  'del medio de pago este mes, así que no hay nada que '
                  'descontar.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// "octubre" a partir de `2026-10`. Si la clave no es válida se devuelve
  /// "el mes" en lugar de inventar un nombre.
  static String _nombreDelMes(final String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return 'el mes';
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return 'el mes';
    return monthName(month);
  }

  /// "160 horas al mes". Sin decimales cuando son horas enteras, que es el
  /// caso normal (días × horas por día).
  static String _formatearHoras(final double hours) {
    final enteras = hours == hours.roundToDouble();
    final texto = enteras
        ? hours.round().toString()
        : hours.toStringAsFixed(1).replaceAll('.', ',');
    return '$texto horas al mes';
  }
}

/// Caja del bloque: alineado a la izquierda, sin tarjeta, sin icono y sin
/// color de fondo. El sistema visual v2 reserva las tarjetas para las
/// secciones de datos, no para los avisos.
class _Bloque extends StatelessWidget {
  const _Bloque({required this.children});

  final List<Widget> children;

  @override
  Widget build(final BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.xl),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}
