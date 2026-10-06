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

# --- Direction change and run stop (PARITY §18) ----------------------------
const TURN_TICKS: int = 8         ## `seqtbl.c:440-449`: flip + frames 45–52, then stand
const RUN_STOP_TICKS: int = 8     ## `seqtbl.c:619-627`: frames 53,54,55,56,49,50,51,52, then stand

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
	# Reference: `seqtbl.c:970-973` — spike impale (contact, `seg005.c:216-245`).
	"impale": [
		[Op.ACTION, Action.RUN_JUMP], [Op.KNOCK_DOWN], [Op.DX, 4],
		[Op.FRAME, 177], [Op.DIE], [Op.FRAME, 177], [Op.JUMP, "impale"],
	],
}
