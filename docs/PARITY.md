# PARITY.md — reference behavior facts for plan §4.3 and §8

This file is the tracked table of *measured reference facts* our sim must match
(plan A1.2). Q1 was answered on 2026-10-06 (review.md): **measured constants with
citation are acceptable in tracked files**. House rules for everything below:

- Every number carries a `file:line` citation into `SDLPoP-1.23/src/` (behavioral
  reference, GPL-3 — cited as fact, never copied as code).
- No code and no reference tables are pasted verbatim; values are re-expressed in
  this file's schema. Arithmetic done here is marked [D].
- "Ours" columns are filled by `scripts/pop/` measurements (plan §8 gates 2–3) and
  stay empty until those gates exist.
- Observation status: the reference binary now **builds and runs locally**
  (Session 002, approved); the screenshot cross-check has run (A1.1), but no
  *gameplay behavior* number below has yet been confirmed by observation — all are
  source-derived [S] or byte-measured [M]. Timer/behavior observation is next.
- Rate basis: **one tick = one logic frame = 1/12 s traversing, 1/10 s with the
  sword drawn** (see §1). Nothing here is per-60 Hz-timer-tick.

## 1. Tick clock

| Quantity | Value | Citation |
|---|---|---|
| Timer resolution | 60 Hz | `types.h:1351`, `seg009.c:3732-3741` |
| Logic frame, traverse | `base_speed = 5` timer ticks → **12 fps** | `seg003.c:350-372`, `data.h:858` |
| Logic frame, sword drawn | `fight_speed = 6` timer ticks → **10 fps** | `seg003.c:360-363`, `data.h:859` |
| Sequence frame rate | one seqtbl frame per logic frame | `seg006.c:570-684` |
| In-game minute | 720 logic frames (`rem_tick` 719→0; comment "720=12*60") | `seg008.c:1761-1763`, called at `seg000.c:895` |
| In-game second | every 12 logic frames (`rem_tick % 12`) | `seg008.c:1777`, `seg008.c:1787` |

Port: SimClock steps at 12 Hz, switches to 10 Hz while the sword is drawn
(plan A3.1 / §8 P8).

## 2. Movement semantics

| Rule | Value | Citation |
|---|---|---|
| Horizontal step | sequence `dx(n)` moves the character `n` internal units in its facing direction (negated facing left) | `seg006.c:575-578`, `seg006.c:553-557`, `types.h:389-391` |
| Vertical step | `dy(n)` adds to y; y grows downward; rows are 63 units apart | `seg006.c:579-582`, `data.h:506`, `types.h:1408` |
| Row change | separate up/down opcodes only; dy never changes row | `seg006.c:570-684` |
| Unit scale | tile = 14 internal units wide (32 screen px), 63 tall | `types.h:1405`, `types.h:1408` |
| Floor y per row | `y_land[row+1]` = −8, 55, 118, 181, 254 | `data.h:506` |

## 3. Run cycle (dx per frame)

Source `seqtbl.c:246-260` (labels: `runcyc1` 251, `runcyc7` 257).

| frame | f7 | f8 | f9 | f10 | f11 | f12 | f13 | f14 | →f7 |
|---|---|---|---|---|---|---|---|---|---|
| dx | 3 (entry) | 5 | 1 | 2 | 4 | 5 | 2 | 3 | 4 |

- Steady cycle: 8 frames, **26 units** [D] ≈ 1.86 tiles/cycle → ≈ **2.8 tiles/s**
  at 12 fps; 10-tile room ≈ 3.6 s [D].
- Start-up: f1–f4 stationary, then dx 8 (f5), 3 (f6) into the cycle
  (`seqtbl.c:247-251`). Footsteps on f9/f13 (`seqtbl.c:254,257`).
- Ours: — pending gate 2.

## 4. Standing jump (frame/dx/dy stream)

Source `seqtbl.c:381-400` (`sjland` label at 391).

| frame | f16 | f17 | f18–f22 | f23 | f24 | f25 | f26 | f27 | f28 | f29 | f30–f33 | stand |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dx | 0 | 0 | 2 each | 7 | 9 | 5 | 1 | 4 | −3 | 5 | 0 | 1 |
| dy | 0 | 0 | 0 | 0 | 0 | −6 | +6 | 0 | 0 | 0 | 0 | 0 |
| cum x | 0 | 0 | 2→10 | 17 | 26 | 31 | 32 | 36 | 33 | 38 | 38 | 39 |

