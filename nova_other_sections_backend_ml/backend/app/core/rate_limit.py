import time
from collections import defaultdict, deque
from typing import Deque, Dict

from fastapi import HTTPException, Request, status

from app.core.config import get_settings

settings = get_settings()
_buckets: Dict[str, Deque[float]] = defaultdict(deque)


async def rate_limit(request: Request) -> None:
    """Simple in-memory per-IP rate limit.

    Production deployments behind multiple workers should replace this with
    Redis-backed limiting, but this meets the API contract and works for a VPS demo.
    """

    key = request.headers.get("x-forwarded-for", request.client.host if request.client else "unknown")
    now = time.monotonic()
    bucket = _buckets[key]
    while bucket and now - bucket[0] > 60:
        bucket.popleft()
    if len(bucket) >= settings.rate_limit_per_minute:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Rate limit exceeded")
    bucket.append(now)
