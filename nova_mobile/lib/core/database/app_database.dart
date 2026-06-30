import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Compile-ready local persistence adapter.
///
/// It keeps the same method names required by the Drift/SQLite SyncService in
/// the project document, but uses JSON so the app can run immediately in
/// simulation mode without code generation. Replace this with the Drift schema
/// in `docs/DRIFT_INTEGRATION.md` when finalizing the project.
class AppDatabase {
  final _uuid = const Uuid();
  File? _file;
  _DbState _state = _DbState.empty();

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/nova_local_queue.json');
    if (!(await _file!.exists())) {
      await _persist();
      return;
    }
    final raw = await _file!.readAsString();
    if (raw.trim().isEmpty) return;
    _state = _DbState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<UsageEventRow> insertUsageEvent({
    required String moduleId,
    required String outcome,
    double? confidenceScore,
  }) async {
    final row = UsageEventRow(
      id: _state.nextUsageId++,
      serverId: _uuid.v4(),
      moduleId: moduleId,
      timestamp: DateTime.now(),
      outcome: outcome,
      confidenceScore: confidenceScore,
      synced: false,
    );
    _state.usageEvents.add(row);
    await _persist();
    return row;
  }

  Future<List<UsageEventRow>> getUnsyncedEvents() async => _state.usageEvents
      .where((e) => !e.synced)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  Future<void> markEventsSynced(List<int> localIds) async {
    final idSet = localIds.toSet();
    _state.usageEvents = _state.usageEvents
        .map((e) => idSet.contains(e.id) ? e.copyWith(synced: true) : e)
        .toList();
    await _persist();
  }

  Future<UserFeedbackRow> insertFeedback({
    required String eventServerId,
    required bool isPositive,
  }) async {
    final row = UserFeedbackRow(
      id: _state.nextFeedbackId++,
      serverId: _uuid.v4(),
      eventServerId: eventServerId,
      isPositive: isPositive,
      timestamp: DateTime.now(),
      synced: false,
    );
    _state.feedbacks.add(row);
    await _persist();
    return row;
  }

  Future<List<UserFeedbackRow>> getUnsyncedFeedback() async => _state.feedbacks
      .where((f) => !f.synced)
      .toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  Future<void> markFeedbackSynced(List<int> localIds) async {
    final idSet = localIds.toSet();
    _state.feedbacks = _state.feedbacks
        .map((f) => idSet.contains(f.id) ? f.copyWith(synced: true) : f)
        .toList();
    await _persist();
  }

  Future<void> enqueuePending({
    required String endpoint,
    required dynamic payloadJson,
  }) async {
    _state.pending.add(
      PendingSyncQueueData(
        id: _state.nextPendingId++,
        endpoint: endpoint,
        payloadJson: payloadJson,
        createdAt: DateTime.now(),
        retryCount: 0,
      ),
    );
    await _persist();
  }

  Future<List<PendingSyncQueueData>> getPendingQueueItems() async =>
      _state.pending.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> deletePendingQueueItem(int id) async {
    _state.pending.removeWhere((p) => p.id == id);
    await _persist();
  }

  Future<void> incrementRetryCount(int id) async {
    _state.pending = _state.pending
        .map((p) => p.id == id ? p.copyWith(retryCount: p.retryCount + 1) : p)
        .toList();
    await _persist();
  }

  Future<void> saveEnrolledContact(EnrolledContactRow contact) async {
    _state.enrolledContacts.removeWhere((c) => c.id == contact.id);
    _state.enrolledContacts.add(contact);
    await _persist();
  }

  Future<List<EnrolledContactRow>> getEnrolledContacts() async =>
      _state.enrolledContacts.toList();

  Future<void> deleteEnrolledContact(String id) async {
    _state.enrolledContacts.removeWhere((c) => c.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    if (_file == null) return;
    await _file!.writeAsString(const JsonEncoder.withIndent('  ').convert(_state));
  }
}

class _DbState {
  int nextUsageId;
  int nextFeedbackId;
  int nextPendingId;
  List<UsageEventRow> usageEvents;
  List<UserFeedbackRow> feedbacks;
  List<PendingSyncQueueData> pending;
  List<EnrolledContactRow> enrolledContacts;

  _DbState({
    required this.nextUsageId,
    required this.nextFeedbackId,
    required this.nextPendingId,
    required this.usageEvents,
    required this.feedbacks,
    required this.pending,
    required this.enrolledContacts,
  });

  factory _DbState.empty() => _DbState(
        nextUsageId: 1,
        nextFeedbackId: 1,
        nextPendingId: 1,
        usageEvents: [],
        feedbacks: [],
        pending: [],
        enrolledContacts: [],
      );