- Crouch phase 5 frames × dx2; landing impact frame f27 (knock + footstep,
  `seqtbl.c:393`); horizontal at landing ≈ **36 units ≈ 2.57 tiles** [D].
- No row change; vertical excursion only 6 units. Ours: — pending gate 2.

## 5. Run jump (frame/dx/dy stream)

Source `seqtbl.c:402-416` (`rjlandrun` label at 413).

| frame | f34 | f35 | f36 | f37 | f38 | f39 | f40 | f41 | f42 | f43 | f44 | →f7 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dx | 0 | 5 | 6 | 3 | 5 | 7 | 12 | 8 | 8 | 4 | 4 | 5 |
| dy | 0 | 0 | 0 | 0 | 0 | 0 | −3 | −9 | −2 | +11 | +3 | 0 |
| cum x | 0 | 5 | 11 | 14 | 19 | 26 | 38 | 46 | 54 | 58 | 62 | 67 |
| cum y | 0 | 0 | 0 | 0 | 0 | 0 | −3 | −12 | −14 | −3 | 0 | 0 |

- Approach 26 units (same pre-flight as standing jump); airborne frames f40–f44 =
  36 units, apex −14 units at f42; total f34→f7 = **67 units ≈ 4.79 tiles** [D].
- Gap-span targets for A2.2's acceptance (stand-jump 1 tile, run-jump 2 tiles of
  *cleared gap*) get pinned by edge-position measurement in gate 2; the streams
  above are the ground truth. Ours: — pending gate 2.

## 6. Hang and climb geometry

| Sequence | Frames | Geometry | Citation |
|---|---|---|---|
| hang sway | f91 + 42-frame loop (sprites f87–f99), then auto-drop | 43 frames ≈ 3.6 s at 12 fps [D] | `seqtbl.c:554-567` |
| hangstraight | f92,f93,f93,f92,f92 then f91 loop | no auto-drop | `seqtbl.c:569-573` |
| climb up | 6 frames (f135–f140), then dx +5, dy −63, row−1, f141 … stand at frame 18 | row = **63 units**; ≈1.5 s | `seqtbl.c:590-600` |
| climb down | 6 frames, then dx −5, dy +63, row+1 → hang sway in 10 frames | mirrored; ≈0.8 s | `seqtbl.c:581-588` |
| climb fail | 11 frames, dx −7 → hangdrop | | `seqtbl.c:575-579` |
| hangdrop | f81–f85 then dx +3 → stand | 5 frames | `seqtbl.c:602-607` |
| mid-air grab | Shift held; fall speed < 32 (30 with port fix); alive; floor row ≤ 25 y-units below; probe −8 units | success: snap x/y, reset fall, `grab_timer = 12` frames (≈1 s) | `seg006.c:1159-1201`, timer `seg006.c:1387-1388` |

## 7. Fall thresholds

| Quantity | Value | Citation |
|---|---|---|
| Integration | fall speed +3 per logic frame, cap 33 (feather: +1, cap 4) | `seg006.c:873-877`, `types.h:1413-1416` |
| Scream starts | impact speed ≥ 31 | `seg005.c:37-40` |
| Soft land | speed < 22 → crouch, no damage | `seg005.c:174-180` |
| Medium land | 22 ≤ speed < 33 → −1 HP | `seg005.c:187-196` |
| Death | speed ≥ 33 → crushed | `seg005.c:197-208` |

Thresholds are on **impact speed** (proportional to drop height through the +3/frame
integration) [D]. Ours: — pending gate 2 (3-row kill / 2-row −1 HP acceptance).

## 8. Spike cycle

State machine from `animate_spike` (`seg007.c:310-329`); durations counted here [D]:

| Phase | Modifier states | Frames | Harmful? |
|---|---|---|---|
| extend | 0→1→2→3→4→(5→0x8F) | 5 | yes while 1–4 (class 2) |
| extended hold | 0x8F→…→0x81→6 | 15 | yes (class 1) |
| retract | 6→7→8→(9→0, stop) | 3 | no |
| disabled | 0xFF | permanent | no (set on a kill, `seg005.c:216-218`) |

