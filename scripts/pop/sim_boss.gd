class_name SimBoss
extends SimGuard
## Plan B2.3 / B3.1 (session 011 step 4) — the Time Warden duel on the sim
## path, built ON the guard framework (plan §4.7): the same 10 fps fight tick,
## the same [PopGuard] decision/reach/frame rules wholesale, the same boundary
## (read-only snapshots + this tick's input byte; damage only ever REQUESTED
## through [SimWorld]'s single writer). What the boss adds:
##
##   * HIGH SKILL + a boss HP pool: the skill profile is the cited PARITY §12
##     row, the pool multiplier is our own characterization (labelled);
##   * a SHIELD: while shielded the boss is INVULNERABLE — the
##     [method _guard_hp_absorbed] hook restores his local hp BEFORE any
##     damage event publishes, so no hit lands, no death, no defeat;
##   * the shield drops ONLY while an ECHO holds the arena plate
##     ([member plate_key]) — foot tiles of
##     [method TemporalManager.active_sim_echoes] are read read-only every
##     logic tick; the kid's own press never counts (and the plate sits
##     beyond the boss's wake range, so you cannot fight from it);
##   * echo expiry returns the shield — NOT a softlock: a fresh take can be
##     recorded again (the re-record loop is test-proven);
##   * [EventBus] `boss_*` events drive the HUD boss bar.
##
## FAIRNESS AND DIFFICULTY ARE NOT VERIFIED — needs human playtest.

## Boss HP pool — MEASURED (session 011 fight matrix): the pinned seed +
## counter cadence clears this pool on BOTH fight streams the tests use
## (fresh engagement: 5 lands before the kid's third incoming; the post-
## expiry engagement, whose duel RNG continues mid-stream: 3 lands before
## death). hp 4+ is not clearable on the post-expiry stream within the
## kid's 3 hp. The shield, not raw hp, is the boss's defence. Character-
## ization; fairness/difficulty not verified, needs human playtest.
const BOSS_HP: int = 3
const DISPLAY_NAME: String = "THE TIME WARDEN"

## "row,col" of the arena plate the shield reads.
var plate_key: String = ""
## true = protected (default); false = an echo holds the plate, hits land.
var shielded: bool = true

var _engaged: bool = false
var _defeated_emitted: bool = false
var _shown_hp: int = BOSS_HP


## Replaces [method SimGuard.setup] (same arguments + the arena plate).
## Call before or after the node enters the tree — the world connection is
## idempotent in the framework.
func setup_boss(p_world: SimWorld, x_sim: int, p_skill: int, seed_n: int, p_plate: String) -> void:
	setup(p_world, x_sim, p_skill, seed_n)
	plate_key = p_plate
	guard["hp"] = BOSS_HP
	shielded = true
	_engaged = false
	_defeated_emitted = false
	_shown_hp = BOSS_HP


## Shield first (by the time the world publishes this tick, echoes have
## already stepped and pressed — `step_with` order), then the framework's
## fight tick, then the boss-facing HUD events.
func _on_logic_tick(state: Dictionary, input_byte: int) -> void:
	_update_shield()
	super._on_logic_tick(state, input_byte)
	_publish_boss()


func _update_shield() -> void:
	var next := not _echo_holds_plate()
	if next == shielded:
		return
	shielded = next
	EventBus.boss_shield_changed.emit(shielded)


## Read-only: does ANY active sim echo stand on the arena plate this tick?
## Mirrors SimWorld._apply_echo_presses' foot-tile read (same row/col rule).
func _echo_holds_plate() -> bool:
	if plate_key.is_empty():
		return false
	var parts := plate_key.split(",")
	if parts.size() != 2:
		return false
	var erow := int(parts[0])
	var ecol := int(parts[1])
	for echo: TemporalEcho in TemporalManager.active_sim_echoes():
		var es: Dictionary = (echo as SimEcho).state
		if es.is_empty() or int(es.get("dead", 0)) != 0:
			continue
		if int(es.get("row", -1)) == erow and PopSim._col_of(PopSim._foot_x(es)) == ecol:
			return true
	return false


## The shield: called by the framework the moment the local duel reports the
## boss hurt — restore hp (and life) before any damage event publishes.
## The transcript keeps the draw and gains a marker, so a shielded window is
## visible in the record and stays deterministic.
func _guard_hp_absorbed(hp_before: int) -> void:
	if not shielded:
		return
	guard["hp"] = hp_before
	if int(guard.get("dead", 0)) != 0:
		guard["dead"] = 0
	transcript.append("boss:shield")


func _publish_boss() -> void:
	if not _engaged and active:
		_engaged = true
		EventBus.boss_engaged.emit(DISPLAY_NAME, int(guard["hp"]), BOSS_HP)
	if not _engaged:
		return
	var hp := int(guard["hp"])
	if hp != _shown_hp:
		_shown_hp = hp
		EventBus.boss_health_changed.emit(hp, BOSS_HP)
	if int(guard.get("dead", 0)) != 0 and not _defeated_emitted:
		_defeated_emitted = true
		# The framework already published its duel_event/sfx on the death tick;
		# the HUD signal is the boss-specific surface.
		EventBus.boss_defeated.emit()
