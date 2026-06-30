from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware

from app.api.v1.api import api_router
from app.core.config import get_settings
from app.db.session import init_db

settings = get_settings()


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version="1.0.0",
        description="NOVA backend for scene description, face matching, model registry, logs sync, and auth.",
        openapi_url=f"{settings.api_v1_prefix}/openapi.json",
        docs_url="/docs",
    )

    if settings.is_production:
        app.add_middleware(HTTPSRedirectMiddleware)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.on_event("startup")
    def _startup() -> None:
        Path(settings.model_store_path).mkdir(parents=True, exist_ok=True)
        init_db()

    app.include_router(api_router, prefix=settings.api_v1_prefix)
    return app


app = create_app()
