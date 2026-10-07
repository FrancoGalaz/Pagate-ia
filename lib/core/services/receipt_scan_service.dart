import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import 'callable_errors.dart';

// ═══════════════════════════════════════════════════════════════════════
// CLIENTE DEL CALLABLE `scanReceipt`
// ═══════════════════════════════════════════════════════════════════════
// Vive en `core/services/` y no en el feature por el mismo motivo que
// `ai_service.dart`: es el mismo tipo de pieza, un cliente fino de Cloud
// Functions, sin estado y sin nada de interfaz.
//
// LO ÚNICO QUE VIAJA ES TEXTO. La imagen no se envía nunca: ya se
// reconoció dentro del teléfono. Esa es la frase que la política de
// privacidad publicada afirma, y este archivo es el único sitio del
// cliente donde podría dejar de ser verdad, así que el contrato se
// escribe aquí arriba: el cuerpo de la petición es `{text, source}` y nada
// más.
//
// `resource-exhausted` NO ES UN ERROR PARA QUIEN LLAMA. Significa que no
// queda cuota para que el modelo ordene la lista, y la lista local ya está
// en pantalla: la pantalla de revisión muestra el mensaje del servidor en
// una franja informativa y sigue. Escanear tres boletas no puede dejar al
// usuario sin función.
// ═══════════════════════════════════════════════════════════════════════

/// Un artículo tal como lo devuelve el backend, sin interpretar.
class ScanReceiptItem {
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final String? code;

  const ScanReceiptItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.code,
  });
}

/// Respuesta del callable.
class ScanReceiptResult {
  final List<ScanReceiptItem> items;
  final String? supplier;
  final String? documentNumber;
  final double? total;
  final bool truncated;

  const ScanReceiptResult({
    required this.items,
    this.supplier,
    this.documentNumber,
    this.total,
    this.truncated = false,
  });
}

/// Error del lector con mensaje listo para mostrar.
class ReceiptScanServiceException implements Exception {
  final String code;
  final String message;

  /// `true` cuando [message] viene tal cual del backend. Solo el servidor
  /// sabe en qué plan está el usuario y cuántas lecturas le quedaban.
  final bool fromServer;

  const ReceiptScanServiceException(
    this.code,
    this.message, {
    this.fromServer = false,
  });

  factory ReceiptScanServiceException.from(
    final String code,
    final String? serverMessage,
  ) {
    if (isHumanCallableMessage(serverMessage)) {
      return ReceiptScanServiceException(
        code,
        serverMessage!.trim(),
        fromServer: true,
      );
    }
    return ReceiptScanServiceException(code, _fallbackFor(code));
  }

  /// `true` si lo que se agotó es una cuota. No es un fallo: la lista local
  /// sigue siendo válida.
  bool get esCuota => code == 'resource-exhausted';

  /// Respaldo cuando el servidor no manda texto legible.
  ///
  /// Ninguno afirma nada que el cliente no pueda saber. En particular el de
  /// `resource-exhausted` NO dice "vuelve mañana" ni "pasa a Pro": la cuota
  /// del plan gratuito es de por vida (`FREE_LIFETIME_SCAN_QUOTA`), el
  /// mismo código lo lanza el tope global del día del dueño, y no hay
  /// ningún plan que se pueda comprar dentro de la app. Es el mismo
  /// criterio ya documentado en `ai_service.dart`.
  static String _fallbackFor(final String code) {
    switch (code) {
      case 'resource-exhausted':
        return 'No quedan lecturas de boleta ordenadas por el asistente.';
      case 'unauthenticated':
        return 'Inicia sesión para leer boletas.';
      case 'invalid-argument':
        return 'El texto de la boleta está vacío o es demasiado largo.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'El lector no responde. Intenta de nuevo.';
      default:
        return 'No pude ordenar la boleta.';
    }
  }

  @override
  String toString() => 'ReceiptScanServiceException($code): $message';
}

/// Cliente del callable `scanReceipt`.
class ReceiptScanService {
  /// Región donde se despliegan las funciones (contrato v1).
  static const String region = 'southamerica-west1';

