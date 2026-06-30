"""Evaluation utilities for NOVA ML models."""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix, roc_curve
from torch.utils.data import DataLoader
from torchvision import datasets, transforms


def evaluate_currency_model(model, test_loader, class_names, device, confidence_threshold: float = 0.85):
    model.eval()
    all_preds, all_labels, all_confs = [], [], []
    with torch.no_grad():
        for images, labels in test_loader:
            images = images.to(device)
            logits = model(images)
            probs = torch.softmax(logits, dim=1)
            confs, preds = probs.max(dim=1)
            all_preds.extend(preds.cpu().numpy())
            all_labels.extend(labels.numpy())
            all_confs.extend(confs.cpu().numpy())
    print("=== Currency Detection Evaluation ===")
    print(classification_report(all_labels, all_preds, target_names=class_names))
    print("Confusion Matrix:")
    print(confusion_matrix(all_labels, all_preds))
    mask = np.array(all_confs) >= confidence_threshold
    if mask.any():
        high_conf_acc = accuracy_score(np.array(all_labels)[mask], np.array(all_preds)[mask])
    else:
        high_conf_acc = 0.0
    print(f"Accuracy @ conf>={confidence_threshold}: {high_conf_acc:.4f} coverage={mask.mean():.2%}")
    return {"accuracy": accuracy_score(all_labels, all_preds), "high_conf_accuracy": high_conf_acc, "coverage": float(mask.mean())}


def evaluate_face_verification(model, pair_loader, threshold: float, device):
    model.eval()
    similarities, is_same = [], []
    with torch.no_grad():
        for img1, img2, same in pair_loader:
            emb1 = F.normalize(model(img1.to(device)), p=2, dim=1)
            emb2 = F.normalize(model(img2.to(device)), p=2, dim=1)
            sim = (emb1 * emb2).sum(dim=1).cpu().numpy()
            similarities.extend(sim)
            is_same.extend(same.numpy())
    similarities = np.array(similarities)
    is_same = np.array(is_same)
    preds = similarities >= threshold
    acc = accuracy_score(is_same, preds)
    fpr, tpr, _ = roc_curve(is_same, similarities)
    tar_at_far = tpr[min(np.searchsorted(fpr, 1e-3), len(tpr) - 1)]
    print(f"Face verification accuracy @ {threshold}: {acc:.4f}")
    print(f"TAR @ FAR=1e-3: {tar_at_far:.4f}")
    return {"accuracy": float(acc), "tar_at_far_1e-3": float(tar_at_far)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--currency-data", type=Path)
    parser.add_argument("--currency-checkpoint", type=Path)
    parser.add_argument("--simulate", action="store_true")
    args = parser.parse_args()
    if args.simulate:
        y_true = [0, 1, 2, 3, 4]
        y_pred = [0, 1, 2, 3, 4]
        print("Simulation accuracy:", accuracy_score(y_true, y_pred))
        return 0
    if not args.currency_data or not args.currency_checkpoint:
        raise SystemExit("Pass --currency-data and --currency-checkpoint, or use --simulate")
    import timm
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    tf = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    ds = datasets.ImageFolder(args.currency_data / "test", transform=tf)
    loader = DataLoader(ds, batch_size=32, shuffle=False)
    model = timm.create_model("mobilenetv3_small_100", pretrained=False, num_classes=5)
    ckpt = torch.load(args.currency_checkpoint, map_location="cpu")
    model.load_state_dict(ckpt.get("model_state", ckpt))
    model.to(device)
    evaluate_currency_model(model, loader, ds.classes, device)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
