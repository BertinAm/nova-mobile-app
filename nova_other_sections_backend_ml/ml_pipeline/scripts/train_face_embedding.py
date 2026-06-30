"""MOD-05 face embedding distillation utilities.

Real production training should use MS1MV2 and a MobileFaceNet implementation.
The included TinyMobileFaceNet supports --simulate to verify loss, optimizer,
and checkpointing without the large dataset.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from tqdm import tqdm


class ArcFaceLoss(nn.Module):
    def __init__(self, num_classes: int, embedding_dim: int, scale: float = 64.0, margin: float = 0.5):
        super().__init__()
        self.scale = scale
        self.margin = margin
        self.weight = nn.Parameter(torch.empty(num_classes, embedding_dim))
        nn.init.xavier_uniform_(self.weight)

    def forward(self, embeddings: torch.Tensor, labels: torch.Tensor) -> torch.Tensor:
        emb_norm = F.normalize(embeddings, p=2, dim=1)
        w_norm = F.normalize(self.weight, p=2, dim=1)
        cosine = F.linear(emb_norm, w_norm)
        theta = torch.acos(cosine.clamp(-1 + 1e-6, 1 - 1e-6))
        target_logits = torch.cos(theta + self.margin)
        one_hot = torch.zeros_like(cosine)
        one_hot.scatter_(1, labels.view(-1, 1), 1.0)
        output = cosine * (1 - one_hot) + target_logits * one_hot
        return F.cross_entropy(output * self.scale, labels)


class EmbeddingDistillationLoss(nn.Module):
    def __init__(self, alpha: float = 0.6):
        super().__init__()
        self.alpha = alpha

    def forward(self, student_emb: torch.Tensor, teacher_emb: torch.Tensor, arcface_loss: torch.Tensor) -> torch.Tensor:
        s = F.normalize(student_emb, p=2, dim=1)
        t = F.normalize(teacher_emb, p=2, dim=1)
        emb_loss = F.mse_loss(s, t)
        return self.alpha * emb_loss + (1 - self.alpha) * arcface_loss


class TinyMobileFaceNet(nn.Module):
    def __init__(self, embedding_dim: int = 512):
        super().__init__()
        self.net = nn.Sequential(
            nn.Conv2d(3, 32, 3, stride=2, padding=1), nn.BatchNorm2d(32), nn.ReLU(inplace=True),
            nn.Conv2d(32, 64, 3, stride=2, padding=1), nn.BatchNorm2d(64), nn.ReLU(inplace=True),
            nn.Conv2d(64, 128, 3, stride=2, padding=1), nn.BatchNorm2d(128), nn.ReLU(inplace=True),
            nn.AdaptiveAvgPool2d(1), nn.Flatten(), nn.Linear(128, embedding_dim),
        )

    def forward(self, x):
        return F.normalize(self.net(x), p=2, dim=1)


def simulate(args: argparse.Namespace) -> Path:
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    tf = transforms.Compose([transforms.Resize((112, 112)), transforms.ToTensor()])
    dataset = datasets.FakeData(size=128, image_size=(3, 112, 112), num_classes=args.num_classes, transform=tf)
    loader = DataLoader(dataset, batch_size=args.batch_size, shuffle=True)
    teacher = TinyMobileFaceNet().to(device).eval()
    student = TinyMobileFaceNet().to(device)
    arcface = ArcFaceLoss(args.num_classes, 512).to(device)
    kd_loss = EmbeddingDistillationLoss(alpha=0.6)
    optimizer = torch.optim.SGD(list(student.parameters()) + list(arcface.parameters()), lr=0.05, momentum=0.9)
    for epoch in range(args.epochs):
        for images, labels in tqdm(loader, desc=f"face-embed {epoch+1}/{args.epochs}"):
            images, labels = images.to(device), labels.to(device)
            with torch.no_grad():
                teacher_emb = teacher(images)
            student_emb = student(images)
            loss = kd_loss(student_emb, teacher_emb, arcface(student_emb, labels))
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            optimizer.step()
        print(f"epoch={epoch+1} loss={loss.item():.4f}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    path = args.output_dir / "face_embedding_best.pth"
    torch.save({"model_state": student.state_dict(), "architecture": "TinyMobileFaceNet", "embedding_dim": 512}, path)
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--simulate", action="store_true", help="Run a tiny fake-data training loop")
    parser.add_argument("--output-dir", type=Path, default=Path("checkpoints"))
    parser.add_argument("--epochs", type=int, default=2)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--num-classes", type=int, default=10)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    if not args.simulate:
        raise SystemExit("Production MS1MV2 training requires a real MobileFaceNet implementation. Use --simulate to verify pipeline.")
    print("saved", simulate(args))
