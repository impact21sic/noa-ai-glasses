import 'package:flutter_tts/flutter_tts.dart';
import '../constants/app_constants.dart';

class TtsService {
  final FlutterTts _tts;

  TtsService({FlutterTts? flutterTts}) : _tts = flutterTts ?? FlutterTts();

  /// Initialize text-to-speech
  Future<void> initialize() async {
    await _tts.setLanguage(AppConstants.language);
    await _tts.setSpeechRate(0.9);
  }

  /// Speak text
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  /// Stop speaking
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Set language
  Future<void> setLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }

  /// Set speech rate (0.0 to 2.0)
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }
}
