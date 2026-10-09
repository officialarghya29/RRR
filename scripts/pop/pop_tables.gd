class_name PopTables
extends RefCounted
## Plan A2.1 — pure reference-derived data for the pop sim. **No logic here.**
##
## Boundary rules (Q1 answer, review.md 2026-10-06): every value below is a
## measured reference fact carried with a `file:line` citation into
## `SDLPoP-1.23/src/` (study only, GPL-3 — cited, never copied as code), and
## every constant is cross-checked row-by-row against `docs/PARITY.md` by
## `tests/test_main.gd::_test_pop_tables_vs_parity()`. If a value changes
## here, the matching PARITY row must change too, and vice versa — the test
## fails otherwise (anti-drift, plan A2.1 accept).
##
## Sequences are *re-authored* in our own op schema (plan §4.4), not
## transliterated: each entry below is a readable op list whose semantics we
## implement in `pop_sim.gd` (A2.2). Reference semantics being mirrored: one
## logic tick consumes ops up to and including the next FRAME op
## (`seg006.c:569-684`); JUMP does not consume a tick by itself.

# --- Op schema (plan §4.4) -------------------------------------------------
# ACTION(a) | FRAME(i) | DX(n) | DY(n) | SET_FALL(x,y) | SOUND(id) | JUMP(seq)
# plus FLIP / KNOCK_DOWN / DIE / ROW_UP / ROW_DOWN, which our sequences need
# (reference equivalents: SEQ_FLIP, SEQ_KNOCK_DOWN, SEQ_DIE, SEQ_UP, SEQ_DOWN
# — `seg006.c:584-586`, `seg006.c:675-677`, all executed by play_seq).
enum Op { ACTION, FRAME, DX, DY, SET_FALL, SOUND, JUMP, FLIP, KNOCK_DOWN, DIE, ROW_UP, ROW_DOWN }

# --- Tile ids (own names; ids map 1:1 to reference semantics) -------------
# Reference: `types.h:113-145` (enum tiles), backticked anchors in PARITY §16.
enum Tile {
	EMPTY = 0,
	FLOOR = 1,
	SPIKES = 2,
	PILLAR = 3,
	GATE = 4,
	GATE_STUCK = 5,
	BUTTON_DROP = 6,
	DOOR_TOP_FLOOR = 7,
	PILLAR_BIG_BOTTOM = 8,
	PILLAR_BIG_TOP = 9,
	POTION = 10,
	FLOOR_LOOSE = 11,
	DOOR_TOP = 12,
	MIRROR = 13,
	FLOOR_BROKEN = 14,
	BUTTON_RAISE = 15,
	EXIT_DOOR_LEFT = 16,
	EXIT_DOOR_RIGHT = 17,
	CHOMPER = 18,
	TORCH = 19,
	WALL = 20,
	SKELETON = 21,
	SWORD = 22,
	BALCONY_LEFT = 23,
	BALCONY_RIGHT = 24,
	LATTICE_PILLAR = 25,
	LATTICE_SUPPORT = 26,
	LATTICE_SMALL = 27,
	LATTICE_LEFT = 28,
	LATTICE_RIGHT = 29,
	TORCH_DEBRIS = 30,
}

# --- Actions (own names; reference: `types.h:394-402`, PARITY §16) --------
enum Action { STAND = 0, RUN_JUMP = 1, HANG_CLIMB = 2, IN_MIDAIR = 3, IN_FREEFALL = 4, BUMPED = 5, HANG_STRAIGHT = 6, TURN = 7 }

# --- Sounds our sim plays (own names; `types.h:702-734`, PARITY §16) ------
enum Sound { MEDIUM_LAND = 16, SOFT_LAND = 17, FOOTSTEP = 23, SPIKED = 48 }

# --- Tick clock (PARITY §1; `seg003.c:350-372`, `data.h:858-859`) ---------
const TICK_HZ_TRAVERSE: int = 12  ## logic frames/s while traversing (base_speed 5 timer ticks of 60 Hz)
const TICK_HZ_SWORD: int = 10     ## logic frames/s with sword drawn (fight_speed 6)

# --- Geometry (PARITY §2; `types.h:1405-1408`, `data.h:506`, `data.h:513`) -
const TILE_W: int = 14            ## internal units per tile width
const TILE_H: int = 63            ## internal units per row height
## Standing y per floor row, index = row + 1 (row −1, 0, 1, 2, off-screen
## below); reference floors the character to `y_land[curr_row + 1]`
## (`seg005.c:124`, `seg002.c:178`).
const Y_LAND: Array[int] = [-8, 55, 118, 181, 244]
## Left-most x of every tile column, index = col + FIRST_ONSCREEN_COLUMN
## (−12 + 14·i). Carried as written in the initializer (`data.h:513`); note
## the reference stores it in `byte` (`types.h:52`), so index 0 would read
## back as 244 there — flagged for gate-2 observation, not tuned here.
const X_BUMP: Array[int] = [-12, 2, 16, 30, 44, 58, 72, 86, 100, 114, 128, 142, 156, 170, 184, 198, 212, 226, 240, 254]
const FIRST_ONSCREEN_COLUMN: int = 5  ## `x_bump` index of on-screen column 0 (`types.h:1412`)

