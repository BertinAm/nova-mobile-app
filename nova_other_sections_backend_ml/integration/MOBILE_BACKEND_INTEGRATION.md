# Mobile ↔ Backend ↔ ML Integration Discussion

The mobile code remains responsible for all safety-critical offline behavior. The backend only supports cloud-dependent or sync/update features.

## 1. Runtime feature split

| Feature | Mobile responsibility | Backend responsibility |
|---|---|---|
| MOD-01 obstacle detection | Camera stream, TFLite inference, distance/zone logic, TTS alerts, alert suppression | Receives optional usage logs; serves OTA model metadata |
| MOD-02 OCR | ML Kit OCR, language heuristic, TTS readout | Receives optional analytics only; raw text should not be uploaded |
| MOD-03 scene description | Capture, compress to <=512 KB, connectivity check, TTS | `/scene/describe` receives one user-triggered JPEG, generates concise text, stores no image |
| MOD-04 currency detection | Still capture, TFLite classification, confidence threshold 0.85, TTS | Receives optional logs; serves OTA model metadata |
| MOD-05 face recognition | Face detection and local comparison for <=20 contacts | Enroll/match large galleries using encrypted embeddings; stores no raw enrollment images |

## 2. API base URL in Flutter

The existing Flutter `DioClient` should use:

```dart
const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.nova-assistive.cm/api/v1',
);
```

For local testing on Android emulator use:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For a physical phone on the same Wi-Fi:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LAPTOP_LAN_IP:8000/api/v1
```

## 3. Authentication integration

Flutter stores `access_token` and `refresh_token` in `flutter_secure_storage`. The backend expects:

```text
Authorization: Bearer <access_token>
```

When the backend returns `401`, the Flutter interceptor should call `/auth/refresh`, replace both tokens, and retry the original request.

## 4. Model update integration

The ML pipeline publishes a TFLite model to HuggingFace and computes SHA-256. The backend stores the active model row in `model_registry`. The mobile app does not need to know HuggingFace internals; it only checks `/models/latest?module_id=...`.

Recommended mobile mapping:

| Module | module_id | Local asset fallback | Downloaded file name |
|---|---|---|---|
| Obstacle | MOD-01 | `assets/models/obstacle_detection_v1.tflite` | `obstacle_detection_v*.tflite` |
| Currency | MOD-04 | `assets/models/currency_detection_v1.tflite` | `currency_detection_v*.tflite` |
| Face detect | MOD-05-detect | `assets/models/face_detection_blazeface.tflite` | `face_detection_blazeface_v*.tflite` |
| Face embed | MOD-05-embed | `assets/models/face_embedding_mobilefacenet.tflite` | `face_embedding_v*.tflite` |

Failure handling:

- Download error: keep bundled/local previous model.
- Checksum mismatch: delete temp file, announce “Model update failed. Using previous version.”
- Missing registry row: use bundled asset.

## 5. Logs sync integration

Mobile logs are generated offline with a UUID. The backend inserts idempotently, so retries are safe. Mobile should mark a row synced only after `/logs/sync` returns success.

## 6. Privacy boundaries

- Obstacle/OCR/currency frames never go to backend.
- Scene frames go only after explicit scene request and are not persisted.
- Face enrollment images are converted to encrypted embeddings and then discarded.
- For large-gallery face matching, send cropped faces only, not full frames.

## 7. Suggested demo flow

1. Start backend with Docker Compose.
2. Register one user from Swagger or the mobile app.
3. Run mobile with `API_BASE_URL` pointed to the backend.
4. Use `/models/register` with an admin token or `register_model_in_backend.py` to add simulated model rows.
5. Trigger scene description from mobile to verify cloud path.
6. Trigger obstacle/OCR/currency offline to show the safety-critical modules remain independent of backend.
7. Turn Wi-Fi off, create usage logs, turn Wi-Fi on, confirm `/logs/sync` receives them.
