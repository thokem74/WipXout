"""Build mechanical racing audio from retained CC0 recordings.

Requires Python 3 and FFmpeg. Sources and licenses live in audio_sources; all
filtering and layering happens offline, leaving only loop crossfades in Godot.
Run with --preview to also write a stereo audition reel into builds/.
"""
from array import array
from pathlib import Path
import argparse
import hashlib
import json
import math
import struct
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "tools" / "audio_sources"
OUTPUT = ROOT / "assets" / "audio"
RATE = 44100
TAU = math.tau
LOOP_FRAMES = RATE * 2


def normalize(samples, peak=0.65):
    gain = peak / max(0.000001, max(abs(value) for value in samples))
    return [value * gain for value in samples]


def lowpass(samples, cutoff):
    decay = math.exp(-TAU * cutoff / RATE)
    state = 0.0
    # Warm the filter for one cycle so periodic recordings keep a stable seam.
    for value in samples:
        state = value + decay * (state - value)
    result = []
    for value in samples:
        state = value + decay * (state - value)
        result.append(state)
    return result


def bandpass(samples, low, high):
    bass = lowpass(samples, low)
    return lowpass([value - bass[i] for i, value in enumerate(samples)], high)


def sample_loop(samples, position):
    index = math.floor(position)
    fraction = position - index
    return (samples[index % len(samples)] * (1.0 - fraction)
            + samples[(index + 1) % len(samples)] * fraction)


def seamless(samples):
    # Overlap the end into the start, then resample the shortened cycle back to
    # two seconds. This joins both level and local texture without a hard splice.
    overlap = min(2205, len(samples) // 8)
    result = list(samples[:-overlap])
    for i in range(overlap):
        blend = 0.5 - 0.5 * math.cos(math.pi * i / (overlap - 1))
        result[i] = samples[-overlap + i] * (1.0 - blend) + samples[i] * blend
    return [sample_loop(result, i * len(result) / LOOP_FRAMES) for i in range(LOOP_FRAMES)]


def read_source(relative_path):
    path = SOURCES / relative_path
    decoded = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
        "-f", "f32le", "pipe:1"])
    values = array("f")
    values.frombytes(decoded)
    if sys.byteorder != "little":
        values.byteswap()
    return normalize(values)


def envelope(time, duration, attack=0.008):
    return min(1.0, max(0.0, time) / attack) * max(0.0, 1.0 - time / duration) ** 2


def write_wav(path, samples, channels=1):
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for value in samples:
        if not math.isfinite(value) or abs(value) >= 0.95:
            raise ValueError(f"{path.name}: invalid sample or insufficient headroom")
        frames.extend(struct.pack("<h", round(value * 32767)))
    with wave.open(str(path), "wb") as sound:
        sound.setnchannels(channels)
        sound.setsampwidth(2)
        sound.setframerate(RATE)
        sound.writeframes(frames)


def build_sounds():
    car = normalize(bandpass(read_source("racing/loop_0.wav"), 80, 3800))
    rotary = normalize(bandpass(read_source("kenney/engineCircular_000.ogg"), 90, 3000))
    low = normalize(bandpass(read_source("kenney/spaceEngineLow_000.ogg"), 65, 1600))
    turbine = normalize(bandpass(read_source("kenney/spaceEngineSmall_000.ogg"), 220, 5200))
    thruster = normalize(bandpass(read_source("kenney/thrusterFire_000.ogg"), 160, 5500))
    metal = read_source("kenney/impactMetal_000.ogg")
    crunch = read_source("kenney/explosionCrunch_000.ogg")
    sounds = {}
    for profile in ("player", "chug", "turbine"):
        for loaded in (False, True):
            result = []
            for i in range(LOOP_FRAMES):
                t = i / RATE
                if profile == "player":
                    # Slightly mismatched engine banks create a rough beating roar.
                    banks = (sample_loop(car, i * (1.25 if loaded else 0.72))
                             + 0.55 * sample_loop(car, i * (1.29 if loaded else 0.75) + 800))
                    value = 0.65 * banks + 0.22 * sample_loop(rotary, i * 0.9)
                    value *= 0.8 + 0.2 * math.sin(TAU * 27 * t) ** 2
                elif profile == "chug":
                    pulse = (0.5 + 0.5 * math.sin(TAU * (19 if loaded else 11) * t)) ** 3
                    uneven = 0.8 + 0.2 * math.sin(TAU * 3 * t + 0.7)
                    value = (0.6 * sample_loop(low, i * 0.75)
                             + 0.45 * sample_loop(car, i * 0.65)) * (0.25 + pulse * uneven)
                    value += 0.12 * math.sin(TAU * 110 * t) * pulse
                else:
                    value = (0.7 * sample_loop(turbine, i * (1.2 if loaded else 0.82))
                             + 0.2 * sample_loop(rotary, i * 1.45))
                    value += 0.10 * math.sin(TAU * 680 * t + 1.5 * math.sin(TAU * 37 * t))
                    value *= 0.8 + 0.2 * math.sin(TAU * 43 * t) ** 2
                # Gentle saturation adds mechanical bite, rather than a clean synth tone.
                result.append(math.tanh(value * (2.6 if loaded else 1.3)))
            name = f"engine_{profile}_{'load' if loaded else 'idle'}"
            sounds[name] = normalize(seamless(result), 0.68 if loaded else 0.54)
    sounds["boost"] = normalize(seamless([
        math.tanh(2.5 * (sample_loop(thruster, i * 1.1)
                        + 0.4 * sample_loop(car, i * 1.8)))
        * (0.8 + 0.2 * math.sin(TAU * 31 * i / RATE) ** 2)
        for i in range(LOOP_FRAMES)]), 0.68)
    for name, duration in (("countdown", 0.3), ("go", 0.55), ("wall", 0.32), ("finish", 0.8)):
        result = []
        for i in range(round(duration * RATE)):
            t = i / RATE
            if name == "countdown":
                # Short race-klaxon pulses with a metallic attack.
                value = (0.35 * math.tanh(3 * math.sin(TAU * 290 * t))
                         + 0.35 * sample_loop(rotary, i * 2)
                         + 0.25 * sample_loop(metal, i * 1.3) * math.exp(-t * 30))
            elif name == "go":
                value = (0.65 * sample_loop(thruster, i * (0.8 + t))
                         + 0.3 * sample_loop(car, i * 1.8)
                         + 0.16 * math.sin(TAU * 580 * t))
            elif name == "wall":
                value = sample_loop(metal, i * 0.8) + 0.6 * sample_loop(crunch, i * 1.1)
            else:
                # A double racing horn, rather than the previous musical arpeggio.
                pulse = 1.0 if t < 0.18 or 0.27 < t < 0.68 else 0.0
                value = (0.5 * math.tanh(2 * math.sin(TAU * 390 * t))
                         + 0.25 * math.sin(TAU * 585 * t)
                         + 0.2 * sample_loop(rotary, i)) * pulse
                # Soften the horn gates to prevent clicks.
                gate_distance = min(abs(t - edge) for edge in (0, 0.18, 0.27, 0.68))
                value *= min(1.0, gate_distance / 0.008)
            result.append(value * envelope(t, duration))
        sounds[name] = normalize(result, 0.62)
    return sounds


