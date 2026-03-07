import pygame
import numpy as np
import threading
import queue
import time


class ToruAvatar:

    # Use a smaller window than the original sprite size
    # to reduce GPU/CPU load and avoid exceeding screen height.
    WIDTH = 416
    HEIGHT = 608

    def __init__(self, width=WIDTH, height=HEIGHT):

        # Store configuration; actual pygame setup happens in the avatar thread
        self.width = width
        self.height = height

        self.screen = None
        self.idle_img = None
        self.A_img = None
        self.E_img = None
        self.O_img = None
        self.U_img = None

        # Extra sprites for idle blink animation
        self.idle_blink_half_img = None
        self.idle_blink_closed_img = None

        # Idle animation state
        self._idle_frames = []
        self._idle_frame_index = 0
        self._idle_last_switch = time.time()
        self._idle_frame_duration = 0.1  # seconds per idle frame

        self.audio_queue = queue.Queue()
        self.running = False
        self._thread = None

    def start(self):
        if self.running:
            return
        self.running = True
        # Run all pygame operations in a dedicated thread to avoid
        # blocking or conflicting with the main thread.
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self.running = False

    def _run(self):

        pygame.init()
        # Windowed, resizable surface with double buffering for smoother updates
        self.screen = pygame.display.set_mode(
            (self.width, self.height), pygame.RESIZABLE | pygame.DOUBLEBUF
        )
        pygame.display.set_caption("Toru AI")

        # Load and pre-convert sprites to display format (faster blitting)
        self.idle_img = self._load_sprite("assets/toru_idle.png", self.width, self.height)
        self.A_img = self._load_sprite("assets/toru_talk_A.png", self.width, self.height)
        self.E_img = self._load_sprite("assets/toru_talk_E.png", self.width, self.height)
        self.O_img = self._load_sprite("assets/toru_talk_O.png", self.width, self.height)
        self.U_img = self._load_sprite("assets/toru_talk_U.png", self.width, self.height)

        # Optional blink sprites for idle animation; fall back to idle if missing
        try:
            self.idle_blink_half_img = self._load_sprite(
                "assets/toru_blink_half.png", self.width, self.height
            )
        except Exception:
            self.idle_blink_half_img = self.idle_img

        try:
            self.idle_blink_closed_img = self._load_sprite(
                "assets/toru_blink_closed.png", self.width, self.height
            )
        except Exception:
            self.idle_blink_closed_img = self.idle_img

        # Build idle animation sequence: idle → half → closed → half → idle ...
        self._idle_frames = [
            self.idle_img,
            self.idle_img,
            self.idle_blink_half_img,
            self.idle_blink_closed_img,
            self.idle_blink_half_img,
        ]
        self._idle_frame_index = 0
        self._idle_last_switch = time.time()

        self._animation_loop()

        pygame.quit()

    def push_audio_chunk(self, audio_chunk: np.ndarray):
        self.audio_queue.put(audio_chunk)

    def _classify_phoneme(self, chunk, samplerate):

        if len(chunk) == 0:
            return "idle"

        # Ensure mono and limit the analysis window to keep FFT cheap
        if chunk.ndim > 1:
            chunk = chunk.mean(axis=1)

        max_len = 2048
        if len(chunk) > max_len:
            chunk = chunk[-max_len:]

        # If the chunk is very short, don't bother classifying
        if len(chunk) < 256:
            return "idle"

        chunk = chunk.astype(np.float32, copy=False)

        spectrum = np.abs(np.fft.rfft(chunk))
        freqs = np.fft.rfftfreq(len(chunk), 1 / samplerate)

        # Safely compute band energies; if a band is empty, treat it as zero
        def band_energy(low_f: float, high_f: float) -> float:
            mask = (freqs > low_f) & (freqs < high_f)
            if not mask.any():
                return 0.0
            band = spectrum[mask]
            if band.size == 0:
                return 0.0
            return float(band.mean())

        energy_low = band_energy(200.0, 500.0)
        energy_mid = band_energy(500.0, 1500.0)
        energy_high = band_energy(1500.0, 3000.0)

        total = energy_low + energy_mid + energy_high + 1e-6

        # If there is effectively no energy, stay idle
        if total <= 1e-6:
            return "idle"

        low_ratio = energy_low / total
        mid_ratio = energy_mid / total
        high_ratio = energy_high / total

        if low_ratio > 0.5:
            return "O"
        elif mid_ratio > 0.45:
            return "A"
        elif high_ratio > 0.4:
            return "E"
        elif low_ratio > 0.3:
            return "U"
        else:
            return "idle"

    def _load_sprite(self, path: str, width: int, height: int) -> pygame.Surface:
        """Load a sprite, convert it to the display format and scale once.

        Doing this up front avoids per-frame conversions/rescales which can
        cause stutter when the avatar is animating.
        """

        img = pygame.image.load(path).convert_alpha()
        if img.get_width() != width or img.get_height() != height:
            img = pygame.transform.smoothscale(img, (width, height))
        return img

    def _animation_loop(self):

        samplerate = 24000
        clock = pygame.time.Clock()

        while self.running:
            # Handle window events so the avatar window stays responsive
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False
                    break

            if not self.running:
                break

            try:
                chunk = self.audio_queue.get(timeout=0.1)
            except queue.Empty:
                # No audio, play idle blink animation
                self._draw(self._next_idle_frame())
                # Limit idle redraw rate to avoid unnecessary CPU usage
                clock.tick(30)
                continue

            phoneme = self._classify_phoneme(chunk, samplerate)

            if phoneme == "A":
                img = self.A_img
            elif phoneme == "E":
                img = self.E_img
            elif phoneme == "O":
                img = self.O_img
            elif phoneme == "U":
                img = self.U_img
            else:
                # When classified as idle while audio is present, keep blinking
                img = self._next_idle_frame()

            self._draw(img)
            # Cap animation loop frame rate to keep window responsive
            clock.tick(30)

    def _draw(self, img):
        self.screen.fill((0, 0, 0))
        self.screen.blit(img, (0, 0))
        pygame.display.flip()

    def _next_idle_frame(self):
        """Return the next frame for the idle blink animation."""

        if not self._idle_frames:
            return self.idle_img

        now = time.time()
        if now - self._idle_last_switch >= self._idle_frame_duration:
            self._idle_last_switch = now
            self._idle_frame_index = (self._idle_frame_index + 1) % len(self._idle_frames)

        return self._idle_frames[self._idle_frame_index]

    # Backwards-compat helpers so existing main code doesn't break
    def set_talking(self, is_talking: bool):
        # Talking state is now driven directly from audio, so this is a no-op.
        pass

    def handle_events(self):
        # Events are handled inside the animation loop; keep this for older code paths.
        pass

    def update(self):
        # Rendering is done in the animation loop thread.
        pass