class_name PopSim
extends RefCounted
## Pure integer step function for the Pop sim core (plan A2.2, skeleton).
##
## Scope of the skeleton: stand / run / turn / stop only. Hanging, climbing,
## jumping, falling, damage and tile snapping arrive with the rest of A2.2/A2.3.
## No engine API, no floats, no wall-clock: step(state, input) is a function of
## its arguments alone, which is what plan §8 gate 1 (determinism) checks.
##
## State keys are stable (STATE_KEYS): tick, x, y, row, dir, pose, turn_left,
## rng. Coordinates are internal units; measured values (Q1 now answered) move
## in with pop_tables.gd.

enum Pose { STAND, RUN, TURN }

const STATE_KEYS: Array[String] = ["tick", "x", "y", "row", "dir", "pose", "turn_left", "rng"]

## TODO(A2.2): placeholders — replace with pop_tables.gd data (the measured
## run-cycle stream is 26 units / 8 frames, docs/PARITY.md §3; a flat average of
## 3 units/frame is deliberately NOT parity). Turn duration is not yet measured.
const RUN_DX_PER_TICK: int = 3   ## placeholder horizontal step while running
const TURN_TICKS: int = 8        ## placeholder duration of a direction change
const STAND_Y: int = 0           ## placeholder floor y for row 0

const _FNV_OFFSET: int = 0x811C9DC5  ## FNV-1a 32-bit offset basis
const _FNV_PRIME: int = 0x01000193   ## FNV-1a 32-bit prime
const _FNV_MASK: int = 0xFFFFFFFF


static func initial_state(seed: int) -> Dictionary:
	return {
		"tick": 0,
		"x": 0,
		"y": STAND_Y,
		"row": 0,
		"dir": 1,
		"pose": Pose.STAND,
		"turn_left": 0,
		"rng": PopRng.normalize_seed(seed),
	}


## Advance exactly one tick. Pure: returns a new dictionary, never mutates the
## input, never reads global state. input.y / input.special are reserved for
## A2.3 (climb, crouch) and are ignored by the skeleton.
static func step(state: Dictionary, input: PopInput) -> Dictionary:
	var s: Dictionary = state.duplicate()
	s["tick"] = int(s["tick"]) + 1
	# The skeleton advances the generator every tick so the gate can observe
	# seed sensitivity; consumption becomes demand-driven with guard AI.
	s["rng"] = PopRng.step_state(int(s["rng"]))

	var dir: int = int(s["dir"])
	match int(s["pose"]):
		Pose.STAND:
			if input.x == dir:
				s["pose"] = Pose.RUN
			elif input.x == -dir and input.x != 0:
				s["pose"] = Pose.TURN
				s["turn_left"] = TURN_TICKS
		Pose.RUN:
			if input.x == 0:
				s["pose"] = Pose.STAND  # TODO A2.2: real stop has frames
			elif input.x == -dir:
				s["pose"] = Pose.TURN
				s["turn_left"] = TURN_TICKS
			else:
				s["x"] = int(s["x"]) + RUN_DX_PER_TICK * dir
		Pose.TURN:
			var left: int = int(s["turn_left"]) - 1
			if left <= 0:
				s["dir"] = -dir
				s["pose"] = Pose.STAND
				s["turn_left"] = 0
			else:
				s["turn_left"] = left
	return s


## Run a whole input script (array of packed bytes) from an initial seed.
static func run(seed: int, script: Array) -> Dictionary:
	var state: Dictionary = initial_state(seed)
	for packed: Variant in script:
		state = step(state, PopInput.from_byte(int(packed)))
	return state


## FNV-1a (32-bit) over the state fields in STATE_KEYS order. Integer-only and
## order-stable; every intermediate stays below 2^32 x 2^24 < 2^63, so the
## result never relies on int64 overflow behaviour. Two runs of the same seed
## and script are therefore comparable byte-for-byte.
static func hash_state(state: Dictionary) -> int:
	var h: int = _FNV_OFFSET
	for key: String in STATE_KEYS:
		var v: int = int(state[key])
		for i: int in 8:
			h = (((h ^ ((v >> (i * 8)) & 0xFF)) * _FNV_PRIME) & _FNV_MASK)
	return h
