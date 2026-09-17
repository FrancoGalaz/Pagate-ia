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

  const AiServiceException(this.code, this.message);

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
      throw AiServiceException(e.code, _messageForCode(e.code));
    } on TimeoutException {
      throw AiServiceException(
        'deadline-exceeded',
        _messageForCode('deadline-exceeded'),
      );
    } catch (_) {
      throw AiServiceException('unknown', _messageForCode('unknown'));
    }

    final data = result.data;
    if (data is! Map) {
      throw AiServiceException('internal', _messageForCode('internal'));
    }
    final id = data['conversationId'];
    final reply = data['reply'];
    if (id is! String || id.isEmpty || reply is! String) {
      throw AiServiceException('internal', _messageForCode('internal'));
    }
    return ChatReply(conversationId: id, reply: reply);
  }

  static String _messageForCode(String code) {
    switch (code) {
      case 'resource-exhausted':
        return 'Alcanzaste el límite diario de mensajes. '
            'Vuelve mañana o pasa a Pro.';
      case 'unauthenticated':
        return 'Inicia sesión para usar el asistente.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'El asistente no responde. Intenta de nuevo.';
      default:
        return 'Ocurrió un error con el asistente.';
    }
  }
}
