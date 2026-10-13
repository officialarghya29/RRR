#!/usr/bin/env python3
"""Session 012 step 5 — procedural SFX for the 14 SoundEvents ids.

Every sound here is ORIGINAL SYNTHESIS written for this project: tones,
noise bursts, envelopes and a seeded jitter — no samples, no third-party
audio, nothing derived from any existing work. Ids, durations and shapes
follow docs/AUDIO_BRIEF.md; output lands in assets/audio/sfx/<id>.wav
(16-bit mono PCM @ 22050 Hz), named after the id.

Determinism: one fixed RNG seed for the whole run — regenerating always
produces byte-identical files.

Usage:  python3 tools/gen_sfx.py
"""

import math
import os
import random
import struct
import wave

SR = 22050                 # sample rate (Hz) — small files, enough bandwidth
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")
SEED = 0x5EC012            # one seed for the whole generator (S012)

rng = random.Random(SEED)


# --- tiny DSP toolkit -------------------------------------------------------

def seconds(n: float) -> int:
    return int(round(n * SR))


def silence(n: int) -> list:
    return [0.0] * n


def add(buf: list, start: int, sig) -> None:
    """Overlay sig into buf at sample start (clipped to buf length)."""
    for i, s in enumerate(sig):
        j = start + i
        if 0 <= j < len(buf):
            buf[j] += s


def sine(freq, n: int, phase: float = 0.0) -> list:
    if callable(freq):
        out, ph = [], phase
        for i in range(n):
            ph += 2.0 * math.pi * freq(i) / SR
            out.append(math.sin(ph))
        return out
    out, ph = [], phase
    for _ in range(n):
        ph += 2.0 * math.pi * freq / SR
        out.append(math.sin(ph))
    return out


def sweep(f0: float, f1: float, n: int, curve: float = 2.0) -> list:
    """Exponential pitch sweep f0 -> f1 over n samples."""
    out, ph = [], 0.0
    for i in range(n):
        t = i / max(1, n - 1)
        f = f0 * ((f1 / f0) ** (t ** curve))
        ph += 2.0 * math.pi * f / SR
        out.append(math.sin(ph))
    return out


def noise(n: int) -> list:
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lp1(x: list, alpha: float) -> list:
    """One-pole low-pass; alpha in (0,1], higher = brighter."""
    y, prev = [], 0.0
    for s in x:
        prev += alpha * (s - prev)
        y.append(prev)
    return y


def hp1(x: list, alpha: float) -> list:
    """One-pole high-pass (low-pass subtracted)."""
    low = lp1(x, alpha)
    return [a - b for a, b in zip(x, low)]


def saw(freq: float, n: int, harmonics: int = 8) -> list:
    out = [0.0] * n
    for k in range(1, harmonics + 1):
        part = sine(freq * k, n)
        for i in range(n):
            out[i] += part[i] / k
    return out


def env_exp(n: int, tau: float) -> list:
    return [math.exp(-i / (tau * SR)) for i in range(n)]


def env_ar(n: int, attack: float, release: float) -> list:
    out = []
    for i in range(n):
        t = i / SR
        a = min(1.0, t / attack) if attack > 0 else 1.0
        r = min(1.0, (n / SR - t) / release) if release > 0 else 1.0
        out.append(max(0.0, min(a, r)))
    return out


def mul(x: list, env: list) -> list:
    return [a * b for a, b in zip(x, env)]


def scale(x: list, gain: float) -> list:
    return [s * gain for s in x]


def gritty(x: list, depth: float = 0.25, rate: float = 30.0) -> list:
    """Seeded amplitude jitter — the 'stone grind' texture."""
    g, level = [], 1.0
    step = rate / SR
    for _ in x:
        level += rng.uniform(-depth, depth)
        level = max(1.0 - depth * 2.0, min(1.0 + depth * 2.0, level))
        g.append(level)
    return [a * b for a, b in zip(x, g)]


def normalize(x: list, peak: float = 0.9) -> list:
    m = max(1e-9, max(abs(s) for s in x))
    return [s * (peak / m) for s in x]


# --- the 14 sounds ----------------------------------------------------------

def land_soft() -> list:
    # light cloth/foot thud: small pitch-drop thump + soft noise puff
    n = seconds(0.25)
    buf = silence(n)
    add(buf, 0, mul(sweep(220, 90, seconds(0.12)), env_exp(seconds(0.12), 0.035)))
    add(buf, 0, scale(mul(lp1(noise(seconds(0.06)), 0.35), env_exp(seconds(0.06), 0.02)), 0.5))
    return buf


