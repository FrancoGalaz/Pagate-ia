import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_brand.dart';
import '../../../../core/constants/firestore_limits.dart';
import '../../../../core/services/ai_service.dart';

/// Quién escribió un mensaje del chat.
enum ChatRole { user, assistant }

/// Un mensaje del chat.
///
/// Los mensajes con [pending] en `true` existen solo en el cliente (envío
/// optimista) hasta que el backend los persiste y llegan por el stream.
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  final bool pending;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.pending = false,
  });

  bool get isAssistant => role == ChatRole.assistant;

  factory ChatMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return ChatMessage(
      id: doc.id,
      role: data['role'] == 'assistant' ? ChatRole.assistant : ChatRole.user,
      text: data['text'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    );
  }
}

/// Motivo por el que una persona reporta una respuesta del asistente.
///
/// Los cuatro motivos salen de lo que la política de Google Play para IA
/// generativa pide poder marcar: contenido ofensivo o inapropiado, y
/// contenido que engaña o puede hacer daño. El valor de [id] es lo que se
/// guarda; la etiqueta es lo que se lee.
enum AiReportReason {
  ofensivo('ofensivo', 'Ofensivo o inapropiado'),
  incorrecto('incorrecto', 'Información incorrecta'),
  peligroso('peligroso', 'Consejo que puede hacer daño'),
  otro('otro', 'Otro motivo');

  const AiReportReason(this.id, this.label);

  /// Lo que se persiste. Es estable aunque cambie la etiqueta.
  final String id;

  /// Lo que lee la persona en la hoja de reporte.
  final String label;
}

/// Estado del chat con el asistente.
///
/// Reglas (ver `docs/ARQUITECTURA.md`):
/// - El cliente NUNCA escribe en `users/{uid}/conversations/**`. Solo llama
///   al callable `chat` a través de [AiService] y escucha el stream de
///   `messages` de la conversación activa.
/// - El contexto financiero lo arma el backend; aquí no hay nada de eso.
/// - Se crea con alcance de usuario (`key: ValueKey(uid)` debajo del auth
///   gate), por eso `userId` llega por constructor.
class AiProvider extends ChangeNotifier {
  static const String _welcomeText =
      'Hola, soy tu asistente financiero de $kAppName.\n\n'
      'Conozco tus finanzas, tu inventario y tu valor hora. '
      'Pregúntame sobre precios, gastos, metas o pide un consejo '
      'para hacer crecer tu negocio.';

  static const String _historyErrorText = 'No se pudo cargar la conversación.';

  /// Subcolección donde se guardan los reportes de respuestas del asistente.
  ///
  /// `firestore.rules` tiene el `match /aiReports/{reportId}` que exige la
  /// política P-12 de Google Play: el dueño puede crear y leer, y `update` y
  /// `delete` están denegados a propósito (un reporte es la prueba de que
  /// alguien marcó una respuesta). La regla valida los mismos topes que
  /// aplica el cliente, [maxReportCommentChars] y [maxReportedTextChars],
  /// porque el cliente no es quien decide.
  ///
  /// Si la escritura falla igualmente, `reportMessage` devuelve `false` y la
  /// pantalla lo dice: nunca le cuenta a nadie que su reporte se envió si no
  /// se envió.
  static const String aiReportsCollection = 'aiReports';

  /// Tope del comentario libre del reporte, en caracteres.
  static const int maxReportCommentChars = 1000;

  /// Tope del fragmento de respuesta que se copia dentro del reporte.
  ///
  /// Se copia el texto y no solo el id del mensaje a propósito: si alguien
  /// borra la conversación, el reporte tiene que seguir siendo legible, que
  /// es justo para lo que sirve.
  static const int maxReportedTextChars = 2000;

  final AiService _service;
  final String _userId;
  final FirebaseFirestore _firestore;

