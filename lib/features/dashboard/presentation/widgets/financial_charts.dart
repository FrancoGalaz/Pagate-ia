import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../finances/domain/entities/finances_summary_entity.dart';
import '../../../finances/domain/entities/finances_transaction_entity.dart';
import '../../../finances/presentation/providers/finances_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// FINANCIAL CHARTS — Dashboard visualizations for the home tab
// ═══════════════════════════════════════════════════════════════════════

// ─── Monthly Income vs Expenses (Bar Chart) ──────────────────────────

class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key});

  static const String _title = 'Ingresos vs Gastos';

  @override
  Widget build(BuildContext context) {
    final finances = context.watch<FinancesProvider>();
    final months = finances.months;

    return _ChartCard(
      title: _title,
      icon: Icons.bar_chart_rounded,
      child: months.length < 2
          ? _EmptyChartMessage(
              message: months.isEmpty
                  ? 'Aún no hay datos mensuales'
                  : 'Registra otro mes para ver la comparativa',
            )
          : SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _maxY(months),
                  minY: 0,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final m = months.length > groupIndex ? months[groupIndex] : null;
                        return BarTooltipItem(
                          '${m?.month ?? ''}\n\$${_fmt(rod.toY)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= months.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _shortMonth(months[idx].month),
                              style: const TextStyle(
                                color: AppColors.textSecondaryDark,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) return const SizedBox.shrink();
                          return Text(
                            '\$${_fmt(value)}',
                            style: const TextStyle(
                              color: AppColors.textSecondaryDark,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _maxY(months) / 4,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.borderDark.withValues(alpha: 0.4),
                      strokeWidth: 0.5,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: months.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: m.totalIncome,
                          color: AppColors.success,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: m.totalExpenses,
                          color: AppColors.error,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
                duration: const Duration(milliseconds: 400),
              ),
            ),
    );
  }

  double _maxY(List<FinancesSummaryEntity> months) {
    double max = 0;
    for (final m in months) {
      final v = m.totalIncome > m.totalExpenses ? m.totalIncome : m.totalExpenses;
      if (v > max) max = v;
    }
    return max > 0 ? max * 1.15 : 1000;
  }
}

// ─── Net Balance Trend (Line Chart) ──────────────────────────────────

class NetBalanceLineChart extends StatelessWidget {
  const NetBalanceLineChart({super.key});

  static const String _title = 'Tendencia Mensual';

  @override
  Widget build(BuildContext context) {
    final finances = context.watch<FinancesProvider>();
    final months = finances.months;

    if (months.length < 2) {
      return _ChartCard(
        title: _title,
        icon: Icons.trending_up_rounded,
        child: _EmptyChartMessage(
          message: months.isEmpty
              ? 'Aún no hay datos mensuales'
              : 'Registra otro mes para ver la tendencia',
        ),
      );
    }

    final spots = months.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.balance);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);

    return _ChartCard(
      title: _title,
      icon: Icons.trending_up_rounded,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (months.length - 1).toDouble(),
            minY: minY > 0 ? 0 : minY * 1.15,
            maxY: maxY > 0 ? maxY * 1.15 : 1000,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                  final idx = spot.spotIndex;
                  final m = idx < months.length ? months[idx] : null;
                  return LineTooltipItem(
                    '${m?.month ?? ''}\n\$${_fmt(spot.y)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= months.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _shortMonth(months[idx].month),
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                  reservedSize: 28,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(
                      '\$${_fmt(value)}',
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(
                color: AppColors.borderDark.withValues(alpha: 0.4),
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.brand,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    final isPositive = spot.y >= 0;
                    return FlDotCirclePainter(
                      radius: 4,
                      color: isPositive ? AppColors.success : AppColors.error,
                      strokeWidth: 2,
                      strokeColor: AppColors.surfaceDark,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.brand.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 400),
        ),
      ),
    );
  }
}

// ─── Category Breakdown (Pie Chart) ──────────────────────────────────

class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key});

  static const String _title = 'Gastos por Categoría';

  @override
  Widget build(BuildContext context) {
    final finances = context.watch<FinancesProvider>();
    final transactions = finances.recentTransactions.where(
      (t) => t.type == TransactionType.expense,
    );

    // Aggregate by category
    final Map<String, double> categoryTotals = {};
    for (final t in transactions) {
      final cat = t.category.isNotEmpty ? t.category : 'Sin categoría';
      categoryTotals.update(cat, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    if (categoryTotals.isEmpty) {
      return _ChartCard(
        title: _title,
        icon: Icons.pie_chart_rounded,
        child: const _EmptyChartMessage(
          message: 'Registra gastos para ver el desglose',
        ),
      );
    }

    final colors = _pieColors;
    final total = categoryTotals.values.fold(0.0, (a, b) => a + b);
    final entries = categoryTotals.entries.toList();

    return _ChartCard(
      title: _title,
      icon: Icons.pie_chart_rounded,
      child: Row(
        children: [
          SizedBox(
            height: 140,
            width: 140,
            child: PieChart(
              PieChartData(
                sections: entries.asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  final percentage = (e.value / total) * 100;
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: e.value,
                    title: '${percentage.toStringAsFixed(0)}%',
                    radius: 42,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  );
                }).toList(),
                centerSpaceRadius: 24,
                sectionsSpace: 2,
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: entries.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                final pct = (e.value / total) * 100;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            color: AppColors.textSecondaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppColors.textPrimaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: AppRadius.xxlBorder,
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.brand, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _EmptyChartMessage extends StatelessWidget {
  const _EmptyChartMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────

String _fmt(double v) =>
    v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);

String _shortMonth(String month) {
  // month is like "Marzo 2025" → "Mar"
  final parts = month.split(' ');
  final name = parts.isNotEmpty ? parts[0] : month;
  if (name.length <= 3) return name;
  return name.substring(0, 3);
}

const List<Color> _pieColors = [
  Color(0xFF006B5F),
  Color(0xFFFF735C),
  Color(0xFF3B82F6),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFF10B981),
  Color(0xFFEF4444),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
  Color(0xFF6366F1),
];
