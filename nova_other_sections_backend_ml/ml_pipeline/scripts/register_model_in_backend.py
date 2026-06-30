"""Register a published TFLite model in NOVA backend model registry."""
from __future__ import annotations

import argparse
import os

import requests


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend-url", default=os.getenv("NOVA_BACKEND_URL", "http://localhost:8000/api/v1"))
    parser.add_argument("--admin-token", default=os.getenv("NOVA_ADMIN_TOKEN"))
    parser.add_argument("--module-id", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--filename", required=True)
    parser.add_argument("--checksum", required=True)
    parser.add_argument("--download-url")
    parser.add_argument("--huggingface-repo")
    parser.add_argument("--notes", default="Registered from ML pipeline")
    args = parser.parse_args()
    if not args.admin_token:
        raise SystemExit("Set --admin-token or NOVA_ADMIN_TOKEN")
    response = requests.post(
        f"{args.backend_url.rstrip('/')}/models/register",
        headers={"Authorization": f"Bearer {args.admin_token}"},
        json={
            "module_id": args.module_id,
            "version": args.version,
            "filename": args.filename,
            "checksum": args.checksum,
            "download_url": args.download_url,
            "huggingface_repo": args.huggingface_repo,
            "is_active": True,
            "notes": args.notes,
        },
        timeout=20,
    )
    print(response.status_code, response.text)
    response.raise_for_status()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
