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
    # Bone cage: walls grind up out of the floor, then clack shut.
    save("cage_rise", mix(rattle(0.8, 13, 45), gain(whoosh(0.8, 14, 0.08), 0.9),
                          gain(thump(0.8, 55, 40, 0.3), 0.6)), 0.7)
    save("cage_shut", mix(rattle(0.35, 15, 24), gain(crack(0.25, 16, 0.05, 0.3), 0.9),
                          gain(thump(0.3, 110, 45, 0.08), 0.7)), 0.8)
    # Low-HP heartbeat: "lub" then a softer "dub".
    save("heartbeat", mix(thump(0.22, 70, 45, 0.06),
                          [0.0] * int(0.17 * RATE) + gain(thump(0.2, 60, 40, 0.05), 0.7)), 0.7)
    # Combo callouts, quiet and short, one per tier: string, heavy route, finisher.
    save("combo_1", chime(0.2, [1320, 1760], 0.04, 0.035), 0.35)
    save("combo_2", mix(chime(0.3, [880, 1320], 0.07, 0.06), gain(thump(0.2, 160, 90, 0.05), 0.35)), 0.4)
    save("combo_3", mix(chime(0.35, [660, 880, 1320], 0.1, 0.04), gain(whoosh(0.35, 17, 0.5), 0.35)), 0.45)
    # Element casts (quiet, they come with most attacks) and the ultimates.
    save("cast_spirit", mix(chime(0.3, [990, 1485], 0.08, 0.03), gain(whoosh(0.25, 18, 0.6), 0.5)), 0.35)
    save("cast_wind", mix(whoosh(0.24, 19, 0.85), gain(chime(0.2, [1760], 0.04), 0.15)), 0.4)
    save("cast_earth", mix(thump(0.25, 110, 45, 0.08), gain(crack(0.2, 20, 0.04, 0.2), 0.8), gain(rattle(0.25, 21, 8), 0.4)), 0.45)
    save("cast_water", mix(whoosh(0.25, 22, 0.4), gain(chime(0.25, [2093, 2637, 3136], 0.05, 0.02), 0.35)), 0.4)
    # Ultimate: a rising sweep into a chord.
    sweep = [math.sin(tone(i / RATE, 180, 900, 0.7)) * env(i / RATE, 0.25, 0.25) for i in range(int(0.7 * RATE))]
    save("ult", mix(gain(sweep, 0.5), whoosh(0.7, 23, 0.3), gain(chime(0.9, [523, 784, 1047], 0.35, 0.05), 0.5)), 0.8)
    # Combo breakers. War cry: a distorted growl swelling up and breaking off
    # (two detuned saws with a wobble, breath noise, darkened, clipped).
    n = int(0.55 * RATE)
    breath = lowpass(noise(n, 26), 0.25)
    cry = []
    for i in range(n):
        t = i / RATE
        f = 105 + 70 * math.sin(math.pi * min(t / 0.4, 1.0)) + 6 * math.sin(2 * math.pi * 23 * t)
        ph = f * t
        saw = (ph % 1.0) * 2 - 1 + ((ph * 1.507) % 1.0) - 0.5
        e = min(t / 0.06, 1.0) * (1.0 if t < 0.32 else math.exp(-(t - 0.32) / 0.08))
        cry.append(math.tanh(2.5 * (saw * 0.7 + breath[i] * 0.8)) * e)
    save("war_cry", mix(lowpass(lowpass(cry, 0.22), 0.35), gain(thump(0.3, 90, 50, 0.1), 0.4)), 0.8)
    # Quake: the floor breaking under the dive, a crack, a low rumble, rubble.
    save("quake", mix(gain(crack(0.3, 27, 0.04, 0.5), 0.9), thump(0.7, 70, 25, 0.22),
                      gain([x * env(i / RATE, 0.005, 0.2) for i, x in enumerate(lowpass(noise(int(0.7 * RATE), 28), 0.03))], 2.2),
                      gain(rattle(0.6, 29, 22), 0.5)), 0.9)
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