  /// Espera máxima. El callable tiene `timeoutSeconds: 60` en el servidor;
  /// aquí se corta un poco antes para poder mostrar la lista local en vez de
  /// quedarse colgado.
  static const Duration timeout = Duration(seconds: 40);

  static const String _callableName = 'scanReceipt';

  /// Tope de caracteres que acepta el backend (`MAX_SCAN_TEXT_CHARS`). Se
  /// recorta aquí para no gastar una llamada que el servidor va a rechazar
  /// con `invalid-argument`.
  static const int maxTextChars = 8000;

  final FirebaseFunctions? _inyectado;
  FirebaseFunctions? _cache;

  ReceiptScanService({final FirebaseFunctions? functions})
      : _inyectado = functions;

  /// LA INSTANCIA SE RESUELVE PEREZOSA, y no es un detalle de estilo.
  ///
  /// `FirebaseFunctions.instanceFor` exige que Firebase esté inicializado,
  /// así que resolverla en el constructor hacía imposible que un doble de
  /// test heredara de esta clase sin levantar Firebase: construir el doble
  /// ya reventaba. Los widget tests de esta feature se montan sin Firebase,
  /// como manda AGENTS.md, y sobrescriben [structure]: por este camino no
  /// llegan a tocar nunca el SDK.
  FirebaseFunctions get _functions =>
      _cache ??= _inyectado ?? FirebaseFunctions.instanceFor(region: region);

  /// Manda el texto del OCR y devuelve los artículos ordenados.
  ///
  /// [source] es `'photo'` o `'pdf'` y solo sirve para el registro del
  /// servidor y para matizar su prompt.
  Future<ScanReceiptResult> structure({
    required final String text,
    final String? source,
  }) async {
    final recortado =
        text.length > maxTextChars ? text.substring(0, maxTextChars) : text;

    final HttpsCallableResult<dynamic> result;
    try {
      result = await _functions
          .httpsCallable(_callableName)
          .call<dynamic>({'text': recortado, 'source': ?source})
          .timeout(timeout);
    } on FirebaseFunctionsException catch (e) {
      throw ReceiptScanServiceException.from(e.code, e.message);
    } on TimeoutException {
      throw ReceiptScanServiceException.from('deadline-exceeded', null);
    } catch (_) {
      throw ReceiptScanServiceException.from('unknown', null);
    }

    final data = result.data;
    if (data is! Map) {
      throw ReceiptScanServiceException.from('internal', null);
    }

    // EL CLIENTE NO SE FÍA DEL BACKEND, igual que el backend no se fía del
    // modelo. Un `quantity` que llegue como texto o un `unitPrice`
    // infinito harían reventar la pantalla de revisión en mitad de un
    // `build`; aquí se descarta el artículo y se sigue con los demás.
    final crudos = data['items'];
    final items = <ScanReceiptItem>[];
    if (crudos is List) {
      for (final crudo in crudos) {
        final item = _leerItem(crudo);
        if (item != null) items.add(item);
      }
    }

    return ScanReceiptResult(
      items: items,
      supplier: _textoOpcional(data['supplier']),
      documentNumber: _textoOpcional(data['documentNumber']),
      total: _numeroOpcional(data['total']),
      truncated: data['truncated'] == true,
    );
  }

  static ScanReceiptItem? _leerItem(final Object? crudo) {
    if (crudo is! Map) return null;
    final name = _textoOpcional(crudo['name']);
    if (name == null) return null;

    final quantity = _numeroOpcional(crudo['quantity']);
    final unitPrice = _numeroOpcional(crudo['unitPrice']);
    if (quantity == null || quantity <= 0) return null;
    if (unitPrice == null || unitPrice <= 0) return null;

    return ScanReceiptItem(
      name: name,
      quantity: quantity,
      unit: _textoOpcional(crudo['unit']) ?? 'unidades',
      unitPrice: unitPrice,
      code: _textoOpcional(crudo['code']),
    );
  }

  static String? _textoOpcional(final Object? valor) {
    if (valor is! String) return null;
    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
  }

  static double? _numeroOpcional(final Object? valor) {
    if (valor is! num) return null;
    final numero = valor.toDouble();
    return numero.isFinite ? numero : null;
  }
}
