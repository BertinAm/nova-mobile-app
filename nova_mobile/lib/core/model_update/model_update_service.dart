import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../network/connectivity_service.dart';
import '../network/dio_client.dart';
import '../tts/tts_service.dart';

class ModelRegistryEntry {
  final String moduleId;
  final String version;
  final String filename;
  final String checksum;
  final String downloadUrl;

  const ModelRegistryEntry({
    required this.moduleId,
    required this.version,
    required this.filename,
    required this.checksum,
    required this.downloadUrl,
  });

  factory ModelRegistryEntry.fromJson(Map<String, dynamic> json) =>
      ModelRegistryEntry(
        moduleId: json['module_id'] as String,
        version: json['version'] as String,
        filename: json['filename'] as String,
        checksum: json['checksum'] as String,
        downloadUrl: json['download_url'] as String,
      );
}

/// Downloads OTA models and verifies SHA-256 before hot swapping.
class ModelUpdateService {
  final DioClient _dio;
  final ConnectivityService _connectivity;
  final TtsService _tts;

  ModelUpdateService(this._dio, this._connectivity, this._tts);

  Future<void> checkForUpdates(List<String> moduleIds) async {
    if (AppConstants.simulated) return;
    if (!(await _connectivity.isConnected)) return;

    for (final moduleId in moduleIds) {
      try {
        final res = await _dio.client.get(
          AppConstants.modelsLatestPath,
          queryParameters: {'module_id': moduleId},
        );
        final entry = ModelRegistryEntry.fromJson(res.data as Map<String, dynamic>);
        await _downloadAndVerify(entry);
      } catch (e) {
        debugPrint('Model update check failed for $moduleId: $e');
      }
    }
  }

  Future<File?> resolveLocalModel(String filename) async {
    final dir = await _modelDirectory();
    final file = File('${dir.path}/$filename');
    return file.existsSync() ? file : null;
  }

  Future<void> _downloadAndVerify(ModelRegistryEntry entry) async {
    final dir = await _modelDirectory();
    final tmp = File('${dir.path}/${entry.filename}.download');
    final finalFile = File('${dir.path}/${entry.filename}');

    try {
      await _dio.client.download(entry.downloadUrl, tmp.path);
      final checksum = await _sha256(tmp);
      if (checksum.toLowerCase() != entry.checksum.toLowerCase()) {
        await tmp.delete().catchError((_) => tmp);
        await _tts.speak(
          'Model update failed. Using previous version.',
          priority: TtsPriority.high,
        );
        return;
      }
      if (await finalFile.exists()) await finalFile.delete();
      await tmp.rename(finalFile.path);
      await _tts.speak('Model update installed.', priority: TtsPriority.normal);
    } on DioException catch (e) {
      debugPrint('Model download failed: $e');
    }
  }

  Future<Directory> _modelDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/models');
    if (!(await modelsDir.exists())) await modelsDir.create(recursive: true);
    return modelsDir;
  }

  Future<String> _sha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
