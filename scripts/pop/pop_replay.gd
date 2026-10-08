class_name PopReplay
extends RefCounted
## Plan B1 (thin slice) — input-byte recording and replay of a pop_sim run.
##
## The Temporal Echo records *input bytes*, not positions: replaying the same
## bytes through the deterministic [PopSim] reproduces the same run (plan §4.5,
## §8 gate 4). This module is the whole of that idea in the smallest useful
## form — it records a live run's per-tick `pop_input` bytes and releases a
## second sim participant that replays them into its own run. The full Stage-B
## Echo (room-scoped recording, multiple participants, the legacy
## `TemporalManager` bridge) is built on top of this, not here.

var seed: int = 0
var bytes: Array = []


## Record a run's input: step a fresh participant and capture each tick's
## packed byte, returning the replay handle and the participant's final state.
static func record_run(seed_n: int, script: Array, tiles: Array,
		mods: Dictionary = {}, entities: Dictionary = {}) -> Dictionary:
	var r: PopReplay = PopReplay.new()
	r.seed = seed_n
	var state: Dictionary = PopSim.initial_state(seed_n, tiles, mods, entities)
	for packed: Variant in script:
		var input: PopInput = PopInput.from_byte(int(packed))
		r.bytes.append(input.to_byte())
		state = PopSim.step(state, input)
	return {"replay": r, "final": state}


## Replay the recorded bytes into a fresh sim participant with `tiles` / `mods`
## / `entities` (a second run, not the recorder's).
func replay(tiles: Array, mods: Dictionary = {}, entities: Dictionary = {}) -> Dictionary:
	return PopSim.run(seed, bytes, tiles, mods, entities)


func size() -> int:
	return bytes.size()


## A copy with one bit of one recorded byte flipped — the plan §8 gate 4
## divergence probe: a single altered input bit must change the run.
func with_flipped_bit(index: int, bit: int) -> PopReplay:
	var r: PopReplay = PopReplay.new()
	r.seed = seed
	r.bytes = bytes.duplicate()
	if index >= 0 and index < r.bytes.size():
		r.bytes[index] = int(r.bytes[index]) ^ (1 << bit)
	return r
