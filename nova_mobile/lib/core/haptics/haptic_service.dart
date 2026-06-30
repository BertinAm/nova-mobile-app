import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

class HapticService {
  Future<void> warning() async {
    await _vibrate(pattern: [0, 120, 80, 120]);
  }

  Future<void> critical() async {
    await _vibrate(pattern: [0, 250, 90, 250, 90, 250]);
  }

  Future<void> success() async {
    await _vibrate(duration: 80);
  }

  Future<void> _vibrate({int? duration, List<int>? pattern}) async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (!hasVibrator) return;
      if (pattern != null) {
        await Vibration.vibrate(pattern: pattern);
      } else {
        await Vibration.vibrate(duration: duration ?? 100);
      }
    } catch (e) {
      debugPrint('Vibration unavailable: $e');
    }
  }
}
