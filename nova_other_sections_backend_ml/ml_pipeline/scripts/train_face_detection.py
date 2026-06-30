"""MOD-05 face detection training notes and optional WIDER FACE loader.

NOVA uses a BlazeFace-style detector for on-device face detection. MediaPipe
already ships a strong lightweight detector. Fine-tuning/distillation requires a
BlazeFace PyTorch implementation plus WIDER FACE annotations.
"""
from __future__ import annotations

import argparse


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--wider-face-split", default="train")
    parser.add_argument("--simulate", action="store_true")
    args = parser.parse_args()
    if args.simulate:
        print("Simulation OK: use pre-trained BlazeFace for mobile and export to TFLite.")
        return 0
    try:
        from datasets import load_dataset
        wider_face = load_dataset("wider_face", split=args.wider_face_split)
        print(wider_face)
        print("Next: connect a BlazeFace PyTorch implementation and train/export.")
        return 0
    except Exception as exc:
        print("Could not load WIDER FACE. Install datasets or use --simulate.")
        print(exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
