// Widget test de FinanzasTab, sin Firebase.
//
// Especificación: docs/DISENO-v2.md, paso 6.5.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/finances/presentation/pages/finanzas_tab.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';

class _FinanzasFalsas extends ChangeNotifier implements FinancesProvider {
  _FinanzasFalsas({
    this.months = const [],
    this.transactions = const [],
    this.fixedExpenses = const [],
    this.error,
    this.isLoading = false,
    this.isLoadingTransactions = false,
    this.monthlyGoal = 0,
  });

  @override
  List<FinancesSummaryEntity> months;
  @override
  List<FinancesTransactionEntity> transactions;
  @override
  List<FixedExpenseEntity> fixedExpenses;
  @override
  String? error;
  @override
  bool isLoading;
  @override
  bool isLoadingTransactions;
  @override
  double monthlyGoal;
  @override
  String selectedMonthKey = '2026-10';

  final List<String> borrados = [];
  int reintentos = 0;

  @override
  double get totalFixedExpenses =>
      fixedExpenses.fold(0, (final a, final b) => a + b.amount);

  @override
  FinancesSummaryEntity get summary {
    for (final m in months) {
      if (m.monthKey == selectedMonthKey) return m;
    }
    return FinancesSummaryEntity(
      monthKey: selectedMonthKey,
      totalIncome: 0,
      totalExpenses: 0,
      transactionCount: 0,
    );
  }

  @override
  double get goalProgress => summary.goalProgress(monthlyGoal);

  @override
  void selectMonthKey(final String monthKey) => selectedMonthKey = monthKey;

  @override
  void retry() => reintentos++;

  @override
  Future<void> deleteTransaction(final String id) async => borrados.add(id);

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

FinancesTransactionEntity _tx({
  required final String title,
  required final double amount,
  required final bool ingreso,
  required final String categoria,
}) =>
    FinancesTransactionEntity(
      id: 'tx-$title',
      title: title,
      description: '',
      amount: amount,
      type: ingreso ? TransactionType.income : TransactionType.expense,
      date: DateTime(2026, 10, 12),
      category: categoria,
    );

Future<void> _montar(
  final WidgetTester tester,
  final _FinanzasFalsas finanzas, {
  final double textScale = 1.0,
}) async {
  tester.view
    ..physicalSize = const Size(360, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 900),
        textScaler: TextScaler.linear(textScale),
      ),
      child: ChangeNotifierProvider<FinancesProvider>.value(
        value: finanzas,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: FinanzasTab()),
        ),
      ),
    ),
  );
  await tester.pump();
}

_FinanzasFalsas _conDatos() => _FinanzasFalsas(
      months: const [
        FinancesSummaryEntity(
          monthKey: '2026-10',
          totalIncome: 1240000,
          totalExpenses: 860000,
          transactionCount: 2,
        ),
      ],
      transactions: [
        _tx(
          title: 'Venta feria Lastarria',
          amount: 120000,
          ingreso: true,
          categoria: 'Venta en feria',
        ),
        _tx(
          title: 'Greda 25 kg',
          amount: 35000,
          ingreso: false,
          categoria: 'Insumos y materiales',
        ),
      ],
      fixedExpenses: const [
        FixedExpenseEntity(id: 'fx1', name: 'Arriendo', amount: 320000),
      ],
      monthlyGoal: 500000,
    );

