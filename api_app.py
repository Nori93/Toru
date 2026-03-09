"""Legacy monolithic API app.

This module is kept for backwards compatibility but is no longer used
in the docker-compose deployment, which instead runs the dedicated
ask_app, image_app, tts_app and the gateway_app.
"""

from fastapi import FastAPI

app = FastAPI(title="Toru Legacy API", version="1.0.0")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "mode": "legacy"}
