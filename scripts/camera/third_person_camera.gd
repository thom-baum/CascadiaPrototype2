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

@onready var yaw_node: Node3D = $CameraYaw
@onready var pitch_node: Node3D = $CameraYaw/CameraPitch

var _pivot: Node3D
var _input: CascadiaInput
var _yaw := 0.0
var _pitch := -12.0


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

	yaw_node.rotation.y = deg_to_rad(_yaw)
	pitch_node.rotation.x = deg_to_rad(_pitch)

	_follow_pivot(delta)


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
