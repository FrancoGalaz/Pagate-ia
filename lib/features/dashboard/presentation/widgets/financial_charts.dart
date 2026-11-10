import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/month_labels.dart';
import '../../../finances/domain/entities/finances_summary_entity.dart';
import '../../../finances/domain/entities/finances_transaction_entity.dart';
import '../../../finances/presentation/providers/finances_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// GRÁFICOS DE FINANZAS
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, "Color" (series de datos) y paso 6.5.
//
// VIVEN EN FINANZAS, NO EN INICIO. En la portada sumaban ~834 dp de los
// ~1.697 totales —el 49% del scroll— y dos de los tres mostraban "Aún no
// hay datos mensuales" hasta que el usuario tuviera dos meses registrados.
// Aquí el usuario llega con intención de analizar.
//
// EL DONUT DESAPARECE, y no se sustituye por una rampa de seis colores.
// Tenía `_pieColors`, diez colores hexadecimales literales de los cuales
// seis duplicaban
// tokens y cuatro —violeta #8B5CF6, rosa #EC4899, turquesa #14B8A6, índigo
// #6366F1— no existían en la paleta. El texto blanco de 11 dp que iba
// dentro de cada porción fallaba el contraste en NUEVE de los diez colores
// (2,15 el ámbar, 2,49 el teal, 2,54 el verde, 2,67 el coral, 3,53 el rosa,
// 3,68 el azul, 3,76 el rojo, 4,23 el violeta, 4,47 el índigo; solo el
// #006B5F pasaba con 6,43). Lo sustituyen barras horizontales con etiqueta,
// monto y porcentaje, donde el color es REDUNDANTE y no hay problema de
// contraste entre segmentos adyacentes. El hallazgo se cierra eliminando la
// necesidad, no inventando seis colores más.
//
// DOS TINTAS EN LAS SERIES, no diez: `moneyIn` #0B6A47 para los ingresos y
// `textPrimary` #101828 para los gastos, los dos sobre blanco con ratio
// verificado. Las barras de categoría usan `ink` sobre pista `sunken` (el
// color de acción queda para lo que se toca) y `seriesOther` #7E8794 (3,63:1, cumple 1.4.11 como objeto
// gráfico) para la fila "Otros".
//
// CADA GRÁFICO SE ANUNCIA. Antes la sección entera era un hueco mudo para
// el lector de pantalla: `Semantics`, `semanticLabel` y `ExcludeSemantics`
// aparecían CERO veces en todo `lib/`. Ahora el `CustomPaint` va excluido y
// el bloque lleva una etiqueta que dice las cifras.
// ═══════════════════════════════════════════════════════════════════════

