#!/usr/bin/env python3
"""Generate all required iOS app icon sizes for CircleDetectAR."""

import math
import os
import random
from PIL import Image, ImageDraw

ICON_DIR = os.path.join(
    os.path.dirname(__file__),
    "../CircleDetectAR/Resources/Assets.xcassets/AppIcon.appiconset"
)

SIZES = {
    "Icon-1024.png": 1024,
    "Icon-180.png":  180,
    "Icon-167.png":  167,
    "Icon-152.png":  152,
    "Icon-120.png":  120,
    "Icon-87.png":   87,
    "Icon-80.png":   80,
    "Icon-76.png":   76,
    "Icon-60.png":   60,
    "Icon-58.png":   58,
    "Icon-40.png":   40,
    "Icon-29.png":   29,
    "Icon-20.png":   20,
}


def ellipse_box(cx, cy, r):
    return [cx - r, cy - r, cx + r, cy + r]


def make_icon(size):
    s = size
    cx, cy = s / 2.0, s / 2.0

    # ── Dark navy background with subtle radial gradient ──────────────────────
    base = Image.new("RGB", (s, s), (6, 8, 20))
    bd = ImageDraw.Draw(base)
    max_r = int(s * 0.72)
    for ri in range(max_r, 0, -2):
        t = ri / max_r          # 1 = edge, 0 = centre
        r = int(6  + (22 - 6)  * (1 - t))
        g = int(8  + (20 - 8)  * (1 - t))
        b = int(20 + (70 - 20) * (1 - t))
        bd.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=(r, g, b))

    # ── iOS rounded-rect mask ─────────────────────────────────────────────────
    mask = Image.new("L", (s, s), 0)
    md = ImageDraw.Draw(mask)
    radius = int(s * 0.2232)
    md.rounded_rectangle([0, 0, s - 1, s - 1], radius=radius, fill=255)
    base.putalpha(mask)     # base is now RGBA

    draw = ImageDraw.Draw(base, "RGBA")

    # ── Glowing yellow/orange circle stroke ───────────────────────────────────
    circle_r = s * 0.34
    lw_glow  = max(int(s * 0.042), 3)
    lw_main  = max(int(s * 0.028), 2)
    lw_core  = max(int(s * 0.014), 1)

    for gw, alpha in [(lw_glow * 3, 25), (lw_glow * 2, 50), (lw_glow, 85)]:
        draw.ellipse(ellipse_box(cx, cy, circle_r),
                     outline=(255, 175, 0, alpha), width=gw)
    draw.ellipse(ellipse_box(cx, cy, circle_r),
                 outline=(255, 200, 10, 225), width=lw_main)
    draw.ellipse(ellipse_box(cx, cy, circle_r),
                 outline=(255, 240, 130, 255), width=lw_core)

    # ── White AR reticle crosshair ────────────────────────────────────────────
    arm    = s * 0.09
    gap    = s * 0.055
    lw_ret = max(int(s * 0.022), 1)
    white  = (255, 255, 255, 215)

    for angle_deg in [0, 90, 180, 270]:
        rad  = math.radians(angle_deg)
        perp = math.radians(angle_deg + 90)
        ca, sa = math.cos(rad),  math.sin(rad)
        cp, sp = math.cos(perp), math.sin(perp)

        x0 = cx + ca * gap       - cp * gap * 0.5
        y0 = cy + sa * gap       - sp * gap * 0.5
        x1 = cx + ca * (gap+arm) - cp * gap * 0.5
        y1 = cy + sa * (gap+arm) - sp * gap * 0.5
        draw.line([x0, y0, x1, y1], fill=white, width=lw_ret)

    dot_r = s * 0.018
    draw.ellipse(ellipse_box(cx, cy, dot_r), fill=(255, 255, 255, 200))

    # ── Subtle blue scatter dots (AR atmosphere) ──────────────────────────────
    random.seed(42)
    for _ in range(int(s * 0.12)):
        angle = random.uniform(0, 2 * math.pi)
        dist  = random.uniform(0, circle_r * 0.75)
        dx    = cx + math.cos(angle) * dist
        dy    = cy + math.sin(angle) * dist
        dr    = max(1, int(s * 0.005))
        a     = random.randint(12, 40)
        draw.ellipse([dx - dr, dy - dr, dx + dr, dy + dr],
                     fill=(100, 160, 255, a))

    return base


def main():
    out_dir = os.path.abspath(ICON_DIR)
    os.makedirs(out_dir, exist_ok=True)
    for filename, size in SIZES.items():
        icon = make_icon(size)
        path = os.path.join(out_dir, filename)
        icon.save(path, "PNG")
        print(f"  wrote {filename}  ({size}x{size})")
    print("Done.")


if __name__ == "__main__":
    main()
