class_name MenuScreen
extends Control
## One screen that serves the title, pause, level-complete and victory states.
##
## Rather than four near-identical scenes, each state is just a title, a body
## line and a list of buttons. Buttons are rebuilt per state, so there is no way
## for a stale button from a previous screen to remain clickable.

## Emitted with one of the action ids that [GameManager] handles.
signal action_requested(action: StringName)

const VIEWPORT_WIDTH: float = 1280.0
const VIEWPORT_HEIGHT: float = 720.0
const PANEL_SIZE: Vector2 = Vector2(560.0, 420.0)
## Centred by hand rather than with an anchor preset: the logical viewport is a
## fixed 1280x720 under canvas_items stretch, and
## [method Control.set_anchors_preset] rewrites offsets, which would fight the
## explicit positions the children below rely on.
##   (1280 - 560) / 2 = 360    (720 - 420) / 2 = 150
const PANEL_POSITION: Vector2 = Vector2(360.0, 150.0)

var _panel: ColorRect
var _title: Label
var _body: Label
var _buttons: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	hide_all()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.015, 0.04, 0.82)
	scrim.position = Vector2.ZERO
	scrim.size = Vector2(VIEWPORT_WIDTH, VIEWPORT_HEIGHT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	_panel = ColorRect.new()
	_panel.color = Palette.UI_PANEL
	_panel.position = PANEL_POSITION
	_panel.size = PANEL_SIZE
	add_child(_panel)

	_title = Label.new()
	_title.position = Vector2(36.0, 40.0)
	_title.custom_minimum_size = Vector2(PANEL_SIZE.x - 72.0, 0.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Palette.TEMPORAL_CORE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_title)

	_body = Label.new()
	_body.position = Vector2(36.0, 150.0)
	_body.custom_minimum_size = Vector2(PANEL_SIZE.x - 72.0, 0.0)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_theme_font_size_override("font_size", 17)
	_body.add_theme_color_override("font_color", Palette.UI_DIM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_body)

	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(150.0, 250.0)
	_buttons.custom_minimum_size = Vector2(PANEL_SIZE.x - 300.0, 0.0)
	_buttons.add_theme_constant_override("separation", 10)
	_panel.add_child(_buttons)


# --- Public screens ---------------------------------------------------------

func show_title() -> void:
	show_all()
	# B5.2 accept clause: the title is "Echoes of Time" — the franchise name
	# appears only as the descriptive credit line on the Credits screen.
	_title.text = "ECHOES OF TIME"
	_body.text = "\"Master your past to survive your present.\"\n\n[WASD / Arrows] move    [Space] jump    [J] light    [K] heavy\n[L] block   [Shift] dodge   [E] interact   [Q] record / release echo\n\nRRR — Rewind. Reimagine. Reconnect."
	_set_buttons([
		["Begin the descent", &"start"],
		["Controls", &"controls"],
		["Credits", &"credits"],
		["Quit", &"quit"],
	])


## Session 012 step 4: the full binding table, straight from
## [InputActions] — the title screen keeps only the summary line.
func show_controls() -> void:
	show_all()
	_title.text = "CONTROLS"
	_body.text = "[A / D or ← / →] move        [W / ↑] up, climb    [S / ↓] crouch\n\n[Space] jump                  [Shift] grab, hang, edge-walk\n[J] light attack              [K] heavy attack    [L] block\n\n[E] interact                  [Q] record — release a temporal echo\n\n[Esc] pause                   [R] restart level    [F3] debug overlay\n\nThe echo walks your recorded path — stand on a plate while recording,\nrelease, and your past will hold the gate for you."
	_set_buttons([
		["Back", &"menu"],
	])


## Session 012 step 4: the tribute line and the upstream credit the hand-off
## protocol requires on screen.
func show_credits() -> void:
	show_all()
	_title.text = "CREDITS"
	_body.text = "Echoes of Time — an original tribute,\ninspired by the 1989 classic Prince of Persia.\n\nBuilt on the RRR project by Arghya Bose\n(github.com/officialarghya29/RRR), of which this work is a maintained fork.\n\nAll code, art and audio in this build are original or licence-cleared —\nsee docs/ASSET_LICENSES.md."
	_set_buttons([
		["Back", &"menu"],
	])


func show_pause() -> void:
	show_all()
	_title.text = "PAUSED"
	_body.text = "The palace waits between moments."
	_set_buttons([
		["Resume", &"resume"],
		["Restart checkpoint", &"restart_checkpoint"],
		["Restart level", &"restart_level"],
		["Abandon to menu", &"menu"],
	])


func show_level_complete(next_title: String) -> void:
	show_all()
	_title.text = "THE MOMENT HOLDS"
	_body.text = "Level cleared.\nNext: %s" % next_title
	_set_buttons([
		["Continue", &"next_level"],
		["Replay this level", &"restart_level"],
		["Abandon to menu", &"menu"],
	])


func show_victory() -> void:
	show_all()
	_title.text = "THE PALACE REMEMBERS"
	_body.text = "You mastered your past and survived your present.\n\nThank you for playing Echoes of Time."
	_set_buttons([
		["Play again", &"start"],
		["Quit", &"quit"],
	])


## Test-facing reads of the current screen (the flow test asserts on the
## real text the player would see).
func screen_title() -> String:
	return _title.text


func screen_body() -> String:
	return _body.text


func show_all() -> void:
	visible = true


func hide_all() -> void:
	visible = false


# --- Internals --------------------------------------------------------------

func _set_buttons(entries: Array) -> void:
	for child: Node in _buttons.get_children():
		child.queue_free()
	for entry: Array in entries:
		var button := Button.new()
		button.text = String(entry[0])
		button.add_theme_font_size_override("font_size", 17)
		var action := StringName(entry[1])
		button.pressed.connect(func() -> void: action_requested.emit(action))
		_buttons.add_child(button)

	# Focus the first button so the menu is keyboard-navigable immediately.
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus()
