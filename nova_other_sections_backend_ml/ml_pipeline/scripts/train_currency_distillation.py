"""MOD-04 currency detection distillation training.

Real mode expects ImageFolder data:
    datasets/cfa_currency/train/fcfa_500/*.jpg ...

Simulation mode runs on torchvision FakeData and only verifies the pipeline.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
import timm
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from tqdm import tqdm

CLASSES = ["fcfa_500", "fcfa_1000", "fcfa_2000", "fcfa_5000", "fcfa_10000"]


def build_loaders(data_dir: Path, batch_size: int, simulate: bool):
    train_tf = transforms.Compose([
        transforms.Resize((256, 256)),
        transforms.RandomCrop(224),
        transforms.RandomHorizontalFlip(),
        transforms.RandomVerticalFlip(p=0.2),
        transforms.ColorJitter(brightness=0.4, contrast=0.4, saturation=0.3),
        transforms.RandomRotation(degrees=30),
        transforms.RandomPerspective(distortion_scale=0.3, p=0.5),
        transforms.GaussianBlur(kernel_size=3, sigma=(0.1, 1.5)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    val_tf = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])
    if simulate:
        train_ds = datasets.FakeData(size=128, image_size=(3, 224, 224), num_classes=5, transform=train_tf)
        val_ds = datasets.FakeData(size=32, image_size=(3, 224, 224), num_classes=5, transform=val_tf)
    else:
        train_ds = datasets.ImageFolder(data_dir / "train", transform=train_tf)
        val_ds = datasets.ImageFolder(data_dir / "val", transform=val_tf)
    return (
        DataLoader(train_ds, batch_size=batch_size, shuffle=True, num_workers=2),
        DataLoader(val_ds, batch_size=batch_size, shuffle=False, num_workers=2),
    )


def evaluate(model: nn.Module, loader: DataLoader, device: torch.device) -> float:
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for images, labels in loader:
            images, labels = images.to(device), labels.to(device)
            preds = model(images).argmax(dim=1)
            correct += int((preds == labels).sum().item())
            total += int(labels.numel())
    return correct / max(1, total)


def distillation_loss(student_logits, teacher_logits, labels, *, temperature: float, alpha: float):
    soft_teacher = F.softmax(teacher_logits / temperature, dim=1)
    soft_student = F.log_softmax(student_logits / temperature, dim=1)
    kd = F.kl_div(soft_student, soft_teacher, reduction="batchmean") * (temperature ** 2)
    hard = F.cross_entropy(student_logits, labels)
    return alpha * kd + (1 - alpha) * hard


def train(args: argparse.Namespace) -> Path:
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    train_loader, val_loader = build_loaders(args.data_dir, args.batch_size, args.simulate)

    teacher = timm.create_model("efficientnet_b4", pretrained=not args.simulate, num_classes=5).to(device)
    student = timm.create_model("mobilenetv3_small_100", pretrained=not args.simulate, num_classes=5).to(device)

    # Phase 1: fine-tune teacher on CFA data.
    teacher_optimizer = torch.optim.AdamW(teacher.parameters(), lr=1e-4, weight_decay=1e-4)
    teacher_scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(teacher_optimizer, T_max=max(1, args.teacher_epochs))
    for epoch in range(args.teacher_epochs):
        teacher.train()
        running = 0.0
        for images, labels in tqdm(train_loader, desc=f"teacher {epoch+1}/{args.teacher_epochs}"):
            images, labels = images.to(device), labels.to(device)
            loss = F.cross_entropy(teacher(images), labels)
            teacher_optimizer.zero_grad(set_to_none=True)
            loss.backward()
            teacher_optimizer.step()
            running += float(loss.item())
        teacher_scheduler.step()
        print(f"teacher_epoch={epoch+1} loss={running:.3f} val_acc={evaluate(teacher, val_loader, device):.3f}")

    teacher.eval()
    for p in teacher.parameters():
        p.requires_grad = False

    # Phase 2: distill student.
    optimizer = torch.optim.AdamW(student.parameters(), lr=args.lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=max(1, args.epochs))
    best_acc = -1.0
    args.output_dir.mkdir(parents=True, exist_ok=True)
    best_path = args.output_dir / "currency_student_best.pth"

    for epoch in range(args.epochs):
        student.train()
        running = 0.0
        for images, labels in tqdm(train_loader, desc=f"student {epoch+1}/{args.epochs}"):
            images, labels = images.to(device), labels.to(device)
            with torch.no_grad():
                teacher_logits = teacher(images)
            student_logits = student(images)
            loss = distillation_loss(
                student_logits, teacher_logits, labels,
                temperature=args.temperature,
                alpha=args.alpha,
            )
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            optimizer.step()
            running += float(loss.item())
        scheduler.step()
        acc = evaluate(student, val_loader, device)
        print(f"student_epoch={epoch+1} loss={running:.3f} val_acc={acc:.3f}")
        if acc > best_acc:
            best_acc = acc
            torch.save({"model_state": student.state_dict(), "classes": CLASSES, "architecture": "mobilenetv3_small_100"}, best_path)
            print(f"saved {best_path} val_acc={best_acc:.3f}")
    return best_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-dir", type=Path, default=Path("datasets/cfa_currency"))
    parser.add_argument("--output-dir", type=Path, default=Path("checkpoints"))
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--teacher-epochs", type=int, default=30)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--temperature", type=float, default=5.0)
    parser.add_argument("--alpha", type=float, default=0.8)
    parser.add_argument("--simulate", action="store_true", help="Use FakeData for a quick pipeline test")
    return parser.parse_args()


if __name__ == "__main__":
    train(parse_args())
