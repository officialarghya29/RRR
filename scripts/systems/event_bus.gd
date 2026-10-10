extends Node
## Global, read-only signal hub (autoload: [code]EventBus[/code]).
##
## Systems publish here instead of holding references to each other. This keeps
## the HUD, the TemporalManager and the level scripts decoupled: the HUD never
## needs to know a [Player] exists, it only listens for [signal health_changed].
##
## Rule: this node stores no state and contains no logic beyond relaying.

# --- Player -----------------------------------------------------------------
signal health_changed(current: int, maximum: int)
signal player_damaged(amount: int, source: Node)
signal player_died
signal player_spawned(player: Node)
## Sim path (plan B0.1): per-tick player position in sim units (x/y), row and
## facing. Producers changed from physics nodes to sim diffs; consumers
## (checkpoints, future enemies) read it the same way.
signal player_moved(x: float, y: float, row: int, dir: int)
## Sim path (plan B0.1 step 3): one entity milestone per logic tick — plate
## press, gate opening / open (parked) / closed / fast-close — parsed from the
## same per-tick diff the echo recorder stamps (PopReplay.entity_events), so
## the puzzle framework's event stream and the echo's event vectors can never
## disagree. [param milestone] is the kind ("press"/"opening"/"open"/
## "closed"/"fastclose"), [param key] the entity key ("row,col").
signal sim_entity_event(milestone: StringName, key: String)

# --- Temporal Echo ----------------------------------------------------------
signal temporal_energy_changed(current: float, maximum: float)
signal recording_started(max_duration: float)
signal recording_progress(elapsed: float, max_duration: float)
signal recording_cancelled(reason: String)
signal echo_created(echo: Node, recorded_duration: float)
signal echo_expired(echo: Node)
signal echo_event_replayed(echo: Node, event_id: StringName)

# --- Boss -------------------------------------------------------------------
signal boss_engaged(display_name: String, current: int, maximum: int)
signal boss_health_changed(current: int, maximum: int)
signal boss_shield_changed(shielded: bool)
signal boss_defeated

# --- World / progression ----------------------------------------------------
signal objective_changed(text: String)
signal checkpoint_reached(checkpoint_id: StringName)
signal level_started(level_id: StringName, title: String)
signal level_completed(level_id: StringName)
signal game_paused(is_paused: bool)
