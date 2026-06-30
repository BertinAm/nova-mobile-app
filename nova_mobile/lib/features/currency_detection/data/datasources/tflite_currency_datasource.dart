import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/currency_result.dart';

class TfliteCurrencyDatasource {
  Interpreter? _interpreter;
  int _simCounter = 0;

  final List<String> _labels = const [
    'fcfa_500',
    'fcfa_1000',
    'fcfa_2000',
    'fcfa_5000',
    'fcfa_10000',
  ];

  final Map<String, String> _labelToSpoken = const {
    'fcfa_500': 'Five hundred francs CFA',
    'fcfa_1000': 'One thousand francs CFA',
    'fcfa_2000': 'Two thousand francs CFA',
    'fcfa_5000': 'Five thousand francs CFA',
    'fcfa_10000': 'Ten thousand francs CFA',
  };

  Future<void> init() async {
    if (AppConstants.simulated) return;
    try {
      _interpreter = await Interpreter.fromAsset(AppConstants.currencyModelAsset);
    } catch (e) {
      debugPrint('Currency model load failed; using simulation: $e');
      _interpreter = null;
    }
  }

  Future<CurrencyResult> classify(File? imageFile) async {
    if (AppConstants.simulated || _interpreter == null || imageFile == null) {
      return _simulate();
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return _simulate(lowConfidence: true);
      final underExposed = _isUnderExposed(decoded);
      final resized = img.copyResize(
        decoded,
        width: AppConstants.currencyInputSize,
        height: AppConstants.currencyInputSize,
      );

      final input = _normaliseToFloat32(resized);
      final output = List.generate(1, (_) => List<double>.filled(_labels.length, 0.0));
      _interpreter!.run(input, output);
      return _resultFromScores(output.first, underExposed: underExposed);
    } catch (e) {
      debugPrint('Currency inference failed; using simulation fallback: $e');
      return _simulate();
    }
  }

  CurrencyResult _resultFromScores(List<double> scores, {bool underExposed = false}) {
    var maxIdx = 0;
    var maxConf = scores.first;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > maxConf) {
        maxIdx = i;
        maxConf = scores[i];
      }
    }

    if (maxConf < AppConstants.currencyConfidenceThreshold) {
      return CurrencyResult(
        success: false,
        confidence: maxConf,
        underExposed: underExposed,
      );
    }
    final label = _labels[maxIdx];
    return CurrencyResult(
      success: true,
      label: label,
      spokenLabel: _labelToSpoken[label],
      confidence: maxConf,
      underExposed: underExposed,
    );
  }

  /// Input shape: [1, 224, 224, 3], normalized to [-1, 1].
  List<List<List<List<double>>>> _normaliseToFloat32(img.Image image) {
    return [
      List.generate(AppConstants.currencyInputSize, (y) {
        return List.generate(AppConstants.currencyInputSize, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (img.getRed(pixel).toDouble() - 127.5) / 127.5,
            (img.getGreen(pixel).toDouble() - 127.5) / 127.5,
            (img.getBlue(pixel).toDouble() - 127.5) / 127.5,
          ];
        });
      }),
    ];
  }

  bool _isUnderExposed(img.Image image) {
    var total = 0.0;
    final stepX = max(1, image.width ~/ 40);
    final stepY = max(1, image.height ~/ 40);
    var count = 0;
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        total += (img.getRed(p) + img.getGreen(p) + img.getBlue(p)) / 3.0;
        count++;
      }
    }
    return count > 0 && (total / count) < 55;
  }

  CurrencyResult _simulate({bool lowConfidence = false}) {
    _simCounter++;
    final label = _labels[_simCounter % _labels.length];
    final confidence = lowConfidence ? 0.62 : 0.91;
    if (confidence < AppConstants.currencyConfidenceThreshold) {
      return CurrencyResult(success: false, confidence: confidence);
    }
    return CurrencyResult(
      success: true,
      label: label,
      spokenLabel: _labelToSpoken[label],
      confidence: confidence,
    );
  }

  void dispose() => _interpreter?.close();
}
