"""Publish NOVA model artifacts to HuggingFace Hub."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path

from huggingface_hub import HfApi, create_repo


def compute_sha256(path: str | Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def make_model_card(module_id: str, repo_name: str, config: dict, evaluation: dict) -> str:
    return f"""---
language:
  - en
  - fr
license: apache-2.0
tags:
  - assistive-technology
  - computer-vision
  - tflite
  - knowledge-distillation
  - quantization
  - android
  - cameroon
  - nova-assistive
---

# NOVA {repo_name} ({module_id})

Part of NOVA: Navigational Object and Voice Assistant, a low-cost assistive vision system for blind and visually impaired users.

## Model configuration

```json
{json.dumps(config, indent=2)}
```

## Evaluation

```json
{json.dumps(evaluation, indent=2)}
```

## Mobile usage

Load the INT8 TFLite file in Flutter with `tflite_flutter`, then verify the SHA-256 checksum from the backend model registry before hot-swapping.
"""


def publish_one(api: HfApi, org: str, item: dict) -> str:
    repo_id = f"{org}/{item['repo_name']}"
    create_repo(repo_id, repo_type="model", exist_ok=True)
    checksum = compute_sha256(item["tflite_model"])
    config = dict(item.get("config", {}))
    config.update({
        "module_id": item["module_id"],
        "version": item["version"],
        "tflite_checksum": checksum,
        "published_at": dt.datetime.utcnow().isoformat() + "Z",
    })
    evaluation = item.get("evaluation_results", {})

    uploads = [
        (item["pytorch_checkpoint"], f"pytorch/{Path(item['pytorch_checkpoint']).name}"),
        (item["tflite_model"], f"tflite/{Path(item['tflite_model']).name}"),
        (item["labels_file"], f"labels/{Path(item['labels_file']).name}"),
    ]
    for local, repo_path in uploads:
        api.upload_file(path_or_fileobj=local, path_in_repo=repo_path, repo_id=repo_id, repo_type="model")
    api.upload_file(path_or_fileobj=json.dumps(config, indent=2).encode(), path_in_repo="config.json", repo_id=repo_id, repo_type="model")
    api.upload_file(path_or_fileobj=json.dumps(evaluation, indent=2).encode(), path_in_repo="evaluation/results.json", repo_id=repo_id, repo_type="model")
    api.upload_file(path_or_fileobj=make_model_card(item["module_id"], item["repo_name"], config, evaluation).encode(), path_in_repo="README.md", repo_id=repo_id, repo_type="model")
    print(f"Published {repo_id}; checksum={checksum}")
    return checksum


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("configs/publish_manifest.json"))
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    api = HfApi()
    for item in manifest["models"]:
        publish_one(api, manifest.get("org", "nova-assistive"), item)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
