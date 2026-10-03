#!/usr/bin/env python3
"""Generate a loopable arcade background track for the game."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 44_100
BPM = 132
BEATS = 32
OUT_PATH = Path(__file__).resolve().parents[1] / "assets" / "audio" / "background_loop.wav"


def midi_to_hz(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def square(phase: float, duty: float = 0.5) -> float:
    return 1.0 if phase % 1.0 < duty else -1.0


def envelope(time: float, duration: float, attack: float, release: float) -> float:
    if time < 0.0 or time >= duration:
        return 0.0
    if time < attack:
        return time / attack
    if time > duration - release:
        return max(0.0, (duration - time) / release)
    return 1.0


def add_tone(
    left: list[float],
    right: list[float],
    start: float,
    duration: float,
    freq: float,
    volume: float,
    pan: float = 0.0,
    waveform: str = "square",
) -> None:
    start_i = int(start * SAMPLE_RATE)
    end_i = min(len(left), int((start + duration) * SAMPLE_RATE))
    left_gain = math.cos((pan + 1.0) * math.pi / 4.0)
    right_gain = math.sin((pan + 1.0) * math.pi / 4.0)

    for i in range(start_i, end_i):
        t = i / SAMPLE_RATE - start
        phase = t * freq
        env = envelope(t, duration, 0.006, min(0.08, duration * 0.45))
        if waveform == "sine":
            sample = math.sin(phase * math.tau)
        elif waveform == "triangle":
            sample = 2.0 * abs(2.0 * (phase % 1.0) - 1.0) - 1.0
        else:
            sample = square(phase, 0.42)

        # Gentle octave shimmer keeps it arcade-like without getting harsh.
        sample += 0.22 * math.sin(phase * 2.0 * math.tau)
        sample *= volume * env
        left[i] += sample * left_gain
        right[i] += sample * right_gain


def add_noise_hit(left: list[float], right: list[float], start: float, duration: float, volume: float) -> None:
    rng = random.Random(int(start * 10_000))
    start_i = int(start * SAMPLE_RATE)
    end_i = min(len(left), int((start + duration) * SAMPLE_RATE))
    last = 0.0

    for i in range(start_i, end_i):
        t = i / SAMPLE_RATE - start
        env = envelope(t, duration, 0.002, duration * 0.85)
        last = (last * 0.72) + (rng.uniform(-1.0, 1.0) * 0.28)
        sample = last * volume * env
        left[i] += sample * 0.62
        right[i] += sample * 0.62


def soft_clip(sample: float) -> float:
    return math.tanh(sample * 1.35) * 0.78


def main() -> None:
    beat = 60.0 / BPM
    duration = beat * BEATS
    count = int(duration * SAMPLE_RATE)
    left = [0.0] * count
    right = [0.0] * count

    bass_notes = [36, 36, 43, 41, 36, 39, 43, 34]
    melody_notes = [72, 75, 79, 77, 75, 82, 79, 75, 70, 72, 75, 79, 84, 82, 79, 77]

    for step in range(BEATS * 2):
        t = step * beat / 2.0
        if step % 2 == 0:
            note = bass_notes[(step // 2) % len(bass_notes)]
            add_tone(left, right, t, beat * 0.44, midi_to_hz(note), 0.16, -0.08, "triangle")
        if step % 4 in (1, 3):
            add_noise_hit(left, right, t, beat * 0.16, 0.034)

    for step, note in enumerate(melody_notes * 2):
        t = step * beat
        pan = -0.35 if step % 2 == 0 else 0.35
        add_tone(left, right, t + beat * 0.06, beat * 0.34, midi_to_hz(note), 0.075, pan)
        if step % 4 == 2:
            add_tone(left, right, t + beat * 0.53, beat * 0.18, midi_to_hz(note + 7), 0.045, -pan)

    # A quiet center drone gives the loop body while leaving room for SFX.
    for note, vol in ((48, 0.024), (55, 0.018), (60, 0.012)):
        add_tone(left, right, 0.0, duration, midi_to_hz(note), vol, 0.0, "sine")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT_PATH), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for l_value, r_value in zip(left, right):
            frames += struct.pack("<hh", int(soft_clip(l_value) * 32767), int(soft_clip(r_value) * 32767))
        wav.writeframes(frames)

    print(f"Wrote {OUT_PATH.relative_to(Path.cwd())} ({duration:.2f}s loop)")


if __name__ == "__main__":
    main()
