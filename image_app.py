import os
import json
import base64
import io

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Integer, MetaData, String, Table, Text, create_engine, func, select, update

from toru_tools import generate_image


DB_URL = os.getenv("TORU_DB_URL")
engine = create_engine(DB_URL, future=True) if DB_URL else None
metadata = MetaData()

_IMAGE_BUSY_MSG = "Image generation already in progress"

messages_table = Table(
    "messages",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("role", String, nullable=False),
    Column("content", Text, nullable=False),
    Column("created_at", DateTime, server_default=func.now()),
)


tasks_table = Table(
    "tasks",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("task_type", String, nullable=False),
    Column("payload", Text, nullable=False),  # JSON-encoded task payload
    Column("status", String, nullable=False, server_default="pending"),
    Column("result", Text, nullable=True),    # JSON-encoded result
    Column("error", Text, nullable=True),
    Column("created_at", DateTime, server_default=func.now()),
    Column("updated_at", DateTime, server_default=func.now(), onupdate=func.now()),
)


def _init_db() -> None:
    if engine is None:
        return
    try:
        metadata.create_all(engine)
    except Exception:
        pass

def _log_message(content: str) -> None:
    """Append a short assistant message so Toru knows about image usage."""

    if engine is None:
        return
    try:
        _init_db()
        with engine.begin() as conn:
            conn.execute(
                messages_table.insert(),
                {"role": "assistant", "content": content},
            )
    except Exception:
        # Logging failures should not break the API
        pass


def _build_image_task_result(prompt: str, image_id: int, seed: int | None, data: bytes | None) -> dict:
    """Construct the JSON result payload for an image task.

    Binary image data is stored as base64 inside the JSON so that
    no separate generated_images table is required.
    """

    result: dict[str, object] = {"image_id": image_id, "prompt": prompt}
    if seed is not None:
        result["seed"] = seed
    if data:
        result["image_b64"] = base64.b64encode(data).decode("ascii")
    return result


def _create_image_task(prompt: str) -> int:
    if engine is None:
        raise RuntimeError("Database engine is not configured.")

    _init_db()
    payload = json.dumps({"prompt": prompt})
    with engine.begin() as conn:
        # Check if another image generation task is already pending.
        existing = conn.execute(
            select(func.count())
            .select_from(tasks_table)
            .where(
                (tasks_table.c.task_type == "image_generate")
                & (tasks_table.c.status == "pending")
            )
        ).scalar_one()

        if existing and int(existing) > 0:
            # Signal to the caller that the API is busy.
            raise RuntimeError(_IMAGE_BUSY_MSG)

        result = conn.execute(
            tasks_table.insert()
            .values(task_type="image_generate", payload=payload, status="pending")
            .returning(tasks_table.c.id)
        )
        task_id = int(result.scalar_one())
    return task_id


def _update_task(task_id: int, *, status: str, result: dict | None = None, error: str | None = None) -> None:
    if engine is None:
        return

    _init_db()
    values: dict[str, object] = {"status": status}
    if result is not None:
        values["result"] = json.dumps(result)
    if error is not None:
        values["error"] = error

    with engine.begin() as conn:
        conn.execute(
            update(tasks_table)
            .where(tasks_table.c.id == task_id)
            .values(**values)
        )


def _run_image_task(task_id: int, prompt: str) -> None:
    """Background worker that generates an image and updates the task row."""

    try:
        meta = generate_image(prompt)

        if isinstance(meta, dict):
            image_id = int(meta.get("image_id"))
            seed = meta.get("seed")
        else:
            image_id = int(meta)
            seed = None

        image_path = os.path.join("assets", "generated", f"img_{image_id}.png")
        data: bytes | None
        try:
            with open(image_path, "rb") as f:
                data = f.read()
        except Exception:
            data = None

        result_payload = _build_image_task_result(prompt, image_id, seed, data)
        _update_task(task_id, status="completed", result=result_payload, error=None)
        _log_message(f"Generated image {image_id} for prompt: {prompt}")
    except Exception as exc:  # pragma: no cover - background error path
        _update_task(task_id, status="failed", result=None, error=str(exc))


