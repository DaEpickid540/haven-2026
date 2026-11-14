"""Chiptune loop composer/renderer. Each track loops seamlessly (tails wrap to the start)."""
import math
import os
import random

from common import ASSETS, SAMPLE_RATE as SR, write_wav

OUT = os.path.join(ASSETS, "music")

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
HARM_MINOR = [0, 2, 3, 5, 7, 8, 11]
PHRYG_DOM = [0, 1, 4, 5, 7, 8, 10]
DORIAN = [0, 2, 3, 5, 7, 9, 10]


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# --------------------------------------------------------------------------- instruments
def render_note(buf, start, dur, midi_note, inst, vol):
    """Adds one note into buf (wrapping around the end for seamless loops)."""
    f = hz(midi_note)
    wave = inst.get("wave", "square")
    duty = inst.get("duty", 0.5)
    a, d, s, r = inst.get("adsr", (0.005, 0.08, 0.6, 0.05))
    vib_d, vib_r = inst.get("vib", (0.0, 5.0))
    decay_only = inst.get("pluck", False)
    n_total = int((dur + r) * SR)
    n = len(buf)
    i0 = int(start * SR)
    phase = 0.0
    inc = f / SR
    two_pi = 2 * math.pi
    for i in range(n_total):
        t = i / SR
        if decay_only:
            env = math.exp(-t * inst.get("decay", 6.0))
        else:
            if t < a:
                env = t / a
            elif t < a + d:
                env = 1 - (1 - s) * (t - a) / d
            else:
                env = s
            if t > dur:
                env *= max(0.0, 1 - (t - dur) / r)
        if vib_d and t > 0.12:
            phase += inc * (1 + vib_d * math.sin(two_pi * vib_r * t))
        else:
            phase += inc
        p = phase - int(phase)
        if wave == "square":
            v = 1.0 if p < duty else -1.0
        elif wave == "tri":
            v = 4.0 * abs(p - 0.5) - 1.0
        elif wave == "saw":
            v = 2.0 * p - 1.0
        else:
            v = math.sin(two_pi * p) + 0.3 * math.sin(2 * two_pi * p) * env
        buf[(i0 + i) % n] += v * env * vol


_nrng = random.Random(99)


def render_drum(buf, start, kind, vol):
    n = len(buf)
    i0 = int(start * SR)
    if kind == "kick":
        length, phase = int(0.16 * SR), 0.0
        for i in range(length):
            t = i / SR
            f = 45 + 110 * math.exp(-t * 30)
            phase += f / SR
            buf[(i0 + i) % n] += math.sin(2 * math.pi * phase) * math.exp(-t * 18) * vol
    elif kind == "snare":
        length, hold, phase = int(0.18 * SR), 0.0, 0.0
        for i in range(length):
            t = i / SR
            if i % 3 == 0:
                hold = _nrng.uniform(-1, 1)
            phase += 190 / SR
            v = hold * 0.8 + 0.5 * math.sin(2 * math.pi * phase) * math.exp(-t * 30)
            buf[(i0 + i) % n] += v * math.exp(-t * 20) * vol
    elif kind in ("hat", "ohat"):
        length = int((0.05 if kind == "hat" else 0.18) * SR)
        prev = 0.0
        for i in range(length):
            t = i / SR
            x = _nrng.uniform(-1, 1)
            v = x - prev
            prev = x
            buf[(i0 + i) % n] += v * 0.5 * math.exp(-t * (70 if kind == "hat" else 18)) * vol


# --------------------------------------------------------------------------- composer
RHYTHMS = [
    # 16 steps per bar; 1 = note onset, 0 = hold/rest (decided by 'r' marks)
    "1.1.1.1.1...1.1.",
    "1...1.1.1...1...",
    "1.1...1.1.1.1...",
    "1..1..1.1...1.1.",
    "1...1...1.1.1.1.",
    "1.......1...1...",
    "1..1..1...1.1...",
]
SPARSE = ["1.......1.......", "1...........1...", "1.....1.....1...", "1...1...1......."]


