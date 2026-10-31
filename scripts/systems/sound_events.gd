extends Node
## Session 010 (step 4, plan audio hook points) — the SoundEvent layer: a
## named-event bus gameplay emits WITHOUT touching the sim or holding an
## audio node. No audio file is loaded or played here; a future SfxPlayer
## (or Arghya's audio pass) connects to [signal sfx] and maps each id to a
## file in one table.
##
## Why an id bus instead of AudioStreamPlayers sprinkled around: the trim
## decision is SFX-first with no assets yet (Q4 = SFX-first), and the sim
## must stay pure — every producer below is on the Godot side, reading the
## same diffs and events the puzzle stream already uses. docs/AUDIO_BRIEF.md
## is the hand-off: each id, where it fires, a suggested duration, and the
## rule that every committed audio file needs a row in docs/ASSET_LICENSES.md.

## One named sound request. [param pos_px] is optional world-pixel position
## (defaults to the origin) so a future player can pan/attenuate per source.
signal sfx(id: StringName, pos_px: Vector2)


## Emit a named sound request. Branch-free for call sites; a no-op for
## listeners until something connects (nothing plays audio yet). Autoload
## methods are reached through the autoload name, like TemporalManager's.
func emit_sfx(id: StringName, pos_px: Vector2 = Vector2.ZERO) -> void:
	sfx.emit(id, pos_px)
