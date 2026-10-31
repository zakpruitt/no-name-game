"""Synthesize the placeholder music loops into assets/music/*.wav.

Stdlib only. Run from the project root:  python tools/gen_music.py
Two layers of the same length and tempo, played in sync by Game:
  ambient  dark pad + drone + sparse bells (always on)
  combat   drums + driving bass (faded in by style rank, see Game.MUSIC_RANK_LEVEL)
Tempo, key and chords are the constants below; swap in real tracks later by
keeping the file names (both loops must stay the same length).
"""
import math
import os
import random
import struct
import wave

RATE = 22050
BPM = 96
BARS = 8
BEAT = 60.0 / BPM
LENGTH = int(BARS * 4 * BEAT * RATE)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "music")

# One chord per 2 bars (MIDI notes): Dm, Bb, Gm, A.
CHORDS = [[50, 57, 65], [46, 53, 62], [43, 50, 58], [45, 52, 61]]
ROOTS = [38, 34, 31, 33]


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12.0)


def add(buf, start, samples, g=1.0):
    """Mix samples into buf at start, wrapping around so the loop is seamless."""
    for i, s in enumerate(samples):
        buf[(start + i) % LENGTH] += s * g


def pad_note(f, dur, attack, release):
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        e = min(1.0, t / attack) * min(1.0, (dur - t) / release)
        # Two slightly detuned voices with a couple of soft harmonics.
        s = 0.0
        for det in (0.997, 1.003):
            p = 2 * math.pi * f * det * t
            s += math.sin(p) + 0.3 * math.sin(2 * p) + 0.12 * math.sin(3 * p)
        out.append(s * e * (0.85 + 0.15 * math.sin(2 * math.pi * 0.25 * t)))
    return out


def bell(f, dur, decay):
    n = int(dur * RATE)
    return [math.exp(-i / RATE / decay) * (math.sin(2 * math.pi * f * i / RATE)
            + 0.4 * math.sin(2 * math.pi * f * 2.76 * i / RATE)) for i in range(n)]


def kick(dur=0.35):
    n = int(dur * RATE)
    out, ph = [], 0.0
    for i in range(n):
        t = i / RATE
        ph += 2 * math.pi * (45 + 75 * math.exp(-t / 0.04)) / RATE
        out.append(math.sin(ph) * math.exp(-t / 0.12))
    return out


def snare(seed, dur=0.22):
    rng = random.Random(seed)
    n = int(dur * RATE)
    return [(rng.uniform(-1, 1) * 0.7 + math.sin(2 * math.pi * 190 * i / RATE) * 0.5)
            * math.exp(-i / RATE / 0.06) for i in range(n)]


def hat(seed, dur=0.06):
    rng = random.Random(seed)
    n = int(dur * RATE)
    out, prev = [], 0.0
    for i in range(n):
        x = rng.uniform(-1, 1)
        out.append((x - prev) * math.exp(-i / RATE / 0.015))  # crude highpass
        prev = x
    return out


def tom(f, dur=0.4):
    n = int(dur * RATE)
    out, ph = [], 0.0
    for i in range(n):
        t = i / RATE
        ph += 2 * math.pi * f * (1 + 0.5 * math.exp(-t / 0.05)) / RATE
        out.append(math.sin(ph) * math.exp(-t / 0.15))
    return out


def bass(f, dur):
    n = int(dur * RATE)
    out, y = [], 0.0
    for i in range(n):
        t = i / RATE
        p = 2 * math.pi * f * t
        s = sum(math.sin(p * k) / k for k in range(1, 6))  # band-limited saw
        y += 0.25 * (s - y)  # lowpass
        out.append(y * min(1.0, t / 0.005) * math.exp(-t / 0.18))
    return out


def save(name, samples, peak):
    m = max(1e-9, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s / m * peak)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def ambient():
    buf = [0.0] * LENGTH
    seg = 2 * 4 * BEAT
    rng = random.Random(1)
    for c, chord in enumerate(CHORDS):
        start = int(c * seg * RATE)
        for note in chord:
            add(buf, start, pad_note(hz(note), seg + 1.2, 1.0, 1.4), 0.22)
        add(buf, start, pad_note(hz(ROOTS[c] - 12), seg + 1.2, 1.5, 1.5), 0.3)
        # Sparse bells on chord tones, an octave up.
        for half in range(4):
            if rng.random() < 0.7:
                note = rng.choice(chord) + 12
                add(buf, start + int(half * 2 * BEAT * RATE), bell(hz(note), 2.0, 0.6), 0.12)
    return buf


def combat():
    buf = [0.0] * LENGTH
    step = int(BEAT / 2 * RATE)  # eighth notes
    for i in range(BARS * 8):
        bar, eighth = divmod(i, 8)
        at = i * step
        if eighth % 2 == 0:
            add(buf, at, kick(), 0.9)
        if eighth in (2, 6):
            add(buf, at, snare(i), 0.5)
        add(buf, at, hat(100 + i), 0.18 if eighth % 2 else 0.1)
        root = ROOTS[bar // 2]
        add(buf, at, bass(hz(root + (12 if eighth in (3, 7) else 0)), BEAT / 2), 0.45)
        if bar == BARS - 1 and eighth >= 4:  # tom fill into the loop point
            add(buf, at, tom(hz(45 - (eighth - 4) * 3)), 0.6)
    return buf


def main():
    os.makedirs(OUT, exist_ok=True)
    save("ambient", ambient(), 0.6)
    save("combat", combat(), 0.75)
    print("wrote", sorted(f for f in os.listdir(OUT) if f.endswith(".wav")),
          "%.1fs each" % (LENGTH / RATE))


if __name__ == "__main__":
    main()
