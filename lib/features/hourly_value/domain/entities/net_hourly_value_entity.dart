import 'package:equatable/equatable.dart';

/// PROPÓSITO
/// ---------
/// Las DOS cifras por hora del mes, que no son la misma y hasta ahora se
/// enseñaban como si lo fueran:
///
/// 1. [entryHourlyValue] — **lo que te ENTRÓ por hora**: los ingresos del mes
///    menos las comisiones del medio de pago, divididos por las horas. Es el
///    neto del contrato C-3 (`docs/ARQUITECTURA.md`: "el neto se deriva donde
///    se muestra, como `totalIncome - totalPlatformFees`"). NO descuenta los
///    gastos.
/// 2. [leftoverHourlyValue] — **lo que te SOBRÓ por hora**: lo anterior menos
///    los gastos que el usuario registró en el mes. Puede ser negativo, y
///    cuando lo es, lo es de verdad: ese mes el taller puso dinero.
///
/// POR QUÉ ESTÁN LAS DOS Y POR QUÉ SE LLAMAN ASÍ. La pantalla enseñaba la
/// cifra 1 con el rótulo de la 2 ("Lo que te quedó por hora"). Medido en
/// emulator-5554 con los datos demo de octubre de 2026 —980.000 de ingresos,
/// 8.995 de comisiones, 640.500 de gastos, 120 horas— la pantalla decía
/// $8.092 cuando lo que de verdad sobró por hora eran $2.754: casi el triple.
/// No era un error de cálculo sino de nombre, y las dos cifras le sirven a
/// una artesana: la primera para comparar con su valor hora objetivo (lo que
/// cobra por su trabajo), la segunda para saber si el mes cerró en positivo.
/// Por eso no se eligió una: se enseñan ambas, cada una con su nombre exacto.
///
/// Esta entidad **mide**, no asesora: agrupa lo que el usuario registró. No
/// calcula impuestos, no estima lo que falta por declarar y no recomienda
/// precios.
class NetHourlyValueEntity extends Equatable {
  /// Suma de los ingresos del mes (bruto, tal como se cobró).
  final double grossIncome;

  /// Suma de las comisiones del medio de pago de esos ingresos.
  final double platformFees;

  /// Suma de los gastos del mes.
  final double expenses;

  /// Horas del mes con las que se divide. Vienen de la configuración del
  /// usuario, no de un supuesto de la app.
  final double availableHoursPerMonth;

  /// `true` si [platformFees] salió del agregado `months/{yyyy-MM}` del
  /// backend, `false` si hubo que recorrer las transacciones del mes.
  ///
  /// No cambia ninguna cifra: existe para que los tests puedan fijar cuál de
  /// los dos caminos se usó, porque el recorrido está acotado a 200
  /// documentos y el agregado no.
  final bool feesFromMonthlyAggregate;

  const NetHourlyValueEntity({
    required this.grossIncome,
    required this.platformFees,
    required this.expenses,
    required this.availableHoursPerMonth,
    required this.feesFromMonthlyAggregate,
  });

  /// Lo que entró en el mes: lo cobrado menos las comisiones. Nunca negativo
  /// (las comisiones vienen acotadas al ingreso).
  double get entryIncome {
    final net = grossIncome - platformFees;
    return net > 0 ? net : 0;
  }

  /// **Lo que te entró por hora.** Ingresos menos comisiones, sobre las horas.
  double get entryHourlyValue => availableHoursPerMonth > 0
      ? entryIncome / availableHoursPerMonth
      : 0;

  /// Lo que sobró en el mes: lo que entró menos los gastos registrados.
  ///
  /// **Puede ser negativo** y no se recorta: un mes en el que los gastos se
  /// comieron los ingresos es un hecho, y taparlo con un 0 sería la misma
  /// clase de mentira que esta entidad vino a arreglar.
  double get leftoverIncome => entryIncome - expenses;

  /// **Lo que te sobró por hora.** Lo que entró menos los gastos, sobre las
  /// horas.
  double get leftoverHourlyValue => availableHoursPerMonth > 0
      ? leftoverIncome / availableHoursPerMonth
      : 0;

  /// Valor hora sin descontar nada. Se conserva para poder decir cuánto se
  /// llevó el medio de pago, no para mostrarlo como resultado.
  double get grossHourlyValue => availableHoursPerMonth > 0
      ? grossIncome / availableHoursPerMonth
      : 0;

  /// `true` si el usuario registró al menos una comisión. Si es `false`, lo
  /// que entró y el bruto coinciden: no se descontó nada porque no había nada
  /// que descontar.
  bool get hasPlatformFees => platformFees > 0;

  /// `true` si el usuario registró algún gasto este mes. Si es `false`, lo que
  /// sobró y lo que entró coinciden, y la pantalla lo dice en vez de dejar al
  /// usuario preguntándose por qué hay dos cifras iguales.
  bool get hasExpenses => expenses > 0;

  /// `true` si hay ingresos sobre los que calcular.
  ///
  /// Se mira el monto y no un contador de documentos a propósito: la cifra
  /// puede venir del agregado del mes, que guarda sumas y no cuenta los
  /// ingresos por separado. Un ingreso de 0 no existe: el formulario y las
  /// reglas exigen un monto mayor que cero.
  bool get hasIncome => grossIncome > 0;

  @override
  List<Object?> get props => [
        grossIncome,
        platformFees,
        expenses,
        availableHoursPerMonth,
        feesFromMonthlyAggregate,
      ];
}
