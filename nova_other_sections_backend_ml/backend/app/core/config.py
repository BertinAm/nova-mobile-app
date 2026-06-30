from functools import lru_cache
from typing import List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables.

    The NOVA_ prefix keeps deployment variables explicit and prevents accidental
    collisions with system-level variables on the VPS.
    """

    model_config = SettingsConfigDict(env_prefix="NOVA_", env_file=".env", extra="ignore")

    app_name: str = "NOVA Assistive Backend"
    environment: str = "development"
    api_v1_prefix: str = "/api/v1"
    database_url: str = "sqlite:///./nova_dev.db"

    secret_key: str = "change-me-access-secret-at-least-32-bytes"
    refresh_secret_key: str = "change-me-refresh-secret-at-least-32-bytes"
    access_token_minutes: int = 60 * 24
    refresh_token_days: int = 30
    password_bcrypt_rounds: int = 12

    # Base64-encoded 32-byte key for AES-256-GCM. Dev default is insecure.
    aes_gcm_key_b64: str = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

    rate_limit_per_minute: int = 60
    cors_origins: str = "*"
    model_store_path: str = "./model_store"
    scene_provider: str = "simulated"
    face_match_threshold: float = 0.75
    large_gallery_threshold: int = 20
    max_scene_image_kb: int = 512

    @field_validator("cors_origins")
    @classmethod
    def strip_origins(cls, value: str) -> str:
        return value.strip()

    @property
    def cors_origin_list(self) -> List[str]:
        if self.cors_origins == "*":
            return ["*"]
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]

    @property
    def is_production(self) -> bool:
        return self.environment.lower() == "production"


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
