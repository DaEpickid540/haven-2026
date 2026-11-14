"""Retro sound effects (sfxr-style synthesis). Stdlib only."""
import math
import os
import random

from common import ASSETS, SAMPLE_RATE as SR, write_wav

OUT = os.path.join(ASSETS, "sounds")
_rng = random.Random(1234)


def osc(wave, p, duty=0.5):
    p -= math.floor(p)
    if wave == "square":
        return 1.0 if p < duty else -1.0
    if wave == "saw":
        return 2.0 * p - 1.0
    if wave == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    return math.sin(2 * math.pi * p)


def tone(dur, f0, f1=None, wave="square", duty=0.5, vol=1.0, attack=0.004,
         curve=1.0, vib_rate=0.0, vib_depth=0.0, sustain=0.0):
    """Pitch slides exponentially f0 -> f1; envelope = attack then decay^curve."""
    f1 = f1 or f0
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        k = t / dur
        f = f0 * (f1 / f0) ** k
        if vib_depth:
            f *= 1 + vib_depth * math.sin(2 * math.pi * vib_rate * t)
        phase += f / SR
        env = min(1.0, t / attack) if attack else 1.0
        env *= sustain + (1 - sustain) * (1 - k) ** curve
        out[i] = osc(wave, phase, duty) * env * vol
    return out


def noise(dur, rate0=8000, rate1=None, vol=1.0, attack=0.002, curve=1.0, swell=False):
    """NES-style sample&hold noise. rate = how often a new random value is picked."""
    rate1 = rate1 or rate0
    n = int(dur * SR)
    out = [0.0] * n
    hold, acc = 0.0, 1.0
    for i in range(n):
        t = i / SR
        k = t / dur
        rate = rate0 * (rate1 / rate0) ** k
        acc += rate / SR
        if acc >= 1.0:
            acc -= math.floor(acc)
            hold = _rng.uniform(-1, 1)
        env = math.sin(math.pi * k) if swell else (min(1.0, t / attack) * (1 - k) ** curve)
        out[i] = hold * env * vol
    return out


def mixdown(*parts):
    """parts: (offset_seconds, samples) tuples or plain sample lists."""
    norm = [(0.0, p) if isinstance(p, list) else p for p in parts]
    n = max(int(o * SR) + len(s) for o, s in norm)
    out = [0.0] * n
    for o, s in norm:
        start = int(o * SR)
        for i, v in enumerate(s):
            out[start + i] += v
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(dur):
    return [0.0] * int(dur * SR)


def notes(freqs, step, wave="square", duty=0.5, tail=None, vol=1.0, curve=1.0):
    parts = []
    for i, f in enumerate(freqs):
        d = tail if (tail and i == len(freqs) - 1) else step * 1.6
        parts.append((i * step, tone(d, f, wave=wave, duty=duty, vol=vol, curve=curve)))
    return mixdown(*parts)


def lowpass(s, a=0.2):
    out, y = [], 0.0
    for v in s:
        y += a * (v - y)
        out.append(y)
    return out


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


