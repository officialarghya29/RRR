# AUDIO BRIEF — SFX for *Prince of Persia: Echoes of Time*

**Status (Session 010):** hook points only — **no audio files exist yet**. Every
gameplay event below already emits a named id on `SoundEvents.sfx` (autoload,
`scripts/systems/sound_events.gd`); nothing plays sound until an `SfxPlayer`
connects and maps ids to files. That is deliberate: the trim decision is
**SFX-first** (Q4), music is a stretch goal, and the sim core stays pure — all
hooks sit on the Godot side, on diffs the sim already publishes.

## The rule (non-negotiable)

> **Every audio file committed to this repo needs a row in
> `docs/ASSET_LICENSES.md` first** — origin, author, licence. No row, no
> commit. Original or properly licensed only (competition rule; the file's
> Summary table has an "Audio" row to fill).

## The contract

An `SfxPlayer` (future) does, once:

```gdscript
SoundEvents.sfx.connect(_on_sfx)   # id: StringName, pos_px: Vector2
```

and looks `id` up in one table. `pos_px` is world-pixel position for
pan/attenuation (origin = no position info). Nothing else in the codebase
needs to change to add sound.

## The ids

Durations are **suggestions** for the eventual samples, not constraints on the
code. "Fires" cites the exact hook point.

| id | Fires when | Hook point | Suggested length / shape |
|---|---|---|---|
| `land_soft` | the kid lands a ≤1-row drop (no damage) | `sim_world.gd::_publish_sounds` — seq enters `soft_land` | ~0.25 s, light cloth/foot thud |
| `land_medium` | the kid lands a 2-row drop (−1 HP) | `_publish_sounds` — seq enters `med_land` | ~0.4 s, heavier impact + grunt |
| `land_hard` | crushed / fell out of the world (death) | `_publish_sounds` — seq enters `hard_land` | ~0.6 s, body impact, dark |
| `spike` | the kid lands on or runs into spikes (instant death) | `_publish_sounds` — seq enters `impale` | ~0.5 s, impale + metal ring |
| `death` | the kid dies (any cause) | `_publish_entity_events` — `dead` milestone | ~0.8 s, death sting (may layer over the cause sound) |
| `plate` | a plate is pressed (kid or echo stance) | `_publish_entity_events` — `press` milestone | ~0.2 s, stone click |
| `gate_open` | a gate reaches its open park (238) | `_publish_entity_events` — `open` milestone | ~1.2 s, stone grind up |
| `gate_close` | a gate finishes closing (0) or fast-closes | `_publish_entity_events` — `closed` / `fastclose` | ~1.0 s, stone grind down + thunk |
| `sword_clash` | a strike is parried (either fighter) | `sim_guard.gd` — `duel_event` `clash` | ~0.3 s, bright metal parry |
| `sword_strike` | a strike lands on the guard | `sim_guard.gd` — `duel_event` `hit_guard` | ~0.3 s, hit + guard grunt |
| `sword_hurt` | the guard's strike lands on the kid | `sim_guard.gd` — `duel_event` `hit_kid` | ~0.3 s, kid pain grunt |
| `guard_death` | the guard falls (duel won) | `sim_guard.gd` — `duel_event` `defeated` | ~0.6 s, body fall + sword drop |
| `echo_record` | a take starts recording (Q key) | `temporal_manager.gd::start_recording` | ~0.5 s, rising time shimmer |
| `echo_release` | a take is released as an echo | `temporal_manager.gd::_finalize_*` | ~0.6 s, shimmer resolve / bell |

Notes for whoever records or composes these:

- **One-shot, short, readable.** These fire during a 12 fps logic game; long
  tails should duck rather than stack (a 2-second gate grind overlaps itself
  rarely, but the pit-run can produce three landings in two seconds).
- **Determinism is unaffected by sound** — ids are emitted from post-tick
  diffs, so the same seed and script always produce the same id sequence.
  Useful for audio QA: the test suite asserts every id fires in its scenario
  (`tests/test_main.gd::_test_sound_events`).
- **Placeholders welcome.** A `.wav` from any editor is fine as long as the
  `ASSET_LICENSES.md` row exists. Keep files in `assets/audio/sfx/` (create
  when the first file lands), name them after the id (`land_soft.wav`).
- **Music (stretch, Q4):** not scoped here. If it becomes real, it goes
  through the same licence row and should never gate the SFX pass.

*Session 010, 2026-10-12. Hand-off written for Arghya (audio) or the
maintainer; questions to the session log in `review.md`.*
