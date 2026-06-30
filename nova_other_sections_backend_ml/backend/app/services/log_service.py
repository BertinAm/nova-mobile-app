from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import UsageEvent, UserFeedback
from app.schemas.logs import FeedbackIn, UsageEventIn


class LogService:
    def __init__(self, db: Session):
        self.db = db

    def sync_usage_events(self, user_id: str, events: list[UsageEventIn]) -> tuple[int, int]:
        accepted = 0
        duplicates = 0
        for event in events:
            exists = self.db.scalar(select(UsageEvent.id).where(UsageEvent.event_id == event.id))
            if exists is not None:
                duplicates += 1
                continue
            self.db.add(
                UsageEvent(
                    event_id=event.id,
                    user_id=user_id,
                    module_id=event.module_id,
                    timestamp=event.timestamp,
                    outcome=event.outcome,
                    confidence_score=event.confidence_score,
                )
            )
            accepted += 1
        self.db.commit()
        return accepted, duplicates

    def sync_feedbacks(self, user_id: str, feedbacks: list[FeedbackIn]) -> tuple[int, int]:
        accepted = 0
        duplicates = 0
        for feedback in feedbacks:
            exists = self.db.scalar(select(UserFeedback.id).where(UserFeedback.feedback_id == feedback.id))
            if exists is not None:
                duplicates += 1
                continue
            self.db.add(
                UserFeedback(
                    feedback_id=feedback.id,
                    event_id=feedback.event_id,
                    user_id=user_id,
                    is_positive=feedback.is_positive,
                    timestamp=feedback.timestamp,
                )
            )
            accepted += 1
        self.db.commit()
        return accepted, duplicates