def validate(sounds):
    hashes = set()
    for name, values in sounds.items():
        rms = math.sqrt(sum(value * value for value in values) / len(values))
        assert rms > 0.02, f"{name}: too quiet"
        if name.startswith("engine_") or name == "boost":
            largest_step = max(abs(b - a) for a, b in zip(values, values[1:]))
            assert abs(values[0] - values[-1]) <= largest_step * 1.1, f"{name}: loop click"
        fingerprint = hashlib.sha256(array("f", values).tobytes()).hexdigest()
        assert fingerprint not in hashes, f"{name}: duplicate profile"
        hashes.add(fingerprint)
        print(f"{name}: {len(values)/RATE:.2f}s, peak {max(map(abs, values)):.2f}, RMS {rms:.3f}")


def preview(sounds):
    # Each profile: idle, acceleration, coast, brake, then boost. Last section:
    # a left-to-right approaching/receding rival, countdown, GO, impact and finish.
    reel = []
    for profile in ("player", "chug", "turbine"):
        idle, loaded = sounds[f"engine_{profile}_idle"], sounds[f"engine_{profile}_load"]
        position = 0.0
        load = 0.0
        for i in range(RATE * 7):
            t = i / RATE
            if t < 1:
                speed = 0.0
            elif t < 3:
                speed = (t - 1) / 2
            elif t < 4:
                speed = 1.0 - (t - 3) * 0.1
            elif t < 5:
                speed = 0.9 - (t - 4) * 0.5
            else:
                speed = 0.4 + (t - 5) * 0.45
            target_load = 1.0 if 1 <= t < 3 or t >= 5 else 0.0
            load += (target_load - load) * (1.0 - math.exp(-8.0 / RATE))
            pitch = 0.68 + speed * 0.65 + load * 0.18
            position += pitch
            value = (sample_loop(idle, position) * math.sqrt(1 - load)
                     + sample_loop(loaded, position) * math.sqrt(load)) * 0.45
            if t > 5:
                value += sample_loop(sounds['boost'], i) * 0.25 * min(1.0, (t - 5) * 10)
            value *= min(1.0, t * 20, (7 - t) * 20)
            reel.extend((value, value))
    position = 0.0
    for i in range(RATE * 4):
        t = i / RATE
        pan = t / 4
        position += 1.25 if t < 2 else 0.85
        gain = 0.45 * math.exp(-((t - 2) / 0.8) ** 2)
        value = sample_loop(sounds['engine_chug_load'], position) * gain
        reel.extend((value * math.sqrt(1 - pan), value * math.sqrt(pan)))
    cues = [("countdown", .85), ("countdown", 1), ("countdown", 1.15),
            ("go", 1), ("wall", 1), ("finish", 1)]
    for name, pitch in cues:
        values = sounds[name]
        for i in range(RATE):
            position = i * pitch
            value = sample_loop(values, position) * 0.7 if position < len(values) else 0.0
            reel.extend((value, value))
    write_wav(ROOT / 'builds' / 'pod-race-audio-preview.wav', reel, 2)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview', action='store_true')
    args = parser.parse_args()
    for entry in json.loads((SOURCES / 'manifest.json').read_text()):
        path = SOURCES / entry['file']
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
            raise ValueError(f"Source recording changed: {path}")
    sounds = build_sounds()
    validate(sounds)
    for name, values in sounds.items():
        write_wav(OUTPUT / f"{name}.wav", values)
    if args.preview:
        preview(sounds)


if __name__ == '__main__':
    main()
