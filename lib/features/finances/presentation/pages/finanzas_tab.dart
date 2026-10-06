import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/pdf_report_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/month_labels.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../dashboard/presentation/widgets/financial_charts.dart';
import '../../domain/entities/finances_transaction_entity.dart';
import '../../domain/entities/fixed_expense_entity.dart';
import '../providers/finances_provider.dart';
import '../widgets/transaction_form_sheet.dart';

// ═══════════════════════════════════════════════════════════════════════
// PANTALLA DE FINANZAS
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 6.5.
//
// Reutiliza el 80% de lo que dejó montado Inicio: el selector de mes, la
// fila de dato, la fila de movimiento, el esqueleto y el formateador. Y
// aquí llegan los gráficos que salieron de la portada, con el donut
// sustituido por barras de categoría.
//
// QUÉ SE BORRÓ Y POR QUÉ:
//
// · EL `FloatingActionButton.extended`. Flotaba con sombra propia, tapaba
//   la última fila de la lista —no hay padding inferior que lo compense— y,
//   cuando se deshabilitaba por un error del stream, SEGUÍA VIÉNDOSE verde
//   y blanco, porque `backgroundColor` y `foregroundColor` estaban fijados
//   explícitamente en el widget y ganan sobre el estado deshabilitado del
//   tema. Un botón que parece activo y no responde es peor que uno apagado.
//   Ahora es una `PagateActionBar` al pie.
//
// · LOS CUATRO `AlertDialog`. Dos problemas, uno de forma y otro de datos:
//   el `elevatedButtonTheme` impone `minimumSize: Size(infinity, 48)`, lo
//   que dentro del `OverflowBar` de un diálogo apila los botones a ancho
//   completo y descoloca la jerarquía Cancelar / Eliminar; y el diálogo de
//   gasto fijo cerraba con `Navigator.pop(dialogContext, true)` PASE LO QUE
//   PASE y liberaba los controllers justo después, así que ante un error el
//   usuario perdía todo lo escrito. Ahora son hojas con `Form` y
//   validación.
//
// · LOS TRES CÍRCULOS DE ICONO TEÑIDOS de las filas (resumen, gasto fijo y
//   movimiento), que robaban ~48 dp de ancho al nombre y duplicaban lo que
//   el signo ya dice.
//
// · EL BORDE EN CADA CHIP NO SELECCIONADO del selector de mes, que
//   convertía la fila en una reja. Ahora es `PagateMonthSelector`, que
//   además garantiza un chip del mes en curso: con datos hasta agosto y el
//   mes actual sin movimientos, la pantalla abría en agosto sin forma de
//   volver.
//
// · "Meta Mensual" y "Gastos Fijos" en Title Case inglés.
//
// Y EL `Dismissible` GANA `onDismissed`, que no tenía: dependía de que el
// stream de Firestore reemitiera antes de que terminara la animación. Eso y
// la acción semántica de borrado los trae ya `PagateMovementRow`.
// ═══════════════════════════════════════════════════════════════════════

class FinanzasTab extends StatelessWidget {
  const FinanzasTab({super.key});

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<FinancesProvider>();

    return Column(
      children: [
        const _Cabecera(),
        Expanded(
          child: provider.error != null
              ? _CuerpoConError(provider: provider)
              : const _Cuerpo(),
        ),

        // Barra fija, no FAB: no tapa la última fila y se apaga de verdad
        // cuando no hay nada que registrar.
        PagateActionBar(
          child: PagatePrimaryButton(
            label: 'Registrar movimiento',
            onPressed: provider.error != null
                ? null
                : () => showTransactionSheet(context),
          ),
        ),
      ],
    );
  }
}

// ─── Cabecera: título, exportar y selector de mes ──────────────────────

class _Cabecera extends StatefulWidget {
  const _Cabecera();

  @override
  State<_Cabecera> createState() => _CabeceraState();
}

class _CabeceraState extends State<_Cabecera> {
  bool _exportando = false;

