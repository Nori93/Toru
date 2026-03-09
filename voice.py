import os
import subprocess
import re
import threading
import queue
import io
import wave
from typing import Callable, Optional, Any

try:
    import sounddevice as sd  # type: ignore[import]
except Exception:  # pragma: no cover - optional in some environments
    sd = None  # type: ignore[assignment]

try:
    import numpy as np  # type: ignore[import]
except Exception:  # pragma: no cover - optional in some environments
    np = None  # type: ignore[assignment]

PIPER_PATH = os.getenv("PIPER_PATH", r"C:\piper\piper.exe")
MODEL_PATH = os.getenv("PIPER_MODEL", r"C:\piper\models\en_US-libritts-high.onnx")

samplerate = 24000  # libritts-high is 24000 Hz
channels = 1

audio_queue = queue.Queue()


def _audio_callback(outdata, frames, time_info, status):
    if np is None:
        outdata.fill(0)
        return

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


def synthesize_to_wav_bytes(text: str) -> bytes:
    """Synthesize ``text`` with Piper and return WAV bytes (no playback).

    The output is mono 16-bit PCM at ``samplerate`` Hz wrapped in a WAV
    container so it can be sent over HTTP and played in browsers.
    """

    cleaned = _clean_text_for_piper(text)
    if not cleaned:
        return b""

    try:
        process = subprocess.Popen(
            [PIPER_PATH, "-m", MODEL_PATH, "--output-raw"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as e:
        raise RuntimeError(
            f"Piper binary not found at '{PIPER_PATH}'. "
            "Set PIPER_PATH/PIPER_MODEL env vars or install Piper in this environment."
        ) from e

    try:
        assert process.stdin is not None
        process.stdin.write((cleaned + "\n").encode("utf-8"))
        process.stdin.close()
    except Exception:
        process.kill()
        raise

    # Read all raw 16-bit PCM samples from Piper
    raw_pcm = process.stdout.read() if process.stdout is not None else b""
    process.wait()

    stderr_output = process.stderr.read() if process.stderr else b""
    if process.returncode != 0:
        raise RuntimeError(
            f"Piper TTS failed with code {process.returncode}: "
            f"{stderr_output.decode(errors='ignore')}"
        )

    # Wrap raw PCM into a WAV container in-memory
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(samplerate)
        wf.writeframes(raw_pcm)

    return buf.getvalue()


def speak(text: str, avatar_audio_consumer: Optional[Callable[[Any], None]] = None) -> None:
    """Stream text to Piper and play audio without cutting mid-sentence.

    If ``avatar_audio_consumer`` is provided, each decoded audio chunk is also
    forwarded to it (for example, ``ToruAvatar.push_audio_chunk``) so the
    avatar can animate in sync with the spoken audio.
    """

    if sd is None or np is None:
        raise RuntimeError(
            "Text-to-speech playback is not available (missing sounddevice/numpy)."
        )

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