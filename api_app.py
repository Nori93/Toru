from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from brain_api import ask_toru_with_tools
from toru_tools import generate_image

app = FastAPI(title="Toru Brain API", version="1.0.0")


class AskRequest(BaseModel):
    question: str


class AskResponse(BaseModel):
    answer: str


@app.get("/", include_in_schema=False)
async def root() -> RedirectResponse:
    """Redirect the root path to the interactive Swagger UI docs."""

    return RedirectResponse(url="/docs")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post("/ask", response_model=AskResponse)
async def ask(request: AskRequest) -> AskResponse:
    """Ask Toru a question and get an answer."""

    answer = ask_toru_with_tools(request.question)
    return AskResponse(answer=answer)


class GenerateImageRequest(BaseModel):
    prompt: str


class GenerateImageResponse(BaseModel):
    image_id: int


@app.post("/generate-image", response_model=GenerateImageResponse)
async def generate_image_endpoint(request: GenerateImageRequest) -> GenerateImageResponse:
    """Generate a single image from a prompt and return its numeric ID.

    The image will be stored as assets/generated/img_<id>.png on the server.
    """

    try:
        image_id = generate_image(request.prompt)
    except RuntimeError as exc:
        # Image generation stack (diffusers/torch/etc.) not available in this deployment
        raise HTTPException(status_code=503, detail=str(exc))

    return GenerateImageResponse(image_id=image_id)
