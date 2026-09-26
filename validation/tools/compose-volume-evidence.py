#!/usr/bin/env python3
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat


ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT.parent
RAW = ROOT / "captures" / "raw" / "volume"
OUT = ROOT / "captures"
OBJECTS = ["panel", "orb", "torus", "cluster"]
VARIANTS = ["regular", "clear", "regular-tinted", "clear-tinted", "identity"]
VIEWS = ["side", "three-quarter", "grazing", "top"]
BACKGROUNDS = {
    "panel": "facade",
    "orb": "city-night",
    "torus": "prism",
    "cluster": "harbour",
}
MIN_ACTIVE_MAE = 1.0
MIN_ACTIVE_PIXELS_PERCENT = 5.0
MAX_IDENTITY_MAE = 0.25
MAX_IDENTITY_PIXELS_PERCENT = 1.0
MIN_VIEW_PAIR_MAE = 0.5


def title(value: str) -> str:
    return value.replace("-", " ").title()


def image_metrics(reference: Image.Image, rendered: Image.Image) -> dict[str, float]:
    difference = ImageChops.difference(reference.convert("RGB"), rendered.convert("RGB"))
    stat = ImageStat.Stat(difference)
    mae = sum(stat.mean) / 3.0
    histogram = difference.convert("L").point(lambda value: 255 if value > 2 else 0).histogram()
    changed = 100.0 * histogram[255] / (difference.width * difference.height)
    return {
        "mae_0_255": round(mae, 4),
        "changed_pixels_percent": round(changed, 4),
    }


def load_capture(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGB")
    if image.size != (2400, 1600):
        raise ValueError(f"{path} is {image.size}, expected 2400x1600")
    return image


def make_sheet() -> None:
    thumb_size = (360, 240)
    gutter = 10
    row_label = 118
    header = 46
    width = row_label + len(VARIANTS) * (thumb_size[0] + gutter) - gutter
    height = header + len(OBJECTS) * (thumb_size[1] + gutter) - gutter
    sheet = Image.new("RGB", (width, height), "#111114")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=16)
    for column, variant in enumerate(VARIANTS):
        draw.text((row_label + column * (thumb_size[0] + gutter) + 8, 15), title(variant), fill="white", font=font)
    for row, object_name in enumerate(OBJECTS):
        y = header + row * (thumb_size[1] + gutter)
        draw.text((8, y + 108), title(object_name), fill="white", font=font)
        for column, variant in enumerate(VARIANTS):
            image = load_capture(RAW / "materials" / object_name / f"{variant}.png")
            image.thumbnail(thumb_size, Image.Resampling.LANCZOS)
            x = row_label + column * (thumb_size[0] + gutter)
            sheet.paste(image, (x, y))
    sheet.save(OUT / "volume-material-matrix.png", optimize=True)


def make_view_strip() -> None:
    thumb_size = (480, 320)
    label_height = 40
    gutter = 10
    width = len(VIEWS) * (thumb_size[0] + gutter) - gutter
    strip = Image.new("RGB", (width, label_height + thumb_size[1]), "#111114")
    draw = ImageDraw.Draw(strip)
    font = ImageFont.load_default(size=16)
    for column, view in enumerate(VIEWS):
        x = column * (thumb_size[0] + gutter)
        draw.text((x + 8, 12), title(view), fill="white", font=font)
        image = load_capture(RAW / "views" / "panel" / f"{view}.png")
        image.thumbnail(thumb_size, Image.Resampling.LANCZOS)
        strip.paste(image, (x, label_height))
    strip.save(OUT / "view-projections.png", optimize=True)


def main() -> None:
    report = {
        "capture_size_pixels": [2400, 1600],
        "acceptance": {
            "active_mae_0_255_min": MIN_ACTIVE_MAE,
            "active_changed_pixels_percent_min": MIN_ACTIVE_PIXELS_PERCENT,
            "identity_mae_0_255_max": MAX_IDENTITY_MAE,
            "identity_changed_pixels_percent_max": MAX_IDENTITY_PIXELS_PERCENT,
            "view_pair_mae_0_255_min": MIN_VIEW_PAIR_MAE,
        },
        "materials": {},
        "view_pair_differences": {},
    }
    failures = []
    for object_name in OBJECTS:
        background = load_capture(REPO / "assets" / "backgrounds" / f"{BACKGROUNDS[object_name]}.png")
        report["materials"][object_name] = {}
        for variant in VARIANTS:
            rendered = load_capture(RAW / "materials" / object_name / f"{variant}.png")
            metrics = image_metrics(background, rendered)
            report["materials"][object_name][variant] = metrics
            if variant == "identity":
                if metrics["mae_0_255"] > MAX_IDENTITY_MAE or metrics["changed_pixels_percent"] > MAX_IDENTITY_PIXELS_PERCENT:
                    failures.append(f"{object_name}/{variant} is not an identity pass: {metrics}")
            elif metrics["mae_0_255"] < MIN_ACTIVE_MAE or metrics["changed_pixels_percent"] < MIN_ACTIVE_PIXELS_PERCENT:
                failures.append(f"{object_name}/{variant} has too little optical effect: {metrics}")

    view_images = {view: load_capture(RAW / "views" / "panel" / f"{view}.png") for view in VIEWS}
    for index, first in enumerate(VIEWS):
        for second in VIEWS[index + 1:]:
            metrics = image_metrics(view_images[first], view_images[second])
            key = f"{first}_vs_{second}"
            report["view_pair_differences"][key] = metrics
            if metrics["mae_0_255"] < MIN_VIEW_PAIR_MAE:
                failures.append(f"views {first}/{second} are not visually distinct: {metrics}")

    make_sheet()
    make_view_strip()
    (OUT / "volume-metrics.json").write_text(json.dumps(report, indent=2) + "\n")
    if failures:
        raise SystemExit("volume acceptance failed:\n" + "\n".join(failures))


if __name__ == "__main__":
    main()
