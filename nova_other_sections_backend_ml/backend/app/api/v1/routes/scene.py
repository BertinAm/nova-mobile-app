from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.core.config import get_settings
from app.core.deps import get_current_user
from app.core.rate_limit import rate_limit
from app.db.models import User
from app.schemas.scene import SceneDescriptionResponse
from app.services.scene_service import SceneService

settings = get_settings()
router = APIRouter(prefix="/scene", tags=["scene"], dependencies=[Depends(rate_limit)])


@router.post("/describe", response_model=SceneDescriptionResponse)
async def describe_scene(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
) -> SceneDescriptionResponse:
    # current_user is intentionally used for auth, not for image persistence.
    _ = current_user
    if image.content_type not in {"image/jpeg", "image/jpg", "image/png", "application/octet-stream"}:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail="Only image upload is supported")
    data = await image.read()
    max_bytes = settings.max_scene_image_kb * 1024
    if len(data) > max_bytes * 2:
        # Mobile should compress to <=512 KB. Allow slight tolerance but reject huge files.
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Image is too large")
    try:
        result = SceneService().describe_scene(data)
    except Exception as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Scene description unavailable") from exc
    return SceneDescriptionResponse(
        description=result.description,
        provider=result.provider,
        processing_ms=result.processing_ms,
    )
