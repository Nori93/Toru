from fastapi import FastAPI
from pydantic import BaseModel

from brain_api import ask_toru_with_tools


app = FastAPI(title="Toru Ask API", version="1.0.0")


class AskRequest(BaseModel):
    question: str


class AskResponse(BaseModel):
    answer: str


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}


@app.post("/ask", response_model=AskResponse)
async def ask(request: AskRequest) -> AskResponse:
    """Ask Toru a question and get an answer."""

    answer = ask_toru_with_tools(request.question)
    return AskResponse(answer=answer)
