import '../../../finances/domain/entities/finances_summary_entity.dart';
import '../../../finances/domain/entities/finances_transaction_entity.dart';
import '../entities/net_hourly_value_entity.dart';

/// PROPÓSITO
/// ---------
/// Calcula las dos cifras por hora del mes a partir del **agregado mensual**
/// que escribe el backend (`users/{uid}/months/{yyyy-MM}`): lo que entró por
/// hora (ingresos − comisiones) y lo que sobró por hora (eso − gastos). El
/// significado exacto de cada una está en [NetHourlyValueEntity].
///
/// POR QUÉ EL AGREGADO Y NO LAS TRANSACCIONES. Antes esta clase recorría la
/// lista de movimientos del mes para sumar ingresos y comisiones. Esa lista
/// llega acotada a 200 documentos por `firestore.rules`: a partir del
/// movimiento 201 de un mes la cifra salía corta **sin avisar**, que es el
/// peor modo de fallar en una app de dinero. El agregado existe justamente
/// para eso y ya traía `totalPlatformFees` desde el contrato C-3
/// (`functions/src/months.ts`); el cliente simplemente no lo leía.
///
/// El recorrido sigue aquí, pero SOLO como respaldo de un caso concreto: un
/// `months/{yyyy-MM}` escrito antes de C-3 no trae `totalPlatformFees`, y en
/// ese documento un 0 no significa "no hubo comisiones" sino "no se sabe".
/// Sumarlas de los movimientos visibles es peor que el agregado y mucho mejor
/// que enseñar un valor hora inflado.
///
/// Dependencia entre features: importa las entidades de `finances` porque el
/// resumen y los movimientos viven ahí. La alternativa —duplicar un DTO— solo
/// añadiría una traducción, y el riesgo real es el contrario: que el neto se
/// calcule de dos formas distintas en dos sitios. Aquí se calcula una vez.
class CalculateNetHourlyValue {
  const CalculateNetHourlyValue();

  /// [summary] es el resumen del mes en pantalla. `FinancesProvider.summary`
  /// ya devuelve el agregado del backend cuando existe y un cálculo local
  /// equivalente mientras el trigger no ha pasado.
  ///
  /// [transactions] son los movimientos del mes y se usan **solo** si
  /// [summary] no trae la suma de comisiones (ver arriba). Pueden traer
  /// ingresos y gastos mezclados.
  ///
  /// [availableHoursPerMonth] sale de la configuración del usuario. Si no es
  /// un número utilizable (0, negativo, NaN), no se inventa un divisor: la
  /// entidad devuelve 0 y la pantalla no muestra la cifra.
  NetHourlyValueEntity execute({
    required final FinancesSummaryEntity summary,
    required final Iterable<FinancesTransactionEntity> transactions,
    required final double availableHoursPerMonth,
  }) {
    final gross = _safe(summary.totalIncome);
    final expenses = _safe(summary.totalExpenses);

    final double fees;
    final bool fromAggregate;
    if (summary.hasPlatformFeesTotal) {
      // `effectivePlatformFees` ya acota a [0, totalIncome].
      fees = _safe(summary.effectivePlatformFees);
      fromAggregate = true;
    } else {
      fees = _feesFromTransactions(transactions, gross);
      fromAggregate = false;
    }

    final hours = availableHoursPerMonth.isFinite && availableHoursPerMonth > 0
        ? availableHoursPerMonth
        : 0.0;

    return NetHourlyValueEntity(
      grossIncome: gross,
      platformFees: fees,
      expenses: expenses,
      availableHoursPerMonth: hours,
      feesFromMonthlyAggregate: fromAggregate,
    );
  }

  /// Respaldo: suma las comisiones de los ingresos visibles, acotada al bruto
  /// del mes para que el neto no pueda salir negativo.
  static double _feesFromTransactions(
    final Iterable<FinancesTransactionEntity> transactions,
    final double gross,
  ) {
    var fees = 0.0;
    for (final transaction in transactions) {
      if (!transaction.isIncome) continue;
      // `effectivePlatformFee`, no `platformFee`: la entidad ya acota la
      // comisión a [0, amount].
      fees += transaction.effectivePlatformFee;
    }
    if (!fees.isFinite || fees <= 0) return 0;
    return fees > gross ? gross : fees;
  }

  static double _safe(final double value) =>
      value.isFinite && value > 0 ? value : 0;
}
