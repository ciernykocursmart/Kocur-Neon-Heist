#!/usr/bin/env python3
"""Synthesises every sound effect and music loop of Streets of Kocur.

All audio is original and generated from code (numpy): no samples, no
third-party material. Output: assets/audio/*.wav (22.05 kHz, 16-bit mono).
Run from the project root:  python3 tools/gen_audio.py
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1234)


def t_arr(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, total=None):
    """Attack/decay/sustain/release envelope over n samples."""
    e = np.zeros(n)
    ai = max(1, int(a * SR))
    di = max(1, int(d * SR))
    ri = max(1, int(r * SR))
    e[:ai] = np.linspace(0, 1, ai)[: n]
    end_d = min(n, ai + di)
    if end_d > ai:
        e[ai:end_d] = np.linspace(1, s, end_d - ai)
    if end_d < n:
        e[end_d:] = s
    if s > 0 and n > ri:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def expdec(n, k):
    return np.exp(-np.arange(n) / SR * k)


def sine_sweep(f0, f1, dur, curve=1.0):
    t = t_arr(dur)
    f = f0 + (f1 - f0) * (t / dur) ** curve
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def square(freq, dur, duty=0.5):
    t = t_arr(dur)
    ph = (t * freq) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def square_sweep(f0, f1, dur, duty=0.5):
    t = t_arr(dur)
    f = np.linspace(f0, f1, len(t))
    ph = np.cumsum(f) / SR % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tri(freq, dur):
    t = t_arr(dur)
    ph = (t * freq) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def saw(freq, dur):
    t = t_arr(dur)
    return 2 * ((t * freq) % 1.0) - 1


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    """One-pole low-pass (cutoff may be an array)."""
    y = np.zeros_like(x)
    c = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * c / SR)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def pad(x, dur):
    n = int(SR * dur)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def norm(x, peak=0.85):
    m = np.max(np.abs(x)) if len(x) else 0
    return x * (peak / m) if m > 0 else x


def write(name, x, peak=0.85):
    x = norm(np.asarray(x, dtype=float), peak)
    # tiny fade at the edges to avoid clicks
    f = min(64, len(x) // 4)
    if f > 0:
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def note_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------------------------------------------------------------- SFX
def sfx():
    write("ui_move", square(880, 0.04, 0.25) * expdec(int(SR * 0.04), 60), 0.4)
    write("ui_ok", np.concatenate([square(660, 0.05, 0.25), square(990, 0.08, 0.25) * expdec(int(SR * 0.08), 30)]), 0.45)
    write("ui_back", np.concatenate([square(700, 0.05, 0.25), square(470, 0.08, 0.25) * expdec(int(SR * 0.08), 30)]), 0.4)
    n = int(SR * 0.07)
    write("jab", mix(lowpass(noise(0.07), 3000) * expdec(n, 70), sine_sweep(260, 120, 0.07) * expdec(n, 50) * 0.8), 0.6)
    n = int(SR * 0.11)
    write("swipe", highpass(noise(0.11), 900) * np.sin(np.linspace(0, np.pi, n)) ** 2 * 0.9 + sine_sweep(300, 140, 0.11) * expdec(n, 40) * 0.5, 0.6)
    n = int(SR * 0.18)
    write("heavy", mix(sine_sweep(160, 45, 0.18) * expdec(n, 18), lowpass(noise(0.18), 1800) * expdec(n, 35) * 0.7), 0.85)
    n = int(SR * 0.13)
    write("whoosh", lowpass(noise(0.13), np.linspace(600, 2500, n)) * np.sin(np.linspace(0, np.pi, n)), 0.35)
    n = int(SR * 0.1)
    write("hit", mix(lowpass(noise(0.03), 4000) * expdec(int(SR * 0.03), 90), sine_sweep(200, 80, 0.1) * expdec(n, 35)), 0.75)
    n = int(SR * 0.26)
    write("hit_heavy", mix(sine_sweep(140, 35, 0.26) * expdec(n, 12), lowpass(noise(0.12), 2500) * expdec(int(SR * 0.12), 30),
                           np.sign(sine_sweep(90, 40, 0.26)) * expdec(n, 25) * 0.25), 0.9)
    n = int(SR * 0.6)
    whirl = square_sweep(200, 900, 0.6, 0.3) * np.linspace(0.2, 1, n) * 0.25
    boom = pad(np.zeros(int(SR * 0.18)), 0.18)
    boom = np.concatenate([boom, sine_sweep(120, 30, 0.42) * expdec(int(SR * 0.42), 8) + lowpass(noise(0.42), 1200) * expdec(int(SR * 0.42), 12) * 0.6])
    write("special", mix(whirl * np.linspace(1, 0, n), boom), 0.9)
    n = int(SR * 0.35)
    write("enemy_ko", mix(square_sweep(520, 120, 0.35, 0.4) * expdec(n, 7) * 0.4, sine_sweep(100, 40, 0.2) * expdec(int(SR * 0.2), 15)), 0.7)
    n = int(SR * 0.22)
    write("hurt", mix(sine_sweep(700, 280, 0.22) * env(n, 0.005, 0.2, 0.0, 0.02) * 0.7, lowpass(noise(0.08), 3000) * expdec(int(SR * 0.08), 40)), 0.7)
    n = int(SR * 0.12)
    write("jump", square_sweep(220, 620, 0.12, 0.25) * expdec(n, 12) * 0.5, 0.45)
    n = int(SR * 0.08)
    write("land", mix(sine_sweep(110, 50, 0.08) * expdec(n, 40), lowpass(noise(0.06), 800) * expdec(int(SR * 0.06), 50) * 0.6), 0.55)
    notes = [72, 76, 79, 84]
    write("food", np.concatenate([tri(note_hz(m), 0.06) * expdec(int(SR * 0.06), 15) for m in notes] + [tri(note_hz(88), 0.18) * expdec(int(SR * 0.18), 12)]), 0.6)
    write("score", np.concatenate([square(note_hz(83), 0.06, 0.25), square(note_hz(88), 0.25, 0.25) * expdec(int(SR * 0.25), 12)]), 0.4)
    write("combo", np.concatenate([square(note_hz(m), 0.045, 0.125) * expdec(int(SR * 0.045), 20) for m in [76, 79, 83, 88, 91]]), 0.4)
    n = int(SR * 0.12)
    write("grab", mix(lowpass(noise(0.12), 1500) * expdec(n, 25), sine_sweep(180, 90, 0.12) * expdec(n, 30) * 0.6), 0.6)
    n = int(SR * 0.3)
    write("throw_body", mix(lowpass(noise(0.3), np.linspace(400, 2000, n)) * np.sin(np.linspace(0, np.pi, n)), sine_sweep(400, 200, 0.3) * 0.15), 0.6)
    n = int(SR * 0.2)
    write("bottle", sine_sweep(1400, 900, 0.2) * np.sin(np.linspace(0, np.pi, n)) * 0.6 + highpass(noise(0.2), 2000) * 0.15, 0.4)
    n = int(SR * 0.35)
    gl = highpass(noise(0.35), 3000) * expdec(n, 14)
    for f in [2400, 3700, 5100]:
        gl += np.sin(2 * np.pi * f * t_arr(0.35)) * expdec(n, 20) * 0.3
    write("glass", gl, 0.55)
    n = int(SR * 0.25)
    write("crate", mix(lowpass(noise(0.25), 1600) * expdec(n, 18), np.sin(2 * np.pi * 310 * t_arr(0.25)) * expdec(n, 25) * 0.5,
                       np.sin(2 * np.pi * 190 * t_arr(0.25)) * expdec(n, 20) * 0.4), 0.7)
    n = int(SR * 0.35)
    buzz = saw(60, 0.35) * 0.5 + saw(121, 0.35) * 0.3
    crack = (rng.uniform(0, 1, n) > 0.985).astype(float) * rng.uniform(-1, 1, n)
    write("electric", (buzz + lowpass(crack, 5000) * 4) * env(n, 0.01, 0.3, 0.6, 0.05), 0.55)
    n = int(SR * 0.5)
    metal = sum(np.sin(2 * np.pi * f * t_arr(0.5)) * expdec(n, k) * a for f, k, a in [(180, 9, 1), (433, 12, 0.6), (871, 16, 0.4), (1290, 20, 0.3)])
    write("press", mix(sine_sweep(90, 30, 0.3) * expdec(int(SR * 0.3), 12) * 1.5, metal * 0.5, lowpass(noise(0.1), 2000) * expdec(int(SR * 0.1), 40)), 0.9)
    n = int(SR * 0.9)
    t = t_arr(0.9)
    vib = np.sin(2 * np.pi * 7 * t) * 6
    f = np.linspace(110, 80, n) + vib
    growl = (2 * ((np.cumsum(f) / SR) % 1.0) - 1) * env(n, 0.05, 0.3, 0.7, 0.3)
    write("boss_roar", lowpass(growl + lowpass(noise(0.9), 700) * 0.6, 1400) * env(n, 0.05, 0.3, 0.8, 0.3), 0.85)
    n = int(SR * 0.6)
    write("boss_slam", mix(sine_sweep(100, 25, 0.6) * expdec(n, 6) * 1.2, lowpass(noise(0.6), 900) * expdec(n, 9), metal[:n] * 0.2), 0.95)
    n = int(SR * 0.8)
    write("boss_roll", lowpass(noise(0.8), 300) * (0.6 + 0.4 * np.sin(2 * np.pi * 12 * t_arr(0.8))) * env(n, 0.1, 0.3, 0.8, 0.2) + sine_sweep(50, 70, 0.8) * 0.4, 0.8)
    n = int(SR * 0.45)
    boing = np.sin(2 * np.pi * np.cumsum(180 + 120 * np.sin(2 * np.pi * 9 * t_arr(0.45)) * expdec(n, 4)) / SR) * expdec(n, 5)
    write("boss_bounce", boing, 0.7)
    n = int(SR * 0.18)
    write("boss_hit", mix(sine_sweep(110, 50, 0.18) * expdec(n, 18), lowpass(noise(0.1), 1800) * expdec(int(SR * 0.1), 35) * 0.7), 0.8)
    write("warn", np.concatenate([square(988, 0.08, 0.5) * 0.5, np.zeros(int(SR * 0.03)), square(740, 0.1, 0.5) * expdec(int(SR * 0.1), 10) * 0.5]), 0.4)
    write("level_clear", jingle([(72, 1), (76, 1), (79, 1), (84, 2), (79, 1), (84, 3)], 0.11), 0.6)
    write("victory", jingle([(67, 1), (72, 1), (76, 1), (79, 2), (76, 1), (79, 1), (84, 4), (83, 1), (84, 6)], 0.13, bass=True), 0.65)
    write("gameover", jingle([(72, 2), (71, 2), (70, 2), (69, 2), (60, 6)], 0.18, duty=0.5), 0.55)
    write("life", jingle([(76, 1), (79, 1), (88, 1), (84, 1), (86, 1), (91, 3)], 0.07), 0.5)
    write("checkpoint", jingle([(79, 1), (84, 2)], 0.09), 0.45)
    # meow: two-formant voice gliding up then down
    n = int(SR * 0.45)
    t = t_arr(0.45)
    f0 = 420 + 380 * np.sin(np.pi * np.clip(t / 0.45, 0, 1)) ** 1.5
    ph = np.cumsum(f0) / SR
    voice = sum(np.sin(2 * np.pi * ph * h) / h for h in range(1, 8))
    form = np.sin(2 * np.pi * 900 * t) * 0.3 + 1
    write("meow", voice * form * env(n, 0.03, 0.2, 0.6, 0.15), 0.55)
    n = int(SR * 0.35)
    write("hiss", highpass(noise(0.35), 3000) * env(n, 0.02, 0.1, 0.7, 0.15), 0.4)
    n = int(SR * 0.16)
    write("dash", lowpass(noise(0.16), np.linspace(3000, 600, n)) * expdec(n, 12), 0.55)
    n = int(SR * 0.7)
    write("phase", mix(square_sweep(300, 900, 0.4, 0.5) * np.linspace(0.6, 0, int(SR * 0.4)) * 0.4,
                       np.concatenate([np.zeros(int(SR * 0.3)), sine_sweep(110, 30, 0.4) * expdec(int(SR * 0.4), 8)])), 0.85)


def jingle(seq, step, duty=0.25, bass=False):
    out = []
    for m, l in seq:
        d = step * l
        n = int(SR * d)
        s = square(note_hz(m), d, duty) * 0.5 + tri(note_hz(m), d) * 0.5
        if bass:
            s += tri(note_hz(m - 24), d) * 0.6
        out.append(s * env(n, 0.005, d * 0.6, 0.5, 0.03))
    return np.concatenate(out)


# ---------------------------------------------------------------- music
class Song:
    def __init__(self, bpm, bars, steps=16):
        self.bpm = bpm
        self.step = 60.0 / bpm / 4.0
        self.bars = bars
        self.n = int(round(self.step * steps * bars * SR))
        self.buf = np.zeros(self.n + SR * 2)

    def at(self, step):
        return int(round(step * self.step * SR))

    def add(self, step, sig, vol=1.0):
        i = self.at(step)
        self.buf[i: i + len(sig)] += sig * vol

    def render(self):
        out = self.buf[: self.n].copy()
        tail = self.buf[self.n:]
        out[: len(tail)] += tail[: len(out)]  # wrap tails so the loop is seamless
        return out


def inst(kind, m, dur):
    f = note_hz(m)
    n = int(SR * dur)
    if kind == "lead":
        s = square(f, dur, 0.25) * 0.6 + square(f * 1.005, dur, 0.25) * 0.4
        return s * env(n, 0.005, 0.08, 0.6, 0.04)
    if kind == "lead2":
        s = square(f, dur, 0.5) * 0.5 + tri(f * 2, dur) * 0.3
        return s * env(n, 0.005, 0.12, 0.5, 0.05)
    if kind == "saw":
        s = lowpass(saw(f, dur) + saw(f * 1.008, dur), 2500)
        return s * env(n, 0.01, 0.15, 0.5, 0.05) * 0.5
    if kind == "bass":
        return tri(f, dur) * env(n, 0.005, 0.1, 0.8, 0.03) + square(f, dur, 0.5) * 0.15 * env(n, 0.005, 0.05, 0.3, 0.03)
    if kind == "pad":
        s = sum(tri(f * k, dur) / k for k in [1, 2]) + saw(f * 0.5, dur) * 0.15
        return lowpass(s, 1200) * env(n, 0.08, 0.2, 0.7, 0.2) * 0.5
    if kind == "bell":
        return (np.sin(2 * np.pi * f * t_arr(dur)) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t_arr(dur))) * expdec(n, 6)
    raise ValueError(kind)


def drum(kind):
    if kind == "k":
        n = int(SR * 0.16)
        return sine_sweep(140, 40, 0.16) * expdec(n, 20)
    if kind == "s":
        n = int(SR * 0.14)
        return lowpass(noise(0.14), 6000) * expdec(n, 25) * 0.7 + sine_sweep(220, 160, 0.14) * expdec(n, 30) * 0.4
    if kind == "h":
        n = int(SR * 0.04)
        return highpass(noise(0.04), 6000) * expdec(n, 80) * 0.5
    if kind == "o":
        n = int(SR * 0.16)
        return highpass(noise(0.16), 5000) * expdec(n, 18) * 0.4
    if kind == "m":  # metal clank for industrial
        n = int(SR * 0.12)
        return sum(np.sin(2 * np.pi * f * t_arr(0.12)) * expdec(n, 30) for f in [520, 1230, 1870]) * 0.4
    raise ValueError(kind)


CHORD = {"m": [0, 3, 7], "M": [0, 4, 7], "m7": [0, 3, 7, 10], "M7": [0, 4, 7, 11], "7": [0, 4, 7, 10], "sus": [0, 5, 7]}


def compose(name, bpm, root, prog, scale, lead="lead", drums="rock", seed=0, bars=16, pad_on=False, swing=0.0):
    r = np.random.default_rng(seed)
    song = Song(bpm, bars)
    beat_patterns = {
        "rock": {"k": [0, 8, 10], "s": [4, 12], "h": [0, 2, 4, 6, 8, 10, 12, 14]},
        "four": {"k": [0, 4, 8, 12], "s": [4, 12], "h": [2, 6, 10, 14], "o": [14]},
        "funk": {"k": [0, 3, 8, 11], "s": [4, 12], "h": list(range(16))},
        "march": {"k": [0, 8], "s": [4, 12, 14, 15], "h": [0, 4, 8, 12]},
        "drive": {"k": [0, 4, 6, 8, 12, 14], "s": [4, 12], "h": list(range(0, 16, 2)), "o": [6]},
        "metal": {"k": [0, 6, 8, 14], "s": [4, 12], "m": [2, 10], "h": list(range(0, 16, 2))},
        "soft": {"k": [0, 8], "s": [12], "h": [4, 12]},
    }
    pat = beat_patterns[drums]
    # Two melodic phrases (A, B) over 4 bars each, arranged A A B A.
    phrases = []
    for p in range(2):
        notes = []
        rhythm = [0, 2, 3, 4, 6, 8, 10, 11, 12, 14] if p == 0 else [0, 3, 6, 8, 10, 12, 13, 14]
        cur = 0
        for bar in range(4):
            ch = prog[bar % len(prog)]
            for s in rhythm:
                if r.random() < 0.18:
                    continue
                tones = [(ch[0] + i) for i in CHORD[ch[1]]]
                if r.random() < 0.6:
                    target = tones[r.integers(len(tones))]
                    cand = [x for x in scale if x % 12 == target % 12] or scale
                else:
                    cand = scale
                cur = min(cand, key=lambda x: abs(x - cur) + r.random() * 4)
                ln = 2 if s in (2, 10, 14) else (3 if r.random() < 0.3 else 2)
                notes.append((bar * 16 + s, cur, ln))
        phrases.append(notes)
    order = [0, 0, 1, 0]
    for bar in range(bars):
        ch = prog[bar % len(prog)]
        base = root + ch[0]
        bstep = bar * 16
        # drums (fill on every 4th bar)
        for k, steps in pat.items():
            for s in steps:
                sw = swing if s % 2 == 1 else 0.0
                song.add(bstep + s + sw, drum(k), 0.5 if k == "k" else 0.35)
        if bar % 4 == 3:
            for s in [13, 14, 15]:
                song.add(bstep + s, drum("s"), 0.3)
        # bass
        bass_pat = [0, 3, 6, 8, 11, 14] if drums in ("funk", "drive") else [0, 4, 8, 10, 12]
        for i, s in enumerate(bass_pat):
            m = base - 24 + (12 if i % 3 == 2 else 0) + (7 if i == len(bass_pat) - 1 else 0)
            song.add(bstep + s, inst("bass", m, song.step * 2), 0.55)
        # pad / chord stabs
        tones = [base + i for i in CHORD[ch[1]]]
        if pad_on:
            for m in tones:
                song.add(bstep, inst("pad", m - 12, song.step * 16), 0.22)
        else:
            for s in [2, 6, 10, 14]:
                for m in tones:
                    song.add(bstep + s, inst("lead2", m, song.step * 1), 0.06)
    # melody
    for sec in range(bars // 4):
        ph = phrases[order[sec % 4]]
        for (s, m, ln) in ph:
            sw = swing if s % 2 == 1 else 0.0
            song.add(sec * 64 + s + sw, inst(lead, root + 12 + m, song.step * ln * 0.95), 0.2)
    write("music_" + name, song.render(), 0.8)


def music():
    minor = [0, 2, 3, 5, 7, 8, 10, 12, 14, 15, 17, 19]
    major = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19]
    dorian = [0, 2, 3, 5, 7, 9, 10, 12, 14, 15, 17, 19]
    compose("menu", 116, 57, [(0, "m7"), (8, "M7"), (3, "M"), (10, "7")], minor, "saw", "four", 1, 8, pad_on=True)
    compose("alley", 132, 52, [(0, "m7"), (5, "7"), (0, "m7"), (7, "m")], dorian, "lead", "funk", 2, swing=0.3)
    compose("market", 140, 60, [(0, "M"), (5, "M"), (7, "M"), (0, "M")], major, "lead2", "rock", 3)
    compose("neon", 118, 54, [(0, "m"), (8, "M"), (3, "M"), (10, "M")], minor, "saw", "four", 4, pad_on=True)
    compose("industrial", 128, 50, [(0, "m"), (0, "m"), (10, "M"), (8, "M")], minor, "lead", "metal", 5)
    compose("hq", 136, 55, [(0, "m"), (8, "M"), (5, "m"), (7, "7")], minor, "lead2", "march", 6)
    compose("boss", 152, 48, [(0, "m"), (1, "M"), (0, "m"), (7, "7")], minor, "lead", "drive", 7)
    compose("final", 158, 46, [(0, "m"), (8, "M"), (10, "M"), (7, "sus")], minor, "saw", "drive", 8, pad_on=True)
    compose("ending", 100, 53, [(0, "M7"), (5, "M7"), (2, "m7"), (7, "7")], major, "lead2", "soft", 9, 8, pad_on=True)


if __name__ == "__main__":
    sfx()
    music()
    print("audio written to", os.path.abspath(OUT))
