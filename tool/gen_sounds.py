import math, struct, wave, os

SR = 44100
OUT = os.environ.get("OUT_DIR", "sounds")
os.makedirs(OUT, exist_ok=True)

def env(i, n, attack=0.005, release=0.5):
    """Attack/decay envelope in [0,1], time in seconds relative to note length."""
    t = i / SR
    total = n / SR
    a = min(attack, total)
    amp = t / a if t < a else 1.0
    # exponential-ish decay over the remainder
    rem = max(total - a, 1e-6)
    decay = math.exp(-3.0 * (t - a) / rem) if t >= a else 1.0
    return amp * decay

def tone(freq, dur, vol=0.35, harmonics=(1.0, 0.25)):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        s = 0.0
        for h, hv in enumerate(harmonics, start=1):
            s += hv * math.sin(2 * math.pi * freq * h * t)
        s *= env(i, n) * vol
        out.append(s)
    return out

def glide(f0, f1, dur, vol=0.32):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = f0 + (f1 - f0) * (i / n)
        s = math.sin(2 * math.pi * f * t) * env(i, n) * vol
        out.append(s)
    return out

def write(name, samples):
    # soft-clip
    frames = b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print(f"wrote {name}: {len(samples)/SR*1000:.0f}ms")

def seq(notes):
    out = []
    for f, d in notes:
        out += tone(f, d)
    return out

# select: bright short blip
write("select.wav", tone(880, 0.07, vol=0.30))

# move: soft descending pluck
write("move.wav", glide(560, 360, 0.09, vol=0.30))

# clear: happy ascending arpeggio C5 E5 G5 (+ octave sparkle)
write("clear.wav", seq([(523.25, 0.075), (659.25, 0.075), (783.99, 0.11)]))

# gameover: gentle descending A4 F4 D4
write("gameover.wav", seq([(440.0, 0.14), (349.23, 0.14), (293.66, 0.22)]))
