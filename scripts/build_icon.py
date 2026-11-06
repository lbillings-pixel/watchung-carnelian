"""Stylised carnelian pebble for the intro screen and the executable icon (Illustrative artwork, not a photograph).

Draws a subrounded pebble (the paper's 1-5.5 cm pieces are subangular to subrounded) in translucent orange-red
with faint concentric banding and a botryoidal top edge, on a transparent background.  Colours follow the paper's
description (hematite red to goethite yellow); nothing here is measured.
Output: assets/carnelian.png (768 px, RGBA), godot/assets/carnelian.png, godot/assets/icon.png (256) and
godot/assets/icon.ico (16-256).
"""
import os
import math
import numpy as np
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_ASSETS = os.path.join(ROOT, "assets")
OUT_GODOT = os.path.join(ROOT, "godot", "assets")
os.makedirs(OUT_ASSETS, exist_ok=True)
os.makedirs(OUT_GODOT, exist_ok=True)

N = 768
yy, xx = np.mgrid[0:N, 0:N].astype(np.float64)
cx, cy = N * 0.5, N * 0.53
rng = np.random.default_rng(7)

# ---- pebble outline: a superellipse with low-order angular noise and three botryoidal bumps on top ----
ang = np.arctan2(yy - cy, xx - cx)
rad = np.hypot((xx - cx) / 0.95, (yy - cy) / 0.80)
wobble = 1.0 + 0.045 * np.cos(3 * ang + 0.6) + 0.03 * np.sin(5 * ang - 1.1) + 0.02 * np.cos(7 * ang + 2.0)
bumps = np.zeros_like(ang)
for a0, w, h in ((-1.25, 0.28, 0.07), (-1.75, 0.22, 0.05), (-0.85, 0.24, 0.045), (-2.15, 0.18, 0.035)):
    bumps += h * np.exp(-((ang - a0) / w) ** 2)
R = N * 0.36 * (wobble + bumps)
inside = rad < R
edge = np.clip((R - rad) / (N * 0.012), 0.0, 1.0)   # soft antialiased edge

# ---- body colour: translucent chalcedony, hematite red core grading to goethite orange rim, with banding ----
depth = np.clip((R - rad) / R, 0.0, 1.0)             # 0 at the edge, 1 at the centre
band_phase = depth * 11.0 + (0.9 * np.sin(ang * 2.0 + depth * 5.0) + 0.5 * np.cos(ang * 4.0)) * (1.0 - depth) ** 1.5   # bands wobble at the rim, round at the core
bands = 0.5 + 0.5 * np.sin(band_phase * math.pi)
bands = bands ** 3.0                                     # thin bright bands, wide dark gaps
noise = rng.normal(0.0, 1.0, (N, N))
noise = np.array(Image.fromarray(np.clip(noise * 40 + 128, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(9)), dtype=np.float64) / 255.0 - 0.5
core = np.array([0.72, 0.12, 0.05])
mid = np.array([0.93, 0.33, 0.08])
rim = np.array([0.98, 0.58, 0.18])
t = np.clip(depth * 1.4 + noise * 0.25, 0.0, 1.0)
col = (rim[None, None, :] * (1 - t)[..., None] ** 1.5 + mid[None, None, :] * (4 * t * (1 - t))[..., None] * 0.9 + core[None, None, :] * (t ** 1.5)[..., None])
col = col / np.maximum(((1 - t) ** 1.5 + 4 * t * (1 - t) * 0.9 + t ** 1.5)[..., None], 1e-6)
col = col * (0.88 + 0.22 * bands[..., None]) + 0.06 * noise[..., None]
# translucency: light passes through the thin rim
glow = np.clip(1.0 - depth * 2.2, 0.0, 1.0) ** 2
col = col + glow[..., None] * np.array([0.25, 0.18, 0.05])
# specular highlight (upper left) and a soft shading toward lower right
lx, ly = cx - N * 0.13, cy - N * 0.17
spec = np.exp(-(((xx - lx) / (N * 0.07)) ** 2 + ((yy - ly) / (N * 0.045)) ** 2))
spec2 = np.exp(-(((xx - lx - N * 0.08) / (N * 0.025)) ** 2 + ((yy - ly + N * 0.09) / (N * 0.02)) ** 2))
shade = 1.0 - 0.35 * np.clip(((xx - cx) + (yy - cy)) / (N * 0.6) + 0.2, 0.0, 1.0)
col = col * shade[..., None] + spec[..., None] * np.array([0.9, 0.85, 0.8]) * 0.85 + spec2[..., None] * 0.6
col = np.clip(col, 0.0, 1.0)

alpha = edge * (0.86 + 0.14 * depth)                      # slightly translucent rim
rgba = np.dstack([col, alpha])
# soft shadow under the pebble
shadow = np.exp(-(((xx - cx - N * 0.03) / (N * 0.33)) ** 2 + ((yy - cy - N * 0.33) / (N * 0.07)) ** 2)) * 0.55
shadow_rgba = np.dstack([np.zeros((N, N, 3)), shadow * (1.0 - edge)])
out = shadow_rgba.copy()
a = rgba[..., 3:4]
out[..., :3] = rgba[..., :3] * a + out[..., :3] * (1 - a)
out[..., 3:4] = a + out[..., 3:4] * (1 - a)
img = Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8), "RGBA")
img.save(os.path.join(OUT_ASSETS, "carnelian.png"))
img.save(os.path.join(OUT_GODOT, "carnelian.png"))

# ---- icon: pebble on a dark rounded square ----
def icon(size: int) -> Image.Image:
    bg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    sq = np.zeros((N, N, 4), dtype=np.float64)
    r0 = N * 0.18
    dx = np.maximum(np.abs(xx - N / 2) - (N / 2 - r0), 0)
    dy = np.maximum(np.abs(yy - N / 2) - (N / 2 - r0), 0)
    inside_sq = np.clip((r0 - np.hypot(dx, dy)) / 3.0 + 0.5, 0, 1)
    grad = 0.10 + 0.08 * (yy / N)
    sq[..., 0] = grad * 1.1
    sq[..., 1] = grad * 1.0
    sq[..., 2] = grad * 1.15
    sq[..., 3] = inside_sq
    bg = Image.fromarray(np.clip(sq * 255, 0, 255).astype(np.uint8), "RGBA")
    peb = Image.fromarray(np.clip(rgba * 255, 0, 255).astype(np.uint8), "RGBA").resize((int(N * 0.86), int(N * 0.86)), Image.LANCZOS)
    bg.alpha_composite(peb, (int(N * 0.07), int(N * 0.05)))
    return bg.resize((size, size), Image.LANCZOS)

icon(256).save(os.path.join(OUT_GODOT, "icon.png"))
icon(256).save(os.path.join(OUT_GODOT, "icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("wrote carnelian.png, icon.png, icon.ico")
