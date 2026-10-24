"""Regenerate original mono PCM arcade sounds. Uses only Python's standard library."""
from pathlib import Path
import math
import random
import struct
import wave

OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RATE = 22050
random_source = random.Random(1986)
SOUNDS = [("engine", 1.0, 65), ("boost", 0.7, 135), ("wall", 0.18, 90),
          ("countdown", 0.16, 740), ("finish", 0.65, 880)]

for name, duration, frequency in SOUNDS:
    samples = bytearray()
    for index in range(int(RATE * duration)):
        time = index / RATE
        if name == "engine":
            value = (math.sin(math.tau * frequency * time)
                     + 0.25 * math.sin(math.tau * frequency * 3 * time)) * 0.35
        elif name == "boost":
            value = (math.sin(math.tau * (frequency * time + 130 * time * time)) * 0.4
                     + random_source.uniform(-0.15, 0.15)) * math.sin(math.pi * time / duration)
        elif name == "wall":
            value = random_source.uniform(-1, 1) * 0.45 * (1 - time / duration) ** 3
        else:
            pitch = frequency if name == "countdown" else frequency * [1, 1.25, 1.5][min(2, int(time / duration * 3))]
            value = math.sin(math.tau * pitch * time) * 0.3 * min(1, time * 100) * (1 - time / duration)
        samples.extend(struct.pack("<h", int(max(-1, min(1, value)) * 32767)))
    with wave.open(str(OUTPUT / f"{name}.wav"), "wb") as sound:
        sound.setnchannels(1)
        sound.setsampwidth(2)
        sound.setframerate(RATE)
        sound.writeframes(samples)
