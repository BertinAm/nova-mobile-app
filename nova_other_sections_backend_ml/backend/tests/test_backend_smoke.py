import os
from datetime import datetime, timezone

# Tests use a local SQLite file so they do not need PostgreSQL.
os.environ.setdefault("NOVA_DATABASE_URL", "sqlite:///./test_nova.db")
os.environ.setdefault("NOVA_AES_GCM_KEY_B64", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")

from fastapi.testclient import TestClient  # noqa: E402

from app.main import create_app  # noqa: E402

client = TestClient(create_app())


def _register_user():
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "test@example.com", "password": "StrongPassword123!", "preferred_language": "en-CM"},
    )
    if response.status_code == 409:
        response = client.post(
            "/api/v1/auth/login",
            json={"email": "test@example.com", "password": "StrongPassword123!"},
        )
    assert response.status_code in (200, 201), response.text
    return response.json()["access_token"]


def test_health():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json()["status"] in {"ok", "degraded"}


def test_register_and_sync_logs_idempotent():
    token = _register_user()
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "events": [
            {
                "id": "event-1",
                "module_id": "MOD-01",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "outcome": "near_person_left",
                "confidence_score": 0.9,
            }
        ]
    }
    first = client.post("/api/v1/logs/sync", json=payload, headers=headers)
    second = client.post("/api/v1/logs/sync", json=payload, headers=headers)
    assert first.status_code == 200, first.text
    assert second.status_code == 200, second.text
    assert second.json()["duplicates"] >= 1


def test_admin_can_register_model():
    token = _register_user()
    headers = {"Authorization": f"Bearer {token}"}
    response = client.post(
        "/api/v1/models/register",
        json={
            "module_id": "MOD-01",
            "version": "1.0.0",
            "filename": "obstacle_detection_v1.tflite",
            "checksum": "a" * 64,
            "download_url": "https://huggingface.co/nova-assistive/obstacle-detection/resolve/main/tflite/obstacle_detection_v1.tflite",
            "is_active": True,
        },
        headers=headers,
    )
    assert response.status_code in (201, 403), response.text
