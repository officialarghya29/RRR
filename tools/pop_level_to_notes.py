#!/usr/bin/env python3
"""
One-way study extractor for SDLPoP 1.23 level files.

Purpose: parse the unpacked room-level structs under
SDLPoP-1.23/data/LEVELS/res20NN.bin and emit *study notes*, not game data.

This is for behavioral study only (plan section 2.3):
- It helps a human understand the original room grammar.
- It does NOT produce playable level data for Echoes of Time.
- It does NOT copy any sprite/audio/text/level layout into the project.

Output goes into untracked study/ only. It must never be committed as game data.

Offset provenance (Session 002 correction)
------------------------------------------
Offsets are the byte offsets of each field in the packed level_type struct
declared in SDLPoP-1.23/src/types.h (lines 216-238, #pragma pack(1)).
The field-size walk sums to exactly 2305, matching the port's compile-time
assert (types.h:239) and the size of every res20NN.bin file.

Session 000 used offsets that were misaligned from byte 1850 onward: it read
the used_rooms byte as start_room (25) and an editor x-coordinate as
start_dir (16). Those values were structurally impossible (start_room must
be 1..24; start_dir must be 0 or -1 per the port's direction enum,
types.h:389-391). Corrected here; --selftest pins the correction so the bug
cannot come back.

Room numbering: the port's level code addresses rooms 1-based
(e.g. level.fg[(room-1)*30], seg008.c:1448). This tool indexes rooms
0-based (file offset room*30). Extractor room r == SDLPoP room r+1.
"""

import sys
from pathlib import Path


