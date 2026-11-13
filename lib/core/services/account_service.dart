/// PROPÓSITO: cliente del callable `deleteAccount`.
///
/// REQUISITO DE GOOGLE PLAY, no una comodidad. La política de eliminación de
/// datos exige que toda app que permita crear una cuenta ofrezca dos caminos
/// para borrarla: uno DENTRO de la app y una URL pública accesible sin
/// instalarla. El backend lo cubre desde hace tiempo
/// (`functions/src/account.ts`) y la landing tiene la página pública, pero en
/// `lib/` no había una sola referencia al callable: la mitad que Play revisa
/// de verdad, la de dentro de la app, no existía.
///
/// Este servicio solo llama. Lo que se borra y en qué orden lo decide el
/// backend: primero el árbol de Firestore y después la credencial de
/// Authentication, porque al revés un fallo dejaría documentos sin ninguna
/// sesión capaz de volver a pedir su borrado.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import 'callable_errors.dart';

/// Fallo al eliminar la cuenta, con un mensaje listo para mostrar.
class AccountDeletionException implements Exception {
  final String code;
  final String message;

  /// `true` cuando [message] viene tal cual del backend.
  final bool fromServer;

  const AccountDeletionException(
    this.code,
    this.message, {
    this.fromServer = false,
  });

  /// Construye el error a partir de lo que devolvió el callable.
  ///
  /// El mensaje del servidor manda: es el único que sabe en qué paso se
  /// quedó el borrado, y los tres `HttpsError` de `account.ts` ya vienen
  /// redactados en español (y distinguen "no se borró nada" de "tus datos se
  /// borraron pero no se pudo cerrar la cuenta", que no es lo mismo).
  factory AccountDeletionException.from(
    final String code,
    final String? serverMessage,
  ) {
    if (isHumanCallableMessage(serverMessage)) {
      return AccountDeletionException(
        code,
        serverMessage!.trim(),
        fromServer: true,
      );
    }
    return AccountDeletionException(code, _fallbackFor(code));
  }

  static String _fallbackFor(final String code) {
    switch (code) {
      case 'unauthenticated':
        return 'Tu sesión expiró. Vuelve a entrar e inténtalo de nuevo.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'No se pudo contactar con el servidor. '
            'Tu cuenta sigue como estaba; inténtalo de nuevo.';
      default:
        return 'No se pudo eliminar la cuenta. '
            'Tu cuenta sigue como estaba; inténtalo de nuevo.';
    }
  }

  @override
  String toString() => 'AccountDeletionException($code): $message';
}

/// Cliente del callable `deleteAccount`.
class AccountService {
  /// Región donde se despliegan las funciones (contrato v1).
  static const String region = 'southamerica-west1';

  /// Espera máxima.
  ///
  /// Generosa a propósito: `deleteAccount` se despliega con
  /// `timeoutSeconds: 300` porque el borrado recursivo de una cuenta con
  /// mucho historial tarda. Cortar antes que el servidor dejaría a la persona
  /// viendo un error mientras su cuenta se borra igualmente, que es la peor
  /// combinación posible.
  static const Duration timeout = Duration(minutes: 5);

  static const String _callableName = 'deleteAccount';

  final FirebaseFunctions? _functionsOverride;

  AccountService({final FirebaseFunctions? functions})
    : _functionsOverride = functions;

  /// Se resuelve al usarlo y no en el constructor: así un doble de pruebas
  /// puede heredar de esta clase sin que construirlo toque Firebase.
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseFunctions.instanceFor(region: region);

  /// Borra la cuenta de quien tiene la sesión abierta.
  ///
  /// No recibe parámetros a propósito: el uid sale del token, no del cliente.
  ///
  /// Al volver sin lanzar, los datos del usuario ya no están y su credencial
  /// de Authentication tampoco. Lo que queda por hacer en el cliente es
  /// cerrar sesión para soltar el token local.
  ///
  /// Lanza [AccountDeletionException] ante cualquier fallo.
  Future<void> deleteAccount() async {
    final HttpsCallableResult<dynamic> result;
    try {
      result = await _functions
          .httpsCallable(_callableName)
          .call<dynamic>()
          .timeout(timeout);
    } on FirebaseFunctionsException catch (e) {
      throw AccountDeletionException.from(e.code, e.message);
    } on TimeoutException {
      throw AccountDeletionException.from('deadline-exceeded', null);
    } catch (_) {
      throw AccountDeletionException.from('unknown', null);
    }

    // El backend contesta `{ok: true, uid, authDeleted, deletedAt}`. Si la
    // respuesta no trae `ok`, no se puede afirmar que la cuenta se borró, y
    // decirlo sin saberlo sería lo peor que podría hacer esta pantalla.
    final data = result.data;
    if (data is! Map || data['ok'] != true) {
      throw AccountDeletionException.from('internal', null);
    }
  }
}
