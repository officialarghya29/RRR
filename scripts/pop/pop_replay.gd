class_name PopReplay
extends RefCounted
## Plan B1 — input-byte recording and replay of a pop_sim run, as a bounded
## ring with per-tick event vectors.
##
## The Temporal Echo records *input bytes*, not positions: replaying the same
## bytes through the deterministic [PopSim] reproduces the same run (plan §4.5,
## §8 gate 4). The buffer is a ring capped at 8 s of logic ticks
## ([constant RING_CAPACITY] = 96 bytes at 12 fps — plan B1.1); recording past
## the cap evicts the oldest byte (and its event vector) so the recorder is
## bounded no matter how long the take is. A run that fits in the ring replays
## to its exact recorded final state; a longer run replays as "the last 8 s",
## which is what an echo should hold anyway.
##
## Each recorded tick also carries an *event vector*: a compact snapshot of the
## observable entity state (plate timers, gate modifier/animation, level-exit
## door, hp, death) plus any milestone fired that tick (plate press, gate
## opening/parked/closed/fast-close). Plan §8 gate 4 compares these vectors
## across runs in addition to state hashes.
##
## The replay participant steps through [PopSim.step] — literally the player's
## step function, no separate echo physics. The legacy `TemporalManager`
## transform path is untouched.

## 8 s at the 12 fps logic tick (plan B1.1: "bounded ring, 8 s = 96 bytes").
const RING_CAPACITY: int = 96

var seed: int = 0
var bytes: Array = []
## Per-tick event vectors, ring-aligned with `bytes` (same eviction).
var events: Array = []
## Per-tick structured milestones ([{kind, key}] — plan B0 step 4),
## ring-aligned with `bytes` (same eviction): the sim-path echo replays
## these as `event_replayed` instead of parsing the `ev:` string tail.
var milestones: Array = []


## Record a run's input: step a fresh participant and capture each tick's
## packed byte plus its entity event vector, returning the replay handle and
## the participant's final state. Bytes beyond [constant RING_CAPACITY] evict
## the oldest (bounded ring).
static func record_run(seed_n: int, script: Array, tiles: Array,
		mods: Dictionary = {}, entities: Dictionary = {}) -> Dictionary:
	var r: PopReplay = PopReplay.new()
	r.seed = seed_n
	var state: Dictionary = PopSim.initial_state(seed_n, tiles, mods, entities)
	for packed: Variant in script:
		var input: PopInput = PopInput.from_byte(int(packed))
		var prev: Dictionary = _entity_view(state)
		state = PopSim.step(state, input)
		r.push_tick(input.to_byte(), entity_events(prev, state), milestones_for(prev, state))
	return {"replay": r, "final": state}


## Append one recorded tick, evicting the oldest byte + its event vector and
## milestone list at ring capacity. The single append path for every recorder
## (record_run and TemporalManager's sim-path take), so the three ring arrays
## can never drift out of alignment.
func push_tick(byte_val: int, event_vec: String, ms: Array = []) -> void:
	bytes.append(int(byte_val))
	events.append(event_vec)
	milestones.append(ms)
	while bytes.size() > RING_CAPACITY:
		bytes.pop_front()
		events.pop_front()
		milestones.pop_front()


## Replay the recorded bytes into a fresh sim participant with `tiles` / `mods`
## / `entities` (a second run, not the recorder's). Steps through [PopSim.step]
## directly — the same function the player runs.
func replay(tiles: Array, mods: Dictionary = {}, entities: Dictionary = {}) -> Dictionary:
	var state: Dictionary = PopSim.initial_state(seed, tiles, mods, entities)
	for packed: Variant in bytes:
		state = PopSim.step(state, PopInput.from_byte(int(packed)))
	return state


## Replay and return `{ "state": ..., "events": [...] }` — the echo run's final
## state plus the event vector it produced, for plan §8 gate 4 comparison.
func replay_events(tiles: Array, mods: Dictionary = {}, entities: Dictionary = {}) -> Dictionary:
	var state: Dictionary = PopSim.initial_state(seed, tiles, mods, entities)
	var vec: Array = []
	for packed: Variant in bytes:
		var input: PopInput = PopInput.from_byte(int(packed))
		var prev: Dictionary = _entity_view(state)
		state = PopSim.step(state, input)
		vec.append(entity_events(prev, state))
	return {"state": state, "events": vec}


func size() -> int:
	return bytes.size()


## True once the ring has dropped at least one byte (cap actually engaged).
func at_capacity() -> bool:
	return bytes.size() >= RING_CAPACITY