class LevelType:
    """Parsed view of one res20NN.bin file."""

    LEVEL_SIZE = 2305

    # struct field byte offsets, re-derived from SDLPoP-1.23/src/types.h:216-238
    # (level_type, #pragma pack(1)). Field sizes in parentheses; the walk
    # below sums to 2305, which the --selftest asserts on every run.
    #   fg[720]            0
    #   bg[720]          720
    #   doorlinks1[256] 1440
    #   doorlinks2[256] 1696
    #   roomlinks[24]   1952   (link_type = 4 bytes: left,right,up,down)
    #   used_rooms      2048
    #   roomxs[24]      2049
    #   roomys[24]      2073
    #   fill_1[15]      2097
    #   start_room      2112
    #   start_pos       2113
    #   start_dir       2114   (sbyte: 0 = right, -1 = left)
    #   fill_2[4]       2115
    #   guards_tile[24] 2119
    #   guards_dir[24]  2143
    #   guards_x[24]    2167
    #   guards_seq_lo[24] 2191
    #   guards_skill[24]  2215
    #   guards_seq_hi[24] 2239
    #   guards_color[24]  2263
    #   fill_3[18]      2287
    OFF_FG = 0
    OFF_BG = 720
    OFF_DOORLINKS1 = 1440
    OFF_DOORLINKS2 = 1696
    OFF_ROOMLINKS = 1952
    OFF_USED_ROOMS = 2048
    OFF_ROOMXS = 2049
    OFF_ROOMYS = 2073
    OFF_FILL1 = 2097
    OFF_START_ROOM = 2112
    OFF_START_POS = 2113
    OFF_START_DIR = 2114
    OFF_FILL2 = 2115
    OFF_GUARDS_TILE = 2119
    OFF_GUARDS_DIR = 2143
    OFF_GUARDS_X = 2167
    OFF_GUARDS_SEQ_LO = 2191
    OFF_GUARDS_SKILL = 2215
    OFF_GUARDS_SEQ_HI = 2239
    OFF_GUARDS_COLOR = 2263
    OFF_FILL3 = 2287

    # (field name, size) in declaration order, for the selftest walk.
    FIELD_WALK = [
        ("FG", 720), ("BG", 720), ("DOORLINKS1", 256), ("DOORLINKS2", 256),
        ("ROOMLINKS", 96), ("USED_ROOMS", 1), ("ROOMXS", 24), ("ROOMYS", 24),
        ("FILL1", 15), ("START_ROOM", 1), ("START_POS", 1), ("START_DIR", 1),
        ("FILL2", 4), ("GUARDS_TILE", 24), ("GUARDS_DIR", 24), ("GUARDS_X", 24),
        ("GUARDS_SEQ_LO", 24), ("GUARDS_SKILL", 24), ("GUARDS_SEQ_HI", 24),
        ("GUARDS_COLOR", 24), ("FILL3", 18),
    ]

    @classmethod
    def from_bytes(cls, data: bytes) -> "LevelType":
        n = len(data)
        if n not in (2304, 2305):
            raise ValueError(f"Unexpected length {n}; expected 2304 or 2305")
        if n == 2304:
            # One file in the shipped set (res2015.bin) is a byte short of the
            # port's compile-time size. Pad so tail offsets are addressable;
            # the selftest treats that file's roomlinks as known-non-canonical.
            data = data + b"\x00"
        return cls(data)

    def __init__(self, data: bytes) -> None:
        self._data = data
        self._true_len = len(data)

    # -- tiles ---------------------------------------------------------------

    def fg(self, room: int, tile: int) -> int:
        if not (0 <= room < 24 and 0 <= tile < 30):
            raise ValueError("room/tile out of range")
        return self._data[self.OFF_FG + room * 30 + tile]

    def bg(self, room: int, tile: int) -> int:
        if not (0 <= room < 24 and 0 <= tile < 30):
            raise ValueError("room/tile out of range")
        return self._data[self.OFF_BG + room * 30 + tile]

    # -- rooms ---------------------------------------------------------------

    def roomlinks(self, room: int) -> tuple:
        """(left, right, up, down) for extractor room index `room` (0-based).

        Port convention: level.roomlinks[room1based - 1] (seg005.c:230),
        values are 1-based room numbers, 0 = no link.
        """
        if not (0 <= room < 24):
            raise ValueError("room out of range")
        base = self.OFF_ROOMLINKS + room * 4
        return (self._data[base], self._data[base + 1],
                self._data[base + 2], self._data[base + 3])

    def used_rooms_raw(self) -> int:
        return self._data[self.OFF_USED_ROOMS]

    def used_rooms(self) -> int:
        """Clamped room count, matching the port's own behaviour.

        SDLPoP clamps the raw byte to ROOMCOUNT (24) because some shipped
        levels store 25: seg000.c:1158-1159 and seg008.c:1163-1164 both
        carry the comment "level.used_rooms is 25 on some levels. Limit it
        to the actual number of rooms."
        """
        return min(self.used_rooms_raw(), 24)

    def room_xs(self, room: int) -> int:
        return self._data[self.OFF_ROOMXS + room]

    def room_ys(self, room: int) -> int:
        return self._data[self.OFF_ROOMYS + room]

    # -- start of level ------------------------------------------------------

    def start_room(self) -> int:
        """1-based room number (port convention), as stored in the file."""
        return self._data[self.OFF_START_ROOM]

    def start_pos(self) -> int:
        """Tile position 0..29 within the start room."""
        return self._data[self.OFF_START_POS]

    def start_dir(self) -> int:
        """sbyte direction: 0 = right (dir_0_right), -1 = left (dir_FF_left)."""
        b = self._data[self.OFF_START_DIR]
        return b - 256 if b >= 128 else b

    # -- guards --------------------------------------------------------------

    def guard_tile(self, room: int) -> int:
        if not (0 <= room < 24):
            raise ValueError(f"guard room out of range: {room}")
        return self._data[self.OFF_GUARDS_TILE + room]

    def guard_dir(self, room: int) -> int:
        return self._data[self.OFF_GUARDS_DIR + room]

    def guard_x(self, room: int) -> int:
        if not (0 <= room < 24):
            raise ValueError(f"guard room out of range: {room}")
        return self._data[self.OFF_GUARDS_X + room]

    def guard_skill(self, room: int) -> int:
        return self._data[self.OFF_GUARDS_SKILL + room]

    def guard_seq_lo(self, room: int) -> int:
        if not (0 <= room < 24):
            raise ValueError(f"guard room out of range: {room}")
        return self._data[self.OFF_GUARDS_SEQ_LO + room]

    def guard_seq_hi(self, room: int) -> int:
        return self._data[self.OFF_GUARDS_SEQ_HI + room]

    def guard_color(self, room: int) -> int:
        return self._data[self.OFF_GUARDS_COLOR + room]

    # -- doorlinks (plate/gate wiring) ---------------------------------------

    def doorlink_count_nonzero(self) -> int:
        n = 0
        for i in range(256):
            if self._data[self.OFF_DOORLINKS1 + i] or self._data[self.OFF_DOORLINKS2 + i]:
                n += 1
        return n

    def doorlink_entries(self) -> list:
        """Nonzero doorlink entries as dicts.

        Field extraction mirrors the port's accessors (seg007.c:713-730):
          tile  = doorlinks1[i] & 0x1F
          next  = !(doorlinks1[i] & 0x80)        (1 = continues chain)
          room  = ((doorlinks1[i] & 0x60) >> 5) + ((doorlinks2[i] & 0xE0) >> 3)
          timer = doorlinks2[i] & 0x1F           (ticks; plate hold budget)
        """
        out = []
        for i in range(256):
            d1 = self._data[self.OFF_DOORLINKS1 + i]
            d2 = self._data[self.OFF_DOORLINKS2 + i]
            if d1 == 0 and d2 == 0:
                continue
            out.append({
                "index": i,
                "tile": d1 & 0x1F,
                "next": 0 if (d1 & 0x80) else 1,
                "room": ((d1 & 0x60) >> 5) + ((d2 & 0xE0) >> 3),
                "timer": d2 & 0x1F,
            })
        return out

    # -- grids ---------------------------------------------------------------

    def level_rooms(self) -> list:
        """Ordered rows of fg tile ids for the clamped room count."""
        rooms = []
        for r in range(self.used_rooms()):
            rooms.append([self.fg(r, t) for t in range(30)])
        return rooms


