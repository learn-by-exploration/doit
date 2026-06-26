#!/usr/bin/env python3
"""
regen_launcher_icons.py — regenerate the legacy
mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
files from the v1.1i / ADR-032 master vector
(android/app/src/main/res/drawable/ic_launcher_{background,
foreground}.xml).

The v1.1i release added adaptive-icon vectors at
mipmap-anydpi-v26/ic_launcher.xml, but the legacy density
buckets (the API 21..25 fallback) were left as the
default Flutter launcher icon (the blue 'F'). This script
fills those buckets with the brand glyph so the API 21..25
fallback matches the adaptive-icon foreground.

Usage:
    python3 tool/regen_launcher_icons.py

The script is idempotent — running it twice produces the
same bytes (no timestamp / random data).

Dependencies:
    Pillow (already installed in the project's dev
    environment per .claude/CLAUDE.md context).

Why Python and not a Dart tool: this is a one-off binary-
asset generator that runs at design-time (not at app
startup, not in CI). Pillow is already installed in this
dev environment; pulling in `dart:ui` would force a
Flutter dependency on a script that has nothing to do
with the runtime.
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError as exc:  # pragma: no cover
    sys.stderr.write(
        "Pillow is required: pip install Pillow\n",
    )
    raise

# Mirrors `lib/theme/app_theme.dart` `streakSeed = Color(0xFF6750A4)`.
# The adaptive-icon background drawable uses the same value
# (see android/app/src/main/res/drawable/ic_launcher_background.xml).
BRAND_PURPLE = (0x67, 0x50, 0xA4, 0xFF)

# Foreground glyph color. Mirrors
# ic_launcher_foreground.xml's `#FFFFFFFF` fill.
WHITE = (0xFF, 0xFF, 0xFF, 0xFF)

# Mirrors the v1.1i vector layout (108dp adaptive-icon canvas).
# The legacy PNGs ship the full canvas (Android applies the
# launcher mask at draw time), so we render the foreground
# inside a 108-unit viewport for every density.
VIEWPORT = 108


def _viewport_to_pixel(viewport_units: float, size_px: int) -> float:
    """Convert a viewport-unit coordinate (0..108) to a
    pixel coordinate (0..size_px). Linear scale."""
    return (viewport_units / VIEWPORT) * size_px


def render(size_px: int) -> Image.Image:
    """Render the full launcher icon (background + foreground)
    at `size_px` × `size_px`. Returns an RGBA `PIL.Image.Image`
    ready to save as PNG."""
    img = Image.new("RGBA", (size_px, size_px), BRAND_PURPLE)
    draw = ImageDraw.Draw(img)

    # Foreground glyph — lowercase 'd' + check dot.
    # Layout matches ic_launcher_foreground.xml (see header
    # comment in that file):
    #
    #   Stem:        x ∈ [23, 29], y ∈ [24, 84]
    #   Outer bowl:  center (54, 54), R = 25
    #   Inner bowl:  center (54, 54), R = 16
    #   Check dot:   center (80, 80), R = 4
    #
    # We use evenOdd fill semantics by drawing the outer
    # disk first (white) and then the inner disk
    # (background-color) — equivalent for solid colors.
    v2p = lambda v: _viewport_to_pixel(v, size_px)

    # Outer bowl (white).
    outer_r = v2p(25)
    draw.ellipse(
        [
            (v2p(54) - outer_r, v2p(54) - outer_r),
            (v2p(54) + outer_r, v2p(54) + outer_r),
        ],
        fill=WHITE,
    )

    # Inner bowl (background-color) — carves the counter.
    inner_r = v2p(16)
    draw.ellipse(
        [
            (v2p(54) - inner_r, v2p(54) - inner_r),
            (v2p(54) + inner_r, v2p(54) + inner_r),
        ],
        fill=BRAND_PURPLE,
    )

    # Stem (white rectangle). The stem visually overlaps
    # the outer bowl; evenOdd semantics in the vector would
    # carves the overlap out, but rendering it as a solid
    # rectangle keeps the 'd' shape readable.
    stem_left = v2p(23)
    stem_top = v2p(24)
    stem_right = v2p(29)
    stem_bottom = v2p(84)
    draw.rectangle(
        [
            (stem_left, stem_top),
            (stem_right, stem_bottom),
        ],
        fill=WHITE,
    )

    # Check dot (white) — small filled circle, bottom-right.
    dot_r = v2p(4)
    draw.ellipse(
        [
            (v2p(80) - dot_r, v2p(80) - dot_r),
            (v2p(80) + dot_r, v2p(80) + dot_r),
        ],
        fill=WHITE,
    )

    return img


# Density bucket dimensions match the v1.1i / v1.1j baseline
# (see app_icon_test.dart 'legacy density buckets still ship
# the default PNG fallback').
DENSITY_BUCKETS = [
    ("mipmap-mdpi", 48),
    ("mipmap-hdpi", 72),
    ("mipmap-xhdpi", 96),
    ("mipmap-xxhdpi", 144),
    ("mipmap-xxxhdpi", 192),
]


def main() -> int:
    # Resolve the Android res directory relative to the script.
    # The script lives at tool/regen_launcher_icons.py; the
    # Android res directory lives at android/app/src/main/res.
    script_dir = Path(__file__).resolve().parent
    res_dir = script_dir.parent / "android" / "app" / "src" / "main" / "res"

    if not res_dir.is_dir():
        sys.stderr.write(
            f"res directory not found: {res_dir}\n"
            "Are you running this from the project root?\n",
        )
        return 1

    for bucket_name, size_px in DENSITY_BUCKETS:
        bucket_dir = res_dir / bucket_name
        target = bucket_dir / "ic_launcher.png"
        bucket_dir.mkdir(parents=True, exist_ok=True)
        img = render(size_px)
        img.save(target, format="PNG", optimize=True)
        print(f"wrote {target} ({size_px}x{size_px})")

    return 0


if __name__ == "__main__":
    sys.exit(main())