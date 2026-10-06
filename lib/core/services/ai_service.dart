import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

/// Respuesta del callable `chat`.
class ChatReply {
  final String conversationId;
  final String reply;

  const ChatReply({required this.conversationId, required this.reply});
}

/// Error del asistente con mensaje listo para mostrar al usuario.
class AiServiceException implements Exception {
  final String code;
  final String message;

  /// `true` cuando [message] viene tal cual del backend.
  ///
  /// Sirve para no inventar: el cliente no sabe en qué plan está el usuario,
  /// cuántos mensajes trae su plan ni si lo que se agotó fue su cuota o el
  /// tope global del día. Todo eso solo lo sabe el servidor, que lo manda
  /// escrito.
  final bool fromServer;

  const AiServiceException(this.code, this.message, {this.fromServer = false});

  /// Construye el error a partir de lo que vino del callable.
  ///
  /// EL MENSAJE DEL SERVIDOR MANDA. Es público y está fuera de [AiService]
  /// para poder probarlo sin levantar Cloud Functions: es la única pieza de
  /// este archivo donde se decide qué lee el usuario.
  factory AiServiceException.from(
    final String code,
    final String? serverMessage,
  ) {
    if (_isHumanMessage(serverMessage)) {
      return AiServiceException(code, serverMessage!.trim(), fromServer: true);
    }
    return AiServiceException(code, _fallbackFor(code));
  }

  /// ¿El mensaje que llegó está escrito para una persona?
  ///
  /// Cuando el backend lanza un `HttpsError`, su texto viaja intacto hasta
  /// aquí. Cuando el fallo lo genera la propia infraestructura, en cambio, el
  /// SDK rellena `message` con el marcador del código en mayúsculas y sin
  /// espacios ('INTERNAL', 'UNAVAILABLE', 'DEADLINE_EXCEEDED'), que no se le
  /// puede enseñar a nadie. Se distinguen por eso: un texto redactado tiene
  /// espacios y minúsculas.
  static bool _isHumanMessage(final String? message) {
    final text = message?.trim();
    if (text == null || text.length < 12) return false;
    if (!text.contains(' ')) return false;
    return text != text.toUpperCase();
  }

  /// Respaldo para cuando el servidor no manda un texto legible.
  ///
  /// Ninguno de estos textos afirma nada que el cliente no pueda saber. En
  /// particular, el de `resource-exhausted` ya NO dice "límite diario" ni
  /// "vuelve mañana" ni "pasa a Pro", que era falso tres veces:
  ///   - la cuota del plan gratuito es DE POR VIDA (`FREE_LIFETIME_QUOTA` en
  ///     `functions/src/quota.ts`), así que no se renueva mañana;
  ///   - el mismo código lo lanza también el tope global del día del dueño,
  ///     que no es un límite del usuario ni depende de su plan;
  ///   - y no hay ningún plan Pro que se pueda comprar dentro de la app.
  /// El respaldo se queda en lo único cierto en los tres casos. Y como el
  /// backend sí manda un texto en los tres, en la práctica el usuario lee el
  /// del servidor, que es el único que sabe cuántos mensajes eran.
  static String _fallbackFor(final String code) {
    switch (code) {
      case 'resource-exhausted':
        return 'No quedan mensajes disponibles para el asistente.';
      case 'unauthenticated':
        return 'Inicia sesión para usar el asistente.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'El asistente no responde. Intenta de nuevo.';
      default:
        return 'Ocurrió un error con el asistente.';
    }
  }

  @override
  String toString() => 'AiServiceException($code): $message';
}

/// Cliente del callable `chat` de Cloud Functions.
///
/// El cliente nunca habla con OpenRouter: la clave y el system prompt viven en
/// el backend (ver `docs/ARQUITECTURA.md`). Este servicio solo envía
/// `{conversationId, message}` y devuelve `{conversationId, reply}`.
class AiService {
  /// Región donde se despliegan las funciones (contrato v1).
  static const String region = 'southamerica-west1';

  /// Tiempo máximo de espera por una respuesta del asistente.
  static const Duration timeout = Duration(seconds: 45);

  static const String _callableName = 'chat';

  final FirebaseFunctions _functions;

  AiService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: region);

  /// Envía [message] al asistente dentro de [conversationId].
  ///
  /// Si [conversationId] es nulo el backend crea una conversación nueva y
  /// devuelve su id en [ChatReply.conversationId].
  ///
  /// Lanza [AiServiceException] con un mensaje en español ante cualquier fallo.
  Future<ChatReply> sendMessage({
    String? conversationId,
    required String message,
  }) async {
    final HttpsCallableResult<dynamic> result;
    try {
      result = await _functions
          .httpsCallable(_callableName)
          .call<dynamic>({
            'conversationId': ?conversationId,
            'message': message,
          })
          .timeout(timeout);
    } on FirebaseFunctionsException catch (e) {
      // Antes se descartaba `e.message` y se mostraba un texto fijo, así que
      // el cliente tenía que adivinar qué había pasado y lo adivinaba mal.
      throw AiServiceException.from(e.code, e.message);
    } on TimeoutException {
      throw AiServiceException.from('deadline-exceeded', null);
    } catch (_) {
      throw AiServiceException.from('unknown', null);
    }

    final data = result.data;
    if (data is! Map) {
      throw AiServiceException.from('internal', null);
    }
    final id = data['conversationId'];
    final reply = data['reply'];
    if (id is! String || id.isEmpty || reply is! String) {
      throw AiServiceException.from('internal', null);
    }
    return ChatReply(conversationId: id, reply: reply);
  }
}
