import 'package:equatable/equatable.dart';
import 'finances_summary_entity.dart';

enum TransactionType { income, expense }

/// Documento con el que se respaldó un ingreso (contrato C-3, Chile).
///
/// Los tres valores son los del oficio real: la **boleta de venta** lleva
/// IVA, la **boleta de honorarios** lleva retención y no lleva IVA, y
/// **sin documento** es el caso del artesano que cobra por transferencia o
/// en efectivo y no emite nada. Guardar cuál fue es lo que después le
/// permite ordenar sus ingresos para hablar con su contador.
///
/// Límite deliberado: la app **registra y muestra**. No calcula impuestos a
/// pagar, no dice cuánto declarar y no da consejo tributario; eso es
/// asesoría y no es lo que hace este producto.
enum TransactionDocType {
  boletaVenta('boleta_venta', 'Boleta de venta'),
  boletaHonorarios('boleta_honorarios', 'Boleta de honorarios'),
  sinDocumento('sin_documento', 'Sin documento');

  const TransactionDocType(this.wire, this.label);

  /// Valor exacto que viaja a Firestore. Lo fija el contrato C-3 y tiene que
  /// coincidir con lo que acepten `firestore.rules` y el backend.
  final String wire;

  /// Nombre en español de Chile, el que se muestra en el formulario.
  final String label;

  /// Valor asumido cuando el campo no viene. El campo es **opcional**: los
  /// movimientos registrados antes del contrato C-3 no lo tienen y siguen
  /// siendo válidos.
  static const TransactionDocType fallback = sinDocumento;

  /// Traduce el valor almacenado. Nunca lanza: un valor desconocido (campo
  /// ausente, documento viejo u otra versión del cliente) cae en [fallback].
  static TransactionDocType fromWire(final Object? value) {
    for (final type in TransactionDocType.values) {
      if (type.wire == value) return type;
    }
    return fallback;
  }
}

/// Movimiento registrado por el usuario (`users/{uid}/transactions/{txId}`).
class FinancesTransactionEntity extends Equatable {
  /// Id del documento en Firestore. Vacío para una transacción aún no guardada.
  final String id;
  final String title;
  final String description;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final String category;

  /// Documento que respalda el movimiento. Opcional en Firestore; aquí el
  /// valor por defecto es el mismo que se asume cuando el campo falta.
  final TransactionDocType docType;

  /// Comisión que se quedó el medio de pago (Mercado Pago, Khipu, Transbank),
  /// en la misma moneda que [amount]. Opcional: 0 significa "no me
  /// descontaron nada", que es el caso de la transferencia y del efectivo.
  final double platformFee;

  const FinancesTransactionEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
    this.docType = TransactionDocType.fallback,
    this.platformFee = 0,
  });

  /// Clave `yyyy-MM` derivada de [date].
  String get monthKey => monthKeyFromDate(date);

  bool get isIncome => type == TransactionType.income;

  /// Comisión acotada a `[0, amount]`.
  ///
  /// No hay `assert` en el constructor a propósito: esta entidad se construye
  /// también desde datos de Firestore, y una app de dinero no puede caerse (ni
  /// en depuración) porque un documento traiga una comisión absurda. Un neto
  /// negativo mentiría más que una comisión recortada, así que se recorta aquí
  /// y el modelo además lo registra con `debugPrint`.
  double get effectivePlatformFee {
    if (!platformFee.isFinite || platformFee <= 0) return 0;
    return platformFee > amount ? amount : platformFee;
  }

  /// Lo que realmente quedó: [amount] menos la comisión del medio de pago.
  ///
  /// El neto **nunca** se persiste (contrato C-3): se deriva siempre, así que
  /// no puede quedar desincronizado del monto ni de la comisión.
  double get netAmount => amount - effectivePlatformFee;

  /// `true` si el usuario registró una comisión en este movimiento.
  bool get hasPlatformFee => effectivePlatformFee > 0;

  FinancesTransactionEntity copyWith({
    final String? id,
    final String? title,
    final String? description,
    final double? amount,
    final TransactionType? type,
    final DateTime? date,
    final String? category,
    final TransactionDocType? docType,
    final double? platformFee,
  }) =>
      FinancesTransactionEntity(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        date: date ?? this.date,
        category: category ?? this.category,
        docType: docType ?? this.docType,
        platformFee: platformFee ?? this.platformFee,
      );

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        amount,
        type,
        date,
        category,
        docType,
        platformFee,
      ];
}
