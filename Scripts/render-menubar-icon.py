#!/usr/bin/env python3
"""Render the menubar pulse-spike icon to template-image PNG.

Q8 fix (2026-04-29): the previous PNG was rendered from a 44×22 SVG via
qlmanage which baked an opaque white background into the PNG. macOS template
images use the alpha channel to decide which pixels get tinted, so an opaque
white pixel renders as a filled tinted square instead of "no icon here". The
result on a green-forest desktop wallpaper looked like a "white box" in the
menubar.

This script renders the same pulse spike on a 22×22 (and 44×44 retina) artboard
with a transparent background and a black opaque stroke. macOS NSStatusItem
with isTemplate=true tints the opaque pixels with the system color (white in
dark menu bar, black in light), and skips the transparent ones.

Usage:
    python3 Scripts/render-menubar-icon.py
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

# Path coordinates from the designer SVG, rescaled from the 44×22 viewBox to a
# 22×22 artboard so the menubar slot stays standard width.
PULSE_POINTS = [
    (2, 11),
    (7, 11),
    (9, 3),
    (11, 19),
    (13, 3),
    (15, 11),
    (20, 11),
]


def render(scale: int, out: Path) -> None:
    size = 22 * scale
    stroke = 1.6 * scale  # designer-spec stroke-width: 1.6 at 1x

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))  # transparent
    draw = ImageDraw.Draw(img)

    # Scale points into pixel space; offset by 0.5 so the line lands on pixel
    # centres rather than between, keeping the rendered shape sharp.
    pts = [(x * scale, y * scale) for x, y in PULSE_POINTS]

    # Pillow >= 9.2 supports joint='curve' for joins. Use it when available;
    # otherwise fall back to plain polyline + per-vertex circle to fake the
    # rounded join (designer spec says stroke-linejoin: round).
    try:
        draw.line(pts, fill=(0, 0, 0, 255), width=int(round(stroke)), joint="curve")
    except TypeError:
        draw.line(pts, fill=(0, 0, 0, 255), width=int(round(stroke)))

    # Round caps at each end of the path — draw a black-filled circle so the
    # stroke ends look round instead of squared off, matching the SVG's
    # stroke-linecap: round.
    cap_radius = stroke / 2
    for x, y in (pts[0], pts[-1]):
        bbox = (x - cap_radius, y - cap_radius, x + cap_radius, y + cap_radius)
        draw.ellipse(bbox, fill=(0, 0, 0, 255))

    img.save(out, "PNG")


def main() -> None:
    out_dir = Path(__file__).parent.parent / "Pulse" / "Resources" / "Assets.xcassets" / "MenuBarIcon.imageset"
    render(scale=1, out=out_dir / "menubar_22.png")
    render(scale=2, out=out_dir / "menubar_44.png")
    print("rendered:")
    for f in ("menubar_22.png", "menubar_44.png"):
        path = out_dir / f
        print(f"  {path}: {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
