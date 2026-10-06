import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/month_labels.dart';
import '../../../finances/presentation/providers/finances_provider.dart';
import '../../domain/usecases/calculate_net_hourly_value.dart';
import '../bloc/hourly_rate_provider.dart';

/// PROPÓSITO
/// ---------
/// Enseña las DOS cifras por hora del mes, cada una con su nombre exacto:
///
/// · **Lo que te entró por hora** = (ingresos − comisiones del medio de pago)
///   ÷ horas configuradas. Es el neto del contrato C-3. No descuenta gastos.
/// · **Lo que te sobró por hora** = lo anterior − los gastos del mes.
///
/// POR QUÉ SON DOS. Hasta ahora había una sola, calculada como la primera y
/// rotulada como la segunda ("Lo que te quedó por hora"). Medido en
/// emulator-5554 con los datos demo de octubre de 2026 la pantalla decía
/// $8.092 cuando lo que sobró por hora eran $2.754. La etiqueta no describía
/// el cálculo, y el propio caso de uso lo decía por escrito: el valor hora
/// responde "cuánto me entró por hora", no "cuánto me sobró".
///
/// Se podía arreglar de dos maneras —cambiar el rótulo o cambiar el cálculo—
/// y las dos cifras le sirven a una artesana: la primera se compara con el
/// valor hora objetivo de arriba (lo que cobra por su trabajo), la segunda
/// dice si el mes cerró en positivo. Así que se enseñan ambas, rotuladas sin
/// ambigüedad y con una línea que explica de dónde sale cada una.
///
/// Es el contrapunto honesto del valor hora *objetivo* que se configura
/// arriba: ese es una meta, estos son hechos. Las horas salen de la
/// configuración del propio usuario y las cifras del agregado mensual que
/// escribe el backend; la app no supone nada.
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

    final summary = finances.summary;
    final mes = _nombreDelMes(summary.monthKey);
    final cifras = _useCase.execute(
      summary: summary,
      transactions: finances.transactions,
      availableHoursPerMonth: rate.availableHoursPerMonth,
    );

    if (!cifras.hasIncome) {
      return _Bloque(
        children: [
          _LineaGuia('Lo que te entró por hora en $mes'),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Registra tus ingresos del mes y aquí aparece lo que te entró '
            'por cada hora de trabajo, y lo que te sobró después de los '
            'gastos.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),
        ],
      );
    }

    final horas = _formatearHoras(cifras.availableHoursPerMonth);

    return _Bloque(
      children: [
        // ─── 1. Lo que ENTRÓ por hora ───────────────────────────────
        _LineaGuia('Lo que te entró por hora en $mes'),
        const SizedBox(height: AppSpacing.x2),
        _Cifra(cifras.entryHourlyValue),
        const SizedBox(height: AppSpacing.x2),
        // La línea sobria que exige el contrato: el usuario tiene que saber
        // qué descuenta la cifra y qué NO descuenta.
        _Nota(
          cifras.hasPlatformFees
              ? 'Tus ingresos de $mes menos '
                  '${formatCurrency(cifras.platformFees, currency: kFallbackCurrency)} '
                  'de comisiones del medio de pago que registraste, sobre las '
                  '$horas que configuraste. No descuenta tus gastos.'
              : 'Tus ingresos de $mes sobre las $horas que configuraste. No '
                  'registraste comisiones del medio de pago este mes, y esta '
                  'cifra no descuenta tus gastos.',
        ),

        // ─── 2. Lo que SOBRÓ por hora ───────────────────────────────
        const SizedBox(height: AppSpacing.x6),
        _LineaGuia('Lo que te sobró por hora en $mes'),
        const SizedBox(height: AppSpacing.x2),
        _Cifra(
          cifras.leftoverHourlyValue,
          // Un resultado negativo se pinta en el color del dinero que sale:
          // es la misma señal que usa el balance de Inicio.
          color: cifras.leftoverHourlyValue < 0 ? AppPalette.moneyOut : null,
        ),
        const SizedBox(height: AppSpacing.x2),
        _Nota(
          cifras.hasExpenses
              ? 'Lo de arriba menos los '
                  '${formatCurrency(cifras.expenses, currency: kFallbackCurrency)} '
                  'de gastos que registraste en $mes.'
              : 'No registraste gastos en $mes, así que por ahora es lo mismo '
                  'que te entró.',
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
  /// caso normal.
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
        margin: const EdgeInsets.only(top: AppSpacing.x6),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
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

/// Una de las dos cifras del bloque.
class _Cifra extends StatelessWidget {
  const _Cifra(this.valor, {this.color});

  final double valor;
  final Color? color;

  @override
  Widget build(final BuildContext context) => Text(
        formatCurrency(valor, currency: kFallbackCurrency),
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: color ?? AppPalette.textPrimary,
            ),
      );
}

/// Línea de contexto bajo una cifra: de dónde sale y qué no incluye.
class _Nota extends StatelessWidget {
  const _Nota(this.texto);

  final String texto;

  @override
  Widget build(final BuildContext context) => Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
      );
}

/// Línea guía sobre la cifra, en `labelSmall` 11/600 mayúsculas
/// `textSecondary` (6,91:1).
class _LineaGuia extends StatelessWidget {
  const _LineaGuia(this.texto);

  final String texto;

  @override
  Widget build(final BuildContext context) => Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
      );
}
