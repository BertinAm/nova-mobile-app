# Drift/SQLite Integration Reference

The app ships with a compile-ready JSON persistence adapter in `lib/core/database/app_database.dart` so your team can run the simulated build immediately.

When you are ready to switch to Drift/SQLite, replace that file with the following schema and run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class UsageEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().unique()();
  TextColumn get moduleId => text().withLength(max: 20)();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get outcome => text().withLength(max: 50)();
  RealColumn get confidenceScore => real().nullable()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

class UserFeedbacks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get serverId => text().unique()();
  TextColumn get eventServerId => text()();
  BoolColumn get isPositive => boolean()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
}

class PendingSyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get endpoint => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [UsageEvents, UserFeedbacks, PendingSyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  @override int get schemaVersion => 1;
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dir = await getApplicationDocumentsDirectory();
  return NativeDatabase.createInBackground(File(p.join(dir.path, 'nova.db')));
});
```
