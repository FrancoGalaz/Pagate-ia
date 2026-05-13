import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Service that calls OpenRouter API for the AI assistant.
///
/// API key configuration (in priority order):
/// 1. --dart-define=OPENROUTER_API_KEY=sk-or-...
/// 2. OPENROUTER_API_KEY environment variable
/// 3. Fallback value from String.fromEnvironment (compile-time)
///
/// In production, consider using Firebase Functions as a proxy
/// to avoid exposing the API key to the client.
class AiService {
  static const String _defaultBaseUrl = 'https://openrouter.ai/api/v1';
  static const String _defaultModel = 'deepseek/deepseek-v4-flash';

  final String _apiKey;
  final String _baseUrl;
  final String _model;
  final http.Client _client;

  AiService({
    String? apiKey,
    String? baseUrl,
    String? model,
    http.Client? client,
  })  : _apiKey = apiKey ??
            const String.fromEnvironment(
              'OPENROUTER_API_KEY',
              defaultValue: '',
            ),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'OPENROUTER_BASE_URL',
              defaultValue: _defaultBaseUrl,
            ),
        _model = model ??
            const String.fromEnvironment(
              'OPENROUTER_MODEL',
              defaultValue: _defaultModel,
            ),
        _client = client ?? http.Client();

  bool get hasApiKey => _apiKey.isNotEmpty;

  /// Sends a chat completion request to OpenRouter.
  ///
  /// [messages] — the conversation history.
  /// [systemPrompt] — the system-level instruction.
  /// Returns the assistant's reply text, or null on failure.
  Future<String?> sendMessage({
    required List<Map<String, String>> messages,
    String? systemPrompt,
  }) async {
    if (!hasApiKey) {
      return '⚠️ IA no configurada. Configura OPENROUTER_API_KEY '
          'al compilar con --dart-define=OPENROUTER_API_KEY=sk-or-...';
    }

    final body = {
      'model': _model,
      'messages': [
        if (systemPrompt != null)
          {'role': 'system', 'content': systemPrompt},
        ...messages,
      ],
      'temperature': 0.7,
      'max_tokens': 1024,
    };

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://pagate-ia.app',
              'X-Title': 'Pagate-IA',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          return message?['content'] as String?;
        }
        return '⚠️ No se recibió respuesta del asistente.';
      } else {
        return '⚠️ Error del servidor (${response.statusCode}). '
            'Intenta de nuevo más tarde.';
      }
    } on SocketException {
      return '⚠️ Sin conexión a internet. '
          'Revisa tu conexión e intenta de nuevo.';
    } on http.ClientException {
      return '⚠️ Error de conexión. Verifica tu red.';
    } catch (e) {
      return '⚠️ Error inesperado: $e';
    }
  }

  /// Builds a default system prompt with financial context.
  static String systemPromptWithContext({
    String? businessName,
    String? businessType,
    double? monthlyGoal,
    double? monthlyIncome,
    double? monthlyExpenses,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Eres Págate-IA, un asistente financiero amigable y experto '
      'para artesanos y pequeños talleres latinoamericanos.',
    );
    buffer.writeln(
      'Hablas español neutro, eres directo y práctico. '
      'Ayudas al usuario a entender sus finanzas, '
      'optimizar precios y tomar mejores decisiones.',
    );

    if (businessName != null || businessType != null) {
      buffer.writeln('');
      buffer.writeln('Contexto del negocio del usuario:');
    }
    if (businessName != null) {
      buffer.writeln('- Nombre del negocio: $businessName');
    }
    if (businessType != null) {
      buffer.writeln('- Tipo: $businessType');
    }
    if (monthlyGoal != null) {
      buffer.writeln('- Meta mensual: \$${monthlyGoal.toStringAsFixed(0)}');
    }
    if (monthlyIncome != null) {
      buffer.writeln('- Ingresos del mes: \$${monthlyIncome.toStringAsFixed(0)}');
    }
    if (monthlyExpenses != null) {
      buffer.writeln(
        '- Gastos del mes: \$${monthlyExpenses.toStringAsFixed(0)}',
      );
    }

    buffer.writeln('');
    buffer.writeln(
      'Sé conciso (máximo 3 párrafos). '
      'Usa números concretos cuando sea posible. '
      'No inventes datos que no estén en el contexto. '
      'Si no sabes algo, dilo honestamente.',
    );

    return buffer.toString();
  }
}
