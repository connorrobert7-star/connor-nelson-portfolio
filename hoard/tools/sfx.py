"""Generate the game's short sound effects as 16-bit mono WAVs in game/audio/.

    python tools/sfx.py

Everything is synthesized here so the game ships no third-party audio.
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22_050
OUT = Path(__file__).resolve().parent.parent / "game" / "audio"


def env(t: float, dur: float, attack: float = 0.005, release: float = 0.08) -> float:
    if t < attack:
        return t / attack
    if t > dur - release:
        return max(0.0, (dur - t) / release)
    return 1.0


def osc(kind: str, phase: float) -> float:
    if kind == "sine":
        return math.sin(2 * math.pi * phase)
    if kind == "square":
        return 1.0 if (phase % 1) < 0.5 else -1.0
    if kind == "tri":
        p = phase % 1
        return 4 * p - 1 if p < 0.5 else 3 - 4 * p
    return 0.0


def tone(
    notes: list[tuple[float, float]], kind: str = "square", vol: float = 0.3, slide: float = 0.0
) -> list[float]:
    """notes: [(freq, seconds)]; slide multiplies frequency over each note."""
    out: list[float] = []
    for freq, dur in notes:
        n = int(dur * RATE)
        phase = 0.0
        for i in range(n):
            t = i / RATE
            f = freq * (1 + slide * t / dur) if freq else 0.0
            phase += f / RATE
            out.append(
                osc(kind, phase) * env(t, dur, release=min(0.08, dur / 2)) * vol if freq else 0.0
            )
    return out


def noise(dur: float, vol: float = 0.3, decay: float = 20.0, seed: int = 1) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(-1, 1) * vol * math.exp(-decay * i / RATE) for i in range(int(dur * RATE))]


def mix(*tracks: list[float]) -> list[float]:
    n = max(len(t) for t in tracks)
    return [sum(t[i] if i < len(t) else 0.0 for t in tracks) for i in range(n)]


def save(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32_000)) for s in samples)
        )


SOUNDS = {
    "blip": lambda: tone([(880, 0.035)], "square", 0.15),
    "coin": lambda: tone([(988, 0.06), (1319, 0.16)], "square", 0.22),
    "cash": lambda: mix(
        tone([(523, 0.07), (659, 0.07), (784, 0.07), (1047, 0.2)], "tri", 0.3),
        noise(0.15, 0.08, 30),
    ),
    "pop": lambda: tone([(600, 0.06)], "sine", 0.4, slide=1.5),
    "tick": lambda: mix(tone([(1800, 0.012)], "square", 0.12), noise(0.02, 0.1, 200)),
    "reveal_common": lambda: tone([(440, 0.08), (554, 0.18)], "tri", 0.3),
    "reveal_rare": lambda: tone([(523, 0.07), (659, 0.07), (784, 0.22)], "tri", 0.32),
    "reveal_epic": lambda: tone(
        [(523, 0.06), (659, 0.06), (784, 0.06), (1047, 0.3)], "square", 0.22
    ),
    "reveal_legendary": lambda: mix(
        tone([(523, 0.08), (659, 0.08), (784, 0.08), (1047, 0.08), (1319, 0.5)], "square", 0.2),
        tone([(262, 0.82)], "tri", 0.2),
    ),
    "reveal_mythic": lambda: mix(
        tone([(110, 0.9)], "square", 0.18, slide=-0.3),
        tone([(1047, 0.1), (988, 0.1), (1319, 0.1), (1568, 0.6)], "square", 0.18),
        noise(0.9, 0.06, 3),
    ),
    "level_up": lambda: tone(
        [(392, 0.08), (523, 0.08), (659, 0.08), (784, 0.08), (1047, 0.35)], "square", 0.2
    ),
    "error": lambda: tone([(196, 0.09), (147, 0.18)], "square", 0.2),
    "door": lambda: mix(tone([(140, 0.12)], "tri", 0.4, slide=-0.4), noise(0.12, 0.15, 25)),
    "whoosh": lambda: noise(0.25, 0.25, 8, seed=3),
    "hit": lambda: mix(tone([(180, 0.1)], "square", 0.3, slide=-0.6), noise(0.1, 0.3, 30)),
    "boss_down": lambda: mix(
        tone([(330, 0.15), (247, 0.15), (196, 0.15), (131, 0.6)], "square", 0.22),
        noise(1.0, 0.1, 4),
    ),
    "chant": lambda: mix(
        tone([(220, 0.9)], "tri", 0.18),
        tone([(277, 0.9)], "tri", 0.12),
        tone([(330, 0.9)], "sine", 0.1),
    ),
    "scratch": lambda: noise(0.08, 0.2, 10, seed=7),
}


def main() -> None:
    for name, make in SOUNDS.items():
        save(name, make())


if __name__ == "__main__":
    main()
