#!/usr/bin/env python3
"""Re-decode SDLPoP frame_table_kid[] and compare with our carried rows.

Reads:
  SDLPoP-1.23/src/seg006.c  (the frame_type frame_table_kid[] initializer)
  SDLPoP-1.23/src/types.h   (the frame_N enum -> role names)
  scripts/pop/pop_tables.gd (our KID_FRAME dictionary)

Theory under test: the C array initializer is POSITION-indexed (position ==
frame id per types.h: frame_141_climbing_7 = 141), the first field of each
row is the *image* id (which may differ from the position on blank/absent
ids), and rows whose first field is 255 are placeholder blanks.
"""
import re
import sys

REF = "SDLPoP-1.23/src/seg006.c"


def parse_reference():
    src = open(REF, encoding="utf-8", errors="replace").read()
    start = src.index("frame_table_kid")
    depth = 0
    body = ""
    for i, ch in enumerate(src[start:], start):
        if ch == "{":
            depth += 1
            if depth == 2 and not body:  # outer { consumed by ==2? outer is 1
                continue
        elif ch == "}":
            depth -= 1
            if depth == 0:
                break
        body += ch
        # crude but works: capture between the first '{' after the name and its matching '}'
    # simpler: cut from '=' to the final '};'
    m = re.search(r"frame_table_kid\[\]\s*=\s*\{(.*?)\};", src, re.S)
    body = m.group(1)
    rows = []
    # rows look like: { 148, 0x00| 4, -32... } -> { image, sword, dx, dy, flags }
    row_re = re.compile(
        r"\{\s*(\d+),\s*0x([0-9A-Fa-f]{2})\|\s*(\d+)?[^,]*,\s*(-?\d+),\s*(-?\d+),\s*0x([0-9A-Fa-f]{2})\|\s*(\d+)?\s*\}",
        re.S,
    )
    for mm in row_re.finditer(body):
        image = int(mm.group(1))
        sword_hi = int(mm.group(2), 16)
        sword_lo = int(mm.group(3) or 0)
        dx = int(mm.group(4))
        dy = int(mm.group(5))
        flags_hi = int(mm.group(6), 16)
        w = int(mm.group(7) or 0)
        rows.append(
            {
                "image": image,
                "sword": sword_hi | sword_lo,
                "dx": dx,
                "dy": dy,
                "flags": flags_hi | w,
            }
        )
    return rows


def role_names():
    src = open("SDLPoP-1.23/src/types.h", encoding="utf-8", errors="replace").read()
    names = {}
    for m in re.finditer(r"frame_(\d+)_(\w+)\s*=\s*(\d+)", src):
        names[int(m.group(3))] = m.group(2)
    return names


def flags_of(v):
    return {
        "needs_floor": 1 if v & 0x40 else 0,
        "thin": 1 if v & 0x20 else 0,
        "even_odd": 1 if v & 0x80 else 0,
        "weight": v & 0x1F,
        "sword": (v >> 3) & 0x3,
    }


def our_rows():
    src = open("scripts/pop/pop_tables.gd", encoding="utf-8").read()
    m = re.search(r"KID_FRAME: Dictionary = \{(.*?)\n\}", src, re.S)
    body = m.group(1)
    out = {}
    for mm in re.finditer(r"(\d+): \{ .*? \}", body):
        fid = int(mm.group(1))
        row = {}
        for k, v in re.findall(r'"(\w+)": (-?\d+)', mm.group(0)):
            row[k] = int(v)
        out[fid] = row
    return out


def main():
    ref = parse_reference()
    names = role_names()
    ours = our_rows()
    print(f"reference initializer rows: {len(ref)}; our KID_FRAME rows: {len(ours)}")

    problems = 0
    for pos, row in enumerate(ref):
        if row["image"] == 255:
            continue
        role = names.get(pos, "?")
        # position vs image consistency
        if row["image"] != pos:
            problems += 1
            print(f"  POS{pos:3d} image {row['image']:3d}  (role {role})  dx={row['dx']:3d} dy={row['dy']:3d} flags=0x{row['flags']:02X}")
    print(f"rows where image != position: {problems}")

    # Diff ours vs reference by position (position == frame id hypothesis)
    print("\n-- ours vs reference (id -> ref row by position) --")
    bad = 0
    for fid in sorted(ours):
        if fid >= len(ref) or ref[fid]["image"] == 255:
            print(f"  {fid:3d}: NO reference row at position {fid}")
            bad += 1
            continue
        # pos(fid)=1+fid↔image(1+fid)=fid+151 for the hanging/climbing band
        # (ids ≥86); low ids are mostly identity positions — probe both.
        hi = 1 + fid
        r = ref[fid] if fid < 86 else ref[hi]
        used_pos = fid if fid < 86 else hi
        rf = flags_of(r["flags"])
        o = ours[fid]
        diffs = []
        if o["dx"] != r["dx"]:
            diffs.append(f"dx {o['dx']}!={r['dx']}")
        if o.get("dy", 0) != r["dy"]:
            diffs.append(f"dy {o.get('dy')}!={r['dy']}")
        if o["weight"] != rf["weight"]:
            diffs.append(f"w {o['weight']}!={rf['weight']}")
        if o["needs_floor"] != rf["needs_floor"]:
            diffs.append(f"floor {o['needs_floor']}!={rf['needs_floor']}")
        if o["thin"] != rf["thin"]:
            diffs.append(f"thin {o['thin']}!={rf['thin']}")
        if o["even_odd"] != rf["even_odd"]:
            diffs.append(f"eo {o['even_odd']}!={rf['even_odd']}")
        role = names.get(used_pos, "?")
        if diffs:
            bad += 1
            print(f"  {fid:3d} ({role:28s}): {' | '.join(diffs)}")
    print(f"rows differing: {bad}")


if __name__ == "__main__":
    sys.exit(main())
