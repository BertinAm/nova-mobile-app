"""Benchmark a TFLite model locally or on Android via Python environment."""
from __future__ import annotations

import argparse
import time

import numpy as np


def parse_shape(value: str) -> tuple[int, ...]:
    return tuple(int(x.strip()) for x in value.split(","))


def benchmark_tflite(tflite_path: str, input_shape: tuple[int, ...], n_runs: int = 100) -> dict:
    import tensorflow as tf

    interpreter = tf.lite.Interpreter(model_path=tflite_path, num_threads=2)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    dtype = input_details[0]["dtype"]
    if dtype == np.int8:
        dummy = np.random.randint(-128, 127, input_shape, dtype=np.int8)
    elif dtype == np.uint8:
        dummy = np.random.randint(0, 255, input_shape, dtype=np.uint8)
    else:
        dummy = np.random.rand(*input_shape).astype(dtype)
    interpreter.set_tensor(input_details[0]["index"], dummy)
    for _ in range(5):
        interpreter.invoke()
    latencies = []
    for _ in range(n_runs):
        interpreter.set_tensor(input_details[0]["index"], dummy)
        start = time.perf_counter()
        interpreter.invoke()
        latencies.append((time.perf_counter() - start) * 1000)
    p50 = float(np.percentile(latencies, 50))
    p95 = float(np.percentile(latencies, 95))
    result = {"p50_ms": p50, "p95_ms": p95, "fps_median": 1000.0 / p50 if p50 else 0.0}
    print(tflite_path, result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("tflite_path")
    parser.add_argument("--input-shape", default="1,224,224,3")
    parser.add_argument("--runs", type=int, default=100)
    args = parser.parse_args()
    benchmark_tflite(args.tflite_path, parse_shape(args.input_shape), args.runs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
