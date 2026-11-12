#!/usr/bin/env python3
"""Render a transparent, animated gradient text overlay for Kitty scrollback.

The shell writes the real text to the terminal first. This renderer creates
only the colored glyph overlay, leaving the underlying text selectable and
copyable while Kitty scrolls the image placement with its owning text.
"""

from __future__ import annotations

import argparse
import math
import sys
import unicodedata
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


PALETTES = {
    "legendary": (
        (74, 50, 12), (105, 74, 17), (139, 101, 26), (174, 132, 39),
        (207, 166, 62), (237, 202, 105), (255, 231, 159), (255, 245, 207),
        (235, 203, 119), (190, 145, 55), (137, 96, 27), (91, 61, 16),
    ),
    "mythic": (
        (15, 17, 21), (27, 30, 36), (43, 47, 55), (62, 68, 78),
        (85, 93, 105), (115, 124, 137), (151, 160, 171),
        (190, 197, 205), (220, 224, 229), (167, 175, 185),
        (105, 113, 124), (48, 53, 62),
    ),
}

FRAME_COUNT = 25
FRAME_DELAY_MS = 80


def cell_width(character: str) -> int:
    """Approximate terminal cell width, excluding combining/format characters."""
    codepoint = ord(character)
    category = unicodedata.category(character)
    if (
        category in {"Mn", "Me", "Cf"}
        or codepoint in {0xFE0E, 0xFE0F, 0x200D}
        or 0xE0100 <= codepoint <= 0xE01EF
    ):
        return 0
    if unicodedata.east_asian_width(character) in {"W", "F"} or codepoint >= 0x1F000:
        return 2
    return 1


def interpolate_palette(palette: tuple[tuple[int, int, int], ...], position: int) -> tuple[int, int, int]:
    scaled = (position % 100) * len(palette) / 100.0
    left = int(scaled) % len(palette)
    right = (left + 1) % len(palette)
    fraction = scaled - int(scaled)
    return tuple(
        round(palette[left][channel] * (1.0 - fraction) + palette[right][channel] * fraction)
        for channel in range(3)
    )


def build_mask(
    lines: list[str],
    font: ImageFont.FreeTypeFont,
    cell_px_width: int,
    cell_px_height: int,
    width_cells: int,
) -> Image.Image:
    mask = Image.new("L", (width_cells * cell_px_width, len(lines) * cell_px_height), 0)
    for row, line in enumerate(lines):
        cursor_cell = 0
        for character in line:
            advance = cell_width(character)
            if advance == 0:
                continue
            # Leave wide symbols and emoji to the terminal's native font
            # fallback. The original text remains visible underneath them.
            if advance == 1 and not character.isspace():
                glyph = Image.new("L", (max(2, cell_px_width * 2), cell_px_height), 0)
                glyph_draw = ImageDraw.Draw(glyph)
                bbox = glyph_draw.textbbox((0, 0), character, font=font)
                glyph_width = max(1, bbox[2] - bbox[0])
                glyph_height = max(1, bbox[3] - bbox[1])
                glyph_draw.text((-bbox[0], -bbox[1]), character, font=font, fill=255)
                cropped = glyph.crop((0, 0, min(glyph.width, glyph_width + 1), min(glyph.height, glyph_height + 1)))
                target_width = cell_px_width * advance
                if cropped.width != target_width:
                    cropped = cropped.resize(
                        (target_width, cropped.height),
                        Image.Resampling.LANCZOS,
                    )
                y = row * cell_px_height + max(0, (cell_px_height - cropped.height) // 2)
                mask.paste(cropped, (cursor_cell * cell_px_width, y))
            cursor_cell += advance
    return mask


def make_frame(
    mask: Image.Image,
    palette: tuple[tuple[int, int, int], ...],
    phase: int,
    cell_px_width: int,
    width_cells: int,
) -> Image.Image:
    width, height = mask.size
    rgba = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = rgba.load()
    alpha = mask.load()
    denominator = max(1, width_cells - 1)
    for x in range(width):
        column = min(width_cells - 1, x // cell_px_width)
        position = ((column * 100 // denominator) - phase + 100) % 100
        red, green, blue = interpolate_palette(palette, position)
        for y in range(height):
            opacity = alpha[x, y]
            if opacity:
                pixels[x, y] = (red, green, blue, opacity)
    return rgba


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--style", choices=tuple(PALETTES), required=True)
    parser.add_argument("--cell-width", type=int, required=True)
    parser.add_argument("--cell-height", type=int, required=True)
    parser.add_argument("--font", type=Path, required=True)
    parser.add_argument("--format", choices=("apng", "gif"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    lines = [line.rstrip("\r") for line in sys.stdin.read().splitlines()]
    if not lines or any("\x1b" in line for line in lines):
        return 2
    if args.cell_width <= 0 or args.cell_height <= 0 or not args.font.is_file():
        return 2

    width_cells = max(sum(cell_width(character) for character in line) for line in lines)
    height_lines = len(lines)
    if width_cells <= 0:
        return 2

    # Kitty's configured JetBrains Mono uses a 150% line height in this
    # setup. Derive glyph size from the measured cell height rather than
    # assuming a fixed terminal font size.
    font_size = max(6, round(args.cell_height / 1.5))
    font = ImageFont.truetype(str(args.font), font_size)
    mask = build_mask(lines, font, args.cell_width, args.cell_height, width_cells)
    frames = [
        make_frame(mask, PALETTES[args.style], frame * 4, args.cell_width, width_cells)
        for frame in range(FRAME_COUNT)
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)

    if args.format == "apng":
        frames[0].save(
            args.output,
            format="PNG",
            save_all=True,
            append_images=frames[1:],
            duration=FRAME_DELAY_MS,
            loop=0,
            disposal=[0] * FRAME_COUNT,
            blend=[0] * FRAME_COUNT,
            optimize=False,
        )
    else:
        paletted = [frame.convert("P", palette=Image.Palette.ADAPTIVE, colors=255) for frame in frames]
        paletted[0].save(
            args.output,
            format="GIF",
            save_all=True,
            append_images=paletted[1:],
            duration=FRAME_DELAY_MS,
            loop=0,
            disposal=2,
            transparency=0,
            optimize=False,
        )

    print(f"{width_cells} {height_lines}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
