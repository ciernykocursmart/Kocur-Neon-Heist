#!/usr/bin/env python3
"""Procedural audio for Kocur Kart.

Synthesises every sound effect, ambience loop and music track from scratch
(numpy), so the game ships only original audio. Output:
  assets/audio/sfx/*.wav       (16-bit mono, 22.05 kHz)
  assets/audio/amb/*.ogg       (mono Vorbis loops)
  assets/audio/music/*.ogg     (stereo Vorbis loops, bar-aligned)

Usage: python3 tools/audio/make_audio.py   (needs numpy + ffmpeg)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
AMB_DIR = os.path.join(ROOT, "assets", "audio", "amb")
MUS_DIR = os.path.join(ROOT, "assets", "audio", "music")
SR = 22050
MSR = 32000
rng = np.random.default_rng(1234)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def t_axis(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def env_adsr(n, a, d, s, r, sr=SR):
    a, d, r = int(a * sr), int(d * sr), int(r * sr)
    sus = max(n - a - d - r, 0)
    e = np.concatenate([
        np.linspace(0, 1, max(a, 1), endpoint=False),
        np.linspace(1, s, max(d, 1), endpoint=False),
        np.full(sus, s),
        np.linspace(s, 0, max(r, 1)),
    ])
    if len(e) < n:
        e = np.pad(e, (0, n - len(e)))
    return e[:n]


def env_exp(n, decay, sr=SR):
    return np.exp(-np.arange(n) / sr / decay)


def osc(freq, t, shape="sine", phase=0.0):
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(freq, t.shape)) / SR_CUR[0] + phase
    if shape == "sine":
        return np.sin(ph)
    if shape == "square":
        return np.sign(np.sin(ph)) * 0.8
    if shape == "saw":
        return 2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0
    if shape == "tri":
        return 2.0 * np.abs(2.0 * ((ph / (2 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(shape)


SR_CUR = [SR]


def lowpass(x, cutoff, sr=SR):
    a = np.exp(-2 * np.pi * cutoff / sr)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def onepole_fast(x, cutoff, sr=SR):
    """Vectorised-ish one-pole low-pass via scipy-free IIR (block loop)."""
    a = np.exp(-2 * np.pi * np.asarray(cutoff, dtype=float) / sr)
    y = np.empty_like(x)
    acc = 0.0
    if a.ndim == 0:
        b = 1 - float(a)
        af = float(a)
        for i in range(len(x)):
            acc = b * x[i] + af * acc
            y[i] = acc
    else:
        for i in range(len(x)):
            acc = (1 - a[i]) * x[i] + a[i] * acc
            y[i] = acc
    return y


def highpass(x, cutoff, sr=SR):
    return x - onepole_fast(x, cutoff, sr)


def bandpass(x, lo, hi, sr=SR):
    return onepole_fast(highpass(x, lo, sr), hi, sr)


def noise(n):
    return rng.uniform(-1, 1, n)


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def make_loop(x, fade, sr=SR):
    """Crossfade the tail into the head so the clip loops seamlessly."""
    f = int(fade * sr)
    head = x[:f].copy()
    tail = x[-f:].copy()
    ramp = np.linspace(0, 1, f)
    x = x[:-f].copy()
    x[:f] = head * ramp + tail * (1 - ramp)
    return x


LOOPS = {"engine", "drift"}


def write_wav(name, x, sr=SR):
    os.makedirs(SFX_DIR, exist_ok=True)
    x = np.clip(x, -1, 1)
    if name not in LOOPS:
        f = min(int(0.012 * sr), len(x))
        x = x.copy()
        x[-f:] *= np.linspace(1, 0, f)
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(SFX_DIR, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def write_ogg(folder, name, x, sr, quality=4):
    os.makedirs(folder, exist_ok=True)
    x = np.clip(x, -1, 1)
    stereo = x.ndim == 2
    data = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(2 if stereo else 1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.T.copy().tobytes() if stereo else data.tobytes())
    out = os.path.join(folder, name + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-c:a", "libvorbis", "-q:a", str(quality), out], check=True)
    os.remove(path)


def tone(freq, dur, shape="sine", a=0.005, d=0.05, s=0.6, r=0.1, sr=SR):
    SR_CUR[0] = sr
    t = t_axis(dur, sr)
    return osc(freq, t, shape) * env_adsr(len(t), a, d, s, r, sr)


# ---------------------------------------------------------------------------
# Sound effects
# ---------------------------------------------------------------------------

def sfx():
    SR_CUR[0] = SR
    # Engine: 1 s seamless loop, integer-Hz partials so it loops exactly.
    t = t_axis(1.0)
    f0 = 70
    x = np.zeros_like(t)
    for h, amp in [(1, 1.0), (2, 0.55), (3, 0.42), (4, 0.25), (5, 0.18), (6, 0.12), (8, 0.06)]:
        x += amp * np.sin(2 * np.pi * f0 * h * t + h * 0.7)
    chug = 0.75 + 0.25 * np.sin(2 * np.pi * 35 * t)
    x *= chug
    x = np.tanh(1.6 * x)
    rough = onepole_fast(noise(len(t)), 900) * 0.25
    x = x + rough
    x = make_loop(np.concatenate([x, x[: int(0.05 * SR)]]), 0.05)
    write_wav("engine", norm(x, 0.7))

    # Tyre squeal / drift loop.
    t = t_axis(1.2)
    n = bandpass(noise(len(t)), 1400, 3200) * 0.6
    whine = np.sin(2 * np.pi * (1650 + 60 * np.sin(2 * np.pi * 5 * t)) * t) * 0.35
    x = make_loop(n + whine, 0.1)
    write_wav("drift", norm(x, 0.55))

    # Drift charge chimes.
    for lvl, base in [(1, 880), (2, 1320)]:
        x = tone(base, 0.25, "sine", 0.002, 0.08, 0.3, 0.12) + 0.5 * tone(base * 1.5, 0.25, "tri", 0.002, 0.08, 0.2, 0.12)
        write_wav("spark%d" % lvl, norm(x, 0.6))

    # Mini-turbo and boosts.
    def whoosh(dur, f_from, f_to, color=(500, 4000), tonal=0.4):
        t = t_axis(dur)
        sweep = np.linspace(f_from, f_to, len(t))
        n = noise(len(t))
        cut = np.linspace(color[0], color[1], len(t))
        body = onepole_fast(n, cut) * 1.2
        tn = osc(sweep, t, "saw") * tonal
        e = env_adsr(len(t), 0.01, dur * 0.3, 0.6, dur * 0.6)
        return (body + tn) * e

    write_wav("boost_small", norm(whoosh(0.6, 200, 600, (800, 5000), 0.3), 0.8))
    write_wav("boost_big", norm(whoosh(1.0, 150, 700, (600, 6000), 0.45), 0.9))
    t = t_axis(1.4)
    purr = (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 26 * t))) * osc(np.linspace(90, 160, len(t)), t, "saw")
    purr = onepole_fast(purr, 1200) * env_adsr(len(t), 0.02, 0.4, 0.7, 0.6)
    write_wav("boost_purr", norm(whoosh(1.4, 120, 520, (500, 5000), 0.3) + purr * 0.9, 0.9))
    t = t_axis(0.5)
    zap = osc(np.linspace(300, 1800, len(t)), t, "square") * env_exp(len(t), 0.18)
    write_wav("pad", norm(onepole_fast(zap, 3000) + whoosh(0.5, 400, 900) * 0.5, 0.75))

    # Impacts.
    def thud(dur, f, noise_amt, decay, bright=1500):
        t = t_axis(dur)
        body = np.sin(2 * np.pi * np.linspace(f * 1.6, f, len(t)) * t) * env_exp(len(t), decay)
        hit = onepole_fast(noise(len(t)), bright) * env_exp(len(t), decay * 0.4) * noise_amt
        return body + hit

    write_wav("bump", norm(thud(0.3, 110, 1.2, 0.06, 2500), 0.85))
    write_wav("wall", norm(thud(0.45, 70, 1.8, 0.08, 1800) + 0.4 * thud(0.45, 230, 0.6, 0.03, 4000), 0.9))
    write_wav("land", norm(thud(0.35, 60, 0.8, 0.07, 900), 0.85))
    write_wav("jump", norm(whoosh(0.35, 300, 900, (1500, 6000), 0.2), 0.6))
    t = t_axis(0.6)
    boing = np.sin(2 * np.pi * (220 + 160 * np.sin(2 * np.pi * 9 * t) * np.exp(-t * 4)) * t) * env_exp(len(t), 0.25)
    write_wav("hazard", norm(boing + thud(0.6, 80, 1.0, 0.07) * 0.8, 0.85))

    # Race events.
    write_wav("count", norm(tone(523.25, 0.32, "square", 0.003, 0.05, 0.6, 0.08), 0.6))
    go = tone(1046.5, 0.7, "square", 0.003, 0.1, 0.6, 0.3) + 0.5 * tone(1568, 0.7, "sine", 0.003, 0.1, 0.5, 0.3)
    write_wav("go", norm(go, 0.7))

    def arp(notes, step, shape="tri", tail=0.25, amp=1.0):
        total = step * len(notes) + tail
        out = np.zeros(int(total * SR))
        for i, f in enumerate(notes):
            x = tone(f, step + tail, shape, 0.003, 0.06, 0.4, tail)
            st = int(i * step * SR)
            out[st:st + len(x)] += x * amp
        return out

    write_wav("lap", norm(arp([659.25, 783.99, 1046.5], 0.09), 0.6))
    write_wav("final_lap", norm(arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.08, "square"), 0.55))
    fin = arp([523.25, 659.25, 783.99, 1046.5], 0.11, "square", 0.6) + arp([261.6, 329.6, 392.0, 523.25], 0.11, "tri", 0.6) * 0.6
    write_wav("finish", norm(fin, 0.75))
    write_wav("record", norm(arp([1046.5, 1318.5, 1568, 2093], 0.06, "sine", 0.4), 0.55))
    fan = arp([392, 523.25, 659.25, 783.99, 659.25, 783.99, 1046.5], 0.13, "saw", 0.7)
    write_wav("fanfare", norm(onepole_fast(fan, 3500), 0.75))
    write_wav("unlock", norm(arp([783.99, 987.77, 1174.7, 1568], 0.07, "tri", 0.5), 0.6))
    t = t_axis(0.9)
    sparkle = np.zeros_like(t)
    for k in range(10):
        st = int(k * 0.07 * SR)
        x = tone(1200 + k * 140, 0.25, "sine", 0.002, 0.05, 0.2, 0.15)
        sparkle[st:st + len(x)] += x[: len(sparkle) - st]
    write_wav("respawn", norm(sparkle, 0.55))
    t = t_axis(0.5)
    buzz = osc(np.full(len(t), 140.0), t, "square") * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 8 * t)))
    write_wav("wrong_way", norm(onepole_fast(buzz, 1500) * env_adsr(len(t), 0.01, 0.1, 0.8, 0.1), 0.5))

    # UI.
    write_wav("ui_move", norm(tone(1200, 0.05, "sine", 0.001, 0.02, 0.3, 0.02), 0.35))
    write_wav("ui_select", norm(tone(880, 0.09, "tri", 0.001, 0.03, 0.4, 0.04) + tone(1320, 0.09, "sine", 0.02, 0.03, 0.3, 0.04), 0.5))
    write_wav("ui_back", norm(tone(520, 0.1, "tri", 0.001, 0.03, 0.4, 0.05), 0.45))
    write_wav("ui_pause", norm(arp([660, 440], 0.06, "tri", 0.1), 0.45))
    t = t_axis(2.5)
    cheer = bandpass(noise(len(t)), 400, 2600) * env_adsr(len(t), 0.3, 0.5, 0.7, 1.2)
    cheer *= 0.7 + 0.3 * np.sin(2 * np.pi * 3.3 * t + np.sin(2 * np.pi * 0.7 * t))
    write_wav("cheer", norm(cheer, 0.6))


# ---------------------------------------------------------------------------
# Ambience loops (10 s)
# ---------------------------------------------------------------------------

def ambience():
    SR_CUR[0] = SR
    dur = 10.5
    n = int(dur * SR)
    t = t_axis(dur)

    def chirps(count, f_lo, f_hi, length=0.12):
        out = np.zeros(n)
        for _ in range(count):
            st = rng.integers(0, n - int(0.4 * SR))
            f = rng.uniform(f_lo, f_hi)
            reps = rng.integers(2, 5)
            for r in range(reps):
                tt = t_axis(length)
                c = np.sin(2 * np.pi * (f + 900 * np.sin(np.pi * tt / length)) * tt) * np.sin(np.pi * tt / length) ** 2
                s0 = st + int(r * length * 1.3 * SR)
                out[s0:s0 + len(c)] += c[: max(0, min(len(c), n - s0))] * rng.uniform(0.3, 0.8)
        return out

    wind = onepole_fast(noise(n), 300) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.1 * t))
    birds = wind * 0.6 + chirps(26, 2200, 3600) * 0.25
    write_ogg(AMB_DIR, "birds", norm(make_loop(birds, 0.5), 0.5), SR)
    waves = onepole_fast(noise(n), 700) * (0.35 + 0.65 * np.sin(2 * np.pi * 0.19 * t) ** 2)
    gulls = chirps(5, 900, 1400, 0.25) * 0.25
    write_ogg(AMB_DIR, "sea", norm(make_loop(waves + gulls, 0.5), 0.5), SR)
    hum = onepole_fast(noise(n), 200) * 0.8 + np.sin(2 * np.pi * 60 * t) * 0.15 + np.sin(2 * np.pi * 120 * t) * 0.08
    zaps = chirps(4, 400, 700, 0.3) * 0.12
    write_ogg(AMB_DIR, "city", norm(make_loop(hum + zaps, 0.5), 0.5), SR)
    howl = bandpass(noise(n), 200, 900) * (0.4 + 0.6 * np.sin(2 * np.pi * 0.08 * t + 1) ** 2)
    write_ogg(AMB_DIR, "wind", norm(make_loop(howl, 0.5), 0.5), SR)
    crickets = np.sin(2 * np.pi * 4300 * t) * (np.sin(2 * np.pi * 28 * t) > 0.6) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.6 * t))
    sav = onepole_fast(noise(n), 400) * 0.5 + crickets * 0.15
    write_ogg(AMB_DIR, "savanna", norm(make_loop(sav, 0.5), 0.5), SR)
    murmur = bandpass(noise(n), 300, 1800) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.3 * t))
    write_ogg(AMB_DIR, "crowd", norm(make_loop(murmur, 0.5), 0.45), SR)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def chord_notes(name, octave=4):
    # name like "C", "Am", "F", "G7", "Dm"
    minor = name.endswith("m") and not name.endswith("maj")
    seventh = name.endswith("7")
    root = name.rstrip("m7")
    r = NOTE[root] + 12 * (octave + 1)
    third = 3 if minor else 4
    notes = [r, r + third, r + 7]
    if seventh:
        notes.append(r + 10)
    return notes


def drum_kit():
    SR_CUR[0] = MSR
    t = t_axis(0.35, MSR)
    kick = np.sin(2 * np.pi * np.cumsum(np.linspace(150, 45, len(t))) / MSR) * env_exp(len(t), 0.12, MSR)
    tn = t_axis(0.2, MSR)
    snare = (onepole_fast(noise(len(tn)), 5000, MSR) * 0.8 + np.sin(2 * np.pi * 190 * tn) * 0.4) * env_exp(len(tn), 0.06, MSR)
    th = t_axis(0.06, MSR)
    hat = highpass(noise(len(th)), 6000, MSR) * env_exp(len(th), 0.015, MSR)
    tc = t_axis(0.15, MSR)
    clap = bandpass(noise(len(tc)), 900, 3000, MSR) * env_exp(len(tc), 0.04, MSR)
    tb = t_axis(0.25, MSR)
    bongo = np.sin(2 * np.pi * np.linspace(320, 260, len(tb)) * tb) * env_exp(len(tb), 0.07, MSR)
    return {"kick": kick, "snare": snare, "hat": hat, "clap": clap, "bongo": bongo}


def voice(freq, dur, kind):
    SR_CUR[0] = MSR
    t = t_axis(dur, MSR)
    n = len(t)
    if kind == "pluck":
        x = osc(freq, t, "tri") + 0.3 * osc(freq * 2, t, "sine")
        return x * env_exp(n, 0.18, MSR) * env_adsr(n, 0.003, 0.01, 1.0, 0.03, MSR)
    if kind == "bell":
        x = osc(freq, t, "sine") + 0.4 * osc(freq * 2.76, t, "sine") + 0.2 * osc(freq * 5.4, t, "sine")
        return x * env_exp(n, 0.35, MSR)
    if kind == "marimba":
        x = osc(freq, t, "sine") + 0.25 * osc(freq * 4, t, "sine")
        return x * env_exp(n, 0.12, MSR)
    if kind == "saw_lead":
        x = osc(freq * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t)), t, "saw")
        return onepole_fast(x, 2600, MSR) * env_adsr(n, 0.01, 0.08, 0.7, 0.06, MSR)
    if kind == "square_lead":
        x = osc(freq, t, "square")
        return onepole_fast(x, 3000, MSR) * env_adsr(n, 0.005, 0.06, 0.6, 0.05, MSR)
    if kind == "brass":
        x = osc(freq, t, "saw") * 0.7 + osc(freq * 1.003, t, "saw") * 0.5
        cut = 600 + 2400 * env_adsr(n, 0.05, 0.2, 0.5, 0.1, MSR)
        return onepole_fast(x, cut, MSR) * env_adsr(n, 0.03, 0.1, 0.8, 0.08, MSR)
    if kind == "bass":
        x = osc(freq, t, "square") * 0.5 + osc(freq, t, "sine")
        return onepole_fast(x, 700, MSR) * env_adsr(n, 0.005, 0.1, 0.7, 0.04, MSR)
    if kind == "saw_bass":
        x = osc(freq, t, "saw")
        return onepole_fast(x, 900, MSR) * env_adsr(n, 0.003, 0.08, 0.6, 0.03, MSR)
    if kind == "pad":
        x = osc(freq, t, "saw") * 0.5 + osc(freq * 1.006, t, "saw") * 0.5
        return onepole_fast(x, 1400, MSR) * env_adsr(n, 0.15, 0.2, 0.7, 0.3, MSR)
    raise ValueError(kind)


STYLES = {
    "menu": {"bpm": 108, "chords": ["C", "Am", "F", "G", "C", "Am", "Dm", "G"], "lead": "pluck", "bass": "bass", "pad": True, "drums": "funk", "seed": 1, "oct": 5},
    "woods": {"bpm": 128, "chords": ["G", "D", "Em", "C", "G", "D", "C", "D"], "lead": "pluck", "bass": "bass", "pad": False, "drums": "pop", "seed": 2, "oct": 5},
    "pier": {"bpm": 120, "chords": ["F", "Bb", "C", "F", "Dm", "Bb", "C", "C"], "lead": "marimba", "bass": "bass", "pad": False, "drums": "calypso", "seed": 3, "oct": 5},
    "neon": {"bpm": 118, "chords": ["Am", "F", "C", "G", "Am", "F", "G", "Em"], "lead": "saw_lead", "bass": "saw_bass", "pad": True, "drums": "synth", "seed": 4, "oct": 5},
    "snow": {"bpm": 132, "chords": ["Dm", "Bb", "F", "C", "Dm", "Bb", "C", "A"], "lead": "bell", "bass": "bass", "pad": True, "drums": "pop", "seed": 5, "oct": 5},
    "safari": {"bpm": 124, "chords": ["Em", "C", "D", "Em", "Em", "G", "D", "B"], "lead": "marimba", "bass": "bass", "pad": False, "drums": "tribal", "seed": 6, "oct": 5},
    "royal": {"bpm": 136, "chords": ["Bb", "F", "Gm", "Eb", "Bb", "F", "Eb", "F"], "lead": "brass", "bass": "bass", "pad": True, "drums": "march", "seed": 7, "oct": 4},
}


def compose(style):
    s = STYLES[style]
    r = np.random.default_rng(s["seed"])
    beat = 60.0 / s["bpm"]
    bars = 16
    total = int(bars * 4 * beat * MSR)
    L = np.zeros(total)
    R = np.zeros(total)
    kit = drum_kit()

    def put(sig, start, pan=0.0, gain=1.0):
        st = int(start * MSR)
        if st >= total:
            return
        end = min(total, st + len(sig))
        seg = sig[: end - st] * gain
        L[st:end] += seg * (1 - max(pan, 0))
        R[st:end] += seg * (1 + min(pan, 0))

    chords = s["chords"]
    # Melody: a motif built from chord tones, repeated with variation.
    motif_rhythm = [0, 0.5, 1.0, 1.5, 2.0, 3.0, 3.5]
    motif_steps = list(r.integers(0, 3, len(motif_rhythm)))
    for bar in range(bars):
        ch = chords[bar % len(chords)]
        notes = chord_notes(ch, s["oct"])
        bstart = bar * 4 * beat
        # Bass.
        root = chord_notes(ch, 2)[0]
        pattern = [0, 1.5, 2, 3, 3.5] if s["drums"] in ("funk", "calypso") else [0, 1, 2, 3]
        for k, b in enumerate(pattern):
            m = root + (12 if (k % 3 == 2 and s["bass"] == "saw_bass") else 0)
            put(voice(midi_hz(m), beat * 0.9, s["bass"]), bstart + b * beat, 0.0, 0.5)
        # Pad.
        if s["pad"]:
            for m in notes:
                put(voice(midi_hz(m - 12), 4 * beat, "pad"), bstart, r.uniform(-0.3, 0.3), 0.12)
        else:
            for i in range(8):
                m = notes[i % 3] - 12 + (12 if i % 4 == 3 else 0)
                put(voice(midi_hz(m), beat * 0.5, "pluck"), bstart + i * beat * 0.5, -0.4 if i % 2 else 0.4, 0.16)
        # Lead: silent first 2 bars, then motif with variations.
        if bar >= 2:
            vary = (bar // 4) % 2 == 1
            for i, b in enumerate(motif_rhythm):
                if vary and i == len(motif_rhythm) - 1:
                    continue
                step = motif_steps[i] + (1 if vary and i % 2 == 0 else 0)
                m = notes[step % 3] + (12 if step >= 3 else 0)
                dur = beat * (0.45 if i < len(motif_rhythm) - 1 else 0.9)
                put(voice(midi_hz(m), dur + 0.1, s["lead"]), bstart + b * beat, 0.1, 0.28)
        # Drums.
        d = s["drums"]
        for b8 in range(8):
            tt = bstart + b8 * beat * 0.5
            on_beat = b8 % 2 == 0
            if d == "march":
                if b8 in (0, 4):
                    put(kit["kick"], tt, 0, 0.8)
                if b8 in (2, 6):
                    put(kit["snare"], tt, 0, 0.55)
                if b8 % 2 == 1:
                    put(kit["snare"], tt, 0.2, 0.18)
            elif d == "tribal":
                if b8 in (0, 3, 6):
                    put(kit["kick"], tt, 0, 0.7)
                put(kit["bongo"], tt, -0.5 if b8 % 2 else 0.5, 0.35 if on_beat else 0.25)
            else:
                if b8 in (0, 4) or (d == "funk" and b8 == 5) or (d == "calypso" and b8 == 3):
                    put(kit["kick"], tt, 0, 0.8)
                if b8 in (2, 6):
                    put(kit["clap"] if d in ("synth", "calypso") else kit["snare"], tt, 0, 0.5)
                put(kit["hat"], tt, 0.3, 0.22 if on_beat else 0.14)
                if d == "synth":
                    put(kit["hat"], tt + beat * 0.25, -0.3, 0.08)
    mix = np.stack([L, R])
    mix = np.tanh(mix * 1.2)
    return norm(mix, 0.85)


def music():
    for style in STYLES:
        print("  music:", style)
        write_ogg(MUS_DIR, style, compose(style), MSR, quality=3)


if __name__ == "__main__":
    print("Generating sfx...")
    sfx()
    print("Generating ambience...")
    ambience()
    print("Generating music...")
    music()
    print("Done.")
