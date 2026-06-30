import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/obstacle_detection_result.dart';
import '../models/raw_detection_model.dart';

class TfliteObstacleDatasource {
  Interpreter? _interpreter;
  List<String> _labels = const [];
  int _simCounter = 0;

  static const Map<String, double> _referenceWidths = {
    'person': 0.5,
    'car': 1.8,
    'motorcycle': 0.8,
    'bicycle': 0.6,
    'bus': 2.5,
    'truck': 2.4,
    'chair': 0.5,
    'dining table': 1.2,
    'open_drain': 0.8,
    'market_stall': 2.0,
    'low_hanging_sign': 1.2,
  };

  Future<void> init() async {
    _labels = await _loadLabels();
    if (AppConstants.simulated) return;

    try {
      final options = InterpreterOptions()..threads = 2;
      // NnApiDelegate is removed/unavailable in this tflite_flutter version.
      _interpreter = await Interpreter.fromAsset(
        AppConstants.obstacleModelAsset,
        options: options,
      );
    } catch (e) {
      debugPrint('Obstacle TFLite load failed; using simulation: $e');
      _interpreter = null;
    }
  }

  Future<List<DetectedObstacle>> detect(CameraFrame frame) async {
    if (_interpreter == null || AppConstants.simulated) {
      return _simulate(frame);
    }

    try {
      return _runRealInference(frame);
    } catch (e) {
      debugPrint('Obstacle inference failed; simulation fallback: $e');
      return _simulate(frame);
    }
  }

  Future<List<String>> _loadLabels() async {
    try {
      final data = await rootBundle.loadString(AppConstants.cocoLabelsAsset);
      return data
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return ['person', 'car', 'motorcycle', 'open_drain', 'market_stall'];
    }
  }

  List<DetectedObstacle> _runRealInference(CameraFrame frame) {
    // Integration point:
    // 1. Convert YUV420/RGB frame bytes to RGB.
    // 2. Resize to 320x320.
    // 3. Quantize to the input tensor type (usually uint8/int8).
    // 4. Decode your exported TFLite output.
    //
    // The model guide allows YOLOv8n or MobileNetV3-SSD. SSD commonly returns
    // boxes/classes/scores/count; YOLOv8 usually returns a single tensor that
    // requires NMS. Keep this function as the only model-specific code path.
    return _simulate(frame);
  }

  List<DetectedObstacle> _simulate(CameraFrame frame) {
    _simCounter++;
    final cycle = _simCounter % 45;
    final simulatedRaw = <RawDetectionModel>[];

    if (cycle < 12) {
      simulatedRaw.add(
        const RawDetectionModel(
          label: 'person',
          confidence: 0.86,
          top: 0.10,
          left: 0.40,
          bottom: 0.92,
          right: 0.62,
        ),
      );
    } else if (cycle < 24) {
      simulatedRaw.add(
        const RawDetectionModel(
          label: 'motorcycle',
          confidence: 0.78,
          top: 0.20,
          left: 0.02,
          bottom: 0.90,
          right: 0.34,
        ),
      );
    } else if (cycle < 35) {
      simulatedRaw.add(
        const RawDetectionModel(
          label: 'open_drain',
          confidence: 0.74,
          top: 0.70,
          left: 0.48,
          bottom: 0.98,
          right: 0.90,
        ),
      );
    }

    return simulatedRaw
        .where((r) => r.confidence >= AppConstants.obstacleConfidenceThreshold)
        .map((r) {
      final distance = _estimateDistance(r.label, r.widthNorm, frame.width);
      final zone = _classifyZone(distance);
      final direction = _classifyDirection(r.left, r.right);
      return DetectedObstacle(
        label: r.label.replaceAll('_', ' '),
        confidence: r.confidence,
        zone: zone,
        direction: direction,
        estimatedDistanceMeters: distance,
        trackingId: '${r.label}-${direction.name}',
      );
    }).toList();
  }

  double _estimateDistance(String label, double boxWidthNorm, int frameWidth) {
    final refWidth = _referenceWidths[label] ?? 0.5;
    const focalLengthPixels = 600.0;
    final pixelWidth = max(1.0, boxWidthNorm * frameWidth);
    return (focalLengthPixels * refWidth) / pixelWidth;
  }

  ObstacleZone _classifyZone(double distanceM) {
    if (distanceM <= AppConstants.nearThresholdMeters) return ObstacleZone.near;
    if (distanceM <= AppConstants.warningThresholdMeters) {
      return ObstacleZone.warning;
    }
    return ObstacleZone.clear;
  }

  ObstacleDirection _classifyDirection(double left, double right) {
    final center = (left + right) / 2;
    if (center < 0.33) return ObstacleDirection.left;
    if (center > 0.67) return ObstacleDirection.right;
    return ObstacleDirection.center;
  }

  void dispose() => _interpreter?.close();
}
