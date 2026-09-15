class_name GameHUD
extends CanvasLayer
## Milestone 13 - the minimal gameplay HUD.
##
## WHAT THIS SHOWS: carried Credits, the player's Health and the player's Stamina. Three values,
## three existing owners, and this file owns NONE of them.
##
##   Credits   CreditLedger.get_credits()          signal credits_changed(current, delta)
##   Health    HealthComponent.current_health      signal health_changed(current, maximum)
##   Stamina   StaminaComponent.current_stamina    signal stamina_changed(current, maximum)
##
## NO DUPLICATED STATE - and that is a hard rule of this milestone, not a style preference. This file
## declares no `credits`, no `health`, no `stamina`, no `is_locked` and no `current_target`. The only
## thing it stores is the TEXT IT IS ALREADY DISPLAYING, in the Labels themselves. That text is a
## rendering of an owner's value, it is never read back as the value, and no decision anywhere in the
## project is made from it. A load, a damage event or a balance change therefore cannot leave the HUD
## showing a stale number - the number is not kept here in the first place.
##
## RE-READING, NOT POLLING FOR CORRECTNESS. The three owner signals are connected, so the labels are
## rewritten when an owner reports a change, and GameStateSave.game_loaded is connected too. Every one
## of those connections is CONNECT_DEFERRED, which is deliberate: these owners emit from inside their
## own change, and a HUD that read them again on the same call stack would be reading a half-applied
## change. Deferred means "read it once the owner has finished", which is exactly when a display
## should look. The per-frame pass is a FALLBACK for an owner that could not be resolved or whose
## signal could not be connected (a scene with no ledger, a ledger added later); it stops mattering
## entirely once the connections exist.
##
## MOUSE FILTER: every Control built here is MOUSE_FILTER_IGNORE, explicitly, on each node. Cascadia's
## light and heavy attacks are bound to MOUSE BUTTONS, so a status panel that consumes clicks silently
## eats attacks. Mouse filter is PER CONTROL and is not inherited, so the filter is set on the panel,
## the margins, the boxes, the labels and the bars rather than relying on a parent. This is also what
## keeps `focus_input_routing_probe_debug._controls_that_steal_gameplay_mouse()` clean, because that
## check enumerates every VISIBLE Control that could take a click at the centre of the viewport.
##
## This is deliberately NOT the combat debug overlay. That one is development tooling with a debug
## toggle; this HUD is part of the shipped game and is visible whenever the game runs.
##
## PLACEMENT IS NOT DECIDED HERE. Both readouts join a RESERVED SCREEN REGION from `ScreenRegions`,
## the project's single layout authority: the credits readout joins the shared TOP-RIGHT STACK (which
## the save/load diagnostic is stacked into as well, directly below it, separated by that stack's
## Container separation) and health/stamina join the RESERVED VITALS region that no debug panel is
## anchored into. Nothing in this file sets a `position`, an `offset` or an anchor value, and no
## per-frame maths measures the viewport - before this pass the credits panel carried
## `offset_left = -220 / offset_top = 10` and the vitals panel `offset_left = 14 / offset_top = -104`,
## which is exactly the hand-tuned arithmetic that a resized window outgrows.

@export_group("Wiring")
## The ledger that owns the carried balance. Leave EMPTY to resolve it through the ledger's own group,
## which is how the rest of the project finds it.
@export var ledger_path: NodePath
## The player-controlled actor whose Health and Stamina are shown. Leave EMPTY to resolve it through
## the player-actor group.
@export var player_path: NodePath

## The three labels, public because they ARE the display and a probe reads them as the measured
## surface. Nothing in this file reads them back as a value.
var credits_label: Label
var health_label: Label
var stamina_label: Label
var health_bar: ProgressBar
var stamina_bar: ProgressBar

## How many times displayed text has been written. Diagnostic: it is the measurement that lets a probe
## prove the DISPLAY changed because a real value changed, without waiting a guessed number of frames.
var display_writes := 0
## Which owner values the last write was derived from, for the same reason. Read-only report.
var last_write_note := "nothing yet"

var _ledger: CreditLedger
var _actor: Node3D
var _health: HealthComponent
var _stamina: StaminaComponent
var _save: GameStateSave
## True once every owner signal this HUD needs is connected, so the per-frame fallback can stand down.
var _connected := false


