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
## PLACEMENT IS NOT DECIDED HERE. The panel joins the RESERVED SCREEN REGION
## `ScreenRegions.Region.INPUT_DIAGNOSTICS` - the left column of the shared layout - and the region's
## VBoxContainer places it. It used to carry a bare `_panel.position = Vector2(16, 16)` with no anchors
## at all, which is correct at exactly one window size. Anchors do not need a resize handler, and this
## file still has none.
##
## THE TABLE REFLOWS AND IS BOUNDED, which is the one genuinely hard layout problem in this prototype.
## 58 rows in a single column is ~928 px tall and the region is 531 px at the shortest logical height,
## so the tail ran off the bottom of the screen with nothing on screen saying so. Two mechanisms fix
## it, both living in ScreenRegions so the next panel gets them without copying any of this:
##
##   REFLOW  the groups are split into two CONTIGUOUS halves and laid out by
##           `ScreenRegions.adaptive_columns()`, so they sit side by side while they fit (~464 px of
##           rows instead of ~928) and the second wraps BELOW the first when they do not.
##   BOUND   the panel is wrapped by `ScreenRegions.bound_to_region()`, so the region's height is the
##           limit and the panel's bottom edge stays inside the viewport at every window size.
##
## This is development tooling. Listed in CASCADIA_DELETION_MANIFEST.md.

const TEXT_DIM := Color(0.62, 0.64, 0.68, 1.0)
const TEXT_ACTIVE := Color(0.95, 0.95, 0.95, 1.0)
const TEXT_FLASH := Color(1.0, 0.86, 0.28, 1.0)
const TEXT_GOOD := Color(0.45, 0.9, 0.5, 1.0)
const TEXT_BAD := Color(1.0, 0.4, 0.4, 1.0)
const TEXT_RESERVED := Color(0.62, 0.5, 0.78, 1.0)
const TEXT_HEADER := Color(0.85, 0.88, 0.95, 1.0)

## Compact column widths. The overlay shares the viewport with the running game, so it stays as narrow
## as the longest label allows - and that now matters twice over, because TWO of these blocks plus a
## separation is what has to fit inside the left region for the table to reflow into two columns.
const NAME_WIDTH := 104
const BINDING_WIDTH := 132
const STATE_WIDTH := 80
const FONT_SIZE := 11
## THE REFLOW BUDGET IS MEASURED, NOT DECLARED: two blocks plus `ScreenRegions.ADAPTIVE_SEPARATION`
## is what has to fit inside the left region, and BOTH the blocks' width and the region's width are read
## at runtime. A declared block width would drift the moment an action or binding string grew, and one
## that under-estimates is exactly what makes the two-column layout unreachable - measured history on
## this panel, where the flow was handed less width than its own blocks needed.
## Vertical space between two rows, and between a group label and its first row. 0 ON PURPOSE: with 58
## rows this is the single biggest lever on the table's height, and Godot's default 4 px of separation
## cost 232 px of panel, which is a large part of why the bottom used to leave the screen. The FONT
## SIZE is deliberately NOT reduced, so rows stay legible - the space BETWEEN them is what was trimmed.
const ROW_SEPARATION := 0
## The panel's own style content padding, left + right. It sits INSIDE the region, so it is part of the
## width two columns have to fit into rather than free space above them.
const PANEL_PADDING := 20.0

var _input: CascadiaInput
var _panel: PanelContainer
var _header_move: Label
var _header_mouse: Label
var _header_mobility: Label
var _rows: Array = []


func _ready() -> void:
	# The diagnostics band, shared with the combat and save/load overlays. They cannot collide on one
	# layer because each owns a different RESERVED SCREEN REGION, and all three stay below the pause
	# overlay. The literal value on the InputDebugOverlay node in main.tscn is read from this constant.
	layer = ScreenRegions.LAYER_DEBUG_PANELS
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
	# `peek_look_delta()`, NOT `get_look_delta()`. This overlay is a CanvasLayer ordered BEFORE the
	# world in `main.tscn`, so consuming the delta here made the DISPLAY the only consumer and the
	# camera always read ZERO - mouse look was dead while movement, attacks and dodge all worked.
	var look := input.peek_look_delta()
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
	# Anchored, not positioned: the panel joins the shared left-column region and that region's
	# container decides where the table sits. There is no `position` and no viewport arithmetic left in
	# this file - the old bare `Vector2(16, 16)` was the only thing placing this panel, and it did not
	# move when the window did.
	var column_host := ScreenRegions.join(self, ScreenRegions.Region.INPUT_DIAGNOSTICS)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# FILL horizontally so the adaptive flow container inside is given the REGION's width to wrap
	# against. Shrinking to the content instead is what starved the two-column layout: the flow was
	# handed the single-column minimum and wrapped every time, at every window size (MEASURED - see
	# `ScreenRegions.bound_to_region`). The height still shrinks to the content, so a short table never
	# stretches into a tall empty box; the bound comes from the region, not from this flag.
	_panel.size_flags_horizontal = Control.SIZE_FILL
	_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.78)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	_panel.add_theme_stylebox_override("panel", style)
	# The region's container owns this panel now; this file never places it. The panel is BOUNDED to
	# the region so its bottom edge cannot leave the viewport - see ScreenRegions.bound_to_region().
	column_host.add_child(ScreenRegions.bound_to_region(_panel))

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", ROW_SEPARATION)
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

	# THE TABLE, SPLIT DOWN THE MIDDLE so it can REFLOW. The live status lines above stay full width and
	# un-split on purpose: they are one reading of global state, not rows of the table.
	var flow := ScreenRegions.adaptive_columns()
	flow.add_theme_constant_override("h_separation", int(ScreenRegions.ADAPTIVE_SEPARATION))
	# THE REFLOW DECISION IS TAKEN FROM THE REGION'S MEASURED WIDTH, and the table's minimum width is
	# then SET from that decision. Leaving the decision to the flow container's own width is what made
	# the two-column layout UNREACHABLE: a ScrollContainer does not stretch its child here (MEASURED -
	# the panel reported 389 px inside a 736 px bound), so the flow only ever saw the single-column
	# minimum and wrapped at every window size. Stating the width makes two columns genuinely reachable
	# on a wide window, and keeps the one-column fallback honest on a narrow one.
	var halves := _split_groups()
	var block_a := _build_block(halves[0])
	var block_b := _build_block(halves[1])
	flow.add_child(block_a)
	flow.add_child(block_b)
	# THE DECISION IS DEFERRED ONE FRAME, and that is deliberate. A block's real width comes from the
	# longest action name and the longest binding string, so it can only be read from the Controls -
	# but reading it in THIS frame returns a STALE value: MEASURED, `get_combined_minimum_size()`
	# answered 433 px for a block that is really 360 px wide, and the reflow decision was then taken on
	# a number that did not describe the table at all. One frame later the same call is correct.
	_apply_reflow.call_deferred(flow, block_a, block_b)
	column.add_child(flow)


