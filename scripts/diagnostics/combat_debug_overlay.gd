class_name CombatDebugOverlay
extends CanvasLayer
## Diagnostic combat readout (Milestone 4).
##
## Milestone 4 could be BUILT and still not be VERIFIABLE: there was no health,
## damage, hit-confirmation or attack-phase display anywhere, so a player could
## swing the whole time and have no way to tell whether the attack reached
## anything or applied damage. This exists to close that gap.
##
## Shows:
##   - the attack phase (IDLE / STARTUP / ACTIVE / RECOVERY) with a progress bar
##     for the current phase, so the three-phase timeline is visible as it runs
##   - whether the damage window is open, which is only ever true on ACTIVE
##   - the player's health
##   - every damageable actor and its current health, in a stable sorted order
##   - a hit log naming the actor that was struck, and the row for that actor
##     lights up at the same moment, so a list entry is tied to a specific
##     object in the world rather than to a name that might be misread
##
## Everything is found through groups and relative paths, so this needs no
## exported NodePath and survives the scene being reorganised.
##
## PLACEMENT IS NOT DECIDED HERE. The panel joins the RESERVED SCREEN REGION
## `ScreenRegions.Region.BOTTOM_RIGHT_DIAGNOSTICS` and that region's VBoxContainer places it, packed
## to the BOTTOM of the region. This file used to re-derive the bottom-right corner itself on every
## frame from `get_viewport_rect()`, and the comment on that code said why: top-right "collides with
## the input overlay in the narrow docked viewport". That is the same magic-number dodge as the
## save/load panel's `offset_top = 62` - a corner picked by eye against one neighbour at one window
## size. The region replaces it: the combat panel and the input table now occupy different reserved
## columns, so they cannot collide at ANY viewport size, and the bottom-right corner is the region's
## bottom edge rather than arithmetic on the panel's own measured size.
##
## Toggled by the same action as the input overlay (F1), so one key clears all
## debug UI. Development tooling; listed in CASCADIA_DELETION_MANIFEST.md.

const TEXT_DIM := Color(0.62, 0.64, 0.68, 1.0)
const TEXT_HEADER := Color(0.85, 0.88, 0.95, 1.0)
const TEXT_ACTIVE := Color(1.0, 0.86, 0.28, 1.0)
const TEXT_GOOD := Color(0.45, 0.9, 0.5, 1.0)
const TEXT_BAD := Color(1.0, 0.4, 0.4, 1.0)
const TEXT_HIT := Color(1.0, 0.55, 0.35, 1.0)

const WIDTH := 246
const FONT_SIZE := 11
const BAR_WIDTH := 16
## How long a landed hit stays lit in the log and on its row.
const HIT_FLASH_TIME := 1.4
## Lines of hit history kept on screen. Deliberately short: the panel has to stay
## fully inside a short docked viewport.
const HIT_LOG_LINES := 3

var _panel: PanelContainer
var _phase_label: Label
var _window_label: Label
var _player_label: Label
var _actors_header: Label
var _hit_log: Label
var _actor_column: VBoxContainer

var _combat: PlayerCombat
var _player_health: HealthComponent
var _player_stamina: StaminaComponent
var _rows: Dictionary = {}
## Instance ids of the actor rows, in the order they are currently laid out.
var _row_order: Array = []
var _hits: Array = []
var _hit_flash := 0.0
## Instance id of a struck actor's HealthComponent -> seconds of highlight left.
var _row_flash: Dictionary = {}


func _ready() -> void:
	# The diagnostics band, shared with the input and save/load overlays: they cannot collide on one
	# layer because each owns a different RESERVED SCREEN REGION, and none of them is above the pause
	# overlay. The literal value on the CombatDebugOverlay node in main.tscn reads from this constant.
	layer = ScreenRegions.LAYER_DEBUG_PANELS
	_build_ui()
	_connect_hitbox()
	# NO `size_changed` HANDLER AND NO PER-FRAME CORNER MATHS. The panel is anchored to its reserved
	# region, and anchors follow the viewport on their own, so there is nothing left to re-derive when
	# a docked viewport is resized.


