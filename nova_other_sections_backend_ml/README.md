# NOVA Other Required Sections: Backend + Database + ML Pipeline

This package contains the non-mobile sections needed to integrate with the NOVA Flutter app:

1. **FastAPI backend** for authentication, scene description, cloud face matching, model registry, logs sync, feedback sync, emergency contact storage, and OpenAPI documentation.
2. **PostgreSQL data model** for users, encrypted enrolled-face embeddings, usage events, feedback, model registry, refresh tokens, and emergency contacts.
3. **ML training/deployment pipeline** for obstacle detection, currency detection, face detection, face embedding, INT8 TFLite conversion, HuggingFace publishing, and backend model registration.
4. **Integration notes** showing how the Flutter mobile section should call the backend and how model OTA updates flow from HuggingFace to backend registry to mobile hot-swap.

The backend is production-shaped but also includes a **simulation mode** so the project can run locally without trained models, a vision-language model, or face-recognition infrastructure. The simulation mode is intentionally isolated in service classes, so replacing it with real models does not change API routes or mobile integration.

## Quick local run

```bash
cd backend
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Open Swagger/OpenAPI:

```text
http://localhost:8000/docs
```

For PostgreSQL + Docker:

```bash
cd backend
docker compose up --build
```

## Important integration order

1. Run backend and create/register a user.
2. Point Flutter `DioClient` to `API_BASE_URL=http://<your-ip>:8000/api/v1` during development.
3. Upload/publish real TFLite models using `ml_pipeline/scripts/push_to_huggingface.py`.
4. Register each model checksum using `ml_pipeline/scripts/register_model_in_backend.py` or the admin `/models/register` endpoint.
5. Mobile `SyncService` checks `/models/latest`, verifies SHA-256, then hot-swaps the TFLite file.

## Security defaults

The `.env.example` contains development defaults only. For real deployment, set long random JWT secrets and a 32-byte AES-GCM key using:

```bash
python -c "import os,base64; print(base64.b64encode(os.urandom(32)).decode())"
```
