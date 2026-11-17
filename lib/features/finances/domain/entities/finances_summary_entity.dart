import 'package:equatable/equatable.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/utils/month_labels.dart';

/// Resumen mensual calculado por el backend (`users/{uid}/months/{yyyy-MM}`).
///
/// El id del documento es el [monthKey]. Los totales NUNCA se escriben desde
/// el cliente: los recalcula el trigger `onTransactionWritten`.
class FinancesSummaryEntity extends Equatable {
  /// Clave del mes en formato `yyyy-MM` (id del documento).
  final String monthKey;
  final double totalIncome;
  final double totalExpenses;

  /// Suma de las comisiones del medio de pago de los INGRESOS del mes
  /// (contrato C-3, `functions/src/months.ts`).
  ///
  /// Es el operando que faltaba para que el cliente pueda derivar el neto del
  /// mes **sin recorrer las transacciones**. El recorrido está acotado a 200
  /// documentos por `firestore.rules`, así que a partir del movimiento 201 de
  /// un mes el neto calculado a mano salía mal sin avisar.
  final double totalPlatformFees;

  /// `true` si [totalPlatformFees] es un dato que venía en el documento, y no
  /// un 0 por ausencia.
  ///
  /// Hace falta porque el campo es POSTERIOR a C-3: un `months/{yyyy-MM}`
  /// escrito antes del contrato no lo trae, y ahí un 0 no significa "no hubo
  /// comisiones" sino "no se sabe". Quien necesite la cifra tiene que poder
  /// distinguir los dos casos para caer al respaldo en vez de enseñar un neto
  /// inflado.
  final bool hasPlatformFeesTotal;

  final int transactionCount;

  const FinancesSummaryEntity({
    required this.monthKey,
    required this.totalIncome,
    required this.totalExpenses,
    required this.transactionCount,
    this.totalPlatformFees = 0,
    this.hasPlatformFeesTotal = false,
  });

  double get balance => totalIncome - totalExpenses;

  /// Comisiones acotadas a `[0, totalIncome]`.
  ///
  /// El trigger ya las acota, pero este agregado también se lee de documentos
  /// escritos por el Admin SDK (sembrado, migraciones), que no pasa por las
  /// reglas. Una comisión mayor que el ingreso daría un neto negativo, que es
  /// una cifra falsa.
  double get effectivePlatformFees {
    if (!hasPlatformFeesTotal) return 0;
    if (!totalPlatformFees.isFinite || totalPlatformFees <= 0) return 0;
    final techo = totalIncome.isFinite && totalIncome > 0 ? totalIncome : 0.0;
    return totalPlatformFees > techo ? techo : totalPlatformFees;
  }

  /// Ingreso neto del mes (C-3): lo cobrado menos lo que se llevó el medio de
  /// pago. **No se persiste**, se deriva.
  double get netIncome => totalIncome - effectivePlatformFees;

  /// Progreso hacia una meta mensual (0..1). La meta vive en el perfil del
  /// usuario, por eso se recibe como parámetro.
  double goalProgress(final double monthlyGoal) =>
      monthlyGoal > 0 ? (totalIncome / monthlyGoal).clamp(0.0, 1.0) : 0.0;

  /// Etiqueta legible, p. ej. "Marzo 2025".
  String get month => monthLabelFromKey(monthKey);

  /// Primer día del mes representado, o `null` si la clave es inválida.
  DateTime? get firstDay {
    final parts = monthKey.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month, 1);
  }

  @override
  List<Object?> get props => [
        monthKey,
        totalIncome,
        totalExpenses,
        totalPlatformFees,
        hasPlatformFeesTotal,
        transactionCount,
      ];
}

/// La zona horaria de Chile continental, con sus reglas de horario de verano.
///
/// Sale de la base de zonas horarias IANA que trae el paquete `timezone`, no
/// de una regla escrita aquí: Chile cambia su horario por decreto (en 2015 no
/// hubo horario de invierno, en 2016 empezó en mayo, en 2022 se corrió una
/// semana) y una regla a mano acierta solo mientras dure el decreto vigente.
///
/// La base viaja DENTRO de la app. Cuando un decreto nuevo cambie las fechas,
/// hay que subir la versión de `timezone` en `pubspec.yaml` y publicar.
final tz.Location _santiago = () {
  tzdata.initializeTimeZones();
  return tz.getLocation('America/Santiago');
}();

/// Deriva la clave `yyyy-MM` de una fecha, SIEMPRE en hora de Chile
/// continental (America/Santiago), esté donde esté el teléfono.
///
/// Antes usaba la hora local: el mismo instante caía en meses distintos según
/// la zona horaria del teléfono, y un movimiento podía cambiar de mes al
/// tocarlo desde otra zona. El backend ya calcula el mes en curso con
/// America/Santiago (`currentMonthKey` en `functions/src/chat.ts`).
String monthKeyFromDate(final DateTime date) {
  final chile = tz.TZDateTime.from(date, _santiago);
  return '${chile.year}-${chile.month.toString().padLeft(2, '0')}';
}

/// Convierte `yyyy-MM` en "Marzo 2025". Si la clave es inválida la devuelve
/// tal cual.
///
/// Los nombres de mes viven en `core/utils/month_labels.dart`; aquí solo se
/// conserva el nombre de la función porque es el que consume la entidad.
String monthLabelFromKey(final String monthKey) =>
    monthLabelFromMonthKey(monthKey);