def land_medium() -> list:
    # heavier impact + a small breath-grunt
    n = seconds(0.40)
    buf = silence(n)
    add(buf, 0, mul(sweep(160, 70, seconds(0.20)), env_exp(seconds(0.20), 0.06)))
    add(buf, 0, scale(mul(lp1(noise(seconds(0.10)), 0.30), env_exp(seconds(0.10), 0.035)), 0.6))
    grunt = mul(sine(180, seconds(0.18)), env_exp(seconds(0.18), 0.06))
    add(buf, seconds(0.08), scale(grunt, 0.35))
    return buf


def land_hard() -> list:
    # body impact, dark: deep thud + broadband decay
    n = seconds(0.60)
    buf = silence(n)
    add(buf, 0, mul(sweep(110, 45, seconds(0.35)), env_exp(seconds(0.35), 0.12)))
    add(buf, 0, scale(mul(lp1(noise(seconds(0.25)), 0.20), env_exp(seconds(0.25), 0.08)), 0.7))
    return buf


def spike() -> list:
    # impale crunch + inharmonic metal ring
    n = seconds(0.50)
    buf = silence(n)
    add(buf, 0, scale(mul(hp1(noise(seconds(0.08)), 0.40), env_exp(seconds(0.08), 0.025)), 0.8))
    ring = silence(seconds(0.35))
    for f in (1180.0, 1712.0, 2390.0, 3350.0):
        add(ring, 0, mul(sine(f, seconds(0.35)), env_exp(seconds(0.35), 0.09)))
    add(buf, seconds(0.02), scale(ring, 0.7))
    add(buf, 0, mul(sine(300, seconds(0.10)), env_exp(seconds(0.10), 0.03)))
    return buf


def death() -> list:
    # death sting: falling detuned pair + low boom
    n = seconds(0.80)
    buf = silence(n)
    body = sweep(220, 130, seconds(0.60))
    body2 = sweep(223, 128, seconds(0.60))
    pair = [(a + b) * 0.5 for a, b in zip(body, body2)]
    add(buf, 0, scale(mul(lp1(pair, 0.35), env_exp(seconds(0.60), 0.25)), 0.8))
    add(buf, 0, mul(sweep(90, 40, seconds(0.45)), env_exp(seconds(0.45), 0.15)))
    return buf


def plate() -> list:
    # stone click: tick transient + short tap
    n = seconds(0.20)
    buf = silence(n)
    add(buf, 0, scale(mul(lp1(noise(seconds(0.03)), 0.5), env_exp(seconds(0.03), 0.008)), 0.7))
    add(buf, 0, mul(sine(420, seconds(0.07)), env_exp(seconds(0.07), 0.02)))
    add(buf, seconds(0.01), mul(sine(150, seconds(0.06)), env_exp(seconds(0.06), 0.02)))
    return buf


def gate_open() -> list:
    # stone grind UP: rumble with a brightening filter + grit
    n = seconds(1.20)
    src = noise(n)
    # brighten over time by blending a darker and a brighter low-pass
    dark, bright = lp1(src, 0.05), lp1(src, 0.25)
    grind = []
    for i in range(n):
        t = i / n
        grind.append(dark[i] * (1.0 - t) + bright[i] * t)
    grind = gritty(grind, depth=0.30)
    buf = mul(grind, env_ar(n, 0.08, 0.15))
    add(buf, 0, mul(sweep(45, 70, n), scale(env_ar(n, 0.1, 0.2), 0.35)))
    return buf


def gate_close() -> list:
    # stone grind DOWN + a closing thunk
    n = seconds(1.00)
    src = noise(n)
    dark, bright = lp1(src, 0.05), lp1(src, 0.25)
    grind = []
    for i in range(n):
        t = i / n
        grind.append(bright[i] * (1.0 - t) + dark[i] * t)
    grind = gritty(grind, depth=0.30)
    buf = mul(grind, env_ar(n, 0.06, 0.10))
    thunk = mul(sweep(90, 45, seconds(0.15)), env_exp(seconds(0.15), 0.05))
    add(buf, seconds(0.82), scale(thunk, 0.9))
    return buf


def sword_clash() -> list:
    # bright parry: inharmonic high partials + a ping
    n = seconds(0.30)
    buf = silence(n)
    for f in (2600.0, 3900.0, 5200.0, 6900.0, 8800.0):
        add(buf, 0, mul(sine(f, n), env_exp(n, 0.05)))
    add(buf, 0, scale(mul(hp1(noise(seconds(0.03)), 0.5), env_exp(seconds(0.03), 0.008)), 0.6))
    return buf


