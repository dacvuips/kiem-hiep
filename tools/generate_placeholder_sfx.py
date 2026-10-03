"""Sinh âm thanh TẠM (placeholder) cho chiêu đánh theo 6 hệ nguyên tố — chạy 1 lần:

    python tools/generate_placeholder_sfx.py

Ghi ra res://audio/sfx/skill/<element>_cast.wav và <element>_hit.wav (mono, 22050Hz, 16-bit).
Khi có file âm thanh thật, chỉ cần GHI ĐÈ đúng tên file (hoặc gán cast_sfx/hit_sfx riêng trên
SkillGemData) — không cần sửa code.
"""
import os
import wave

import numpy as np

SR = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "audio", "sfx", "skill")
rng = np.random.default_rng(7)


def t_axis(duration):
    return np.arange(int(SR * duration)) / SR


def env(duration, attack=0.005, decay_power=2.0):
    t = t_axis(duration)
    a = np.clip(t / attack, 0.0, 1.0)
    d = (1.0 - t / duration) ** decay_power
    return a * d


def noise(duration):
    return rng.uniform(-1.0, 1.0, int(SR * duration))


def lowpass(signal, cutoff_hz):
    """One-pole lowpass; cutoff_hz có thể là số hoặc mảng (quét tần số theo thời gian)."""
    cutoff = np.broadcast_to(np.asarray(cutoff_hz, dtype=float), signal.shape)
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    out = np.empty_like(signal)
    y = 0.0
    for i, x in enumerate(signal):
        y += alpha[i] * (x - y)
        out[i] = y
    return out


def highpass(signal, cutoff_hz):
    return signal - lowpass(signal, cutoff_hz)


def sweep_sine(f0, f1, duration, shape=np.sin):
    t = t_axis(duration)
    freq = f0 * (f1 / f0) ** (t / duration)
    phase = 2.0 * np.pi * np.cumsum(freq) / SR
    return shape(phase)


def square(phase):
    return np.sign(np.sin(phase))


def saw(phase):
    return 2.0 * ((phase / (2.0 * np.pi)) % 1.0) - 1.0


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def whoosh(duration, f_start, f_end):
    t = t_axis(duration)
    cutoff = f_start * (f_end / f_start) ** (t / duration)
    bell = np.sin(np.pi * t / duration) ** 1.5
    return lowpass(highpass(noise(duration), 200), cutoff) * bell


def crackle(duration, density):
    n = int(SR * duration)
    out = np.zeros(n)
    hits = rng.random(n) < density / SR
    out[hits] = rng.uniform(-1, 1, hits.sum())
    return highpass(lowpass(out, 6000), 800) * 3.0


# ---------------- 6 hệ × (cast, hit) ----------------

def physical_cast():
    return whoosh(0.2, 600, 4000)


def physical_hit():
    d = 0.14
    thud = sweep_sine(140, 55, d) * env(d, 0.002, 3)
    click = highpass(noise(0.02), 1500) * env(0.02, 0.001, 2)
    return mix(thud, click * 0.6)


def fire_cast():
    d = 0.32
    return mix(whoosh(d, 300, 2200) * 1.2, crackle(d, 120) * env(d, 0.05, 1) * 0.5)


def fire_hit():
    d = 0.42
    body = lowpass(noise(d), np.linspace(3000, 300, int(SR * d))) * env(d, 0.003, 2.5)
    boom = sweep_sine(90, 38, d) * env(d, 0.003, 2)
    return mix(body * 1.6, boom, crackle(d, 60) * env(d, 0.01, 1.5) * 0.4)


def ice_cast():
    d = 0.28
    t = t_axis(d)
    vib = 1.0 + 0.01 * np.sin(2 * np.pi * 18 * t)
    tone = sum(np.sin(2 * np.pi * f * vib * t) for f in (1850, 2480, 3300)) / 3
    air = highpass(noise(d), 4000) * 0.35
    return (tone + air) * env(d, 0.01, 1.8)


def ice_hit():
    d = 0.3
    shards = highpass(noise(d), 3000) * env(d, 0.001, 4)
    pings = np.zeros(int(SR * d))
    for _ in range(6):
        start = rng.integers(0, int(SR * 0.12))
        pd = 0.12
        ping = np.sin(2 * np.pi * rng.uniform(2500, 5200) * t_axis(pd)) * env(pd, 0.001, 3)
        pings[start:start + len(ping)] += ping[: len(pings) - start] * 0.5
    return mix(shards, pings)


def lightning_cast():
    d = 0.16
    zap = sweep_sine(1400, 180, d, square) * 0.5
    fizz = highpass(noise(d), 2000) * 0.5
    return (zap + fizz) * env(d, 0.002, 1.5)


def lightning_hit():
    d = 0.28
    gate = np.repeat(rng.random(int(d * 400)) < 0.55, SR // 400)[: int(SR * d)]
    gate = np.pad(gate, (0, int(SR * d) - len(gate)))
    buzz = sweep_sine(120, 60, d, saw) * 0.4
    return (highpass(noise(d), 1000) * gate + buzz) * env(d, 0.001, 2)


def poison_cast():
    d = 0.26
    seg = int(SR * 0.03)
    freqs = np.repeat(rng.uniform(280, 720, int(SR * d) // seg + 1), seg)[: int(SR * d)]
    blub = np.sin(2 * np.pi * np.cumsum(freqs) / SR)
    return mix(blub * 0.7, lowpass(noise(d), 1500) * 0.4) * env(d, 0.02, 1.2)


def poison_hit():
    d = 0.3
    splat = lowpass(noise(d), 1800) * env(d, 0.002, 2.5) * 1.4
    blip = sweep_sine(500, 160, 0.12) * env(0.12, 0.002, 2) * 0.6
    hiss = highpass(noise(d), 5000) * env(d, 0.05, 1) * 0.25
    return mix(splat, blip, hiss)


def chaos_cast():
    d = 0.34
    a = sweep_sine(220, 80, d, saw)
    b = sweep_sine(226, 83, d, saw)
    ring = np.sin(2 * np.pi * 37 * t_axis(d))
    return lowpass((a + b) * 0.5 * (0.6 + 0.4 * ring), 2500) * env(d, 0.03, 1.2)


def chaos_hit():
    d = 0.4
    boom = sweep_sine(110, 30, d) * env(d, 0.002, 1.8)
    grit = lowpass(noise(d), 900) * env(d, 0.002, 3)
    return np.tanh((boom + grit) * 2.5)


SOUNDS = {
    "physical": (physical_cast, physical_hit),
    "fire": (fire_cast, fire_hit),
    "ice": (ice_cast, ice_hit),
    "lightning": (lightning_cast, lightning_hit),
    "poison": (poison_cast, poison_hit),
    "chaos": (chaos_cast, chaos_hit),
}


def write_wav(path, signal):
    peak = np.max(np.abs(signal)) or 1.0
    signal = signal / peak * 0.7  ## ~ -3dB, chừa headroom khi nhiều âm chồng nhau
    fade = min(len(signal), int(SR * 0.01))
    signal[-fade:] *= np.linspace(1.0, 0.0, fade)
    data = (signal * 32767).astype(np.int16)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(data.tobytes())


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    for element, (cast_fn, hit_fn) in SOUNDS.items():
        write_wav(os.path.join(OUT_DIR, f"{element}_cast.wav"), cast_fn())
        write_wav(os.path.join(OUT_DIR, f"{element}_hit.wav"), hit_fn())
        print("ok", element)