/// Ingresos y gastos de los últimos meses, en dos tintas.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, this.anio});

  /// `'2026'` para mostrar solo los meses de ese año; `null`, todos.
  final String? anio;

  @override
  Widget build(final BuildContext context) {
    final finances = context.watch<FinancesProvider>();

    // El provider entrega del más reciente al más antiguo; una serie
    // temporal va en orden cronológico.
    final months = [
      for (final m in finances.months.reversed)
        if (anio == null || m.monthKey.startsWith('$anio-')) m,
    ];

    // El año ya está en la cabecera: el eje dice «oct», y solo un mes de
    // otro año lleva el suyo («dic 25»), para no confundir dos diciembres.
    final anioDeReferencia = anio ?? finances.selectedMonthKey.split('-').first;
    String etiquetaEje(final FinancesSummaryEntity m) {
      final partes = m.monthKey.split('-');
      final mes = partes.length == 2 ? int.tryParse(partes[1]) : null;
      if (mes == null || mes < 1 || mes > 12) return m.monthKey;
      return partes[0] == anioDeReferencia
          ? monthAbbreviation(mes)
          : shortMonthLabelFromMonthKey(m.monthKey);
    }

    if (months.length < 2) {
      return _BloqueGrafico(
        title: 'Ingresos y gastos por mes',
        child: _MensajeVacio(
          message: months.isEmpty
              ? 'Registra movimientos para ver la comparación.'
              : 'Con un mes más aparece la comparación.',
        ),
      );
    }

    final (maxY, paso) = _escala(months);

    return _BloqueGrafico(
      title: 'Ingresos y gastos por mes',
      semanticsLabel: _describir(months),
      leyenda: const [
        _Leyenda(color: AppPalette.moneyIn, texto: 'Ingresos'),
        _Leyenda(color: AppPalette.textPrimary, texto: 'Gastos'),
      ],
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            // El eje parte en $0 y lo dice: una barra que arranca más
            // arriba exagera la diferencia entre meses.
            minY: 0,
            maxY: maxY,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (
                  final group,
                  final groupIndex,
                  final rod,
                  final rodIndex,
                ) =>
                    BarTooltipItem(
                  '${monthLabelFromMonthKey(months[groupIndex].monthKey)}\n'
                  '${formatCurrency(rod.toY, currency: kFallbackCurrency)}',
                  _estiloEje(context).copyWith(color: AppPalette.surface),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (final value, final meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= months.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.x2),
                      child: Text(
                        etiquetaEje(months[idx]),
                        style: _estiloEje(context),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: _anchoEjeVertical,
                  interval: paso,
                  // Único sitio del sistema donde se abrevia una cifra: en
                  // un eje no cabe entera. El $0 también se rotula.
                  getTitlesWidget: (final value, final meta) =>
                      _rotuloVertical(
                        context,
                        formatCompactCurrency(
                          value,
                          currency: kFallbackCurrency,
                        ),
                      ),
                ),
              ),
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
            ),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: paso,
              getDrawingHorizontalLine: (final value) => const FlLine(
                color: AppPalette.hairline,
                strokeWidth: AppSizes.borderHairline,
              ),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < months.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: months[i].totalIncome,
                      color: AppPalette.moneyIn,
                      width: 14,
                      borderRadius: _topeBarra,
                    ),
                    BarChartRodData(
                      toY: months[i].totalExpenses,
                      color: AppPalette.textPrimary,
                      width: 14,
                      borderRadius: _topeBarra,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static const BorderRadius _topeBarra = BorderRadius.vertical(
    top: Radius.circular(AppRadius.r4),
  );

  /// Tope y paso del eje, en números redondos: $100 mil, $200 mil… y no
  /// $89,3 mil. Como mucho cuatro tramos sobre el $0.
  static (double, double) _escala(final List<FinancesSummaryEntity> months) {
    var max = 0.0;
    for (final m in months) {
      final v = math.max(m.totalIncome, m.totalExpenses);
      if (v > max) max = v;
    }
    if (max <= 0) return (1000, 250);
    final crudo = max / 4;
    final base = math
        .pow(10, (math.log(crudo) / math.ln10).floor())
        .toDouble();
    final paso = [1, 2, 2.5, 5, 10]
        .map((final f) => f * base)
        .firstWhere((final v) => v >= crudo);
    return ((max / paso).ceil() * paso, paso);
  }

  String _describir(final List<FinancesSummaryEntity> months) {
    final ultimo = months.last;
    return 'Ingresos y gastos por mes. '
        'Último mes, ${monthLabelFromMonthKey(ultimo.monthKey)}: '
        'ingresos ${formatCurrency(
      ultimo.totalIncome,
      currency: kFallbackCurrency,
    )}, gastos ${formatCurrency(
      ultimo.totalExpenses,
      currency: kFallbackCurrency,
    )}, balance ${formatCurrency(
      ultimo.balance,
      currency: kFallbackCurrency,
    )}.';
  }
}

/// Gastos por categoría, en barras horizontales con etiqueta, monto y
/// porcentaje. Sustituye al donut de diez colores.
class CategoryBars extends StatelessWidget {
  const CategoryBars({super.key});

  /// Cinco categorías y el resto agrupado en "Otros". Más filas se leen
  /// como una lista, y la lista ya está debajo.
  static const int _maxCategorias = 5;

  @override
  Widget build(final BuildContext context) {
    final finances = context.watch<FinancesProvider>();

    final porCategoria = <String, double>{};
    for (final t in finances.transactions) {
      if (t.type != TransactionType.expense || t.amount <= 0) continue;
      final categoria = t.category.isNotEmpty ? t.category : 'Sin categoría';
      porCategoria.update(
        categoria,
        (final v) => v + t.amount,
        ifAbsent: () => t.amount,
      );
    }

    final total = porCategoria.values.fold<double>(0, (final a, final b) => a + b);
    if (total <= 0) {
      return const _BloqueGrafico(
        title: 'En qué se te va el mes',
        child: _MensajeVacio(
          message: 'Registra gastos para ver en qué se te va el mes.',
        ),
      );
    }

    final ordenadas = porCategoria.entries.toList()
      ..sort((final a, final b) => b.value.compareTo(a.value));

    final filas = <_FilaCategoria>[];
    for (var i = 0; i < ordenadas.length && i < _maxCategorias; i++) {
      filas.add(
        _FilaCategoria(
          nombre: ordenadas[i].key,
          monto: ordenadas[i].value,
          fraccion: ordenadas[i].value / total,
        ),
      );
    }
    if (ordenadas.length > _maxCategorias) {
      final resto = ordenadas
          .skip(_maxCategorias)
          .fold<double>(0, (final a, final b) => a + b.value);
      filas.add(
        _FilaCategoria(
          nombre: 'Otros',
          monto: resto,
          fraccion: resto / total,
          esResto: true,
        ),
      );
    }

    return _BloqueGrafico(
      title: 'En qué se te va el mes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final fila in filas) ...[
            fila,
            if (fila != filas.last) const SizedBox(height: AppSpacing.x3),
          ],
        ],
      ),
    );
  }
}

/// Una categoría: nombre, monto, porcentaje y la barra debajo.
class _FilaCategoria extends StatelessWidget {
  const _FilaCategoria({
    required this.nombre,
    required this.monto,
    required this.fraccion,
    this.esResto = false,
  });

