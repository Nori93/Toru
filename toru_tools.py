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


def generate_sprites(description: str) -> str:
    """Generate/update Toru sprites based on a text description.

    Returns a short status string for the LLM to read.
    """

    generate_toru_sprites(description)
    return "Sprites generated based on description."


def ping(message: str = "pong") -> str:
    """Simple test tool to verify tool-calling works."""

    return f"Ping result: {message}"


def generate_image(prompt: str) -> int:
    """Tool: generate a single image from a prompt and return its ID.

    This is designed to be called by Toru via the tool-calling system or
    directly from the API. The returned integer is the image ID used in the
    filename assets/generated/img_<id>.png.
    """

    return generate_image_from_prompt(prompt)


TOOLS: Dict[str, Callable[..., Any]] = {
    "generate_sprites": generate_sprites,
    "ping": ping,
    "generate_image": generate_image,
}
