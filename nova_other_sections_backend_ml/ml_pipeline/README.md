# NOVA ML Training, Conversion, Evaluation, and HuggingFace Deployment

This folder implements the ML pipeline required by NOVA:

- MOD-01 obstacle detection: YOLOv8n or MobileNetV3-SSD student, distilled from YOLOv8m.
- MOD-04 currency detection: MobileNetV3-Small student, distilled from EfficientNet-B4.
- MOD-05 face detection: BlazeFace-style detector, optionally fine-tuned/distilled from RetinaFace.
- MOD-05 face embedding: MobileFaceNet-style embedding model, distilled from ArcFace R100.
- PyTorch → ONNX → TFLite INT8 conversion.
- TFLite benchmarking.
- HuggingFace Hub publishing.
- Backend model registry registration.

The real training jobs require datasets and GPU time. For development without datasets, scripts include `--simulate` modes where practical.

## Environment

```bash
python -m venv nova_ml_env
source nova_ml_env/bin/activate
pip install -r requirements.txt
```

## Dataset layout

### Currency

```text
datasets/cfa_currency/
  train/fcfa_500/*.jpg
  train/fcfa_1000/*.jpg
  ...
  val/fcfa_500/*.jpg
  test/fcfa_500/*.jpg
```

### Obstacle

```text
datasets/obstacle_combined/
  images/train/*.jpg
  labels/train/*.txt
  images/val/*.jpg
  labels/val/*.txt
```

## Typical pipeline

```bash
# Train/distill
python scripts/train_currency_distillation.py --data-dir datasets/cfa_currency --epochs 80
python scripts/train_obstacle_distillation.py --data-yaml configs/obstacle_data.yaml --epochs 100

# Evaluate
python scripts/evaluate_models.py --currency-checkpoint checkpoints/currency_student_best.pth --currency-data datasets/cfa_currency

# Convert + benchmark
python scripts/convert_to_tflite.py --manifest configs/conversion_manifest.json
python scripts/benchmark_tflite.py exports/currency_detection_v1.tflite --input-shape 1,224,224,3

# Publish and register
python scripts/push_to_huggingface.py --manifest configs/publish_manifest.json
python scripts/register_model_in_backend.py --module-id MOD-04 --version 1.0.0 --filename currency_detection_v1.tflite --checksum <sha256>
```
