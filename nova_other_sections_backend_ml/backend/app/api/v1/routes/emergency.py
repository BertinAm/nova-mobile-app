from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.emergency import EmergencyContactOut, EmergencyContactSetRequest, EmergencyShareRequest, EmergencyShareResponse
from app.services.emergency_service import EmergencyService

router = APIRouter(prefix="/emergency", tags=["emergency"])


@router.put("/contact", response_model=EmergencyContactOut)
def set_contact(
    payload: EmergencyContactSetRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> EmergencyContactOut:
    row = EmergencyService(db).set_contact(current_user.id, payload.name, payload.phone_number)
    return EmergencyContactOut(id=row.id, name=row.name, phone_number=payload.phone_number)


@router.get("/contact", response_model=EmergencyContactOut)
def get_contact(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> EmergencyContactOut:
    contact = EmergencyService(db).get_contact(current_user.id)
    if contact is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Emergency contact not configured")
    row, phone = contact
    return EmergencyContactOut(id=row.id, name=row.name, phone_number=phone)


@router.post("/share-location", response_model=EmergencyShareResponse)
def share_location(
    payload: EmergencyShareRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> EmergencyShareResponse:
    phone, body = EmergencyService(db).build_sms(
        current_user.id, payload.latitude, payload.longitude, payload.accuracy_meters
    )
    return EmergencyShareResponse(
        message="Send this SMS body through the mobile platform SMS channel.",
        sms_body=body,
        phone_number=phone,
    )