  final String nombre;
  final double monto;
  final double fraccion;
  final bool esResto;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final porcentaje = (fraccion * 100).round();
    // Con letra de 1,5 o más el nombre va en su línea, entero, y el monto
    // con el porcentaje debajo: al lado quedaba en «Arriendo …».
    final apilado = MediaQuery.textScalerOf(context).scale(10) >= 15;
    final cifras = <Widget>[
      Text(
        formatCurrency(monto, currency: kFallbackCurrency),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppPalette.textPrimary,
        ),
      ),
      Text(
        '$porcentaje %',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppPalette.textMuted,
        ),
      ),
    ];

    return Semantics(
      label: '$nombre, '
          '${formatCurrency(monto, currency: kFallbackCurrency)}, '
          '$porcentaje por ciento',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (apilado) ...[
              Text(nombre, style: theme.textTheme.bodyMedium),
              Wrap(
                spacing: AppSpacing.x3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: cifras,
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x2),
                  Flexible(
                    child: Text(
                      formatCurrency(monto, currency: kFallbackCurrency),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppPalette.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Text(
                    '$porcentaje %',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.x1),
            ClipRRect(
              borderRadius: AppRadius.r4Border,
              child: LinearProgressIndicator(
                value: fraccion.clamp(0, 1),
                // El color aquí es redundante: la etiqueta, el monto y el
                // porcentaje ya están escritos al lado.
                // El oscuro y no el color de acción: estas barras no se
                // tocan.
                color: esResto ? AppPalette.seriesOther : AppPalette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Piezas compartidas ────────────────────────────────────────────────

/// Encabezado, leyenda y marco de un gráfico.
class _BloqueGrafico extends StatelessWidget {
  const _BloqueGrafico({
    required this.title,
    required this.child,
    this.semanticsLabel,
    this.leyenda,
  });

  final String title;
  final Widget child;

  /// Lo que el lector de pantalla anuncia en lugar del dibujo. Si es `null`
  /// (gráfico vacío), basta con el texto del mensaje.
  final String? semanticsLabel;

  final List<Widget>? leyenda;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    // Con letra de 1,5 o más la leyenda baja bajo el título: a su lado lo
    // estrujaba hasta partir «Ingresos» en «Ingres / os».
    final apilado = MediaQuery.textScalerOf(context).scale(10) >= 15;
    final titulo = Text(title, style: theme.textTheme.titleLarge);

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (apilado) ...[
          titulo,
          if (leyenda != null) ...[
            const SizedBox(height: AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.x3,
              runSpacing: AppSpacing.x1,
              children: leyenda!,
            ),
          ],
        ] else
          Row(
            children: [
              Expanded(child: titulo),
              if (leyenda != null)
                for (final item in leyenda!) ...[
                  const SizedBox(width: AppSpacing.x3),
                  item,
                ],
            ],
          ),
        const SizedBox(height: AppSpacing.x4),

        // El dibujo es mudo para un lector de pantalla; lo que se anuncia
        // son las cifras del `Semantics` de fuera.
        if (semanticsLabel == null)
          child
        else
          ExcludeSemantics(child: child),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x4,
      ),
      child: semanticsLabel == null
          ? contenido
          : Semantics(label: semanticsLabel, child: contenido),
    );
  }
}

/// Cuadrado de color y nombre de una serie.
class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(final BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.x2,
            height: AppSpacing.x2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.x1),
          Text(
            texto,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppPalette.textMuted,
                ),
          ),
        ],
      );
}

class _MensajeVacio extends StatelessWidget {
  const _MensajeVacio({required this.message});

  final String message;

  @override
  Widget build(final BuildContext context) => Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppPalette.textSecondary,
            ),
      );
}

// ─── Helpers ───────────────────────────────────────────────────────────

/// Estilo de los rótulos de eje. Sale del `TextTheme`, así que hereda
/// `fontVariations` y la familia; escrito a mano no las heredaría.
///
/// `labelSmall` (11 dp) y no `labelMedium`: con 13 dp, "$500 mil" no cabía
/// en el ancho reservado del eje y se partía en dos líneas, de modo que los
/// rótulos se pisaban entre sí.
TextStyle _estiloEje(final BuildContext context) =>
    Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppPalette.textSecondary,
        ) ??
    const TextStyle(color: AppPalette.textSecondary);

/// Rótulo de eje vertical: una sola línea, a la derecha y sin partirse.
Widget _rotuloVertical(final BuildContext context, final String texto) =>
    Padding(
      padding: const EdgeInsets.only(right: AppSpacing.x2),
      child: Text(
        texto,
        style: _estiloEje(context),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        textAlign: TextAlign.right,
      ),
    );

/// Ancho reservado para el eje vertical. Cabe "$1.310 mil" a 11 dp con el
/// hueco de 8 dp hasta la primera barra.
const double _anchoEjeVertical = 72;
