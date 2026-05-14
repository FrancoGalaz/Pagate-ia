import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/ai_service.dart';
import '../../../../features/finances/domain/entities/finances_summary_entity.dart';
import '../../../../features/finances/domain/entities/finances_transaction_entity.dart';
import '../../../../features/inventory/domain/entities/inventory_item_entity.dart';
import '../../../../features/hourly_value/domain/entities/hourly_rate_entity.dart';
import '../../../../features/user_profile/domain/entities/user_profile_entity.dart';

/// Manages the AI chat state and delegates to AiService.
///
/// Provides conversation history, streaming state, and
/// automatically enriches prompts with the user's financial context.
/// Persists chat history to Firestore for cross-session continuity.
class AiProvider extends ChangeNotifier {
  final AiService _service;
  final FirebaseFirestore _firestore;

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String _userId = 'anonymous';

  // Context passed in from other providers
  UserProfileEntity? _profile;
  FinancesSummaryEntity? _currentSummary;
  List<FinancesTransactionEntity> _recentTransactions = [];
  List<InventoryItemEntity> _inventoryItems = [];
  HourlyRateEntity? _hourlyRate;
  List<FinancesSummaryEntity> _allMonths = [];
  String _currency = 'MXN';

  AiProvider({
    required AiService service,
    FirebaseFirestore? firestore,
  })  : _service = service,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // ─── Getters ───────────────────────────────────────────────────────

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isReady => _service.hasApiKey;

  // ─── Context injection ─────────────────────────────────────────────

  void updateContext({
    UserProfileEntity? profile,
    FinancesSummaryEntity? currentSummary,
    List<FinancesTransactionEntity>? recentTransactions,
    List<InventoryItemEntity>? inventoryItems,
    HourlyRateEntity? hourlyRate,
    List<FinancesSummaryEntity>? allMonths,
    String? currency,
  }) {
    _profile = profile;
    _currentSummary = currentSummary;
    _recentTransactions = recentTransactions ?? [];
    _inventoryItems = inventoryItems ?? [];
    _hourlyRate = hourlyRate;
    _allMonths = allMonths ?? [];
    _currency = currency ?? 'MXN';
  }

  /// Sets the userId and loads persisted chat history.
  void setUserId(String userId) {
    if (_userId == userId) return;
    _userId = userId;
    if (_isInitialized) {
      _loadChatHistory();
    }
  }

  // ─── Chat history persistence ──────────────────────────────────────

  String get _chatCollection =>
      'ai_${_userId}_conversations';

  String get _activeSessionId {
    // Derive session ID from current date (one session per day)
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveMessageToFirestore(ChatMessage message) async {
    try {
      await _firestore
          .collection(_chatCollection)
          .doc(_activeSessionId)
          .collection('messages')
          .add({
        'text': message.text,
        'isAi': message.isAi,
        'timestamp': FieldValue.serverTimestamp(),
        'role': message.isAi ? 'assistant' : 'user',
      });
    } catch (_) {
      // Silently fail — chat should work even offline
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final snapshot = await _firestore
          .collection(_chatCollection)
          .doc(_activeSessionId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .limit(50)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _messages = snapshot.docs.map((doc) {
          final data = doc.data();
          return ChatMessage(
            text: data['text'] as String? ?? '',
            isAi: data['isAi'] as bool? ?? data['role'] == 'assistant',
          );
        }).toList();
        notifyListeners();
      }
    } catch (_) {
      // Silently fail — start fresh if can't load history
    }
  }

  // ─── Chat actions ──────────────────────────────────────────────────

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Load saved chat history if userId is set
    if (_userId != 'anonymous') {
      _loadChatHistory();
      return;
    }

    _showWelcomeMessage();
  }

  void _showWelcomeMessage() {
    final hasContext = _profile != null || _currentSummary != null ||
        _recentTransactions.isNotEmpty || _inventoryItems.isNotEmpty;

    _messages = [
      ChatMessage(
        text: hasContext
            ? '¡Hola! Soy tu asistente financiero Págate-IA.\n\n'
                'Tengo acceso a tus datos financieros, inventario y más. '
                'Pregúntame sobre tus finanzas, precios, inventario, '
                'o pide consejo para hacer crecer tu negocio.'
            : '¡Hola! Soy tu asistente de IA para Págate-IA.\n\n'
                'Completa tu perfil y registra tus primeros datos '
                'en Finanzas para que pueda ayudarte mejor.',
        isAi: true,
      ),
    ];
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    // Add user message
    final userMsg = ChatMessage(text: text.trim(), isAi: false);
    _messages.add(userMsg);
    _isLoading = true;
    notifyListeners();

    // Persist user message
    if (_userId != 'anonymous') {
      _saveMessageToFirestore(userMsg);
    }

    // Build enriched system prompt with all available context
    final systemPrompt = AiService.systemPromptWithContext(
      businessName: _profile?.businessName,
      businessType: _profile?.businessType,
      monthlyGoal: _currentSummary?.monthlyGoal,
      monthlyIncome: _currentSummary?.totalIncome,
      monthlyExpenses: _currentSummary?.totalExpenses,
      recentTransactions: _recentTransactions.take(5).toList(),
      inventoryCount: _inventoryItems.length,
      productsCount: _inventoryItems
          .where((i) => i.type.name == 'product')
          .length,
      materialsCount: _inventoryItems
          .where((i) => i.type.name == 'material')
          .length,
      hourlyRate: _hourlyRate?.hourlyValue,
      currency: _currency,
      monthsAvailable: _allMonths.length,
      latestMonthIncome: _allMonths.isNotEmpty
          ? _allMonths.first.totalIncome
          : null,
      latestMonthExpenses: _allMonths.isNotEmpty
          ? _allMonths.first.totalExpenses
          : null,
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

    final aiMsg = ChatMessage(
      text: reply ?? '⚠️ No se pudo obtener respuesta. Intenta de nuevo.',
      isAi: true,
    );
    _messages.add(aiMsg);
    _isLoading = false;
    notifyListeners();

    // Persist AI response
    if (_userId != 'anonymous') {
      _saveMessageToFirestore(aiMsg);
    }
  }

  void clearChat() {
    _messages = [];
    _isInitialized = false;
    _showWelcomeMessage();
  }
}

/// A single chat message in the conversation.
class ChatMessage {
  final String text;
  final bool isAi;

  const ChatMessage({required this.text, required this.isAi});
}
