# NOVA Backend API Contract for Flutter Integration

Base URL used by the Flutter `DioClient`:

```text
https://api.nova-assistive.cm/api/v1
```

For local development:

```text
http://<LAN-IP>:8000/api/v1
```

## Authentication

### `POST /auth/register`

Request:

```json
{
  "email": "user@example.com",
  "password": "StrongPassword123!",
  "preferred_language": "en-CM"
}
```

Response:

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "token_type": "bearer",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "preferred_language": "en-CM",
    "is_admin": false
  }
}
```

### `POST /auth/login`

Same token response as register.

### `POST /auth/refresh`

Request:

```json
{"refresh_token": "..."}
```

The backend rotates refresh tokens, so Flutter should replace both stored tokens after every refresh.

## Scene description

### `POST /scene/describe`

Authenticated multipart request:

```text
image=<JPEG file, <=512 KB recommended by mobile>
```

Response:

```json
{
  "description": "A bright indoor scene with a table and people nearby.",
  "provider": "simulated",
  "processing_ms": 42
}
```

Mobile behavior:

- Check connectivity before calling.
- Say: “Describing the scene, please wait.”
- Timeout after 8 seconds.
- Do not use for safety-critical obstacle avoidance.

## Face recognition

### `POST /faces/enroll`

Authenticated multipart request:

```text
contact_name=Alice
images=<3 to 5 face images>
```

The backend extracts/simulates embeddings, encrypts the final embedding at rest, and discards raw images.

### `POST /faces/match`

Authenticated multipart request:

```text
face_crop=<cropped detected face image>
```

Response:

```json
{
  "match_found": true,
  "contact_name": "Alice",
  "similarity": 0.82,
  "threshold": 0.75
}
```

Flutter should only send cropped faces for galleries larger than 20 contacts. For small galleries, mobile can compare embeddings locally.

## Model OTA update

### `GET /models/latest?module_id=MOD-01`

Response:

```json
{
  "id": "uuid",
  "module_id": "MOD-01",
  "version": "1.0.0",
  "filename": "obstacle_detection_v1.tflite",
  "checksum": "sha256hex",
  "download_url": "https://.../obstacle_detection_v1.tflite",
  "is_active": true
}
```

Mobile OTA flow:

1. Ask `/models/latest` per module.
2. Compare returned version with local version.
3. Download `download_url` or `/models/download/{id}`.
4. Verify SHA-256 before moving the file into the app model directory.
5. If checksum fails, discard the new file and keep the previous model.

## Usage logs and feedback

### `POST /logs/sync`

Request:

```json
{
  "events": [
    {
      "id": "client-generated-uuid",
      "module_id": "MOD-01",
      "timestamp": "2026-06-01T12:00:00Z",
      "outcome": "near_person_left",
      "confidence_score": 0.91
    }
  ]
}
```

Response:

```json
{"accepted": 1, "duplicates": 0}
```

Idempotency is based on the client-generated `id`.

### `POST /logs/feedback/sync`

Request:

```json
{
  "feedbacks": [
    {
      "id": "client-generated-feedback-uuid",
      "event_id": "client-generated-event-uuid",
      "is_positive": true,
      "timestamp": "2026-06-01T12:01:00Z"
    }
  ]
}
```

## Health

### `GET /health`

Returns basic API and database status for deployment monitoring.