TILE_NAMES = {
    0: "empty", 1: "floor", 2: "spike", 3: "pillar", 4: "gate",
    5: "stuck", 6: "closer", 7: "doortop_with_floor",
    8: "bigpillar_bottom", 9: "bigpillar_top", 10: "potion",
    11: "loose_floor", 12: "tapestry_top", 13: "mirror", 14: "debris",
    15: "raise_button", 16: "exit_door_left", 17: "exit_door_right",
    18: "chomper", 19: "torch", 20: "wall", 21: "skeleton", 22: "sword",
    23: "balcony_left", 24: "balcony_right", 25: "lattice_pillar",
    26: "lattice_down", 27: "lattice_small", 28: "lattice_left",
    29: "lattice_right", 30: "torch_with_debris",
}  # names per SDLPoP src/types.h:113-131 (enum tiles); corrected in Session 002
# (entries 5/6/7/10 previously named drop_button/tapestry_bottom/potion/unknown_10).


def tile_label(t: int) -> str:
    return TILE_NAMES.get(t, f"tile_{t}")


def write_study_page(index: int, level: LevelType, path: Path) -> None:
    raw = level.used_rooms_raw()
    used = level.used_rooms()
    lines = [
        f"# study/level_{index:02d}.txt — SDLPoP level {index:02d} (res20{index:02d}.bin)\n",
        "# Study note only. Not playable level data. Not for commit as game data.\n",
        f"# Unpack size: {level._true_len} bytes (level_type == 2305 in SDLPoP).\n",
        f"# Used rooms: raw byte = {raw}, clamped = {used} "
        "(port clamps >24; seg000.c:1158-1159).\n",
        "# Room indices below are 0-based file indices; SDLPoP room numbers are index+1.\n",
        "# Rooms with editor x == 255 are unused placeholders in the original data.\n\n",
    ]

    rooms = level.level_rooms()
    lines.append("## Room tiles (10 cols x 3 rows, clamped room count)\n\n")
    for r in range(used):
        mark = "  [editor-unused]" if level.room_xs(r) == 255 else ""
        lines.append(
            f"room {r:2d} (=SDLPoP room {r + 1:2d}) "
            f"(editor x={level.room_xs(r)}, y={level.room_ys(r)}){mark} fg:"
        )
        for row in range(3):
            tiles = [level.fg(r, row * 10 + col) for col in range(10)]
            lines.append("   " + " ".join(f"{t:2d}" for t in tiles))
        lines.append("")
    lines.append("\n")

    lines.append("## Modifier bytes (bg) for room 0 (study sample)\n\n")
    for row in range(3):
        tiles = [level.bg(0, row * 10 + col) for col in range(10)]
        lines.append("   " + " ".join(f"{t:2d}" for t in tiles))
    lines.append("")
    lines.append("# bg interpretation is position-dependent (floor / button / spike / loose).\n")
    lines.append("# See SDLPoP src for the exact rules; this file lists the raw bytes only.\n\n")

    lines.append("## Room links (left right up down) per room\n\n")
    for r in range(used):
        l, ri, u, d = level.roomlinks(r)
        lines.append(f"room {r:2d}: left={l} right={ri} up={u} down={d}\n")
    lines.append("# 0 means no link in that direction; values are 1-based SDLPoP room numbers.\n\n")

    lines.append("## Doorlink entries (plate/gate wiring; nonzero only)\n\n")
    entries = level.doorlink_entries()
    lines.append(f"# count = {len(entries)} (of 256 slots)\n")
    lines.append("# timer = doorlinks2 & 0x1F (ticks; plate hold budget, seg007.c:713-715)\n")
    lines.append("# next  = 1 means the chain continues to the next link index\n\n")
    for e in entries:
        lines.append(
            f"link {e['index']:3d}: room={e['room']:2d} tile={e['tile']:2d} "
            f"timer={e['timer']:2d} next={e['next']}\n"
        )
    lines.append("\n")

    lines.append("## Start-of-level and guard facts (study only)\n\n")
    sr = level.start_room()
    lines.append(
        f"start_room={sr} (1-based SDLPoP room; 0-based file index {sr - 1 if 1 <= sr <= 24 else 'n/a'}) "
        f"start_pos={level.start_pos()} start_dir={level.start_dir()} "
        "(dir: 0=right, -1=left)\n\n"
    )
    lines.append("# guards_tile by room (tile index; >=30 means no guard, seg002.c:115):\n")
    for r in range(used):
        gt = level.guard_tile(r)
        lines.append(f"  room {r:2d}: tile={gt}\n")
    lines.append("\n# guards_dir by room:\n")
    for r in range(used):
        lines.append(f"  room {r:2d}: dir={level.guard_dir(r)}\n")
    lines.append("\n# guards_x by room:\n")
    for r in range(used):
        lines.append(f"  room {r:2d}: x={level.guard_x(r)}\n")
    lines.append("\n# guards_skill by room:\n")
    for r in range(used):
        lines.append(f"  room {r:2d}: skill={level.guard_skill(r)}\n")
    lines.append("\n# guards_seq_hi by room:\n")
    for r in range(used):
        lines.append(f"  room {r:2d}: seq_hi={level.guard_seq_hi(r)}\n")
    lines.append("\n# guards_color by room:\n")
    for r in range(used):
        lines.append(f"  room {r:2d}: color={level.guard_color(r)}\n")
    lines.append("\n# Note: these guard fields are facts about the original data layout, not\n")
    lines.append("# reused gameplay data. Echoes of Time uses its own enemy instances.\n\n")

    path.write_text("".join(lines))