func _process(delta: float) -> void:
	var input := _get_input()
	if input != null and input.is_action_pressed_now(GameActions.TOGGLE_DEBUG_OVERLAY):
		_panel.visible = not _panel.visible

	_resolve()
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
	for id in _row_flash.keys():
		_row_flash[id] = maxf(0.0, float(_row_flash[id]) - delta)
	_update_attack()
	_update_actors()
	_update_hit_log()
	# Nothing to re-pin afterwards. The panel's height still changes as actor rows are discovered, but
	# it grows inside its region now: the VBoxContainer packs it against the region's BOTTOM edge, so
	# added rows extend upward instead of pushing the bottom of the panel off the screen.


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	# The reserved bottom-right diagnostics region owns this panel's geometry.
	var column_host := ScreenRegions.join(self, ScreenRegions.Region.BOTTOM_RIGHT_DIAGNOSTICS)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Right-aligned in the region and shrunk to its own text both ways, so the readout keeps its
	# designed width instead of stretching across the region.
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.06, 0.78)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	_panel.add_theme_stylebox_override("panel", style)
	# The region's container places this panel; this file never positions it.
	column_host.add_child(_panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(column)

	column.add_child(_make_label("CASCADIA - COMBAT", TEXT_HEADER))

	_phase_label = _make_label("phase -", TEXT_DIM)
	column.add_child(_phase_label)
	_window_label = _make_label("damage window -", TEXT_DIM)
	column.add_child(_window_label)
	_player_label = _make_label("player -", TEXT_DIM)
	column.add_child(_player_label)

	_actors_header = _make_label("DAMAGEABLE ACTORS", TEXT_HEADER)
	column.add_child(_actors_header)

	_actor_column = VBoxContainer.new()
	_actor_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_actor_column)

	column.add_child(_make_label("HIT LOG", TEXT_HEADER))
	_hit_log = _make_label("-", TEXT_HIT)
	_hit_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hit_log)

	# NO PRESET AND NO CORNER MATHS AFTER THE CONTENT EXISTS. Three traps used to be measured here:
	#   1. Presetting before the labels exist gave the panel a zero width and later growth pushed it off
	#      the RIGHT edge (unreadable).
	#   2. Without a grow direction the panel expanded toward the END of its axes as rows were added at
	#      runtime, pushing its bottom off the BOTTOM edge (the second clipping report).
	#   3. Top-right collides with the input overlay in the narrow docked viewport.
	# All three are now structural rather than tuned: the panel lives in the reserved bottom-right
	# region (so it cannot reach the input column), the region's right and bottom edges are anchors (so
	# growth cannot escape them), and the VBoxContainer packs it against the region's BOTTOM (so added
	# rows extend upward). Nothing here needs to be recomputed when the content or the window changes.


