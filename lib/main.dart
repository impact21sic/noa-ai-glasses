import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frame_sdk/frame_sdk.dart';
import 'package:frame_sdk/bluetooth.dart';
import 'package:frame_sdk/camera.dart';
import 'package:frame_sdk/display.dart' hide Alignment;
import 'package:frame_sdk/motion.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BrilliantBluetooth.requestPermission();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOA AI Glasses',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
      home: const GlassesPage(),
    );
  }
}

class GlassesPage extends StatefulWidget {
  const GlassesPage({super.key});
  @override
  State<GlassesPage> createState() => _GlassesPageState();
}

class _GlassesPageState extends State<GlassesPage> {
  late Frame _frame;
  bool _isConnected = false;
  bool _isLoading = false;
  bool _isListeningForTaps = false;
  String _status = 'Натисни "Свържи" за да започнеш';
  String _lastResponse = '';
  final List<Map<String, String>> _conversationHistory = [];

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  // ── СЛАГАШ ТВОЯ GEMINI API KEY ТУК ──
  static const String _apiKey = 'YOUR_KEY_HERE';
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static const String _systemPrompt =
      'Ти си полезен AI асистент на умни очила. Отговаряй кратко (1-3 изречения) на български език.';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('bg-BG');
    await _tts.setSpeechRate(0.9);
  }

  // ── Свържи се с очилата ──
  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _status = 'Свързване...';
    });

    try {
      _frame = Frame();
      final connected = await _frame.connect();

      if (connected) {
        setState(() {
          _isConnected = true;
          _isLoading = false;
          _status = 'Свързан! Готов за употреба.';
        });
        await _frame.display.showText('Свързан!\nГотов.', align: Alignment2D.middleCenter);
        _startTapLoop();
      } else {
        setState(() {
          _isLoading = false;
          _status = 'Неуспешно свързване. Опитай пак.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Грешка: $e';
      });
    }
  }

  // ── Слушай за докосвания в цикъл ──
  void _startTapLoop() {
    _isListeningForTaps = true;
    _tapLoop();
  }

  Future<void> _tapLoop() async {
    while (_isListeningForTaps && _isConnected) {
      try {
        await _frame.motion.waitForTap();
        if (!_isListeningForTaps) break;
        await _startVoiceConversation();
      } catch (e) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  // ── 1 ДОКОСВАНЕ: Гласов разговор с AI ──
  Future<void> _startVoiceConversation() async {
    setState(() { _status = 'Слушам...'; _isLoading = true; });
    await _frame.display.showText('Слушам...', align: Alignment2D.middleCenter);

    String spokenText = '';
    await _speech.listen(
      onResult: (result) { spokenText = result.recognizedWords; },
      listenFor: const Duration(seconds: 8),
    );
    await Future.delayed(const Duration(seconds: 8));
    await _speech.stop();

    if (spokenText.isEmpty) {
      await _frame.display.showText('Не чух нищо!', align: Alignment2D.middleCenter);
      setState(() { _isLoading = false; _status = 'Готов'; });
      return;
    }

    setState(() => _status = 'Мисля...');
    await _frame.display.showText('Мисля...', align: Alignment2D.middleCenter);

    _conversationHistory.add({'role': 'user', 'content': spokenText});
    final response = await _callGemini();
    _conversationHistory.add({'role': 'assistant', 'content': response});

    setState(() { _lastResponse = response; _isLoading = false; _status = 'Готов'; });

    final displayText = response.length > 150 ? '${response.substring(0, 150)}...' : response;
    await _frame.display.showText(displayText, align: Alignment2D.middleCenter);
    await _tts.speak(response);
  }

  // ── Снимка + AI ──
  Future<void> _startPhotoConversation() async {
    if (!_isConnected) return;
    setState(() { _status = 'Правя снимка...'; _isLoading = true; });
    await _frame.display.showText('Снимам...', align: Alignment2D.middleCenter);

    try {
      final photoBytes = await _frame.camera.takePhoto(
        autofocusSeconds: 2,
        quality: PhotoQuality.medium,
      );

      setState(() => _status = 'Анализирам...');
      await _frame.display.showText('Анализирам...', align: Alignment2D.middleCenter);

      final response = await _callGeminiWithPhoto(photoBytes);
      _conversationHistory.add({'role': 'user', 'content': '[Снимка от очилата]'});
      _conversationHistory.add({'role': 'assistant', 'content': response});

      setState(() { _lastResponse = response; _isLoading = false; _status = 'Готов'; });

      final displayText = response.length > 150 ? '${response.substring(0, 150)}...' : response;
      await _frame.display.showText(displayText, align: Alignment2D.middleCenter);
      await _tts.speak(response);
    } catch (e) {
      setState(() { _isLoading = false; _status = 'Грешка при снимане: $e'; });
    }
  }

  // ── Изчисти паметта ──
  Future<void> _clearConversation() async {
    _conversationHistory.clear();
    setState(() { _status = 'Паметта е изчистена!'; _lastResponse = ''; });
    if (_isConnected) {
      await _frame.display.showText('Нов разговор!', align: Alignment2D.middleCenter);
    }
    await _tts.speak('Паметта е изчистена.');
  }

  // ── Gemini API (само текст) ──
  Future<String> _callGemini() async {
    try {
      // Изгради историята на разговора за Gemini
      final contents = _conversationHistory.map((m) => {
        'role': m['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': m['content']}],
      }).toList();

      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [{'text': _systemPrompt}]
          },
          'contents': contents,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      }
      return 'Грешка: ${response.statusCode} - ${response.body}';
    } catch (e) {
      return 'Грешка: $e';
    }
  }

  // ── Gemini API (снимка) ──
  Future<String> _callGeminiWithPhoto(List<int> photoBytes) async {
    try {
      final base64Image = base64Encode(photoBytes);

      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {
            'parts': [{'text': _systemPrompt}]
          },
          'contents': [
            {
              'parts': [
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                },
                {'text': 'Какво виждаш на тази снимка от моите умни очила? Бъди кратък.'}
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'] as String;
      }
      return 'Грешка при анализ: ${response.statusCode}';
    } catch (e) {
      return 'Грешка: $e';
    }
  }

  @override
  void dispose() {
    _isListeningForTaps = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NOA AI Очила'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Статус карта
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_status, style: const TextStyle(fontSize: 16))),
                        if (_isLoading)
                          const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    if (_lastResponse.isNotEmpty) ...[
                      const Divider(),
                      const Text('Последен отговор:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(_lastResponse),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Бутон за свързване
            if (!_isConnected)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _connect,
                icon: const Icon(Icons.bluetooth),
                label: const Text('Свържи с очилата'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),

            // Контроли
            if (_isConnected) ...[
              const Text('Контроли:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildControlRow('👆', '1 докосване на очилата', 'Гласов разговор с AI'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _startVoiceConversation,
                      icon: const Icon(Icons.mic),
                      label: const Text('Тест: Глас'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _startPhotoConversation,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Тест: Снимка'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _clearConversation,
                      icon: const Icon(Icons.delete),
                      label: const Text('Изчисти'),
                    ),
                  ),
                ],
              ),
            ],

            // История
            const SizedBox(height: 16),
            if (_conversationHistory.isNotEmpty) ...[
              const Text('Разговор:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _conversationHistory.length,
                  itemBuilder: (ctx, i) {
                    final msg = _conversationHistory[i];
                    final isUser = msg['role'] == 'user';
                    return Align(
                      alignment: isUser ? Alignment.topRight : Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.deepPurple[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg['content'] ?? ''),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlRow(String emoji, String tap, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tap, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(action, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}