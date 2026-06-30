from pydantic import BaseModel, Field


class SceneDescriptionResponse(BaseModel):
    description: str = Field(max_length=600)
    provider: str
    processing_ms: int
