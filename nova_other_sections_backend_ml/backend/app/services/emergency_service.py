from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.crypto import decrypt_text, encrypt_text
from app.db.models import EmergencyContact


class EmergencyService:
    def __init__(self, db: Session):
        self.db = db

    def set_contact(self, user_id: str, name: str, phone_number: str) -> EmergencyContact:
        encrypted = encrypt_text(phone_number, user_id=user_id)
        row = self.db.scalar(select(EmergencyContact).where(EmergencyContact.user_id == user_id))
        if row is None:
            row = EmergencyContact(user_id=user_id, name=name, phone_number_ciphertext=encrypted)
        else:
            row.name = name
            row.phone_number_ciphertext = encrypted
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        return row

    def get_contact(self, user_id: str) -> tuple[EmergencyContact, str] | None:
        row = self.db.scalar(select(EmergencyContact).where(EmergencyContact.user_id == user_id))
        if row is None:
            return None
        return row, decrypt_text(row.phone_number_ciphertext, user_id=user_id)

    def build_sms(self, user_id: str, latitude: float, longitude: float, accuracy_meters: float | None) -> tuple[str | None, str]:
        contact = self.get_contact(user_id)
        phone = contact[1] if contact else None
        maps_link = f"https://maps.google.com/?q={latitude:.6f},{longitude:.6f}"
        accuracy = f" Accuracy about {accuracy_meters:.0f} meters." if accuracy_meters else ""
        body = f"NOVA emergency alert: I need help. My location is {maps_link}.{accuracy}"
        return phone, body
