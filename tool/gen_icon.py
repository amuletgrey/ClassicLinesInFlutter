"""Generates the app launcher icon: a diagonal line of shaded balls on the dark
board background. Matches the in-app ball look (see lib/ball.dart).

    ICON_DIR=assets/icon python tool/gen_icon.py

Outputs:
    icon.png             opaque 1024 square (iOS / web / legacy Android)
    icon_foreground.png  transparent, balls in the adaptive-icon safe zone (Android)
"""
import math
import os

from PIL import Image, ImageDraw

SS = 2                       # supersample, downscaled at the end for crisp edges
BASE = 1024
N = BASE * SS
OUT = os.environ.get("ICON_DIR", "assets/icon")
os.makedirs(OUT, exist_ok=True)

BG_TOP = (0x2C, 0x33, 0x45)
BG_BOT = (0x16, 0x1A, 0x23)
# A subset of the 7 game colors, in play order down the diagonal.
BALLS = [(0xE5, 0x4B, 0x4B), (0xF5, 0xC1, 0x42), (0x4C, 0xAF, 0x50), (0x42, 0x8B, 0xF5)]


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


def draw_ball(img, cx, cy, r, color):
    """A radial-gradient ball lit from the upper-left, matching lib/ball.dart."""
    light = lerp(color, (255, 255, 255), 0.45)
    dark = lerp(color, (0, 0, 0), 0.30)
    hx, hy = cx - 0.35 * r, cy - 0.40 * r          # highlight center (app Alignment)
    grad_r = r * 0.95
    x0, y0 = int(cx - r - 2), int(cy - r - 2)
    x1, y1 = int(cx + r + 2), int(cy + r + 2)
    w, h = x1 - x0, y1 - y0
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = layer.load()
    for j in range(h):
        for i in range(w):
            gx, gy = x0 + i, y0 + j
            edge = clamp(r - math.hypot(gx - cx, gy - cy), 0.0, 1.0)  # AA alpha
            if edge <= 0:
                continue
            p = clamp(math.hypot(gx - hx, gy - hy) / grad_r, 0.0, 1.0)
            if p < 0.55:
                col = lerp(light, color, p / 0.55)
            else:
                col = lerp(color, dark, (p - 0.55) / 0.45)
            px[i, j] = (int(col[0]), int(col[1]), int(col[2]), int(edge * 255))
    img.alpha_composite(layer, (x0, y0))


def diagonal_centers(scale=1.0, cx0=0.5, cy0=0.5):
    """Four ball centers along the lower-left -> upper-right diagonal."""
    fx = [0.24, 0.41, 0.59, 0.76]
    fy = [0.76, 0.59, 0.41, 0.24]
    pts = []
    for x, y in zip(fx, fy):
        pts.append(((cx0 + (x - 0.5) * scale) * N, (cy0 + (y - 0.5) * scale) * N))
    return pts


def make_full():
    img = Image.new("RGBA", (N, N), (0, 0, 0, 255))
    # vertical background gradient, corner to corner
    grad = Image.new("RGB", (1, N))
    for y in range(N):
        grad.putpixel((0, y), tuple(int(v) for v in lerp(BG_TOP, BG_BOT, y / N)))
    img.paste(grad.resize((N, N)), (0, 0))
    r = 0.118 * N
    for (cx, cy), color in zip(diagonal_centers(scale=1.0), BALLS):
        draw_ball(img, cx, cy, r, color)
    return img.resize((BASE, BASE), Image.LANCZOS)


def make_foreground():
    # Transparent; balls pulled into the central safe zone (~66%) for adaptive icons.
    img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    r = 0.098 * N
    for (cx, cy), color in zip(diagonal_centers(scale=0.66), BALLS):
        draw_ball(img, cx, cy, r, color)
    return img.resize((BASE, BASE), Image.LANCZOS)


make_full().save(os.path.join(OUT, "icon.png"))
print("wrote icon.png")
make_foreground().save(os.path.join(OUT, "icon_foreground.png"))
print("wrote icon_foreground.png")
