import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Safety-first TTS wrapper.
///
/// Critical obstacle alerts interrupt scene/OCR reading, matching the NOVA
/// requirement that safety output has higher priority than normal speech.
enum TtsPriority { critical, high, normal, low }

class TtsService {
  final FlutterTts _tts;
  TtsPriority? _currentPriority;
  double _currentRate = 0.75;   // Natural, clear rate for BVI users (SRS NFR-35)
  String _currentLanguage = 'en-CM';

  TtsService({FlutterTts? flutterTts}) : _tts = flutterTts ?? FlutterTts();

  Future<void> init(String languageCode) async {
    _currentLanguage = languageCode;
    try {
      await _tts.setLanguage(languageCode);
      await _tts.setSpeechRate(_currentRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() => _currentPriority = null);
    } catch (e) {
      debugPrint('TTS init failed; app can still run in UI simulation: $e');
    }
  }

  Future<void> speak(
    String text, {
    TtsPriority priority = TtsPriority.normal,
    bool interrupt = false,
  }) async {
    if (text.trim().isEmpty) return;

    final shouldInterrupt = interrupt ||
        priority == TtsPriority.critical ||
        (priority == TtsPriority.high && _currentPriority != TtsPriority.critical);

    try {
      if (shouldInterrupt) await _tts.stop();
      _currentPriority = priority;
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $text ($e)');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } finally {
      _currentPriority = null;
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _currentRate = rate.clamp(0.5, 2.0);
    try {
      await _tts.setSpeechRate(_currentRate);
    } catch (e) {
      debugPrint('TTS rate update failed: $e');
    }
  }

  Future<void> setLanguage(String code) async {
    _currentLanguage = code;
    try {
      await _tts.setLanguage(code);
    } catch (e) {
      debugPrint('TTS language update failed: $e');
    }
  }

  String get currentLanguage => _currentLanguage;
  double get currentRate => _currentRate;
}
