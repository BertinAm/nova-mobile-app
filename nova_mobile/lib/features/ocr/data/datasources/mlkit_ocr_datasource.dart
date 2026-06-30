import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/ocr_result.dart';

class MlKitOcrDatasource {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<OcrResult> recognizeFromImage(File? imageFile) async {
    if (AppConstants.simulated || imageFile == null) {
      return const OcrResult(
        text: 'Welcome to NOVA. This is simulated OCR text for testing the read text feature.',
        language: 'en-CM',
        success: true,
        blockCount: 1,
      );
    }

    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognised = await _recognizer.processImage(inputImage);
      if (recognised.text.trim().isEmpty) {
        return const OcrResult(text: '', language: 'unknown', success: false);
      }
      final language = _detectLanguage(recognised.blocks);
      return OcrResult(
        text: recognised.text,
        language: language,
        success: true,
        blockCount: recognised.blocks.length,
      );
    } catch (e) {
      debugPrint('ML Kit OCR failed: $e');
      return const OcrResult(text: '', language: 'unknown', success: false);
    }
  }

  String _detectLanguage(List<TextBlock> blocks) {
    final frenchChars = RegExp(r'[àâäéèêëîïôùûüÿçœæ]', caseSensitive: false);
    var frenchScore = 0;
    for (final block in blocks) {
      if (frenchChars.hasMatch(block.text)) frenchScore++;
    }
    return frenchScore > blocks.length * 0.3 ? 'fr-CM' : 'en-CM';
  }

  Future<void> dispose() => _recognizer.close();
}
