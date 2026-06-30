from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_user
from app.core.rate_limit import rate_limit
from app.db.models import User
from app.db.session import get_db
from app.schemas.faces import DeleteFaceResponse, EnrolledFaceOut, FaceEnrollResponse, FaceMatchResponse
from app.services.face_service import FaceService

router = APIRouter(prefix="/faces", tags=["faces"], dependencies=[Depends(rate_limit)])


@router.post("/enroll", response_model=FaceEnrollResponse, status_code=status.HTTP_201_CREATED)
async def enroll_face(
    contact_name: str = Form(...),
    images: list[UploadFile] = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FaceEnrollResponse:
    if not 1 <= len(images) <= 5:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Upload 1 to 5 enrollment images")
    image_bytes = [await item.read() for item in images]
    row = FaceService(db).enroll(current_user.id, contact_name, image_bytes)
    return FaceEnrollResponse(contact_name=row.contact_name, enrolled_count=len(images), stored_face_id=row.id)


@router.post("/match", response_model=FaceMatchResponse)
async def match_face(
    face_crop: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FaceMatchResponse:
    data = await face_crop.read()
    if not data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Empty face crop")
    match = FaceService(db).match(current_user.id, data)
    message = None if match.match_found else "Unknown person detected"
    return FaceMatchResponse(
        match_found=match.match_found,
        contact_name=match.contact_name,
        similarity=match.similarity,
        threshold=match.threshold,
        message=message,
    )


@router.get("/list", response_model=list[EnrolledFaceOut])
def list_faces(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[EnrolledFaceOut]:
    rows = FaceService(db).list_faces(current_user.id)
    return [EnrolledFaceOut(id=row.id, contact_name=row.contact_name, created_at=row.created_at) for row in rows]


@router.delete("/{face_id}", response_model=DeleteFaceResponse)
def delete_face(
    face_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeleteFaceResponse:
    deleted = FaceService(db).delete_face(current_user.id, face_id=face_id)
    return DeleteFaceResponse(deleted=deleted)


@router.delete("/contact/{contact_name}", response_model=DeleteFaceResponse)
def delete_contact_faces(
    contact_name: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> DeleteFaceResponse:
    deleted = FaceService(db).delete_face(current_user.id, contact_name=contact_name)
    return DeleteFaceResponse(deleted=deleted)
