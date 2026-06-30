"""Tiny smoke test for a running NOVA backend.

Usage:
    python scripts/smoke_test_backend.py http://localhost:8000/api/v1
"""
import sys
from datetime import datetime, timezone
from uuid import uuid4

import requests


def main() -> int:
    base = sys.argv[1].rstrip("/") if len(sys.argv) > 1 else "http://localhost:8000/api/v1"
    print("Checking", base)
    print(requests.get(f"{base}/health", timeout=5).json())

    email = f"demo-{uuid4().hex[:8]}@example.com"
    auth = requests.post(
        f"{base}/auth/register",
        json={"email": email, "password": "StrongPassword123!", "preferred_language": "en-CM"},
        timeout=5,
    )
    auth.raise_for_status()
    token = auth.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    sync = requests.post(
        f"{base}/logs/sync",
        json={
            "events": [
                {
                    "id": str(uuid4()),
                    "module_id": "MOD-01",
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "outcome": "smoke_test",
                    "confidence_score": 1.0,
                }
            ]
        },
        headers=headers,
        timeout=5,
    )
    sync.raise_for_status()
    print("Log sync:", sync.json())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
