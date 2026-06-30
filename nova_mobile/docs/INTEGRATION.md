# NOVA Mobile Integration Notes

## 1. Connect real TFLite models

1. Copy model files into `assets/models/`.
2. Keep asset names exactly as defined in `lib/core/constants/app_constants.dart`.
3. Run:

```bash
flutter clean
flutter pub get
flutter run --dart-define=NOVA_SIMULATED=false
```

## 2. Obstacle detection model output

`TfliteObstacleDatasource` currently includes SSD-style output comments:

```dart
boxes:   [1, N, 4]
classes: [1, N]
scores:  [1, N]
count:   [1]
```

If your exported YOLOv8n TFLite file returns `[1, 84, 2100]` or similar, replace `_runRealInference` with your YOLO decode + NMS logic.

## 3. Currency model output

The currency classifier expects one output vector with five probabilities:

```text
[fcfa_500, fcfa_1000, fcfa_2000, fcfa_5000, fcfa_10000]
```

Confidence threshold is `0.85`, matching the SRS.

## 4. Backend endpoints expected

```text
POST /auth/refresh
POST /scene/describe
POST /faces/match
GET  /models/latest?module_id=MOD-01
POST /logs/sync
POST /logs/feedback/sync
```

## 5. Privacy guardrails

- Obstacle, OCR, and currency detection remain on-device.
- Scene description sends a compressed still frame only after explicit user request.
- Face recognition sends detected face crops only when the gallery exceeds 20 contacts.
- No raw frames are persisted by the mobile side.