Full cycle ≈ **23 logic frames ≈ 1.9 s** at 12 fps [D]. Harmfulness classes:
`is_spike_harmful()` (`seg007.c:1171-1176`); contact rules differ for running frames
(class ≥2 hurts) vs landing frames 43/26 (any nonzero hurts) — `seg006.c:950-964`,
`seg005.c:161-164`. Ours: — pending A4.2.

## 9. Gate and level-door speeds

Gate modifier: 0 = closed, ≥188 = open, 238 = parked after opening, 0xFF = permanent
(`seg007.c:336-403`).

| Motion | Speed (units/logic frame) | Citation |
|---|---|---|
| normal closing | −1 (`door_delta[0]`) | `seg007.c:334`, `seg007.c:364` |
| opening / permanent | +4 (`door_delta[1..2]`) | `seg007.c:334`, `seg007.c:364` |
| fast close (types 3–8) | 20, 40, 60, 80, 100, 120; type auto-increments each frame up to 8 | `seg007.c:332`, `seg007.c:344-352` |
| open reached | ≥188 → snap 238 → switch to closing; permanent → 0xFF | `seg007.c:378-397` |
| close reached | 0 → stop + sound | `seg007.c:366-367`, `seg007.c:405-409` |
| level (exit) door | fast-close speeds {0,5,17,99}, starts open at modifier 43, clamps 0 | `seg007.c:411`, `seg007.c:424-431`, `seg007.c:795-798` |

Modifier↔pixel mapping not derived; ±1-tick gate acceptance applies at the modifier
level. Ours: — pending A4.1.

## 10. Plate / doorlink timing

| Field | Encoding | Range | Citation |
|---|---|---|---|
| target tile | `d1 & 0x1F` | 0–29 | `seg007.c:725-727` |
| chain flag | `!(d1 & 0x80)` | 0/1 | `seg007.c:730-732` |
| target room | `((d1 & 0x60)>>5) + ((d2 & 0xE0)>>3)` | 0–23 | `seg007.c:735-739` |
| hold timer | `d2 & 0x1F` | 0–31; 31 = jammed | `seg007.c:713-715`, `seg007.c:750-751` |

Press sets timer = **5**; the button animation decrements per logic frame and stops
below 2 (≈4-frame press sequence; re-press only when < 2). The linked gate runs §9's
schedule independently. `seg007.c:742-768`, `seg007.c:783-791`. Ours: — pending A4.1.

## 11. Loose floors and chompers

| Quantity | Value | Citation |
|---|---|---|
| press→fall delay | 11 logic frames (≈0.9 s at 12 fps) | `data.h:827`, `seg007.c:825` |
| shake band | modifier 0x80–0x83, resets ≥0x84 | `seg007.c:813-829` |
| detach landing rows | {2, 65, 128, 191, 254} | `seg007.c:809` |
| crush test | same room+col, feet within 30 y-units above block | `seg007.c:1185-1193` |
| chomper cycle | 15 frames ≈ 1.25 s; bite sound on frame 2; blood flag 0x80; stops past frame 6 when kid left/dead | `data.h:860`, `seg007.c:281-306` |

## 12. Guard decision tables and HP

Fire rule: `table[skill] > prandom(255)` → probability value/256 [D]; RNG
`seg009.c:245-252`. Consumption: advance `seg002.c:864-870`, block
`seg002.c:872-885`, strike `seg002.c:887-899`.

| skill | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | citation |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| strike odds | 61 | 100 | 61 | 61 | 61 | 40 | 100 | 220 | 0 | 48 | 32 | 48 | `data.h:841` |
| re-strike odds | 0 | 0 | 0 | 5 | 5 | 175 | 16 | 8 | 0 | 255 | 255 | 150 | `data.h:842` |
| block odds | 0 | 150 | 150 | 200 | 200 | 255 | 200 | 250 | 0 | 255 | 255 | 255 | `data.h:843` |
| immediate re-block odds | 0 | 61 | 61 | 100 | 100 | 145 | 100 | 250 | 0 | 145 | 255 | 175 | `data.h:844` |
| advance odds | 255 | 200 | 200 | 200 | 255 | 255 | 200 | 0 | 0 | 255 | 100 | 100 | `data.h:845` |
| refractory frames | 16 | 16 | 16 | 16 | 8 | 8 | 8 | 8 | 0 | 8 | 0 | 0 | `data.h:846` |
| bonus HP | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | `data.h:847` |
| base HP | 4 | 3 | 3 | 3 | 3 | 4 | 5 | 4 | 4 | 5 | 5 | 5 | `data.h:835` |

