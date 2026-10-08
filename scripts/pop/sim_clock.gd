class_name SimClock
extends RefCounted
## Plan A3.1 — fixed-step clock that turns a variable render delta into whole
## sim ticks at a fixed logic rate (PARITY §1: 12 Hz traverse, 10 Hz with the
## sword drawn). Arithmetic only: no engine clock, no floats inside the sim.
##
## [member prev] and [member curr] are the two SimStates straddling the current
## render position, and [member alpha] is the fraction between them (0.0 → prev,
## approaching 1.0 → curr). The clock renders one tick "behind" the newest
## state so [method lerp_channel] can interpolate without stutter.

## Tick rate while traversing; 12 Hz per PARITY §1 (`PopTables.TICK_HZ_TRAVERSE`).
const TICK_HZ_TRAVERSE: int = PopTables.TICK_HZ_TRAVERSE
## Tick rate with the sword drawn; 10 Hz per PARITY §1.
const TICK_HZ_SWORD: int = PopTables.TICK_HZ_SWORD

## Small tolerance so a run of `1/60 s` frames sums to the exact expected tick
## count instead of landing a hair under each period boundary.
const _EPS: float = 1e-6

var hz: int = TICK_HZ_TRAVERSE
var prev: Dictionary = {}
var curr: Dictionary = {}
var ticks: int = 0
## Fractional progress toward the next tick, kept in `0.0 ≤ alpha < 1.0`.
var alpha: float = 0.0

var _acc: float = 0.0  ## seconds accumulated toward the next tick


func _init(state: Dictionary = {}, sword_drawn: bool = false) -> void:
	prev = state
	curr = state
	set_sword_drawn(sword_drawn)


## Seconds per sim tick at the current rate.
func period() -> float:
	return 1.0 / float(hz)


func set_sword_drawn(drawn: bool) -> void:
	hz = TICK_HZ_SWORD if drawn else TICK_HZ_TRAVERSE


## Add one render frame's [param delta]; return how many sim ticks are due now.
## The caller steps and [method push]es the sim that many times.
func advance(delta: float) -> int:
	if delta <= 0.0 or hz <= 0:
		return 0
	_acc += delta
	var due := 0
	var p := period()
	while _acc >= p - _EPS:
		_acc -= p
		due += 1
	alpha = clampf(_acc / p, 0.0, 1.0)
	return due


## Record a freshly stepped state: curr becomes prev, the new state becomes curr.
func push(state: Dictionary) -> void:
	prev = curr
	curr = state
	ticks += 1


## Interpolate the named numeric channel between prev and curr by [member alpha].
func lerp_channel(key: String) -> float:
	if prev.is_empty() and curr.is_empty():
		return 0.0
	return lerpf(float(prev.get(key, 0)), float(curr.get(key, 0)), alpha)
