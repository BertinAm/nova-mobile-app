"""Knowledge distillation losses for YOLO-style detection.

Use this file as the integration point for Ultralytics custom trainer overrides.
The loss itself is framework-independent and testable.
"""
from __future__ import annotations

import torch
import torch.nn as nn
import torch.nn.functional as F


class DistillationLoss(nn.Module):
    def __init__(self, temperature: float = 4.0, alpha: float = 0.7, beta: float = 0.3):
        super().__init__()
        self.temperature = temperature
        self.alpha = alpha
        self.beta = beta

    def forward(
        self,
        student_cls_logits: torch.Tensor,
        teacher_cls_logits: torch.Tensor,
        student_box_loss: torch.Tensor,
        gt_cls_loss: torch.Tensor,
    ) -> torch.Tensor:
        teacher_soft = F.softmax(teacher_cls_logits / self.temperature, dim=-1)
        student_log_soft = F.log_softmax(student_cls_logits / self.temperature, dim=-1)
        kd_loss = F.kl_div(student_log_soft, teacher_soft, reduction="batchmean") * (self.temperature ** 2)
        return self.alpha * kd_loss + self.beta * (student_box_loss + gt_cls_loss)


def align_teacher_logits(teacher_cls: torch.Tensor, student_cls: torch.Tensor) -> torch.Tensor:
    """Align teacher anchors/spatial dimension to student anchors when shapes differ."""

    if teacher_cls.shape == student_cls.shape:
        return teacher_cls
    # Expected [batch, anchors, classes]. Interpolate the anchors axis.
    return F.interpolate(
        teacher_cls.permute(0, 2, 1),
        size=student_cls.shape[1],
        mode="linear",
        align_corners=False,
    ).permute(0, 2, 1)


class KDDetectionTrainerMixin:
    """Mixin showing where to inject KD into an Ultralytics DetectionTrainer.

    Example:
        class KDDetectionTrainer(KDDetectionTrainerMixin, DetectionTrainer):
            pass

    Then set self.teacher before training. The exact hook signature may need a
    small adjustment depending on the installed Ultralytics version.
    """

    kd_loss_fn = DistillationLoss()

    def criterion(self, preds, batch):  # pragma: no cover - depends on ultralytics internals
        gt_loss, gt_loss_items = super().criterion(preds, batch)
        with torch.no_grad():
            teacher_preds = self.teacher.model(batch["img"])
        student_cls = preds[0][..., 5:]
        teacher_cls = align_teacher_logits(teacher_preds[0][..., 5:], student_cls)
        kd_total = self.kd_loss_fn(student_cls, teacher_cls, gt_loss_items[1], gt_loss_items[0])
        return kd_total, gt_loss_items
