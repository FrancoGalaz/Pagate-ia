// PROPÓSITO
// ---------
// Widget test del formulario de movimientos, sin Firebase: un repositorio
// falso recoge lo que se guarda. Comprueba lo que exige el contrato C-3 en el
// cliente: los dos campos nuevos solo existen en un INGRESO, la comisión es
// opcional, no puede superar el monto, y lo que el usuario eligió llega tal
// cual a la capa de datos.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/finances/domain/repositories/finances_repository.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';
import 'package:pagate_ia/features/finances/presentation/widgets/transaction_form_sheet.dart';

/// Repositorio falso: solo guarda lo que le mandan.
class FakeRepository implements FinancesRepository {
  final List<FinancesTransactionEntity> added = [];

  @override
  Stream<List<FinancesSummaryEntity>> watchMonths() => const Stream.empty();

  @override
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) =>
      const Stream.empty();

  @override
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() =>
      const Stream.empty();

  @override
  Future<void> addTransaction(
    final FinancesTransactionEntity transaction,
  ) async {
    added.add(transaction);
  }

  @override
  Future<void> updateTransaction(
    final FinancesTransactionEntity transaction,
  ) async {}

  @override
  Future<void> deleteTransaction(final String transactionId) async {}

  @override
  Future<void> addFixedExpense({
    required final String name,
    required final double amount,
  }) async {}

  @override
  Future<void> deleteFixedExpense(final String id) async {}
}

void main() {
  late FakeRepository repository;
  late FinancesProvider provider;

  setUp(() {
    repository = FakeRepository();
    provider = FinancesProvider(repository: repository);
  });

  tearDown(() => provider.dispose());

  Future<void> montar(
    final WidgetTester tester, {
    final TransactionType tipo = TransactionType.income,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChangeNotifierProvider<FinancesProvider>.value(
          value: provider,
          child: Scaffold(
            body: TransactionFormSheet(initialType: tipo),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Escribe en el campo que está debajo de una etiqueta dada.
  Future<void> escribir(
    final WidgetTester tester,
    final String etiqueta,
    final String texto,
  ) async {
    final campo = find.descendant(
      of: find.byType(Form),
      matching: find.byType(TextFormField),
    );
    final indices = {
      'titulo': 0,
      'monto': 1,
      'comision': 2,
    };
    await tester.enterText(campo.at(indices[etiqueta]!), texto);
    await tester.pump();
  }

  /// Pulsa el botón de guardar. Hace falta `ensureVisible` porque el
  /// formulario es más alto que el viewport de 800x600 del test.
  Future<void> enviar(final WidgetTester tester, final String etiqueta) async {
    final boton = find.text(etiqueta);
    await tester.ensureVisible(boton);
    await tester.pump();
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  testWidgets('en un ingreso aparecen el documento y la comisión', (
    final tester,
  ) async {
    await montar(tester);

    expect(find.text('Documento'), findsOneWidget);
    expect(find.text('Boleta de venta'), findsOneWidget);
    expect(find.text('Boleta de honorarios'), findsOneWidget);
    expect(find.text('Sin documento'), findsOneWidget);
    expect(
      find.text('Comisión del medio de pago (opcional)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mercado Pago'),
      findsOneWidget,
      reason: 'la ayuda tiene que nombrar los medios de pago reales',
    );
  });

  testWidgets('en un gasto no aparece ninguno de los dos', (
    final tester,
  ) async {
    await montar(tester, tipo: TransactionType.expense);

    expect(find.text('Documento'), findsNothing);
    expect(find.text('Boleta de venta'), findsNothing);
    expect(find.text('Comisión del medio de pago (opcional)'), findsNothing);
  });

  testWidgets('al cambiar de ingreso a gasto se olvidan los dos campos', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'comision', '5.000');
    await tester.tap(find.text('Boleta de venta'));
    await tester.pump();

    await tester.tap(find.text('Gasto'));
    await tester.pump();
    expect(find.text('Comisión del medio de pago (opcional)'), findsNothing);

    await tester.tap(find.text('Ingreso'));
    await tester.pump();
    // El campo vuelve vacío: una comisión escrita para un ingreso no puede
    // sobrevivir a un paso por Gasto.
    expect(find.text('5.000'), findsNothing);
  });

  testWidgets('guarda el documento y la comisión elegidos', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'titulo', 'Venta en feria');
    await escribir(tester, 'monto', '120.000');
    await escribir(tester, 'comision', '4.560');
    await tester.tap(find.text('Boleta de venta'));
    await tester.pump();

    await enviar(tester, 'Registrar ingreso');

    expect(repository.added, hasLength(1));
    final guardada = repository.added.single;
    expect(guardada.title, 'Venta en feria');
    expect(guardada.amount, 120000);
    expect(guardada.platformFee, 4560);
    expect(guardada.docType, TransactionDocType.boletaVenta);
    expect(guardada.netAmount, 115440);
  });

  testWidgets('sin comisión el movimiento queda con los valores por defecto', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'titulo', 'Pedido por transferencia');
    await escribir(tester, 'monto', '80.000');

    await enviar(tester, 'Registrar ingreso');

    expect(repository.added, hasLength(1));
    final guardada = repository.added.single;
    expect(guardada.platformFee, 0);
    expect(guardada.docType, TransactionDocType.sinDocumento);
    expect(guardada.netAmount, 80000);
  });

  testWidgets('las categorías de ingreso son las del oficio chileno', (
    final tester,
  ) async {
    await montar(tester);

    for (final categoria in incomeCategories) {
      expect(find.text(categoria), findsOneWidget, reason: categoria);
    }
    expect(find.text('Venta en feria'), findsOneWidget);
    expect(find.text('Venta por Instagram'), findsOneWidget);
    // Las genéricas de antes ya no se ofrecen.
    expect(find.text('Materiales'), findsNothing);
    expect(find.text('Servicios'), findsNothing);
  });

  testWidgets('las categorías de gasto son las de un taller', (
    final tester,
  ) async {
    await montar(tester, tipo: TransactionType.expense);

    for (final categoria in expenseCategories) {
      expect(find.text(categoria), findsOneWidget, reason: categoria);
    }
    // Un gasto no ofrece categorías de ingreso.
    expect(find.text('Venta en feria'), findsNothing);
  });

  testWidgets('una comisión mayor que el monto no se guarda', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'titulo', 'Venta por Instagram');
    await escribir(tester, 'monto', '20.000');
    await escribir(tester, 'comision', '30.000');

    await enviar(tester, 'Registrar ingreso');

    expect(repository.added, isEmpty);
    expect(
      find.text('La comisión no puede ser mayor que el monto'),
      findsOneWidget,
    );
  });
}
