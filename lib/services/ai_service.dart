import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/message.dart';

class AiService {
  final String _apiKey = AppConstants.apiKey;
  final String _togetherUrl = AppConstants.togetherUrl;
  final String _model = AppConstants.model;
  final String _systemPrompt = AppConstants.systemPrompt;

  String _lastResponse = '';
  final List<Message> _conversationHistory = [];

  /// Getters for UI to access managed state
  String get lastResponse => _lastResponse;
  List<Message> get conversationHistory => List.unmodifiable(_conversationHistory);

  /// Add user message to history and call AI
  Future<String> callAiWithText(String userMessage) async {
    _conversationHistory.add(Message.user(userMessage));
    return _callAiWithHistory();
  }

  /// Call AI with photo and add to history
  Future<String> callAiWithPhoto(List<int> photoBytes) async {
    _conversationHistory.add(Message.user('[Снимка от очилата]'));
    return _callAiWithPhotoAndHistory(photoBytes);
  }

  /// Make API call with current conversation history
  Future<String> _callAiWithHistory() async {
    try {
      final messages = <Map<String, dynamic>>[
        {'role': 'system', 'content': _systemPrompt},
        ..._conversationHistory.map((m) => {
          'role': m.role,
          'content': m.content,
        }),
      ];

      final response = await http.post(
        Uri.parse(_togetherUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': AppConstants.maxTokens,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = _extractMessageContent(data);
        _lastResponse = content;
        _conversationHistory.add(Message.assistant(content));
        return content;
      }
      return 'Грешка: ${response.statusCode}';
    } catch (e) {
      return 'Грешка при свяжка: $e';
    }
  }

  /// Extract message content from Together AI response
  String _extractMessageContent(Map<String, dynamic> data) {
    try {
      // For reasoning models, extract 'content' field (actual answer, not reasoning)
      final message = data['choices'][0]['message']['content'];
      return message;
    } catch (e) {
      return 'Грешка при разбору на отговора: $e';
    }
  }

  /// Make API call with photo and current conversation history
  Future<String> _callAiWithPhotoAndHistory(List<int> photoBytes) async {
    try {
      final base64Image = base64Encode(photoBytes);

      final response = await http.post(
        Uri.parse(_togetherUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': AppConstants.maxTokens,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            ..._conversationHistory.map((m) => {
              'role': m.role,
              'content': m.content,
            }),
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
                {
                  'type': 'text',
                  'text': AppConstants.strings['photoDescription'],
                }
              ],
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = _extractMessageContent(data);
        _lastResponse = content;
        _conversationHistory.add(Message.assistant(content));
        return content;
      }
      return 'Грешка при анализ: ${response.statusCode}';
    } catch (e) {
      return 'Грешка при снимане: $e';
    }
  }

  /// Clear conversation history and last response
  void clearHistory() {
    _conversationHistory.clear();
    _lastResponse = '';
  }
}
