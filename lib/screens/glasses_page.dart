import 'package:flutter/material.dart';
import 'package:frame_sdk/frame_sdk.dart';
import 'package:frame_sdk/camera.dart';
import 'package:frame_sdk/display.dart' hide Alignment;
import 'dart:async';
import '../constants/app_constants.dart';
import '../services/ai_service.dart';
import '../services/speech_service.dart';
import '../widgets/status_card.dart';
import '../widgets/control_row.dart';
import '../widgets/conversation_bubble.dart';
import '../widgets/action_buttons.dart';

class GlassesPage extends StatefulWidget {
  const GlassesPage({super.key});

  @override
  State<GlassesPage> createState() => _GlassesPageState();
}

class _GlassesPageState extends State<GlassesPage> {
  late Frame _frame;
  late AiService _aiService;
  late SpeechService _speechService;

  bool _isConnected = false;
  bool _isLoading = false;
  bool _isListeningForTaps = false;
  String _status = '';
  int _conversationUpdateCount = 0; // Track conversation updates for UI rebuilds
  Timer? _connectionMonitorTimer;
  late TextEditingController _textInputController;

  @override
  void initState() {
    super.initState();
    _textInputController = TextEditingController();
    _initializeServices();
    _status = AppConstants.strings['initialStatus'] ?? 'Натисни "Свържи" за да започнеш';
  }

  Future<void> _initializeServices() async {
    _aiService = AiService();
    _speechService = SpeechService();
    await _speechService.initialize();
  }

  /// Connect to Frame glasses
  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _status = AppConstants.strings['connecting'] ?? 'Свързване...';
    });

    try {
      _frame = Frame();
      final connected = await _frame.connect();

      if (connected) {
        setState(() {
          _isConnected = true;
          _isLoading = false;
          _status = AppConstants.strings['connected'] ?? 'Свързан! Готов за употреба.';
        });
        await _frame.display.showText(
          '${AppConstants.strings['connected']}\n',
          align: Alignment2D.middleCenter,
        );
        _startConnectionMonitor();
        _startTapLoop();
      } else {
        setState(() {
          _isLoading = false;
          _status = AppConstants.strings['connectionFailed'] ?? 'Неуспешно свързване. Опитай пак.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Грешка: $e';
      });
    }
  }

  /// Start connection monitoring to maintain Bluetooth connection
  void _startConnectionMonitor() {
    // Check connection every 5 seconds
    _connectionMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isConnected) {
        _connectionMonitorTimer?.cancel();
        return;
      }
      
      try {
        // Try to use the frame to check if connection is alive
        // If it fails, attempt to reconnect
        await _checkAndMaintainConnection();
      } catch (e) {
        print('Connection monitor error: $e');
      }
    });
  }

  /// Check if connection is still active and attempt reconnection if not
  Future<void> _checkAndMaintainConnection() async {
    // Simplified connection check - just verify state
    if (!_isConnected) {
      _connectionMonitorTimer?.cancel();
      return;
    }
    
    // If listener stopped but we're still connected, restart it
    if (!_isListeningForTaps && _isConnected && !_isLoading) {
      try {
        _startTapLoop();
      } catch (e) {
        print('Error restarting tap loop: $e');
      }
    }
  }

  /// Stop connection monitoring
  void _stopConnectionMonitor() {
    _connectionMonitorTimer?.cancel();
    _connectionMonitorTimer = null;
  }

  /// Start listening for tap events
  void _startTapLoop() {
    _isListeningForTaps = true;
    _tapLoop();
  }

  /// Continuous tap listener loop
  Future<void> _tapLoop() async {
    while (_isListeningForTaps && _isConnected) {
      try {
        await _frame.motion.waitForTap();
        if (!_isListeningForTaps || !_isConnected) break;
        await _startVoiceConversation();
      } catch (e) {
        // Connection might be lost
        if (mounted) {
          setState(() {
            _isListeningForTaps = false;
            if (!_isConnected) {
              _status = 'Връзката е прекъсната';
            }
          });
        }
        await Future.delayed(const Duration(milliseconds: 500));
        break;
      }
    }
  }

  /// Start voice conversation with AI
  Future<void> _startVoiceConversation() async {
    setState(() {
      _status = AppConstants.strings['listening'] ?? 'Слушам...';
      _isLoading = true;
    });
    await _frame.display.showText(
      AppConstants.strings['listening'] ?? 'Слушам...',
      align: Alignment2D.middleCenter,
    );

    final spokenText = await _speechService.listen();

    if (spokenText.isEmpty) {
      await _frame.display.showText(
        AppConstants.strings['noSpeech'] ?? 'Не чух нищо!',
        align: Alignment2D.middleCenter,
      );
      setState(() {
        _isLoading = false;
        _status = AppConstants.strings['ready'] ?? 'Готов';
      });
      return;
    }

    final response = await _aiService.callAiWithText(spokenText);

    setState(() {
      _isLoading = false;
      _status = AppConstants.strings['ready'] ?? 'Готов';
      _conversationUpdateCount++;
    });

    final displayText = response.length > AppConstants.maxDisplayLength
        ? '${response.substring(0, AppConstants.maxDisplayLength)}...'
        : response;
    await _frame.display.showText(displayText, align: Alignment2D.middleCenter);
  }

  /// Start photo conversation with AI
  Future<void> _startPhotoConversation() async {
    if (!_isConnected) return;
    setState(() {
      _status = AppConstants.strings['takingPhoto'] ?? 'Правя снимка...';
      _isLoading = true;
    });
    await _frame.display.showText(
      AppConstants.strings['takingPhoto'] ?? 'Снимам...',
      align: Alignment2D.middleCenter,
    );

    try {
      final photoBytes = await _frame.camera.takePhoto(
        autofocusSeconds: 2,
        quality: PhotoQuality.medium,
      );

      final response = await _aiService.callAiWithPhoto(photoBytes);

      setState(() {
        _isLoading = false;
        _status = AppConstants.strings['ready'] ?? 'Готов';
        _conversationUpdateCount++;
      });

      final displayText = response.length > AppConstants.maxDisplayLength
          ? '${response.substring(0, AppConstants.maxDisplayLength)}...'
          : response;
      await _frame.display.showText(displayText, align: Alignment2D.middleCenter);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '${AppConstants.strings['photoError'] ?? 'Грешка при снимане'}: $e';
      });
    }
  }

  /// Start text conversation with AI
  Future<void> _startTextConversation(String userText) async {
    if (userText.trim().isEmpty) return;
    
    setState(() {
      _status = AppConstants.strings['processing'] ?? 'Обработвам...';
      _isLoading = true;
    });

    try {
      final response = await _aiService.callAiWithText(userText);

      _textInputController.clear();

      setState(() {
        _isLoading = false;
        _status = AppConstants.strings['ready'] ?? 'Готов';
        _conversationUpdateCount++;
      });

      // If connected to glasses, display the response there too
      if (_isConnected) {
        final displayText = response.length > AppConstants.maxDisplayLength
            ? '${response.substring(0, AppConstants.maxDisplayLength)}...'
            : response;
        await _frame.display.showText(displayText, align: Alignment2D.middleCenter);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Грешка при обработка: $e';
      });
    }
  }

  /// Clear conversation history
  Future<void> _clearConversation() async {
    _aiService.clearHistory();
    setState(() {
      _status = AppConstants.strings['memoryCleared'] ?? 'Паметта е изчистена!';
    });
    if (_isConnected) {
      await _frame.display.showText(
        AppConstants.strings['newConversation'] ?? 'Нов разговор!',
        align: Alignment2D.middleCenter,
      );
    }
  }
