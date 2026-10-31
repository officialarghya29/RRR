extends Node
## Session 013 (step 1, plan B4.3) — the SfxPlayer: the ONE consumer of the
## [Signal SoundEvents.sfx] id bus. Maps each of the 14 ids in
## docs/AUDIO_BRIEF.md to its wav in [code]audio/sfx/[/code], plays it through a
## small [AudioStreamPlayer] pool with per-event volume and a touch of pitch
## variation, and applies the echo audio identity (plan B4.3 / GDD §14): a
## rising pitch ramp at record start, a settling resolve at release, and a
## hollow filter (high-pass + low-pass) on the echo pair — "heard through
## time".
##
## Everything here is Godot-side: the sim emits ids from post-tick diffs and
## never waits on audio. Determinism is untouched — this node holds its OWN
## [RandomNumberGenerator], consumes no global/sim RNG state, and writes
## nothing back into gameplay. Sounds fired while the tree is paused still
## finish (audio mixing is independent of pause); their pitch tweens freeze
## with the tree, which is invisible for sub-second one-shots.
##
## Test seam: [signal sfx_play_requested] fires with the full decision (id,
## stream path, volume, bus, treatment, start pitch) BEFORE playback, so the
## headless suite proves every id routes to the right stream — no audio
## device needed ([code]tests/test_main.gd::_test_sfx_player[/code]).
##
## Positional panning is deliberately NOT implemented yet: [Signal
## SoundEvents.sfx] carries [param pos_px], but a pooled non-positional player
## ignores it (mono game SFX bus). Documented rather than faked.

## Full playback decision for one request — the headless test asserts on this
## instead of on audible output.
signal sfx_play_requested(id: StringName, path: String, volume_db: float, \
		bus: StringName, treatment: StringName, pitch: float)

## Where the 14 wavs live (docs/AUDIO_BRIEF.md rule: named after the id).
const SFX_DIR := "res://audio/sfx/"

## Voices in the ring. 8 comfortably covers the worst case (a pit run can
## stack three landings in two seconds plus a gate grind) without letting one
## burst starve the next.
const POOL_SIZE := 8

## ±5% pitch variation per playback — enough that repeated landings/plates
## don't machine-gun, small enough to stay in character.
const PITCH_JITTER := 0.05

## Buses (created at runtime, below): gameplay on SFX, the echo pair on
## ECHO_SFX which is high/low-passed into SFX. Master volume and mute ride
## bus 0, so they govern everything.
const SFX_BUS: StringName = &"SFX"
const ECHO_SFX_BUS: StringName = &"EchoSFX"

## Master volume steps cycled by the pause menu's "Volume" button, as linear
## gain (0 dB at 100%).
const VOLUME_STEPS: Array[float] = [1.0, 0.75, 0.5, 0.25]

## id -> { volume_db, treatment }. Volumes are mix decisions on top of the
## generator's per-file peak normalisation (tools/gen_sfx.py): impacts and
## deaths sit loudest, UI-ish/mechanism sounds sit back.
## treatment: &"" plain, &"rise" (record start), &"resolve" (release).
const EVENTS: Dictionary = {
	&"land_soft": {"volume_db": -10.0, "treatment": &""},
	&"land_medium": {"volume_db": -8.0, "treatment": &""},
	&"land_hard": {"volume_db": -6.0, "treatment": &""},
	&"spike": {"volume_db": -6.0, "treatment": &""},
	&"death": {"volume_db": -6.0, "treatment": &""},
	&"plate": {"volume_db": -10.0, "treatment": &""},
	&"gate_open": {"volume_db": -8.0, "treatment": &""},
	&"gate_close": {"volume_db": -8.0, "treatment": &""},
	&"sword_clash": {"volume_db": -8.0, "treatment": &""},
	&"sword_strike": {"volume_db": -8.0, "treatment": &""},
	&"sword_hurt": {"volume_db": -8.0, "treatment": &""},
	&"guard_death": {"volume_db": -6.0, "treatment": &""},
	&"echo_record": {"volume_db": -8.0, "treatment": &"rise"},
	&"echo_release": {"volume_db": -8.0, "treatment": &"resolve"},
}

## The stream path an id plays — the single filename rule in one place.
static func stream_path_for(id: StringName) -> String:
	return "%s%s.wav" % [SFX_DIR, id]


var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _streams: Dictionary = {}   # path -> AudioStream (loaded once, cached)
var _rng := RandomNumberGenerator.new()
var _volume_step: int = 0
var _muted: bool = false


func _ready() -> void:
	_rng.randomize()   # own stream only; the sim's RNG is never touched here
	_ensure_buses()
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = String(SFX_BUS)
		add_child(player)
		_players.append(player)
	SoundEvents.sfx.connect(_on_sfx)


# --- The bus consumer -------------------------------------------------------

