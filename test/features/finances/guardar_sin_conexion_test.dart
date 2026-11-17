// PROPÓSITO
// ---------
// Revisión prelanzamiento 5.1. Sin red, una escritura de Firestore queda en
// la cola local y su `Future` no termina hasta que el servidor la confirma.
// Las pantallas la esperaban sin plazo y quedaban cargando sin fin.
//
// Aquí van los gastos fijos y los dos borrados de Finanzas, con el provider
// de verdad y un repositorio que no confirma nunca. Registrar un movimiento
// está en `transaction_form_sheet_test.dart`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/utils/app_feedback.dart';
import 'package:pagate_ia/core/utils/escritura_pendiente.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/finances/domain/repositories/finances_repository.dart';
import 'package:pagate_ia/features/finances/presentation/pages/finanzas_tab.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';

/// Repositorio sin conexión: anota la escritura y no la confirma hasta que
/// se complete [conexion].
class _RepositorioSinConexion implements FinancesRepository {
  /// Un test que la rechace con `completeError` tiene que crearla dentro del
  /// propio test: un error no cruza de la zona de `setUp` a la del test.
  Completer<void> conexion = Completer<void>();
  final List<String> gastosFijos = [];
  final List<String> gastosBorrados = [];
  final List<String> movimientosBorrados = [];

  @override
  Stream<List<FinancesSummaryEntity>> watchMonths() => Stream.value(const []);

  @override
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) =>
      Stream.value([
        FinancesTransactionEntity(
          id: 'tx1',
          title: 'Venta en feria',
          description: '',
          amount: 12000,
          type: TransactionType.income,
          date: DateTime.now(),
          category: 'Ventas',
        ),
      ]);

  @override
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() => Stream.value(
        const [FixedExpenseEntity(id: 'g1', name: 'Luz', amount: 30000)],
      );

  @override
  Future<void> addTransaction(
    final FinancesTransactionEntity transaction,
  ) async {
    await conexion.future;
  }

  @override
  Future<void> updateTransaction(
    final FinancesTransactionEntity transaction,
  ) async {}

  @override
  Future<void> deleteTransaction(final String transactionId) async {
    movimientosBorrados.add(transactionId);
    await conexion.future;
  }

  @override
  Future<void> addFixedExpense({
    required final String name,
    required final double amount,
  }) async {
    gastosFijos.add(name);
    await conexion.future;
  }

  @override
  Future<void> deleteFixedExpense(final String id) async {
    gastosBorrados.add(id);
    await conexion.future;
  }
}

void main() {
  late _RepositorioSinConexion repository;
  late FinancesProvider provider;

  setUp(() {
    repository = _RepositorioSinConexion();
    provider = FinancesProvider(repository: repository);
  });

  tearDown(() => provider.dispose());

  testWidgets('sin conexión el gasto fijo se guarda y la hoja se cierra', (
    final tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 900)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<FinancesProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: FinanzasTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Agregar'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo gasto fijo'), findsOneWidget);

    final campos = find.descendant(
      of: find.byType(Form),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(campos.at(0), 'Arriendo del taller');
    await tester.enterText(campos.at(1), '250.000');
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Nuevo gasto fijo'),
      findsNothing,
      reason: 'la hoja no puede quedarse cargando sin fin',
    );
    expect(
      find.text(
        'Guardado en el teléfono. Se sincronizará cuando vuelva la conexión.',
      ),
      findsOneWidget,
    );

    // Vuelve la red: sigue habiendo un solo gasto fijo.
    repository.conexion.complete();
    await tester.pump();
    expect(repository.gastosFijos, ['Arriendo del taller']);

    AppFeedback.dismiss();
    await tester.pumpAndSettle();
  });

  /// ¿Termina [escritura] sola, sin que el servidor confirme? Y, como los
  /// guardados, ¿dice que quedó sin confirmar (`false`)?
  Future<bool> terminaSola(
    final WidgetTester tester,
    final Future<void> Function() escritura,
  ) async {
    var termino = false;
    Object? confirmado;
    unawaited(
      escritura().then((final dynamic r) {
        termino = true;
        confirmado = r as Object?;
      }),
    );
    await tester.pump(const Duration(seconds: 15));
    expect(confirmado, isFalse, reason: 'el borrado no quedó confirmado');
    return termino;
  }

  testWidgets('sin conexión borrar un gasto fijo no deja esperando', (
    final tester,
  ) async {
    expect(
      await terminaSola(tester, () => provider.deleteFixedExpense('g1')),
      isTrue,
    );
    expect(repository.gastosBorrados, ['g1']);
  });

  // Lo que el servidor rechaza al sincronizar se avisa nombrando qué fue: con
  // varios guardados pendientes, «algo no se guardó» no sirve de nada.
  group('el rechazo al sincronizar dice qué no se guardó', () {
    late List<String> avisos;

    setUp(() {
      avisos = [];
      RechazoAlSincronizar.avisar = avisos.add;
    });

    /// La conexión se crea dentro del test (ver [_RepositorioSinConexion]).
    Future<void> sinConexion(final WidgetTester tester) async {
      repository.conexion = Completer<void>();
      await tester.pump();
    }

    tearDown(() => RechazoAlSincronizar.avisar = null);

    Future<void> rechazar(final WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 15));
      repository.conexion.completeError(Exception('permission-denied'));
      await tester.pump();
    }

    testWidgets('un movimiento nuevo', (final tester) async {
      await sinConexion(tester);
      unawaited(
        provider.addTransaction(
          title: 'Taller de cerámica',
          amount: 25000,
          type: TransactionType.income,
          category: 'Ventas',
          date: DateTime.now(),
        ),
      );
      await rechazar(tester);
      expect(avisos, ['No se pudo guardar el movimiento «Taller de cerámica».']);
    });

    testWidgets('un movimiento borrado', (final tester) async {
      await sinConexion(tester);
      unawaited(provider.deleteTransaction('tx1'));
      await rechazar(tester);
      expect(avisos, ['No se pudo eliminar el movimiento «Venta en feria».']);
    });

    testWidgets('un gasto fijo nuevo y uno borrado', (final tester) async {
      await sinConexion(tester);
      unawaited(provider.addFixedExpense(name: 'Arriendo', amount: 250000));
      unawaited(provider.deleteFixedExpense('g1'));
      await rechazar(tester);
      expect(avisos, [
        'No se pudo guardar el gasto fijo «Arriendo».',
        'No se pudo eliminar el gasto fijo «Luz».',
      ]);
    });
  });

  testWidgets('sin conexión borrar un movimiento no deja esperando', (
    final tester,
  ) async {
    expect(
      await terminaSola(tester, () => provider.deleteTransaction('tx1')),
      isTrue,
    );
    expect(repository.movimientosBorrados, ['tx1']);
  });
}
