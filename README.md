# NOVA Mobile Application

Navigational Object and Voice Assistant

| Field | Value |
| --- | --- |
| **Framework** | Flutter 3.22+ (Dart 3.4+) |
| **Platform** | Android API 26 (Android 8.0) and above |
| **Architecture** | Clean Architecture + BLoC |
| **On-device ML** | TensorFlow Lite 2.14+ |
| **On-device OCR** | Google ML Kit Text Recognition v2 |
| **TTS** | Android TextToSpeech API (flutter_tts) |
| **Voice Input** | speech_to_text |
| **Local DB** | SQLite via Drift ORM |
| **License** | MIT |

---

## What This Repository Contains

This is the Flutter Android application that the end user installs on their phone. It captures camera frames, runs on-device ML inference for obstacle detection and currency classification, reads text via ML Kit OCR, recognises enrolled faces, requests cloud-assisted scene descriptions from the *nova-backend* server, and delivers all output as spoken audio via the Android TTS engine.

The application is designed for blind and visually impaired users in Cameroon. All safety-critical features (obstacle detection, OCR, currency detection) work fully offline. The phone is worn rear-camera-outward on a chest lanyard so the camera has a clear forward field of view during navigation.

## Features

| Module | ID | Works Offline | Description |
| --- | --- | --- | --- |
| Obstacle Detection | MOD-01 | Yes | Real-time forward obstacle detection with directional TTS alerts |
| Text Reading (OCR) | MOD-02 | Yes | Camera-based text recognition read aloud via TTS |
| Scene Description | MOD-03 | No (cloud) | Natural-language scene description via backend BLIP-2 |
| Currency Detection | MOD-04 | Yes | CFA franc denomination identification (500–10000 FCFA) |
| Face Recognition | MOD-05 | Partial | Enrolled contact recognition; large galleries use cloud matching |

## Project Structure

```text
lib/
├── main.dart                # App entry point
├── injection_container.dart # GetIt dependency injection
├── core/                    # Shared: TTS, network, database, sync, permissions
└── features/
    ├── auth/                # Login, registration
    ├── obstacle_detection/  # MOD-01
    ├── ocr/                 # MOD-02
    ├── scene_description/   # MOD-03
    ├── currency_detection/  # MOD-04
    └── face_recognition/    # MOD-05
assets/
├── models/                  # Bundled TFLite model files
└── labels/                  # Class label files

```

## Getting Started

### Prerequisites

* Flutter 3.22+ installed ([flutter.dev/install](https://www.google.com/search?q=https://flutter.dev/install))
* Android Studio or VS Code with Flutter extension
* Android device or emulator running API 26+
* A running instance of *nova-backend* (local or remote)

### 1. Clone and configure

```bash
git clone https://github.com/your-org/nova-mobile.git
cd nova-mobile
flutter pub get

```

### 2. Set the backend URL

```bash
# The API base URL is injected at build time via --dart-define
# For local development:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# For production build:
flutter build apk --dart-define=API_BASE_URL=https://api.nova-assistive.cm

```

### 3. Run on device

```bash
# Connect Android device via USB with developer mode enabled
flutter run

# Build release APK for distribution
flutter build apk --release --dart-define=API_BASE_URL=https://api.nova-assistive.cm
# APK location: build/app/outputs/flutter-apk/app-release.apk

```

### 4. Run tests

```bash
flutter test

```

## TFLite Model Files

The repository includes baseline model versions in `assets/models/`. When the app starts and network is available, it checks the *nova-backend* model registry for newer versions and downloads them automatically (OTA update). Downloaded models replace the bundled baseline without requiring an app reinstall.

| File | Module | Description |
| --- | --- | --- |
| obstacle_detection_v1.tflite | MOD-01 | YOLOv8n INT8 quantized 83-class obstacle detection |
| currency_detection_v1.tflite | MOD-04 | MobileNetV3-Small INT8 5-class CFA franc classification |
| face_detection_blazeface.tflite | MOD-05 | BlazeFace INT8 face localisation |
| face_embedding_mobilefacenet.tflite | MOD-05 | MobileFaceNet INT8 512-d face embedding extraction |

## Phone Mounting Position

NOVA is designed to be used with the phone worn on the chest on a lanyard or in a chest pocket, with the rear camera facing outward (away from the body). This gives the rear camera which is significantly higher quality than the front camera a clear, stable forward field of view at chest height (approximately 1.2–1.5m above ground).

* Use the rear camera, not the front camera.
* Mount the phone with the screen facing toward your body and the camera facing the environment.
* A chest lanyard or clip-style phone holder works well. An armband worn at chest height is an alternative.
* The chest-height mounting position does not detect ground-level hazards below approximately 0.8m. NOVA is a supplement to a white cane, not a replacement for it.

## Voice Commands

| English Command | French Command | Action |
| --- | --- | --- |
| Start obstacle detection | — | Activate MOD-01 |
| Stop obstacle detection | — | Deactivate MOD-01 |
| Read text | Lire texte | Trigger OCR capture |
| Describe scene | Decrire scene | Request cloud scene description |
| Identify money | Identifier argent | Trigger currency detection |
| Who is this | Qui est | Trigger face recognition |
| Call for help | Au secours | Send emergency location SMS |
| Stop | — | Stop current TTS output |
| Slow down / Speed up | — | Adjust TTS reading speed |

## Offline Behaviour

* Obstacle detection, OCR, and currency detection work with zero network connectivity at all times.
* Usage events and feedback are stored locally in SQLite when offline and automatically synced to the backend when connectivity is restored.
* Scene description announces an informative error if network is unavailable and does not crash or hang.
* Face recognition uses on-device matching for galleries of 20 or fewer enrolled contacts, requiring no network.

## Related Repositories

* [nova-backend](https://www.google.com/search?q=https://github.com/your-org/nova-backend) FastAPI server
* [nova-ml](https://www.google.com/search?q=https://github.com/your-org/nova-ml) ML training pipeline
* [huggingface.co/nova-assistive](https://www.google.com/search?q=https://huggingface.co/nova-assistive) Published TFLite models

---

**Licence**
MIT see LICENSE file.

University of Buea, Faculty of Engineering and Technology, Department of Computer Engineering. Internet of Things and Video Processing Academic Year 2025/2026.