@override
  void dispose() {
    _isListeningForTaps = false;
    _stopConnectionMonitor();
    _textInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.appTitle),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            StatusCard(
              isConnected: _isConnected,
              status: _status,
              isLoading: _isLoading,
              lastResponse: _aiService.lastResponse,
            ),
            const SizedBox(height: 16),

            // Connect Button
            if (!_isConnected)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _connect,
                icon: const Icon(Icons.bluetooth),
                label: Text(AppConstants.strings['connectButton'] ?? 'Свържи с очилата'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),

            // Disconnect Button
            if (_isConnected)
              ElevatedButton.icon(
                onPressed: () {
                  _stopConnectionMonitor();
                  _isListeningForTaps = false;
                  setState(() {
                    _isConnected = false;
                    _status = 'Отключен от очилата';
                  });
                },
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Отключи'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),

            // Controls
            if (_isConnected) ...[
              Text(
                AppConstants.strings['controls'] ?? 'Контроли:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ControlRow(
                    emoji: '👆',
                    tapDescription: AppConstants.strings['tapControl'] ?? '1 докосване на очилата',
                    actionDescription: AppConstants.strings['tapAction'] ?? 'Гласов разговор с AI',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ActionButtons(
                onVoice: _isLoading ? () {} : _startVoiceConversation,
                onPhoto: _isLoading ? () {} : _startPhotoConversation,
                onClear: _isLoading ? () {} : _clearConversation,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
            ],

            // Text Input Section (Always available)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textInputController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: 'Напиши съобщение...',
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        maxLines: null,
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading
                          ? null
                          : () => _startTextConversation(_textInputController.text),
                      icon: const Icon(Icons.send),
                      color: Colors.deepPurple,
                      disabledColor: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_aiService.conversationHistory.isNotEmpty) ...[
              Text(
                AppConstants.strings['conversation'] ?? 'Разговор:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  key: Key(_conversationUpdateCount.toString()),
                  itemCount: _aiService.conversationHistory.length,
                  itemBuilder: (ctx, i) {
                    final msg = _aiService.conversationHistory[i];
                    final isUser = msg.role == 'user';
                    return ConversationBubble(
                      message: msg.content,
                      isUser: isUser,
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
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
}
