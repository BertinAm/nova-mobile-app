# NOVA FastAPI Backend

Implements the backend portion defined by the NOVA SRS:

- FastAPI + PostgreSQL service layer.
- JWT authentication with refresh-token rotation.
- bcrypt password hashing with cost factor 12.
- Encrypted face embeddings at rest using AES-GCM with a 256-bit key.
- Scene description endpoint with no persistent image storage.
- Cloud face matching endpoint that accepts cropped faces only.
- Model registry endpoint for OTA TFLite updates and SHA-256 verification on mobile.
- Usage log and feedback sync endpoints designed for idempotent offline retries.

## Run with Docker

```bash
cp .env.example .env
docker compose up --build
```

API docs:

```text
http://localhost:8000/docs
```

## Run without Docker

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

The development `.env.example` uses SQLite for quick simulation. Docker Compose uses PostgreSQL.

## Replace simulation services

- Replace `SceneService.describe_scene()` with a call to your BLIP-2/VLM service.
- Replace `FaceService._embedding_from_bytes()` with real face crop preprocessing + MobileFaceNet/ArcFace embedding extraction.
- Keep API schemas unchanged so the Flutter app does not need changes.