func _ready() -> void:
	# The shipped HUD sits ABOVE the debug panels and BELOW the pause overlay. The literal value is
	# repeated on the GameHUD node in main.tscn and read here from the one authority, so the saved
	# scene text and the running code can be read against each other.
	layer = ScreenRegions.LAYER_GAME_HUD
	_build_ui()
	_resolve()
	_refresh()


func _process(_delta: float) -> void:
	if _ledger == null or not is_instance_valid(_ledger):
		_resolve()
	_sync_connections()
	if not _connected:
		_refresh()


# --- Reading the owners -----------------------------------------------------

## Rewrite the display from the owners. Called on every owner signal and, while a signal could not be
## connected, once a frame.
func _refresh() -> void:
	var wrote := false
	var notes: Array = []

	if _ledger != null and is_instance_valid(_ledger):
		credits_label.text = "CREDITS  %d" % _ledger.get_credits()
		wrote = true
		notes.append("credits=%d" % _ledger.get_credits())
	else:
		credits_label.text = "CREDITS  --"

	if _health != null and is_instance_valid(_health):
		health_bar.max_value = _health.max_health
		health_bar.value = _health.current_health
		health_label.text = "HEALTH  %d / %d" % [int(_health.current_health), int(_health.max_health)]
		wrote = true
		notes.append("health=%.1f" % _health.current_health)
	else:
		health_bar.value = 0.0
		health_label.text = "HEALTH  --"

	if _stamina != null and is_instance_valid(_stamina):
		stamina_bar.max_value = _stamina.max_stamina
		stamina_bar.value = _stamina.current_stamina
		stamina_label.text = "STAMINA  %d / %d" % [int(_stamina.current_stamina),
			int(_stamina.max_stamina)]
		wrote = true
		notes.append("stamina=%.1f" % _stamina.current_stamina)
	else:
		stamina_bar.value = 0.0
		stamina_label.text = "STAMINA  --"

	if wrote:
		display_writes += 1
		last_write_note = " ".join(PackedStringArray(notes))


## Connect every owner signal this HUD listens to, once. Deferred, so the read happens after the owner
## has finished the change it is reporting; the receiving method takes no arguments on purpose, so it
## works for signals of any arity and for the ones with none.
func _sync_connections() -> void:
	if _connected:
		return
	var missing: Array = []
	if _ledger != null and is_instance_valid(_ledger):
		_connect_signal(_ledger, &"credits_changed")
	else:
		missing.append("ledger")
	if _health != null and is_instance_valid(_health):
		_connect_signal(_health, &"health_changed")
	else:
		missing.append("health")
	if _stamina != null and is_instance_valid(_stamina):
		_connect_signal(_stamina, &"stamina_changed")
	else:
		missing.append("stamina")
	if _save != null and is_instance_valid(_save):
		# A load restores through the owners, so their own signals do the work. This one is connected
		# as well because a load is the moment a stale number would be most visible, and re-reading
		# once more costs nothing.
		_connect_signal(_save, &"game_loaded")
	var was_connected := _connected
	_connected = missing.is_empty()

	# ONE REFRESH THE MOMENT THE CONNECTIONS LAND, and this is a real defect fix, not belt-and-braces.
	# Godot runs `_ready()` in tree order, and in `main.tscn` this HUD is a SIBLING that comes BEFORE
	# `TestEnvironment`. So this node's `_ready()` runs first and reads the owners' raw defaults - the
	# player's `HealthComponent` only sets `current_health = max_health` in ITS OWN `_ready()`, which
	# has not run yet. That `reset()` emits `health_changed` into a signal nobody is connected to, this
	# class then connects and (correctly) stands its per-frame fallback down, and the display keeps the
	# stale `0 / 100` it read a moment too early until the next damage event - measured on screen, with
	# the combat overlay in the same frame reading `100/100`.
	#
	# Reading once here closes the window: by the first frame every owner has been readied, so this
	# refresh sees the real value. It is deliberately gated on the transition into `_connected` so it
	# runs exactly once, and it does not replace the signal connections - it covers the gap before them.
	if _connected and not was_connected:
		_refresh()


func _connect_signal(emitter: Object, signal_name: StringName) -> void:
	var target := Callable(self, "_on_owner_changed")
	if emitter.is_connected(signal_name, target):
		return
	emitter.connect(signal_name, target, CONNECT_DEFERRED)


## Any owner change. The arguments are deliberately ignored: this HUD re-reads the owners rather than
## trusting a copy of what they just said.
func _on_owner_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	_refresh()


