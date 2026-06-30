from datetime import datetime, timedelta, timezone
from typing import Tuple

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    hash_token_for_storage,
    verify_password,
    verify_stored_token,
)
from app.core.config import get_settings
from app.db.models import RefreshToken, User, utcnow

settings = get_settings()


class AuthError(Exception):
    pass


class AuthService:
    def __init__(self, db: Session):
        self.db = db

    def register(self, email: str, password: str, preferred_language: str) -> Tuple[User, str, str]:
        existing = self.db.scalar(select(User).where(User.email == email.lower()))
        if existing:
            raise AuthError("Email is already registered")
        user = User(
            email=email.lower(),
            password_hash=hash_password(password),
            preferred_language=preferred_language,
            # The first created user becomes admin in local demos. Remove this rule in production.
            is_admin=self.db.scalar(select(User.id).limit(1)) is None,
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        access, refresh = self._issue_tokens(user)
        return user, access, refresh

    def login(self, email: str, password: str) -> Tuple[User, str, str]:
        user = self.db.scalar(select(User).where(User.email == email.lower()))
        if user is None or not verify_password(password, user.password_hash):
            raise AuthError("Invalid email or password")
        access, refresh = self._issue_tokens(user)
        return user, access, refresh

    def refresh(self, refresh_token: str) -> Tuple[User, str, str]:
        try:
            payload = decode_token(refresh_token, "refresh")
        except ValueError as exc:
            raise AuthError("Invalid refresh token") from exc
        user_id = payload["sub"]
        jti = payload["jti"]
        token_row = self.db.scalar(select(RefreshToken).where(RefreshToken.jti == jti))
        if token_row is None or token_row.revoked_at is not None:
            raise AuthError("Refresh token has been revoked")
        if token_row.expires_at < utcnow():
            raise AuthError("Refresh token has expired")
        if not verify_stored_token(refresh_token, token_row.token_hash):
            raise AuthError("Invalid refresh token")
        user = self.db.get(User, user_id)
        if user is None:
            raise AuthError("User not found")
        token_row.revoked_at = utcnow()
        self.db.add(token_row)
        self.db.commit()
        access, new_refresh = self._issue_tokens(user)
        return user, access, new_refresh

    def logout(self, refresh_token: str | None) -> None:
        if not refresh_token:
            return
        try:
            payload = decode_token(refresh_token, "refresh")
        except ValueError:
            return
        row = self.db.scalar(select(RefreshToken).where(RefreshToken.jti == payload.get("jti")))
        if row and row.revoked_at is None:
            row.revoked_at = utcnow()
            self.db.add(row)
            self.db.commit()

    def _issue_tokens(self, user: User) -> Tuple[str, str]:
        access = create_access_token(user.id)
        refresh = create_refresh_token(user.id)
        payload = decode_token(refresh, "refresh")
        row = RefreshToken(
            user_id=user.id,
            jti=payload["jti"],
            token_hash=hash_token_for_storage(refresh),
            expires_at=datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_days),
        )
        self.db.add(row)
        self.db.commit()
        return access, refresh
