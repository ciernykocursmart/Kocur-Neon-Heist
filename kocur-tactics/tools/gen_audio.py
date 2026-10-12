"""Synthesises every sound effect and music loop for Kocur Tactics.

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

def blip(f, d, kind='square', duty=0.5, dec=None):
    return osc(f, d, kind, duty) * env(int(SR * d), 0.002, dec if dec else d * 0.5)


def seq(notes, d, kind='square', duty=0.4, gap=0.0):
    parts = []
    for f in notes:
        parts.append(blip(f, d, kind, duty))
        if gap:
            parts.append(np.zeros(int(SR * gap)))
    return np.concatenate(parts)


def sfx():
    d = 0.04
    write('ui_move', blip(1200, d, dec=0.015), 0.22)
    write('ui_ok', np.concatenate([blip(880, 0.05), blip(1320, 0.08)]), 0.32)
    write('ui_back', np.concatenate([blip(660, 0.05), blip(440, 0.08)]), 0.32)
    write('denied', blip(140, 0.2, dec=0.08), 0.4)
    write('select', np.concatenate([blip(660, 0.04, 'tri'), blip(990, 0.07, 'tri')]), 0.4)
    d = 0.09
    write('step', lp_fast(noise(d), 8) * env(int(SR * d), 0.002, 0.03), 0.3)
    d = 0.14
    write('claw', lp_fast(noise(d), 3) * env(int(SR * d), 0.002, 0.04) +
          0.3 * osc(sweep(1400, 300, d), d, 'sine') * env(int(SR * d), 0.001, 0.03), 0.6)
    d = 0.18
    write('strike', lp_fast(noise(d), 2) * env(int(SR * d), 0.01, 0.05) +
          0.5 * osc(sweep(500, 200, d), d, 'saw') * env(int(SR * d), 0.002, 0.05), 0.6)
    d = 0.4
    write('heavy', osc(sweep(160, 40, d, 0.5), d, 'sine') * env(int(SR * d), 0.001, 0.15) +
          lp_fast(noise(d), 6) * env(int(SR * d), 0.001, 0.08), 0.85)
    d = 0.25
    write('shot', osc(sweep(420, 380, d), d, 'saw') * env(int(SR * d), 0.001, 0.07) * 0.6 +
          lp_fast(noise(d), 2) * env(int(SR * d), 0.001, 0.03) * 0.4, 0.5)
    d = 0.5
    v = np.zeros(int(SR * d))
    for k in range(4):
        s = osc(sweep(460 - k * 20, 380, 0.2), 0.2, 'saw') * env(int(SR * 0.2), 0.001, 0.05)
        i0 = int(SR * 0.07 * k)
        v[i0:i0 + len(s)] += s
    write('volley', v + 0.3 * lp_fast(noise(d), 3) * env(int(SR * d), 0.01, 0.2), 0.55)
    d = 0.25
    write('pounce', lp_fast(noise(d), 4) * env(int(SR * d), 0.01, 0.08) +
          0.4 * osc(sweep(300, 900, d), d, 'tri') * env(int(SR * d), 0.005, 0.08), 0.6)
    d = 0.35
    write('stance', osc(sweep(1800, 600, d), d, 'tri') * env(int(SR * d), 0.001, 0.12) +
          0.5 * osc(220, d, 'square', 0.3) * env(int(SR * d), 0.001, 0.1), 0.5)
    notes = [523, 659, 784, 1047]
    write('heal', delay(np.concatenate([blip(f, 0.08, 'sine', dec=0.07) for f in notes]), 70), 0.5)
    d = 0.35
    write('frost', osc(sweep(2400, 1600, d), d, 'sine') * env(int(SR * d), 0.001, 0.1) +
          0.5 * osc(3100, d, 'sine') * env(int(SR * d), 0.001, 0.05), 0.45)
    d = 0.16
    write('hit', osc(sweep(220, 60, d, 0.5), d, 'sine') * env(int(SR * d), 0.001, 0.05) +
          0.6 * lp_fast(noise(d), 2) * env(int(SR * d), 0.001, 0.025), 0.8)
    d = 0.2
    write('block', osc(sweep(900, 700, d), d, 'square', 0.3) * env(int(SR * d), 0.001, 0.05) +
          0.4 * lp_fast(noise(d), 1) * env(int(SR * d), 0.001, 0.02), 0.45)
    write('ko', delay(seq([523, 415, 330, 247], 0.14, 'square', 0.4), 110), 0.55)
    d = 0.4
    write('enemy_ko', lp_fast(noise(d), 6) * env(int(SR * d), 0.005, 0.15) +
          0.5 * osc(sweep(600, 100, d), d, 'square', 0.5) * env(int(SR * d), 0.005, 0.12), 0.6)
    write('turn_player', delay(seq([523, 659, 784], 0.08, 'tri'), 90), 0.45)
    write('turn_enemy', delay(seq([392, 370, 330], 0.1, 'square', 0.3), 110), 0.4)
    write('objective', delay(seq([784, 988, 1175, 1568], 0.07, 'tri'), 90), 0.5)
    lens = [0.1, 0.1, 0.1, 0.25, 0.1, 0.45]
    parts = []
    for f, ln in zip([523, 659, 784, 1047, 784, 1047], lens):
        parts.append((osc(f, ln, 'square', 0.3) + 0.5 * osc(f / 2, ln, 'tri')) * env(int(SR * ln), 0.003, ln * 0.8))
    write('victory', delay(np.concatenate(parts), 130), 0.6)
    parts = []
    for f, ln in zip([392, 370, 349, 262], [0.2, 0.2, 0.2, 0.6]):
        parts.append((osc(f, ln, 'tri') + 0.4 * osc(f / 2, ln, 'square', 0.3)) * env(int(SR * ln), 0.005, ln * 0.7))
    write('defeat', delay(np.concatenate(parts), 160), 0.55)
    d = 0.2
    write('warn', osc(880, d, 'square', 0.5) * env(int(SR * d), 0.002, 0.06) +
          osc(1320, d, 'square', 0.5) * env(int(SR * d), 0.002, 0.04) * 0.5, 0.45)
    d = 0.6
    write('blast', osc(sweep(120, 35, d, 0.4), d, 'sine') * env(int(SR * d), 0.001, 0.2) +
          lp_fast(noise(d), 10) * env(int(SR * d), 0.001, 0.12) * 0.8, 0.9)
    tt = t_(1.0)
    f = 80 + 30 * np.sin(tt * 40) + sweep(40, -20, 1.0)
    x = osc(f, 1.0, 'saw') * 0.6 + lp_fast(noise(1.0), 4) * 0.5
    write('boss', lp_fast(x, 3) * env(len(tt), 0.08, 0.5), 0.75)
    d = 1.2
    ch = sum(osc(fq, d, 'saw') for fq in [110, 165, 220, 277]) * env(int(SR * d), 0.02, 0.5) * 0.3
    write('phase', lp_fast(ch, 3) + osc(sweep(90, 30, d), d, 'sine') * env(int(SR * d), 0.001, 0.4), 0.85)
    d = 0.5
    fm = 900 + 400 * np.sin(np.linspace(0, 30, int(SR * d)))
    write('summon', osc(fm, d, 'sine') * env(int(SR * d), 0.02, 0.15) + 0.3 * osc(fm * 1.5, d, 'tri') * env(int(SR * d), 0.02, 0.1), 0.5)
    d = 0.5
    fm = np.concatenate([sweep(500, 900, d * 0.4), sweep(900, 600, d * 0.6)])
    m = osc(fm, d, 'saw') * env(int(SR * d), 0.03, 0.25)
    write('free', lp_fast(m, 3) + 0.3 * osc(fm * 2, d, 'sine') * env(int(SR * d), 0.03, 0.2), 0.6)
    write('claim', delay(seq([659, 784, 1047, 1319, 1568], 0.08, 'square', 0.25), 100), 0.5)
    write('escape', delay(seq([392, 523, 659, 784], 0.07, 'tri'), 80), 0.5)
    write('treasure', np.concatenate([lp_fast(noise(0.08), 6) * env(int(SR * 0.08), 0.001, 0.03),
                                      blip(1047, 0.1), blip(1568, 0.2)]), 0.5)
    write('levelup', delay(seq([523, 659, 784, 1047, 1319], 0.09, 'square', 0.3), 120), 0.5)
    write('buy', seq([784, 1047, 1319, 1568], 0.07), 0.45)
    d = 0.3
    write('wake', osc(sweep(300, 600, d), d, 'square', 0.3) * env(int(SR * d), 0.01, 0.1), 0.35)


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
    render_track('menu', 84, 57, 'dorian', [0, 3, 5, 4], 1, lead='tri', drums=False, seed=103, pad_amt=1.0, lead_density=0.5)
    render_track('campaign', 96, 60, 'major', [0, 5, 3, 4], 1, lead='tri', drums=True, seed=111, pad_amt=0.8, swing=0.3)
    render_track('act1', 108, 62, 'major', [0, 3, 4, 5], 1, lead='square', drums=True, seed=121, pad_amt=0.5)
    render_track('act2', 116, 57, 'dorian', [0, 6, 3, 4], 1, lead='square', drums=True, seed=131, bass_kind='drive',
                 intensity=1.2)
    render_track('act3', 120, 55, 'minor', [0, 5, 2, 6], 1, lead='tri', drums=True, seed=141, pad_amt=1.0, arp=True,
                 lead_density=0.55, intensity=1.2)
    render_track('boss', 140, 52, 'harm', [0, 0, 5, 4], 1, lead='square', drums=True, seed=171, bass_kind='drive',
                 intensity=1.5, lead_density=0.75)
    render_track('final', 148, 50, 'harm', [0, 5, 1, 4, 0, 5, 6, 4], 1, lead='saw', drums=True, seed=181,
                 bass_kind='drive', intensity=1.6, lead_density=0.8, pad_amt=0.6, reps=3)
    render_track('ending', 92, 60, 'major', [0, 3, 4, 0, 5, 3, 4, 4], 1, lead='square', drums=True, seed=191,
                 pad_amt=0.8, reps=2)


if __name__ == '__main__':
    sfx()
    music()
    print('audio generated')
