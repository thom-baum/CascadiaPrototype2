class_name EnemyDeathPresentationDebug
extends Node3D
## Temporary defeat presentation for a capsule enemy (placeholder, not production).
##
## The counterpart of the player's death presentation, adapted to an enemy. The
## player gets a full-screen panel because the player is the camera's subject; an
## enemy needs something readable in the WORLD, from wherever the player happens to
## be standing. So this is a pose plus a world-space label:
##
##   - the enemy's capsule mesh is sunk and tipped over, and tinted a dead colour
##   - a billboarded "DEFEATED" label is raised above the body, so the defeated
##     state is legible from across the arena and not only up close
##
## It owns no state and decides nothing: EnemyDeathComponent is the authority, and
## this only represents what that component already says. It listens to the
## `defeated` signal so the change lands on the same frame the health reaches zero,
## and it also polls, so a state change can never be missed.
##
## There is NO restore path, and that is deliberate rather than unfinished: a
## defeated enemy stays defeated for the life of the arena (see the persistence note
## on EnemyDeathComponent).
##
## Placeholder presentation, NOT animation - the project still has no animation
## system. Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## How far the body tips over when defeated, in degrees.
const POSE_TILT := 82.0
## Height the tipped body is left at, in metres.
const POSE_HEIGHT := 0.16
## Colour the defeated body is tinted.
const TINT := Color(0.20, 0.17, 0.18, 1.0)
## Height of the label above the body's origin, in metres.
const LABEL_HEIGHT := 2.35
const LABEL_TEXT := "DEFEATED"
const LABEL_COLOR := Color(0.86, 0.30, 0.28, 1.0)

@export_group("Wiring")
## The enemy's death state. Defaults to a sibling named "Death".
@export var death_path: NodePath = NodePath("../Death")
## The body whose mesh is posed. Defaults to the parent body.
@export var body_path: NodePath

## Print the presentation transition. Diagnostic.
@export var debug_logging := false

var _death: Node
var _body: Node3D
var _mesh: MeshInstance3D
var _label: Label3D
var _posed := false
var _mesh_transform := Transform3D.IDENTITY
var _mesh_material: Material


func _ready() -> void:
	_build_label()
	_resolve()
	if _death != null and _death.has_signal("defeated"):
		if not _death.is_connected("defeated", _on_defeated):
			_death.connect("defeated", _on_defeated)


func _process(_delta: float) -> void:
	# The poll is the safety net; the signal is what makes it read on the frame the
	# enemy's health reaches zero.
	#
	# BOTH DIRECTIONS, and the second one is a DEFECT FIX. This adapter previously only ever
	# went one way: once an actor was posed as defeated, `_posed` stayed true for the life of
	# the instance and the label never came off. Milestone 10's load restores the world a
	# snapshot recorded, so an actor CAN go back to alive - and without this branch the
	# DEFEATED label would stay on screen over a living actor forever, which is exactly the
	# "defeated after a load" defect that was reported.
	#
	# Polled rather than driven by the signal, because `EnemyDeathComponent.restore_defeated()`
	# deliberately does NOT emit `defeated`: that signal pays Credits, so emitting it on a
	# restore would mint currency every time a save was loaded.
	if not _posed and _is_defeated():
		_apply_defeat_pose()
	elif _posed and not _is_defeated():
		_clear_defeat_pose()


# --- Queries ----------------------------------------------------------------

## True while the defeat presentation is actually being shown. Used by the enemy
## death probe, so "the enemy is visibly defeated" is checkable from output.
func is_showing() -> bool:
	return _posed


## The label's current text. Exposed so the probe can check the words, not only the
## boolean.
func status_text() -> String:
	if _label == null:
		return ""
	return _label.text


# --- Presentation -----------------------------------------------------------

func _on_defeated() -> void:
	_apply_defeat_pose()


func _apply_defeat_pose() -> void:
	if _posed:
		return
	_posed = true
	_resolve()
	if _mesh != null:
		# Remembered, not guessed: nothing reads the pose again, but a future
		# resurrect/reset would need the original values and this is where they are.
		_mesh_transform = _mesh.transform
		_mesh_material = _mesh.material_override
		var pose := _mesh_transform
		pose.basis = pose.basis.rotated(Vector3.RIGHT, deg_to_rad(POSE_TILT))
		pose.origin = Vector3(pose.origin.x, POSE_HEIGHT, pose.origin.z)
		_mesh.transform = pose
		# material_override and NOT material_overlay: the hit-feedback diagnostic owns
		# the overlay channel for its hit flash, so the two would otherwise write over
		# each other on the frame of a killing blow.
		_mesh.material_override = _make_defeated_material()
	if _label != null:
		_label.visible = true
	_log("defeat pose applied")


## Take the defeat pose back OFF: the exact inverse of _apply_defeat_pose(), and the reason
## the original transform and material were remembered rather than guessed.
##
## Restores the remembered mesh transform and material and hides the label. A no-op when the
## pose is not currently applied, so it is safe to poll every frame.
func _clear_defeat_pose() -> void:
	if not _posed:
		return
	_posed = false
	if _mesh != null:
		_mesh.transform = _mesh_transform
		_mesh.material_override = _mesh_material
	if _label != null:
		_label.visible = false
	_log("defeat pose CLEARED (actor is alive again)")


func _make_defeated_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = TINT
	material.roughness = 0.9
	return material


func _build_label() -> void:
	_label = Label3D.new()
	_label.name = "DefeatedLabel"
	_label.text = LABEL_TEXT
	_label.visible = false
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.pixel_size = 0.006
	_label.outline_size = 16
	_label.modulate = LABEL_COLOR
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	_label.position = Vector3(0.0, LABEL_HEIGHT, 0.0)
	add_child(_label)


# --- Resolution -------------------------------------------------------------

func _is_defeated() -> bool:
	_resolve()
	if _death == null:
		return false
	if not _death.has_method("is_defeated"):
		return false
	return bool(_death.call("is_defeated"))


func _resolve() -> void:
	if _body == null or not is_instance_valid(_body):
		_body = _resolve_body()
	if _death == null or not is_instance_valid(_death):
		if String(death_path).is_empty():
			_death = null
		else:
			_death = get_node_or_null(death_path)
	if _mesh == null or not is_instance_valid(_mesh):
		if _body != null:
			_mesh = _find_mesh(_body)


func _resolve_body() -> Node3D:
	if not String(body_path).is_empty():
		return get_node_or_null(body_path) as Node3D
	return get_parent() as Node3D


func _find_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found := _find_mesh(child)
		if found != null:
			return found
	return null


func _log(message: String) -> void:
	if debug_logging:
		print("[ENEMYDEATHPRES] %s: %s" % [name, message])
