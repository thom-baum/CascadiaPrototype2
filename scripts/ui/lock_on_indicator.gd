class_name LockOnIndicator
extends Node3D
## Milestone 13 - the lock-on indicator.
##
## WHAT THIS IS: a world-anchored marker that sits on the CURRENT lock-on target. It is hidden while
## no lock is held, appears on that target when a lock is taken, follows the lock when the target is
## cycled, and disappears for every one of the four release causes.
##
## THE LOCK STATE AND THE TARGET ARE NOT KEPT HERE. They are read from the module that owns them:
##
##   TargetingComponent.is_locked()          whether a lock is held
##   TargetingComponent.get_current_target() which actor is locked
##   signal target_acquired(target)          a lock was taken
##   signal target_released(target, reason)  a lock ended, with its cause named
##   signal target_changed(target)           the lock moved to another target (a cycle)
##
## The signals DRIVE the marker, so the indicator reacts to the event rather than inferring one, and
## `_process` RE-READS the owner as a reconciliation pass so a missed or re-ordered event cannot leave
## a marker on a target that is no longer locked. Reading the owner every frame is not a second copy
## of the lock state - it is the same single authority being asked again. There is deliberately no
## `_locked`, no `_current_target` and no `is_valid()` here; the four release causes are not
## re-derived either, because `TargetingComponent.invalidation_reason()` is their only owner.
##
## WHY A 3D MARKER AND NOT A SCREEN-SPACE PANEL: this project's focus-routing check enumerates every
## VISIBLE Control under every CanvasLayer and fails if one with a non-IGNORE mouse filter overlaps
## the centre of the viewport - correctly, because a Control there can silently eat a mouse-button
## attack. A 3D marker has no Control in the tree at all, so it cannot take a click no matter where
## the target stands, including dead centre of the screen. It is also the honest presentation for
## "this actor is the locked one": the marker stays on the actor as the camera frames it.
##
## The marker reads through walls on purpose (`no_depth_test`). It is a UI affordance for a locked
## target, and an indicator that vanishes the moment the target passes behind a railing would read as
## a broken lock rather than as occlusion.

## The group TargetingComponent joins. Resolution goes through it, so no scene path is hard-coded.
const GROUP_TARGETING := &"targeting"

@export_group("Wiring")
## The targeting module to read. Leave EMPTY to resolve it through its own group.
@export var targeting_path: NodePath

@export_group("Marker")
## How far above the target's origin the marker floats, in metres.
@export var height_offset := 1.75
## Radius of the marker ring, in metres.
@export var marker_radius := 0.3
## Colour of the marker.
@export var marker_color := Color(1.0, 0.68, 0.18, 1)

## How many times a target has been MARKED (a marker appeared on it). A cycle to a different actor
## counts once, so a probe can tell "followed the cycle" from "stayed where it was".
var marks := 0
## How many times the marker has been cleared because no lock was held. Diagnostic, same reason.
var hides := 0
## The actor the marker is currently on, or null. This is the marker's own DRAWING state - which node
## it is parented to - not a copy of the lock; it is derived from the owner every time it changes.
var marked: Node3D

var ring: MeshInstance3D
var name_label: Label3D

var _targeting: TargetingComponent
var _connected := false


func _ready() -> void:
	_build_marker()
	_resolve()
	_sync_connections()
	_sync_from_owner()


func _process(_delta: float) -> void:
	if _targeting == null or not is_instance_valid(_targeting):
		_resolve()
		_sync_connections()
	_sync_from_owner()


# --- Reading the owner ------------------------------------------------------

## Ask the targeting module what it holds and place, move or clear the marker to match. The one place
## the marker's position is decided, so the signal path and the per-frame reconciliation cannot drift.
func _sync_from_owner() -> void:
	var targeting := _get_targeting()
	if targeting == null or not targeting.is_locked():
		_clear()
		return
	var target: Node3D = targeting.get_current_target()
	if target == null or not is_instance_valid(target):
		_clear()
		return
	if target != marked:
		marked = target
		marks += 1
		if name_label != null:
			name_label.text = String(target.name)
	visible = true
	global_position = target.global_position + Vector3(0.0, height_offset, 0.0)


## Hide the marker and forget which actor it was on.
func _clear() -> void:
	if marked != null:
		marked = null
		hides += 1
	if visible:
		visible = false


## Connect the three targeting signals, once. Deferred for the same reason the HUD defers: the module
## emits from inside its own state change, so the marker is moved after that change has landed.
func _sync_connections() -> void:
	if _connected:
		return
	var targeting := _get_targeting()
	if targeting == null:
		return
	for signal_name in [&"target_acquired", &"target_released", &"target_changed"]:
		var target := Callable(self, "_on_targeting_changed")
		if not targeting.is_connected(signal_name, target):
			targeting.connect(signal_name, target, CONNECT_DEFERRED)
	_connected = true


func _on_targeting_changed(_a: Variant = null, _b: Variant = null) -> void:
	_sync_from_owner()


## Whether the marker is currently drawing on a target. Read-only report for a probe or a debug
## readout: it answers "is something marked", not "is a lock held" - the lock state is the module's
## business and is never cached here.
func is_marking() -> bool:
	return marked != null and is_instance_valid(marked)


# --- Resolution -------------------------------------------------------------

func _resolve() -> void:
	if not String(targeting_path).is_empty():
		_targeting = get_node_or_null(targeting_path) as TargetingComponent
	if _targeting == null and get_tree() != null:
		_targeting = get_tree().get_first_node_in_group(GROUP_TARGETING) as TargetingComponent


func _get_targeting() -> TargetingComponent:
	if _targeting == null or not is_instance_valid(_targeting):
		_resolve()
	return _targeting


# --- Marker construction ----------------------------------------------------

func _build_marker() -> void:
	visible = false

	var mesh := TorusMesh.new()
	mesh.inner_radius = marker_radius * 0.78
	mesh.outer_radius = marker_radius
	mesh.rings = 24
	mesh.ring_segments = 6

	var material := StandardMaterial3D.new()
	material.albedo_color = marker_color
	# UNLIT AND ALWAYS VISIBLE ON PURPOSE: this is a UI affordance drawn in the world, so the arena's
	# key light must not decide whether the player can see what they are locked onto, and the marker
	# must not disappear behind the target's own body.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.disable_receive_shadows = true

	ring = MeshInstance3D.new()
	ring.name = "Ring"
	ring.mesh = mesh
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	name_label = Label3D.new()
	name_label.name = "TargetName"
	name_label.text = ""
	name_label.font_size = 48
	name_label.pixel_size = 0.0035
	name_label.outline_size = 12
	name_label.modulate = marker_color
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.position = Vector3(0.0, marker_radius + 0.24, 0.0)
	name_label.visible = true
	add_child(name_label)
