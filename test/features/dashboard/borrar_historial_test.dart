// Borrar el historial del asistente: AiProvider con dobles de Firestore, del
// callable `chat` y de `deleteChatHistory`, y la fila de Configuración.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/ai_service.dart';
import 'package:pagate_ia/core/services/chat_history_service.dart';
import 'package:pagate_ia/features/dashboard/presentation/providers/ai_provider.dart';
import 'package:pagate_ia/features/dashboard/presentation/widgets/borrar_historial_row.dart';
import 'package:provider/provider.dart';

// ─── Firestore mínimo: sin conversaciones y un stream de mensajes mudo ──────
//
// Las referencias de Firestore están marcadas `@sealed` para el código de la
// app; un doble de test es justo la excepción, de ahí los `ignore`.

typedef _Datos = Map<String, dynamic>;

class _Db extends Fake implements FirebaseFirestore {
  @override
  CollectionReference<_Datos> collection(final String path) => _Col();
}

// ignore: subtype_of_sealed_class
class _Col extends Fake implements CollectionReference<_Datos> {
  @override
  DocumentReference<_Datos> doc([final String? path]) => _Doc();

  @override
  Query<_Datos> orderBy(final Object field, {final bool descending = false}) =>
      _Query();
}

// ignore: subtype_of_sealed_class
class _Doc extends Fake implements DocumentReference<_Datos> {
  @override
  CollectionReference<_Datos> collection(final String path) => _Col();
}

// ignore: subtype_of_sealed_class
class _Query extends Fake implements Query<_Datos> {
  @override
  Query<_Datos> limit(final int limit) => this;

  @override
  Query<_Datos> limitToLast(final int limit) => this;

  @override
  Future<QuerySnapshot<_Datos>> get([final GetOptions? options]) async =>
      _Vacio();

  @override
  Stream<QuerySnapshot<_Datos>> snapshots({
    final bool includeMetadataChanges = false,
    final ListenSource source = ListenSource.defaultSource,
  }) =>
      StreamController<QuerySnapshot<_Datos>>().stream;
}

class _Vacio extends Fake implements QuerySnapshot<_Datos> {
  @override
  List<QueryDocumentSnapshot<_Datos>> get docs => const [];
}

// ─── Callables ──────────────────────────────────────────────────────────────

/// Anota el `conversationId` de cada envío. Con [pendiente], no responde
/// hasta que se complete.
class _ChatFalso implements AiService {
  final List<String?> enviados = [];
  Completer<ChatReply>? pendiente;

  @override
  Future<ChatReply> sendMessage({
    final String? conversationId,
    required final String message,
  }) {
    enviados.add(conversationId);
    return pendiente?.future ??
        Future.value(const ChatReply(conversationId: 'c1', reply: 'Hola'));
  }

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _HistorialFalso extends ChatHistoryService {
  int llamadas = 0;
  ChatHistoryDeletionException? error;

  @override
  Future<void> deleteChatHistory() async {
    llamadas++;
    if (error != null) throw error!;
  }
}

void main() {
  late _ChatFalso chat;
  late _HistorialFalso historial;

  Future<AiProvider> provider() async {
    final p = AiProvider(
      service: chat,
      userId: 'uid-a',
      firestore: _Db(),
      historyService: historial,
    );
    await Future<void>.delayed(Duration.zero);
    return p;
  }

  setUp(() {
    chat = _ChatFalso();
    historial = _HistorialFalso();
  });

  group('AiProvider.borrarHistorial', () {
    test('vuelve al saludo y el siguiente envío no manda conversationId',
        () async {
      final p = await provider();
      await p.sendMessage('¿Cuánto cobro?');
      expect(p.conversationId, 'c1');

      expect(await p.borrarHistorial(), isTrue);

      expect(historial.llamadas, 1);
      expect(p.conversationId, isNull);
      expect(p.messages.map((final m) => m.id), ['welcome']);

      await p.sendMessage('Otra pregunta');
      expect(chat.enviados, [null, null]);
    });

    test('con una respuesta pendiente no llama al backend', () async {
      final p = await provider();
      chat.pendiente = Completer<ChatReply>();
      unawaited(p.sendMessage('Hola'));
      expect(p.isSending, isTrue);

      expect(await p.borrarHistorial(), isFalse);
      expect(historial.llamadas, 0);

      chat.pendiente!.complete(
        const ChatReply(conversationId: 'c1', reply: 'Hola'),
      );
    });

    test('si el borrado falla, lanza y no toca la conversación', () async {
      final p = await provider();
      await p.sendMessage('Hola');
      historial.error = const ChatHistoryDeletionException('No se pudo.');

      await expectLater(
        p.borrarHistorial(),
        throwsA(isA<ChatHistoryDeletionException>()),
      );
      expect(p.conversationId, 'c1');
    });
  });

  group('BorrarHistorialRow', () {
    Future<_AiProviderFalso> montar(
      final WidgetTester tester, {
      required final bool respondiendo,
    }) async {
      final ai = _AiProviderFalso(isSending: respondiendo);
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AiProvider>.value(
            value: ai,
            child: const Scaffold(body: BorrarHistorialRow()),
          ),
        ),
      );
      return ai;
    }

    testWidgets('desactivada mientras el asistente responde', (
      final tester,
    ) async {
      final ai = await montar(tester, respondiendo: true);

      expect(find.text('Espera a que el asistente responda'), findsOneWidget);
      await tester.tap(find.text('Borrar historial del asistente'));
      await tester.pumpAndSettle();

      expect(find.text('¿Borrar el historial?'), findsNothing);
      expect(ai.borrados, 0);
    });

    testWidgets('pide confirmación; Cancelar no borra', (final tester) async {
      final ai = await montar(tester, respondiendo: false);

      await tester.tap(find.text('Borrar historial del asistente'));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar el historial?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(ai.borrados, 0);
    });

    testWidgets('confirmado, borra y lo avisa', (final tester) async {
      final ai = await montar(tester, respondiendo: false);

      await tester.tap(find.text('Borrar historial del asistente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pump();

      expect(ai.borrados, 1);
      expect(find.text('Historial del asistente borrado.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}

class _AiProviderFalso extends ChangeNotifier implements AiProvider {
  _AiProviderFalso({required this.isSending});

  @override
  final bool isSending;

  int borrados = 0;

  @override
  Future<bool> borrarHistorial() async {
    borrados++;
    return true;
  }

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}