void main() {
  testWidgets('la acción principal es una barra fija, no un FAB flotante', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());

    // El FAB tapaba la última fila de la lista y, al deshabilitarse por un
    // error del stream, seguía viéndose verde y blanco.
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(PagateActionBar), findsOneWidget);
    expect(find.text('Registrar movimiento'), findsWidgets);
  });

  testWidgets('con error, la acción se apaga de verdad', (final tester) async {
    final finanzas = _FinanzasFalsas(error: 'Sin permiso para leer esto.');
    await _montar(tester, finanzas);

    final boton = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byType(PagateActionBar),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(boton.onPressed, isNull);

    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(PagateActionBar),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, AppPalette.sunken);
  });

  testWidgets('un fallo muestra el mensaje del servidor y reintenta', (
    final tester,
  ) async {
    final finanzas = _FinanzasFalsas(error: 'Sin permiso para leer esto.');
    await _montar(tester, finanzas);

    expect(find.text('Sin permiso para leer esto.'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(finanzas.reintentos, 1);
  });

  testWidgets('el balance es la cifra dominante y el resumen lo explica', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());

    expect(find.text(r'$380.000'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
    expect(find.text(r'$1.240.000'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text(r'−$860.000'), findsOneWidget);
  });

  testWidgets('los movimientos van con su signo y sin círculo de icono', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());

    expect(find.text('Venta feria Lastarria'), findsOneWidget);
    expect(find.text('12 oct · Venta en feria'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(r'+$120.000')).style!.color,
      AppPalette.moneyIn,
    );
    expect(
      tester.widget<Text>(find.text(r'−$35.000')).style!.color,
      AppPalette.textPrimary,
    );
  });

  testWidgets('deslizar un movimiento pide confirmación en una hoja', (
    final tester,
  ) async {
    final finanzas = _conDatos();
    await _montar(tester, finanzas);

    // La fila queda bajo la barra de acción fija, así que primero se
    // desplaza la lista: si no, el gesto cae sobre el botón.
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Greda 25 kg'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // Los cuatro AlertDialog desaparecen: el elevatedButtonTheme impone
    // minimumSize infinito y dentro del OverflowBar de un diálogo eso apila
    // los botones a ancho completo y descoloca Cancelar / Eliminar.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Eliminar movimiento'), findsOneWidget);

    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(finanzas.borrados, ['tx-Greda 25 kg']);
  });

  testWidgets('el gasto fijo se agrega en una hoja con validación', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo gasto fijo'), findsOneWidget);

    // El diálogo anterior cerraba con pop(true) PASE LO QUE PASE y liberaba
    // los controllers acto seguido: un error borraba lo escrito.
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.text('Escribe un nombre'), findsOneWidget);
    expect(find.text('Escribe un monto válido'), findsOneWidget);
    expect(find.text('Nuevo gasto fijo'), findsOneWidget);
  });

  testWidgets('los gastos fijos muestran lo comprometido, sin signo', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());

    expect(find.text('Gastos fijos'), findsOneWidget);
    expect(find.text('Arriendo'), findsOneWidget);
    expect(find.text('Comprometido cada mes'), findsOneWidget);

    // SIN signo menos, igual que en Inicio: un menos dice "ya se restó del
    // balance", y el balance lo calcula el backend desde las transacciones,
    // así que un gasto fijo no está restado en ninguna parte. El signo era
    // lo que hacía que la portada no cuadrara.
    expect(find.text(r'−$320.000'), findsNothing);
    expect(find.text(r'$320.000'), findsNWidgets(2));
    expect(find.textContaining('No se resta del balance'), findsOneWidget);
  });

  testWidgets('no queda Title Case inglés ni el donut de diez colores', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());

    for (final viejo in [
      'Meta Mensual',
      'Gastos Fijos',
      'Ingresos vs Gastos',
      'Tendencia Mensual',
      'Gastos por Categoría',
    ]) {
      expect(find.text(viejo), findsNothing, reason: viejo);
    }
  });

  testWidgets('las categorías son barras con etiqueta, monto y porcentaje', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());

    await tester.scrollUntilVisible(
      find.text('En qué se te va el mes'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Insumos y materiales'), findsOneWidget);
    expect(find.text('100 %'), findsOneWidget);
  });

  testWidgets('mientras carga se pinta el esqueleto, no un spinner', (
    final tester,
  ) async {
    await _montar(
      tester,
      _FinanzasFalsas(isLoading: true, isLoadingTransactions: true),
    );

    expect(find.byType(PagateSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('sin movimientos el estado vacío dice qué hacer', (
    final tester,
  ) async {
    await _montar(tester, _FinanzasFalsas());

    expect(find.text('Sin movimientos este mes'), findsOneWidget);
    expect(find.text('Sin gastos fijos'), findsOneWidget);
  });

  testWidgets('no desborda a 1,3x ni a 2,0x', (final tester) async {
    await _montar(tester, _conDatos(), textScale: 1.3);
    expect(tester.takeException(), isNull);

    await _montar(tester, _conDatos(), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });
}
