from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Literal
from uuid import uuid4

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import get_settings

settings = get_settings()

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__rounds=settings.password_bcrypt_rounds,
)

TokenType = Literal["access", "refresh"]


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def _token_secret(token_type: TokenType) -> str:
    return settings.secret_key if token_type == "access" else settings.refresh_secret_key


def create_token(subject: str, token_type: TokenType, expires_delta: timedelta | None = None) -> str:
    now = datetime.now(timezone.utc)
    if expires_delta is None:
        expires_delta = (
            timedelta(minutes=settings.access_token_minutes)
            if token_type == "access"
            else timedelta(days=settings.refresh_token_days)
        )
    payload: Dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int((now + expires_delta).timestamp()),
        "jti": str(uuid4()),
    }
    return jwt.encode(payload, _token_secret(token_type), algorithm="HS256")


def create_access_token(subject: str) -> str:
    return create_token(subject, "access")


def create_refresh_token(subject: str) -> str:
    return create_token(subject, "refresh")


def decode_token(token: str, expected_type: TokenType) -> Dict[str, Any]:
    try:
        payload = jwt.decode(token, _token_secret(expected_type), algorithms=["HS256"])
    except JWTError as exc:
        raise ValueError("Invalid token") from exc
    if payload.get("type") != expected_type:
        raise ValueError("Invalid token type")
    return payload


def hash_token_for_storage(token: str) -> str:
    """Hash refresh tokens before storing so DB leakage does not expose live tokens."""

    return pwd_context.hash(token)


def verify_stored_token(token: str, stored_hash: str) -> bool:
    return pwd_context.verify(token, stored_hash)
