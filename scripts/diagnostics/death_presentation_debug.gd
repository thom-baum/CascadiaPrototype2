class_name DeathPresentationDebug
extends CanvasLayer
## Prototype death presentation (temporary diagnostic, not production).
##
## A death the player cannot SEE is not a death the player can react to, and
## Cascadia has no animation system yet, so this is the honest prototype answer:
## a controlled death pose on the actor, a colour change, and an unambiguous
## on-screen message for the duration of the dead state.
##
## It decides nothing. It reads DeathComponent.is_dead() every frame and adapts -
## gameplay owns the state and this follows it, exactly the way the combat and
## input overlays follow the systems they display. If no DeathComponent exists in
## the scene it shows nothing at all.
##
## What it does:
##
##   - tips the actor's mesh forward and sinks it, then restores its EXACT
##     original transform and material on reset, so no residue is left behind
##   - tints the mesh, so "dead" is distinguishable from "alive" even when the
##     capsule is seen edge-on and the tip is hard to read
##   - shows "YOU DIED" with the seconds until the automatic reset, and the
##     RESTART hint, so the reset path is legible instead of feeling like a stall
##
## It deliberately does NOT create an animation, a ragdoll, a ragdoll-shaped
## effect, a death camera or a transition. It is a readable state change.
##
## Development presentation; recorded in CASCADIA_DELETION_MANIFEST.md.

## Degrees the death pose tips the actor's mesh forward.
const DEATH_POSE_TILT := 78.0
## Local Y the death pose lowers the mesh to, so the body reads as down rather
## than standing upright with a strange tilt.
const DEATH_POSE_HEIGHT := 0.18
## Tint applied to the actor's mesh while dead.
const DEATH_TINT := Color(0.36, 0.30, 0.34, 1.0)

const TEXT_DEAD := Color(0.95, 0.28, 0.24, 1.0)
const TEXT_HINT := Color(0.80, 0.82, 0.86, 1.0)
const FONT_SIZE_TITLE := 34
const FONT_SIZE_HINT := 15
## Margin kept between the panel and the viewport edge.
const EDGE_MARGIN := 16

## Every presentation joins this group, so tooling can find it without a
## hard-coded scene path - the same convention as stamina, dodge, parry and the
## test attacker.
const GROUP_DEATH_PRESENTATION := &"death_presentation"

var _panel: PanelContainer
var _title: Label
var _hint: Label

var _death: DeathComponent
var _mesh: MeshInstance3D
var _posed := false
var _mesh_transform := Transform3D.IDENTITY
var _mesh_material: Material
var _connected := false


func _ready() -> void:
	add_to_group(GROUP_DEATH_PRESENTATION)
	_build_ui()
	get_viewport().size_changed.connect(_reclamp)
	_reclamp()


func _process(_delta: float) -> void:
	_ensure_connected()
	var dead := _is_actor_dead()
	if dead != _posed:
		if dead:
			_apply_death_pose()
		else:
			_restore_living_pose()
	_apply_message(dead)
	_reclamp()


## Listen to the death itself rather than waiting for the next frame to notice it.
## The poll above is what restores the living pose after a reset; this is what makes
## the death readable on the same frame the health reaches zero.
func _ensure_connected() -> void:
	if _connected:
		return
	var death := _resolve_death()
	if death == null:
		return
	_connected = true
	death.death_started.connect(_on_death_started)


func _on_death_started() -> void:
	_apply_death_pose()
	_apply_message(true)
	_reclamp()


# --- Queries ----------------------------------------------------------------

## True while the actor this presentation follows is dead.
func _is_actor_dead() -> bool:
	var death := _resolve_death()
	return death != null and death.is_dead()


## True while the death pose and message are actually being shown. Used by the
## death probe so "the player is visibly dead" is checkable from output.
func is_showing() -> bool:
	return _posed


## The words currently on screen. Exposed so the death probe can check the message
## itself rather than only the boolean that drives it.
func status_text() -> String:
	if _title == null:
		return ""
	return "%s - %s" % [_title.text, _hint.text]


## Seconds until the automatic reset, for the countdown. 0 when nothing is due.
func _seconds_until_reset() -> float:
	var death := _resolve_death()
	if death == null:
		return 0.0
	return death.time_until_reset()


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.03, 0.82)
	style.border_color = Color(0.65, 0.16, 0.14, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(column)

	_title = _make_label("YOU DIED", FONT_SIZE_TITLE, TEXT_DEAD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_hint = _make_label("", FONT_SIZE_HINT, TEXT_HINT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_hint)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	return label


## Keeps the message centred horizontally and inside the viewport, recomputed
## every frame: the panel's size depends on its text, and a docked viewport can be
## resized at any moment.
func _reclamp() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var viewport := _panel.get_viewport_rect().size
	var content := _panel.get_combined_minimum_size()
	_panel.size = content
	_panel.position = Vector2(
		maxf(EDGE_MARGIN, (viewport.x - content.x) * 0.5),
		viewport.y * 0.30)


func _apply_message(dead: bool) -> void:
	_panel.visible = dead
	if not dead:
		return
	_title.text = "YOU DIED"
	_hint.text = "respawning in %.1f s   -   press %s to revive now" % [
		_seconds_until_reset(), _restart_binding_label()]


## The RESTART key as the project actually binds it, so the hint can never drift
## from the binding. Falls back to plain text if the action is unbound.
func _restart_binding_label() -> String:
	if not InputMap.has_action(GameActions.RESTART):
		return "RESTART"
	for event in InputMap.action_get_events(GameActions.RESTART):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
			return OS.get_keycode_string(code)
	return "RESTART"


# --- Pose -------------------------------------------------------------------

## Tip the actor's mesh forward and sink it. Everything changed is remembered
## first, so the restoration is exact rather than a second guess about what the
## scene looked like.
func _apply_death_pose() -> void:
	_posed = true
	var actor := _resolve_actor()
	if actor == null:
		return
	_mesh = _find_mesh(actor)
	if _mesh == null:
		push_warning("DeathPresentationDebug: no MeshInstance3D under %s" % actor.name)
		return
	_mesh_transform = _mesh.transform
	_mesh_material = _mesh.material_override
	var pose := _mesh_transform
	pose.basis = pose.basis.rotated(Vector3.RIGHT, deg_to_rad(DEATH_POSE_TILT))
	pose.origin = Vector3(pose.origin.x, DEATH_POSE_HEIGHT, pose.origin.z)
	_mesh.transform = pose
	# material_override and NOT material_overlay: the hit-feedback diagnostic owns
	# the overlay channel for its hit flash, and a killing blow would otherwise have
	# the two writing over each other on the same frame.
	_mesh.material_override = _make_death_material()


func _restore_living_pose() -> void:
	if _mesh != null and is_instance_valid(_mesh):
		_mesh.transform = _mesh_transform
		_mesh.material_override = _mesh_material
	_mesh = null
	_posed = false


func _make_death_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = DEATH_TINT
	material.roughness = 0.9
	return material


# --- Resolution -------------------------------------------------------------

func _resolve_death() -> DeathComponent:
	if _death == null or not is_instance_valid(_death):
		_death = get_tree().get_first_node_in_group(DeathComponent.GROUP_DEATH) as DeathComponent
	return _death


func _resolve_actor() -> Node3D:
	var death := _resolve_death()
	if death == null:
		return null
	var owner := death.get_parent()
	return owner as Node3D


func _find_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