(Row labels are our schema; the cited symbols in `data.h` are `strikeprob`,
`restrikeprob`, `blockprob`, `impblockprob`, `advprob`, `refractimer`,
`extrastrength`, `tbl_guard_hp` — named only as citation anchors.)

Decision context: block reacts to opponent frames 152/153/162; re-strike applies
while self in 150/161; strike skipped if opponent in 169/151 (`seg002.c:875`,
`seg002.c:891-899`). No-guard marker: tile ≥ 30 (`seg002.c:115`). Measured guard
population in shipped levels [M]: 38 guards, skills {0,1,2,3,4,5,7,9} — all within
the 12-wide tables. Ours: — pending gate 3.

## 13. Sword frame windows

| Action | Frame chain (1 frame/logic frame) | Citation |
|---|---|---|
| ready | f158 loop | `seqtbl.c:287` |
| strike | f168→f151→f152→f153→f154→f155→f156→f157→ready (8 frames; fast strike skips f168) | `seqtbl.c:331-340` |
| **kid's hit window** | **f153, f154 only** | `seg002.c:1004`, `seg002.c:1014`, `seg002.c:1036` |
| block | f169→f150 loop→ready | `seqtbl.c:351-354` |
| parry stops hits | f150 or f161 | `seg002.c:1010` |
| blocked strike | f167→f155…→ready | `seqtbl.c:342-344` |
| block→strike | f162→f152… | `seqtbl.c:347-349` |
| strike→block | f159,f160→f150 | `seqtbl.c:356-358` |
| advance / fast / retreat | dx+2 f163, dx+4 f164 / dx+6 f164 / dx−3 f160, dx−2 f157 | `seqtbl.c:314-329` |

At 10 fps: hit possible 0.4–0.5 s after input, full chain 0.8 s [D].
Ours: — pending A4.3 duels / gate 3.

## 14. RNG

| Quantity | Value | Citation |
|---|---|---|
| generator | 32-bit LCG: seed × 214013 + 2531011 (wrap), result `(seed >> 16) % (max+1)` | `seg009.c:251-252` |
| seeding | once from `time(NULL)` if uninitialised | `seg009.c:246-250` |

Ours: `scripts/pop/pop_rng.gd` **adopts this reference generator** (constants +
high-16 draw, cited above) since Q1 was answered (D5); `rand_below(n)` =
`prandom(n-1)`. Determinism gate proves seed→state reproducibility; gate 3 will
prove generator identity end-to-end.

## 15. Parity targets (plan §8 gates 2–3 rows)

Every value below is restated from §1–§14 of this file, each of which carries its
`file:line` citations; no independent numbers appear in this table.

| ID | Behavior | Reference (this file) | Ours | Status |
|---|---|---|---|---|
| P1 | Standing jump horizontal distance | §4 stream; ≈36 units at landing [D]; `seqtbl.c:381-400` | — | ⬜ |
| P2 | Running jump horizontal distance | §5 stream; ≈67 units total [D]; `seqtbl.c:402-416` | — | ⬜ |
| P3 | Fall thresholds soft/medium/death | §7 (22 / 33 / 33); `seg005.c:174-208` | — | ⬜ |
| P4 | Hang / grab frame counts | §6 (43-frame sway; grab_timer 12); `seqtbl.c:554-567`, `seg006.c:1199` | — | ⬜ |
| P5 | Spike cycle length | §8 (≈23 frames); `seg007.c:310-329` | — | ⬜ |
| P6 | Gate open/close speeds, plate timing ±1 tick | §9–§10; `seg007.c:332-364`, `seg007.c:742-791` | — | ⬜ |
| P7 | Guard duel transcript, seeded, skill 0 | §12–§14 (skill-0 odds 61/0/255); `data.h:841-847`, `seg009.c:245-252` | — | ⬜ |
| P8 | Tick model 12 fps / 10 fps | §1; `seg003.c:350-372` | — | ⬜ |

## 16. Open items

- No gameplay number above has been confirmed by *observation* yet (binary now runs;
  timer/replay-based confirmation is scheduled next session). Treat [S] values as
  source-measured, not behavior-verified.
- Level-1 cross-validation done: `--screenshot-level-extras` map vs byte extraction
  matched on start marker and guard label positions (Session 002; see review.md).
