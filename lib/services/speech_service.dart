import 'package:speech_to_text/speech_to_text.dart';
import '../constants/app_constants.dart';

class SpeechService {
  final SpeechToText _speech;

  SpeechService({SpeechToText? speechToText}) : _speech = speechToText ?? SpeechToText();

  /// Initialize speech recognition
  Future<void> initialize() async {
    await _speech.initialize();
  }

  /// Listen for speech input
  /// Returns the recognized text
  Future<String> listen() async {
    String spokenText = '';

    await _speech.listen(
      onResult: (result) {
        spokenText = result.recognizedWords;
      },
      listenFor: AppConstants.speechListenDuration,
    );

    // Wait for the full duration
    await Future.delayed(AppConstants.speechListenDuration);
    await _speech.stop();

    return spokenText;
  }

  /// Stop listening
  Future<void> stop() async {
    await _speech.stop();
  }

  /// Check if speech recognition is available
  Future<bool> isAvailable() async {
    return await _speech.initialize();
  }
}
