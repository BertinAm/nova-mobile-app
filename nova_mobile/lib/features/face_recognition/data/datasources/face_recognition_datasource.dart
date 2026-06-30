import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/face_entities.dart';

class FaceRecognitionDatasource {
  final AppDatabase _db;
  final Dio _dio;
  final _uuid = const Uuid();

  FaceRecognitionDatasource(this._db, this._dio);

  Future<List<EnrolledContact>> contacts() async {
    final rows = await _db.getEnrolledContacts();
    return rows
        .map((r) => EnrolledContact(id: r.id, name: r.name, createdAt: r.createdAt))
        .toList();
  }

  Future<EnrolledContact> enroll(String name, List<File?> photos) async {
    // Integration point: run face detector, crop aligned face, extract MobileFaceNet
    // embedding, L2-normalize, and store embedding only. Raw enrolment images are
    // not retained by this mobile layer.
    final embedding = _simulatedEmbedding('$name-${photos.length}-${DateTime.now()}');
    final row = EnrolledContactRow(
      id: _uuid.v4(),
      name: name.trim(),
      embedding: embedding,
      createdAt: DateTime.now(),
    );
    await _db.saveEnrolledContact(row);
    return EnrolledContact(id: row.id, name: row.name, createdAt: row.createdAt);
  }

  Future<void> deleteContact(String id) async {
    await _db.deleteEnrolledContact(id);
  }

  Future<FaceRecognitionResult> recognise(File? imageFile) async {
    final gallery = await _db.getEnrolledContacts();
    if (gallery.isEmpty) {
      return const FaceRecognitionResult(faceDetected: true, matched: false);
    }

    if (!AppConstants.simulated && gallery.length > AppConstants.localFaceGalleryLimit) {
      return _recogniseViaBackend(imageFile);
    }

    // Simulate or perform local comparison for <= 20 contacts.
    final probe = AppConstants.simulated
        ? gallery.first.embedding
        : _simulatedEmbedding(imageFile?.path ?? DateTime.now().toIso8601String());

    var best = gallery.first;
    var bestSimilarity = -1.0;
    for (final contact in gallery) {
      final similarity = _cosine(probe, contact.embedding);
      if (similarity > bestSimilarity) {
        best = contact;
        bestSimilarity = similarity;
      }
    }

    final matched = bestSimilarity >= AppConstants.faceMatchThreshold;
    return FaceRecognitionResult(
      faceDetected: true,
      matched: matched,
      contactName: matched ? best.name : null,
      similarity: bestSimilarity,
    );
  }

  Future<FaceRecognitionResult> _recogniseViaBackend(File? imageFile) async {
    if (imageFile == null) {
      return const FaceRecognitionResult(faceDetected: false, matched: false);
    }

    try {
      // Privacy rule: send detected face crop only, not full frame. The current
      // placeholder sends the imageFile passed by the face detector. Replace this
      // with the crop file once face-detection integration is complete.
      final formData = FormData.fromMap({
        'face_crop': await MultipartFile.fromFile(imageFile.path, filename: 'face.jpg'),
      });
      final res = await _dio.post(AppConstants.facesMatchPath, data: formData);
      final matched = res.data['matched'] as bool? ?? false;
      return FaceRecognitionResult(
        faceDetected: res.data['face_detected'] as bool? ?? true,
        matched: matched,
        contactName: matched ? res.data['contact_name'] as String? : null,
        similarity: (res.data['similarity'] as num?)?.toDouble(),
      );
    } catch (e) {
      debugPrint('Cloud face match failed: $e');
      return const FaceRecognitionResult(faceDetected: true, matched: false);
    }
  }

  List<double> _simulatedEmbedding(String seed) {
    final digest = sha256.convert(utf8.encode(seed)).bytes;
    final values = List<double>.generate(128, (i) {
      final byte = digest[i % digest.length];
      return (byte / 255.0) * 2.0 - 1.0;
    });
    final norm = sqrt(values.fold<double>(0, (sum, v) => sum + v * v));
    return values.map((v) => v / max(norm, 1e-9)).toList();
  }

  double _cosine(List<double> a, List<double> b) {
    final n = min(a.length, b.length);
    var dot = 0.0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }
}
