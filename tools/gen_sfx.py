"""Synthesize the placeholder sound effects into assets/sfx/*.wav.

Stdlib only. Run from the project root:  python tools/gen_sfx.py
Every sound is a few lines below, so they're easy to tweak or replace with
real recordings later (keep the file names and Godot picks them up).
"""
import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def env(t, attack, decay):
    """Linear attack, exponential decay envelope."""
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay)


def lowpass(samples, amount):
    """One-pole lowpass; amount in (0, 1], lower = darker."""
    out, y = [], 0.0
    for s in samples:
        y += amount * (s - y)
        out.append(y)
    return out


def noise(n, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def tone(t, f0, f1, dur):
    """Phase of a sine sweeping exponentially from f0 to f1 over dur."""
    k = math.log(f1 / f0) / dur
    return 2 * math.pi * f0 * (math.exp(k * t) - 1) / k if k else 2 * math.pi * f0 * t


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def gain(samples, g):
    return [s * g for s in samples]


def save(name, samples, peak=0.9):
    m = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s / m * peak)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def whoosh(dur, seed, bright):
    """Filtered noise with a swelling-then-fading envelope."""
    n = int(dur * RATE)
    raw = noise(n, seed)
    out = []
    y = 0.0
    for i, s in enumerate(raw):
        t = i / RATE
        cutoff = bright * (0.15 + 0.85 * math.sin(math.pi * min(t / dur, 1.0)))
        y += cutoff * (s - y)
        out.append(y * math.sin(math.pi * t / dur) ** 1.5)
    return out


def thump(dur, f0, f1, decay):
    n = int(dur * RATE)
    return [math.sin(tone(i / RATE, f0, f1, dur)) * env(i / RATE, 0.002, decay) for i in range(n)]


def crack(dur, seed, decay, bright):
    n = int(dur * RATE)
    raw = lowpass(noise(n, seed), bright)
    return [s * env(i / RATE, 0.001, decay) for i, s in enumerate(raw)]


def chime(dur, freqs, decay, spacing=0.0):
    n = int(dur * RATE)
    out = [0.0] * n
    for j, f in enumerate(freqs):
        start = int(j * spacing * RATE)
        for i in range(start, n):
            t = (i - start) / RATE
            out[i] += (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(4 * math.pi * f * t)) * env(t, 0.004, decay)
    return out


def rattle(dur, seed, clicks):
    rng = random.Random(seed)
    n = int(dur * RATE)
    out = [0.0] * n
    for _ in range(clicks):
        start = int(rng.uniform(0, dur * 0.7) * RATE)
        f = rng.uniform(900, 2200)
        for i in range(start, min(n, start + int(0.03 * RATE))):
            t = (i - start) / RATE
            out[i] += math.sin(2 * math.pi * f * t) * env(t, 0.0005, 0.006) * rng.uniform(0.5, 1.0)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    save("swing", whoosh(0.16, 1, 0.35), 0.6)
    save("swing_heavy", mix(whoosh(0.28, 2, 0.2), gain(thump(0.28, 140, 70, 0.12), 0.25)), 0.7)
    save("hit", mix(thump(0.14, 180, 60, 0.04), gain(crack(0.08, 3, 0.012, 0.6), 0.7)))
    save("hit_big", mix(thump(0.3, 140, 40, 0.08), gain(crack(0.18, 4, 0.03, 0.4), 0.8),
                        gain(thump(0.3, 70, 35, 0.12), 0.6)))
    save("dash", whoosh(0.18, 5, 0.6), 0.5)
    save("enemy_death", mix(rattle(0.45, 6, 14), gain(thump(0.2, 120, 50, 0.06), 0.5)), 0.7)
    save("player_hurt", mix(thump(0.25, 220, 90, 0.07), gain(crack(0.12, 7, 0.03, 0.25), 0.6)))
    save("perfect", mix(chime(0.6, [880, 1320], 0.2, 0.05), gain(whoosh(0.3, 8, 0.7), 0.3)), 0.6)
    save("awaken", mix(whoosh(0.9, 9, 0.15), gain(thump(0.9, 50, 30, 0.35), 0.9),
                       gain(chime(0.9, [440, 660, 880], 0.35, 0.06), 0.4)))
    save("spawn", mix(gain(crack(0.5, 10, 0.2, 0.05), 0.8), rattle(0.5, 11, 6)), 0.5)
    save("wave_clear", chime(0.8, [660, 990], 0.3, 0.12), 0.5)
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
