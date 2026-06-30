from pathlib import Path
from typing import List

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.models import ModelRegistry

settings = get_settings()


class ModelRegistryService:
    def __init__(self, db: Session):
        self.db = db

    def register(
        self,
        *,
        module_id: str,
        version: str,
        filename: str,
        checksum: str,
        download_url: str | None,
        huggingface_repo: str | None,
        tflite_path: str | None,
        is_active: bool,
        notes: str | None,
    ) -> ModelRegistry:
        if is_active:
            self.db.execute(
                update(ModelRegistry)
                .where(ModelRegistry.module_id == module_id)
                .values(is_active=False)
            )
        row = ModelRegistry(
            module_id=module_id,
            version=version,
            filename=filename,
            checksum=checksum.lower(),
            download_url=download_url,
            huggingface_repo=huggingface_repo,
            tflite_path=tflite_path,
            is_active=is_active,
            notes=notes,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return row

    def latest(self, module_id: str) -> ModelRegistry | None:
        return self.db.scalar(
            select(ModelRegistry)
            .where(ModelRegistry.module_id == module_id, ModelRegistry.is_active.is_(True))
            .order_by(ModelRegistry.uploaded_at.desc())
        )

    def list(self, module_id: str | None = None) -> List[ModelRegistry]:
        stmt = select(ModelRegistry).order_by(ModelRegistry.module_id, ModelRegistry.uploaded_at.desc())
        if module_id:
            stmt = stmt.where(ModelRegistry.module_id == module_id)
        return list(self.db.scalars(stmt).all())

    def file_path(self, model: ModelRegistry) -> Path | None:
        if model.tflite_path:
            candidate = Path(model.tflite_path)
            if candidate.exists():
                return candidate
        candidate = Path(settings.model_store_path) / model.filename
        if candidate.exists():
            return candidate
        return None
