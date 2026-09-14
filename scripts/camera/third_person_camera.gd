class_name ThirdPersonCamera
extends Node3D
## Minimal third-person orbit rig (Milestone 0 scaffolding, formalised in
## Milestone 2).
##
## Hierarchy this expects:
##
##   CameraRig (this script)
##   +- CameraYaw          <- horizontal orbit only, roll is always zero
##      +- CameraPitch     <- vertical orbit only, clamped
##         +- SpringArm3D  <- pushes the camera back, collides with WORLD layer
##            +- Camera3D
##
## The rig follows the pivot, it does not drive it. Camera behaviour never
## determines gameplay state.
##
## The SpringArm3D mask is GameLayers.WORLD only, so actors on GameLayers.ACTOR
## never shove the camera around.

@export var pivot_path: NodePath
@export var height_offset := 1.6
@export var follow_smoothing := 12.0
## Degrees of rotation per pixel-equivalent unit of look delta.
@export var yaw_sensitivity := 0.22
@export var pitch_sensitivity := 0.22
@export var pitch_degrees := -12.0
@export var pitch_min := -60.0
@export var pitch_max := 25.0

## How quickly the rig yaws onto a locked target, in the same units as `follow_smoothing` (higher is
## tighter). Only used while a lock is held; with no lock this rig behaves exactly as before.
@export var lock_yaw_smoothing := 12.0

@onready var yaw_node: Node3D = $CameraYaw
@onready var pitch_node: Node3D = $CameraYaw/CameraPitch

var _pivot: Node3D
var _input: CascadiaInput
var _targeting: TargetingComponent
var _yaw := 0.0
var _pitch := -12.0
var _framing_lock := false


func _ready() -> void:
	_pitch = clampf(pitch_degrees, pitch_min, pitch_max)
	yaw_node.rotation.y = deg_to_rad(_yaw)
	pitch_node.rotation.x = deg_to_rad(_pitch)
	_pivot = _resolve_pivot()


func _process(delta: float) -> void:
	var input := _get_input()
	if input != null:
		var look := input.get_look_delta()
		if look != Vector2.ZERO:
			_yaw -= look.x * yaw_sensitivity
			_pitch = clampf(_pitch - look.y * pitch_sensitivity, pitch_min, pitch_max)

	_frame_locked_target(delta)

	yaw_node.rotation.y = deg_to_rad(_yaw)
	pitch_node.rotation.x = deg_to_rad(_pitch)

	_follow_pivot(delta)


## Yaw onto the locked target while a lock is held (Milestone 12).
##
## The rig READS targeting state and never drives it: it asks the module whether a lock is held and
## who the target is, and it changes nothing about the lock. With no lock - or no targeting module at
## all - this returns immediately and the rig behaves exactly as it did before, so an optional module
## can never change how the camera works in its absence.
##
## ONLY `_yaw` is written here. Pitch is untouched, so lock-on never changes how steeply the rig
## looks, and roll stays zero by construction: this rig has two orbit axes and nothing writes a third
## rotation component. The SpringArm3D still collides with the world layer, so the camera is still
## pushed in by geometry rather than clipping through it.
##
## The desired yaw is the horizontal direction from the PIVOT to the target, expressed in this rig's
## convention - yaw 0 looks along -Z, growing positive to the LEFT - which is why the Z and X terms
## are negated. The target's height is dropped: this is the horizontal orbit, and vertical framing is
## the pitch's business.
func _frame_locked_target(delta: float) -> void:
	_framing_lock = false
	var targeting := _get_targeting()
	if targeting == null or not targeting.is_locked():
		return
	var target: Node3D = targeting.get_current_target()
	if target == null or not is_instance_valid(target):
		return
	var pivot := _resolve_pivot()
	if pivot == null:
		return
	var to_target := target.global_position - pivot.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		# Directly overhead: there is no horizontal direction to frame, so the existing yaw stands
		# rather than snapping to a value derived from a zero-length vector.
		return
	_framing_lock = true
	var desired := rad_to_deg(atan2(-to_target.x, -to_target.z))
	# Shortest arc, so a target behind the rig swings the short way around instead of unwinding.
	var offset := wrapf(desired - _yaw, -180.0, 180.0)
	_yaw = wrapf(_yaw + offset * (1.0 - exp(-lock_yaw_smoothing * delta)), -180.0, 180.0)


## True while this rig is actively framing a locked target. Read-only report for tooling; it is not a
## gameplay state and nothing branches on it.
func is_framing_lock() -> bool:
	return _framing_lock


func _follow_pivot(delta: float) -> void:
	if _pivot == null:
		_pivot = _resolve_pivot()
		if _pivot == null:
			return
	var target := _pivot.global_position + Vector3(0.0, height_offset, 0.0)
	global_position = global_position.lerp(target, 1.0 - exp(-follow_smoothing * delta))


# --- Orientation, for a snapshot -------------------------------------------------

## The rig's current horizontal orbit, in degrees. Read when a snapshot is taken.
func current_yaw_degrees() -> float:
	return _yaw


## The rig's current vertical orbit, in degrees. Read when a snapshot is taken.
func current_pitch_degrees() -> float:
	return _pitch


## Put the orbit back to a recorded orientation (snapshot restore).
##
## Owned here rather than written from outside: the rig is the only thing that knows how its two
## orbit nodes relate to `_yaw`/`_pitch`, so it is the only thing that can put them back. The pitch
## is re-clamped to this rig's own limits, so a corrupt save cannot pitch the camera past its range.
func restore_orientation(yaw_degrees: float, pitch_degrees: float) -> void:
	_yaw = yaw_degrees
	_pitch = clampf(pitch_degrees, pitch_min, pitch_max)
	yaw_node.rotation.y = deg_to_rad(_yaw)
	pitch_node.rotation.x = deg_to_rad(_pitch)


func _resolve_pivot() -> Node3D:
	if pivot_path.is_empty():
		return null
	return get_node_or_null(pivot_path) as Node3D


func _get_input() -> CascadiaInput:
	if _input == null:
		_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	return _input


## The targeting module, if the scene has one. Resolved through the module's own group rather than a
## scene path, because the module is optional: a scene without it gives this rig a null here and the
## camera behaves exactly as it did before targeting existed.
func _get_targeting() -> TargetingComponent:
	if _targeting == null or not is_instance_valid(_targeting):
		_targeting = get_tree().get_first_node_in_group(TargetingComponent.GROUP_TARGETING) as TargetingComponent
	return _targeting
