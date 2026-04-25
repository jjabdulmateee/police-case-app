"""
Generate assets/app_icon.png — 1024x1024, dark rounded square + white serif 'P'.
Requires: pip install Pillow
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw, ImageFont

CANVAS = 1024
BG = "#0A0A0A"
FG = "#FFFFFF"
FONT_SIZE = 620
# Heavily rounded (squircle-like) — ~22% of side
CORNER_RADIUS = 220

FONTS_TO_TRY = [
    r"C:\Windows\Fonts\timesbd.ttf",
    r"C:\Windows\Fonts\arialbd.ttf",
]


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for path in FONTS_TO_TRY:
        if os.path.isfile(path):
            print(f"Using font: {path}", file=sys.stderr)
            return ImageFont.truetype(path, size)
    print("ERROR: No Windows system font found. Install Times New Roman or Arial, or set FONTS_TO_TRY.", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "assets", "app_icon.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    # Transparent outside rounded rect (useful for some pipelines); fill squircle
    im = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im)
    # Pillow 8.2+: rounded_rectangle
    draw.rounded_rectangle(
        (0, 0, CANVAS - 1, CANVAS - 1),
        radius=CORNER_RADIUS,
        fill=BG,
    )

    font = load_font(FONT_SIZE)
    ch = "P"
    # Bounding box of glyph at origin (includes offset for non-zero left/top of caps)
    bbox = draw.textbbox((0, 0), ch, font=font)
    l, t, r, b = bbox
    gw, gh = r - l, b - t
    # Position so the bbox is centered in the canvas
    x = (CANVAS - gw) / 2 - l
    y = (CANVAS - gh) / 2 - t
    draw.text((x, y), ch, font=font, fill=FG)

    im.save(out, "PNG", optimize=True)
    print(f"Wrote {out} ({CANVAS}x{CANVAS})")
    return


if __name__ == "__main__":
    main()
