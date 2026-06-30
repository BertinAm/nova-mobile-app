"""Create or promote an admin user.

Usage:
    python scripts/create_admin.py admin@example.com StrongPassword123!
"""
import sys
from sqlalchemy import select

from app.core.security import hash_password
from app.db.models import User
from app.db.session import SessionLocal, init_db


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python scripts/create_admin.py <email> <password>")
        return 2
    email, password = sys.argv[1].lower(), sys.argv[2]
    init_db()
    db = SessionLocal()
    try:
        user = db.scalar(select(User).where(User.email == email))
        if user is None:
            user = User(email=email, password_hash=hash_password(password), preferred_language="en-CM", is_admin=True)
        else:
            user.is_admin = True
            user.password_hash = hash_password(password)
        db.add(user)
        db.commit()
        print(f"Admin ready: {email}")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
