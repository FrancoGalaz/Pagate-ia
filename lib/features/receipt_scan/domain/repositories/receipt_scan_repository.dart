import '../entities/receipt_document.dart';
import '../entities/receipt_reading.dart';
import '../entities/scanned_line_item.dart';

/// Error de lectura con un mensaje ya escrito para el usuario.
///
/// Igual que `AiServiceException`, el mensaje es la pieza que importa: la
/// pantalla de lectura lo muestra tal cual. Por eso cada caso tiene su
/// propio texto y no hay un "ocurrió un error" genérico: "este PDF está
/// protegido" y "la foto pesa demasiado" se arreglan de formas distintas, y
/// un mensaje único obligaría al usuario a adivinar cuál es la suya.
class ReceiptScanException implements Exception {
  /// Identificador corto para los tests y el registro. No se muestra.
  final String code;

  final String message;

  /// Pista concreta de qué hacer, si la hay. Va en la descripción del
  /// estado de error, debajo del título.
  final String? hint;

  const ReceiptScanException(this.code, this.message, {this.hint});

  @override
  String toString() => 'ReceiptScanException($code): $message';
}

/// Resultado de pedirle al backend que ordene el texto.
class StructuredReceipt {
  final List<ScannedLineItem> items;
  final ScanDegradation degradation;

  /// Mensaje del servidor cuando lo hay (cuota agotada, tope global). Se
  /// muestra TAL CUAL: el cliente no sabe en qué plan está el usuario ni
  /// cuántas lecturas le quedaban.
  final String? serverMessage;

  /// `true` si el backend recortó artículos por el tope de 40.
  final bool truncated;

  const StructuredReceipt({
    required this.items,
    required this.degradation,
    this.serverMessage,
    this.truncated = false,
  });
}

/// Lo que sacó la heurística local.
class LocalParse {
  final List<ScannedLineItem> items;

  /// `true` si se alcanzó el tope de 40 artículos y se descartó el resto.
  /// Se dice en pantalla: una lista recortada en silencio haría pensar que
  /// la boleta no tenía más.
  final bool truncated;

  const LocalParse({required this.items, this.truncated = false});
}

/// Contrato del lector de boletas.
///
/// Las tres entradas se reducen a [ReceiptDocument]; la lectura es local y
/// siempre produce una lista con [parseLocal]; [structure] solo la mejora y
/// NUNCA es obligatoria. Esa separación es lo que hace que la función siga
/// existiendo en una feria sin señal, que es justo donde se usa.
abstract class ReceiptScanRepository {
  /// Abre la cámara del sistema. `null` si el usuario canceló.
  Future<ReceiptDocument?> tomarFoto();

  /// Abre el selector de imágenes del sistema. `null` si canceló.
  Future<ReceiptDocument?> elegirImagen();

  /// Reconoce el texto EN EL DISPOSITIVO y borra el archivo al terminar,
  /// haya ido bien o mal.
  ///
  /// Lanza [ReceiptScanException] con un mensaje propio ante un PDF
  /// protegido, un archivo demasiado grande o un teléfono que no rasteriza.
  Future<ReceiptReading> leer(ReceiptDocument documento);

  /// La heurística local. Sin red, sin cuota y sin que nada salga del
  /// teléfono. Nunca lanza: como mucho devuelve una lista vacía.
  LocalParse parseLocal(ReceiptReading lectura);

  /// Pide al backend que ordene el texto. Si falla por cualquier motivo
  /// devuelve [local] con la bandera de degradación que corresponda.
  ///
  /// [esPdf] solo viaja como etiqueta de origen para el registro del
  /// servidor; lo decide el documento, no el número de páginas leídas (un
  /// PDF de una página sigue siendo un PDF).
  Future<StructuredReceipt> structure({
    required ReceiptReading lectura,
    required List<ScannedLineItem> local,
    required bool esPdf,
  });
}
