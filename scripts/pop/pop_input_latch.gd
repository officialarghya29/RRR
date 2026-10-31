class_name PopInputLatch
extends RefCounted
## Plan A3.3 — bridge the engine's render-rate input to the fixed sim rate.
##
## The latcher is sampled every render frame and holds the *union* of intents
## seen since the last tick, so a tap shorter than one sim tick still reaches
## the sim (input latency ≤ 1 tick + ≤ 1 render frame). A fresh [PopInput] is
## handed to [PopSim] on each tick via [method take].

var _latch: PopInput = PopInput.neutral()


## OR one render frame's axes into the latch. Opposite directions pressed in
## the same interval cancel (x = right − left), as they would on a real pad.
## Session 010: attack/block ride the byte's reserved special bits (1 = strike,
## 2 = block) — plan B1.1 kept event attachment as special bits; SimGuard reads
## them as duel commands on the sim path. A held bit latches like the axes and
## clears on [method take], like every other field.
func sample(left: bool, right: bool, up: bool, down: bool, shift: bool,
		attack: bool = false, block: bool = false) -> void:
	var x: int = (1 if right else 0) - (1 if left else 0)
	var y: int = (1 if down else 0) - (1 if up else 0)
	if x != 0:
		_latch.x = x
	if y != 0:
		_latch.y = y
	if shift:
		_latch.shift = 1
	if attack:
		_latch.special |= 1
	if block:
		_latch.special |= 2


## Convenience: sample the runtime-registered actions (see
## `scripts/systems/input_actions.gd`). Jump-up is `move_up`; the grab/climb
## modifier is `grab`.
func sample_actions() -> void:
	sample(
		Input.is_action_pressed(&"move_left"),
		Input.is_action_pressed(&"move_right"),
		Input.is_action_pressed(&"move_up"),
		Input.is_action_pressed(&"crouch"),
		Input.is_action_pressed(&"grab"),
		Input.is_action_pressed(&"light_attack"),
		Input.is_action_pressed(&"block"))


func is_empty() -> bool:
	return _latch.is_neutral()


## Consume the latch at a sim tick and start a fresh interval.
func take() -> PopInput:
	var out := _latch
	_latch = PopInput.neutral()
	return out