## A pre-step snapshot of the observable entity state. `PopSim.step` returns a
## *shallow* duplicate and mutates the nested plates/gates/exit dictionaries in
## place, so holding the old outer dictionary would show post-step values — the
## event diff needs a real copy of the sub-dicts taken before the step.
static func _entity_view(s: Dictionary) -> Dictionary:
	return {
		"plates": (s.get("plates", {}) as Dictionary).duplicate(),
		"gates": PopSim._dup_entities(s.get("gates", {})),
		"exit": (s.get("exit", {}) as Dictionary).duplicate(),
		"hp": int(s.get("hp", 0)),
		"dead": int(s.get("dead", 0)),
	}


## The plan §8 gate 4 event vector for one tick: a snapshot of the observable
## entity state (`p:` plate timers, `g:` gate mod/type, `e:` exit door, `hp`,
## `d`) followed by any milestone that fired this tick (`ev:` plate press, gate
## opening / parked / closed / fast-close). Pure state-diff — deterministic
## across runs, and any divergence in entity trajectories shows up as a string
## inequality at the tick it happens.
static func entity_events(prev: Dictionary, cur: Dictionary) -> String:
	var snap: Array = []
	var milestones := milestones_for(prev, cur)
	var cp: Dictionary = cur.get("plates", {})
	for key: String in cp.keys():
		snap.append("p:%s=%d" % [key, int(cp[key])])

	# Gates: snapshot mod/type (milestones come from milestones_for below).
	var cg: Dictionary = cur.get("gates", {})
	for key: String in cg.keys():
		var g1: Dictionary = cg[key] as Dictionary
		snap.append("g:%s=%d,%d" % [key, int(g1.get("mod", PopTables.GATE_CLOSED)), int(g1.get("type", -1))])

	# Level-exit door + kid condition.
	var e1: Dictionary = cur.get("exit", {}) as Dictionary
	if not e1.is_empty():
		snap.append("e=%d" % int(e1.get("mod", 0)))
		snap.append("hp=%d" % int(cur.get("hp", 0)))
		snap.append("d=%d" % int(cur.get("dead", 0)))

	var out := String("|".join(snap))
	if not milestones.is_empty():
		var texts: Array = []
		for m: Dictionary in milestones:
			texts.append("%s:%s" % [m["kind"], m["key"]])
		out += "|ev:" + ",".join(texts)
	return out


## The structured milestones for one tick: [{kind, key}] — plate press
## (PARITY §10), gate opening / fast-close / open (parked) / closed (PARITY
## §9), and the kid's death. This is the list entity_events stringifies into
## its `ev:` tail; consumers that need the entity keys (which contain commas)
## should read this instead of parsing that string.
static func milestones_for(prev: Dictionary, cur: Dictionary) -> Array:
	var out: Array = []
	var pp: Dictionary = prev.get("plates", {})
	var cp: Dictionary = cur.get("plates", {})
	for key: String in cp.keys():
		var was: int = int(pp.get(key, 0))
		var now: int = int(cp[key])
		if was < PopTables.PLATE_REPRESS_BELOW and now == PopTables.PLATE_HOLD_TIMER - 1:
			out.append({"kind": "press", "key": key})
	var pg: Dictionary = prev.get("gates", {})
	var cg: Dictionary = cur.get("gates", {})
	for key: String in cg.keys():
		var g0: Dictionary = pg.get(key, {}) as Dictionary
		var g1: Dictionary = cg[key] as Dictionary
		var m0: int = int(g0.get("mod", PopTables.GATE_CLOSED))
		var m1: int = int(g1.get("mod", PopTables.GATE_CLOSED))
		var t0: int = int(g0.get("type", -1))
		var t1: int = int(g1.get("type", -1))
		if t1 == 1 and t0 != 1:
			out.append({"kind": "opening", "key": key})
		if t1 >= 3 and t0 < 3:
			out.append({"kind": "fastclose", "key": key})
		if m1 >= PopTables.GATE_PARKED and m0 < PopTables.GATE_PARKED:
			out.append({"kind": "open", "key": key})
		if m1 == 0 and m0 > 0:
			out.append({"kind": "closed", "key": key})
	if int(cur.get("dead", 0)) != 0 and int(prev.get("dead", 0)) == 0:
		out.append({"kind": "dead", "key": "kid"})
	return out


## A copy with one bit of one recorded byte flipped — the plan §8 gate 4
## divergence probe: a single altered input bit must change the run. Event
## vectors are NOT copied: they belonged to the unflipped take; regenerate
## them with [method replay_events] on this handle.
func with_flipped_bit(index: int, bit: int) -> PopReplay:
	var r: PopReplay = PopReplay.new()
	r.seed = seed
	r.bytes = bytes.duplicate()
	if index >= 0 and index < r.bytes.size():
		r.bytes[index] = int(r.bytes[index]) ^ (1 << bit)
	return r
