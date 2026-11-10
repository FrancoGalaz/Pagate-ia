// Widget test de FinanzasTab, sin Firebase.
//
// Especificación: docs/DISENO-v2.md, paso 6.5.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/utils/currency_formatter.dart';
import 'package:pagate_ia/core/utils/month_labels.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/dashboard/presentation/widgets/financial_charts.dart';
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
  void selectMonthKey(final String monthKey) {
    selectedMonthKey = monthKey;
    notifyListeners();
  }

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

/// `'2026-11'` → `'2026-10'`, a partir de hoy: los tests del selector no
/// pueden fijar el mes en curso.
String _mesAnterior(final String mes) {
  final partes = mes.split('-');
  return monthKeyFromDate(
    DateTime(int.parse(partes[0]), int.parse(partes[1]) - 1),
  );
}

/// Desplaza la lista hasta [texto]: los gastos fijos van al final.
Future<void> _bajarHasta(final WidgetTester tester, final String texto) async {
  await tester.scrollUntilVisible(
    find.text(texto),
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

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
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Ingresos'), findsOneWidget);
    expect(find.text(r'+$1.240.000'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text(r'−$860.000'), findsOneWidget);
    // La meta dice qué mide, y sin tope.
    expect(find.text('248 %'), findsOneWidget);
    expect(
      find.text(r'Ingresos sobre la meta de $500.000'),
      findsOneWidget,
    );
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

  testWidgets('deslizar un movimiento pide confirmación, en carmesí', (
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

    // El diálogo de confirmación de toda la app: Cancelar / Eliminar, con
    // el botón destructivo en carmesí.
    expect(find.text('Eliminar movimiento'), findsOneWidget);
    final eliminar = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Eliminar').last,
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(
      eliminar.style!.backgroundColor!.resolve(<WidgetState>{}),
      AppPalette.danger,
    );

    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(finanzas.borrados, ['tx-Greda 25 kg']);
  });

  testWidgets('el gasto fijo se agrega en una hoja con validación', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());

    await _bajarHasta(tester, 'Agregar');
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

    await _bajarHasta(tester, 'Comprometido cada mes');
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
    await _bajarHasta(tester, 'Sin gastos fijos');
    expect(find.text('Sin gastos fijos'), findsOneWidget);
  });

  // ─── Selector de período: uno solo ────────────────────────────────────

  group('el período', () {
    final actual = FinancesProvider.currentMonthKey;
    final anterior = _mesAnterior(actual);
    final antiguo = _mesAnterior(anterior);
    final anio = actual.split('-').first;

    _FinanzasFalsas tresMeses() => _FinanzasFalsas(
          months: [
            FinancesSummaryEntity(
              monthKey: actual,
              totalIncome: 300000,
              totalExpenses: 100000,
              transactionCount: 4,
            ),
            FinancesSummaryEntity(
              monthKey: anterior,
              totalIncome: 200000,
              totalExpenses: 50000,
              transactionCount: 2,
            ),
            FinancesSummaryEntity(
              monthKey: antiguo,
              totalIncome: 100000,
              totalExpenses: 20000,
              transactionCount: 1,
            ),
          ],
        )..selectedMonthKey = actual;

    testWidgets('se elige en un solo selector de cuatro opciones', (
      final tester,
    ) async {
      final finanzas = tresMeses();
      await _montar(tester, finanzas);

      expect(find.byType(PagateMonthSelector), findsNothing);
      for (final opcion in ['Este mes', 'Mes pasado', 'Año', 'Otro mes']) {
        expect(find.text(opcion), findsOneWidget, reason: opcion);
      }

      await tester.tap(find.text('Mes pasado'));
      await tester.pumpAndSettle();
      expect(finanzas.selectedMonthKey, anterior);
      expect(find.text(r'+$200.000'), findsOneWidget);

      await tester.tap(find.text('Este mes'));
      await tester.pumpAndSettle();
      expect(finanzas.selectedMonthKey, actual);
    });

    testWidgets('«Otro mes» abre la lista de meses', (final tester) async {
      final finanzas = tresMeses();
      await _montar(tester, finanzas);

      await tester.tap(find.text('Otro mes'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir mes'), findsOneWidget);

      await tester.tap(find.text(monthLabelFromMonthKey(antiguo)).last);
      await tester.pumpAndSettle();
      expect(finanzas.selectedMonthKey, antiguo);
      expect(find.text(r'+$100.000'), findsOneWidget);

      // Ya elegido, tocarlo otra vez vuelve a abrir la lista.
      await tester.tap(find.text('Otro mes'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir mes'), findsOneWidget);
    });

    testWidgets('el gráfico del año muestra solo los meses de ese año', (
      final tester,
    ) async {
      final otroAnio = '${int.parse(anio) - 1}-06';
      final finanzas = tresMeses()
        ..months = [
          ...tresMeses().months,
          FinancesSummaryEntity(
            monthKey: otroAnio,
            totalIncome: 50000,
            totalExpenses: 10000,
            transactionCount: 1,
          ),
        ];
      await _montar(tester, finanzas);

      await tester.tap(find.text('Año'));
      await tester.pumpAndSettle();
      await _bajarHasta(tester, 'Ingresos y gastos por mes');

      final delAnio = finanzas.months
          .where((final m) => m.monthKey.startsWith('$anio-'))
          .length;
      final datos = tester.widget<BarChart>(find.byType(BarChart)).data;
      expect(datos.barGroups, hasLength(delAnio));
    });

    testWidgets('en «Año» el balance va a todo el ancho', (
      final tester,
    ) async {
      await _montar(tester, tresMeses());
      await tester.tap(find.text('Año'));
      await tester.pumpAndSettle();

      final balance = find.ancestor(
        of: find.text('Balance'),
        matching: find.byType(PagateMetricCard),
      );
      expect(tester.getSize(balance).width, 360 - 2 * AppSpacing.x4);
    });

    testWidgets('«Año» suma los meses del año y lista cada uno', (
      final tester,
    ) async {
      final finanzas = tresMeses();
      await _montar(tester, finanzas);

      await tester.tap(find.text('Año'));
      await tester.pumpAndSettle();

      // Solo los meses de este año: en enero, el anterior es de otro.
      final delAnio = finanzas.months
          .where((final m) => m.monthKey.startsWith('$anio-'))
          .toList();
      final ingresos = delAnio.fold<double>(
        0,
        (final a, final m) => a + m.totalIncome,
      );
      expect(
        find.text(formatSigned(ingresos, currency: kFallbackCurrency)),
        findsOneWidget,
      );
      expect(find.text('Año $anio'), findsOneWidget);
      // La meta es mensual: en el año no se muestra.
      expect(find.textContaining('sobre la meta'), findsNothing);
      expect(find.text('Movimientos del mes'), findsNothing);

      await _bajarHasta(tester, 'Meses de $anio');
      final mes = find.text(monthLabelFromMonthKey(actual));
      await tester.scrollUntilVisible(
        mes,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(mes);
      await tester.pumpAndSettle();

      // Tocar un mes lo abre.
      expect(finanzas.selectedMonthKey, actual);
      expect(find.text('Meses de $anio'), findsNothing);
    });
  });

  testWidgets('el gráfico de barras parte en \$0 y lo rotula', (
    final tester,
  ) async {
    final finanzas = _conDatos()
      ..months = const [
        FinancesSummaryEntity(
          monthKey: '2026-10',
          totalIncome: 1240000,
          totalExpenses: 860000,
          transactionCount: 2,
        ),
        FinancesSummaryEntity(
          monthKey: '2026-09',
          totalIncome: 900000,
          totalExpenses: 700000,
          transactionCount: 2,
        ),
      ];
    await _montar(tester, finanzas);
    await _bajarHasta(tester, 'Ingresos y gastos por mes');

    final datos = tester.widget<BarChart>(find.byType(BarChart)).data;
    expect(datos.minY, 0);
    // Pasos redondos: de 500 mil en 500 mil hasta 1,5 millones.
    expect(datos.titlesData.leftTitles.sideTitles.interval, 500000);
    expect(datos.maxY, 1500000);
    expect(
      find.descendant(
        of: find.byType(BarChart),
        matching: find.text(r'$0'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('el eje dice «oct», y el año solo si es otro', (
    final tester,
  ) async {
    final finanzas = _conDatos()
      ..months = const [
        FinancesSummaryEntity(
          monthKey: '2026-10',
          totalIncome: 1240000,
          totalExpenses: 860000,
          transactionCount: 2,
        ),
        FinancesSummaryEntity(
          monthKey: '2026-09',
          totalIncome: 900000,
          totalExpenses: 700000,
          transactionCount: 2,
        ),
        FinancesSummaryEntity(
          monthKey: '2025-12',
          totalIncome: 500000,
          totalExpenses: 300000,
          transactionCount: 2,
        ),
      ];
    await _montar(tester, finanzas);
    await _bajarHasta(tester, 'Ingresos y gastos por mes');

    Finder enElEje(final String texto) =>
        find.descendant(of: find.byType(BarChart), matching: find.text(texto));
    expect(enElEje('oct'), findsOneWidget);
    expect(enElEje('sep'), findsOneWidget);
    expect(enElEje('oct 26'), findsNothing);
    // Un mes de otro año lleva el suyo: dos diciembres no se confunden.
    expect(enElEje('dic 25'), findsOneWidget);
  });

  testWidgets('las barras de categoría van en el oscuro', (
    final tester,
  ) async {
    await _montar(tester, _conDatos());
    await _bajarHasta(tester, 'Insumos y materiales');

    final barra = tester.widget<LinearProgressIndicator>(
      find.descendant(
        of: find.byType(CategoryBars),
        matching: find.byType(LinearProgressIndicator),
      ),
    );
    expect(barra.color, AppPalette.ink);
  });

  testWidgets('con letra 1,5 o más el selector se desplaza con la lista', (
    final tester,
  ) async {
    Finder enLaLista() => find.ancestor(
      of: find.text('Mes pasado'),
      matching: find.byType(ListView),
    );

    await _montar(tester, _conDatos());
    expect(enLaLista(), findsNothing, reason: 'en 1,0 va fijo');

    await _montar(tester, _conDatos(), textScale: 1.5);
    expect(enLaLista(), findsOneWidget);
  });

  testWidgets('con letra 2,0 ninguna palabra se parte ni se corta', (
    final tester,
  ) async {
    final finanzas = _conDatos()
      ..months = const [
        FinancesSummaryEntity(
          monthKey: '2026-10',
          totalIncome: 1240000,
          totalExpenses: 860000,
          transactionCount: 2,
        ),
        FinancesSummaryEntity(
          monthKey: '2026-09',
          totalIncome: 900000,
          totalExpenses: 700000,
          transactionCount: 2,
        ),
      ];
    await _montar(tester, finanzas, textScale: 2.0);

    // El ancho mínimo de un párrafo es el de su palabra más larga: si no
    // cabe, la palabra se parte («Ingres / os») o se corta («pasad»).
    void palabrasEnteras(final String texto) {
      final parrafo = tester.renderObject<RenderParagraph>(find.text(texto));
      expect(
        parrafo.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(parrafo.size.width + 0.5),
        reason: texto,
      );
    }

    palabrasEnteras('Mes pasado');
    await _bajarHasta(tester, 'Ingresos y gastos por mes');
    palabrasEnteras('Ingresos y gastos por mes');

    // La categoría, entera en su línea: sin «Insumos y …».
    await _bajarHasta(tester, 'Insumos y materiales');
    expect(
      tester.widget<Text>(find.text('Insumos y materiales')).maxLines,
      isNull,
    );
  });

  testWidgets('no desborda a 1,3x ni a 2,0x', (final tester) async {
    await _montar(tester, _conDatos(), textScale: 1.3);
    expect(tester.takeException(), isNull);

    await _montar(tester, _conDatos(), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });
}
