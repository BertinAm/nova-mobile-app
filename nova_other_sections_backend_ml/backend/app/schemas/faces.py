from datetime import datetime
from pydantic import BaseModel, Field


class EnrolledFaceOut(BaseModel):
    id: str
    contact_name: str
    created_at: datetime


class FaceEnrollResponse(BaseModel):
    contact_name: str
    enrolled_count: int
    stored_face_id: str


class FaceMatchResponse(BaseModel):
    match_found: bool
    contact_name: str | None = None
    similarity: float | None = None
    threshold: float
    message: str | None = None


class DeleteFaceResponse(BaseModel):
    deleted: int = Field(ge=0)
