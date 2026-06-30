from datetime import datetime
from pydantic import BaseModel, Field


class UsageEventIn(BaseModel):
    id: str = Field(max_length=64)
    module_id: str = Field(max_length=20)
    timestamp: datetime
    outcome: str = Field(max_length=80)
    confidence_score: float | None = Field(default=None, ge=0.0, le=1.0)


class UsageSyncRequest(BaseModel):
    events: list[UsageEventIn]


class FeedbackIn(BaseModel):
    id: str = Field(max_length=64)
    event_id: str = Field(max_length=64)
    is_positive: bool
    timestamp: datetime


class FeedbackSyncRequest(BaseModel):
    feedbacks: list[FeedbackIn]


class SyncResponse(BaseModel):
    accepted: int
    duplicates: int
