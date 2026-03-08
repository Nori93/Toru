import os

from brain import ask_toru
from voice import speak
from image_generator import generate_toru_sprites
from avatar import ToruAvatar

import threading
import time
import queue

print("🐉 Toru Modular System Online!")
if not os.path.exists("assets/toru_idle.png"):
    description = ask_toru("Describe your appearance in prompt for generating your sprites.keep it short, and i like gothic sexy  with big ass and tits ")
    print("Toru Appearance Description:", description)
    generate_toru_sprites(description)

avatar = ToruAvatar()
avatar.start()


def speak_with_avatar(text: str) -> None:
    # Stream Piper audio and feed the same audio chunks into the avatar
    # so Toru's mouth moves in sync with the spoken voice.
    speak(text, avatar_audio_consumer=avatar.push_audio_chunk)


user_input_queue: queue.Queue[str] = queue.Queue()


def input_loop():
    while True:
        try:
            user_input = input("Ty: ")
        except EOFError:
            # Stop input loop if stdin closes
            break

        user_input_queue.put(user_input)
        if user_input.lower() in ["exit", "quit"]:
            break


threading.Thread(target=input_loop, daemon=True).start()

running = True
while running:
    try:
        # Process user input without blocking the avatar animation
        try:
            user_input = user_input_queue.get_nowait()
        except queue.Empty:
            user_input = None

        if user_input is not None:
            if user_input.lower() in ["exit", "quit"]:
                print("Toru: Sayonara! 👋")
                running = False
            else:
                answer = ask_toru(user_input)
                print("Toru:", answer)
                threading.Thread(
                    target=speak_with_avatar,
                    args=(answer,),
                    daemon=True,
                ).start()

        # Small sleep to avoid maxing out CPU while keeping the loop responsive
        time.sleep(0.01)

    except Exception as e:
        print("Error:", e)
        running = False