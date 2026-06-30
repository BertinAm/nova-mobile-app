import hashlib
import io
from dataclasses import dataclass
from typing import Iterable, List

import numpy as np
from PIL import Image
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.crypto import decrypt_embedding, encrypt_embedding
from app.db.models import EnrolledFace

settings = get_settings()


@dataclass(frozen=True)
class FaceMatch:
    match_found: bool
    contact_name: str | None
    similarity: float | None
    threshold: float


class FaceService:
    """Face enrollment and matching service.

    Simulation mode creates deterministic embeddings from image pixels. Production
    should replace _embedding_from_bytes() with face alignment + MobileFaceNet or
    ArcFace embedding extraction. The encryption/storage and API behavior remain
    the same.
    """

    def __init__(self, db: Session):
        self.db = db

    def enroll(self, user_id: str, contact_name: str, images: Iterable[bytes]) -> EnrolledFace:
        embeddings = [self._embedding_from_bytes(data) for data in images]
        if not embeddings:
            raise ValueError("At least one face image is required")
        mean_embedding = self._l2_normalize(np.mean(np.stack(embeddings), axis=0))
        encrypted = encrypt_embedding(mean_embedding.tolist(), user_id=user_id)
        row = EnrolledFace(user_id=user_id, contact_name=contact_name.strip(), embedding_ciphertext=encrypted)
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return row

    def list_faces(self, user_id: str) -> List[EnrolledFace]:
        return list(self.db.scalars(select(EnrolledFace).where(EnrolledFace.user_id == user_id)).all())

    def delete_face(self, user_id: str, face_id: str | None = None, contact_name: str | None = None) -> int:
        query = delete(EnrolledFace).where(EnrolledFace.user_id == user_id)
        if face_id:
            query = query.where(EnrolledFace.id == face_id)
        if contact_name:
            query = query.where(EnrolledFace.contact_name == contact_name)
        result = self.db.execute(query)
        self.db.commit()
        return int(result.rowcount or 0)

    def match(self, user_id: str, face_crop: bytes) -> FaceMatch:
        query_embedding = self._embedding_from_bytes(face_crop)
        best_name: str | None = None
        best_score = -1.0
        for row in self.list_faces(user_id):
            gallery = np.array(decrypt_embedding(row.embedding_ciphertext, user_id=user_id), dtype=np.float32)
            score = float(np.dot(query_embedding, gallery))
            if score > best_score:
                best_score = score
                best_name = row.contact_name
        if best_name is None:
            return FaceMatch(False, None, None, settings.face_match_threshold)
        if best_score >= settings.face_match_threshold:
            return FaceMatch(True, best_name, best_score, settings.face_match_threshold)
        return FaceMatch(False, None, best_score, settings.face_match_threshold)

    def _embedding_from_bytes(self, image_bytes: bytes) -> np.ndarray:
        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("L").resize((32, 32))
            pixels = np.asarray(image, dtype=np.float32).flatten() / 255.0
            digest = hashlib.sha256(image_bytes).digest()
            noise = np.frombuffer(digest * 32, dtype=np.uint8)[:512].astype(np.float32) / 255.0
            vec = np.concatenate([pixels[:512], noise])[:512]
        except Exception:
            digest = hashlib.sha256(image_bytes).digest()
            vec = np.frombuffer(digest * 16, dtype=np.uint8).astype(np.float32)[:512] / 255.0
        return self._l2_normalize(vec)

    @staticmethod
    def _l2_normalize(vec: np.ndarray) -> np.ndarray:
        norm = float(np.linalg.norm(vec))
        if norm == 0:
            return vec
        return (vec / norm).astype(np.float32)
