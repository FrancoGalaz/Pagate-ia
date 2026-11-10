/// Cliente del callable `deleteChatHistory`: borra las conversaciones con el
/// asistente. El backend no toca la cuota (`meta/usage`) ni los reportes
/// (`aiReports`); ver `functions/src/chatHistory.ts`.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import 'callable_errors.dart';

/// Fallo al borrar el historial, con un mensaje listo para mostrar.
class ChatHistoryDeletionException implements Exception {
  final String message;

  const ChatHistoryDeletionException(this.message);

  factory ChatHistoryDeletionException.from(
    final String code,
    final String? serverMessage,
  ) {
    if (isHumanCallableMessage(serverMessage)) {
      return ChatHistoryDeletionException(serverMessage!.trim());
    }
    return ChatHistoryDeletionException(
      code == 'unauthenticated'
          ? 'Tu sesión expiró. Vuelve a entrar e inténtalo de nuevo.'
          : 'No se pudo borrar el historial. Inténtalo de nuevo.',
    );
  }

  @override
  String toString() => 'ChatHistoryDeletionException: $message';
}

class ChatHistoryService {
  static const String region = 'southamerica-west1';

  /// `deleteChatHistory` se despliega con `timeoutSeconds: 120`.
  static const Duration timeout = Duration(minutes: 2);

  final FirebaseFunctions? _functionsOverride;

  ChatHistoryService({final FirebaseFunctions? functions})
    : _functionsOverride = functions;

  /// Se resuelve al usarlo: construir el servicio no toca Firebase.
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instanceFor(region: region);

  /// Lanza [ChatHistoryDeletionException] ante cualquier fallo.
  Future<void> deleteChatHistory() async {
    final HttpsCallableResult<dynamic> result;
    try {
      result = await _functions
          .httpsCallable('deleteChatHistory')
          .call<dynamic>()
          .timeout(timeout);
    } on FirebaseFunctionsException catch (e) {
      throw ChatHistoryDeletionException.from(e.code, e.message);
    } on TimeoutException {
      throw ChatHistoryDeletionException.from('deadline-exceeded', null);
    } catch (_) {
      throw ChatHistoryDeletionException.from('unknown', null);
    }
    final data = result.data;
    if (data is! Map || data['ok'] != true) {
      throw ChatHistoryDeletionException.from('internal', null);
    }
  }
}
