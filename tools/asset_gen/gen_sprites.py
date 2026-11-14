"""Procedural pixel-art generator: characters, enemies, tiles, items, UI, FX, backgrounds.

Every animated sheet is registered in MANIFEST so gen_godot.py can build
SpriteFrames resources for it.
"""
import math
import os
import random

from common import ASSETS, Canvas, hexc, mix, shade, sheet, CLEAR

SPR = os.path.join(ASSETS, "sprites")
OUTLINE = hexc("181425")
WHITE = hexc("ffffff")

# path(rel to assets/sprites) -> {"fw","fh","anims": {name: (frame_indices, fps, loop)}}
MANIFEST = {}


def register(rel_path, fw, fh, anims):
    MANIFEST[rel_path] = {"fw": fw, "fh": fh, "anims": anims}


def save(canvas, rel_path):
    canvas.save(os.path.join(SPR, rel_path))


# ---------------------------------------------------------------------------
# Characters (16x16 humanoids, built from head / torso / legs parts)
# ---------------------------------------------------------------------------
HEADS = {
    "hair": [
        "..hhhhh.",
        ".hhhhhhh",
        "hhhsssss",
        "hhsseses",
        "hssseses",
        ".sssssss",
        "..SSSSS.",
    ],
    "knight": [
        "..hhhh..",
        ".hhhhhhh",
        "hhhhhhhh",
        "hhHvvvvv",
        "hhHhhhhh",
        ".hhhhhhh",
        "..HHHHH.",
    ],
    "wizard": [
        "....hh..",
        "...hhhh.",
        "hhhhhhhh",
        ".sssssss",
        ".sssesse",
        "wwwwwwww",
        ".wwwwww.",
    ],
    "robot": [
        "...aa...",
        ".hhhhhhh",
        "hhvvvvvh",
        "hvvwvvvh",
        "hvvvvvvh",
        ".hhhhhhh",
        "..HHHHH.",
    ],
    "ninja": [
        "..hhhhh.",
        ".hhhhhhh",
        "ahhhhhhh",
        "aassesse",
        "hhhhhhhh",
        ".hhhhhhh",
        "..hhhhh.",
    ],
    "skull": [
        "..hhhhh.",
        ".hhhhhhh",
        "hhhhhhhh",
        "hhheehee",
        "hhheehee",
        ".hhhhhhh",
        "..hHhHh.",
    ],
    "zombie": [
        "..hh.hh.",
        ".hhhhhhh",
        "hhsSssss",
        "hssseses",
        "hsssSeSs",
        ".sssssss",
        "..SSSSS.",
    ],
}

TORSO = {
    "idle": ["..bbbb..", ".bbbbbb.", ".sbbbbs.", "..aaaa.."],
    "swing_a": ["..bbbb..", ".bbbbbbs", ".sbbbbb.", "..aaaa.."],
    "swing_b": ["..bbbb..", "sbbbbbb.", ".bbbbbs.", "..aaaa.."],
    "up": ["s.bbbb.s", ".bbbbbb.", "..bbbb..", "..aaaa.."],
    "out": ["..bbbb..", "sbbbbbbs", "..bbbb..", "..aaaa.."],
}

LEGS = {
    "stand": ["..pppp..", "..p..p..", ".ff..ff."],
    "run_a": ["..pppp..", "..pp.pp.", ".ff...ff"],
    "run_b": ["..pppp..", "...ppp..", "...fff.."],
    "run_c": ["..pppp..", ".pp.pp..", "ff...ff."],
    "run_d": ["..pppp..", "..ppp...", "..fff..."],
    "jump": ["..pppp..", ".pp..pp.", ".f....f."],
    "fall": ["..pppp..", "..p..p..", "..f..f.."],
}

# frame = (torso, legs, bob)
CHAR_FRAMES = [
    ("idle", "stand", 0),
    ("idle", "stand", 1),
    ("swing_a", "run_a", 1),
    ("idle", "run_b", 0),
    ("swing_b", "run_c", 1),
    ("idle", "run_d", 0),
    ("up", "jump", 0),
    ("out", "fall", 0),
    ("out", "stand", 0),  # hurt (tinted)
]
CHAR_ANIMS = {
    "idle": ([0, 1], 3.0, True),
    "run": ([2, 3, 4, 5], 10.0, True),
    "jump": ([6], 1.0, False),
    "fall": ([7], 1.0, False),
    "hurt": ([8], 1.0, False),
}

SKIN = {"s": hexc("e8b796"), "S": hexc("c28569"), "e": hexc("262b44")}

CHARACTERS = {
    "knight": dict(head="knight", pal={
        "h": hexc("c0cbdc"), "H": hexc("8b9bb4"), "v": hexc("262b44"),
        "b": hexc("3b5dc9"), "a": hexc("b86f50"), "s": hexc("c0cbdc"),
        "p": hexc("5a6988"), "f": hexc("3a4466")}),
    "adventurer": dict(head="hair", pal={
        **SKIN, "h": hexc("733e39"),
        "b": hexc("e43b44"), "a": hexc("733e39"),
        "p": hexc("3a4466"), "f": hexc("3e2731")}),
    "wizard": dict(head="wizard", pal={
        **SKIN, "h": hexc("68386c"), "w": hexc("e5e5e5"),
        "b": hexc("68386c"), "a": hexc("feae34"),
        "p": hexc("68386c"), "f": hexc("3e2731")}),
    "robot": dict(head="robot", pal={
        "h": hexc("c0cbdc"), "H": hexc("8b9bb4"), "v": hexc("0099db"), "w": WHITE,
        "a": hexc("feae34"), "b": hexc("8b9bb4"), "s": hexc("5a6988"),
        "p": hexc("5a6988"), "f": hexc("3a4466")}),
    "ninja": dict(head="ninja", pal={
        **SKIN, "h": hexc("262b44"), "e": hexc("181425"),
        "b": hexc("262b44"), "a": hexc("e43b44"),
        "p": hexc("262b44"), "f": hexc("3a4466")}),
    "astronaut": dict(head="robot", pal={
        "h": hexc("ffffff"), "H": hexc("c0cbdc"), "v": hexc("f77622"), "w": hexc("fee761"),
        "a": hexc("e43b44"), "b": hexc("ffffff"), "s": hexc("c0cbdc"),
        "p": hexc("c0cbdc"), "f": hexc("5a6988")}),
}

HUMANOID_ENEMIES = {
    "skeleton": dict(head="skull", pal={
        "h": hexc("ead4aa"), "H": hexc("181425"), "e": hexc("181425"),
        "b": hexc("ead4aa"), "a": hexc("c28569"), "s": hexc("ead4aa"),
        "p": hexc("ead4aa"), "f": hexc("c28569")}),
    "zombie": dict(head="zombie", pal={
        "s": hexc("8fbf5a"), "S": hexc("5a8f3a"), "e": hexc("e43b44"), "h": hexc("3e2731"),
        "b": hexc("5a6988"), "a": hexc("733e39"),
        "p": hexc("733e39"), "f": hexc("3e2731")}),
}


def build_humanoid(head, pal, torso, legs, bob):
    c = Canvas(16, 16)
    c.ascii(LEGS[legs], pal, 4, 12)
    c.ascii(TORSO[torso], pal, 4, 8 + bob)
    c.ascii(HEADS[head], pal, 4, 1 + bob)
    return c.outlined(OUTLINE)


def tint(canvas, col, amt):
    out = Canvas(canvas.w, canvas.h)
    out.px = [mix(p, col[:3] + (p[3],), amt) if p[3] else p for p in canvas.px]
    return out


def gen_characters():
    for group, defs, folder in ((CHARACTERS, CHARACTERS, "characters"),
                                (HUMANOID_ENEMIES, HUMANOID_ENEMIES, "enemies")):
        for name, d in defs.items():
            frames = []
            for i, (t, l, b) in enumerate(CHAR_FRAMES):
                f = build_humanoid(d["head"], d["pal"], t, l, b)
                if i == 8:
                    f = tint(f, hexc("ff0044"), 0.55)
                frames.append(f)
            rel = f"{folder}/{name}.png"
            save(sheet(frames), rel)
            register(rel, 16, 16, CHAR_ANIMS)


