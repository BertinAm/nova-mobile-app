import 'dart:async';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../network/connectivity_service.dart';
import '../network/dio_client.dart';

class SyncService {
  final ConnectivityService _connectivity;
  final AppDatabase _db;
  final DioClient _dio;

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;

  static const int _maxBatchSize = 50;
  static const int _maxRetries = 3;
  static const Duration _retryBackoffBase = Duration(seconds: 2);

  SyncService(this._connectivity, this._db, this._dio);

  void startWatching() {
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .where((isConnected) => isConnected)
        .listen((_) => _triggerSync());
  }

  Future<void> syncNow() => _triggerSync();

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _syncUsageEvents();
      await _syncFeedback();
      await _drainPendingQueue();
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncUsageEvents() async {
    final unsynced = await _db.getUnsyncedEvents();
    if (unsynced.isEmpty) return;

    for (int i = 0; i < unsynced.length; i += _maxBatchSize) {
      final batch = unsynced.skip(i).take(_maxBatchSize).toList();
      final success = await _postWithRetry(
        endpoint: AppConstants.logsSyncPath,
        payload: {
          'events': batch
              .map(
                (e) => {
                  'id': e.serverId,
                  'module_id': e.moduleId,
                  'timestamp': e.timestamp.toIso8601String(),
                  'outcome': e.outcome,
                  'confidence_score': e.confidenceScore,
                },
              )
              .toList(),
        },
      );
      if (success) {
        await _db.markEventsSynced(batch.map((e) => e.id).toList());
      }
    }
  }

  Future<void> _syncFeedback() async {
    final unsynced = await _db.getUnsyncedFeedback();
    if (unsynced.isEmpty) return;

    for (int i = 0; i < unsynced.length; i += _maxBatchSize) {
      final batch = unsynced.skip(i).take(_maxBatchSize).toList();
      final success = await _postWithRetry(
        endpoint: AppConstants.feedbackSyncPath,
        payload: {
          'feedbacks': batch
              .map(
                (f) => {
                  'id': f.serverId,
                  'event_id': f.eventServerId,
                  'is_positive': f.isPositive,
                  'timestamp': f.timestamp.toIso8601String(),
                },
              )
              .toList(),
        },
      );
      if (success) {
        await _db.markFeedbackSynced(batch.map((f) => f.id).toList());
      }
    }
  }

  Future<void> _drainPendingQueue() async {
    final pending = await _db.getPendingQueueItems();
    for (final item in pending) {
      if (item.retryCount >= _maxRetries) {
        await _db.deletePendingQueueItem(item.id);
        continue;
      }
      final success = await _postWithRetry(
        endpoint: item.endpoint,
        payload: item.payloadJson,
        maxAttempts: 1,
      );
      if (success) {
        await _db.deletePendingQueueItem(item.id);
      } else {
        await _db.incrementRetryCount(item.id);
      }
    }
  }

  Future<bool> _postWithRetry({
    required String endpoint,
    required dynamic payload,
    int maxAttempts = _maxRetries,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        await _dio.client.post(endpoint, data: payload);
        return true;
      } catch (e) {
        debugPrint('Sync attempt ${attempt + 1} failed for $endpoint: $e');
        if (attempt < maxAttempts - 1) {
          await Future<void>.delayed(_retryBackoffBase * (1 << attempt));
        }
      }
    }
    return false;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
