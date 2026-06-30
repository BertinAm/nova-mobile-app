import io
import time
from dataclasses import dataclass

from PIL import Image, ImageStat

from app.core.config import get_settings

settings = get_settings()


@dataclass(frozen=True)
class SceneDescription:
    description: str
    provider: str
    processing_ms: int


class SceneService:
    """Scene description service.

    The simulated provider keeps the API functional for demos. Replace the body
    of describe_scene() with BLIP-2, LLaVA, a hosted VLM, or another model while
    keeping the same return type.
    """

    def describe_scene(self, image_bytes: bytes) -> SceneDescription:
        start = time.perf_counter()
        provider = settings.scene_provider
        if provider != "simulated":
            # Integration point: call your VLM here and keep descriptions concise
            # (maximum 80 words) as required by the SRS.
            description = self._simulate_description(image_bytes)
            provider = f"{provider}-adapter-not-configured"
        else:
            description = self._simulate_description(image_bytes)
        return SceneDescription(
            description=description,
            provider=provider,
            processing_ms=int((time.perf_counter() - start) * 1000),
        )

    def _simulate_description(self, image_bytes: bytes) -> str:
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        stat = ImageStat.Stat(image)
        brightness = sum(stat.mean) / 3
        width, height = image.size
        orientation = "landscape" if width > height else "portrait"
        lighting = "bright" if brightness > 170 else "dim" if brightness < 80 else "moderately lit"
        return (
            f"A {lighting} {orientation} scene was captured. I can describe broad lighting and framing in "
            "simulation mode, but a real vision-language model should replace this service for detailed scene content."
        )
