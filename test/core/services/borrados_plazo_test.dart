// PROPÓSITO
// ---------
// Revisión prelanzamiento 5.4. `deleteAccount` (300 s) y `deleteChatHistory`
// (120 s) tardan en una cuenta grande. El cliente no le pasaba su plazo al
// plugin de Cloud Functions, que corta a los 60 s por defecto: la persona
// veía un error mientras el servidor seguía borrando su cuenta.
//
// Igual que en 5.2 (`ai_service_plazo_test.dart`): el plazo del cliente se
// compara con el `timeoutSeconds` leído del código del servidor, y tiene que
// llegar también al plugin.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/account_service.dart';
import 'package:pagate_ia/core/services/chat_history_service.dart';

/// `timeoutSeconds` del callable definido en [archivo].
Duration _plazoDelServidor(final String archivo) {
  final codigo = File('functions/src/$archivo').readAsStringSync();
  final m = RegExp(r'timeoutSeconds:\s*(\d+)').firstMatch(codigo);
  expect(m, isNotNull, reason: '$archivo debería declarar timeoutSeconds');
  return Duration(seconds: int.parse(m!.group(1)!));
}

void main() {
  group('borrar la cuenta', () {
    test('el cliente espera más que el servidor', () {
      expect(AccountService.timeout, greaterThan(_plazoDelServidor('account.ts')));
    });

    test('el plugin recibe el mismo plazo', () {
      expect(AccountService.opciones.timeout, AccountService.timeout);
    });
  });

  group('borrar el historial del asistente', () {
    test('el cliente espera más que el servidor', () {
      expect(
        ChatHistoryService.timeout,
        greaterThan(_plazoDelServidor('chatHistory.ts')),
      );
    });

    test('el plugin recibe el mismo plazo', () {
      expect(ChatHistoryService.opciones.timeout, ChatHistoryService.timeout);
    });
  });
}
