from fastapi import APIRouter

from app.api.v1.routes import auth, emergency, faces, health, logs, models, scene

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(scene.router)
api_router.include_router(faces.router)
api_router.include_router(models.router)
api_router.include_router(logs.router)
api_router.include_router(emergency.router)
