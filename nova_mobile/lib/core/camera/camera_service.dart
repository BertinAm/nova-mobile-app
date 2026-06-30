import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class CameraFrame {
  final Uint8List bytes;
  final int width;
  final int height;
  final DateTime timestamp;
  final String format;

  const CameraFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.timestamp,
    this.format = 'rgb',
  });
}

/// Camera wrapper used by all modules.
///
/// In simulation mode it produces synthetic 10 FPS frames, so BLoCs and
/// use-cases can be tested without real hardware or model files.
class CameraService {
  CameraController? _controller;
  CameraController? get controller => _controller;
  StreamController<CameraFrame>? _frameController;
  Timer? _simulationTimer;
  int _simulatedFrameIndex = 0;

  Future<void> initialize() async {
    if (AppConstants.simulated) return;
    if (_controller?.value.isInitialized == true) return;

    try {
      final cameras = await availableCameras();
      final rear = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        rear,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();
    } catch (e) {
      debugPrint('Camera init failed; falling back to simulation: $e');
    }
  }

  Stream<CameraFrame> frames() {
    if (AppConstants.simulated || _controller?.value.isInitialized != true) {
      return _simulatedFrames();
    }

    _frameController ??= StreamController<CameraFrame>.broadcast(
      onListen: () async {
        try {
          await _controller!.startImageStream((CameraImage image) {
            // Real devices provide YUV420. The TFLite data source should convert
            // this to RGB for model input. For now we pass the planes through so
            // integration can be completed when model output is known.
            final bytes = BytesBuilder();
            for (final plane in image.planes) {
              bytes.add(plane.bytes);
            }
            _frameController?.add(
              CameraFrame(
                bytes: bytes.toBytes(),
                width: image.width,
                height: image.height,
                timestamp: DateTime.now(),
                format: 'yuv420',
              ),
            );
          });
        } catch (e) {
          debugPrint('Camera image stream failed; using simulation: $e');
          _startSimulation(_frameController!);
        }
      },
      onCancel: () async {
        if (_controller?.value.isStreamingImages == true) {
          await _controller?.stopImageStream();
        }
      },
    );
    return _frameController!.stream;
  }

  Stream<CameraFrame> _simulatedFrames() {
    final controller = StreamController<CameraFrame>.broadcast();
    controller.onListen = () => _startSimulation(controller);
    controller.onCancel = () => _simulationTimer?.cancel();
    return controller.stream;
  }

  void _startSimulation(StreamController<CameraFrame> controller) {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.obstacleTargetFrameIntervalMs),
      (_) {
        _simulatedFrameIndex++;
        // Small byte buffer is enough for simulated data sources. Real TFLite
        // integration should use actual RGB bytes from the camera frame.
        final random = Random(_simulatedFrameIndex);
        final bytes = Uint8List.fromList(
          List<int>.generate(64, (_) => random.nextInt(255)),
        );
        if (!controller.isClosed) {
          controller.add(
            CameraFrame(
              bytes: bytes,
              width: 640,
              height: 480,
              timestamp: DateTime.now(),
            ),
          );
        }
      },
    );
  }

  Future<File?> captureStill() async {
    if (AppConstants.simulated || _controller?.value.isInitialized != true) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/nova_simulated_capture.jpg');
      // Placeholder file. Simulated data sources do not decode it.
      await file.writeAsBytes(Uint8List.fromList([0, 1, 2, 3]));
      return file;
    }

    try {
      final picture = await _controller!.takePicture();
      return File(picture.path);
    } catch (e) {
      debugPrint('Capture failed: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _simulationTimer?.cancel();
    await _frameController?.close();
    await _controller?.dispose();
  }
}
