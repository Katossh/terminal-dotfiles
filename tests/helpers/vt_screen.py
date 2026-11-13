#!/usr/bin/env python3
"""Small VT100/xterm screen model used by the zsh PTY tests.

It intentionally implements only the sequences ZLE emits for an interactive
prompt: cursor motion, erase, scroll regions, SGR colours, and UTF-8 text with
wide characters.  The model keeps both the visible grid and a scrollback list
so tests can distinguish "redrawn in place" from "new line per frame".
"""

from __future__ import annotations

import argparse
import json
import sys
import unicodedata

BLANK = " "


def cell_width(ch: str) -> int:
    if ch in ("\u200b", "\u200c", "\u200d", "\ufe0e", "\ufe0f"):
        return 0
    if unicodedata.combining(ch):
        return 0
    codepoint = ord(ch)
    if 0x1F000 <= codepoint <= 0x1FAFF:
        return 2
    if 0x2600 <= codepoint <= 0x27BF:
        # Emoji presentation selectors make these double width.  The caller
        # checks the following character; default to one for text symbols.
        return 1
    if unicodedata.east_asian_width(ch) in ("W", "F"):
        return 2
    return 1


class Cell:
    __slots__ = ("ch", "cont", "fg", "bg")

    def __init__(self, ch: str = BLANK, cont: bool = False, fg=None, bg=None):
        self.ch = ch
        self.cont = cont
        self.fg = fg
        self.bg = bg


def blank_row(cols: int) -> list[Cell]:
    return [Cell() for _ in range(cols)]


