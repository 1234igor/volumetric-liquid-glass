#!/usr/bin/env python3
"""Build the README image from the rendered volume matrix.

First run capture-volume-matrix.sh. Requires Pillow 10.1 or later.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "validation/captures/raw/volume/materials"
SAMPLES = [
    ("panel", "clear", "Panel", "Clear / three-quarter view"),
    ("orb", "clear", "Orb", "Clear / three-quarter view"),
    ("torus", "regular-tinted", "Torus", "Regular + tint / top view"),
    ("cluster", "regular", "Cluster", "Regular / three-quarter view"),
]


def main():
    sheet = Image.new("RGB", (1600, 1296), "#111317")
    draw = ImageDraw.Draw(sheet)
    title = ImageFont.load_default(size=38)
    label = ImageFont.load_default(size=26)
    body = ImageFont.load_default(size=20)
    draw.text((40, 30), "Volumetric Liquid Glass", font=title, fill="white")
    draw.text((40, 84), "Four glass shapes rendered in Godot", font=body, fill="#adb6c3")
    for index, (shape, material, name, detail) in enumerate(SAMPLES):
        x = 40 + (index % 2) * 780
        y = 142 + (index // 2) * 550
        source = RAW / shape / f"{material}.png"
        with Image.open(source) as frame:
            if frame.size != (2400, 1600):
                raise ValueError(f"{source}: expected 2400x1600, got {frame.size}")
            # Keep the whole frame so the orb and torus silhouettes are complete.
            rendered = frame.convert("RGB")
        sheet.paste(rendered.resize((740, 493), Image.Resampling.LANCZOS), (x, y + 40))
        draw.text((x, y), name, font=label, fill="white")
        draw.text((x + 130, y + 5), detail, font=body, fill="#adb6c3")
    draw.text((40, 1258), "Rendered Godot captures. Resized; no added glass effects.", font=body, fill="#adb6c3")
    output = ROOT / "examples/spatial_gallery/app.png"
    sheet.save(output, optimize=True)
    print(output)


if __name__ == "__main__":
    main()
