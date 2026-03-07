import subprocess
import sounddevice as sd
import numpy as np
import re
import threading
import queue
from typing import Callable, Optional

PIPER_PATH = r"C:\piper\piper.exe"
MODEL_PATH = r"C:\piper\models\en_US-libritts-high.onnx"

samplerate = 24000  # libritts-high is 24000 Hz
channels = 1

audio_queue = queue.Queue()


def _audio_callback(outdata, frames, time_info, status):
    try:
        data = audio_queue.get_nowait()
    except queue.Empty:
        outdata.fill(0)
        return

    if len(data) >= frames:
        chunk = data[:frames]
        remainder = data[frames:]
        if len(remainder) > 0:
            audio_queue.put(remainder)
    else:
        chunk = np.zeros(frames, dtype=np.int16)
        chunk[: len(data)] = data

    outdata[:] = chunk.reshape(-1, 1)


def _clean_text_for_piper(text: str) -> str:
    # Remove newlines, collapse spaces
    text = text.replace("\n", " ")
    text = re.sub(r"\s+", " ", text)

    # Drop emojis / non-ASCII chars that can confuse Piper
    text = text.encode("ascii", errors="ignore").decode("ascii")

    return text.strip()


def speak(text: str, avatar_audio_consumer: Optional[Callable[[np.ndarray], None]] = None) -> None:
    """Stream text to Piper and play audio without cutting mid-sentence.

    If ``avatar_audio_consumer`` is provided, each decoded audio chunk is also
    forwarded to it (for example, ``ToruAvatar.push_audio_chunk``) so the
    avatar can animate in sync with the spoken audio.
    """

    # Clear any leftover audio from previous calls
    while not audio_queue.empty():
        try:
            audio_queue.get_nowait()
        except queue.Empty:
            break

    cleaned = _clean_text_for_piper(text)
    if not cleaned:
        return

    process = subprocess.Popen(
        [PIPER_PATH, "-m", MODEL_PATH, "--output-raw"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        process.stdin.write((cleaned + "\n").encode("utf-8"))
        process.stdin.close()
    except Exception:
        process.kill()
        return

    def feed_audio():
        while True:
            data = process.stdout.read(4096)
            if not data:
                break
            audio = np.frombuffer(data, dtype=np.int16)
            if audio.size == 0:
                continue
            audio_queue.put(audio)

            # Also send this chunk to the avatar, if requested.
            if avatar_audio_consumer is not None:
                # Use a copy so the avatar can safely process the data.
                avatar_audio_consumer(audio.copy())

    feed_thread = threading.Thread(target=feed_audio, daemon=True)
    feed_thread.start()

    with sd.OutputStream(
        samplerate=samplerate,
        channels=channels,
        dtype="int16",
        callback=_audio_callback,
        blocksize=2048,
    ):
        # Wait for Piper to finish generating audio
        process.wait()
        # Ensure we've read all stdout into the queue
        feed_thread.join()
        # Let the output stream drain the remaining audio
        while not audio_queue.empty():
            sd.sleep(50)

    # If Piper aborted early, print its error so you can see why.
    stderr_output = process.stderr.read() if process.stderr else b""
    if stderr_output:
        print("[Piper stderr]", stderr_output.decode(errors="ignore"))