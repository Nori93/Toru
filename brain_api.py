import json
import os
import ollama
from sqlalchemy import (
    Column,
    DateTime,
    Integer,
    MetaData,
    String,
    Table,
    Text,
    create_engine,
    delete,
    func,
    select,
)

from toru_tools import TOOLS

# Reuse the same DB schema/name by default; can be overridden via env in Docker
MEMORY_FILE = os.getenv("TORU_MEMORY_JSON", "toru_memory.json")  # legacy JSON (optional)
DB_FILE = os.getenv("TORU_DB_FILE", "toru_memory.db")

# Prefer an explicit DB URL when provided; otherwise fall back to local SQLite
DB_URL = os.getenv("TORU_DB_URL") or f"sqlite:///{DB_FILE}"

engine = create_engine(DB_URL, future=True)
metadata = MetaData()

messages_table = Table(
    "messages",
    metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("role", String, nullable=False),
    Column("content", Text, nullable=False),
    Column("created_at", DateTime, server_default=func.now()),
)


conversation_history: list[dict[str, str]] = []


SYSTEM_PROMPT_WITH_TOOLS = (
    "You are Toru, energetic anime assistant.\n"
    "You can call tools by replying with JSON ONLY in this format:\n"
    '{"tool": "tool_name", "args": {"arg1": "value"}}\n'
    "Use tools only when they are genuinely helpful."
)


def _init_db() -> None:
    """Ensure the DB schema for conversation history exists."""

    try:
        metadata.create_all(engine)
    except Exception:
        # Schema creation errors should not crash the whole app.
        pass


def _load_memory_from_json_legacy() -> list[dict[str, str]]:
    """Load history from the old JSON file (used once for migration)."""

    if not os.path.exists(MEMORY_FILE):
        return []

    try:
        with open(MEMORY_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)

        if isinstance(data, list):
            cleaned: list[dict[str, str]] = []
            for item in data:
                if (
                    isinstance(item, dict)
                    and item.get("role") in {"user", "assistant"}
                    and isinstance(item.get("content"), str)
                ):
                    cleaned.append(
                        {
                            "role": item["role"],
                            "content": item["content"],
                        }
                    )
            return cleaned
    except Exception:
        pass

    return []


def _load_memory() -> None:
    """Load persistent conversation history from the configured database.

    If the DB is empty, attempt a one-time migration from the legacy JSON
    file, then persist that into the DB.
    """

    global conversation_history

    try:
        _init_db()

        with engine.connect() as conn:
            rows = conn.execute(
                select(messages_table.c.role, messages_table.c.content).order_by(
                    messages_table.c.id
                )
            ).all()

        if rows:
            conversation_history = [
                {"role": role, "content": content}
                for (role, content) in rows
                if role in {"user", "assistant"} and isinstance(content, str)
            ]
        else:
            # DB empty – try migrating from legacy JSON, if present
            legacy = _load_memory_from_json_legacy()
            conversation_history = legacy

            if legacy:
                # Persist migrated data into the DB
                with engine.begin() as conn:
                    conn.execute(
                        messages_table.insert(),
                        [
                            {"role": m["role"], "content": m["content"]}
                            for m in legacy
                        ],
                    )
    except Exception:
        # If anything goes wrong, start with a fresh in-memory history
        conversation_history = []


def _save_memory() -> None:
    """Persist the full conversation history to the configured database."""

    try:
        _init_db()

        with engine.begin() as conn:
            # Simple approach: replace all rows with the current in-memory history
            conn.execute(delete(messages_table))
            if conversation_history:
                conn.execute(
                    messages_table.insert(),
                    [
                        {
                            "role": m.get("role"),
                            "content": m.get("content"),
                        }
                        for m in conversation_history
                        if m.get("role") in {"user", "assistant"}
                        and isinstance(m.get("content"), str)
                    ],
                )
    except Exception:
        # Failing to save shouldn't crash the API; ignore silently.
        pass


def _chat_once(system_prompt: str) -> str:
    """Send one chat turn to Ollama and append the assistant reply to history."""

    global conversation_history

    messages = [
        {"role": "system", "content": system_prompt},
        *conversation_history,
    ]

    response = ollama.chat(
        model="reefer/erphermesl3",
        messages=messages,
    )

    content = response["message"]["content"].strip()
    conversation_history.append({"role": "assistant", "content": content})
    return content


def ask_toru(user_input: str) -> str:
    """Simpler helper that *does not* use tools (backwards-compatible)."""

    global conversation_history

    conversation_history.append({"role": "user", "content": user_input})

    answer = _chat_once("You are Toru, energetic anime assistant.")
    _save_memory()
    return answer


def ask_toru_with_tools(user_input: str, max_tool_calls: int = 4) -> str:
    """Ask Toru a question, allowing her to call registered Python tools.

    The model may respond with a JSON tool call, which we execute and feed
    back into the conversation, before asking again for a final answer.
    """

    global conversation_history

    conversation_history.append({"role": "user", "content": user_input})

    tool_calls = 0

    while True:
        content = _chat_once(SYSTEM_PROMPT_WITH_TOOLS)

        # Try to interpret the reply as a tool call JSON
        try:
            obj = json.loads(content)
            if not isinstance(obj, dict):
                raise ValueError("Tool JSON must be an object")
            tool_name = obj.get("tool")
            args = obj.get("args", {}) or {}
        except Exception:
            # Not a valid tool call → treat as final answer
            answer = content
            _save_memory()
            return answer

        if not tool_name:
            # No tool field → treat as final answer
            answer = content
            _save_memory()
            return answer

        if tool_name not in TOOLS:
            # Unknown tool: let Toru know and continue
            conversation_history.append(
                {
                    "role": "assistant",
                    "content": f"Tool '{tool_name}' is not available.",
                }
            )
            tool_calls += 1
        else:
            fn = TOOLS[tool_name]
            try:
                if not isinstance(args, dict):
                    raise ValueError("'args' must be a JSON object")
                result = fn(**args)
            except Exception as e:
                result = f"Tool '{tool_name}' failed: {e!r}"

            # Feed tool result back into the conversation
            conversation_history.append(
                {
                    "role": "assistant",
                    "content": f"[tool:{tool_name} result] {result}",
                }
            )
            tool_calls += 1

        if tool_calls >= max_tool_calls:
            # Avoid infinite tool-calling loops; ask once more for a final answer
            final = _chat_once(SYSTEM_PROMPT_WITH_TOOLS)
            _save_memory()
            return final


# Initialize memory when the module is imported (useful for web apps)
_load_memory()