## The action groups, split into two CONTIGUOUS halves balanced by ROW COUNT rather than by group
## count, so the two columns come out a similar height without reordering anything: the early groups
## stay early, and the reading order is column one top to bottom, then column two.
func _split_groups() -> Array:
	var names: Array = GameActions.GROUPS.keys()
	var total := 0
	for group_name in names:
		total += _rows_in(group_name)
	var half := int(ceil(float(total) * 0.5))
	var left: Array = []
	var right: Array = []
	var filled := 0
	for group_name in names:
		if filled < half:
			left.append(group_name)
			filled += _rows_in(group_name)
		else:
			right.append(group_name)
	return [left, right]


## How many rows one group contributes: its own header label, plus one row per action.
func _rows_in(group_name) -> int:
	var entries: Array = GameActions.GROUPS[group_name]
	return entries.size() + 1


## One column of the split table: a group label followed by that group's action rows.
##
## THE BLOCK STATES ITS OWN MINIMUM WIDTH, and that is what lets the adaptive container decide whether
## two of them fit side by side. Without it the HFlowContainer would measure only the widest single
## label and wrap against that, and the reflow point would move with the text rather than with the table.
func _build_block(groups: Array) -> Control:
	var block := VBoxContainer.new()
	block.name = "Block"
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", ROW_SEPARATION)
	block.custom_minimum_size = Vector2(_table_width(), 0)
	for group_name in groups:
		block.add_child(_make_label(str(group_name), _table_width(), TEXT_HEADER))
		for action in GameActions.GROUPS[group_name]:
			block.add_child(_build_row(action))
	return block


## Print the reflow decision and the two measurements behind it, so why the table chose one column or
## two can be READ rather than inferred from the positions afterwards.
func _say_layout(region: Vector2, pair: float, widest: float) -> void:
	print("[INPUTPANEL] region %.0f px wide | widest block %.0f px | two blocks + gap need %.0f px -> %s"
		% [region.x, widest, pair, "TWO COLUMNS" if region.x >= pair else "ONE COLUMN (narrow reflow)"])


## Decide ONE column or TWO from the blocks' REAL width, measured AFTER the first layout pass.
##
## THE FLOW IS GIVEN THE WHOLE AVAILABLE WIDTH, and that is the fix for the last defect in this
## panel. An HFlowContainer wraps against the width it HOLDS, not the width its children would like,
## so stating only `pair` left it stacked even when the pair fitted: the container was 660 px wide with
## two 360 px blocks inside it and wrapped them, because 728 > 660. It is handed the region's inner
## width instead, the blocks then fit side by side on their own, and the fallback is honest - when the
## pair genuinely cannot fit, the flow is left at one block's width and wraps.
func _apply_reflow(flow: HFlowContainer, block_a: Control, block_b: Control) -> void:
	if not is_instance_valid(flow) or not is_instance_valid(block_a) or not is_instance_valid(block_b):
		return
	var widest := maxf(block_a.get_combined_minimum_size().x, block_b.get_combined_minimum_size().x)
	var pair := widest * 2.0 + ScreenRegions.ADAPTIVE_SEPARATION
	var region := ScreenRegions.region_pixel_size(self, ScreenRegions.Region.INPUT_DIAGNOSTICS)
	# The style content margins (10 left + 10 right) sit INSIDE the region, so they are part of the
	# budget; leaving them out would over-state the width available to the two blocks by 20 px.
	var available := region.x - PANEL_PADDING
	flow.custom_minimum_size = Vector2(available if available >= pair else widest, 0.0)
	_say_layout(region, pair, widest)


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
