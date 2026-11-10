// PROPÓSITO
// ---------
// El formulario del valor hora salía VACÍO aunque el perfil ya tuviera una
// configuración guardada: los tres controladores nacían en blanco y nadie los
// rellenaba nunca. Una usuaria con 900.000 y 120 horas guardadas veía los
// marcadores "0 / 20 / 8" y tenía que escribirlo todo otra vez a ciegas.
//
// Lo que se vigila aquí:
//   · Los campos llegan precargados con lo que hay en el perfil.
//   · Se precargan también cuando el valor llega TARDE, que es lo normal:
//     viene por el stream de `users/{uid}`.
//   · La precarga no pisa lo que la persona ya escribió.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/finances/domain/repositories/finances_repository.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';
import 'package:pagate_ia/features/hourly_value/domain/entities/hourly_rate_entity.dart';
import 'package:pagate_ia/features/hourly_value/domain/repositories/hourly_rate_repository.dart';
import 'package:pagate_ia/features/hourly_value/domain/usecases/calculate_hourly_rate.dart';
import 'package:pagate_ia/features/hourly_value/presentation/bloc/hourly_rate_provider.dart';
import 'package:pagate_ia/features/hourly_value/presentation/pages/hourly_rate_setup_page.dart';

/// Repositorio con un stream controlado: deja emitir el valor hora cuando el
/// test quiera, que es como llega de verdad (después del primer fotograma).
class FakeHourlyRateRepository implements HourlyRateRepository {
  final controller = StreamController<HourlyRateEntity?>.broadcast();
  HourlyRateEntity? guardado;

  @override
  Stream<HourlyRateEntity?> watchHourlyRate() => controller.stream;

  @override
  Future<void> saveHourlyRate(final HourlyRateEntity hourlyRate) async {
    guardado = hourlyRate;
  }

  Future<void> dispose() => controller.close();
}

class FakeFinancesRepository implements FinancesRepository {
  @override
  Stream<List<FinancesSummaryEntity>> watchMonths() => Stream.value(const []);

  @override
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) => Stream.value(const []);

  @override
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() =>
      Stream.value(const []);

  @override
  Future<void> addTransaction(
    final FinancesTransactionEntity transaction,
  ) async {}

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
  late FakeHourlyRateRepository hourlyRepository;
  late HourlyRateProvider hourly;
  late FinancesProvider finances;

  setUp(() {
    hourlyRepository = FakeHourlyRateRepository();
    hourly = HourlyRateProvider(
      calculateUseCase: CalculateHourlyRate(),
      repository: hourlyRepository,
    );
    finances = FinancesProvider(repository: FakeFinancesRepository());
  });

  tearDown(() async {
    hourly.dispose();
    finances.dispose();
    await hourlyRepository.dispose();
  });

  Future<void> montar(final WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<HourlyRateProvider>.value(value: hourly),
            ChangeNotifierProvider<FinancesProvider>.value(value: finances),
          ],
          child: const HourlyRateSetupPage(),
        ),
      ),
    );
    await tester.pump();
  }

  /// El campo cuya etiqueta es [label]. La etiqueta es HERMANA del
  /// `TextFormField` dentro de `PagateTextField`, no su ancestro, así que se
  /// busca por el widget y no por el texto.
  Finder campoConEtiqueta(final String label) => find.byWidgetPredicate(
    (final w) => w is PagateTextField && w.labelText == label,
  );

  /// Texto que hay dentro del campo cuya etiqueta es [label].
  String valorDelCampo(final WidgetTester tester, final String label) =>
      tester
          .widget<PagateTextField>(campoConEtiqueta(label))
          .controller
          ?.text ??
      '';

  testWidgets('precarga el sueldo y las horas que ya estaban guardados', (
    final tester,
  ) async {
    await montar(tester);

    // El valor hora llega por el stream, después del primer fotograma: es el
    // caso que dejaba el formulario vacío.
    hourlyRepository.controller.add(
      const HourlyRateEntity(
        desiredMonthlySalary: 900000,
        availableHoursPerMonth: 120,
      ),
    );
    await tester.pumpAndSettle();

    expect(valorDelCampo(tester, 'Sueldo que quieres al mes'), '900.000');
    expect(valorDelCampo(tester, 'Horas que trabajas al mes'), '120');
  });

  testWidgets('sin configuración guardada los campos quedan vacíos', (
    final tester,
  ) async {
    await montar(tester);
    hourlyRepository.controller.add(null);
    await tester.pumpAndSettle();

    expect(valorDelCampo(tester, 'Sueldo que quieres al mes'), '');
    expect(valorDelCampo(tester, 'Horas que trabajas al mes'), '');
  });

  testWidgets('las horas con decimales se precargan con coma', (
    final tester,
  ) async {
    await montar(tester);
    hourlyRepository.controller.add(
      const HourlyRateEntity(
        desiredMonthlySalary: 450000,
        availableHoursPerMonth: 82.5,
      ),
    );
    await tester.pumpAndSettle();

    expect(valorDelCampo(tester, 'Horas que trabajas al mes'), '82,5');
  });

  testWidgets('guardar no vuelve a pisar lo que la persona escribió', (
    final tester,
  ) async {
    await montar(tester);
    hourlyRepository.controller.add(
      const HourlyRateEntity(
        desiredMonthlySalary: 900000,
        availableHoursPerMonth: 120,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: campoConEtiqueta('Horas que trabajas al mes'),
        matching: find.byType(TextFormField),
      ),
      '160',
    );
    await tester.pumpAndSettle();

    // Un emisión nueva del stream (la que provoca el propio guardado) no
    // puede devolver el campo a 120.
    hourlyRepository.controller.add(
      const HourlyRateEntity(
        desiredMonthlySalary: 900000,
        availableHoursPerMonth: 160,
      ),
    );
    await tester.pumpAndSettle();

    expect(valorDelCampo(tester, 'Horas que trabajas al mes'), '160');
  });
}
