from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.logs import FeedbackSyncRequest, SyncResponse, UsageSyncRequest
from app.services.log_service import LogService

router = APIRouter(prefix="/logs", tags=["logs"])


@router.post("/sync", response_model=SyncResponse)
def sync_usage_events(
    payload: UsageSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SyncResponse:
    accepted, duplicates = LogService(db).sync_usage_events(current_user.id, payload.events)
    return SyncResponse(accepted=accepted, duplicates=duplicates)


@router.post("/feedback/sync", response_model=SyncResponse)
def sync_feedback(
    payload: FeedbackSyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SyncResponse:
    accepted, duplicates = LogService(db).sync_feedbacks(current_user.id, payload.feedbacks)
    return SyncResponse(accepted=accepted, duplicates=duplicates)
