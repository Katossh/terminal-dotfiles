#!/usr/bin/env python3
"""Create a transparent animated GIF overlay for Kitty's graphics protocol.

The Zsh caller prints the real selectable text once beneath this image.
Kitty owns playback and scrolls the placement with the underlying text.
"""
from __future__ import annotations

import argparse
import html
import shutil
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

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
FRAME_DELAY = 8  # GIF hundredths of a second: 80 ms per frame.


def cell_width(character: str) -> int:
    if unicodedata.combining(character) or unicodedata.category(character) in {"Cf", "Mn", "Me"}:
        return 0
    if unicodedata.east_asian_width(character) in {"W", "F"} or ord(character) >= 0x1F000:
        return 2
    return 1


def palette_color(palette: tuple[tuple[int, int, int], ...], position: int) -> str:
    scaled = (position % 100) * len(palette) / 100.0
    left = int(scaled) % len(palette)
    right = (left + 1) % len(palette)
    fraction = scaled - int(scaled)
    rgb = tuple(
        round(palette[left][channel] * (1 - fraction) + palette[right][channel] * fraction)
        for channel in range(3)
    )
    return "#%02x%02x%02x" % rgb


def render_frame(
    path: Path,
    lines: list[str],
    palette: tuple[tuple[int, int, int], ...],
    phase: int,
    cell_px_width: int,
    cell_px_height: int,
    font_family: str,
) -> tuple[int, int]:
    columns = max(sum(cell_width(character) for character in line) for line in lines)
    rows = len(lines)
    width_px = columns * cell_px_width
    height_px = rows * cell_px_height
    font_px = cell_px_height / 1.5
    baseline = cell_px_height * 0.77
    denominator = max(1, columns - 1)

    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width_px}" '
        f'height="{height_px}" viewBox="0 0 {width_px} {height_px}">',
        f'<g font-family="{html.escape(font_family, quote=True)}" '
        f'font-size="{font_px:.3f}px" font-weight="normal">',
    ]
    for row, line in enumerate(lines):
        cell = 0
        spans: list[str] = []
        for character in line:
            advance = cell_width(character)
            if advance == 0:
                continue
            if character.isascii() and character.isprintable():
                position = ((cell * 100 // denominator) - phase + 100) % 100
                color = palette_color(palette, position)
                # Preserve spaces so textLength lines up with the terminal grid.
                spans.append(f'<tspan fill="{color}">{html.escape(character)}</tspan>')
            else:
                # Let Kitty render emoji and wide glyphs with its own font fallback.
                spans.append(f'<tspan fill="none">{" " * advance}</tspan>')
            cell += advance
        row_width = max(1, sum(cell_width(character) for character in line)) * cell_px_width
        y = row * cell_px_height + baseline
        svg.append(
            f'<text x="0" y="{y:.3f}" xml:space="preserve" '
            f'textLength="{row_width}" lengthAdjust="spacingAndGlyphs">'
            f'{"".join(spans)}</text>'
        )
    svg.extend(("</g>", "</svg>"))
    path.write_text("\n".join(svg), encoding="utf-8")
    return columns, rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--style", choices=tuple(PALETTES), required=True)
    parser.add_argument("--cell-width", type=int, required=True)
    parser.add_argument("--cell-height", type=int, required=True)
    parser.add_argument("--font-family", default="monospace")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    lines = [line.rstrip("\r") for line in sys.stdin.read().splitlines()]
    if (
        not lines
        or args.cell_width < 2
        or args.cell_height < 4
        or any("\x1b" in line for line in lines)
        or not any(character.isascii() and character.isalnum() for line in lines for character in line)
    ):
        return 2

    converter = shutil.which("magick") or shutil.which("convert")
    if not converter:
        return 2

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="dots-failure-frames-") as temporary_directory:
        frame_paths: list[str] = []
        dimensions = (0, 0)
        for frame in range(FRAME_COUNT):
            frame_path = Path(temporary_directory) / f"frame-{frame:03d}.svg"
            dimensions = render_frame(
                frame_path,
                lines,
                PALETTES[args.style],
                frame * 4,
                args.cell_width,
                args.cell_height,
                args.font_family,
            )
            frame_paths.append(str(frame_path))

        command = [
            converter,
            "-background", "none",
            "-delay", str(FRAME_DELAY),
            *frame_paths,
            "-loop", "0",
            "-dispose", "background",
            f"GIF:{args.output}",
        ]
        try:
            subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        except (OSError, subprocess.CalledProcessError) as error:
            print(str(error), file=sys.stderr)
            return 2

    print(f"{dimensions[0]} {dimensions[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