# --- Fall and landing thresholds (PARITY §7; `seg005.c:174-208`,
#     `types.h:1413-1416`) --------------------------------------------------
const FALL_ACCEL: int = 3         ## fall speed +3 per logic frame
const FALL_SPEED_MAX: int = 33    ## fall speed cap
const SOFT_LAND_MAX: int = 22     ## impact speed < 22 → crouch, no damage
const MEDIUM_LAND_MIN: int = 22   ## 22 ≤ speed → −1 HP …
const MEDIUM_LAND_MAX: int = 33   ## … while speed < 33
const DEATH_SPEED: int = 33       ## speed ≥ 33 → crushed

# --- Level and contact rules (PARITY §2/§8/§16) ---------------------------
## Tiles that are NOT standable floor (empty, big-pillar top, doortop, wall,
## lattice support/small/left/right) — reference tile_is_floor()
## (`seg006.c:933-947`).
const NON_FLOOR_TILES: Array[int] = [0, 9, 12, 20, 26, 27, 28, 29]
## Kid starting HP: `hitp_beg_lev = custom->start_hitp // 3`
## (`seg003.c:43`, `data.h:752`).
const KID_HP_START: int = 3
## Spike extends through modifier states 1–4 before holding (harm class 2,
## `seg007.c:1174`); PARITY §8.
const SPIKE_EXTEND_MAX: int = 4

# --- Gates, plates and the level-exit door (PARITY §9/§10; plan A4.1) ------
## The reference animates a gate through a tile *modifier* and a small trob
## "type" (anim_type): 0 = closing, 1 = opening, 2 = permanent open,
## 3..8 = fast closing (`seg007.c:336-403`). The values below are the
## reference's own tables, cited per line.
const GATE_CLOSED: int = 0            ## modifier 0 = closed (`seg007.c:336-403`)
const GATE_OPEN_THRESHOLD: int = 188  ## modifier ≥ 188 counts as open (`seg007.c:378-386`)
const GATE_PARKED: int = 238          ## snap value kept open after a regular open (`seg007.c:381`)
const GATE_PERMANENT: int = 0xFF      ## permanent open (`seg007.c:390`)
## Closing / opening / permanent modifier delta per logic frame
## (`data:27C0`, `seg007.c:334`, `seg007.c:364`).
const DOOR_DELTA: Array[int] = [-1, 4, 4]
## Fast-close speeds by anim_type 3..8: 20,40,60,80,100,120 (`seg007.c:331`).
const GATE_CLOSE_SPEEDS: Array[int] = [0, 0, 0, 20, 40, 60, 80, 100, 120]
## Level-door fast-close speeds; the trailing 0 mirrors the 5-entry source
## array (`seg007.c:411`).
const LEVELDOOR_CLOSE_SPEEDS: Array[int] = [0, 5, 17, 99, 0]
const LEVELDOOR_START: int = 43       ## a level door starts fully open (`seg007.c:795-798`)
const LEVELDOOR_OPEN_AT: int = 43     ## opening stops once the modifier reaches 43 (`seg007.c:424-431`)
## Plate / doorlink timer: a press sets 5, the button animation decrements per
## logic frame and stops below 2, so it only re-presses when the timer is < 2
## (`seg007.c:742-751`, `seg007.c:783-791`).
const PLATE_HOLD_TIMER: int = 5
const PLATE_REPRESS_BELOW: int = 2
const PLATE_JAMMED: int = 0x1F        ## 31 = jammed, cannot fire (`seg007.c:713-715`)

# --- Spike cycle (PARITY §8; `animate_spike`, `seg007.c:310-329`) ----------
const SPIKE_HOLD_START: int = 0x8F    ## modifier set on the 5th extend frame (`seg007.c:320-322`)
const SPIKE_HOLD_END: int = 0x81      ## last hold state; next tick falls to 0x80 → 6 (`seg007.c:313-317`)
const SPIKE_RETRACT_START: int = 6    ## retract frames 6 → 7 → 8 → (9 → 0, stop) (`seg007.c:324-327`)
const SPIKE_DISABLED: int = 0xFF      ## permanent, set on a kill (`seg005.c:220-222`)
const SPIKE_CYCLE_TICKS: int = 23     ## 5 extend + 15 hold + 3 retract, ≈1.9 s [D] (PARITY §8)

# --- Loose floors and chompers (PARITY §11; `seg007.c:809-829`, `281-306`) --
const LOOSE_FALL_DELAY: int = 11      ## press→fall delay (`data.h:827`, `seg007.c:825`)
const LOOSE_SHAKE_START: int = 0x80   ## shake band 0x80–0x83 (`seg007.c:813-829`)
const LOOSE_SHAKE_RESET: int = 0x84   ## ≥ 0x84 resets the modifier to 0 (`seg007.c:813-829`)
## `y_loose_land` — the y a detached block rests at, per starting row
## (`seg007.c:809`); equals Y_LAND + 10.
const LOOSE_LAND_ROWS: Array[int] = [2, 65, 128, 191, 254]
const CRUSH_DEPTH: int = 30           ## feet within 30 y-units above the block (`seg007.c:1185-1195`)
const CHOMPER_FRAMES: int = 15        ## cycle length (`data.h:860`)
const CHOMPER_BITE_FRAME: int = 2     ## bite sound on frame 2 (`seg007.c:281-306`)
const CHOMPER_STOP_FRAME: int = 6     ## stops past frame 6 when the kid left/died (`seg007.c:286-300`)
const CHOMPER_BLOOD: int = 0x80       ## blood flag in the modifier (`seg007.c:283`)

# --- Direction change and run stop (PARITY §18) ----------------------------
const TURN_TICKS: int = 8             ## `seqtbl.c:440-449`: flip + frames 45–52, then stand
const RUN_STOP_TICKS: int = 8         ## `seqtbl.c:619-627`: frames 53,54,55,56,49,50,51,52, then stand

