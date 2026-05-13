import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/services/ai_service.dart';
import '../../finances/domain/entities/finances_summary_entity.dart';
import '../../user_profile/domain/entities/user_profile_entity.dart';

/// Manages the AI chat state and delegates to AiService.
///
/// Provides conversation history, streaming state, and
/// automatically enriches prompts with the user's financial context.
class AiProvider extends ChangeNotifier {
  final AiService _service;

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  // Context passed in from other providers
  UserProfileEntity? _profile;
  FinancesSummaryEntity? _currentSummary;

  AiProvider({required AiService service}) : _service = service;

  // ─── Getters ───────────────────────────────────────────────────────

  List<_ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isReady => _service.hasApiKey;
  String get _suggestionIfNoData =>
      _profile == null || _currentSummary == null;

  // ─── Context injection ─────────────────────────────────────────────

  void updateContext({
    UserProfileEntity? profile,
    FinancesSummaryEntity? currentSummary,
  }) {
    _profile = profile;
    _currentSummary = currentSummary;
  }

  // ─── Chat actions ──────────────────────────────────────────────────

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    _messages = [
      ChatMessage(
        text: _suggestionIfNoData
            ? '¡Hola! Soy tu asistente de IA para Págate-IA.\n\n'
                'Completa tu perfil y registra tus primeros datos '
                'en Finanzas para que pueda ayudarte mejor.'
            : '¡Hola! Soy tu asistente de IA para Págate-IA.\n\n'
                'Puedo ayudarte a analizar tus finanzas, '
                'dar sugerencias de precios, '
                'y optimizar tu inventario. ¿En qué te ayudo hoy?',
        isAi: true,
      ),
    ];
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    // Add user message
    _messages.add(ChatMessage(text: text.trim(), isAi: false));
    _isLoading = true;
    notifyListeners();

    // Build context-aware system prompt
    final systemPrompt = AiService.systemPromptWithContext(
      businessName: _profile?.businessName,
      businessType: _profile?.businessType,
      monthlyGoal: _currentSummary?.monthlyGoal,
      monthlyIncome: _currentSummary?.totalIncome,
      monthlyExpenses: _currentSummary?.totalExpenses,
    );

    // Prepare conversation history for the API
    final apiMessages = _messages
        .map((m) => {
              'role': m.isAi ? 'assistant' : 'user',
              'content': m.text,
            })
        .toList();

    // Call the AI service
    final reply = await _service.sendMessage(
      messages: apiMessages,
      systemPrompt: systemPrompt,
    );

    // Add AI response
    _messages.add(ChatMessage(
      text: reply ?? '⚠️ No se pudo obtener respuesta. Intenta de nuevo.',
      isAi: true,
    ));
    _isLoading = false;
    notifyListeners();
  }

  void clearChat() {
    _messages = [];
    _isInitialized = false;
    init();
  }
}

/// A single chat message in the conversation.
class ChatMessage {
  final String text;
  final bool isAi;

  const ChatMessage({required this.text, required this.isAi});
}
