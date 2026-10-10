extends Node2D
## Entry point for the game.
##
## Almost all orchestration lives in the [code]GameManager[/code] autoload, which
## has already shown the title screen by the time this runs. This node exists to
## own the window and to provide a QA shortcut so a level can be booted directly
## without clicking through the menu — the same trick the headless smoke test
## relies on.

const WINDOW_TITLE: String = "Prince of Persia: Echoes of Time"


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(WINDOW_TITLE)
	_apply_boot_flags()
	_apply_level_shortcut()


## Supports [code]--legacy-physics[/code] on the command line (plan B0.1,
## approval condition c): selects the original physics stack — kept runnable
## as the video fallback — instead of the default PopSim path. Applied before
## the level shortcut so a combined [code]--legacy-physics --level=N[/code]
## boots level N on the legacy stack.
func _apply_boot_flags() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if args.has("--legacy-physics"):
		GameManager.use_legacy_physics = true
		print("[Main] Boot flag: --legacy-physics (physics stack, video fallback).")


## Supports [code]--level=N[/code] (1-based) on the command line.
func _apply_level_shortcut() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	for argument: String in args:
		if not argument.begins_with("--level="):
			continue
		var raw := argument.split("=")
		if raw.size() < 2 or not raw[1].is_valid_int():
			push_warning("Main: --level expects an integer, got '%s'." % argument)
			return
		var index: int = clampi(int(raw[1]) - 1, 0, LevelCatalog.count() - 1)
		print("[Main] QA shortcut: booting level index %d." % index)
		GameManager.load_level(index)
		return
