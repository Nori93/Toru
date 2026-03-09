import os

import httpx
from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse, StreamingResponse
from pydantic import BaseModel


ASK_SERVICE_URL = os.getenv("ASK_SERVICE_URL", "http://ask-service:8000")
IMAGE_SERVICE_URL = os.getenv("IMAGE_SERVICE_URL", "http://image-service:8000")
TTS_SERVICE_URL = os.getenv("TTS_SERVICE_URL", "http://tts-service:8000")


app = FastAPI(title="Toru Gateway API", version="1.0.0")


class AskRequest(BaseModel):
    question: str


class AskResponse(BaseModel):
    answer: str


class GenerateImageRequest(BaseModel):
    prompt: str


class GenerateImageResponse(BaseModel):
    image_id: int


class GenerateImageTaskResponse(BaseModel):
    task_id: int


class ImageTaskStatus(BaseModel):
    task_id: int
    status: str
    result: dict | None = None
    error: str | None = None


class TTSRequest(BaseModel):
    text: str


@app.get("/", include_in_schema=False)
async def root() -> RedirectResponse:
    """Redirect the root path to the interactive Swagger UI docs."""

    return RedirectResponse(url="/docs")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post("/ask", response_model=AskResponse)
async def ask_proxy(request: AskRequest) -> AskResponse:
    """Proxy ask requests to the dedicated Ask service."""

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(f"{ASK_SERVICE_URL}/ask", json=request.dict())
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"Ask service unreachable: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()
    return AskResponse(**data)


@app.post("/generate-image", response_model=GenerateImageResponse)
async def generate_image_proxy(request: GenerateImageRequest) -> GenerateImageResponse:
    """Proxy image generation requests to the Image service."""

    # Image generation can take a long time (minutes on CPU).
    # Disable client-side timeout so we wait for completion.
    async with httpx.AsyncClient(timeout=None) as client:
        try:
            resp = await client.post(f"{IMAGE_SERVICE_URL}/generate-image", json=request.dict())
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"Image service unreachable: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()
    return GenerateImageResponse(**data)


@app.post("/generate-image-async", response_model=GenerateImageTaskResponse)
async def generate_image_async_proxy(request: GenerateImageRequest) -> GenerateImageTaskResponse:
    """Proxy async image generation: returns a task id immediately."""

    # Async path should be fast, but we still disable the timeout to
    # avoid spurious client-side timeouts during periods of load.
    async with httpx.AsyncClient(timeout=None) as client:
        try:
            resp = await client.post(f"{IMAGE_SERVICE_URL}/generate-image-async", json=request.dict())
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"Image service unreachable: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()
    return GenerateImageTaskResponse(**data)


@app.get("/task/{task_id}", response_model=ImageTaskStatus)
async def get_image_task_status_proxy(task_id: int) -> ImageTaskStatus:
    """Proxy task status lookup for background tasks (image generation or future types)."""

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(f"{IMAGE_SERVICE_URL}/task/{task_id}")
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"Image service unreachable: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()
    return ImageTaskStatus(**data)


@app.get(
    "/image/{image_id}",
    responses={
        200: {
            "content": {"image/png": {}},
            "description": "Return a previously generated image as PNG.",
        }
    },
)
async def get_image_proxy(image_id: int):
    """Proxy image download by ID to the Image service.

    Allows clients to fetch assets/generated/img_<id>.png via the gateway
    using the ID returned from /generate-image.
    """

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.get(f"{IMAGE_SERVICE_URL}/image/{image_id}")
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"Image service unreachable: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    content_type = resp.headers.get("content-type", "image/png")
    return StreamingResponse(iter([resp.content]), media_type=content_type)


@app.post(
    "/tts",
    responses={
        200: {
            "content": {"audio/wav": {}},
            "description": "Synthesized speech as a WAV audio stream.",
        }
    },
)
async def tts_proxy(request: TTSRequest):
    """Proxy TTS requests to the TTS service and stream back audio.

    The gateway does not perform synthesis itself; it simply forwards
    requests and returns the resulting audio stream.
    """

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(f"{TTS_SERVICE_URL}/tts", json=request.dict())
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"TTS service unreachable: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    content_type = resp.headers.get("content-type", "audio/wav")
    return StreamingResponse(iter([resp.content]), media_type=content_type)


@app.get(
    "/tts",
    responses={
        200: {
            "content": {"audio/wav": {}},
            "description": "Synthesized speech as a WAV audio stream.",
        }
    },
)
async def tts_proxy_get(text: str):
    """GET convenience endpoint: /tts?text=Hello -> WAV audio.

    Forwards the text query parameter to the TTS service's /tts endpoint
    and streams back the synthesized audio, just like the POST variant.
    """

    async with httpx.AsyncClient() as client:
        try:
            resp = await client.post(f"{TTS_SERVICE_URL}/tts", json={"text": text})
        except httpx.RequestError as exc:
            raise HTTPException(status_code=502, detail=f"TTS service unreachable: {exc}")

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    content_type = resp.headers.get("content-type", "audio/wav")
    return StreamingResponse(iter([resp.content]), media_type=content_type)