  Future<void> _exportar() async {
    final provider = context.read<FinancesProvider>();
    final summary = provider.summary;

    setState(() => _exportando = true);
    try {
      final pdf = await PdfReportService.generateReport(
        summary: summary,
        transactions: provider.transactions,
        fixedExpenses: provider.fixedExpenses,
        monthlyGoal: provider.monthlyGoal,
      );
      await PdfReportService.share(pdfBytes: pdf, month: summary.month);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'No se pudo exportar el informe: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<FinancesProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x2,
            AppSpacing.x1,
            AppSpacing.x2,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Expanded(
                  child: Text('Finanzas', style: theme.textTheme.headlineMedium),
                ),
                if (_exportando)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.x3),
                    child: SizedBox(
                      width: AppIconSize.sm,
                      height: AppIconSize.sm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    tooltip: 'Exportar informe en PDF',
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed:
                        provider.error == null ? () => unawaited(_exportar()) : null,
                  ),
              ],
            ),
          ),
        ),
        PagateMonthSelector(
          monthKeys: [for (final m in provider.months) m.monthKey],
          selectedMonthKey: provider.selectedMonthKey,
          currentMonthKey: FinancesProvider.currentMonthKey,
          onSelected: provider.selectMonthKey,
        ),
      ],
    );
  }
}

// ─── Cuerpo ────────────────────────────────────────────────────────────

class _CuerpoConError extends StatelessWidget {
  const _CuerpoConError({required this.provider});

  final FinancesProvider provider;

  @override
  Widget build(final BuildContext context) => ListView(
        padding: const EdgeInsets.only(top: AppSpacing.x6),
        children: [
          PagateErrorState(
            message: provider.error!,
            onRetry: provider.retry,
          ),
        ],
      );
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<FinancesProvider>();

    if (provider.isLoading) {
      return ListView(
        children: [
          PagateSkeleton.balance(),
          PagateSkeleton.rows(4),
        ],
      );
    }

    final summary = provider.summary;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.x8),
      children: [
        // La cifra dominante de esta pantalla: el balance del mes.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x6,
            AppSpacing.x4,
            AppSpacing.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance de ${monthLabelFromMonthKey(summary.monthKey)}'
                    .toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppPalette.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                formatCurrency(summary.balance, currency: kFallbackCurrency),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: summary.balance < 0
                          ? AppPalette.moneyOut
                          : AppPalette.textPrimary,
                    ),
              ),
            ],
          ),
        ),

        PagateSectionCard(
          child: Column(
            children: [
              PagateDataRow(
                label: 'Ingresos',
                value: formatCurrency(
                  summary.totalIncome,
                  currency: kFallbackCurrency,
                ),
              ),
              PagateDataRow(
                label: 'Gastos',
                value: formatSigned(
                  -summary.totalExpenses,
                  currency: kFallbackCurrency,
                ),
                showDivider: false,
              ),
            ],
          ),
        ),

        if (provider.monthlyGoal > 0) const _Meta(),

        const _GastosFijos(),
        const _Movimientos(),

        const SizedBox(height: AppSpacing.x6),
        const PagateSectionCard(child: MonthlyBarChart()),
        const SizedBox(height: AppSpacing.x6),
        const PagateSectionCard(child: NetBalanceLineChart()),
        const SizedBox(height: AppSpacing.x6),
        const PagateSectionCard(child: CategoryBars()),
      ],
    );
  }
}

// ─── Meta del mes ──────────────────────────────────────────────────────

class _Meta extends StatelessWidget {
  const _Meta();

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<FinancesProvider>();
    final progreso = provider.goalProgress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x6,
        AppSpacing.x4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Meta del mes '
                  '${formatCurrency(
                    provider.monthlyGoal,
                    currency: kFallbackCurrency,
                  )}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
              Text(
                '${(progreso * 100).round()} %',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppPalette.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          ClipRRect(
            borderRadius: AppRadius.r4Border,
            child: LinearProgressIndicator(value: progreso),
          ),
        ],
      ),
    );
  }
}

// ─── Gastos fijos ──────────────────────────────────────────────────────

