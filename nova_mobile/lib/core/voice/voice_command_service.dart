import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceCommandRouter {
  final _controller = StreamController<VoiceCommand>.broadcast();

  Stream<VoiceCommand> get commands => _controller.stream;

  void dispatch(VoiceCommand command) => _controller.add(command);

  void dispose() => _controller.close();
}

class VoiceCommandService {
  final SpeechToText _speech;
  final VoiceCommandRouter _router;

  VoiceCommandService(this._router, {SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  static const Map<String, VoiceCommand> _commands = {
    'start obstacle': VoiceCommand.startObstacle,
    'stop obstacle': VoiceCommand.stopObstacle,
    'read text': VoiceCommand.readText,
    'lire texte': VoiceCommand.readText,
    'describe scene': VoiceCommand.describeScene,
    'décrire scène': VoiceCommand.describeScene,
    'identify money': VoiceCommand.identifyMoney,
    'check note': VoiceCommand.identifyMoney,
    'identifier argent': VoiceCommand.identifyMoney,
    'who is this': VoiceCommand.recogniseFace,
    'qui est': VoiceCommand.recogniseFace,
    'call for help': VoiceCommand.emergency,
    'au secours': VoiceCommand.emergency,
    'slow down': VoiceCommand.slowTts,
    'speed up': VoiceCommand.speedUpTts,
    'stop': VoiceCommand.stopTts,
  };

  Future<void> init(String locale) async {
    try {
      await _speech.initialize(
        onError: (err) => debugPrint('Speech error: $err'),
        debugLogging: false,
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  void startListening({String localeId = 'en_CM'}) {
    try {
      _speech.listen(
        onResult: (result) {
          if (!result.finalResult) return;
          _processTranscript(result.recognizedWords.toLowerCase());
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        localeId: localeId,
      );
    } catch (e) {
      debugPrint('Speech listen failed: $e');
    }
  }

  void stopListening() {
    _speech.stop();
  }

  @visibleForTesting
  void processTranscriptForTest(String transcript) =>
      _processTranscript(transcript.toLowerCase());

  void _processTranscript(String transcript) {
    for (final entry in _commands.entries) {
      if (transcript.contains(entry.key)) {
        _router.dispatch(entry.value);
        return;
      }
    }
  }
}

enum VoiceCommand {
  startObstacle,
  stopObstacle,
  readText,
  describeScene,
  identifyMoney,
  recogniseFace,
  emergency,
  slowTts,
  speedUpTts,
  stopTts,
}
