#!/usr/bin/env python3
"""Cross-check SDLPoP's --screenshot-level map against our level extraction.

Reads the map PNG produced by `prince ... --screenshot --screenshot-level
--screenshot-level-extras` and locates the yellow annotation pixels (the
"start ->" marker and the guard "sN hN" label, both drawn in
color_14_brightyellow — SDLPoP src/screenshot.c:426-457). It then compares the
found clusters against the start/guard positions computed from our own
extraction (study/level_NN.txt facts, i.e. tools/pop_level_to_notes.py output).

Pure standard library (zlib only) — no PIL needed. Study tool; output is a
numeric cross-check, not a pass/fail gate on its own (visual confirmation is
still the plan's literal Accept for A1.1).

Usage: python3 tools/map_shot_check.py <png> <level_index>
       (level_index = NN from study/level_NN.txt, e.g. 01 for res2001)
"""
import struct
import sys
import zlib
import re
from pathlib import Path

# Map geometry from SDLPoP src/screenshot.c:578-581 and the tile drawing code:
# each room cell is 320x189 px, each tile is 32x63 px, image_height = h*189+11.
CELL_W, CELL_H = 320, 189
TILE_W, TILE_H = 32, 63


def read_png_rgba(path):
    data = Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a PNG"
    pos, idat, width, height, depth, ctype = 8, [], 0, 0, 0, 0
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if tag == b"IHDR":
            width, height, depth, ctype = struct.unpack(">IIBB", body[:10])
        elif tag == b"IDAT":
            idat.append(body)
        elif tag == b"IEND":
            break
        pos += 12 + length
    assert depth == 8 and ctype == 6, f"expected 8-bit RGBA, got depth={depth} ctype={ctype}"
    raw = zlib.decompress(b"".join(idat))
    stride = width * 4
    out = bytearray(height * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(height):
        f = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        if f == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                left = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return width, height, out


def yellow_clusters(width, height, rgba, bucket=24):
    """Coarse connected components over bright-yellow pixels."""
    occupied = set()
    for y in range(height):
        row = y * width * 4
        for x in range(width):
            i = row + x * 4
            r, g, b, a = rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]
            if a and r > 200 and g > 200 and b < 90:
                occupied.add((x // bucket, y // bucket))
    clusters = []
    while occupied:
        seed = occupied.pop()
        stack, comp = [seed], [seed]
        while stack:
            cx, cy = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nb = (cx + dx, cy + dy)
                    if nb in occupied:
                        occupied.discard(nb)
                        stack.append(nb)
                        comp.append(nb)
        xs = [c[0] for c in comp]
        ys = [c[1] for c in comp]
        clusters.append({
            "bbox": (min(xs) * bucket, min(ys) * bucket,
                     (max(xs) + 1) * bucket, (max(ys) + 1) * bucket),
            "cells": len(comp),
        })
    clusters.sort(key=lambda c: -c["cells"])
    return clusters


def extract_facts(level_idx):
    """Pull start/guard/editor facts back out of our own study output."""
    txt = Path(f"study/level_{level_idx:02d}.txt").read_text()
    m = re.search(r"start_room=(\d+).*?start_pos=(\d+) start_dir=(-?\d+)", txt)
    start_room, start_pos, start_dir = (int(g) for g in m.groups())
    editors = dict(
        (int(r), (int(x), int(y)))
        for r, x, y in re.findall(
            r"room\s+(\d+) \(=SDLPoP room\s+\d+\) \(editor x=(\d+), y=(\d+)\)", txt)
    )
    tiles = dict((int(r), int(t)) for r, t in
                 re.findall(r"room\s+(\d+): tile=(\d+)", txt))
    skills = dict((int(r), int(s)) for r, s in
                  re.findall(r"room\s+(\d+): skill=(\d+)", txt))
    return start_room, start_pos, start_dir, editors, tiles, skills


def near(bbox, x0, y0, x1, y1, tol=48):
    return (bbox[0] - tol <= x0 <= bbox[2] + tol and bbox[1] - tol <= y0 <= bbox[3] + tol) or \
           (abs((bbox[0] + bbox[2]) // 2 - (x0 + x1) // 2) <= tol + (x1 - x0) and
            abs((bbox[1] + bbox[3]) // 2 - (y0 + y1) // 2) <= tol + (y1 - y0))


def main():
    png, level_idx = sys.argv[1], int(sys.argv[2])
    width, height, rgba = read_png_rgba(png)
    print(f"png {width}x{height}; cells {width // CELL_W}x"
          f"{(height - 11) // CELL_H} (expect integer grid)")

    start_room, start_pos, start_dir, editors, tiles, skills = extract_facts(level_idx)
    print(f"our facts: start_room={start_room} start_pos={start_pos} "
          f"start_dir={start_dir}")

    # Two candidate layouts: the editor coordinates we extract, normalized to
    # the minimum x/y seen (SDLPoP may instead BFS from room 1 via roomlinks;
    # we test the editor layout here and report clusters for manual/BFS audit).
    used = {r: p for r, p in editors.items() if p[0] != 255}
    min_x = min(p[0] for p in used.values())
    min_y = min(p[1] for p in used.values())

    def cell_of(room_idx):
        x, y = used[room_idx]
        return x - min_x, y - min_y

    def tile_rect(room_idx, tilepos):
        c, r = cell_of(room_idx)
        col, row = tilepos % 10, tilepos // 10
        x0, y0 = c * CELL_W + col * TILE_W, r * CELL_H + row * TILE_H
        return x0, y0, x0 + TILE_W, y0 + TILE_H

    s_cell = cell_of(start_room - 1)
    s_rect = tile_rect(start_room - 1, start_pos)
    print(f"editor-layout cell for start room: {s_cell}, tile rect {s_rect}")

    guard_idx = None
    for r, t in sorted(tiles.items()):
        if t < 30 and r in used:
            guard_idx = r
            break
    g_rect = tile_rect(guard_idx, tiles[guard_idx]) if guard_idx is not None else None
    if guard_idx is not None:
        hp_guess = f"s{skills.get(guard_idx, -1)} h?"
        print(f"our facts: guard file-room {guard_idx} tile {tiles[guard_idx]} "
              f"({hp_guess}), tile rect {g_rect}")

    clusters = yellow_clusters(width, height, rgba)
    print(f"\nyellow clusters found: {len(clusters)}")
    for cl in clusters:
        print(f"  bbox={cl['bbox']} cells={cl['cells']}")

    def match(rect, label):
        if rect is None:
            print(f"  {label}: no expected rect (no guard?)")
            return False
        x0, y0, x1, y1 = rect
        hits = [c for c in clusters if near(c["bbox"], x0, y0, x1, y1)]
        ok = bool(hits)
        print(f"  {label} expected near {rect}: "
              f"{'MATCH' if ok else 'NO MATCH in this layout'}"
              + (f" -> {hits[0]['bbox']}" if hits else ""))
        return ok

    print("\ncross-check (editor-coordinate layout):")
    start_ok = match(s_rect, "start marker")
    guard_ok = match(g_rect, "guard label ")
    if not (start_ok and guard_ok):
        print("note: a miss may mean SDLPoP laid the map out by BFS from the "
              "start room instead of editor coordinates — inspect cluster "
              "positions against the PNG visually before concluding.")
    return 0 if (start_ok and guard_ok) else 2


if __name__ == "__main__":
    sys.exit(main())