class _GastosFijos extends StatelessWidget {
  const _GastosFijos();

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<FinancesProvider>();
    final gastos = provider.fixedExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PagateSectionHeader(
          title: 'Gastos fijos',
          actionLabel: 'Agregar',
          onAction: () => unawaited(_agregar(context)),
        ),
        PagateSectionCard(
          child: gastos.isEmpty
              ? PagateEmptyState(
                  title: 'Sin gastos fijos',
                  description: 'Agrega el arriendo del taller, la luz o el '
                      'internet: lo que pagas todos los meses.',
                  actionLabel: 'Agregar gasto fijo',
                  onAction: () => unawaited(_agregar(context)),
                )
              : Column(
                  children: [
                    for (final gasto in gastos)
                      PagateDataRow(
                        label: gasto.name,
                        // SIN signo menos. Coherencia con Inicio: el menos
                        // de una fila significa "ya se restó del balance", y
                        // un gasto fijo no se resta (el balance lo calcula
                        // el backend desde las transacciones). El signo era
                        // lo que hacía que la suma de la portada no cuadrara.
                        value: formatCurrency(
                          gasto.amount,
                          currency: kFallbackCurrency,
                        ),
                        // Un chevron dice "esto navega". Borrar no navega,
                        // así que la acción va en un control propio con su
                        // etiqueta, alcanzable también con lector de
                        // pantalla.
                        trailing: IconButton(
                          tooltip: 'Eliminar ${gasto.name}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => unawaited(_eliminar(context, gasto)),
                        ),
                      ),
                    PagateDataRow(
                      label: 'Comprometido cada mes',
                      value: formatCurrency(
                        provider.totalFixedExpenses,
                        currency: kFallbackCurrency,
                      ),
                      showDivider: false,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        AppSpacing.x0,
                        AppSpacing.x4,
                        AppSpacing.x3,
                      ),
                      child: Text(
                        'Referencia de lo que pagas todos los meses. No se '
                        'resta del balance: cada pago entra cuando lo '
                        'registras como gasto.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppPalette.textMuted),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Hoja con formulario, no `AlertDialog`.
  ///
  /// El diálogo anterior cerraba con `Navigator.pop(dialogContext, true)`
  /// pase lo que pase y liberaba los controllers acto seguido, así que un
  /// error de red o de permisos borraba lo que el usuario había escrito.
  Future<void> _agregar(final BuildContext context) async {
    final provider = context.read<FinancesProvider>();
    final guardado = await showPagateSheet<bool>(
      context: context,
      builder: (final _) => _HojaGastoFijo(provider: provider),
    );
    if (guardado != true || !context.mounted) return;
    AppFeedback.showMessage(context, 'Gasto fijo agregado.');
  }

  Future<void> _eliminar(
    final BuildContext context,
    final FixedExpenseEntity gasto,
  ) async {
    final provider = context.read<FinancesProvider>();
    final confirmado = await _confirmar(
      context,
      title: 'Eliminar gasto fijo',
      message: '¿Eliminar "${gasto.name}"? Dejará de descontarse cada mes.',
    );
    if (!confirmado || !context.mounted) return;

    try {
      await provider.deleteFixedExpense(gasto.id);
    } catch (e) {
      if (!context.mounted) return;
      // Aquí no hay hoja abierta (la de confirmación ya se cerró), pero
      // el aviso va igual por el overlay raíz: `showError` se ve encima de
      // cualquier cosa.
      AppFeedback.showError(
        context,
        FinancesProvider.describeError(e, operation: DataOperation.delete),
      );
    }
  }
}

/// Formulario de gasto fijo. Valida antes de cerrar y conserva lo escrito
/// si el guardado falla.
class _HojaGastoFijo extends StatefulWidget {
  const _HojaGastoFijo({required this.provider});

  final FinancesProvider provider;

  @override
  State<_HojaGastoFijo> createState() => _HojaGastoFijoState();
}

class _HojaGastoFijoState extends State<_HojaGastoFijo> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _monto = TextEditingController();
  bool _guardando = false;

  /// Mensaje del último guardado fallido. Se pinta DENTRO de la hoja: un
  /// aviso tapado por la propia hoja era lo que hacía que el botón pareciera
  /// no responder.
  String? _errorGuardado;

  @override
  void dispose() {
    _nombre.dispose();
    _monto.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });
    try {
      await widget.provider.addFixedExpense(
        name: _nombre.text.trim(),
        // `parseCurrencyInput` y no `double.tryParse`: con el segundo,
        // "50.000" se guardaba como CINCUENTA.
        amount: parseCurrencyInput(_monto.text)!,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = FinancesProvider.describeError(
          e,
          operation: DataOperation.write,
        );
      });
    }
  }

