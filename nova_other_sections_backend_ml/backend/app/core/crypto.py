import base64
import json
import os
from typing import Iterable, List

from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from app.core.config import get_settings

settings = get_settings()


def _get_key() -> bytes:
    key = base64.b64decode(settings.aes_gcm_key_b64)
    if len(key) != 32:
        raise RuntimeError("NOVA_AES_GCM_KEY_B64 must decode to exactly 32 bytes for AES-256-GCM")
    return key


def encrypt_bytes(plaintext: bytes, associated_data: bytes | None = None) -> str:
    """Encrypt bytes with AES-256-GCM and return base64(nonce+ciphertext)."""

    nonce = os.urandom(12)
    ciphertext = AESGCM(_get_key()).encrypt(nonce, plaintext, associated_data)
    return base64.b64encode(nonce + ciphertext).decode("ascii")


def decrypt_bytes(token_b64: str, associated_data: bytes | None = None) -> bytes:
    raw = base64.b64decode(token_b64)
    nonce, ciphertext = raw[:12], raw[12:]
    return AESGCM(_get_key()).decrypt(nonce, ciphertext, associated_data)


def encrypt_embedding(embedding: Iterable[float], user_id: str) -> str:
    payload = json.dumps([round(float(x), 8) for x in embedding], separators=(",", ":")).encode()
    return encrypt_bytes(payload, associated_data=user_id.encode())


def decrypt_embedding(token_b64: str, user_id: str) -> List[float]:
    payload = decrypt_bytes(token_b64, associated_data=user_id.encode())
    values = json.loads(payload.decode())
    return [float(x) for x in values]


def encrypt_text(text: str, user_id: str) -> str:
    return encrypt_bytes(text.encode(), associated_data=user_id.encode())


def decrypt_text(token_b64: str, user_id: str) -> str:
    return decrypt_bytes(token_b64, associated_data=user_id.encode()).decode()
