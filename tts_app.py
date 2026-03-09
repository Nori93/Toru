import os
import json
import base64

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy import Column, DateTime, Integer, MetaData, String, Table, Text, create_engine, func

from voice import synthesize_to_wav_bytes


DB_URL = os.getenv("TORU_DB_URL")
engine = create_engine(DB_URL, future=True) if DB_URL else None
metadata = MetaData()

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
    Column("status", String, nullable=False, server_default="completed"),
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


def _log_tts(text: str, audio: bytes | None) -> None:
    if engine is None:
        return
    try:
        _init_db()
        audio_b64: str | None = None
        if audio:
            audio_b64 = base64.b64encode(audio).decode("ascii")

        payload = json.dumps({"text": text})
        result: dict[str, object] = {"text": text}
        if audio_b64 is not None:
            result["audio_b64"] = audio_b64

        with engine.begin() as conn:
            conn.execute(
                tasks_table.insert(),
                {
                    "task_type": "tts_generate",
                    "payload": payload,
                    "status": "completed",
                    "result": json.dumps(result),
                    "error": None,
                },
            )
            conn.execute(
                messages_table.insert(),
                {
                    "role": "assistant",
                    "content": f"Generated TTS audio for text: {text}",
                },
            )
    except Exception:
        # Logging failures should not break the API
        pass


app = FastAPI(title="Toru TTS API", version="1.0.0")


class TTSRequest(BaseModel):
    text: str


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post(
    "/tts",
    responses={
        200: {
            "content": {"audio/wav": {}},
            "description": "Synthesized speech as a WAV audio stream.",
        }
    },
)
async def tts_endpoint(request: TTSRequest):
    """Convert text to speech and return the audio WAV bytes.

    No audio is played on the server/host; the client receives WAV bytes
    and is responsible for playback.
    """

    try:
        audio_bytes = synthesize_to_wav_bytes(request.text)
    except RuntimeError as exc:
        # TTS stack (Piper/voice.py) not available in this deployment
        raise HTTPException(status_code=503, detail=str(exc))

    if not audio_bytes:
        raise HTTPException(status_code=400, detail="No audio generated from empty text.")

    _log_tts(request.text, audio_bytes)

    return StreamingResponse(iter([audio_bytes]), media_type="audio/wav")


@app.get(
    "/tts",
    responses={
        200: {
            "content": {"audio/wav": {}},
            "description": "Synthesized speech as a WAV audio stream.",
        }
    },
)
async def tts_get(text: str):
    """GET convenience endpoint: /tts?text=Hello -> WAV audio.

    Mirrors the POST /tts behavior but takes the text from a query
    parameter so it can be called directly from a browser.
    """

    try:
        audio_bytes = synthesize_to_wav_bytes(text)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))

    if not audio_bytes:
        raise HTTPException(status_code=400, detail="No audio generated from empty text.")

    _log_tts(text, audio_bytes)

    return StreamingResponse(iter([audio_bytes]), media_type="audio/wav")