  @override
  Widget build(final BuildContext context) => PagateSheet(
        title: 'Nuevo gasto fijo',
        primaryAction: PagatePrimaryButton(
          label: 'Guardar',
          isLoading: _guardando,
          onPressed: _guardar,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PagateTextField(
                labelText: 'Nombre',
                hintText: 'Arriendo del taller',
                controller: _nombre,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (final v) => (v == null || v.trim().isEmpty)
                    ? 'Escribe un nombre'
                    : null,
              ),
              const SizedBox(height: AppSpacing.x4),
              PagateTextField.amount(
                labelText: 'Monto mensual',
                hintText: '0',
                controller: _monto,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (final _) => unawaited(_guardar()),
                validator: (final v) {
                  final monto = parseCurrencyInput(v ?? '');
                  if (monto == null) return 'Escribe un monto válido';
                  if (monto <= 0) return 'El monto debe ser mayor que cero';
                  return null;
                },
              ),
              if (_errorGuardado != null) ...[
                const SizedBox(height: AppSpacing.x4),
                PagateInlineError(message: _errorGuardado),
              ],
            ],
          ),
        ),
      );
}

// ─── Movimientos del mes ───────────────────────────────────────────────

class _Movimientos extends StatelessWidget {
  const _Movimientos();

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<FinancesProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PagateSectionHeader(title: 'Movimientos del mes'),
        PagateSectionCard(
          child: provider.isLoadingTransactions
              ? PagateSkeleton.rows(4)
              : provider.transactions.isEmpty
                  ? PagateEmptyState(
                      title: 'Sin movimientos este mes',
                      description: 'Registra tu primera venta o tu primer '
                          'gasto del mes.',
                      actionLabel: 'Registrar movimiento',
                      onAction: () => showTransactionSheet(context),
                    )
                  : Column(
                      children: [
                        for (final tx in provider.transactions)
                          PagateMovementRow(
                            title: tx.title,
                            meta: '${formatDayMonth(tx.date)} · ${tx.category}',
                            amount: formatSigned(
                              tx.isIncome ? tx.amount : -tx.amount,
                              currency: kFallbackCurrency,
                            ),
                            isIncome: tx.isIncome,
                            dismissKey: tx.id,
                            onConfirmDelete: () => _confirmarBorrado(
                              context,
                              provider,
                              tx,
                            ),
                            onDeleted: () {},
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  Future<bool> _confirmarBorrado(
    final BuildContext context,
    final FinancesProvider provider,
    final FinancesTransactionEntity tx,
  ) async {
    final confirmado = await _confirmar(
      context,
      title: 'Eliminar movimiento',
      message: '¿Eliminar "${tx.title}"?',
    );
    if (!confirmado) return false;

    try {
      await provider.deleteTransaction(tx.id);
      return true;
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(
          context,
          FinancesProvider.describeError(e, operation: DataOperation.delete),
        );
      }
      return false;
    }
  }
}

// ─── Confirmación destructiva ──────────────────────────────────────────

/// Hoja de confirmación.
///
/// Sustituye a los `AlertDialog`: el `elevatedButtonTheme` impone
/// `minimumSize: Size(infinity, 48)`, y dentro del `OverflowBar` de un
/// diálogo eso apila los botones a ancho completo y descoloca la jerarquía
/// Cancelar / Eliminar. En la hoja el orden es explícito.
Future<bool> _confirmar(
  final BuildContext context, {
  required final String title,
  required final String message,
}) async {
  final resultado = await showPagateSheet<bool>(
    context: context,
    builder: (final sheetContext) => PagateSheet(
      title: title,
      primaryAction: PagatePrimaryButton.secondary(
        label: 'Cancelar',
        onPressed: () => Navigator.of(sheetContext).pop(false),
      ),
      secondaryAction: PagatePrimaryButton(
        label: 'Eliminar',
        onPressed: () => Navigator.of(sheetContext).pop(true),
      ),
      child: Text(
        message,
        style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
              color: AppPalette.textSecondary,
            ),
      ),
    ),
  );
  return resultado ?? false;
}