class Screen:
    def __init__(self, cols: int, rows: int):
        self.cols = cols
        self.rows = rows
        self.grid = [blank_row(cols) for _ in range(rows)]
        self.scrollback: list[list[Cell]] = []
        self.row = 0
        self.col = 0
        self.saved = (0, 0)
        self.wrap = True
        self.wrap_pending = False
        self.scroll_top = 0
        self.scroll_bottom = rows - 1
        self.fg = None
        self.bg = None
        self.alt_grid = None
        self.alt_saved = None

    # -- grid helpers -------------------------------------------------
    def clear_row(self, row: int, start: int = 0, end: int | None = None) -> None:
        if end is None:
            end = self.cols
        for col in range(max(0, start), min(self.cols, end)):
            self.grid[row][col] = Cell()

    def copy_row(self, row: int) -> list[Cell]:
        return [Cell(c.ch, c.cont, c.fg, c.bg) for c in self.grid[row]]

    def push_scrollback(self, row: int) -> None:
        self.scrollback.append(self.copy_row(row))

    def scroll_up(self, count: int = 1) -> None:
        for _ in range(count):
            if self.scroll_top == 0 and self.scroll_bottom == self.rows - 1:
                self.push_scrollback(0)
                del self.grid[0]
                self.grid.append(blank_row(self.cols))
            else:
                del self.grid[self.scroll_top]
                self.grid.insert(self.scroll_bottom, blank_row(self.cols))

    def scroll_down(self, count: int = 1) -> None:
        for _ in range(count):
            if self.scroll_top == 0 and self.scroll_bottom == self.rows - 1:
                del self.grid[self.scroll_bottom]
                self.grid.insert(0, blank_row(self.cols))
            else:
                del self.grid[self.scroll_bottom]
                self.grid.insert(self.scroll_top, blank_row(self.cols))

    def linefeed(self) -> None:
        self.wrap_pending = False
        if self.row == self.scroll_bottom:
            self.scroll_up()
        elif self.row < self.rows - 1:
            self.row += 1

    def reverse_index(self) -> None:
        self.wrap_pending = False
        if self.row == self.scroll_top:
            self.scroll_down()
        elif self.row > 0:
            self.row -= 1

    # -- writing ------------------------------------------------------
    def clear_continuation(self, row: int, col: int) -> None:
        if 0 <= row < self.rows and 0 <= col < self.cols:
            cell = self.grid[row][col]
            if cell.cont and col > 0:
                self.grid[row][col - 1] = Cell()
            elif col + 1 < self.cols and self.grid[row][col + 1].cont:
                self.grid[row][col + 1] = Cell()

    def put(self, ch: str, width: int | None = None) -> None:
        if width is None:
            width = cell_width(ch)
        if width == 0:
            return
        if self.wrap_pending:
            if self.wrap:
                self.col = 0
                self.linefeed()
            self.wrap_pending = False
        if self.col + width > self.cols:
            if self.wrap:
                self.col = 0
                self.linefeed()
            else:
                self.col = max(0, self.cols - width)
        self.clear_continuation(self.row, self.col)
        if width == 2:
            self.clear_continuation(self.row, self.col + 1)
        self.grid[self.row][self.col] = Cell(ch, False, self.fg, self.bg)
        if width == 2 and self.col + 1 < self.cols:
            self.grid[self.row][self.col + 1] = Cell("", True, self.fg, self.bg)
        self.col += width
        if self.col >= self.cols:
            self.col = self.cols - 1
            if self.wrap:
                self.wrap_pending = True

    # -- rendering ----------------------------------------------------
    def row_text(self, row: list[Cell], strip: bool = True) -> str:
        chars = []
        for cell in row:
            if cell.cont:
                continue
            chars.append(cell.ch if cell.ch else BLANK)
        text = "".join(chars)
        return text.rstrip() if strip else text

    def screen_text(self) -> str:
        return "\n".join(self.row_text(row) for row in self.grid)

    def scrollback_text(self) -> str:
        return "\n".join(self.row_text(row) for row in self.scrollback)

    def all_text(self) -> str:
        parts = [self.row_text(row) for row in self.scrollback]
        parts.extend(self.row_text(row) for row in self.grid)
        return "\n".join(parts)

    def find(self, text: str) -> tuple[int, int]:
        screen_count = sum(
            1 for row in self.grid if text in self.row_text(row)
        )
        scrollback_count = sum(
            1 for row in self.scrollback if text in self.row_text(row)
        )
        return screen_count, scrollback_count

    def rows_with(self, text: str) -> list[int]:
        return [i for i, row in enumerate(self.grid) if text in self.row_text(row)]

    def colors_on_rows(self, text: str) -> list[tuple[int, int, int]]:
        found: set[tuple[int, int, int]] = set()
        for row in self.grid + self.scrollback:
            if text not in self.row_text(row):
                continue
            for cell in row:
                if isinstance(cell.fg, tuple):
                    found.add(cell.fg)
        return sorted(found)

    def cursor(self) -> tuple[int, int]:
        return self.row, self.col

    # -- escape sequence handling ------------------------------------
    def sgr(self, params: list[int]) -> None:
        i = 0
        while i < len(params):
            value = params[i]
            if value == 0:
                self.fg = None
                self.bg = None
            elif value == 39:
                self.fg = None
            elif value == 49:
                self.bg = None
            elif 30 <= value <= 37 or 90 <= value <= 97:
                self.fg = ("basic", value)
            elif 40 <= value <= 47 or 100 <= value <= 107:
                self.bg = ("basic", value)
            elif value in (38, 48):
                target = "fg" if value == 38 else "bg"
                if i + 1 < len(params) and params[i + 1] == 2:
                    if i + 4 < len(params):
                        rgb = (params[i + 2], params[i + 3], params[i + 4])
                        if target == "fg":
                            self.fg = rgb
                        else:
                            self.bg = rgb
                        i += 4
                elif i + 1 < len(params) and params[i + 1] == 5:
                    if i + 2 < len(params):
                        color = ("index", params[i + 2])
                        if target == "fg":
                            self.fg = color
                        else:
                            self.bg = color
                        i += 2
            i += 1

    def csi(self, private: str, params: list[str], intermediate: str, final: str) -> None:
        def number(index: int, default: int = 1) -> int:
            if index < len(params) and params[index]:
                try:
                    return int(params[index])
                except ValueError:
                    return default
            return default

        n = number(0)
        if final == "A":
            self.row = max(self.scroll_top, self.row - n)
            self.wrap_pending = False
        elif final == "B":
            self.row = min(self.scroll_bottom, self.row + n)
            self.wrap_pending = False
        elif final == "C":
            self.col = min(self.cols - 1, self.col + n)
            self.wrap_pending = False
        elif final == "D":
            self.col = max(0, self.col - n)
            self.wrap_pending = False
        elif final == "E":
            self.row = min(self.scroll_bottom, self.row + n)
            self.col = 0
            self.wrap_pending = False
        elif final == "F":
            self.row = max(self.scroll_top, self.row - n)
            self.col = 0
            self.wrap_pending = False
        elif final == "G":
            self.col = min(self.cols - 1, max(0, n - 1))
            self.wrap_pending = False
        elif final in ("H", "f"):
            row = number(0, 1)
            col = number(1, 1)
            self.row = min(self.rows - 1, max(0, row - 1))
            self.col = min(self.cols - 1, max(0, col - 1))
            self.wrap_pending = False
        elif final == "d":
            self.row = min(self.rows - 1, max(0, n - 1))
            self.wrap_pending = False
        elif final == "`":
            self.col = min(self.cols - 1, max(0, n - 1))
            self.wrap_pending = False
        elif final == "a":
            self.col = min(self.cols - 1, self.col + n)
            self.wrap_pending = False
        elif final == "e":
            self.row = min(self.scroll_bottom, self.row + n)
            self.wrap_pending = False
        elif final == "J":
            mode = number(0, 0)
            if mode == 0:
                self.clear_row(self.row, self.col)
                for row in range(self.row + 1, self.rows):
                    self.clear_row(row)
            elif mode == 1:
                for row in range(0, self.row):
                    self.clear_row(row)
                self.clear_row(self.row, 0, self.col + 1)
            elif mode == 2:
                for row in range(self.rows):
                    self.clear_row(row)
            elif mode == 3:
                self.scrollback.clear()
            self.wrap_pending = False
        elif final == "K":
            mode = number(0, 0)
            if mode == 0:
                self.clear_row(self.row, self.col)
            elif mode == 1:
                self.clear_row(self.row, 0, self.col + 1)
            elif mode == 2:
                self.clear_row(self.row)
            self.wrap_pending = False
        elif final == "P":
            count = min(n, self.cols - self.col)
            del self.grid[self.row][self.col : self.col + count]
            self.grid[self.row].extend(Cell() for _ in range(count))
            self.wrap_pending = False
        elif final == "@":
            count = min(n, self.cols - self.col)
            for _ in range(count):
                self.grid[self.row].insert(self.col, Cell())
            del self.grid[self.row][self.cols :]
            self.wrap_pending = False
        elif final == "X":
            self.clear_row(self.row, self.col, self.col + n)
            self.wrap_pending = False
        elif final == "L":
            for _ in range(n):
                if self.scroll_top <= self.row <= self.scroll_bottom:
                    del self.grid[self.scroll_bottom]
                    self.grid.insert(self.row, blank_row(self.cols))
            self.wrap_pending = False
        elif final == "M":
            for _ in range(n):
                if self.scroll_top <= self.row <= self.scroll_bottom:
                    del self.grid[self.row]
                    self.grid.insert(self.scroll_bottom, blank_row(self.cols))
            self.wrap_pending = False
        elif final == "S":
            self.scroll_up(n)
            self.wrap_pending = False
        elif final == "T":
            self.scroll_down(n)
            self.wrap_pending = False
        elif final == "r":
            top = number(0, 1) - 1
            bottom = number(1, self.rows) - 1
            if 0 <= top < bottom < self.rows:
                self.scroll_top = top
                self.scroll_bottom = bottom
                self.row = top
                self.col = 0
            self.wrap_pending = False
        elif final == "m":
            values = [int(p) if p else 0 for p in params]
            self.sgr(values)
        elif final in ("h", "l"):
            # Private modes.  The only one that changes our model is wrap.
            if private == "?":
                for p in params:
                    if p == "7":
                        self.wrap = final == "h"
                    elif p == "1049":
                        if final == "h":
                            self.alt_grid = self.grid
                            self.alt_saved = (self.row, self.col)
                            self.grid = [blank_row(self.cols) for _ in range(self.rows)]
                            self.row = 0
                            self.col = 0
                        elif self.alt_grid is not None:
                            self.grid = self.alt_grid
                            self.alt_grid = None
                            if self.alt_saved is not None:
                                self.row, self.col = self.alt_saved
                                self.alt_saved = None
        elif final == "s":
            self.saved = (self.row, self.col)
        elif final == "u":
            self.row, self.col = self.saved

    def feed(self, data: str) -> None:
        i = 0
        length = len(data)
        while i < length:
            ch = data[i]
            if ch == "\x1b":
                i = self.escape(data, i)
                continue
            if ch == "\x07":
                i += 1
                continue
            if ch == "\x08":
                self.col = max(0, self.col - 1)
                self.wrap_pending = False
                i += 1
                continue
            if ch == "\t":
                self.col = min(self.cols - 1, (self.col // 8 + 1) * 8)
                self.wrap_pending = False
                i += 1
                continue
            if ch == "\r":
                self.col = 0
                self.wrap_pending = False
                i += 1
                continue
            if ch in ("\n", "\v", "\f"):
                self.linefeed()
                i += 1
                continue
            if ch == "\x0e" or ch == "\x0f" or ch == "\x00":
                i += 1
                continue
            if ch < " ":
                i += 1
                continue
            # Variation selectors never occupy a cell of their own.
            if ch == "\ufe0f" or ch == "\ufe0e":
                i += 1
                continue
            if ch == "\u200d" and i + 1 < length:
                # The pools used by the prompt do not currently contain ZWJ
                # sequences.  Skipping the joiner keeps each base emoji in its
                # own cells rather than dropping it entirely.
                i += 1
                continue
            width = None
            if (
                i + 1 < length
                and data[i + 1] in ("\ufe0f", "\ufe0e")
                and 0x2600 <= ord(ch) <= 0x27BF
            ):
                # Text-default symbols become double width when followed by
                # an emoji presentation selector (for example, heart + VS16).
                width = 2
                i += 1
            self.put(ch, width)
            i += 1

    def escape(self, data: str, index: int) -> int:
        if index + 1 >= len(data):
            return index + 1
        nxt = data[index + 1]
        if nxt == "[":
            j = index + 2
            private = ""
            if j < len(data) and data[j] in "?><!":
                private = data[j]
                j += 1
            start = j
            while j < len(data) and (data[j].isdigit() or data[j] in ";: "):
                j += 1
            if j >= len(data):
                return j
            intermediate = ""
            while j < len(data) and 0x20 <= ord(data[j]) <= 0x2F:
                intermediate += data[j]
                j += 1
            if j >= len(data):
                return j
            final = data[j]
            raw_params = data[start:j]
            if ":" in raw_params and ";" not in raw_params:
                raw_params = raw_params.replace(":", ";")
            params = raw_params.split(";")
            self.csi(private, params, intermediate, final)
            return j + 1
        if nxt == "]":
            j = index + 2
            while j < len(data):
                if data[j] == "\x07":
                    return j + 1
                if data[j] == "\x1b" and j + 1 < len(data) and data[j + 1] == "\\":
                    return j + 2
                j += 1
            return j
        if nxt in "()*+-./":
            return min(len(data), index + 3)
        if nxt == "7":
            self.saved = (self.row, self.col)
            return index + 2
        if nxt == "8":
            self.row, self.col = self.saved
            return index + 2
        if nxt == "M":
            self.reverse_index()
            return index + 2
        if nxt == "D":
            self.linefeed()
            return index + 2
        if nxt == "E":
            self.col = 0
            self.linefeed()
            return index + 2
        if nxt == "c":
            self.grid = [blank_row(self.cols) for _ in range(self.rows)]
            self.row = 0
            self.col = 0
            self.scroll_top = 0
            self.scroll_bottom = self.rows - 1
            self.fg = None
            self.bg = None
            return index + 2
        if nxt in "=>":
            return index + 2
        if nxt in "P^_":
            j = index + 2
            while j < len(data):
                if data[j] == "\x1b" and j + 1 < len(data) and data[j + 1] == "\\":
                    return j + 2
                j += 1
            return j
        return index + 2


def decode(data: bytes) -> str:
    return data.decode("utf-8", "replace")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--cols", type=int, default=120)
    parser.add_argument("--rows", type=int, default=30)
    parser.add_argument("--query", default="screen")
    parser.add_argument("--text", default="")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    with open(args.input, "rb") as handle:
        raw = handle.read()
    screen = Screen(args.cols, args.rows)
    screen.feed(decode(raw))

    if args.query == "screen":
        print(screen.screen_text())
    elif args.query == "scrollback":
        print(screen.scrollback_text())
    elif args.query == "all":
        print(screen.all_text())
    elif args.query == "find":
        on_screen, in_scrollback = screen.find(args.text)
        row, col = screen.cursor()
        print(f"screen={on_screen} scrollback={in_scrollback} cursor_row={row} cursor_col={col}")
    elif args.query == "rows":
        print(" ".join(str(row) for row in screen.rows_with(args.text)))
    elif args.query == "colors":
        colors = screen.colors_on_rows(args.text)
        print(" ".join(f"{r},{g},{b}" for r, g, b in colors))
    elif args.query == "cursor":
        row, col = screen.cursor()
        print(f"{row} {col}")
    elif args.query == "json":
        payload = {
            "screen": screen.screen_text().splitlines(),
            "scrollback": screen.scrollback_text().splitlines(),
            "cursor": list(screen.cursor()),
        }
        print(json.dumps(payload))
    else:
        print(f"unknown query: {args.query}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
