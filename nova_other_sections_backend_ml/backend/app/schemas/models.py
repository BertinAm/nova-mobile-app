from datetime import datetime
from pydantic import BaseModel, Field


class ModelRegisterRequest(BaseModel):
    module_id: str = Field(max_length=32)
    version: str = Field(max_length=32)
    filename: str = Field(max_length=255)
    checksum: str = Field(min_length=64, max_length=64)
    download_url: str | None = None
    huggingface_repo: str | None = None
    tflite_path: str | None = None
    is_active: bool = True
    notes: str | None = None


class ModelOut(BaseModel):
    id: str
    module_id: str
    version: str
    filename: str
    checksum: str
    download_url: str | None = None
    huggingface_repo: str | None = None
    uploaded_at: datetime
    is_active: bool
    notes: str | None = None


class ModelListResponse(BaseModel):
    models: list[ModelOut]
