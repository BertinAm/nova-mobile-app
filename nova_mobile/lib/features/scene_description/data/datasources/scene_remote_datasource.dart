import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../../../core/constants/app_constants.dart';

class SceneRemoteDatasource {
  final Dio _dio;

  SceneRemoteDatasource(this._dio);

  Future<String> describeScene(File? imageFile) async {
    if (AppConstants.simulated || imageFile == null) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      return 'A clear walkway is ahead. There may be a person slightly to the left and a table on the right.';
    }

    final compressed = await _compressImage(imageFile);
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(compressed, filename: 'scene.jpg'),
    });

    final response = await _dio
        .post(AppConstants.sceneDescribePath, data: formData)
        .timeout(const Duration(seconds: 8));
    return response.data['description'] as String;
  }

  Future<List<int>> _compressImage(File file) async {
    try {
      final original = img.decodeImage(await file.readAsBytes());
      if (original == null) return await file.readAsBytes();

      final resized = original.width > original.height
          ? img.copyResize(original, width: 800)
          : img.copyResize(original, height: 800);

      var quality = 75;
      var encoded = img.encodeJpg(resized, quality: quality);
      while (encoded.length > 512 * 1024 && quality > 35) {
        quality -= 10;
        encoded = img.encodeJpg(resized, quality: quality);
      }
      return encoded;
    } catch (e) {
      debugPrint('Scene image compression failed: $e');
      return file.readAsBytes();
    }
  }
}
