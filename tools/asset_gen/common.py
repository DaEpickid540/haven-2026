"""Shared helpers: tiny PNG writer, RGBA canvas, WAV writer. Stdlib only."""
import os
import struct
import wave
import zlib
from array import array

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ASSETS = os.path.join(ROOT, "assets")


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def mix(c1, c2, t):
    return tuple(int(round(c1[i] + (c2[i] - c1[i]) * t)) for i in range(4))


def shade(c, f):
    """f < 1 darkens, f > 1 lightens (towards white)."""
    if f <= 1:
        return (int(c[0] * f), int(c[1] * f), int(c[2] * f), c[3])
    t = f - 1
    return mix(c, (255, 255, 255, c[3]), t)


CLEAR = (0, 0, 0, 0)


class Canvas:
    def __init__(self, w, h, fill=CLEAR):
        self.w, self.h = w, h
        self.px = [fill] * (w * h)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y * self.w + x]
        return CLEAR

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            if c[3] == 255 or c[3] == 0:
                if c[3] == 255:
                    self.px[y * self.w + x] = c
            else:  # alpha blend
                d = self.px[y * self.w + x]
                a = c[3] / 255
                out_a = a + d[3] / 255 * (1 - a)
                if out_a <= 0:
                    return
                col = tuple(
                    int((c[i] * a + d[i] * (d[3] / 255) * (1 - a)) / out_a) for i in range(3)
                )
                self.px[y * self.w + x] = col + (int(out_a * 255),)

    def put(self, x, y, c):
        """Overwrite without blending (can write transparency)."""
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = c

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def circle(self, cx, cy, r, c):
        for yy in range(int(cy - r - 1), int(cy + r + 2)):
            for xx in range(int(cx - r - 1), int(cx + r + 2)):
                if (xx - cx + 0.5) ** 2 + (yy - cy + 0.5) ** 2 <= r * r:
                    self.set(xx, yy, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.set(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                c = other.px[y * other.w + x]
                if c[3]:
                    self.set(ox + x, oy + y, c)

    def ascii(self, rows, palette, ox=0, oy=0):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                c = palette.get(ch)
                if c is not None:
                    self.set(ox + x, oy + y, c)

    def flipped(self):
        out = Canvas(self.w, self.h)
        for y in range(self.h):
            for x in range(self.w):
                out.px[y * self.w + x] = self.px[y * self.w + (self.w - 1 - x)]
        return out

    def outlined(self, color, diagonal=False):
        out = Canvas(self.w, self.h)
        out.px = list(self.px)
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diagonal:
            nb += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x, y)[3] == 0 and any(self.get(x + dx, y + dy)[3] for dx, dy in nb):
                    out.px[y * self.w + x] = color
        return out

    def recolor(self, mapping):
        out = Canvas(self.w, self.h)
        out.px = [mapping.get(p, p) for p in self.px]
        return out

    def scaled(self, k):
        out = Canvas(self.w * k, self.h * k)
        for y in range(out.h):
            for x in range(out.w):
                out.px[y * out.w + x] = self.px[(y // k) * self.w + (x // k)]
        return out

    def save(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            for c in self.px[y * self.w:(y + 1) * self.w]:
                raw.extend(c)

        def chunk(t, d):
            return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

        data = b"\x89PNG\r\n\x1a\n"
        data += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        data += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        data += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(data)


def sheet(frames, cols=None):
    """Pack equally sized canvases into a horizontal (or grid) strip."""
    fw, fh = frames[0].w, frames[0].h
    cols = cols or len(frames)
    rows = (len(frames) + cols - 1) // cols
    out = Canvas(fw * cols, fh * rows)
    for i, f in enumerate(frames):
        out.blit(f, (i % cols) * fw, (i // cols) * fh)
    return out


SAMPLE_RATE = 44100


def write_wav(path, samples, rate=SAMPLE_RATE, normalize=0.89):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    k = normalize / peak if normalize else 1.0
    pcm = array("h", (max(-32767, min(32767, int(s * k * 32767))) for s in samples))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())


def rel(path):
    return os.path.relpath(path, ROOT).replace("\\", "/")
