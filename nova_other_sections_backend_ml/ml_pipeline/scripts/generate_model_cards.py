"""Generate HuggingFace README model cards from the publish manifest."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def card(item: dict) -> str:
    cfg = item.get("config", {})
    return f"""---
language:
  - en
  - fr
license: apache-2.0
tags:
  - assistive-technology
  - computer-vision
  - tflite
  - android
  - cameroon
---

# NOVA {item['repo_name']} ({item['module_id']})

Part of the NOVA assistive vision system.

## Training details

| Property | Value |
|---|---|
| Module | {item['module_id']} |
| Version | {item['version']} |
| Architecture | {cfg.get('architecture', 'TBD')} |
| Distilled from | {cfg.get('distilled_from', 'TBD')} |
| Input size | {cfg.get('input_size', 'TBD')} |

## Files

- PyTorch checkpoint: `{item['pytorch_checkpoint']}`
- TFLite INT8 model: `{item['tflite_model']}`
- Labels: `{item['labels_file']}`

## Mobile integration

The mobile app discovers this artifact through the backend `/models/latest` endpoint and verifies the SHA-256 checksum before hot-swapping.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("configs/publish_manifest.json"))
    parser.add_argument("--out-dir", type=Path, default=Path("model_cards"))
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    args.out_dir.mkdir(parents=True, exist_ok=True)
    for item in manifest["models"]:
        path = args.out_dir / f"{item['repo_name']}_README.md"
        path.write_text(card(item), encoding="utf-8")
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
