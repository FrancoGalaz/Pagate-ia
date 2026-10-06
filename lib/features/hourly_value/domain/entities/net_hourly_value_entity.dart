import 'package:equatable/equatable.dart';

/// PROPÓSITO
/// ---------
/// Resultado del valor hora **neto**: lo que de verdad le quedó al usuario por
/// cada hora de trabajo del mes, una vez descontadas las comisiones del medio
/// de pago que él mismo registró (contrato C-3).
///
/// Por qué existe: hasta ahora la app solo conocía el valor hora *objetivo*
/// (`HourlyRateEntity` = sueldo deseado ÷ horas). Eso es una meta, no un
/// hecho. Un artesano que cobra por Mercado Pago (3,19% + IVA) o Khipu
/// (0,69% + IVA) nunca recibe el monto de la venta, así que una cifra basada
/// en el bruto le dice que gana más de lo que gana.
///
/// Esta entidad **mide**, no asesora: agrupa lo que el usuario registró. No
/// calcula impuestos, no estima lo que falta por declarar y no recomienda
/// precios.
class NetHourlyValueEntity extends Equatable {
  /// Suma de los montos de los ingresos del periodo (bruto, tal como se
  /// cobró).
  final double grossIncome;

  /// Suma de las comisiones registradas en esos ingresos.
  final double platformFees;

  /// Horas del mes con las que se divide. Vienen de la configuración del
  /// usuario (`días × horas`), no de un supuesto de la app.
  final double availableHoursPerMonth;

  /// Cuántos ingresos entraron en la suma. Con 0 no hay nada que mostrar.
  final int incomeCount;

  const NetHourlyValueEntity({
    required this.grossIncome,
    required this.platformFees,
    required this.availableHoursPerMonth,
    required this.incomeCount,
  });

  /// Ingreso neto del periodo. No se persiste en ninguna parte: se deriva.
  double get netIncome {
    final net = grossIncome - platformFees;
    return net > 0 ? net : 0;
  }

  /// Valor hora neto. Es la cifra que se muestra.
  double get netHourlyValue =>
      availableHoursPerMonth > 0 ? netIncome / availableHoursPerMonth : 0;

  /// Valor hora sin descontar comisiones. Se conserva para poder decir
  /// cuánto se llevó el medio de pago, no para mostrarlo como resultado.
  double get grossHourlyValue =>
      availableHoursPerMonth > 0 ? grossIncome / availableHoursPerMonth : 0;

  /// `true` si el usuario registró al menos una comisión. Si es `false`, el
  /// neto y el bruto coinciden: no se descontó nada porque no había nada que
  /// descontar.
  bool get hasPlatformFees => platformFees > 0;

  bool get hasIncome => incomeCount > 0;

  @override
  List<Object?> get props => [
        grossIncome,
        platformFees,
        availableHoursPerMonth,
        incomeCount,
      ];
}
