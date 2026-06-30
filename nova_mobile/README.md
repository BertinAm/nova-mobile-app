# NOVA Mobile Section (Flutter/Dart)

This zip contains a complete **mobile-side implementation** for NOVA, built to match the supplied project documents:

- Flutter 3.22+ / Dart 3.4+
- Android API 26+
- Clean Architecture + BLoC
- `flutter_bloc`, `get_it`, `dio`, `camera`, `flutter_tts`, `speech_to_text`, `google_mlkit_text_recognition`, `tflite_flutter`
- Offline-first safety modules: obstacle detection, OCR, and currency detection
- Cloud-dependent scene description
- Hybrid face recognition
- Offline usage-log sync and OTA model-update checksum verification

The project runs in **simulation mode by default**, so you can open the app and demo the flows before the trained `.tflite` files and backend are ready.

## Run in simulation mode

```bash
flutter pub get
flutter run --dart-define=NOVA_SIMULATED=true
```

Simulation mode provides fake but realistic outputs for:

- MOD-01 obstacle alerts
- MOD-02 OCR reading
- MOD-03 scene description
- MOD-04 CFA currency recognition
- MOD-05 face enrolment/recognition
- offline usage logging and sync attempts

## Run with real models and backend

1. Put trained models here:

```text
assets/models/obstacle_detection_v1.tflite
assets/models/currency_detection_v1.tflite
assets/models/face_detection_blazeface.tflite
assets/models/face_embedding_mobilefacenet.tflite
```

2. Keep labels here:

```text
assets/labels/coco_labels.txt
assets/labels/cfa_labels.txt
```

3. Run with simulation disabled:

```bash
flutter run \
  --dart-define=NOVA_SIMULATED=false \
  --dart-define=API_BASE_URL=https://api.nova-assistive.cm
```

## Important integration notes

- `lib/core/constants/app_constants.dart` contains model paths, thresholds, and endpoint paths.
- The TFLite data sources intentionally catch model-load failures and fall back to simulation, so the app remains demonstrable.
- Replace the preprocessing/postprocessing in:
  - `lib/features/obstacle_detection/data/datasources/tflite_obstacle_datasource.dart`
  - `lib/features/currency_detection/data/datasources/tflite_currency_datasource.dart`
  - `lib/features/face_recognition/data/datasources/face_recognition_datasource.dart`
- `lib/core/model_update/model_update_service.dart` implements `/models/latest` download + SHA-256 verification and keeps the previous model if verification fails.
- `lib/core/database/app_database.dart` is a compile-ready JSON persistence adapter with the same method names expected by the Drift/SQLite SyncService. A Drift schema reference is included in `docs/DRIFT_INTEGRATION.md` for swapping in the generated SQLite database when the team is ready.

## Structure

```text
lib/
├── core/
│   ├── camera/
│   ├── constants/
│   ├── database/
│   ├── error/
│   ├── haptics/
│   ├── model_update/
│   ├── network/
│   ├── sync/
│   ├── tts/
│   └── voice/
├── features/
│   ├── currency_detection/
│   ├── face_recognition/
│   ├── home/
│   ├── ocr/
│   ├── onboarding/
│   ├── obstacle_detection/
│   ├── scene_description/
│   └── settings/
└── main.dart
```

## What has been optimized

- Default simulation avoids crashes when model/backend assets are missing.
- Obstacle inference is serialized with `asyncMap`, avoiding overlapping TFLite calls.
- Alert suppression is isolated and unit-testable.
- TTS has priorities so critical obstacle alerts interrupt lower-priority speech.
- Camera streams are throttled to a 10 FPS target in simulation, matching the reference requirement.
- Model update download verifies SHA-256 before hot-swap.
- Raw camera frames are not sent to the backend except explicit cloud features.