app = FastAPI(title="Toru Image API", version="1.0.0")


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


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post("/generate-image", response_model=GenerateImageResponse)
async def generate_image_endpoint(request: GenerateImageRequest) -> GenerateImageResponse:
    """Generate a single image from a prompt and return its numeric ID.

    The image will be stored as assets/generated/img_<id>.png on the server.
    """

    # Optionally create a task row so this synchronous call is also
    # represented in the generic tasks table.
    task_id: int | None = None
    try:
        if engine is not None:
            _init_db()
            task_id = _create_image_task(request.prompt)
    except RuntimeError as exc:
        # If another image is already being generated, surface a clear
        # "API busy" error to the client.
        if str(exc) == _IMAGE_BUSY_MSG:
            raise HTTPException(status_code=503, detail="Image service busy: another image is currently being generated.")
        task_id = None
    except Exception:
        # If task creation fails for any other reason, continue; the main
        # API response should not break just because logging failed.
        task_id = None

    try:
        meta = generate_image(request.prompt)
    except RuntimeError as exc:
        # Image generation stack (diffusers/torch/etc.) not available in this deployment
        if task_id is not None:
            _update_task(task_id, status="failed", result=None, error=str(exc))
        raise HTTPException(status_code=503, detail=str(exc))

    # Support both legacy int return and new metadata dict
    if isinstance(meta, dict):
        image_id = int(meta.get("image_id"))
        seed = meta.get("seed")
    else:
        image_id = int(meta)
        seed = None

    # Read the generated PNG bytes from disk for storage
    image_path = os.path.join("assets", "generated", f"img_{image_id}.png")
    data: bytes | None
    try:
        with open(image_path, "rb") as f:
            data = f.read()
    except Exception:
        data = None

    # Build a task-style result payload and, if we have a task id,
    # mark it as completed so this call is represented in tasks.
    result_payload = _build_image_task_result(request.prompt, image_id, seed, data)
    if task_id is not None:
        _update_task(task_id, status="completed", result=result_payload, error=None)

    # Also append a short assistant message so Toru's history
    # reflects that an image was generated.
    _log_message(f"Generated image {image_id} for prompt: {request.prompt}")

    return GenerateImageResponse(image_id=image_id)


@app.post("/generate-image-async", response_model=GenerateImageTaskResponse)
async def generate_image_async_endpoint(
    request: GenerateImageRequest,
    background_tasks: BackgroundTasks,
) -> GenerateImageTaskResponse:
    """Create an image-generation task and return immediately with a task id."""

    try:
        task_id = _create_image_task(request.prompt)
    except RuntimeError as exc:
        if str(exc) == _IMAGE_BUSY_MSG:
            # Do not enqueue another task if one is already running.
            raise HTTPException(status_code=503, detail="Image service busy: another image is currently being generated.")
        raise

    background_tasks.add_task(_run_image_task, task_id, request.prompt)
    return GenerateImageTaskResponse(task_id=task_id)


@app.get("/task/{task_id}", response_model=ImageTaskStatus)
async def get_image_task_status(task_id: int) -> ImageTaskStatus:
    """Return the status of a background task (image generation or future types)."""

    if engine is None:
        raise HTTPException(status_code=500, detail="Database engine is not configured.")

    _init_db()
    with engine.connect() as conn:
        row = conn.execute(
            select(
                tasks_table.c.id,
                tasks_table.c.status,
                tasks_table.c.result,
                tasks_table.c.error,
            ).where(tasks_table.c.id == task_id)
        ).first()

    if row is None:
        raise HTTPException(status_code=404, detail="Task not found.")

    result_dict: dict | None = None
    if row.result is not None:
        try:
            result_dict = json.loads(row.result)
        except Exception:
            result_dict = None

    return ImageTaskStatus(
        task_id=row.id,
        status=row.status,
        result=result_dict,
        error=row.error,
    )


@app.get(
    "/image/{image_id}",
    responses={
        200: {
            "content": {"image/png": {}},
            "description": "Return a previously generated image as PNG.",
        }
    },
)
async def get_image(image_id: int):
    """Return the generated PNG for the given image_id.

    Primary source is the tasks table, where image tasks store
    base64-encoded image bytes in the JSON result. If no matching
    task is found (or it lacks image data), fall back to the legacy
    filesystem location assets/generated/img_<id>.png.
    """

    # First, try to load the image bytes from the tasks table
    if engine is not None:
        _init_db()
        with engine.connect() as conn:
            rows = conn.execute(
                select(tasks_table.c.result, tasks_table.c.status, tasks_table.c.task_type)
                .where(tasks_table.c.task_type == "image_generate")
            ).all()

        for row in rows:
            if not row.result:
                continue
            try:
                payload = json.loads(row.result)
            except Exception:
                continue

            # Match by image_id in the JSON result
            try:
                stored_id = int(payload.get("image_id"))
            except Exception:
                continue
            if stored_id != image_id:
                continue

            image_b64 = payload.get("image_b64")
            if not image_b64:
                continue

            try:
                image_bytes = base64.b64decode(image_b64)
            except Exception:
                continue

            return StreamingResponse(io.BytesIO(image_bytes), media_type="image/png")

    # Fallback: try to read from the filesystem (legacy behavior)
    image_path = os.path.join("assets", "generated", f"img_{image_id}.png")
    if not os.path.exists(image_path):
        raise HTTPException(status_code=404, detail="Image not found.")

    return FileResponse(image_path, media_type="image/png")
