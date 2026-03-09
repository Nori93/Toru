from typing import Callable, Any, Dict

try:
    # Heavy diffusion / GPU stack; may be unavailable inside lightweight Docker images
    from image_generator import generate_toru_sprites, generate_image_from_prompt
    HAS_IMAGE_GENERATOR = True
except Exception:
    HAS_IMAGE_GENERATOR = False

    def generate_toru_sprites(*args, **kwargs) -> None:  # type: ignore[override]
        """Fallback when image generation stack isn't installed."""

        raise RuntimeError(
            "Image generation is not available in this environment (missing diffusers/torch)."
        )

    def generate_image_from_prompt(*args, **kwargs) -> int:  # type: ignore[override]
        """Fallback when image generation stack isn't installed."""

        raise RuntimeError(
            "Image generation is not available in this environment (missing diffusers/torch)."
        )

try:
    # Local text-to-speech using Piper; may not be available in Docker
    from voice import speak as _speak
    HAS_TTS = True
except Exception:
    HAS_TTS = False

    def _speak(*args, **kwargs) -> None:  # type: ignore[override]
        raise RuntimeError(
            "Text-to-speech is not available in this environment (missing Piper/voice stack)."
        )


def generate_sprites(description: str) -> str:
    """Generate/update Toru sprites based on a text description.

    Returns a short status string for the LLM to read.
    """

    generate_toru_sprites(description)
    return "Sprites generated based on description."


def ping(message: str = "pong") -> str:
    """Simple test tool to verify tool-calling works."""

    return f"Ping result: {message}"


def generate_image(prompt: str) -> dict:
    """Tool: generate a single image from a prompt.

    Returns a dict with at least::

        {"image_id": <int>, "seed": <int>}

    The image is saved as assets/generated/img_<id>.png, and the metadata
    can be logged to the database by the image-service.
    """

    return generate_image_from_prompt(prompt)


def text_to_speech(text: str) -> str:
    """Tool: convert text to speech using the local Piper TTS.

    This plays audio on the host where the TTS stack is installed.
    """

    _speak(text)
    return "Text-to-speech playback started."


TOOLS: Dict[str, Callable[..., Any]] = {
    "generate_sprites": generate_sprites,
    "ping": ping,
    "generate_image": generate_image,
    "text_to_speech": text_to_speech,
}
