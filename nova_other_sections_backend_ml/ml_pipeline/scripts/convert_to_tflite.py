"""PyTorch -> ONNX -> TensorFlow SavedModel -> TFLite INT8 conversion."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Callable

import numpy as np
import torch
import torch.nn as nn


def export_pytorch_to_onnx(model: nn.Module, input_shape: tuple[int, ...], output_path: str, opset: int = 17) -> str:
    import onnx

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    model.eval()
    dummy = torch.randn(*input_shape)
    torch.onnx.export(
        model,
        dummy,
        output_path,
        opset_version=opset,
        input_names=["input"],
        output_names=["output"],
        dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
        do_constant_folding=True,
    )
    onnx_model = onnx.load(output_path)
    onnx.checker.check_model(onnx_model)
    print(f"ONNX exported: {output_path}")
    return output_path


def make_random_representative_dataset(input_shape_nhwc: tuple[int, ...], n_samples: int = 100) -> Callable:
    def generator():
        for _ in range(n_samples):
            yield [np.random.uniform(-1, 1, input_shape_nhwc).astype(np.float32)]
    return generator


def convert_onnx_to_tflite_int8(onnx_path: str, tflite_output_path: str, representative_dataset_gen: Callable) -> str:
    import onnx
    import tensorflow as tf
    from onnx_tf.backend import prepare

    onnx_model = onnx.load(onnx_path)
    tf_rep = prepare(onnx_model)
    saved_model_dir = onnx_path.replace(".onnx", "_saved_model")
    tf_rep.export_graph(saved_model_dir)

    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative_dataset_gen
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.int8
    converter.inference_output_type = tf.int8
    tflite_model = converter.convert()
    Path(tflite_output_path).parent.mkdir(parents=True, exist_ok=True)
    Path(tflite_output_path).write_bytes(tflite_model)
    print(f"TFLite INT8 saved: {tflite_output_path} ({len(tflite_model)/(1024*1024):.2f} MB)")
    return tflite_output_path


class TinyClassifier(nn.Module):
    def __init__(self, num_classes: int = 5):
        super().__init__()
        self.net = nn.Sequential(nn.Flatten(), nn.Linear(3 * 224 * 224, num_classes))

    def forward(self, x):
        return self.net(x)


def load_model_from_manifest(item: dict) -> nn.Module:
    if item.get("kind") == "timm_classifier":
        import timm
        model = timm.create_model(item["architecture"], pretrained=False, num_classes=int(item["num_classes"]))
        ckpt = torch.load(item["checkpoint"], map_location="cpu")
        model.load_state_dict(ckpt.get("model_state", ckpt), strict=False)
        return model
    loaded = torch.load(item["checkpoint"], map_location="cpu")
    if isinstance(loaded, nn.Module):
        return loaded
    raise ValueError(f"Cannot reconstruct model from manifest item: {item['name']}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=Path("configs/conversion_manifest.json"))
    parser.add_argument("--simulate", action="store_true")
    parser.add_argument("--export-only-onnx", action="store_true")
    args = parser.parse_args()

    if args.simulate:
        model = TinyClassifier()
        export_pytorch_to_onnx(model, (1, 3, 224, 224), "exports/simulated_currency.onnx")
        print("Simulation exported ONNX. TFLite conversion needs tensorflow and onnx-tf installed.")
        return 0

    manifest = json.loads(args.manifest.read_text())
    for item in manifest["models"]:
        model = load_model_from_manifest(item)
        shape_nchw = tuple(item["input_shape_nchw"])
        export_pytorch_to_onnx(model, shape_nchw, item["onnx_path"])
        if not args.export_only_onnx:
            n, c, h, w = shape_nchw
            gen = make_random_representative_dataset((n, h, w, c), n_samples=100)
            convert_onnx_to_tflite_int8(item["onnx_path"], item["tflite_path"], gen)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