# ---------------------------------------------------------------------------
# Self-test: real assertions, not "section exists" checks.
# ---------------------------------------------------------------------------

def selftest(levels_dir: Path) -> int:
    failures = 0

    def check(cond: bool, label: str) -> None:
        nonlocal failures
        if cond:
            print(f"  PASS  {label}")
        else:
            failures += 1
            print(f"  FAIL  {label}")

    print("== selftest: offset walk ==")
    off = 0
    offsets_ok = True
    for name, size in LevelType.FIELD_WALK:
        expected = getattr(LevelType, "OFF_" + name)
        if expected != off:
            offsets_ok = False
            print(f"    mismatch: OFF_{name} = {expected}, walk says {off}")
        off += size
    check(off == LevelType.LEVEL_SIZE,
          f"field walk sums to {LevelType.LEVEL_SIZE} (got {off})")
    check(offsets_ok, "every OFF_* constant matches the declaration-order walk")

    print("== selftest: per-file semantic ranges ==")
    files = sorted(levels_dir.glob("res20*.bin"))
    check(len(files) >= 15, f"found {len(files)} res20*.bin files (want >= 15)")
    for p in files:
        data = p.read_bytes()
        if len(data) < 2115:
            print(f"    skip {p.name}: too short for start fields ({len(data)} bytes)")
            continue
        lvl = LevelType.from_bytes(data)
        sr, sp, sd = lvl.start_room(), lvl.start_pos(), lvl.start_dir()
        check(1 <= sr <= 24, f"{p.name}: start_room={sr} in 1..24")
        check(0 <= sp <= 29, f"{p.name}: start_pos={sp} in 0..29")
        check(sd in (-1, 0), f"{p.name}: start_dir={sd} in {{-1, 0}}")
        if len(data) == 2305:
            bad = []
            for r in range(24):
                for v in lvl.roomlinks(r):
                    if v > 24:
                        bad.append((r, v))
            check(not bad, f"{p.name}: all roomlinks values <= 24")
            for r in range(24):
                if lvl.guard_tile(r) < 30:
                    sk = lvl.guard_skill(r)
                    if sk > 11:
                        check(False,
                              f"{p.name}: guard at room {r} has skill {sk} > 11 "
                              "(skill tables are 12 wide, data.h:841-847)")
        else:
            print(f"    note {p.name}: {len(data)} bytes (non-canonical); "
                  "roomlinks not range-checked")

    print("== selftest: regression pin on res2000.bin ==")
    p = levels_dir / "res2000.bin"
    if p.exists():
        lvl = LevelType.from_bytes(p.read_bytes())
        check(lvl.start_room() == 1, "res2000: start_room == 1")
        check(lvl.start_pos() == 9, "res2000: start_pos == 9")
        check(lvl.start_dir() == -1, "res2000: start_dir == -1 (left)")
        check(lvl.used_rooms_raw() == 25, "res2000: used_rooms raw byte == 25")
        check(lvl.used_rooms() == 24, "res2000: used_rooms clamped == 24")
        check(lvl.roomlinks(0) == (2, 0, 0, 7), "res2000: roomlinks[0] == (2,0,0,7)")
        check(lvl.guard_tile(3) == 2, "res2000: guard present in file-room 3 (tile 2)")
        check(lvl.guard_skill(3) == 5, "res2000: that guard has skill 5")
        raw = p.read_bytes()
        old_val = raw[2048]
        check(not (1 <= old_val <= 24),
              f"negative control: old offset 2048 reads {old_val}, out of 1..24 "
              "(documents the Session 000 offset bug)")
    else:
        check(False, "res2000.bin present for regression pin")

    print(f"== selftest: {failures} failure(s) ==")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "--selftest":
        levels_dir = Path(argv[2]) if len(argv) >= 3 else Path("SDLPoP-1.23/data/LEVELS")
        return selftest(levels_dir)

    if len(argv) < 2:
        print("Usage: pop_level_to_notes.py [--selftest [SDLPoP_dir]] "
              "[SDLPoP_dir] <ignored> [first_index]", file=sys.stderr)
        print("       (positional mode: study notes into ./study/)", file=sys.stderr)
        return 2

    sdlpop_dir = Path(argv[1])
    levels_dir = sdlpop_dir / "data" / "LEVELS"
    if not levels_dir.is_dir():
        print(f"Not a level directory: {levels_dir}", file=sys.stderr)
        return 1

    first_index = int(argv[3]) if len(argv) >= 4 else 0
    out_dir = Path("study")
    out_dir.mkdir(exist_ok=True)

    for i in range(16):
        path = levels_dir / f"res20{i:02d}.bin"
        if not path.exists():
            continue
        data = path.read_bytes()
        try:
            level = LevelType.from_bytes(data)
        except ValueError as exc:
            print(f"skip {path.name}: {exc}", file=sys.stderr)
            continue
        write_study_page(first_index + i, level, out_dir / f"level_{first_index + i:02d}.txt")
        print(f"wrote study/level_{first_index + i:02d}.txt")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
