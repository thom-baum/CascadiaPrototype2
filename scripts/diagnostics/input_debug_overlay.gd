class_name InputDebugOverlay
extends CanvasLayer
## Diagnostic overlay for the input foundation (Milestone 0).
##
## Shows, for every semantic action: its name, its current bindings, and whether
## it is idle / held / pressed this frame. It also shows the resolved sprint and
## dodge state, which is what proves DODGE and SPRINT stay separate actions even
## though the controller drives both from Circle.
##
## Press F1 to hide/show the panel. The panel has to be hideable because
## Milestone 1 is judged by eye while moving around the test environment, and a
## full-width table would cover the arena.
##
## This is development tooling. Listed in CASCADIA_DELETION_MANIFEST.md.

const TEXT_DIM := Color(0.62, 0.64, 0.68, 1.0)
const TEXT_ACTIVE := Color(0.95, 0.95, 0.95, 1.0)
const TEXT_FLASH := Color(1.0, 0.86, 0.28, 1.0)
const TEXT_GOOD := Color(0.45, 0.9, 0.5, 1.0)
const TEXT_BAD := Color(1.0, 0.4, 0.4, 1.0)
const TEXT_RESERVED := Color(0.62, 0.5, 0.78, 1.0)
const TEXT_HEADER := Color(0.85, 0.88, 0.95, 1.0)

## Compact column widths. The overlay shares the viewport with the running game,
## so it stays as narrow as the longest label allows.
const NAME_WIDTH := 112
const BINDING_WIDTH := 150
const STATE_WIDTH := 86
const FONT_SIZE := 11

var _input: CascadiaInput
var _panel: PanelContainer
var _header_move: Label
var _header_mouse: Label
var _header_mobility: Label
var _rows: Array = []


func _ready() -> void:
	_build_ui()


func _process(_delta: float) -> void:
	var input := _get_input()
	if input != null and input.is_action_pressed_now(GameActions.TOGGLE_DEBUG_OVERLAY):
		_panel.visible = not _panel.visible
	_update_rows(input)
	if input == null:
		_header_move.text = "input layer not found in scene"
		_header_mouse.text = ""
		_header_mobility.text = ""
		return

	var move := input.get_move_vector()
	var look := input.get_look_delta()
	_header_move.text = "move (%.2f, %.2f)   look (%.1f, %.1f)" % [move.x, move.y, look.x, look.y]
	# The LIVE engine state and the focus gate, side by side, so a focus change is readable while it
	# happens instead of being inferred from the camera. `mouse_look_enabled` is still gameplay's
	# intent; the capture shown here is what the engine is actually doing right now.
	# `scale` and `clock_resumes` are the discriminator for the reported "camera moves, nothing else
	# moves" state. Mouse look is the ONLY consumer in this project that is not delta-scaled, so a
	# stopped clock freezes movement and every attack phase while the camera keeps turning. A NON-ZERO
	# clock_resumes means something OUTSIDE the game stopped the clock and the layer had to put it back.
	_header_mouse.text = "mouse: %s   focus: %s   scale: %.3f   clock_resumes: %d   (Esc releases, click recaptures, F1 hides panel)" % [
		"CAPTURED" if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else "VISIBLE",
		"HELD" if input.is_input_active() else "LOST - input suspended",
		Engine.time_scale,
		input.clock_resumes,
	]
	_header_mobility.text = "SPRINT resolved: %s   mobility: %s   dodge buffer: %.2f" % [
		"ON" if input.is_sprinting() else "OFF",
		input.mobility_state_name(),
		input.buffer_time(GameActions.DODGE),
	]


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.78)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)

	column.add_child(_make_label(
		"CASCADIA - INPUT FOUNDATION", _table_width(), TEXT_HEADER
	))
	_header_move = _make_label("", _table_width(), TEXT_DIM)
	column.add_child(_header_move)
	_header_mouse = _make_label("", _table_width(), TEXT_DIM)
	column.add_child(_header_mouse)
	_header_mobility = _make_label("", _table_width(), TEXT_DIM)
	column.add_child(_header_mobility)

	for group_name in GameActions.GROUPS:
		var group_label := _make_label(str(group_name), _table_width(), TEXT_HEADER)
		column.add_child(group_label)
		for action in GameActions.GROUPS[group_name]:
			column.add_child(_build_row(action))


func _build_row(action: StringName) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_make_label(String(action).to_upper(), NAME_WIDTH, TEXT_DIM))
	row.add_child(_make_label(_binding_label(action), BINDING_WIDTH, TEXT_DIM))
	var state := _make_label("-", STATE_WIDTH, TEXT_DIM)
	row.add_child(state)
	_rows.append({"action": action, "label": state})
	return row


func _update_rows(input: CascadiaInput) -> void:
	for entry in _rows:
		var action: StringName = entry["action"]
		var label: Label = entry["label"]
		var text := "-"
		var color := TEXT_DIM

		if not InputMap.has_action(action):
			text = "MISSING FROM INPUTMAP"
			color = TEXT_BAD
		elif GameActions.is_reserved(action):
			text = "reserved"
			color = TEXT_RESERVED
		else:
			if Input.is_action_just_pressed(action):
				text = "PRESSED"
				color = TEXT_FLASH
			elif Input.is_action_pressed(action):
				text = "held"
				color = TEXT_ACTIVE

			if action == GameActions.SPRINT and input != null and input.is_sprinting():
				text = "SPRINT RESOLVED ON"
				color = TEXT_GOOD
			elif action == GameActions.DODGE and input != null and input.buffer_time(action) > 0.0:
				text = "DODGE QUEUED"
				color = TEXT_FLASH

		label.text = text
		label.add_theme_color_override("font_color", color)


func _make_label(text: String, width: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	return label


## Readable summary of what a semantic action is currently bound to.
func _binding_label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "(unbound)"
	var parts: Array = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			parts.append(OS.get_keycode_string(code))
		elif event is InputEventMouseButton:
			parts.append("Mouse%d" % event.button_index)
		elif event is InputEventJoypadButton:
			parts.append("PadBtn%d" % event.button_index)
		elif event is InputEventJoypadMotion:
			parts.append("PadAxis%d %+.1f" % [event.axis, event.axis_value])
	return ", ".join(parts)


func _get_input() -> CascadiaInput:
	if _input == null:
		_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	return _input


## Width helper so the header spans the full table.
func _table_width() -> int:
	return NAME_WIDTH + BINDING_WIDTH + STATE_WIDTH