# ---------------------------------------------------------------------------
# Non-humanoid enemies
# ---------------------------------------------------------------------------
def ellipse(c, cx, cy, rx, ry, col):
    for y in range(c.h):
        for x in range(c.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                c.set(x, y, col)


def gen_slimes():
    colors = {"green": "63c74d", "blue": "0099db", "red": "e43b44", "purple": "b55088"}
    shapes = [(6.0, 4.0), (6.5, 3.5), (5.5, 4.5), (5.0, 5.0)]
    for name, hx in colors.items():
        base = hexc(hx)
        frames = []
        for rx, ry in shapes:
            c = Canvas(16, 16)
            cy = 15 - ry
            ellipse(c, 8, cy, rx, ry, shade(base, 0.7))
            ellipse(c, 8, cy - 0.6, rx - 0.6, ry - 0.8, base)
            c.set(int(8 - rx / 2), int(cy - ry / 2), shade(base, 1.6))
            c.set(int(8 - rx / 2) + 1, int(cy - ry / 2), shade(base, 1.4))
            ey = int(cy) - 1
            c.rect(6, ey, 1, 2, OUTLINE)
            c.rect(10, ey, 1, 2, OUTLINE)
            frames.append(c.outlined(OUTLINE))
        rel = f"enemies/slime_{name}.png"
        save(sheet(frames), rel)
        register(rel, 16, 16, {"idle": ([0, 1, 2, 3, 2, 1], 8.0, True), "hurt": ([3], 1.0, False)})


BAT_UP = [
    "................", "................", "................",
    ".bb..........bb.", ".bbb........bbb.", "..bbb.b..b.bbb..",
    "..bbbbbbbbbbbb..", "...bbbbbbbbbb...", "....bbebbebb....",
    "......bbbb......", ".......dd.......",
]
BAT_DOWN = [
    "................", "................", "................",
    "................", "......b..b......", ".....bbbbbb.....",
    "...bbbebbebbb...", "..bbbbbbbbbbbb..", ".bbb..bbbb..bbb.",
    ".bb.....dd...bb.", "................",
]


def gen_bat():
    pal = {"b": hexc("5d275d"), "e": hexc("feae34"), "d": hexc("ffffff")}
    frames = [Canvas(16, 16) for _ in range(2)]
    frames[0].ascii(BAT_UP, pal, 0, 2)
    frames[1].ascii(BAT_DOWN, pal, 0, 2)
    frames = [f.outlined(OUTLINE) for f in frames]
    save(sheet(frames), "enemies/bat.png")
    register("enemies/bat.png", 16, 16, {"fly": ([0, 1], 8.0, True)})


def gen_ghost():
    body, sh = hexc("e5f0ff"), hexc("a3b8d8")
    frames = []
    for i in range(4):
        c = Canvas(16, 16)
        off = [0, 1, 1, 0][i]
        ellipse(c, 8, 7 + off, 5.5, 5.5, body)
        c.rect(3, 7 + off, 11, 5, body)
        for x in range(3, 14):
            if (x + i) % 3 == 0:
                c.put(x, 11 + off, CLEAR)
        c.rect(12, 6 + off, 2, 5, sh)
        c.rect(6, 6 + off, 1, 2, OUTLINE)
        c.rect(9, 6 + off, 1, 2, OUTLINE)
        c.rect(7, 9 + off, 2, 1, OUTLINE)
        frames.append(c.outlined(OUTLINE))
    save(sheet(frames), "enemies/ghost.png")
    register("enemies/ghost.png", 16, 16, {"float": ([0, 1, 2, 3], 6.0, True)})


def gen_drone():
    frames = []
    for i in range(4):
        c = Canvas(16, 16)
        ellipse(c, 8, 9, 5, 4, hexc("5a6988"))
        ellipse(c, 8, 8.5, 4, 3, hexc("8b9bb4"))
        c.rect(7, 8, 3, 2, hexc("e43b44") if i % 2 == 0 else hexc("feae34"))
        c.rect(8, 3, 1, 3, hexc("3a4466"))
        w = [5, 2, 5, 2][i]
        c.rect(8 - w, 2, w * 2 + 1, 1, hexc("c0cbdc"))
        c.rect(4, 13, 2, 1, hexc("3a4466"))
        c.rect(11, 13, 2, 1, hexc("3a4466"))
        frames.append(c.outlined(OUTLINE))
    save(sheet(frames), "enemies/drone.png")
    register("enemies/drone.png", 16, 16, {"fly": ([0, 1, 2, 3], 12.0, True)})


def gen_eyeball():
    frames = []
    looks = [(0, 0), (1, 0), (0, 0), (-1, 0), (0, 0), (0, -1)]
    for dx, dy in looks:
        c = Canvas(16, 16)
        ellipse(c, 8, 8, 6, 6, hexc("ffffff"))
        ellipse(c, 8, 9, 6, 5, hexc("e5e5e5"))
        c.rect(3, 6, 2, 1, hexc("e43b44"))
        c.rect(12, 10, 2, 1, hexc("e43b44"))
        ellipse(c, 8 + dx, 8 + dy, 3, 3, hexc("63c74d"))
        ellipse(c, 8 + dx, 8 + dy, 1.5, 1.5, OUTLINE)
        c.set(7 + dx, 7 + dy, WHITE)
        frames.append(c.outlined(OUTLINE))
    save(sheet(frames), "enemies/eyeball.png")
    register("enemies/eyeball.png", 16, 16, {"idle": (list(range(6)), 4.0, True)})


def gen_spider():
    frames = []
    for i in range(2):
        c = Canvas(16, 16)
        leg = hexc("262b44")
        for k, (x0, x1) in enumerate([(5, 1), (6, 2), (10, 14), (11, 13)]):
            y = 10 + (k % 2) + (i if k < 2 else 1 - i)
            c.line(x0, 9, x1, y, leg)
            c.set(x1, y + 1, leg)
        ellipse(c, 8, 8, 4, 3.5, hexc("3e2731"))
        ellipse(c, 8, 6, 2.5, 2, hexc("68386c"))
        c.set(7, 8, hexc("e43b44"))
        c.set(9, 8, hexc("e43b44"))
        frames.append(c.outlined(OUTLINE))
    save(sheet(frames), "enemies/spider.png")
    register("enemies/spider.png", 16, 16, {"walk": ([0, 1], 8.0, True)})


# ---------------------------------------------------------------------------
# Tilesets (8x4 atlas of 16x16, identical layout for every theme)
# ---------------------------------------------------------------------------
# Row 0: top-left, top, top-right, top-single, plat-left, plat-mid, plat-right, crate
# Row 1: fill-left, fill, fill-right, fill-alt, wall, bg-wall, ladder, spikes
# Row 2: deco x6 (tuft, plant, rock, bush, light, sign), door-top, door-bottom
# Row 3: floor-a, floor-b, floor-c, path, liquid, wall-top, wall-face, pit
T = 16

THEMES = {
    "grassland": dict(
        top=["3e8948", "63c74d", "a8e06a"], fill=["6b3e26", "8a5432", "a8714b"], fill_style="dirt",
        top_style="grass", plat=["733e39", "b86f50", "e4a672"], wall=["5a6988", "8b9bb4", "c0cbdc"],
        liquid=["0099db", "2ce8f5"], path=["a8714b", "c8a46e", "e4c08e"], accent="e43b44",
        light="feae34", deco=["tuft", "flower", "rock", "bush", "torch", "sign"]),
    "desert": dict(
        top=["c28569", "e4a672", "ead4aa"], fill=["9e5a3c", "b86f50", "d08f5f"], fill_style="strata",
        top_style="sand", plat=["733e39", "9e6a3d", "c8955f"], wall=["b86f50", "e4a672", "ead4aa"],
        liquid=["0099db", "2ce8f5"], path=["c28569", "e4a672", "ead4aa"], accent="63c74d",
        light="feae34", deco=["drygrass", "cactus", "rock", "skull", "torch", "sign"]),
    "snow": dict(
        top=["8b9bb4", "dde8f3", "ffffff"], fill=["3a4466", "4b6b9a", "6f8fbf"], fill_style="rock",
        top_style="snow", plat=["4b9fd0", "8fd3f0", "d6f4ff"], wall=["4b6b9a", "6f8fbf", "a3c4e8"],
        liquid=["8fd3f0", "d6f4ff"], path=["8b9bb4", "c0cbdc", "dde8f3"], accent="e43b44",
        light="fee761", deco=["snowtuft", "crystal", "rock", "snowbush", "lamp", "sign"]),
    "dungeon": dict(
        top=["265c42", "3e8948", "63c74d"], fill=["262b44", "3a4466", "5a6988"], fill_style="brick",
        top_style="moss", plat=["3a4466", "5a6988", "8b9bb4"], wall=["262b44", "3a4466", "5a6988"],
        liquid=["e43b44", "feae34"], path=["3a4466", "5a6988", "8b9bb4"], accent="b55088",
        light="feae34", deco=["moss", "bones", "rock", "barrel", "torch", "chain"]),
    "scifi": dict(
        top=["5a6988", "8b9bb4", "c0cbdc"], fill=["181425", "262b44", "3a4466"], fill_style="panel",
        top_style="metal", plat=["3a4466", "8b9bb4", "c0cbdc"], wall=["262b44", "3a4466", "5a6988"],
        liquid=["3e8948", "a8e06a"], path=["3a4466", "5a6988", "8b9bb4"], accent="2ce8f5",
        light="2ce8f5", deco=["cable", "screen", "vent", "pipe", "lamp", "sign"]),
}


class Tile(Canvas):
    def __init__(self):
        super().__init__(T, T)

    def wset(self, x, y, c):
        self.set(x % T, y % T, c)


def fill_texture(theme, rng, style=None, pal=None):
    t = Tile()
    pal = [hexc(c) for c in (pal or theme["fill"])]
    dark, base, light = pal
    style = style or theme["fill_style"]
    t.rect(0, 0, T, T, base)
    if style in ("dirt", "rock"):
        for _ in range(26 if style == "dirt" else 14):
            x, y = rng.randrange(T), rng.randrange(T)
            t.wset(x, y, rng.choice([dark, light]))
        for _ in range(3 if style == "dirt" else 4):
            x, y = rng.randrange(T), rng.randrange(T)
            t.wset(x, y, light)
            t.wset(x + 1, y, light)
            t.wset(x, y + 1, dark)
            t.wset(x + 1, y + 1, dark)
        if style == "rock":
            x, y = rng.randrange(T), rng.randrange(T)
            for i in range(6):
                t.wset(x + i, y + (i // 2), dark)
    elif style == "strata":
        for y in range(T):
            for x in range(T):
                band = (y + 1.5 * math.sin(x * 2 * math.pi / T)) % 8
                if band < 1:
                    t.set(x, y, dark)
                elif band < 2.2:
                    t.set(x, y, light)
        for _ in range(8):
            t.wset(rng.randrange(T), rng.randrange(T), dark)
    elif style == "brick":
        brick_rows(t, dark, base, light)
    elif style == "panel":
        t.rect(0, 0, T, T, base)
        t.rect(0, 0, T, 1, light)
        t.rect(0, 0, 1, T, light)
        t.rect(0, T - 1, T, 1, dark)
        t.rect(T - 1, 0, 1, T, dark)
        for x, y in ((2, 2), (13, 2), (2, 13), (13, 13)):
            t.set(x, y, light)
        t.rect(5, 7, 6, 2, dark)
        t.rect(5, 7, 6, 1, shade(light, 0.9))
    return t


def brick_rows(t, dark, base, light, h=4):
    t.rect(0, 0, T, T, base)
    for row in range(T // h):
        y0 = row * h
        t.rect(0, y0 + h - 1, T, 1, dark)
        off = 0 if row % 2 == 0 else T // 2
        for bx in range(0, T, 8):
            x = (bx + off) % T
            t.rect(x, y0, 1, h - 1, dark)
            t.rect((x + 1) % T, y0, 6, 1, light)


def add_top(t, theme, rng):
    dark, base, light = [hexc(c) for c in theme["top"]]
    style = theme["top_style"]
    if style in ("grass", "sand", "snow", "moss"):
        depth = {"grass": 4, "sand": 3, "snow": 5, "moss": 2}[style]
        for x in range(T):
            d = depth + rng.choice([0, 0, 1, -1]) if style != "sand" else depth + int(1.2 * math.sin(x / 2.5))
            t.rect(x, 0, 1, d, base)
            t.set(x, d, dark)
            if style in ("snow",) and rng.random() < 0.25:
                t.set(x, d + 1, dark)
        t.rect(0, 0, T, 1, light)
        for _ in range(4):
            t.set(rng.randrange(T), rng.randrange(1, depth), light)
        if style == "snow":
            for x in range(T):
                t.set(x, 1, light)
    elif style == "metal":
        t.rect(0, 0, T, 4, base)
        t.rect(0, 0, T, 1, light)
        t.rect(0, 3, T, 1, dark)
        for x in range(T):
            col = hexc("feae34") if ((x // 2) % 2 == 0) else hexc("262b44")
            t.set(x, 4, col)
            t.set((x + 1) % T, 5, col)
        t.rect(0, 6, T, 1, dark)


def edge(t, side, theme, rounded=True):
    dark = shade(hexc(theme["fill"][0]), 0.75)
    x = 0 if side == "left" else T - 1
    for y in range(T):
        if t.get(x, y)[3]:
            t.put(x, y, mix(t.get(x, y), dark, 0.6))
    if rounded:
        t.put(x, 0, CLEAR)


def platform(theme, part):
    t = Tile()
    dark, base, light = [hexc(c) for c in theme["plat"]]
    t.rect(0, 0, T, 6, base)
    t.rect(0, 0, T, 1, light)
    t.rect(0, 5, T, 1, dark)
    if theme["fill_style"] == "panel":
        for x in range(1, T, 3):
            t.rect(x, 2, 1, 2, dark)
    elif theme["top_style"] == "snow":
        t.rect(3, 2, 4, 1, light)
        t.rect(10, 3, 2, 1, light)
    else:
        t.rect(7, 1, 1, 4, dark)
        t.set(3, 3, dark)
        t.set(12, 2, dark)
    if part == "left":
        t.rect(0, 0, 1, 6, dark)
        t.put(0, 0, CLEAR)
        t.put(0, 5, CLEAR)
    if part == "right":
        t.rect(T - 1, 0, 1, 6, dark)
        t.put(T - 1, 0, CLEAR)
        t.put(T - 1, 5, CLEAR)
    if theme["top_style"] in ("grass", "moss"):
        g = hexc(theme["top"][1])
        for x in range(0, T, 5):
            t.set(x + (2 if part == "mid" else 3), 6, g)
    return t


def crate(theme):
    t = Tile()
    dark, base, light = [hexc(c) for c in theme["plat"]]
    if theme["fill_style"] == "brick":
        dark, base, light = [hexc(c) for c in theme["wall"]]
    t.rect(0, 0, T, T, base)
    t.rect(0, 0, T, 2, light)
    t.rect(0, T - 2, T, 2, dark)
    t.rect(0, 0, 2, T, light)
    t.rect(T - 2, 0, 2, T, dark)
    if theme["fill_style"] == "panel":
        t.line(3, 3, 12, 12, hexc(theme["accent"]))
        t.line(3, 12, 12, 3, hexc(theme["accent"]))
    elif theme["fill_style"] == "brick":
        t.line(4, 5, 7, 8, dark)
        t.line(7, 8, 6, 11, dark)
    elif theme["top_style"] == "snow":
        t.rect(4, 4, 3, 1, WHITE)
        t.rect(4, 4, 1, 3, WHITE)
    else:
        t.line(2, 3, 12, 13, dark)
        t.line(3, 2, 13, 12, light)
    return t


def ladder(theme):
    t = Tile()
    dark, base, light = [hexc(c) for c in theme["plat"]]
    for x in (2, 12):
        t.rect(x, 0, 2, T, base)
        t.rect(x, 0, 1, T, light)
    for y in (2, 7, 12):
        t.rect(4, y, 8, 2, base)
        t.rect(4, y + 1, 8, 1, dark)
    return t


def spikes(theme):
    t = Tile()
    metal = [hexc("5a6988"), hexc("8b9bb4"), hexc("c0cbdc")]
    for i in range(4):
        cx = i * 4
        for h in range(7):
            w = max(0, (h + 1) // 2)
            for x in range(cx + 2 - w, cx + 2 + w):
                t.set(x, 9 + h, metal[1] if x < cx + 2 else metal[0])
        t.set(cx + 1, 9, metal[2])
    t.rect(0, 15, T, 1, metal[0])
    return t


def light_source(theme, kind, rng):
    t = Tile()
    glow = hexc(theme["light"])
    if kind == "torch":
        t.rect(7, 7, 2, 7, hexc("733e39"))
        t.rect(6, 6, 4, 2, hexc("5a6988"))
        t.circle(8, 4, 2.5, hexc("f77622"))
        t.circle(8, 4.5, 1.5, glow)
        t.set(8, 1, hexc("fee761"))
    else:
        t.rect(7, 4, 2, 12, hexc("3a4466"))
        t.rect(5, 1, 6, 4, hexc("5a6988"))
        t.rect(6, 2, 4, 2, glow)
        t.rect(6, 2, 1, 1, WHITE)
    return t


def deco(theme, kind, rng):
    t = Tile()
    tdark, tbase, tlight = [hexc(c) for c in theme["top"]]
    wdark, wbase, wlight = [hexc(c) for c in theme["wall"]]
    pdark, pbase, plight = [hexc(c) for c in theme["plat"]]
    acc = hexc(theme["accent"])
    if kind in ("tuft", "drygrass", "snowtuft", "moss"):
        col = {"tuft": hexc("63c74d"), "drygrass": hexc("c8955f"),
               "snowtuft": hexc("ffffff"), "moss": hexc("3e8948")}[kind]
        for x in range(3, 13, 2):
            h = rng.randint(2, 6)
            t.rect(x, 16 - h, 1, h, col)
            t.set(x, 16 - h, shade(col, 1.3))
        return t.outlined(shade(col, 0.5)) if kind != "moss" else t
    if kind == "flower":
        t.rect(7, 9, 1, 7, hexc("3e8948"))
        t.set(6, 12, hexc("63c74d"))
        t.set(8, 11, hexc("63c74d"))
        for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            t.set(7 + dx, 7 + dy, acc)
        t.set(7, 7, hexc("fee761"))
        return t.outlined(OUTLINE)
    if kind == "cactus":
        g, gd = hexc("3e8948"), hexc("265c42")
        t.rect(6, 4, 4, 12, g)
        t.rect(3, 7, 2, 5, g)
        t.rect(3, 11, 3, 2, g)
        t.rect(11, 5, 2, 5, g)
        t.rect(10, 9, 2, 2, g)
        t.rect(9, 4, 1, 12, gd)
        t.set(7, 6, hexc("ead4aa"))
        t.set(7, 10, hexc("ead4aa"))
        return t.outlined(OUTLINE)
    if kind == "crystal":
        c1, c2 = hexc("2ce8f5"), hexc("0099db")
        for x, h in ((5, 6), (8, 10), (11, 5)):
            t.rect(x - 1, 16 - h, 3, h, c2)
            t.rect(x - 1, 16 - h, 1, h, c1)
            t.set(x, 15 - h, c1)
        return t.outlined(OUTLINE)
    if kind == "rock":
        ellipse(t, 8, 12, 5, 3.5, wbase)
        ellipse(t, 7, 11, 3, 2, wlight)
        t.set(10, 13, wdark)
        t.set(11, 12, wdark)
        return t.outlined(OUTLINE)
    if kind in ("bush", "snowbush"):
        g, gl = hexc("3e8948"), hexc("63c74d")
        ellipse(t, 5, 12, 4, 4, g)
        ellipse(t, 11, 12, 4, 4, g)
        ellipse(t, 8, 10, 4, 4, gl)
        if kind == "snowbush":
            for x in range(3, 14):
                t.set(x, 8 + abs(8 - x) // 2, WHITE)
                t.set(x, 7 + abs(8 - x) // 2, WHITE)
        else:
            t.set(7, 9, acc)
            t.set(11, 11, acc)
        return t.outlined(OUTLINE)
    if kind in ("torch", "lamp"):
        return light_source(theme, kind, rng).outlined(OUTLINE)
    if kind == "sign":
        t.rect(7, 9, 2, 7, pdark)
        t.rect(2, 3, 12, 7, pbase)
        t.rect(2, 3, 12, 1, plight)
        t.rect(4, 5, 7, 1, pdark)
        t.rect(4, 7, 5, 1, pdark)
        return t.outlined(OUTLINE)
    if kind == "skull":
        b = hexc("ead4aa")
        ellipse(t, 8, 11, 4, 3.5, b)
        t.rect(6, 13, 5, 2, b)
        t.rect(6, 11, 1, 1, OUTLINE)
        t.rect(9, 11, 1, 1, OUTLINE)
        t.set(7, 14, hexc("c28569"))
        t.set(9, 14, hexc("c28569"))
        return t.outlined(OUTLINE)
    if kind == "bones":
        b = hexc("ead4aa")
        t.line(3, 14, 12, 11, b)
        t.line(4, 11, 11, 15, b)
        for x, y in ((3, 14), (12, 11), (4, 11), (11, 15)):
            t.set(x - 1, y, b)
            t.set(x, y - 1, b)
        return t.outlined(OUTLINE)
    if kind == "barrel":
        w = [hexc("733e39"), hexc("9e6a3d"), hexc("c8955f")]
        t.rect(4, 4, 8, 12, w[1])
        t.rect(3, 6, 10, 8, w[1])
        t.rect(5, 4, 2, 12, w[2])
        for y in (6, 12):
            t.rect(3, y, 10, 1, hexc("5a6988"))
        t.rect(10, 4, 2, 12, w[0])
        return t.outlined(OUTLINE)
    if kind == "chain":
        m = hexc("8b9bb4")
        for y in range(0, 14, 3):
            t.rect(7, y, 2, 2, m)
            t.set(7 + (y // 3) % 2, y + 2, hexc("5a6988"))
        return t
    if kind == "cable":
        for x in range(T):
            y = 3 + int(5 * math.sin(math.pi * x / (T - 1)))
            t.set(x, y, hexc("262b44"))
            t.set(x, y + 1, acc if x % 4 == 0 else hexc("3a4466"))
        return t
    if kind == "screen":
        t.rect(2, 3, 12, 9, hexc("262b44"))
        t.rect(3, 4, 10, 7, hexc("0b3b4a"))
        for i, w in enumerate((6, 8, 4)):
            t.rect(4, 5 + i * 2, w, 1, acc)
        t.rect(7, 12, 2, 4, hexc("3a4466"))
        return t.outlined(OUTLINE)
    if kind == "vent":
        t.rect(2, 4, 12, 9, hexc("5a6988"))
        for y in range(5, 12, 2):
            t.rect(3, y, 10, 1, hexc("262b44"))
        return t.outlined(OUTLINE)
    if kind == "pipe":
        t.rect(5, 0, 6, T, hexc("5a6988"))
        t.rect(6, 0, 2, T, hexc("8b9bb4"))
        t.rect(4, 6, 8, 3, hexc("3a4466"))
        t.set(6, 7, acc)
        return t
    return t


def door(theme, half):
    t = Tile()
    if theme["fill_style"] == "panel":
        dark, base, light = hexc("262b44"), hexc("5a6988"), hexc("8b9bb4")
    else:
        dark, base, light = [hexc(c) for c in theme["plat"]]
    frame = hexc(theme["wall"][0])
    t.rect(1, 0, 14, T, frame)
    t.rect(3, 0, 10, T, base)
    if half == "top":
        t.rect(1, 0, 14, 2, frame)
        t.rect(3, 2, 10, 1, light)
        t.put(1, 0, CLEAR)
        t.put(14, 0, CLEAR)
        if theme["fill_style"] == "panel":
            t.rect(5, 5, 6, 4, hexc(theme["accent"]))
    else:
        t.set(11, 4, hexc("feae34"))
        t.set(11, 5, hexc("feae34"))
    if theme["fill_style"] != "panel":
        t.rect(7, 0 if half == "bottom" else 2, 1, T, dark)
    else:
        t.rect(3, 0, 10, 1, dark) if half == "bottom" else None
    return t


def floor(theme, variant, rng):
    if variant == "a":
        t = fill_texture(theme, rng, "dirt", theme["top"])
    elif variant == "b":
        t = fill_texture(theme, rng, "dirt", theme["top"])
        acc = hexc(theme["accent"])
        for _ in range(3):
            x, y = rng.randrange(1, 15), rng.randrange(1, 15)
            t.set(x, y, acc)
            t.set(x, y - 1, shade(acc, 1.3))
    elif variant == "c":
        t = Tile()
        d, b, l = [hexc(c) for c in theme["path"]]
        for y in range(T):
            for x in range(T):
                t.set(x, y, b if ((x // 8) + (y // 8)) % 2 == 0 else mix(b, d, 0.5))
        t.rect(0, 0, T, 1, l)
        t.rect(0, 8, T, 1, l)
        t.rect(0, 0, 1, T, l)
        t.rect(8, 0, 1, T, l)
    else:  # path
        t = fill_texture(theme, rng, "dirt", theme["path"])
        d, b, l = [hexc(c) for c in theme["path"]]
        for _ in range(4):
            x, y = rng.randrange(T), rng.randrange(T)
            ellipse(t, x, y, 2, 1.5, l)
            t.wset(x, y + 1, d)
    return t


def liquid(theme):
    t = Tile()
    base, light = [hexc(c) for c in theme["liquid"]]
    t.rect(0, 0, T, T, base)
    for y in range(2, T, 5):
        for x in range(T):
            if math.sin((x + y * 1.7) * 2 * math.pi / 8) > 0.6:
                t.set(x, y, light)
    t.set(3, 5, WHITE)
    t.set(11, 12, WHITE)
    return t


def gen_tilesets():
    for name, theme in THEMES.items():
        rng = random.Random(name)
        atlas = Canvas(8 * T, 4 * T)

        def put(col, row, tile):
            atlas.blit(tile, col * T, row * T)

        def top_tile(variant):
            t = fill_texture(theme, rng)
            add_top(t, theme, rng)
            if variant in ("left", "single"):
                edge(t, "left", theme)
            if variant in ("right", "single"):
                edge(t, "right", theme)
            return t

        put(0, 0, top_tile("left"))
        put(1, 0, top_tile("mid"))
        put(2, 0, top_tile("right"))
        put(3, 0, top_tile("single"))
        put(4, 0, platform(theme, "left"))
        put(5, 0, platform(theme, "mid"))
        put(6, 0, platform(theme, "right"))
        put(7, 0, crate(theme))

        fl = fill_texture(theme, rng)
        edge(fl, "left", theme, rounded=False)
        put(0, 1, fl)
        put(1, 1, fill_texture(theme, rng))
        fr = fill_texture(theme, rng)
        edge(fr, "right", theme, rounded=False)
        put(2, 1, fr)
        alt = fill_texture(theme, rng)
        for _ in range(2):
            ellipse(alt, rng.randrange(3, 13), rng.randrange(3, 13), 2, 1.5, hexc(theme["wall"][1]))
        put(3, 1, alt)
        w = Tile()
        brick_rows(w, *[hexc(c) for c in theme["wall"]])
        put(4, 1, w)
        bg = Tile()
        brick_rows(bg, *[shade(hexc(c), 0.55) for c in theme["wall"]])
        put(5, 1, bg)
        put(6, 1, ladder(theme))
        put(7, 1, spikes(theme))

        for i, kind in enumerate(theme["deco"]):
            put(i, 2, deco(theme, kind, rng))
        put(6, 2, door(theme, "top"))
        put(7, 2, door(theme, "bottom"))

        put(0, 3, floor(theme, "a", rng))
        put(1, 3, floor(theme, "b", rng))
        put(2, 3, floor(theme, "c", rng))
        put(3, 3, floor(theme, "path", rng))
        put(4, 3, liquid(theme))
        wt = Tile()
        d, b, l = [hexc(c) for c in theme["wall"]]
        wt.rect(0, 0, T, T, l)
        wt.rect(0, T - 2, T, 2, b)
        for _ in range(5):
            wt.set(rng.randrange(T), rng.randrange(T - 2), b)
        put(5, 3, wt)
        wf = Tile()
        brick_rows(wf, d, b, l)
        wf.rect(0, 0, T, 2, shade(d, 0.7))
        put(6, 3, wf)
        pit = Tile()
        pit.rect(0, 0, T, T, hexc("0b0a12"))
        pit.rect(0, 0, T, 3, shade(d, 0.6))
        put(7, 3, pit)

        save(atlas, f"tiles/{name}_tileset.png")


# ---------------------------------------------------------------------------
# Items
# ---------------------------------------------------------------------------
HEART = [
    "..rrr.rrr..",
    ".rwrrrrrrr.",
    ".rwrrrrrrr.",
    ".rrrrrrrrR.",
    "..rrrrrrR..",
    "...rrrrR...",
    "....rrR....",
    ".....r.....",
]
GEM = [
    "..lllll..",
    ".lwllmmm.",
    "lllllmmmd",
    ".lllmmmd.",
    "..llmmd..",
    "...lmd...",
    "....d....",
]
KEY = [
    ".yyyy.......",
    "yy..yyyyyyyy",
    "yd..dddddddd",
    ".dddd...y.y.",
    "........y...",
]
POTION = [
    "..cccc..",
    "...gg...",
    "...gg...",
    "..gllg..",
    ".gwlllg.",
    "gwllllLg",
    "gllllLLg",
    "gLLLLLLg",
    ".gLLLLg.",
    "..gggg..",
]
CHEST_CLOSED = [
    ".llllllllllll.",
    "lbbbbbbbbbbbbl",
    "lbbbbbbbbbbbbl",
    "mmmmmmyymmmmmm",
    "lbbbbbyybbbbbl",
    "lbbbbbbbbbbbbl",
    "lbbbbbbbbbbbbl",
    "lddddddddddddl",
    "mmmmmmmmmmmmmm",
]
CHEST_OPEN = [
    ".llllllllllll.",
    "lddddddddddddl",
    "mmmmmmmmmmmmmm",
    "lyyYyyyYyyyyYl",
    "mmmmmmmmmmmmmm",
    "lbbbbbbbbbbbbl",
    "lbbbbbbbbbbbbl",
    "lddddddddddddl",
    "mmmmmmmmmmmmmm",
]
STAR = [
    ".....y.....",
    "....yyy....",
    "yyyyywyyyyy",
    ".yyywyyyyy.",
    "..yyyyyyy..",
    "..yyyyyyy..",
    ".yyyy.yyyy.",
    ".yy.....yy.",
]
BOMB = [
    "......s.",
    ".....f..",
    "....f...",
    "..bbbb..",
    ".bwbbbb.",
    "bwbbbbbb",
    "bbbbbbbb",
    "bbbbbbbB",
    ".bbbbBB.",
    "..bBBB..",
]
SHIELD = [
    "mmmmmmmmmm",
    "mrrrryyyym",
    "mrrrryyyym",
    "mrrrryyyym",
    "myyyyrrrrm",
    "myyyyrrrrm",
    ".myyyrrrm.",
    "..myyrrm..",
    "...mmmm...",
]
MUSHROOM = [
    "...rrrr...",
    ".rrwwrrrr.",
    "rrwwrrrwwr",
    "rrrrrrrwwr",
    "Rrrrwwrrrr",
    ".RRRRRRRR.",
    "...ssss...",
    "...ssss...",
    "...SSSS...",
]
APPLE = [
    "....b.gg.",
    "....bgg..",
    ".rrrbrrr.",
    "rwrrrrrrr",
    "rwrrrrrrr",
    "rrrrrrrrR",
    "rrrrrrrRR",
    ".rrrrrRR.",
    "..rr.rR..",
]
BATTERY = [
    "...mm...",
    ".mmmmmm.",
    ".mgwggm.",
    ".mggggm.",
    ".mggggm.",
    ".mGGGGm.",
    ".mGGGGm.",
    ".mmmmmm.",
]
SCROLL = [
    ".pppppppp.",
    "pPPPPPPPPp",
    ".pppppppp.",
    ".pddddddp.",
    ".pppppppp.",
    ".pddddp.p.",
    ".pppppppp.",
    "pPPPPPPPPp",
    ".pppppppp.",
]


def centered(rows, pal, w=16, h=16, outline=True):
    c = Canvas(w, h)
    ox = (w - len(rows[0])) // 2
    oy = (h - len(rows)) // 2
    c.ascii(rows, pal, ox, oy)
    return c.outlined(OUTLINE) if outline else c


def gen_items():
    red = {"r": hexc("e43b44"), "R": hexc("a22633"), "w": hexc("ffffff")}
    save(centered(HEART, red), "items/heart.png")

    gems = {"red": ("ff6b6b", "e43b44", "a22633"), "blue": ("6fd3ff", "0099db", "124e89"),
            "green": ("a8e06a", "63c74d", "265c42"), "purple": ("e08fd9", "b55088", "68386c"),
            "yellow": ("fff3a0", "fee761", "f77622")}
    for n, (l, m, d) in gems.items():
        save(centered(GEM, {"l": hexc(l), "m": hexc(m), "d": hexc(d), "w": WHITE}), f"items/gem_{n}.png")

    for n, (y, d) in {"gold": ("fee761", "f77622"), "silver": ("e5e5e5", "8b9bb4"),
                      "red": ("ff6b6b", "a22633")}.items():
        save(centered(KEY, {"y": hexc(y), "d": hexc(d)}), f"items/key_{n}.png")

    for n, (l, L) in {"red": ("e43b44", "a22633"), "blue": ("0099db", "124e89"),
                      "green": ("63c74d", "265c42"), "purple": ("b55088", "68386c")}.items():
        pal = {"c": hexc("b86f50"), "g": hexc("c0cbdc"), "w": WHITE, "l": hexc(l), "L": hexc(L)}
        save(centered(POTION, pal), f"items/potion_{n}.png")

    wood = {"l": hexc("e4a672"), "b": hexc("b86f50"), "d": hexc("733e39"), "m": hexc("8b9bb4"),
            "y": hexc("fee761"), "Y": hexc("f77622")}
    save(centered(CHEST_CLOSED, wood), "items/chest_closed.png")
    save(centered(CHEST_OPEN, wood), "items/chest_open.png")
    save(centered(STAR, {"y": hexc("fee761"), "w": WHITE}), "items/star.png")
    save(centered(BOMB, {"b": hexc("3a4466"), "B": hexc("262b44"), "w": hexc("8b9bb4"),
                         "f": hexc("c28569"), "s": hexc("feae34")}), "items/bomb.png")
    save(centered(SHIELD, {"m": hexc("8b9bb4"), "r": hexc("3b5dc9"), "y": hexc("fee761")}), "items/shield.png")
    save(centered(MUSHROOM, {"r": hexc("e43b44"), "R": hexc("a22633"), "w": WHITE,
                             "s": hexc("ead4aa"), "S": hexc("c28569")}), "items/mushroom.png")
    save(centered(APPLE, {"r": hexc("e43b44"), "R": hexc("a22633"), "w": WHITE,
                          "b": hexc("733e39"), "g": hexc("63c74d")}), "items/apple.png")
    save(centered(BATTERY, {"m": hexc("5a6988"), "g": hexc("a8e06a"), "G": hexc("63c74d"),
                            "w": WHITE}), "items/battery.png")
    save(centered(SCROLL, {"p": hexc("ead4aa"), "P": hexc("c28569"), "d": hexc("8b9bb4")}), "items/scroll.png")

    # sword (procedural)
    s = Canvas(16, 16)
    s.line(4, 11, 12, 3, hexc("e5e5e5"))
    s.line(5, 11, 12, 4, hexc("8b9bb4"))
    s.set(12, 3, WHITE)
    s.line(2, 9, 6, 13, hexc("feae34"))
    s.line(2, 13, 4, 11, hexc("733e39"))
    s.set(1, 14, hexc("feae34"))
    save(s.outlined(OUTLINE), "items/sword.png")

    # bow
    b = Canvas(16, 16)
    for y in range(2, 14):
        x = 10 - int(5 * math.sin(math.pi * (y - 2) / 11))
        b.set(x, y, hexc("b86f50"))
        b.set(x + 1, y, hexc("733e39"))
    b.line(10, 2, 10, 13, hexc("e5e5e5"))
    save(b.outlined(OUTLINE), "items/bow.png")

    # coin spin (4 frames)
    frames = []
    for w in (5, 3.5, 1, 3.5):
        c = Canvas(16, 16)
        ellipse(c, 8, 8, w, 5, hexc("f77622"))
        ellipse(c, 8 - (0.5 if w > 1 else 0), 7.6, max(0.6, w - 1), 4.2, hexc("feae34"))
        if w > 3:
            c.rect(8, 5, 1, 5, hexc("fee761"))
        frames.append(c.outlined(OUTLINE))
    save(sheet(frames), "items/coin.png")
    register("items/coin.png", 16, 16, {"spin": ([0, 1, 2, 3], 8.0, True)})

    # flag (checkpoint) - 4 frame wave
    frames = []
    for i in range(4):
        c = Canvas(16, 16)
        c.rect(3, 1, 1, 15, hexc("8b9bb4"))
        for x in range(4, 13):
            dy = int(round(math.sin((x + i * 2) * 0.8)))
            c.rect(x, 2 + dy, 1, 6, hexc("e43b44") if x < 12 else hexc("a22633"))
        c.rect(2, 15, 3, 1, hexc("5a6988"))
        frames.append(c.outlined(OUTLINE))
    save(sheet(frames), "items/flag.png")
    register("items/flag.png", 16, 16, {"wave": ([0, 1, 2, 3], 8.0, True)})

    # spring (idle / compressed / extended)
    frames = []
    for h in (6, 3, 9):
        c = Canvas(16, 16)
        c.rect(2, 14, 12, 2, hexc("5a6988"))
        for i in range(h):
            y = 13 - i
            c.rect(4 if i % 2 else 5, y, 7, 1, hexc("c0cbdc") if i % 2 else hexc("8b9bb4"))
        c.rect(2, 13 - h, 12, 2, hexc("e43b44"))
        frames.append(c.outlined(OUTLINE))
    save(sheet(frames), "items/spring.png")
    register("items/spring.png", 16, 16, {"idle": ([0], 1.0, False), "bounce": ([1, 2, 0], 14.0, False)})


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
def gen_ui():
    red = {"r": hexc("e43b44"), "R": hexc("a22633"), "w": WHITE}
    full = centered(HEART, red)
    save(full, "ui/heart_full.png")
    empty = centered(HEART, {"r": hexc("3a4466"), "R": hexc("262b44"), "w": hexc("5a6988")})
    save(empty, "ui/heart_empty.png")
    half = Canvas(16, 16)
    half.blit(empty, 0, 0)
    for y in range(16):
        for x in range(8):
            if full.get(x, y)[3]:
                half.put(x, y, full.get(x, y))
    save(half, "ui/heart_half.png")

    def box(w, h, base, light, dark, border=OUTLINE, inset=False):
        c = Canvas(w, h)
        c.rect(1, 1, w - 2, h - 2, base)
        c.rect(1, 0, w - 2, 1, border)
        c.rect(1, h - 1, w - 2, 1, border)
        c.rect(0, 1, 1, h - 2, border)
        c.rect(w - 1, 1, 1, h - 2, border)
        hi, lo = (dark, light) if inset else (light, dark)
        c.rect(1, 1, w - 2, 1, hi)
        c.rect(1, h - 2, w - 2, 1, lo)
        c.rect(1, h - 3, w - 2, 1, lo) if not inset else None
        return c

    save(box(24, 16, hexc("3b5dc9"), hexc("6fa8ff"), hexc("124e89")), "ui/button_normal.png")
    save(box(24, 16, hexc("4f7fe8"), hexc("a3c8ff"), hexc("3b5dc9")), "ui/button_hover.png")
    save(box(24, 16, hexc("124e89"), hexc("3b5dc9"), hexc("0b2a4d"), inset=True), "ui/button_pressed.png")
    save(box(24, 16, hexc("5a6988"), hexc("8b9bb4"), hexc("3a4466")), "ui/button_disabled.png")

    p = box(24, 24, hexc("262b44"), hexc("5a6988"), hexc("181425"))
    p.rect(2, 2, 20, 20, hexc("262b44"))
    p.rect(2, 2, 20, 1, hexc("3a4466"))
    save(p, "ui/panel.png")
    p2 = box(24, 24, hexc("ead4aa"), hexc("ffffff"), hexc("c28569"))
    save(p2, "ui/panel_light.png")

    frame = Canvas(48, 8)
    frame.rect(1, 0, 46, 8, OUTLINE)
    frame.rect(0, 1, 48, 6, OUTLINE)
    frame.rect(1, 1, 46, 6, hexc("3a4466"))
    frame.rect(2, 2, 44, 4, hexc("262b44"))
    save(frame, "ui/bar_frame.png")
    for n, (b, l) in {"red": ("e43b44", "ff6b6b"), "green": ("63c74d", "a8e06a"),
                      "blue": ("0099db", "6fd3ff"), "yellow": ("feae34", "fee761")}.items():
        f = Canvas(48, 8)
        f.rect(2, 2, 44, 4, hexc(b))
        f.rect(2, 2, 44, 1, hexc(l))
        save(f, f"ui/bar_fill_{n}.png")

    cur = Canvas(12, 12)
    for y in range(10):
        for x in range(min(y + 1, 7 if y < 7 else 10 - y)):
            cur.set(x + 1, y + 1, WHITE)
    save(cur.outlined(OUTLINE), "ui/cursor.png")

    ch = Canvas(16, 16)
    for i in list(range(1, 6)) + list(range(10, 15)):
        ch.set(i, 7, WHITE)
        ch.set(7, i, WHITE)
    ch.set(7, 7, hexc("e43b44"))
    save(ch.outlined(OUTLINE), "ui/crosshair.png")

    for on in (False, True):
        cb = box(10, 10, hexc("262b44"), hexc("3a4466"), hexc("181425"), inset=True)
        if on:
            cb.line(2, 5, 4, 7, hexc("a8e06a"))
            cb.line(4, 7, 7, 2, hexc("a8e06a"))
        save(cb, f"ui/checkbox_{'on' if on else 'off'}.png")

    arrow = Canvas(8, 8)
    for x in range(4):
        arrow.rect(2 + x, 1 + x, 1, 6 - 2 * x, WHITE)
    save(arrow.outlined(OUTLINE), "ui/arrow_right.png")
    save(arrow.outlined(OUTLINE).flipped(), "ui/arrow_left.png")

    coin_icon = Canvas(8, 8)
    ellipse(coin_icon, 4, 4, 3, 3, hexc("feae34"))
    coin_icon.rect(4, 2, 1, 4, hexc("fee761"))
    save(coin_icon.outlined(OUTLINE), "ui/icon_coin.png")


# ---------------------------------------------------------------------------
# Effects & projectiles
# ---------------------------------------------------------------------------
def gen_effects():
    # explosion 32x32, 8 frames
    frames = []
    cols = [hexc("ffffff"), hexc("fee761"), hexc("feae34"), hexc("f77622"), hexc("e43b44"), hexc("5a6988")]
    rng = random.Random(7)
    puffs = [(rng.uniform(-6, 6), rng.uniform(-6, 6), rng.uniform(3, 6)) for _ in range(7)]
    for i in range(8):
        c = Canvas(32, 32)
        t = i / 7
        for px, py, r in puffs:
            rr = r * (0.5 + t * 1.2) * (1 - t * 0.6)
            ci = min(len(cols) - 1, int(t * 5.5))
            c.circle(16 + px * (0.5 + t), 16 + py * (0.5 + t) - t * 3, rr, cols[ci])
            if rr > 2:
                c.circle(16 + px * (0.5 + t) - 1, 16 + py * (0.5 + t) - t * 3 - 1, rr * 0.5,
                         cols[max(0, ci - 1)])
        frames.append(c)
    save(sheet(frames), "effects/explosion.png")
    register("effects/explosion.png", 32, 32, {"default": (list(range(8)), 16.0, False)})

    def sheet16(name, n, draw, fps, loop=False, size=16):
        fr = []
        for i in range(n):
            c = Canvas(size, size)
            draw(c, i, n)
            fr.append(c)
        save(sheet(fr), f"effects/{name}.png")
        register(f"effects/{name}.png", size, size, {"default": (list(range(n)), fps, loop)})

    def dust(c, i, n):
        t = i / (n - 1)
        for dx in (-4, 0, 4):
            c.circle(8 + dx * (1 + t), 12 - t * 3, 2.5 * (1 - t) + 0.5, mix(hexc("e5e5e5"), hexc("8b9bb4"), t))

    def sparkle(c, i, n):
        r = [1, 3, 5, 2][i]
        col = [WHITE, hexc("fee761"), hexc("fee761"), hexc("feae34")][i]
        for k in range(-r, r + 1):
            c.set(8 + k, 8, col)
            c.set(8, 8 + k, col)
        if i in (1, 2):
            for d in (1, 2):
                for sx, sy in ((1, 1), (-1, -1), (1, -1), (-1, 1)):
                    c.set(8 + d * sx, 8 + d * sy, WHITE)

    def hit(c, i, n):
        r = [2, 4, 6, 7][i]
        for a in range(8):
            ang = a * math.pi / 4 + 0.3
            x0, y0 = 8 + math.cos(ang) * (r - 3), 8 + math.sin(ang) * (r - 3)
            x1, y1 = 8 + math.cos(ang) * r, 8 + math.sin(ang) * r
            c.line(int(x0), int(y0), int(x1), int(y1), WHITE if i < 2 else hexc("fee761"))
        if i == 0:
            c.circle(8, 8, 3, WHITE)

    def smoke(c, i, n):
        t = i / (n - 1)
        g = mix(hexc("c0cbdc"), hexc("5a6988"), t)
        c.circle(8, 11 - t * 7, 3 + t * 3, g)
        c.circle(6, 12 - t * 6, 2 + t * 2, shade(g, 1.15))

    def magic(c, i, n):
        t = i / (n - 1)
        r = 2 + t * 12
        col = mix(hexc("e08fd9"), hexc("68386c"), t)
        for a in range(16):
            ang = a * math.pi / 8 + t
            c.set(int(16 + math.cos(ang) * r), int(16 + math.sin(ang) * r), col)
            c.set(int(16 + math.cos(ang) * r * 0.6), int(16 + math.sin(ang) * r * 0.6), WHITE)
        if i < 3:
            c.circle(16, 16, 4 - i, WHITE)

    def blood(c, i, n):
        rng2 = random.Random(3)
        t = i / (n - 1)
        for _ in range(9):
            a = rng2.uniform(0, math.tau)
            d = rng2.uniform(2, 7) * (0.3 + t)
            c.circle(8 + math.cos(a) * d, 8 + math.sin(a) * d + t * t * 4, 1.4 * (1 - t * 0.5),
                     hexc("e43b44") if rng2.random() > 0.3 else hexc("a22633"))

    def heal(c, i, n):
        for k, (x, y0) in enumerate(((4, 14), (8, 12), (12, 15))):
            y = y0 - i * 2 - k
            col = hexc("a8e06a") if k != 1 else hexc("63c74d")
            c.rect(x - 1, y, 3, 1, col)
            c.rect(x, y - 1, 1, 3, col)

    sheet16("dust", 5, dust, 14)
    sheet16("sparkle", 4, sparkle, 12)
    sheet16("hit", 4, hit, 18)
    sheet16("smoke", 6, smoke, 10)
    sheet16("magic_burst", 6, magic, 14, size=32)
    sheet16("splat", 5, blood, 14)
    sheet16("heal", 5, heal, 10, loop=True)


def gen_projectiles():
    b = Canvas(8, 8)
    b.circle(4, 4, 2.5, hexc("fee761"))
    b.set(3, 3, WHITE)
    save(b.outlined(OUTLINE), "projectiles/bullet.png")

    for name, (c1, c2) in {"laser_blue": ("2ce8f5", "ffffff"), "laser_red": ("e43b44", "ffb3b3"),
                           "laser_green": ("63c74d", "e0ffc0")}.items():
        l = Canvas(16, 4)
        l.rect(0, 0, 16, 4, hexc(c1))
        l.rect(1, 1, 14, 2, hexc(c2))
        l.put(0, 0, CLEAR)
        l.put(0, 3, CLEAR)
        l.put(15, 0, CLEAR)
        l.put(15, 3, CLEAR)
        save(l, f"projectiles/{name}.png")

    a = Canvas(16, 5)
    a.rect(2, 2, 11, 1, hexc("b86f50"))
    a.line(12, 0, 15, 2, hexc("c0cbdc"))
    a.line(12, 4, 15, 2, hexc("c0cbdc"))
    a.rect(12, 1, 2, 3, hexc("c0cbdc"))
    a.rect(0, 1, 3, 1, hexc("e5e5e5"))
    a.rect(0, 3, 3, 1, hexc("e5e5e5"))
    save(a, "projectiles/arrow.png")

    frames = []
    for i in range(4):
        c = Canvas(16, 16)
        for k in range(4):
            c.circle(6 - k * 1.5 + (i % 2) * 0.5, 8 + math.sin(i + k) * 1, 3 - k * 0.6,
                     [hexc("f77622"), hexc("feae34"), hexc("e43b44"), hexc("a22633")][k])
        c.circle(10, 8, 3.5, hexc("feae34"))
        c.circle(10.5, 7.5, 2, hexc("fee761"))
        c.set(11, 7, WHITE)
        frames.append(c)
    save(sheet(frames), "projectiles/fireball.png")
    register("projectiles/fireball.png", 16, 16, {"default": ([0, 1, 2, 3], 12.0, True)})

    frames = []
    for i in range(4):
        c = Canvas(12, 12)
        r = 3.5 + (0.6 if i % 2 else 0)
        c.circle(6, 6, r + 1, hexc("68386c"))
        c.circle(6, 6, r, hexc("b55088"))
        c.circle(6, 6, r - 1.5, hexc("e08fd9"))
        c.set(5, 5, WHITE)
        ang = i * math.pi / 2
        c.set(int(6 + math.cos(ang) * 5), int(6 + math.sin(ang) * 5), hexc("e08fd9"))
        frames.append(c)
    save(sheet(frames), "projectiles/magic_orb.png")
    register("projectiles/magic_orb.png", 12, 12, {"default": ([0, 1, 2, 3], 10.0, True)})

    frames = []
    for i in range(4):
        c = Canvas(12, 12)
        c.circle(6, 6, 4.5, hexc("0099db"))
        c.circle(6, 6, 3, hexc("2ce8f5"))
        c.circle(6, 6, 1.5, WHITE)
        for k in range(3):
            ang = i * 0.8 + k * 2.1
            c.set(int(6 + math.cos(ang) * 5.5), int(6 + math.sin(ang) * 5.5), WHITE)
        frames.append(c)
    save(sheet(frames), "projectiles/energy_ball.png")
    register("projectiles/energy_ball.png", 12, 12, {"default": ([0, 1, 2, 3], 12.0, True)})


# ---------------------------------------------------------------------------
# Parallax backgrounds (320x180, horizontally tileable)
# ---------------------------------------------------------------------------
BW, BH = 320, 180


def periodic_noise(seed, octaves=((2, 1.0), (5, 0.5), (11, 0.25), (23, 0.12))):
    rng = random.Random(seed)
    phases = [(f, a, rng.uniform(0, math.tau)) for f, a in octaves]

    def h(x):
        return sum(a * math.sin(2 * math.pi * f * x / BW + p) for f, a, p in phases)
    return h


def silhouette(c, base_y, amp, col, seed, cap=None, cap_depth=4, highlight=None, octaves=None):
    h = periodic_noise(seed, octaves) if octaves else periodic_noise(seed)
    for x in range(BW):
        top = int(base_y - amp * h(x))
        for y in range(max(0, top), BH):
            c.set(x, y, col)
        if cap and top < base_y - amp * 0.3:
            for y in range(top, top + cap_depth):
                c.set(x, y, cap)
        if highlight:
            c.set(x, top, highlight)


def gradient(c, top, bottom):
    for y in range(BH):
        col = mix(top, bottom, y / (BH - 1))
        c.rect(0, y, BW, 1, col)


def clouds(c, seed, col, n=6, y_range=(15, 70)):
    rng = random.Random(seed)
    for _ in range(n):
        cx, cy = rng.randrange(BW), rng.randrange(*y_range)
        for k in range(5):
            r = rng.uniform(5, 10)
            dx = rng.uniform(-14, 14)
            for ox in (-BW, 0, BW):
                c.circle(cx + dx + ox, cy + rng.uniform(-2, 2), r, col)


def stars(c, seed, n, cols):
    rng = random.Random(seed)
    for _ in range(n):
        c.set(rng.randrange(BW), rng.randrange(BH - 40), rng.choice(cols))


def gen_backgrounds():
    # grassland
    sky = Canvas(BW, BH)
    gradient(sky, hexc("4fa4e8"), hexc("cbeaf5"))
    clouds(sky, 1, hexc("ffffff", 230))
    far = Canvas(BW, BH)
    silhouette(far, 110, 25, hexc("7fb2c9"), 2, cap=hexc("e5f2f8"), cap_depth=3)
    near = Canvas(BW, BH)
    silhouette(near, 140, 12, hexc("3e8948"), 3, highlight=hexc("63c74d"))
    write_bg("grassland", sky, far, near)

    # desert
    sky = Canvas(BW, BH)
    gradient(sky, hexc("f77622"), hexc("fde6b5"))
    sky.circle(240, 60, 22, hexc("fee761", 200))
    sky.circle(240, 60, 16, hexc("fff6c4"))
    far = Canvas(BW, BH)
    silhouette(far, 120, 14, hexc("e0915a"), 4, octaves=((2, 1.0), (3, 0.6)))
    near = Canvas(BW, BH)
    silhouette(near, 145, 10, hexc("b86f50"), 5, highlight=hexc("e4a672"), octaves=((3, 1.0), (4, 0.4)))
    write_bg("desert", sky, far, near)

    # snow
    sky = Canvas(BW, BH)
    gradient(sky, hexc("6f8fbf"), hexc("e6f0fa"))
    stars(sky, 6, 60, [hexc("ffffff", 200)])
    far = Canvas(BW, BH)
    silhouette(far, 105, 35, hexc("8b9bb4"), 7, cap=hexc("ffffff"), cap_depth=6)
    near = Canvas(BW, BH)
    silhouette(near, 140, 10, hexc("dde8f3"), 8, highlight=hexc("ffffff"))
    write_bg("snow", sky, far, near)

    # dungeon
    sky = Canvas(BW, BH)
    gradient(sky, hexc("0b0a12"), hexc("262b44"))
    far = Canvas(BW, BH)
    for x in range(0, BW, 64):
        far.rect(x + 20, 0, 24, BH, hexc("1e2238"))
        far.rect(x + 18, 30, 28, 6, hexc("2a2f4e"))
        far.rect(x + 18, 140, 28, 6, hexc("2a2f4e"))
        for y in range(0, BH, 12):
            far.rect(x + 20, y, 24, 1, hexc("181c30"))
    near = Canvas(BW, BH)
    for x in range(0, BW, 80):
        for y in range(0, 60, 4):
            near.rect(x + 40, y, 2, 3, hexc("3a4466"))
        near.circle(x + 41, 64, 3, hexc("feae34", 160))
        near.circle(x + 41, 64, 1.5, hexc("fee761"))
    near.rect(0, 165, BW, 15, hexc("1a1d30"))
    write_bg("dungeon", sky, far, near)

    # scifi
    sky = Canvas(BW, BH)
    gradient(sky, hexc("0b0a1e"), hexc("3a1f5a"))
    stars(sky, 9, 140, [hexc("ffffff"), hexc("2ce8f5"), hexc("fee761")])
    sky.circle(70, 50, 26, hexc("b55088"))
    sky.circle(64, 45, 20, hexc("e08fd9"))
    for x in range(30, 112):
        sky.set(x, 52 + (x - 70) // 6, hexc("ffffff", 120))
    far = Canvas(BW, BH)
    rng = random.Random(10)
    x = 0
    while x < BW:
        w, h = rng.randrange(14, 30), rng.randrange(40, 90)
        far.rect(x, BH - h, w, h, hexc("1e1a3a"))
        x += w + rng.randrange(0, 4)
    near = Canvas(BW, BH)
    x = 0
    while x < BW:
        w, h = rng.randrange(18, 36), rng.randrange(25, 60)
        w = min(w, BW - x)
        near.rect(x, BH - h, w, h, hexc("120f26"))
        for wy in range(BH - h + 4, BH - 4, 6):
            for wx in range(x + 3, x + w - 3, 5):
                if rng.random() < 0.4:
                    near.rect(wx, wy, 2, 2, rng.choice([hexc("feae34"), hexc("2ce8f5")]))
        x += w + rng.randrange(2, 8)
    write_bg("scifi", sky, far, near)


def write_bg(name, sky, far, near):
    save(sky, f"backgrounds/{name}_sky.png")
    save(far, f"backgrounds/{name}_far.png")
    save(near, f"backgrounds/{name}_near.png")


def run():
    gen_characters()
    gen_slimes()
    gen_bat()
    gen_ghost()
    gen_drone()
    gen_eyeball()
    gen_spider()
    gen_tilesets()
    gen_items()
    gen_ui()
    gen_effects()
    gen_projectiles()
    gen_backgrounds()


if __name__ == "__main__":
    run()
    print(f"sprites done, {len(MANIFEST)} animated sheets")