def chord_tones(root_deg, scale, key, seventh=False):
    degs = [root_deg, root_deg + 2, root_deg + 4] + ([root_deg + 6] if seventh else [])
    out = []
    for d in degs:
        octv, idx = divmod(d, 7)
        out.append(key + scale[idx] + 12 * octv)
    return out


def scale_notes(scale, key, lo, hi):
    out = []
    for octv in range(-3, 5):
        for s in scale:
            m = key + s + 12 * octv
            if lo <= m <= hi:
                out.append(m)
    return sorted(out)


def compose_melody(rng, prog, scale, key, rhythms, lo, hi, bars):
    pool = scale_notes(scale, key, lo, hi)
    motif = [rng.choice(rhythms), rng.choice(rhythms)]
    events = []  # (step_index, length_steps, midi)
    prev = pool[len(pool) // 2]
    for bar in range(bars):
        phrase_pos = bar % 8
        rhythm = motif[bar % 2] if phrase_pos < 6 else rng.choice(rhythms)
        if phrase_pos == 7:
            rhythm = "1.1.1...1......."
        chord = chord_tones(prog[bar % len(prog)][0], scale, key)
        onsets = [i for i, ch in enumerate(rhythm) if ch == "1"]
        for j, st in enumerate(onsets):
            nxt = onsets[j + 1] if j + 1 < len(onsets) else 16
            length = nxt - st
            if st % 4 == 0:
                cands = [m for m in pool if (m - chord[0]) % 12 in [(c - chord[0]) % 12 for c in chord]]
                cands.sort(key=lambda m: abs(m - prev) + rng.random() * 3)
                note = cands[0] if rng.random() < 0.7 else cands[min(1, len(cands) - 1)]
            else:
                idx = min(range(len(pool)), key=lambda k: abs(pool[k] - prev))
                idx = max(0, min(len(pool) - 1, idx + rng.choice([-2, -1, -1, 1, 1, 2])))
                note = pool[idx]
            if phrase_pos == 7 and j == len(onsets) - 1:
                note = min((m for m in pool if (m - key) % 12 == 0), key=lambda m: abs(m - prev))
            if rng.random() < 0.08 and length > 1 and phrase_pos != 7:
                continue  # rest
            events.append((bar * 16 + st, length, note))
            prev = note
    return events


def song(name, key, scale, bpm, prog, bars=16, seed=0, lead=None, harm=None, bass=None,
         drums=None, rhythms=RHYTHMS, mel_range=(72, 88), harm_style="arp16", bass_style="eighths",
         drum_vol=0.5, swing=0.0):
    rng = random.Random(seed or name)
    step = 60.0 / bpm / 4
    total = bars * 16 * step
    buf = [0.0] * int(total * SR)

    def at(st):
        return st * step + (swing * step if st % 2 == 1 else 0)

    # melody
    if lead:
        events = compose_melody(rng, prog, scale, key + 12, rhythms, *mel_range, bars)
        for st, ln, m in events:
            render_note(buf, at(st), ln * step * 0.92, m, lead, lead.get("vol", 0.2))
        if lead.get("echo"):
            for st, ln, m in events:
                render_note(buf, at(st) + step * 3, ln * step * 0.8, m, lead, lead.get("vol", 0.2) * 0.3)

    for bar in range(bars):
        deg, sev = prog[bar % len(prog)]
        ch = chord_tones(deg, scale, key, sev)
        base = bar * 16
        # harmony
        if harm:
            hv = harm.get("vol", 0.08)
            if harm_style == "arp16":
                seq_ = ch + [ch[1] + 12] if len(ch) == 3 else ch
                for s16 in range(16):
                    render_note(buf, at(base + s16), step * 0.9, seq_[s16 % len(seq_)] + 12, harm, hv)
            elif harm_style == "arp8":
                seq_ = [ch[0], ch[1], ch[2], ch[1]]
                for s8 in range(8):
                    render_note(buf, at(base + s8 * 2), step * 1.8, seq_[s8 % 4] + 12, harm, hv)
            elif harm_style == "pad":
                for m in ch:
                    render_note(buf, at(base), 16 * step * 0.98, m, harm, hv)
            elif harm_style == "stabs":
                for s in (2, 6, 10, 14):
                    for m in ch:
                        render_note(buf, at(base + s), step * 1.2, m + 12, harm, hv)
            elif harm_style == "bells":
                for s, m in zip((0, 6, 10), (ch[0] + 12, ch[1] + 12, ch[2] + 12)):
                    render_note(buf, at(base + s), step * 6, m, harm, hv)
        # bass
        if bass:
            bv = bass.get("vol", 0.3)
            r = ch[0] - 12
            while r > key - 2:
                r -= 12
            if bass_style == "eighths":
                for s8 in range(8):
                    render_note(buf, at(base + s8 * 2), step * 1.7, r + (12 if s8 % 2 else 0), bass, bv)
            elif bass_style == "quarter":
                for q, iv in enumerate((0, 7, 12, 7)):
                    render_note(buf, at(base + q * 4), step * 3.6, r + iv, bass, bv)
            elif bass_style == "whole":
                render_note(buf, at(base), step * 15.5, r, bass, bv)
            elif bass_style == "drive":
                for s16 in range(16):
                    render_note(buf, at(base + s16), step * 0.8, r + (12 if s16 % 4 == 2 else 0), bass, bv)
            elif bass_style == "gallop":
                for s in (0, 3, 4, 8, 11, 12):
                    render_note(buf, at(base + s), step * 0.9, r, bass, bv)
        # drums
        if drums:
            for kind, pattern in drums.items():
                for s16, ch_ in enumerate(pattern):
                    if ch_ == "x":
                        render_drum(buf, at(base + s16), kind, drum_vol)
                    elif ch_ == "o":
                        render_drum(buf, at(base + s16), kind, drum_vol * 0.45)
            if bar % 4 == 3:  # fill
                for s16 in (12, 13, 14, 15):
                    render_drum(buf, at(base + s16), "snare", drum_vol * (0.4 + 0.15 * (s16 - 12)))

    # gentle master lowpass to tame naive square-wave harshness (circular so it stays loopable)
    y, a = 0.0, 0.55
    for _ in range(2):
        for i in range(len(buf)):
            y += a * (buf[i] - y)
            buf[i] = y
    # downsample to 22.05 kHz (plenty for chiptune, halves file size)
    if len(buf) % 2:
        buf.append(buf[0])
    half = [(buf[i] + buf[i + 1]) * 0.5 for i in range(0, len(buf), 2)]
    write_wav(os.path.join(OUT, f"{name}.wav"), half, rate=SR // 2, normalize=0.8)
    print(f"  {name}: {total:.1f}s")


SQ25 = {"wave": "square", "duty": 0.25, "adsr": (0.005, 0.1, 0.55, 0.04), "vib": (0.006, 5.5)}
SQ50 = {"wave": "square", "duty": 0.5, "adsr": (0.005, 0.12, 0.5, 0.05), "vib": (0.005, 5)}
SQ12 = {"wave": "square", "duty": 0.125, "adsr": (0.002, 0.05, 0.3, 0.02)}
TRI_BASS = {"wave": "tri", "adsr": (0.003, 0.05, 0.8, 0.03)}
SAW = {"wave": "saw", "adsr": (0.01, 0.15, 0.5, 0.08), "vib": (0.008, 5)}
PAD = {"wave": "saw", "adsr": (0.25, 0.3, 0.6, 0.3)}
BELL = {"wave": "sine", "pluck": True, "decay": 3.5}
SOFT_LEAD = {"wave": "tri", "adsr": (0.02, 0.2, 0.6, 0.15), "vib": (0.01, 4.5)}

ROCK = {"kick": "x.......x.x.....", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x."}
FOUR = {"kick": "x...x...x...x...", "snare": "....x.......x...", "hat": "..x...x...x...x."}
SPARSE_D = {"kick": "x...........x...", "hat": "....o.......o..."}
BOSS = {"kick": "x.x.x.x.x.x.x.x.", "snare": "....x.......x...", "hat": "xoxoxoxoxoxoxoxo"}
SHUFFLE = {"kick": "x.....x...x.....", "snare": "....x.......x...", "hat": "x..ox..ox..ox..o"}
SOFT_HATS = {"hat": "o...o...o...o..."}


def run():
    print("music:")
    song("adventure_theme", 60, MAJOR, 132, [(0, 0), (4, 0), (5, 0), (3, 0)],
         lead={**SQ25, "vol": 0.22}, harm={**SQ12, "vol": 0.06}, bass={**TRI_BASS, "vol": 0.35},
         drums=ROCK, harm_style="arp16", bass_style="eighths", drum_vol=0.45)
    song("dungeon_crawl", 57, HARM_MINOR, 88, [(0, 0), (5, 0), (3, 0), (4, 0)],
         lead={**SQ50, "vol": 0.18, "echo": True}, harm={**PAD, "vol": 0.05}, bass={**TRI_BASS, "vol": 0.4},
         drums=SPARSE_D, rhythms=SPARSE + RHYTHMS[4:6], harm_style="pad", bass_style="quarter",
         mel_range=(64, 81), drum_vol=0.5)
    song("space_station", 52, MINOR, 116, [(0, 0), (6, 0), (5, 0), (6, 0)],
         lead={**SAW, "vol": 0.14, "echo": True}, harm={**SQ12, "vol": 0.07}, bass={**SQ50, "vol": 0.2},
         drums=FOUR, harm_style="arp16", bass_style="eighths", mel_range=(64, 83), drum_vol=0.45)
    song("calm_menu", 53, MAJOR, 76, [(0, 1), (5, 1), (1, 1), (4, 1)],
         lead={**SOFT_LEAD, "vol": 0.22}, harm={**BELL, "vol": 0.1}, bass={**TRI_BASS, "vol": 0.3},
         drums=SOFT_HATS, rhythms=SPARSE + RHYTHMS[4:6], harm_style="arp8", bass_style="whole",
         mel_range=(67, 84), drum_vol=0.3)
    song("boss_battle", 50, HARM_MINOR, 168, [(0, 0), (0, 0), (5, 0), (4, 0)],
         lead={**SQ25, "vol": 0.2}, harm={**SQ50, "vol": 0.05}, bass={**TRI_BASS, "vol": 0.4},
         drums=BOSS, harm_style="stabs", bass_style="drive", mel_range=(69, 88), drum_vol=0.5)
    song("desert_wind", 50, PHRYG_DOM, 104, [(0, 0), (1, 0), (0, 0), (6, 0)],
         lead={**SQ50, "vol": 0.18, "vib": (0.012, 6)}, harm={**SQ12, "vol": 0.05}, bass={**TRI_BASS, "vol": 0.38},
         drums=SHUFFLE, harm_style="arp8", bass_style="gallop", mel_range=(62, 81), drum_vol=0.4, swing=0.2)
    song("winter_village", 55, MAJOR, 96, [(0, 0), (2, 0), (3, 0), (4, 0)],
         lead={**BELL, "vol": 0.3, "decay": 4.0}, harm={**SQ12, "vol": 0.04}, bass={**TRI_BASS, "vol": 0.32},
         drums=SOFT_HATS, harm_style="arp8", bass_style="quarter", mel_range=(71, 91), drum_vol=0.35)
    song("puzzle_groove", 57, DORIAN, 108, [(0, 1), (3, 1), (0, 1), (4, 0)],
         lead={**SQ25, "vol": 0.18}, harm={**SQ50, "vol": 0.05}, bass={**TRI_BASS, "vol": 0.38},
         drums=SHUFFLE, harm_style="stabs", bass_style="quarter", mel_range=(64, 81), drum_vol=0.4, swing=0.15)


if __name__ == "__main__":
    run()