SFX = {
    # movement
    "jump_1": (lambda: tone(0.16, 220, 660, duty=0.5, curve=0.8), 0.6),
    "jump_2": (lambda: tone(0.13, 300, 900, duty=0.25), 0.6),
    "jump_3": (lambda: tone(0.2, 200, 520, wave="tri", curve=0.7), 0.7),
    "double_jump": (lambda: seq(tone(0.07, 400, 1000, duty=0.25), tone(0.12, 600, 1400, duty=0.25)), 0.6),
    "land": (lambda: lowpass(noise(0.08, 2500, 600, curve=2), 0.3), 0.5),
    "footstep_1": (lambda: lowpass(noise(0.04, 3000, curve=2), 0.35), 0.35),
    "footstep_2": (lambda: lowpass(noise(0.045, 2200, curve=2), 0.35), 0.35),
    "footstep_3": (lambda: lowpass(noise(0.05, 1600, curve=2), 0.35), 0.35),
    "dash": (lambda: noise(0.22, 600, 7000, swell=True), 0.55),
    "whoosh": (lambda: lowpass(noise(0.3, 4000, 1500, swell=True), 0.25), 0.55),
    "bounce": (lambda: tone(0.35, 140, 560, wave="sine", vib_rate=18, vib_depth=0.15, curve=1.4), 0.8),
    # pickups
    "coin_1": (lambda: seq(tone(0.06, 988, duty=0.5, curve=0.1), tone(0.28, 1319, duty=0.5, curve=1.2)), 0.5),
    "coin_2": (lambda: notes([1047, 1568, 2093], 0.045, duty=0.25, tail=0.2), 0.5),
    "pickup": (lambda: mixdown(tone(0.12, 600, 1200, wave="tri"), (0.05, tone(0.1, 1200, 1800, duty=0.25, vol=0.5))), 0.55),
    "powerup_1": (lambda: notes([midi(n) for n in (60, 64, 67, 72, 76, 79, 84)], 0.05, duty=0.25, tail=0.25), 0.55),
    "powerup_2": (lambda: tone(0.6, 250, 1500, duty=0.5, vib_rate=30, vib_depth=0.08, sustain=0.6), 0.5),
    "heal": (lambda: notes([midi(n) for n in (72, 76, 79, 84)], 0.08, wave="sine", tail=0.5), 0.6),
    "key_get": (lambda: notes([midi(n) for n in (79, 84, 88, 91)], 0.06, duty=0.125, tail=0.35), 0.5),
    "gem": (lambda: mixdown(notes([2093, 2637, 3136], 0.04, wave="sine", tail=0.3), (0.02, noise(0.2, 12000, vol=0.1))), 0.5),
    # combat
    "hurt_1": (lambda: mixdown(tone(0.22, 520, 140, duty=0.5), noise(0.12, 5000, vol=0.4)), 0.6),
    "hurt_2": (lambda: tone(0.25, 320, 80, wave="saw", curve=0.7), 0.6),
    "hit_1": (lambda: mixdown(noise(0.08, 9000, 2000, curve=2), tone(0.08, 220, 80)), 0.6),
    "hit_2": (lambda: lowpass(noise(0.14, 3000, 800, curve=1.5), 0.5), 0.65),
    "punch": (lambda: mixdown(lowpass(noise(0.1, 2000, 300, curve=2), 0.4), tone(0.1, 160, 50, wave="sine")), 0.75),
    "sword_swing": (lambda: noise(0.16, 2000, 9000, swell=True), 0.45),
    "death": (lambda: tone(0.9, 700, 55, duty=0.5, vib_rate=10, vib_depth=0.06, curve=0.6), 0.55),
    "enemy_death": (lambda: mixdown(tone(0.3, 900, 100, duty=0.25), noise(0.3, 4000, 500, vol=0.6)), 0.55),
    "explosion_1": (lambda: noise(0.45, 3000, 250, curve=1.3), 0.7),
    "explosion_2": (lambda: mixdown(noise(1.1, 1600, 90, curve=1.1), tone(0.6, 90, 30, wave="sine", curve=1.5)), 0.85),
    "explosion_3": (lambda: lowpass(noise(0.8, 1200, 100, curve=1.0), 0.12), 0.6),
    "laser_1": (lambda: tone(0.15, 1500, 300, duty=0.25), 0.45),
    "laser_2": (lambda: tone(0.2, 2000, 600, wave="saw"), 0.4),
    "laser_3": (lambda: tone(0.3, 900, 110, duty=0.5, vib_rate=25, vib_depth=0.1), 0.45),
    "shoot_1": (lambda: mixdown(noise(0.12, 6000, 1000, curve=2), tone(0.05, 800, 200)), 0.6),
    "shoot_2": (lambda: tone(0.12, 650, 200, wave="tri"), 0.6),
    "magic": (lambda: mixdown(notes([midi(n) for n in (72, 79, 84, 91, 96)], 0.035, wave="sine", tail=0.3, vol=0.8),
                              noise(0.35, 14000, vol=0.08, swell=True)), 0.55),
    "shield_block": (lambda: mixdown(tone(0.25, 1800, 1700, wave="square", duty=0.125, curve=2), noise(0.05, 10000, vol=0.5)), 0.45),
    # world
    "door_open": (lambda: mixdown(tone(0.45, 70, 110, wave="saw", vol=0.6, curve=0.5), lowpass(noise(0.45, 900, vol=0.4), 0.2)), 0.55),
    "door_close": (lambda: mixdown(tone(0.15, 90, 50, wave="saw"), lowpass(noise(0.12, 1500, curve=2), 0.4)), 0.6),
    "unlock": (lambda: seq(noise(0.02, 12000), silence(0.05), noise(0.02, 12000), silence(0.03),
                           tone(0.25, 1760, duty=0.25)), 0.45),
    "switch": (lambda: seq(tone(0.03, 1200, duty=0.5, curve=3), silence(0.02), tone(0.04, 800, duty=0.5, curve=3)), 0.4),
    "checkpoint": (lambda: notes([midi(n) for n in (72, 76, 79, 84)], 0.07, duty=0.25, tail=0.4), 0.5),
    "alarm": (lambda: seq(*[tone(0.15, f, duty=0.5, sustain=1.0, curve=0.0) for f in (880, 660) * 3]), 0.4),
    "splash": (lambda: lowpass(noise(0.4, 7000, 1500, curve=1.5), 0.5), 0.55),
    "teleport": (lambda: tone(0.5, 200, 2400, wave="sine", vib_rate=40, vib_depth=0.2, curve=0.5), 0.5),
    # ui
    "ui_click": (lambda: tone(0.035, 1200, duty=0.5, curve=2), 0.35),
    "ui_hover": (lambda: tone(0.03, 900, wave="tri", curve=2), 0.25),
    "ui_confirm": (lambda: seq(tone(0.07, 660, duty=0.25, sustain=0.5), tone(0.14, 990, duty=0.25)), 0.4),
    "ui_back": (lambda: seq(tone(0.07, 660, duty=0.25, sustain=0.5), tone(0.14, 440, duty=0.25)), 0.4),
    "ui_error": (lambda: seq(tone(0.09, 140, duty=0.5, sustain=1, curve=0), silence(0.04),
                             tone(0.12, 140, duty=0.5, sustain=1, curve=0.5)), 0.35),
    "text_blip": (lambda: tone(0.025, 620, duty=0.5, curve=0.5), 0.25),
    "pause": (lambda: notes([1319, 988, 1319, 988], 0.06, duty=0.5, tail=0.1), 0.35),
    # jingles
    "level_complete": (lambda: mixdown(
        notes([midi(n) for n in (72, 76, 79, 84, 79, 84)], 0.12, duty=0.25, tail=0.7),
        notes([midi(n) for n in (60, 64, 67, 72, 67, 72)], 0.12, wave="tri", tail=0.7)), 0.6),
    "game_over": (lambda: mixdown(
        notes([midi(n) for n in (67, 66, 65, 64)], 0.32, duty=0.5, tail=1.0, curve=0.5),
        notes([midi(n) for n in (55, 54, 53, 52)], 0.32, wave="tri", tail=1.0, curve=0.5)), 0.6),
    "victory_fanfare": (lambda: mixdown(
        notes([midi(n) for n in (67, 67, 67, 72)], 0.1, duty=0.25, tail=0.8),
        notes([midi(n) for n in (55, 55, 55, 60)], 0.1, wave="tri", tail=0.8),
        (0.55, notes([midi(n) for n in (76, 79, 84)], 0.08, duty=0.125, tail=0.5, vol=0.6))), 0.6),
}


def run():
    for name, (fn, vol) in SFX.items():
        write_wav(os.path.join(OUT, f"{name}.wav"), fn(), normalize=vol)
    print(f"sfx done, {len(SFX)} files")


if __name__ == "__main__":
    run()