func _on_sfx(id: StringName, _pos_px: Vector2) -> void:
	play_id(id)


## Play one id through the pool. Returns false (with a warning) for an id
## that has no table entry or no stream file — a call site can never stop the
## game with audio, that is the whole point of the id bus.
func play_id(id: StringName) -> bool:
	var cfg: Variant = EVENTS.get(id)
	if cfg == null:
		push_warning("SfxPlayer: unknown sound id '%s'." % id)
		return false
	var path := stream_path_for(id)
	var stream := _stream(path)
	if stream == null:
		return false

	var entry: Dictionary = cfg
	var treatment := StringName(entry.get("treatment", &""))
	var bus := ECHO_SFX_BUS if treatment != &"" else SFX_BUS
	var target_pitch := 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	var player := _claim_player(bus)
	player.stream = stream
	player.volume_db = float(entry["volume_db"])
	# Treatments start off-pitch and ramp to the jittered rest pitch: the
	# record shimmer rises INTO the moment, the release settles out of it.
	match treatment:
		&"rise":
			player.pitch_scale = 0.8
		&"resolve":
			player.pitch_scale = target_pitch * 1.2
		_:
			player.pitch_scale = target_pitch

	sfx_play_requested.emit(id, path, float(entry["volume_db"]), bus, treatment, player.pitch_scale)
	player.play()
	if treatment != &"":
		_apply_treatment(player, treatment, target_pitch)
	return true


## The B4.3 echo identity, as a pitch tween on the playing voice: record
## start climbs from 0.8x, release resolves down from 1.2x, both landing on
## the jittered rest pitch over the sample's own (sub-second) length.
func _apply_treatment(player: AudioStreamPlayer, treatment: StringName, target_pitch: float) -> void:
	var duration := clampf(player.stream.get_length(), 0.15, 0.6)
	var tween := player.create_tween()
	tween.tween_property(player, "pitch_scale", target_pitch, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	player.set_meta(&"sfx_tween", tween)


## Round-robin voice claim: deterministic, bounded, and a burst can steal the
## oldest voice instead of being dropped (the pit-run case in the pool note).
func _claim_player(bus: StringName) -> AudioStreamPlayer:
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	# A reused voice may still carry a treatment tween from its last job —
	# kill it so this request owns pitch_scale outright.
	var old: Variant = player.get_meta(&"sfx_tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	player.set_meta(&"sfx_tween", null)
	player.bus = String(bus)
	return player


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path] as AudioStream
	if not ResourceLoader.exists(path):
		push_warning("SfxPlayer: missing stream file %s." % path)
		return null
	var stream := ResourceLoader.load(path) as AudioStream
	if stream == null:
		push_warning("SfxPlayer: %s did not load as an AudioStream." % path)
		return null
	_streams[path] = stream
	return stream


# --- Buses (runtime; no committed bus layout to drift) ----------------------

func _ensure_buses() -> void:
	if AudioServer.get_bus_index(String(SFX_BUS)) == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, String(SFX_BUS))
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index(String(ECHO_SFX_BUS)) == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		var idx2 := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx2, String(ECHO_SFX_BUS))
		AudioServer.set_bus_send(idx2, String(SFX_BUS))
		# Hollow "heard through time": strip the deep lows (300 Hz) and the
		# top-end air (3.2 kHz). Mid-band survives, so the shimmer still
		# reads — it just arrives from the other side of a wall of years.
		var highpass := AudioEffectHighPassFilter.new()
		highpass.cutoff_hz = 300.0
		AudioServer.add_bus_effect(idx2, highpass)
		var lowpass := AudioEffectLowPassFilter.new()
		lowpass.cutoff_hz = 3200.0
		AudioServer.add_bus_effect(idx2, lowpass)


# --- Pause-menu controls (master volume + mute, bus 0) ----------------------

## True when the master bus is muted (what the pause menu's label shows).
func is_muted() -> bool:
	return _muted


## Current master volume as a whole percentage for the pause menu label.
func volume_percent() -> int:
	return int(round(VOLUME_STEPS[_volume_step] * 100.0))


func toggle_mute() -> void:
	_muted = not _muted
	AudioServer.set_bus_mute(0, _muted)


## The pause menu's "Volume" button: steps DOWN and wraps (100 → 75 → 50 →
## 25 → 100). One button keeps the keyboard-driven menu simple.
func cycle_volume_down() -> void:
	set_volume_step((_volume_step + 1) % VOLUME_STEPS.size())


## Test- and menu-facing setter; clamped to the step table.
func set_volume_step(step: int) -> void:
	_volume_step = clampi(step, 0, VOLUME_STEPS.size() - 1)
	AudioServer.set_bus_volume_db(0, linear_to_db(VOLUME_STEPS[_volume_step]))