# --- Resolution -------------------------------------------------------------

## Resolve each owner through the path given, or through the group its own module joins. Nothing here
## hard-codes a scene layout: the HUD is a reader, so it asks the owners where they are.
func _resolve() -> void:
	if not String(ledger_path).is_empty():
		_ledger = get_node_or_null(ledger_path) as CreditLedger
	if _ledger == null:
		_ledger = CreditLedger.find_ledger(get_tree())

	if not String(player_path).is_empty():
		_actor = get_node_or_null(player_path) as Node3D
	if _actor == null:
		_actor = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	if _actor != null:
		_health = _actor.get_node_or_null("Health") as HealthComponent
		_stamina = _actor.get_node_or_null("Stamina") as StaminaComponent

	if _save == null or not is_instance_valid(_save):
		_save = GameStateSave.find_save(get_tree())


# --- UI construction --------------------------------------------------------

## Build the HUD in code rather than in a scene: one control surface, no second file to keep in sync
## with the wiring above, and every mouse filter visible in the same place as the reason for it.
##
## There is deliberately NO full-rect root here any more. A full-rect Control is a hit-test surface
## across the whole screen for no reason at all, and a root that is only there to hold two panels in
## opposite corners is a layout decision this file has no business making. Each panel joins its own
## RESERVED SCREEN REGION instead, and the region owns the geometry.
func _build_ui() -> void:
	_build_credits()
	_build_vitals()


## Carried Credits: the first slot of the shared TOP-RIGHT STACK. The save/load diagnostic joins the
## same stack and lands directly beneath this panel, so the space between the two comes from the
## stack's Container separation rather than from an offset tuned by eye at one window size.
func _build_credits() -> void:
	var column := ScreenRegions.join(self, ScreenRegions.Region.TOP_RIGHT_STACK)

	var panel := PanelContainer.new()
	panel.name = "CreditsPanel"
	# The region sets the anchors and the width; this panel only says how it shrinks inside them. It is
	# right-aligned in its slot so the number stays in the corner instead of stretching to the region
	# edge, and vertical shrinking is what makes the panel exactly the height of its own text - which
	# is what lets the stack separate it from the panel below by a real gap.
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	credits_label = Label.new()
	credits_label.name = "CreditsLabel"
	credits_label.text = "CREDITS  --"
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_label.add_theme_font_size_override("font_size", 20)
	credits_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45, 1))
	credits_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(credits_label)


## Health and Stamina: one panel in the RESERVED VITALS region, the bottom strip of the centre band.
##
## THE REGION IS RESERVED. No debug panel is anchored into it - that is the point of moving this panel
## out of the bottom-left corner, where a debug panel could have claimed the same strip. The panel
## centres itself in its region and hangs from the bottom of it, so it grows UPWARD from the screen
## edge when a row is added rather than pushing its own bottom off the screen.
##
## Two bars plus two exact readouts, because the bar is what reads at a glance and the numbers are
## what a playtest report can quote.
func _build_vitals() -> void:
	var column := ScreenRegions.join(self, ScreenRegions.Region.VITALS)

	var panel := PanelContainer.new()
	panel.name = "VitalsPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 6)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(rows)

	var health_row := _build_row(rows, "HealthRow", "HEALTH", Color(0.85, 0.26, 0.24, 1))
	health_label = health_row[0]
	health_bar = health_row[1]

	var stamina_row := _build_row(rows, "StaminaRow", "STAMINA", Color(0.36, 0.72, 0.42, 1))
	stamina_label = stamina_row[0]
	stamina_bar = stamina_row[1]


## One label plus one bar, stacked. Returns [label, bar] so the caller keeps the handles it reads.
func _build_row(parent: Control, row_name: String, title: String, fill: Color) -> Array:
	var column := VBoxContainer.new()
	column.name = row_name
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)

	var label := Label.new()
	label.name = "%sLabel" % title.capitalize()
	label.text = "%s  --" % title
	label.add_theme_font_size_override("font_size", 16)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)

	var bar := ProgressBar.new()
	bar.name = "%sBar" % title.capitalize()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(280.0, 16.0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", _style(fill))
	bar.add_theme_stylebox_override("background", _style(Color(0.08, 0.09, 0.11, 0.85)))
	column.add_child(bar)

	return [label, bar]


func _style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	return box