  List<ChatMessage> _messages = [];
  String? _conversationId;
  bool _isSending = false;
  bool _isLoadingHistory = true;
  String? _error;
  String? _lastFailedText;
  bool _historyFailed = false;

  /// Ids de mensajes ya reportados en esta sesión. Solo sirve para que el
  /// botón no invite a reportar dos veces lo mismo; no se persiste.
  Set<String> _reportedMessageIds = const {};

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messagesSub;
  int _generation = 0;
  bool _disposed = false;

  AiProvider({
    required AiService service,
    required String userId,
    FirebaseFirestore? firestore,
  }) : _service = service,
       _userId = userId,
       _firestore = firestore ?? FirebaseFirestore.instance {
    _loadLatestConversation();
  }

  // ─── Getters ───────────────────────────────────────────────────────

  /// Mensajes a mostrar. Incluye un saludo local (no persistido) cuando aún
  /// no existe conversación.
  List<ChatMessage> get messages =>
      List.unmodifiable([if (_showWelcome) _welcomeMessage, ..._messages]);

  String? get conversationId => _conversationId;
  bool get isSending => _isSending;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get error => _error;

  /// `true` cuando hay algo que reintentar con [retry].
  bool get canRetry => _lastFailedText != null || _historyFailed;

  /// `true` si [messageId] ya se reportó en esta sesión.
  bool isReported(final String messageId) =>
      _reportedMessageIds.contains(messageId);

  bool get _showWelcome =>
      _conversationId == null && !_isLoadingHistory && !_historyFailed;

  ChatMessage get _welcomeMessage => ChatMessage(
    id: 'welcome',
    role: ChatRole.assistant,
    text: _welcomeText,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('users').doc(_userId).collection('conversations');

  // ─── Historial ─────────────────────────────────────────────────────

  Future<void> _loadLatestConversation() async {
    _isLoadingHistory = true;
    _historyFailed = false;
    _error = null;
    _notify();

    final generation = _generation;
    try {
      final snapshot = await _conversations
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();
      if (_disposed || generation != _generation) return;

      if (snapshot.docs.isEmpty) {
        _isLoadingHistory = false;
        _notify();
        return;
      }
      _subscribe(snapshot.docs.first.id);
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _isLoadingHistory = false;
      _historyFailed = true;
      _error = _historyErrorText;
      _notify();
    }
  }

  /// Se suscribe a los mensajes de [conversationId].
  ///
  /// `limitToLast` y no `limit`: el orden es ascendente (el chat se lee de
  /// arriba abajo) y lo que interesa son los ÚLTIMOS mensajes, no los
  /// primeros. Y el tope no es opcional: sin `request.query.limit` la regla
  /// `list` de `conversations/{id}/messages` deniega la consulta y el chat se
  /// queda en el error de historial para siempre (ver [FirestoreLimits]).
  void _subscribe(String conversationId) {
    _messagesSub?.cancel();
    _conversationId = conversationId;
    _messagesSub = _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .limitToLast(FirestoreLimits.maxList)
        .snapshots()
        .listen(_onMessages, onError: _onStreamError);
  }

  void _onMessages(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (_disposed) return;
    final remote = snapshot.docs.map(ChatMessage.fromDoc).toList();

    // Los pendientes que ya llegaron por el stream se descartan
    // (dedup por rol + texto, solo dentro de los pendientes).
    final stillPending = _messages
        .where((m) => m.pending)
        .where((p) => !remote.any((r) => r.role == p.role && r.text == p.text))
        .toList();

    _messages = [...remote, ...stillPending];
    _isLoadingHistory = false;
    _historyFailed = false;
    _notify();
  }

  void _onStreamError(Object _) {
    if (_disposed) return;
    _isLoadingHistory = false;
    _historyFailed = true;
    _error = _historyErrorText;
    _notify();
  }

  // ─── Acciones ──────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    _error = null;
    _lastFailedText = null;

    final optimistic = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      role: ChatRole.user,
      text: trimmed,
      createdAt: DateTime.now(),
      pending: true,
    );
    _messages = [..._messages, optimistic];
    _isSending = true;
    _notify();

