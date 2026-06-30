from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse, RedirectResponse
from sqlalchemy.orm import Session

from app.core.deps import require_admin
from app.db.models import ModelRegistry, User
from app.db.session import get_db
from app.schemas.models import ModelListResponse, ModelOut, ModelRegisterRequest
from app.services.model_registry_service import ModelRegistryService

router = APIRouter(prefix="/models", tags=["models"])


def _to_model_out(row) -> ModelOut:
    return ModelOut(
        id=row.id,
        module_id=row.module_id,
        version=row.version,
        filename=row.filename,
        checksum=row.checksum,
        download_url=row.download_url,
        huggingface_repo=row.huggingface_repo,
        uploaded_at=row.uploaded_at,
        is_active=row.is_active,
        notes=row.notes,
    )


@router.get("/latest", response_model=ModelOut)
def latest_model(module_id: str = Query(...), db: Session = Depends(get_db)) -> ModelOut:
    row = ModelRegistryService(db).latest(module_id)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No active model found for module")
    return _to_model_out(row)


@router.get("/list", response_model=ModelListResponse)
def list_models(module_id: str | None = None, db: Session = Depends(get_db)) -> ModelListResponse:
    rows = ModelRegistryService(db).list(module_id=module_id)
    return ModelListResponse(models=[_to_model_out(row) for row in rows])


@router.post("/register", response_model=ModelOut, status_code=status.HTTP_201_CREATED)
def register_model(
    payload: ModelRegisterRequest,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
) -> ModelOut:
    _ = admin
    row = ModelRegistryService(db).register(**payload.model_dump())
    return _to_model_out(row)


@router.get("/download/{model_id}")
def download_model(model_id: str, db: Session = Depends(get_db)):
    row = db.get(ModelRegistry, model_id)
    if row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Model not found")
    service = ModelRegistryService(db)
    path = service.file_path(row)
    if path:
        return FileResponse(str(path), media_type="application/octet-stream", filename=row.filename)
    if row.download_url:
        return RedirectResponse(row.download_url)
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Model file is not available")