def sword_strike() -> list:
    # hit lands on the guard: transient + thump + a hint of metal
    n = seconds(0.30)
    buf = silence(n)
    add(buf, 0, scale(mul(lp1(noise(seconds(0.04)), 0.5), env_exp(seconds(0.04), 0.012)), 0.8))
    add(buf, 0, mul(sweep(190, 110, seconds(0.12)), env_exp(seconds(0.12), 0.04)))
    add(buf, 0, mul(sine(1900, seconds(0.10)), env_exp(seconds(0.10), 0.03)))
    return buf


def sword_hurt() -> list:
    # kid pain grunt: two formants falling + breath
    n = seconds(0.30)
    buf = silence(n)
    pitch = seconds(0.22)
    f0 = [240.0 - 50.0 * (i / pitch) for i in range(pitch)]
    grunt = [0.0] * pitch
    for formant, gain in ((1.0, 1.0), (2.9, 0.45)):  # ~320 Hz + ~880 Hz
        phase = 0.0
        for i in range(pitch):
            phase += 2.0 * math.pi * f0[i] * formant / SR
            grunt[i] += gain * math.sin(phase)
    add(buf, 0, mul(lp1(grunt, 0.4), env_exp(pitch, 0.07)))
    add(buf, 0, scale(mul(lp1(noise(seconds(0.10)), 0.25), env_exp(seconds(0.10), 0.035)), 0.4))
    return buf


def guard_death() -> list:
    # guard falls: body drop + two clatters of the sword
    n = seconds(0.60)
    buf = silence(n)
    add(buf, 0, mul(sweep(140, 60, seconds(0.30)), env_exp(seconds(0.30), 0.09)))
    add(buf, 0, scale(mul(lp1(noise(seconds(0.18)), 0.25), env_exp(seconds(0.18), 0.06)), 0.7))
    for start, f in ((seconds(0.25), 3100.0), (seconds(0.36), 4700.0)):
        clat = mul(sine(f, seconds(0.12)), env_exp(seconds(0.12), 0.03))
        add(buf, start, scale(clat, 0.5))
    return buf


def echo_record() -> list:
    # rising time shimmer
    n = seconds(0.50)
    buf = silence(n)
    base = sweep(600, 900, n)
    vib = [1.0 + 0.03 * math.sin(2.0 * math.pi * 6.0 * i / SR) for i in range(n)]
    shimmer = [a * b for a, b in zip(base, vib)]
    add(buf, 0, mul(shimmer, env_ar(n, 0.12, 0.12)))
    add(buf, 0, scale(mul(hp1(noise(n), 0.5), env_ar(n, 0.15, 0.15)), 0.15))
    return buf


def echo_release() -> list:
    # shimmer resolve: FM bell (inharmonic ratio), long decay
    n = seconds(0.60)
    carrier, index = 520.0, 4.0
    mod_ratio = 1.52                       # deliberately inharmonic
    out, ph, mph = [], 0.0, 0.0
    dec = env_exp(n, 0.18)
    for i in range(n):
        mph += 2.0 * math.pi * carrier * mod_ratio / SR
        idx = index * dec[i]
        ph += 2.0 * math.pi * carrier / SR
        out.append(math.sin(ph + idx * math.sin(mph)))
    buf = mul(out, env_exp(n, 0.16))
    add(buf, 0, mul(sine(1046, n), scale(env_exp(n, 0.08), 0.3)))
    return buf


SOUNDS = {
    "land_soft": land_soft,
    "land_medium": land_medium,
    "land_hard": land_hard,
    "spike": spike,
    "death": death,
    "plate": plate,
    "gate_open": gate_open,
    "gate_close": gate_close,
    "sword_clash": sword_clash,
    "sword_strike": sword_strike,
    "sword_hurt": sword_hurt,
    "guard_death": guard_death,
    "echo_record": echo_record,
    "echo_release": echo_release,
}


def write_wav(name: str, samples: list) -> str:
    data = normalize(samples)
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in data)
        w.writeframes(frames)
    return path


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, fn in SOUNDS.items():
        samples = fn()
        path = write_wav(name, samples)
        peak = max(abs(s) for s in samples)
        rms = math.sqrt(sum(s * s for s in samples) / max(1, len(samples)))
        print("%-14s %5.2fs  peak %.2f  rms %.3f  -> %s" % (
            name, len(samples) / SR, peak, rms, os.path.relpath(path)))


if __name__ == "__main__":
    main()