func _make_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2(WIDTH, 0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	return label


# --- Live readout -----------------------------------------------------------

func _update_attack() -> void:
	if _combat == null:
		_phase_label.text = "phase: no PlayerCombat in scene"
		_window_label.text = ""
		_player_label.text = ""
		return

	var phase := _combat.state_name()
	var remaining := _combat.phase_remaining()
	_phase_label.text = "phase %s  %.2fs left  %s" % [phase, remaining, "ATTACKING" if _combat.is_busy() else ""]
	_phase_label.add_theme_color_override(
		"font_color", TEXT_ACTIVE if phase == "ACTIVE" else TEXT_DIM)

	var open := _combat.hitbox_is_open()
	_window_label.text = "damage window %s" % ("OPEN" if open else "closed")
	_window_label.add_theme_color_override(
		"font_color", TEXT_HIT if open else TEXT_DIM)

	if _player_health == null:
		_player_label.text = "player: no Health"
	else:
		_player_label.text = "player %s %d/%d%s" % [
			_bar(_player_health.health_fraction()), int(_player_health.current_health),
			int(_player_health.max_health),
			"  DEAD" if _player_health.is_dead else ""]
		_player_label.add_theme_color_override(
			"font_color", TEXT_BAD if _player_health.is_dead else TEXT_DIM)

	if _player_stamina != null:
		_player_label.text += "\nstamina %s %d/%d" % [
			_bar(_player_stamina.fraction()), int(_player_stamina.current_stamina),
			int(_player_stamina.max_stamina)]

	# Milestone 9: the CARRIED Credits the loop earns. Read from the ledger every frame rather than
	# cached here, so this line can never disagree with the authority it is displaying. No ledger in
	# the tree simply means no line, so a scene without the economy keeps working unchanged.
	var ledger := CreditLedger.find_ledger(get_tree())
	if ledger != null:
		_player_label.text += "\ncarried credits %d" % ledger.get_credits()


## One row per damageable actor, created on first sighting and kept in a stable
## name-sorted order so the list does not reshuffle itself between frames.
func _update_actors() -> void:
	var entries: Array = []
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		# The player is shown in its own line above.
		if health == _player_health:
			continue
		entries.append(health)
	entries.sort_custom(func(a: HealthComponent, b: HealthComponent) -> bool:
		return _actor_name(a) < _actor_name(b))

	var ids: Array = []
	for health in entries:
		ids.append(health.get_instance_id())
	if ids != _row_order:
		_rebuild_rows(entries, ids)

	for health in entries:
		var id: int = health.get_instance_id()
		var label: Label = _rows.get(id)
		if label == null:
			continue
		label.text = "%-11s %s %d/%d%s  %s" % [
			_actor_name(health), _bar(health.health_fraction()),
			int(health.current_health), int(health.max_health),
			"  DEAD" if health.is_dead else "",
			_combat_flags(health)]
		var flashing := float(_row_flash.get(id, 0.0)) > 0.0
		var color := TEXT_DIM
		if health.is_dead:
			color = TEXT_BAD
		elif flashing:
			color = TEXT_HIT
		label.add_theme_color_override("font_color", color)


func _rebuild_rows(entries: Array, ids: Array) -> void:
	for child in _actor_column.get_children():
		_actor_column.remove_child(child)
		child.queue_free()
	_rows.clear()
	_row_order = ids
	for health in entries:
		var id: int = health.get_instance_id()
		var label := _make_label("", TEXT_DIM)
		_actor_column.add_child(label)
		_rows[id] = label
	# The row count changed, so the panel's size changed - and that is now entirely the region's
	# business. The panel is packed against the bottom of its band, so a taller list extends upward.


func _actor_name(health: HealthComponent) -> String:
	var owner := health.get_parent()
	if owner == null:
		return "?"
	return String(owner.name)


## The actor's combat-participant state, read through the ONE component that answers
## it, so the readout shows what the game actually believes about the actor rather
## than a guess reconstructed from health alone. An actor with no participant is
## labelled as such instead of being silently misrepresented.
func _combat_flags(health: HealthComponent) -> String:
	var owner := health.get_parent()
	if owner == null:
		return ""
	var participant := CombatParticipant.find_for(owner)
	if participant == null:
		return "[no participant]"
	return "[%s]" % participant.state_summary()


func _update_hit_log() -> void:
	if _hits.is_empty():
		_hit_log.text = "no hits yet"
		return
	_hit_log.text = "\n".join(_hits)
	_hit_log.add_theme_color_override(
		"font_color", TEXT_HIT if _hit_flash > 0.0 else TEXT_DIM)


func _bar(fraction: float) -> String:
	var filled := int(round(clampf(fraction, 0.0, 1.0) * float(BAR_WIDTH)))
	var out := "["
	for i in BAR_WIDTH:
		out += "#" if i < filled else "."
	out += "]"
	return out


# --- Hit confirmation -------------------------------------------------------

## Connects to the player's attack volume so a landed hit is reported on screen
## the moment it happens. This is the hit-confirmation the milestone lacked.
func _connect_hitbox() -> void:
	_resolve()
	if _combat == null:
		return
	var actor := _combat.get_parent()
	if actor == null:
		return
	var hitbox := actor.get_node_or_null("AttackHitbox") as HitboxComponent
	if hitbox == null:
		return
	if not hitbox.hit_landed.is_connected(_on_hit_landed):
		hitbox.hit_landed.connect(_on_hit_landed)


func _on_hit_landed(event: DamageEvent) -> void:
	_hit_flash = HIT_FLASH_TIME
	var target := "unknown"
	if event.victim != null:
		target = String(event.victim.name)
		# Light up the row for the actor that was actually struck, so the entry
		# in this list is tied to the object that lost health.
		var victim_health := event.victim.get_node_or_null("Health") as HealthComponent
		if victim_health != null:
			_row_flash[victim_health.get_instance_id()] = HIT_FLASH_TIME
	_hits.push_front("%s   -%.0f" % [target, event.amount])
	while _hits.size() > HIT_LOG_LINES:
		_hits.pop_back()


# --- Lookup -----------------------------------------------------------------

func _resolve() -> void:
	if _combat == null or not is_instance_valid(_combat):
		_combat = get_tree().get_first_node_in_group(
			PlayerCombat.GROUP_PLAYER_COMBAT) as PlayerCombat
	if _combat == null:
		return
	var actor := _combat.get_parent()
	if actor == null:
		return
	if _player_health == null or not is_instance_valid(_player_health):
		_player_health = actor.get_node_or_null("Health") as HealthComponent
		_player_stamina = actor.get_node_or_null("Stamina") as StaminaComponent


func _get_input() -> CascadiaInput:
	return get_tree().get_first_node_in_group(
		CascadiaInput.ACTION_GROUP) as CascadiaInput