# --- Hang, climb, crouch and safe-step (PARITY §6; plan A2.3) --------------
## Hang sway auto-drop: 43 logic ticks (f91 + 42-frame hang1 cycle, one FRAME
## op per tick), `seqtbl.c:554-567`.
const HANG_TICKS: int = 43
## Mid-air grab timeout state (`seg006.c:1201`).
const GRAB_TIMER: int = 12
## Climb-fail opening crouch tick budget: frames 135,136,137,137,138,138×4,
## 137,136,135 = 11 ticks, `seqtbl.c:575-579`.
const CLIMB_FAIL_TICKS: int = 11
## Standing-crouch loop budget: 29 crouch ticks before the stand-up chain,
## `seqtbl.c:946-950` (rotation stopped by control logic, `seg005.c:362-364`).
const CROUCH_TICKS: int = 29
## Climb-fail pull-back: dx −7 inside the climbfail sequence, co-timed with
## hangdrop's opening f81 (`seqtbl.c:578-579`).
const CLIMB_FAIL_ENTRY_DX: int = -7
## Hang-fall release opening dy: +6 (`seqtbl.c:609-613`).
const RELEASE_FALL_DY: int = 6

# --- Kid frame rows --------------------------------------------------------
## Index = frame id (reference array index, `seg006.c:127-369`). `dx`/`dy`
## are per-frame foot/sprite offsets, *not* motion: motion comes from the
## sequence DX/DY ops, while `dx − weight` gives the foot x used for column
## and edge tests (`dx_weight`, `seg006.c:547-550`). Flags are decoded into
## separate fields per our schema (reference bit masks: `types.h:366-370`).
## Carried frames: 1–56 (run/stand/jumps/turn/stop), 102–119 (fall/land),
## 177 (spiked), 185 (dead) — exactly the frames our sequences reference.
## Full table in PARITY §17; rows below must match it one for one.
const KID_FRAME: Dictionary = {
	1: { "dx": 1, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	2: { "dx": 1, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	3: { "dx": 3, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	4: { "dx": 4, "dy": 0, "weight": 8, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	5: { "dx": 0, "dy": 0, "weight": 6, "thin": 1, "needs_floor": 1, "even_odd": 1 },
	6: { "dx": 0, "dy": 0, "weight": 9, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	7: { "dx": 0, "dy": 0, "weight": 10, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	8: { "dx": 0, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	9: { "dx": 0, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	10: { "dx": 0, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	11: { "dx": 0, "dy": 0, "weight": 11, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	12: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	13: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	14: { "dx": 0, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	15: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	16: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	17: { "dx": 0, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	18: { "dx": 0, "dy": 0, "weight": 6, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	19: { "dx": 0, "dy": 0, "weight": 8, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	20: { "dx": 0, "dy": 0, "weight": 9, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	21: { "dx": 0, "dy": 0, "weight": 11, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	22: { "dx": 0, "dy": 0, "weight": 11, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	23: { "dx": 0, "dy": 0, "weight": 17, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	24: { "dx": 0, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	25: { "dx": 0, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	26: { "dx": 0, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	27: { "dx": 0, "dy": 0, "weight": 6, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	28: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	29: { "dx": 0, "dy": 0, "weight": 8, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	30: { "dx": 0, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	31: { "dx": 0, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	32: { "dx": 0, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	33: { "dx": 0, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	34: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	35: { "dx": 0, "dy": 0, "weight": 8, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	36: { "dx": 0, "dy": 0, "weight": 14, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	37: { "dx": 0, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	38: { "dx": 0, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	39: { "dx": 0, "dy": 0, "weight": 14, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	40: { "dx": 0, "dy": 0, "weight": 11, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	41: { "dx": 0, "dy": 0, "weight": 11, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	42: { "dx": 0, "dy": 0, "weight": 10, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	43: { "dx": 0, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	44: { "dx": 0, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	45: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	46: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	47: { "dx": 0, "dy": 0, "weight": 5, "thin": 1, "needs_floor": 0, "even_odd": 1 },
	48: { "dx": 0, "dy": 0, "weight": 4, "thin": 1, "needs_floor": 0, "even_odd": 1 },
	49: { "dx": 0, "dy": 0, "weight": 6, "thin": 1, "needs_floor": 1, "even_odd": 0 },
	50: { "dx": 4, "dy": 0, "weight": 7, "thin": 1, "needs_floor": 1, "even_odd": 0 },
	51: { "dx": 3, "dy": 0, "weight": 6, "thin": 1, "needs_floor": 1, "even_odd": 0 },
	52: { "dx": 1, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	53: { "dx": 0, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	54: { "dx": 0, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	55: { "dx": 0, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	56: { "dx": 0, "dy": 0, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	102: { "dx": 0, "dy": 0, "weight": 6, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	103: { "dx": 0, "dy": 0, "weight": 6, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	104: { "dx": 0, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	105: { "dx": 0, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	106: { "dx": 0, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	107: { "dx": 0, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	108: { "dx": 0, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	109: { "dx": 0, "dy": 0, "weight": 6, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	110: { "dx": 0, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	111: { "dx": 0, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	112: { "dx": 0, "dy": 0, "weight": 9, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	113: { "dx": 0, "dy": 0, "weight": 8, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	114: { "dx": 0, "dy": 0, "weight": 9, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	115: { "dx": 0, "dy": 0, "weight": 9, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	116: { "dx": 0, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	117: { "dx": 2, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	118: { "dx": 2, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	119: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	67: { "dx": -2, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	68: { "dx": -2, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	69: { "dx": -1, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	70: { "dx": -2, "dy": 0, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	71: { "dx": -2, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	72: { "dx": -2, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	73: { "dx": -2, "dy": 0, "weight": 1, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	74: { "dx": -1, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	75: { "dx": -1, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	76: { "dx": 2, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	77: { "dx": 2, "dy": 0, "weight": 7, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	78: { "dx": 2, "dy": -3, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	79: { "dx": 2, "dy": -10, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	80: { "dx": 2, "dy": -11, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	81: { "dx": 3, "dy": -2, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	82: { "dx": 3, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	83: { "dx": 3, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	84: { "dx": 3, "dy": 0, "weight": 3, "thin": 1, "needs_floor": 1, "even_odd": 0 },
	85: { "dx": 4, "dy": 0, "weight": 3, "thin": 1, "needs_floor": 1, "even_odd": 1 },
	87: { "dx": 7, "dy": -14, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	88: { "dx": 7, "dy": -12, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	89: { "dx": 4, "dy": -12, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	90: { "dx": 3, "dy": -10, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	91: { "dx": 2, "dy": -10, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	92: { "dx": 1, "dy": -10, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	93: { "dx": 0, "dy": -11, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	94: { "dx": -1, "dy": -12, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	95: { "dx": -1, "dy": -14, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	96: { "dx": -1, "dy": -14, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	97: { "dx": -1, "dy": -15, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	98: { "dx": -1, "dy": -15, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	99: { "dx": 0, "dy": -15, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	121: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	122: { "dx": 0, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	123: { "dx": 0, "dy": 0, "weight": 5, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	124: { "dx": 0, "dy": 0, "weight": 8, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	125: { "dx": 0, "dy": 0, "weight": 12, "thin": 1, "needs_floor": 1, "even_odd": 0 },
	126: { "dx": 0, "dy": 0, "weight": 15, "thin": 1, "needs_floor": 1, "even_odd": 1 },
	127: { "dx": 0, "dy": 0, "weight": 3, "thin": 1, "needs_floor": 0, "even_odd": 1 },
	128: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	129: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	130: { "dx": 0, "dy": 0, "weight": 3, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	131: { "dx": 0, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	132: { "dx": 0, "dy": 0, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	135: { "dx": 0, "dy": -12, "weight": 1, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	136: { "dx": 0, "dy": -21, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 0 },
	137: { "dx": 1, "dy": -26, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	138: { "dx": 4, "dy": -32, "weight": 0, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	139: { "dx": 6, "dy": -36, "weight": 1, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	140: { "dx": 7, "dy": -41, "weight": 2, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	141: { "dx": 2, "dy": 17, "weight": 2, "thin": 0, "needs_floor": 1, "even_odd": 0 },
	142: { "dx": 4, "dy": 9, "weight": 4, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	143: { "dx": 4, "dy": 5, "weight": 9, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	144: { "dx": 4, "dy": 4, "weight": 8, "thin": 0, "needs_floor": 1, "even_odd": 1 },
	145: { "dx": 5, "dy": 0, "weight": 9, "thin": 1, "needs_floor": 1, "even_odd": 0 },
	146: { "dx": 5, "dy": 0, "weight": 9, "thin": 1, "needs_floor": 1, "even_odd": 1 },
	147: { "dx": 5, "dy": 0, "weight": 8, "thin": 1, "needs_floor": 1, "even_odd": 1 },
	148: { "dx": 5, "dy": 0, "weight": 9, "thin": 1, "needs_floor": 1, "even_odd": 0 },
	149: { "dx": 5, "dy": 0, "weight": 9, "thin": 1, "needs_floor": 1, "even_odd": 0 },
	177: { "dx": 0, "dy": 3, "weight": 10, "thin": 0, "needs_floor": 0, "even_odd": 1 },
	185: { "dx": 4, "dy": 7, "weight": 9, "thin": 0, "needs_floor": 1, "even_odd": 0 },
}

# --- Sequences (re-authored in our op schema; plan §4.4) -------------------
# One op list per animation. Ticks are delimited by FRAME ops; SOUND and
# KNOCK_DOWN fire in the tick of the frame that follows them. Each entry
# cites the reference block it was derived from. Not transliterated: loop
# structure is expressed with explicit named JUMP targets, the feather-fall
# conditional branch of stepfall (`seqtbl.c:492`) is intentionally omitted
# until potions exist (A4.5), and op order is our own readable layout.
const SEQUENCES: Dictionary = {
	# Reference: `seqtbl.c:261-263`
	"stand": [
		[Op.ACTION, Action.STAND], [Op.FRAME, 15], [Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:246-251` (startup f1–f6, then enters run_cycle)
	"startrun": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 1], [Op.FRAME, 2], [Op.FRAME, 3], [Op.FRAME, 4],
		[Op.DX, 8], [Op.FRAME, 5],
		[Op.DX, 3], [Op.FRAME, 6],
		[Op.DX, 3], [Op.JUMP, "run_cycle"],
	],
	# Reference: `seqtbl.c:251-259` (runcyc1 at 251, runcyc7 at 257);
	# steady cycle 8 frames / 26 units — PARITY §3.
	"run_cycle": [
		[Op.FRAME, 7],
		[Op.DX, 5], [Op.FRAME, 8],
		[Op.DX, 1], [Op.SOUND, Sound.FOOTSTEP], [Op.FRAME, 9],
		[Op.DX, 2], [Op.FRAME, 10],
		[Op.DX, 4], [Op.FRAME, 11],
		[Op.DX, 5], [Op.FRAME, 12],
		[Op.DX, 2], [Op.SOUND, Sound.FOOTSTEP], [Op.FRAME, 13],
		[Op.DX, 3], [Op.FRAME, 14],
		[Op.DX, 4], [Op.JUMP, "run_cycle"],
	],
	# Reference: `seqtbl.c:440-449` — flip on tick 1, frames 45–52 → stand.
	"turn": [
		[Op.ACTION, Action.TURN], [Op.FLIP],
		[Op.DX, 6], [Op.FRAME, 45],
		[Op.DX, 1], [Op.FRAME, 46],
		[Op.DX, 2], [Op.FRAME, 47],
		[Op.DX, -1], [Op.FRAME, 48],
		[Op.DX, 1], [Op.FRAME, 49],
		[Op.DX, -2], [Op.FRAME, 50],
		[Op.FRAME, 51],
		[Op.FRAME, 52],
		[Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:619-627` — frames 53,54,55,56,49,50,51,52 → stand.
	"run_stop": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 53],
		[Op.DX, 2], [Op.SOUND, Sound.FOOTSTEP], [Op.FRAME, 54],
		[Op.DX, 7], [Op.FRAME, 55],
		[Op.SOUND, Sound.FOOTSTEP], [Op.FRAME, 56],
		[Op.DX, 2], [Op.FRAME, 49],
		[Op.DX, -2], [Op.FRAME, 50],
		[Op.FRAME, 51], [Op.FRAME, 52],
		[Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:381-400` (sjland at 391) — PARITY §4 stream.
	"stand_jump": [
		[Op.ACTION, Action.RUN_JUMP],
		[Op.FRAME, 16], [Op.FRAME, 17],
		[Op.DX, 2], [Op.FRAME, 18],
		[Op.DX, 2], [Op.FRAME, 19],
		[Op.DX, 2], [Op.FRAME, 20],
		[Op.DX, 2], [Op.FRAME, 21],
		[Op.DX, 2], [Op.FRAME, 22],
		[Op.DX, 7], [Op.FRAME, 23],
		[Op.DX, 9], [Op.FRAME, 24],
		[Op.DX, 5], [Op.DY, -6], [Op.FRAME, 25],
		[Op.DX, 1], [Op.DY, 6], [Op.FRAME, 26],
		[Op.DX, 4], [Op.KNOCK_DOWN], [Op.SOUND, Sound.FOOTSTEP], [Op.FRAME, 27],
		[Op.DX, -3], [Op.FRAME, 28],
		[Op.DX, 5], [Op.FRAME, 29],
		[Op.SOUND, Sound.FOOTSTEP], [Op.FRAME, 30],
		[Op.FRAME, 31], [Op.FRAME, 32], [Op.FRAME, 33],
		[Op.DX, 1], [Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:402-414` (rjlandrun at 413) — PARITY §5 stream;
	# landing re-enters the run cycle.
	"run_jump": [
		[Op.ACTION, Action.RUN_JUMP], [Op.SOUND, Sound.FOOTSTEP], [Op.FRAME, 34],
		[Op.DX, 5], [Op.FRAME, 35],
		[Op.DX, 6], [Op.FRAME, 36],
		[Op.DX, 3], [Op.FRAME, 37],
		[Op.DX, 5], [Op.SOUND, Sound.FOOTSTEP], [Op.FRAME, 38],
		[Op.DX, 7], [Op.FRAME, 39],
		[Op.DX, 12], [Op.DY, -3], [Op.FRAME, 40],
		[Op.DX, 8], [Op.DY, -9], [Op.FRAME, 41],
		[Op.DX, 8], [Op.DY, -2], [Op.FRAME, 42],
		[Op.DX, 4], [Op.DY, 11], [Op.FRAME, 43],
		[Op.DX, 4], [Op.DY, 3], [Op.FRAME, 44],
		[Op.DX, 5], [Op.KNOCK_DOWN], [Op.SOUND, Sound.FOOTSTEP], [Op.JUMP, "run_cycle"],
	],
	# Reference: `seqtbl.c:502-503` — entry used when the run cycle breaks at
	# frame 13 (reference `start_fall`, `seg006.c:1091-1093`).
	"step_fall_2": [
		[Op.DX, 1], [Op.JUMP, "step_fall"],
	],
	# Reference: `seqtbl.c:491-497` — walking off an edge (fall1 at 493).
	"step_fall": [
		[Op.ACTION, Action.IN_MIDAIR],
		[Op.DX, 1], [Op.DY, 3], [Op.FRAME, 102],
		[Op.DX, 2], [Op.DY, 6], [Op.FRAME, 103],
		[Op.DX, -1], [Op.DY, 9], [Op.FRAME, 104],
		[Op.DY, 12], [Op.FRAME, 105],
		[Op.DX, -2], [Op.SET_FALL, 1, 15], [Op.JUMP, "free_fall"],
	],
	# Reference: `seqtbl.c:512-517` — falling after a standing jump.
	"jump_fall": [
		[Op.ACTION, Action.IN_MIDAIR],
		[Op.DX, 1], [Op.DY, 3], [Op.FRAME, 102],
		[Op.DX, 2], [Op.DY, 6], [Op.FRAME, 103],
		[Op.DX, 1], [Op.DY, 9], [Op.FRAME, 104],
		[Op.DX, 2], [Op.DY, 12], [Op.FRAME, 105],
		[Op.SET_FALL, 2, 15], [Op.JUMP, "free_fall"],
	],
	# Reference: `seqtbl.c:519-524` — falling after a running jump.
	"run_jump_fall": [
		[Op.ACTION, Action.IN_MIDAIR],
		[Op.DX, 1], [Op.DY, 3], [Op.FRAME, 102],
		[Op.DX, 3], [Op.DY, 6], [Op.FRAME, 103],
		[Op.DX, 2], [Op.DY, 9], [Op.FRAME, 104],
		[Op.DX, 3], [Op.DY, 12], [Op.FRAME, 105],
		[Op.SET_FALL, 3, 15], [Op.JUMP, "free_fall"],
	],
	# Reference: `seqtbl.c:615-617` — the falling loop; impact resolution is
	# in logic (seg005.c:174-208), not here.
	"free_fall": [
		[Op.ACTION, Action.IN_FREEFALL], [Op.FRAME, 106], [Op.JUMP, "free_fall"],
	],
	# Reference: `seqtbl.c:916-920` — soft land (impact < 22): knock down,
	# two recovery frames, then crouch loop.
	"soft_land": [
		[Op.ACTION, Action.BUMPED], [Op.KNOCK_DOWN],
		[Op.DX, 1], [Op.FRAME, 107],
		[Op.DX, 2], [Op.FRAME, 108],
		[Op.ACTION, Action.RUN_JUMP], [Op.JUMP, "soft_land_crouch"],
	],
	"soft_land_crouch": [  # reference: `seqtbl.c:919-920`
		[Op.FRAME, 109], [Op.JUMP, "soft_land_crouch"],
	],
	# Reference: `seqtbl.c:934-953` — medium land (22 ≤ impact < 33):
	# knock down, 29 crouch ticks, then the stand-up chain → stand.
	"med_land": [
		[Op.ACTION, Action.BUMPED], [Op.KNOCK_DOWN], [Op.DY, -2],
		[Op.DX, 1], [Op.DX, 2], [Op.FRAME, 108],
		[Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109],
		[Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109],
		[Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109],
		[Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109],
		[Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109],
		[Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109], [Op.FRAME, 109],
		[Op.DX, 1], [Op.FRAME, 110],
		[Op.FRAME, 110], [Op.FRAME, 110], [Op.FRAME, 111],
		[Op.DX, 2], [Op.FRAME, 112],
		[Op.FRAME, 113],
		[Op.DX, 1], [Op.DY, 1], [Op.FRAME, 114],
		[Op.DY, 1], [Op.FRAME, 115],
		[Op.FRAME, 116],
		[Op.DX, -4], [Op.FRAME, 117],
		[Op.FRAME, 118], [Op.FRAME, 119],
		[Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:955-958` — hard land (impact ≥ 33): death.
	"hard_land": [
		[Op.ACTION, Action.BUMPED], [Op.KNOCK_DOWN], [Op.DY, -2], [Op.DX, 3],
		[Op.FRAME, 185], [Op.DIE], [Op.FRAME, 185], [Op.JUMP, "hard_land"],
	],
	# --- A2.3: hang, climb, crouch, safe-step --------------------------------
	# Reference: `seqtbl.c:686-688` (fallhang = seq 15, the mid-air grab
	# landing): one frame, then the hang sway.
	"grab_hang": [
		[Op.ACTION, Action.HANG_CLIMB], [Op.FRAME, 80], [Op.JUMP, "hang"],
	],
	# Reference: `seqtbl.c:552-553` (hang entry) — f91, then the 42-frame
	# hang1 sway below; the auto-drop therefore lands on tick 43.
	"hang": [
		[Op.ACTION, Action.HANG_CLIMB], [Op.FRAME, 91], [Op.JUMP, "hang_cycle"],
	],
	# Reference: `seqtbl.c:554-567` (hang1). climbdown re-enters here
	# (`seqtbl.c:588`), so the cycle — including its auto-drop — is its own
	# sequence.
	"hang_cycle": [
		[Op.FRAME, 90], [Op.FRAME, 89], [Op.FRAME, 88],
		[Op.FRAME, 87], [Op.FRAME, 87], [Op.FRAME, 87],
		[Op.FRAME, 88], [Op.FRAME, 89], [Op.FRAME, 90], [Op.FRAME, 91],
		[Op.FRAME, 92], [Op.FRAME, 93], [Op.FRAME, 94], [Op.FRAME, 95],
		[Op.FRAME, 96], [Op.FRAME, 97], [Op.FRAME, 98], [Op.FRAME, 99],
		[Op.FRAME, 97], [Op.FRAME, 96], [Op.FRAME, 95], [Op.FRAME, 94],
		[Op.FRAME, 93], [Op.FRAME, 92], [Op.FRAME, 91], [Op.FRAME, 90],
		[Op.FRAME, 89], [Op.FRAME, 88], [Op.FRAME, 87], [Op.FRAME, 88],
		[Op.FRAME, 89], [Op.FRAME, 90], [Op.FRAME, 91], [Op.FRAME, 92],
		[Op.FRAME, 93], [Op.FRAME, 94], [Op.FRAME, 95], [Op.FRAME, 96],
		[Op.FRAME, 95], [Op.FRAME, 94], [Op.FRAME, 93], [Op.FRAME, 92],
		[Op.JUMP, "hang_drop"],
	],
	# Reference: `seqtbl.c:568-573` (hangstraight) — Shift held against a
	# wall; hangs flat without the sway cycle and never auto-drops.
	"hang_straight": [
		[Op.ACTION, Action.HANG_STRAIGHT], [Op.FRAME, 92],
		[Op.FRAME, 93], [Op.FRAME, 93], [Op.FRAME, 92], [Op.FRAME, 92],
		[Op.FRAME, 91], [Op.JUMP, "hang_straight"],
	],
	# Reference: `seqtbl.c:590-600` (climbup) — 14 climbing frames, then the
	# ROW_UP carries the kid onto the ledge (dx +5, dy −63, row −1),
	# f149, and the stand-up chain f118/f119 → stand.
	"climb_up": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 135],
		[Op.FRAME, 136], [Op.FRAME, 137], [Op.FRAME, 138],
		[Op.FRAME, 139], [Op.FRAME, 140],
		[Op.DX, 5], [Op.DY, -63], [Op.ROW_UP], [Op.FRAME, 141],
		[Op.FRAME, 142], [Op.FRAME, 143], [Op.FRAME, 144], [Op.FRAME, 145],
		[Op.FRAME, 146], [Op.FRAME, 147], [Op.FRAME, 148],
		[Op.ACTION, Action.BUMPED],
		[Op.FRAME, 149],
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 118], [Op.FRAME, 119],
		[Op.DX, 1], [Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:581-588` (climbdown) — descend one row and re-enter
	# the hang sway (jmp hang1); entry dx −5 is applied by the control logic.
	"climb_down": [
		[Op.FRAME, 148],
		[Op.FRAME, 145], [Op.FRAME, 144], [Op.FRAME, 143], [Op.FRAME, 142],
		[Op.FRAME, 141],
		[Op.DX, -5], [Op.DY, 63], [Op.ROW_DOWN],
		[Op.ACTION, Action.IN_MIDAIR],   # act(actions_3_in_midair) co-timed with f140
		[Op.FRAME, 140],
		[Op.FRAME, 138], [Op.FRAME, 136],
		[Op.FRAME, 91], [Op.ACTION, Action.HANG_CLIMB], [Op.JUMP, "hang_cycle"],
	],
	# Reference: `seqtbl.c:575-579` (climbfail) — 11 crouched ticks (f135…f135),
	# then dx −7 and jmp(hangdrop) in the same tick: hangdrop's opening f81
	# plays immediately on tick 12, exactly as the reference streams it.
	# Carried for shape parity only: the reference never routes to this label
	# (nothing jumps to climbfail; can_climb_up always climbs, `seg005.c:812-830`).
	"climb_fail": [
		[Op.FRAME, 135],
		[Op.FRAME, 136], [Op.FRAME, 137], [Op.FRAME, 137],
		[Op.FRAME, 138], [Op.FRAME, 138], [Op.FRAME, 138], [Op.FRAME, 138],
		[Op.FRAME, 137], [Op.FRAME, 136],
		[Op.DX, -7], [Op.JUMP, "hang_drop"],
	],
	# Reference: `seqtbl.c:601-607` (hangdrop) — drop from the ledge and
	# land on the feet (5 frames + dx +3).
	"hang_drop": [
		[Op.FRAME, 81], [Op.FRAME, 82],
		[Op.ACTION, Action.BUMPED], [Op.FRAME, 83],
		[Op.ACTION, Action.RUN_JUMP], [Op.KNOCK_DOWN],
		[Op.FRAME, 84], [Op.FRAME, 85],
		[Op.DX, 3], [Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:628-652` (jumpup / highjump) — Shift+Up from
	# stand: straight vertical jump. Ceiling vs no-ceiling is unmodeled
	# (A2.3), so both variants play the shared 67→79 arc into hangdrop.
	"jump_up": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 67],
		[Op.FRAME, 68], [Op.FRAME, 69], [Op.FRAME, 70], [Op.FRAME, 71],
		[Op.FRAME, 72], [Op.FRAME, 73], [Op.FRAME, 74], [Op.FRAME, 75],
		[Op.FRAME, 76], [Op.FRAME, 77], [Op.FRAME, 78], [Op.FRAME, 79],
		[Op.JUMP, "hang_drop"],
	],
	# Our alias for the A2.3 up-from-stand branch (kept name-distinct from
	# the reference's jumpup to make the control-layer mapping visible).
	"hang_jump_up": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 67],
		[Op.FRAME, 68], [Op.FRAME, 69], [Op.FRAME, 70], [Op.FRAME, 71],
		[Op.FRAME, 72], [Op.FRAME, 73], [Op.FRAME, 74], [Op.FRAME, 75],
		[Op.FRAME, 76], [Op.FRAME, 77], [Op.FRAME, 78], [Op.FRAME, 79],
		[Op.JUMP, "hang_drop"],
	],
	# Reference: `seqtbl.c:674-685` (jumpbackhang) — jump up and grab with
	# the hands reaching the ledge: 70-77 straight, dx −1 at 77, then the
	# HANG_CLIMB frames 78-80 into the hang sway.
	"jump_grab_up": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 67],
		[Op.FRAME, 68], [Op.FRAME, 69], [Op.FRAME, 70], [Op.FRAME, 71],
		[Op.FRAME, 72], [Op.FRAME, 73], [Op.FRAME, 74], [Op.FRAME, 75],
		[Op.FRAME, 76], [Op.DX, -1], [Op.FRAME, 77],
		[Op.ACTION, Action.HANG_CLIMB], [Op.DX, -2], [Op.FRAME, 78],
		[Op.DX, -1], [Op.FRAME, 79],
		[Op.DX, -1], [Op.FRAME, 80],
		[Op.JUMP, "hang"],
	],
	# Reference: `seqtbl.c:608-612` (hangfall) — releasing the ledge into a
	# fall (hand momentum then free fall).
	"release_fall": [
		[Op.ACTION, Action.IN_MIDAIR], [Op.FRAME, 81],
		[Op.DY, 6], [Op.FRAME, 81],
		[Op.DY, 9], [Op.FRAME, 81],
		[Op.DY, 12], [Op.DX, 2], [Op.SET_FALL, 0, 12], [Op.JUMP, "free_fall"],
	],
	# Reference: seq_50_crouch → `seqtbl.c:857-861` (stoop) — the sequence's
	# own stoop head carries the dx; crouch() (`seg005.c:527-530`) adds none.
	"crouch": [
		[Op.ACTION, Action.RUN_JUMP], [Op.DX, 1], [Op.FRAME, 107],
		[Op.DX, 2], [Op.FRAME, 108], [Op.JUMP, "crouch_cycle"],
	],
	"crouch_cycle": [
		[Op.FRAME, 109], [Op.JUMP, "crouch_cycle"],
	],
	# Reference: `seqtbl.c:915-927` (standup) — up from crouch: f110–f119
	# → stand. Kept name-distinct from med_land's inline chain on purpose.
	"stand_up": [
		[Op.ACTION, Action.BUMPED], [Op.DX, 1], [Op.FRAME, 110],
		[Op.FRAME, 111],
		[Op.DX, 2], [Op.FRAME, 112], [Op.FRAME, 113],
		[Op.DX, 1], [Op.FRAME, 114], [Op.FRAME, 115], [Op.FRAME, 116],
		[Op.DX, -4], [Op.FRAME, 117], [Op.FRAME, 118], [Op.FRAME, 119],
		[Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:735-912` (step14 down to step1) — the safe-step
	# family. Steps 12–14 prepend extra −1 dx pairs before f127; step9 jumps
	# into step10a (`seqtbl.c:783-792`); sizes 2–8 and 11 are standalone
	# labels sharing the f121–f126 skeleton with per-size dx tails and
	# rejoin points, which our flat op lists mirror exactly. dx totals equal
	# the sequence's name (1..14 units).
	# Reference `seqtbl.c:765-774` (step11, the plain step over floor): the
	# shared skeleton with its own −1 tail through f127 (not the step10a body).
	"safe_step_11": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 3], [Op.FRAME, 124],
		[Op.DX, 4], [Op.FRAME, 125],
		[Op.DX, 3], [Op.FRAME, 126],
		[Op.DX, -1], [Op.FRAME, 127],
		[Op.FRAME, 128], [Op.FRAME, 129], [Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_10": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 3], [Op.FRAME, 124],
		[Op.DX, 4], [Op.FRAME, 125],
		[Op.DX, 3], [Op.FRAME, 126],
		[Op.DX, -2], [Op.FRAME, 128],
		[Op.FRAME, 129], [Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_9": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.FRAME, 122], [Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 3], [Op.FRAME, 124],
		[Op.DX, 4], [Op.FRAME, 125],
		[Op.DX, 3], [Op.FRAME, 126],
		[Op.DX, -2], [Op.FRAME, 128],
		[Op.FRAME, 129], [Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_8": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 3], [Op.FRAME, 124],
		[Op.DX, 4], [Op.FRAME, 125],
		[Op.DX, -1], [Op.FRAME, 127],
		[Op.FRAME, 128], [Op.FRAME, 129], [Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_14": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 3], [Op.FRAME, 124],
		[Op.DX, 4], [Op.FRAME, 125],
		[Op.DX, 3], [Op.FRAME, 126],
		[Op.DX, -1], [Op.DX, 3], [Op.FRAME, 127],
		[Op.FRAME, 128], [Op.FRAME, 129], [Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_13": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 3], [Op.FRAME, 124],
		[Op.DX, 4], [Op.FRAME, 125],
		[Op.DX, 3], [Op.FRAME, 126],
		[Op.DX, -1], [Op.DX, 2], [Op.FRAME, 127],
		[Op.FRAME, 128], [Op.FRAME, 129], [Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_12": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 3], [Op.FRAME, 124],
		[Op.DX, 4], [Op.FRAME, 125],
		[Op.DX, 3], [Op.FRAME, 126],
		[Op.DX, -1], [Op.DX, 1], [Op.FRAME, 127],
		[Op.FRAME, 128], [Op.FRAME, 129], [Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_7": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 3], [Op.FRAME, 124],
		[Op.DX, 2], [Op.FRAME, 129],
		[Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_6": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 2], [Op.FRAME, 124],
		[Op.DX, 2], [Op.FRAME, 129],
		[Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_5": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 2], [Op.FRAME, 124],
		[Op.DX, 1], [Op.FRAME, 129],
		[Op.FRAME, 130], [Op.FRAME, 131], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_4": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 2], [Op.FRAME, 131],
		[Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_3": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 123],
		[Op.DX, 1], [Op.FRAME, 131],
		[Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_2": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 122],
		[Op.DX, 1], [Op.FRAME, 132],
		[Op.JUMP, "stand"],
	],
	"safe_step_1": [
		[Op.ACTION, Action.RUN_JUMP], [Op.FRAME, 121],
		[Op.DX, 1], [Op.FRAME, 132], [Op.JUMP, "stand"],
	],
	# Reference: `seqtbl.c:970-973` — spike impale (contact, `seg005.c:216-245`).
	"impale": [
		[Op.ACTION, Action.RUN_JUMP], [Op.KNOCK_DOWN], [Op.DX, 4],
		[Op.FRAME, 177], [Op.DIE], [Op.FRAME, 177], [Op.JUMP, "impale"],
	],
}
