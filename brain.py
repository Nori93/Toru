import ollama


def ask_toru(user_input: str) -> str:
    """Call Ollama and return Toru's answer as plain text."""

    response = ollama.chat(
        model="reefer/erphermesl3",
        messages=[
            {"role": "system", "content": "You are Toru, energetic anime assistant."},
            {"role": "user", "content": user_input},
        ],
    )

    return response["message"]["content"]


print("🐉 Toru Brain Online! 🧠")