  factory _DbState.fromJson(Map<String, dynamic> json) => _DbState(
        nextUsageId: json['nextUsageId'] as int? ?? 1,
        nextFeedbackId: json['nextFeedbackId'] as int? ?? 1,
        nextPendingId: json['nextPendingId'] as int? ?? 1,
        usageEvents: (json['usageEvents'] as List<dynamic>? ?? [])
            .map((e) => UsageEventRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        feedbacks: (json['feedbacks'] as List<dynamic>? ?? [])
            .map((f) => UserFeedbackRow.fromJson(f as Map<String, dynamic>))
            .toList(),
        pending: (json['pending'] as List<dynamic>? ?? [])
            .map((p) => PendingSyncQueueData.fromJson(p as Map<String, dynamic>))
            .toList(),
        enrolledContacts: (json['enrolledContacts'] as List<dynamic>? ?? [])
            .map((c) => EnrolledContactRow.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'nextUsageId': nextUsageId,
        'nextFeedbackId': nextFeedbackId,
        'nextPendingId': nextPendingId,
        'usageEvents': usageEvents.map((e) => e.toJson()).toList(),
        'feedbacks': feedbacks.map((f) => f.toJson()).toList(),
        'pending': pending.map((p) => p.toJson()).toList(),
        'enrolledContacts': enrolledContacts.map((c) => c.toJson()).toList(),
      };
}

class UsageEventRow {
  final int id;
  final String serverId;
  final String moduleId;
  final DateTime timestamp;
  final String outcome;
  final double? confidenceScore;
  final bool synced;

  UsageEventRow({
    required this.id,
    required this.serverId,
    required this.moduleId,
    required this.timestamp,
    required this.outcome,
    required this.synced,
    this.confidenceScore,
  });

  UsageEventRow copyWith({bool? synced}) => UsageEventRow(
        id: id,
        serverId: serverId,
        moduleId: moduleId,
        timestamp: timestamp,
        outcome: outcome,
        confidenceScore: confidenceScore,
        synced: synced ?? this.synced,
      );

  factory UsageEventRow.fromJson(Map<String, dynamic> json) => UsageEventRow(
        id: json['id'] as int,
        serverId: json['serverId'] as String,
        moduleId: json['moduleId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        outcome: json['outcome'] as String,
        confidenceScore: (json['confidenceScore'] as num?)?.toDouble(),
        synced: json['synced'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'serverId': serverId,
        'moduleId': moduleId,
        'timestamp': timestamp.toIso8601String(),
        'outcome': outcome,
        'confidenceScore': confidenceScore,
        'synced': synced,
      };
}

class UserFeedbackRow {
  final int id;
  final String serverId;
  final String eventServerId;
  final bool isPositive;
  final DateTime timestamp;
  final bool synced;

  UserFeedbackRow({
    required this.id,
    required this.serverId,
    required this.eventServerId,
    required this.isPositive,
    required this.timestamp,
    required this.synced,
  });

  UserFeedbackRow copyWith({bool? synced}) => UserFeedbackRow(
        id: id,
        serverId: serverId,
        eventServerId: eventServerId,
        isPositive: isPositive,
        timestamp: timestamp,
        synced: synced ?? this.synced,
      );

  factory UserFeedbackRow.fromJson(Map<String, dynamic> json) => UserFeedbackRow(
        id: json['id'] as int,
        serverId: json['serverId'] as String,
        eventServerId: json['eventServerId'] as String,
        isPositive: json['isPositive'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
        synced: json['synced'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'serverId': serverId,
        'eventServerId': eventServerId,
        'isPositive': isPositive,
        'timestamp': timestamp.toIso8601String(),
        'synced': synced,
      };
}

class PendingSyncQueueData {
  final int id;
  final String endpoint;
  final dynamic payloadJson;
  final DateTime createdAt;
  final int retryCount;

  PendingSyncQueueData({
    required this.id,
    required this.endpoint,
    required this.payloadJson,
    required this.createdAt,
    required this.retryCount,
  });

  PendingSyncQueueData copyWith({int? retryCount}) => PendingSyncQueueData(
        id: id,
        endpoint: endpoint,
        payloadJson: payloadJson,
        createdAt: createdAt,
        retryCount: retryCount ?? this.retryCount,
      );

  factory PendingSyncQueueData.fromJson(Map<String, dynamic> json) =>
      PendingSyncQueueData(
        id: json['id'] as int,
        endpoint: json['endpoint'] as String,
        payloadJson: json['payloadJson'],
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'payloadJson': payloadJson,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };
}

class EnrolledContactRow {
  final String id;
  final String name;
  final List<double> embedding;
  final DateTime createdAt;

  EnrolledContactRow({
    required this.id,
    required this.name,
    required this.embedding,
    required this.createdAt,
  });

  factory EnrolledContactRow.fromJson(Map<String, dynamic> json) =>
      EnrolledContactRow(
        id: json['id'] as String,
        name: json['name'] as String,
        embedding: (json['embedding'] as List<dynamic>)
            .map((v) => (v as num).toDouble())
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'embedding': embedding,
        'createdAt': createdAt.toIso8601String(),
      };
}