    final generation = _generation;
    try {
      final reply = await _service.sendMessage(
        conversationId: _conversationId,
        message: trimmed,
      );
      if (_disposed) return;
      // Si el usuario abrió una conversación nueva mientras esperábamos,
      // la respuesta pertenece a la anterior: se ignora.
      if (generation != _generation) return;

      if (_conversationId == null) {
        _subscribe(reply.conversationId);
      }

      // Mostrar la respuesta de inmediato; el stream la reemplaza al llegar.
      final alreadyStreamed = _messages.any(
        (m) => !m.pending && m.isAssistant && m.text == reply.reply,
      );
      if (!alreadyStreamed) {
        _messages = [
          ..._messages,
          ChatMessage(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            role: ChatRole.assistant,
            text: reply.reply,
            createdAt: DateTime.now(),
            pending: true,
          ),
        ];
      }
    } on AiServiceException catch (e) {
      if (_disposed || generation != _generation) return;
      _messages = _messages.where((m) => m.id != optimistic.id).toList();
      _error = e.message;
      _lastFailedText = trimmed;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _messages = _messages.where((m) => m.id != optimistic.id).toList();
      _error = 'Ocurrió un error con el asistente.';
      _lastFailedText = trimmed;
    } finally {
      if (!_disposed && generation == _generation) {
        _isSending = false;
        _notify();
      }
    }
  }

  /// Guarda el reporte de una respuesta del asistente.
  ///
  /// POR QUÉ EXISTE: la política de Google Play para apps con IA generativa
  /// exige un mecanismo DENTRO de la app para marcar contenido ofensivo, sin
  /// que la persona tenga que salir a buscar un correo de soporte.
  ///
  /// Devuelve `true` solo si Firestore aceptó la escritura. No hay reintento
  /// ni cola local: un reporte que no se guardó se dice que no se guardó.
  Future<bool> reportMessage({
    required final ChatMessage message,
    required final AiReportReason reason,
    final String? comment,
  }) async {
    final trimmedComment = comment?.trim() ?? '';
    final text = message.text.length > maxReportedTextChars
        ? message.text.substring(0, maxReportedTextChars)
        : message.text;
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection(aiReportsCollection)
          .add({
            'messageId': message.id,
            'conversationId': ?_conversationId,
            'reason': reason.id,
            if (trimmedComment.isNotEmpty)
              'comment': trimmedComment.length > maxReportCommentChars
                  ? trimmedComment.substring(0, maxReportCommentChars)
                  : trimmedComment,
            'reportedText': text,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (error) {
      // Se registra y se devuelve false: quien llama decide qué enseñar, y
      // lo que enseña es que no se pudo.
      debugPrint('AiProvider.reportMessage: $error');
      return false;
    }
    if (_disposed) return true;
    _reportedMessageIds = {..._reportedMessageIds, message.id};
    _notify();
    return true;
  }

  /// Reintenta la última acción fallida: reenvía el último mensaje que no
  /// se pudo entregar o, si falló la carga del historial, vuelve a cargarlo.
  Future<void> retry() async {
    final text = _lastFailedText;
    if (text != null) {
      await sendMessage(text);
      return;
    }
    if (_historyFailed) {
      await _loadLatestConversation();
    }
  }

  /// Limpia el error visible sin reintentar.
  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  /// Empieza una conversación nueva. El backend la crea con el primer mensaje.
  void newConversation() {
    _generation++;
    _messagesSub?.cancel();
    _messagesSub = null;
    _conversationId = null;
    _messages = [];
    _isSending = false;
    _isLoadingHistory = false;
    _historyFailed = false;
    _error = null;
    _lastFailedText = null;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _messagesSub?.cancel();
    _messagesSub = null;
    super.dispose();
  }
}
