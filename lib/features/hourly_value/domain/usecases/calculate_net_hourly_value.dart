import '../../../finances/domain/entities/finances_transaction_entity.dart';
import '../entities/net_hourly_value_entity.dart';

/// PROPÓSITO
/// ---------
/// Calcula el valor hora **neto** del periodo a partir de los movimientos que
/// el usuario registró: suma los ingresos, les resta las comisiones del medio
/// de pago y divide por las horas configuradas.
///
/// Por qué importa el neto (contrato C-3): cobrar por Mercado Pago cuesta
/// 3,19% + IVA y por Khipu 0,69% + IVA. Si el cálculo usa el monto cobrado y
/// no el recibido, la cifra que ve el artesano está inflada. Si no registró
/// ninguna comisión, el neto y el bruto coinciden y el resultado es el mismo
/// de siempre: nada cambia para quien cobra en efectivo o por transferencia.
///
/// Dependencia entre features: importa la entidad de `finances` porque los
/// movimientos viven ahí. La alternativa —duplicar un DTO con monto y
/// comisión— solo añadiría una traducción sin aportar nada, y el riesgo real
/// es justo el contrario: que el neto se calcule de dos formas distintas en
/// dos sitios. Aquí se calcula una vez.
class CalculateNetHourlyValue {
  const CalculateNetHourlyValue();

  /// [transactions] puede traer ingresos y gastos mezclados: se usan solo los
  /// ingresos, porque el valor hora responde "cuánto me entró por hora", no
  /// "cuánto me sobró".
  ///
  /// [availableHoursPerMonth] sale de la configuración del usuario. Si no es
  /// un número utilizable (0, negativo, NaN), no se inventa un divisor: la
  /// entidad devuelve 0 y la pantalla no muestra la cifra.
  NetHourlyValueEntity execute({
    required final Iterable<FinancesTransactionEntity> transactions,
    required final double availableHoursPerMonth,
  }) {
    var gross = 0.0;
    var fees = 0.0;
    var count = 0;

    for (final transaction in transactions) {
      if (!transaction.isIncome) continue;
      if (!transaction.amount.isFinite) continue;
      gross += transaction.amount;
      // `effectivePlatformFee`, no `platformFee`: la entidad ya acota la
      // comisión a [0, amount], así que el neto nunca puede salir negativo.
      fees += transaction.effectivePlatformFee;
      count++;
    }

    final hours = availableHoursPerMonth.isFinite && availableHoursPerMonth > 0
        ? availableHoursPerMonth
        : 0.0;

    return NetHourlyValueEntity(
      grossIncome: gross,
      platformFees: fees,
      availableHoursPerMonth: hours,
      incomeCount: count,
    );
  }
}
