"""Synthesises every sound effect and music loop for Kocur Dungeon.

Usage (from the kocur-dungeon folder):  python3 tools/gen_audio.py
Output: assets/audio/*.wav (22.05 kHz, 16-bit mono). All audio is original,
generated from simple oscillators, noise and envelopes by this script.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)


def write(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) if len(x) else 1.0
    if m > 0:
        x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.0, total=None):
    """Simple attack/decay envelope over n samples."""
    a_n = max(1, int(a * SR))
    e = np.ones(n)
    e[:a_n] = np.linspace(0, 1, a_n)
    rest = n - a_n
    if rest > 0:
        e[a_n:] = s + (1 - s) * np.exp(-np.arange(rest) / max(1, d * SR))
    return e


def osc(freq, dur, kind='square', duty=0.5):
    t = t_(dur)
    if np.isscalar(freq):
        ph = freq * t
    else:
        ph = np.cumsum(freq) / SR
    ph = ph % 1.0
    if kind == 'square':
        return np.where(ph < duty, 1.0, -1.0)
    if kind == 'tri':
        return 4 * np.abs(ph - 0.5) - 1
    if kind == 'saw':
        return 2 * ph - 1
    return np.sin(2 * np.pi * ph)


def noise(dur):
    return RNG.uniform(-1, 1, int(SR * dur))


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def lp_fast(x, k):
    """Cheap moving-average low pass (k samples)."""
    if k <= 1:
        return x
    c = np.convolve(x, np.ones(k) / k, mode='same')
    return c


def sweep(f0, f1, dur, curve=1.0):
    n = int(SR * dur)
    return f0 + (f1 - f0) * (np.linspace(0, 1, n) ** curve)


def pad(x, dur):
    n = int(SR * dur)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mixl(*xs):
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[:len(x)] += x
    return out


def delay(x, ms, fb=0.3, mix=0.3):
    d = int(SR * ms / 1000)
    y = np.copy(x)
    out = np.concatenate([y, np.zeros(d * 4)])
    for k in range(1, 4):
        out[d * k:d * k + len(x)] += x * (fb ** k) * mix * 3
    return out


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

def sfx():
    # claw swipe: filtered noise with fast downward sweep
    d = 0.14
    n = noise(d) * env(int(SR * d), 0.002, 0.04)
    write('claw', lp_fast(n, 3) + 0.3 * osc(sweep(1200, 300, d), d, 'sine') * env(int(SR * d), 0.001, 0.03), 0.6)
    # claw hit: punchy thud + crunch
    d = 0.16
    th = osc(sweep(220, 60, d, 0.5), d, 'sine') * env(int(SR * d), 0.001, 0.05)
    cr = lp_fast(noise(d), 2) * env(int(SR * d), 0.001, 0.025)
    write('hit', th + 0.6 * cr, 0.8)
    # pounce
    d = 0.25
    n = lp_fast(noise(d), 4) * env(int(SR * d), 0.01, 0.08)
    write('pounce', n + 0.4 * osc(sweep(300, 900, d), d, 'tri') * env(int(SR * d), 0.005, 0.08), 0.6)
    # jump, land
    d = 0.12
    write('jump', osc(sweep(300, 620, d, 0.6), d, 'square', 0.25) * env(int(SR * d), 0.002, 0.05) * 0.5, 0.35)
    d = 0.1
    write('land', lp_fast(noise(d), 8) * env(int(SR * d), 0.001, 0.03), 0.35)
    # player hurt: descending pulse + noise
    d = 0.3
    write('hurt', osc(sweep(700, 180, d), d, 'square', 0.3) * env(int(SR * d), 0.002, 0.12) +
          0.4 * lp_fast(noise(d), 3) * env(int(SR * d), 0.001, 0.05), 0.7)
    # death: sad descending triad
    notes = [523, 415, 330, 247]
    parts = [osc(f, 0.18, 'square', 0.4) * env(int(SR * 0.18), 0.005, 0.12) for f in notes]
    write('death', delay(np.concatenate(parts), 120), 0.6)
    # enemy hurt / die / attack
    d = 0.12
    write('enemy_hurt', osc(sweep(500, 250, d), d, 'square', 0.5) * env(int(SR * d), 0.001, 0.05) * 0.6 +
          0.5 * lp_fast(noise(d), 2) * env(int(SR * d), 0.001, 0.02), 0.6)
    d = 0.4
    write('enemy_die', lp_fast(noise(d), 6) * env(int(SR * d), 0.005, 0.15) +
          0.5 * osc(sweep(600, 100, d), d, 'square', 0.5) * env(int(SR * d), 0.005, 0.12), 0.65)
    d = 0.2
    write('swing', lp_fast(noise(d), 2) * env(int(SR * d), 0.03, 0.06), 0.45)
    # telegraph warning ping
    d = 0.2
    write('warn', osc(880, d, 'square', 0.5) * env(int(SR * d), 0.002, 0.06) +
          osc(1320, d, 'square', 0.5) * env(int(SR * d), 0.002, 0.04) * 0.5, 0.45)
    # arrow twang + whoosh
    d = 0.25
    write('arrow', osc(sweep(420, 380, d), d, 'saw') * env(int(SR * d), 0.001, 0.07) * 0.6 +
          lp_fast(noise(d), 2) * env(int(SR * d), 0.001, 0.03) * 0.4, 0.5)
    # magic sparkle
    d = 0.4
    f = 900 + 400 * np.sin(np.linspace(0, 30, int(SR * d)))
    write('magic', osc(f, d, 'sine') * env(int(SR * d), 0.02, 0.15) + 0.3 * osc(f * 1.5, d, 'tri') * env(int(SR * d), 0.02, 0.1), 0.5)
    # fire whoosh
    d = 0.5
    write('fire', lp_fast(noise(d), 5) * env(int(SR * d), 0.05, 0.2), 0.55)
    # ice crystal
    d = 0.35
    write('ice', osc(sweep(2400, 1600, d), d, 'sine') * env(int(SR * d), 0.001, 0.1) +
          0.5 * osc(3100, d, 'sine') * env(int(SR * d), 0.001, 0.05), 0.45)
    # beast roar / boss roar
    for name, base, dur in [('roar', 120, 0.7), ('boss_roar', 80, 1.1)]:
        tt = t_(dur)
        f = base + 30 * np.sin(tt * 40) + sweep(40, -20, dur)
        x = osc(f, dur, 'saw') * 0.6 + lp_fast(noise(dur), 4) * 0.5
        write(name, lp_fast(x, 3) * env(len(tt), 0.08, dur * 0.5), 0.75)
    # slam / boom
    d = 0.6
    write('slam', osc(sweep(120, 35, d, 0.4), d, 'sine') * env(int(SR * d), 0.001, 0.2) +
          lp_fast(noise(d), 10) * env(int(SR * d), 0.001, 0.12) * 0.8, 0.9)
    # phase transition: big chord + boom
    d = 1.2
    ch = sum(osc(f, d, 'saw') for f in [110, 165, 220, 277]) * env(int(SR * d), 0.02, 0.5) * 0.3
    write('phase', lp_fast(ch, 3) + osc(sweep(90, 30, d), d, 'sine') * env(int(SR * d), 0.001, 0.4), 0.85)
    # coin / gem / heal / checkpoint / secret / rescue / level complete
    d = 0.09
    a = osc(988, d, 'square', 0.5) * env(int(SR * d), 0.001, 0.05)
    b = osc(1319, 0.16, 'square', 0.5) * env(int(SR * 0.16), 0.001, 0.08)
    write('coin', np.concatenate([a, b]) * 0.5, 0.35)
    notes = [784, 988, 1175, 1568]
    write('gem', delay(np.concatenate([osc(f, 0.07, 'tri') * env(int(SR * 0.07), 0.001, 0.05) for f in notes]), 90), 0.5)
    notes = [523, 659, 784, 1047]
    write('heal', delay(np.concatenate([osc(f, 0.08, 'sine') * env(int(SR * 0.08), 0.005, 0.07) for f in notes]), 70), 0.5)
    d = 0.9
    ch = sum(osc(f, d, 'tri') * env(int(SR * d), 0.01, 0.35) for f in [523, 659, 784])
    write('checkpoint', delay(ch, 150), 0.5)
    notes = [392, 466, 587, 740, 880]
    write('secret', delay(np.concatenate([osc(f, 0.1, 'square', 0.3) * env(int(SR * 0.1), 0.002, 0.08) for f in notes]), 110), 0.45)
    # meow (formant-ish sweep) for rescue
    d = 0.5
    f = np.concatenate([sweep(500, 900, d * 0.4), sweep(900, 600, d * 0.6)])
    m = osc(f, d, 'saw') * env(int(SR * d), 0.03, 0.25)
    m = lp_fast(m, 3) + 0.3 * osc(f * 2, d, 'sine') * env(int(SR * d), 0.03, 0.2)
    write('meow', m, 0.6)
    notes = [659, 784, 1047, 1319, 1047, 1319, 1568]
    jing = np.concatenate([osc(f, 0.1, 'square', 0.25) * env(int(SR * 0.1), 0.002, 0.08) for f in notes])
    write('rescue', delay(jing, 100), 0.5)
    notes = [523, 659, 784, 1047, 784, 1047]
    lens = [0.1, 0.1, 0.1, 0.25, 0.1, 0.45]
    parts = []
    for f, ln in zip(notes, lens):
        parts.append((osc(f, ln, 'square', 0.3) + 0.5 * osc(f / 2, ln, 'tri')) * env(int(SR * ln), 0.003, ln * 0.8))
    write('complete', delay(np.concatenate(parts), 130), 0.6)
    # door, chest, lever, spring, crumble, shield break, buy, ui
    d = 0.5
    write('door', lp_fast(noise(d), 12) * env(int(SR * d), 0.05, 0.2) +
          0.4 * osc(sweep(200, 120, d), d, 'saw') * env(int(SR * d), 0.05, 0.2), 0.55)
    d = 0.35
    write('chest', np.concatenate([lp_fast(noise(0.08), 6) * env(int(SR * 0.08), 0.001, 0.03),
                                   osc(1047, 0.1, 'square', 0.5) * env(int(SR * 0.1), 0.001, 0.06),
                                   osc(1568, 0.2, 'square', 0.5) * env(int(SR * 0.2), 0.001, 0.1)]), 0.5)
    d = 0.18
    write('lever', lp_fast(noise(d), 3) * env(int(SR * d), 0.001, 0.03) +
          osc(sweep(300, 150, d), d, 'square') * env(int(SR * d), 0.001, 0.04) * 0.5, 0.5)
    d = 0.3
    write('spring', osc(sweep(200, 900, d, 0.5) + 60 * np.sin(t_(d) * 90), d, 'tri') * env(int(SR * d), 0.002, 0.15), 0.5)
    d = 0.5
    write('crumble', lp_fast(noise(d), 14) * env(int(SR * d), 0.02, 0.2), 0.5)
    d = 0.3
    write('shield', osc(sweep(1800, 600, d), d, 'tri') * env(int(SR * d), 0.001, 0.1) +
          lp_fast(noise(d), 1) * env(int(SR * d), 0.001, 0.04) * 0.5, 0.5)
    write('buy', np.concatenate([osc(f, 0.07, 'square', 0.5) * env(int(SR * 0.07), 0.001, 0.05) for f in [784, 1047, 1319, 1568]]), 0.45)
    d = 0.04
    write('ui_move', osc(1200, d, 'square', 0.5) * env(int(SR * d), 0.001, 0.015), 0.25)
    d = 0.12
    write('ui_ok', np.concatenate([osc(880, 0.05, 'square', 0.5) * env(int(SR * 0.05), 0.001, 0.03),
                                   osc(1320, 0.08, 'square', 0.5) * env(int(SR * 0.08), 0.001, 0.05)]), 0.35)
    write('ui_back', np.concatenate([osc(660, 0.05, 'square', 0.5) * env(int(SR * 0.05), 0.001, 0.03),
                                     osc(440, 0.08, 'square', 0.5) * env(int(SR * 0.08), 0.001, 0.05)]), 0.35)
    write('denied', osc(140, 0.2, 'square', 0.5) * env(int(SR * 0.2), 0.001, 0.08), 0.4)


# ---------------------------------------------------------------------------
# Music: tiny procedural chiptune sequencer
# ---------------------------------------------------------------------------

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


SCALES = {'minor': [0, 2, 3, 5, 7, 8, 10], 'major': [0, 2, 4, 5, 7, 9, 11], 'dorian': [0, 2, 3, 5, 7, 9, 10],
          'phryg': [0, 1, 3, 5, 7, 8, 10], 'harm': [0, 2, 3, 5, 7, 8, 11]}


def chord_notes(root, scale, degree):
    sc = SCALES[scale]
    return [root + sc[(degree + k) % 7] + 12 * ((degree + k) // 7) for k in (0, 2, 4)]


def render_track(name, bpm, root, scale, prog, bars_per_chord=1, lead='square', drums=True, seed=1,
                 arp=True, lead_density=0.6, bass_kind='tri', pad_amt=0.0, swing=0.0, intensity=1.0, reps=3):
    rng = np.random.default_rng(seed)
    beat = 60.0 / bpm
    step = beat / 4  # 16th notes
    steps_per_bar = 16
    nbars = len(prog) * bars_per_chord * reps
    total = nbars * steps_per_bar * step
    n = int(total * SR)
    out = np.zeros(n + SR)
    sc = SCALES[scale]

    def place(sig, t0, amp):
        i0 = int(t0 * SR)
        e = min(len(out), i0 + len(sig))
        out[i0:e] += sig[:e - i0] * amp

    # melody: generated once per chord cycle, repeated with variation
    melody_cache = {}
    for bar in range(nbars):
        deg = prog[(bar // bars_per_chord) % len(prog)]
        ch = chord_notes(root, scale, deg)
        bar_t = bar * steps_per_bar * step
        # bass
        for s in range(0, 16, 4 if bass_kind != 'drive' else 2):
            note = ch[0] - 12 if (s // 4) % 2 == 0 or bass_kind == 'drive' else ch[2] - 24
            dur = step * (3.6 if bass_kind != 'drive' else 1.8)
            sig = osc(midi(note), dur, 'tri' if bass_kind != 'drive' else 'square', 0.5) * env(int(SR * dur), 0.005, dur * 0.7, 0.3)
            if bass_kind == 'drive':
                sig = lp_fast(sig, 6)
            place(sig, bar_t + s * step, 0.32)
        # pad
        if pad_amt > 0:
            dur = steps_per_bar * step
            sig = sum(osc(midi(nn), dur, 'saw') for nn in ch)
            sig = lp_fast(sig, 18) * env(int(SR * dur), 0.3, dur, 0.6)
            place(sig, bar_t, 0.05 * pad_amt)
        # arpeggio
        if arp:
            pat = [0, 1, 2, 1] if bar % 2 == 0 else [0, 2, 1, 2]
            for s in range(0, 16, 2):
                nn = ch[pat[(s // 2) % 4]] + 12
                dur = step * 1.6
                sig = osc(midi(nn), dur, 'square', 0.25) * env(int(SR * dur), 0.002, dur * 0.4)
                sw = swing * step if (s // 2) % 2 else 0
                place(lp_fast(sig, 2), bar_t + s * step + sw, 0.07)
        # lead melody (cached per bar index within the cycle, varied on repeat)
        cyc = len(prog) * bars_per_chord
        key = (bar % cyc, 1 if bar >= 2 * cyc else 0)
        if key not in melody_cache:
            notes = []
            s = 0
            cur = ch[0] + 12
            while s < 16:
                ln = int(rng.choice([2, 2, 4, 4, 6, 8]))
                if rng.random() < lead_density:
                    if s % 8 == 0:
                        cur = ch[int(rng.integers(0, 3))] + 12
                    else:
                        idx = sc.index((cur - root) % 12) if (cur - root) % 12 in sc else 0
                        idx = (idx + int(rng.choice([-2, -1, 1, 1, 2]))) % 7
                        octv = (cur - root) // 12
                        cur = root + sc[idx] + 12 * octv
                        cur = max(root + 7, min(root + 26, cur))
                    notes.append((s, ln, cur))
                s += ln
            melody_cache[key] = notes
        if bar >= len(prog) * bars_per_chord or reps == 1:
            for (s, ln, nn) in melody_cache[key]:
                dur = ln * step * 0.95
                vib = midi(nn) * (1 + 0.004 * np.sin(t_(dur) * 30))
                sig = osc(vib, dur, lead, 0.5 if lead == 'square' else 0.5) * env(int(SR * dur), 0.01, dur * 0.6, 0.4)
                place(lp_fast(sig, 3), bar_t + s * step, 0.11)
        # drums
        if drums:
            for s in range(16):
                tt = bar_t + s * step
                if s in (0, 8) or (intensity > 1 and s in (6, 10)):
                    d = 0.18
                    k = osc(sweep(150, 40, d, 0.5), d, 'sine') * env(int(SR * d), 0.001, 0.06)
                    place(k, tt, 0.5)
                if s in (4, 12):
                    d = 0.15
                    sn = lp_fast(noise(d), 2) * env(int(SR * d), 0.001, 0.04)
                    place(sn, tt, 0.22)
                if s % 2 == 0 or intensity > 1:
                    d = 0.04
                    hh = noise(d) * env(int(SR * d), 0.001, 0.01)
                    hh = hh - lp_fast(hh, 4)
                    place(hh, tt, 0.12 if s % 4 == 2 else 0.06)
    out = out[:n]
    # gentle room echo, wrapped so the loop stays seamless
    d = int(SR * beat * 0.75)
    wet = np.zeros_like(out)
    for k in range(1, 3):
        wet += np.roll(out, d * k) * (0.22 / k)
    out = out + wet
    write('music_' + name, out, 0.7)


def music():
    render_track('menu', 84, 57, 'dorian', [0, 3, 5, 4], 1, lead='tri', drums=False, seed=3, pad_amt=1.0, lead_density=0.5)
    render_track('camp', 92, 60, 'major', [0, 5, 3, 4], 1, lead='tri', drums=False, seed=11, pad_amt=0.8, swing=0.3)
    render_track('r1', 112, 57, 'dorian', [0, 6, 3, 4], 1, lead='square', drums=True, seed=21, pad_amt=0.5)
    render_track('r2', 126, 52, 'phryg', [0, 1, 0, 6], 1, lead='square', drums=True, seed=31, bass_kind='drive',
                 intensity=1.2)
    render_track('r3', 96, 62, 'minor', [0, 5, 2, 6], 1, lead='tri', drums=True, seed=41, pad_amt=1.0, arp=True,
                 lead_density=0.45)
    render_track('r4', 88, 50, 'harm', [0, 5, 1, 4], 1, lead='tri', drums=False, seed=51, pad_amt=1.4, lead_density=0.35)
    render_track('r5', 118, 55, 'harm', [0, 5, 3, 4], 1, lead='square', drums=True, seed=61, pad_amt=0.8)
    render_track('boss', 144, 52, 'harm', [0, 0, 5, 4], 1, lead='square', drums=True, seed=71, bass_kind='drive',
                 intensity=1.5, lead_density=0.75)
    render_track('final', 152, 50, 'harm', [0, 5, 1, 4, 0, 5, 6, 4], 1, lead='saw', drums=True, seed=81,
                 bass_kind='drive', intensity=1.6, lead_density=0.8, pad_amt=0.6, reps=3)
    render_track('victory', 100, 60, 'major', [0, 3, 4, 0, 5, 3, 4, 4], 1, lead='square', drums=True, seed=91,
                 pad_amt=0.8, reps=1)


if __name__ == '__main__':
    sfx()
    music()
    print('audio generated')
