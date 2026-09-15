class_name EnemyDeathPresentationDebug
extends Node3D
## Temporary defeat presentation for a capsule enemy (placeholder, not production).
##
## The counterpart of the player's death presentation, adapted to an enemy. The
## player gets a full-screen panel because the player is the camera's subject; an
## enemy needs something readable in the WORLD, from wherever the player happens to
## be standing. So this is a pose plus a world-space label:
##
##   - the enemy's body mesh is sunk and tipped over, and tinted a dead colour
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
## --- DEFEAT-POSE OWNERSHIP (Milestone 22, section 8AB) -----------------------
##
## ONE system owns an enemy's FINAL DEFEAT POSE, and this component DECLARES which one
## it is taking. Two things could plausibly write that pose - this component, which
## writes the body MESH's transform and material_override, and an animated VISUAL,
## which writes the SKELETON's bones - and "both, a bit" is not a result, because the
## pose would then depend on which one happened to run last.
##
##   pose_body_meshes = true   (default, unchanged behaviour)
##       THIS COMPONENT owns the pose. It writes the body mesh's transform and
##       material_override, exactly as it always has, and NO clip poses the defeat.
##       Correct for an enemy whose only presentation is its primitive capsule.
##
##   pose_body_meshes = false
##       the ANIMATED VISUAL owns the pose. The `dead` slot's clip supplies the fall
##       of the body, and this component writes NO transform and NO material at all -
##       it keeps only what a skeleton cannot say, the world-space DEFEATED label.
##       The capsule that used to be the body's presentation is hidden by the scene,
##       because a capsule lying inside an imported character's chest is a duplicate
##       read rather than a fallback.
##
## THE LABEL IS NOT A POSE. Both modes still raise the DEFEATED label, because the
## label is legibility from across the arena rather than a claim about the body. That
## is why ownership can be handed over without also handing over the defeat signal,
## and why `is_showing()` keeps its meaning for `enemy_death_probe_debug` and for
## every save/load restore probe that reads it.
##
## MATERIALS ARE NOT SPLIT FROM POSE. `pose_body_meshes` covers `material_override` as
## well, and that is the safe direction: on a rigged enemy the body MeshInstance3D is
## the RIGGED MODEL INSTANCE, whose own transform is the model's authored facing
## correction and whose material the model needs. Overwriting either to tint a pose
## the skeleton has taken over would corrupt the visual rather than complement it.
##
## WHAT "OWNS" MEANS, measurably: exactly one of the two systems writes the pose and
## the other writes nothing at all. There is deliberately no third mode where both
## write. `owns_body_pose()` and `pose_owner_name()` report the declaration, so a
## probe asserts the contract instead of inferring it from a transform that a
## skeleton-driven pose and a transform-driven pose would report alike.
##
## WHY THE RESULT CANNOT DEPEND ON UPDATE ORDER. With `true`, nothing animates the
## defeat, so there is no second writer to race. With `false`, the pose writer does
## not exist for this actor at all. Neither mode resolves the same pose twice, which
## is why the outcome is identical whichever system runs first.
##
## Placeholder presentation for a capsule, NOT animation. Recorded in
## CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## How far the body tips over when defeated, in degrees. INERT when an animated visual
## owns the pose - left in place rather than deleted so the mesh-owning mode is intact.
const POSE_TILT := 82.0
## Height the tipped body is left at, in metres. Inert under visual ownership, as above.
const POSE_HEIGHT := 0.16
## Colour the defeated body is tinted. Inert under visual ownership, as above.
const TINT := Color(0.20, 0.17, 0.18, 1.0)
## Height of the label above the body's origin, in metres.
const LABEL_HEIGHT := 2.35
const LABEL_TEXT := "DEFEATED"
const LABEL_COLOR := Color(0.86, 0.30, 0.28, 1.0)

## The group an animated visual joins, spelled as a LITERAL for the reason the adapter and the
## probes spell it literally: referring to the visual class here would make this file depend on a
## `class_name` being in the global registry, and a registration that has not caught up yet fails
## to PARSE rather than to resolve.
const GROUP_VISUAL_DRIVER := &"visual_driver"

@export_group("Pose ownership")
## WHETHER THIS COMPONENT IS THE DEFEAT-POSE OWNER (Milestone 22, section 8AB).
##
## TRUE (default) is the original behaviour and is correct for an enemy whose only presentation is
## its primitive mesh: this component sinks, tips and tints the body mesh. FALSE hands the pose to
## the enemy's ANIMATED VISUAL, which supplies it from the `dead` slot's clip; this component then
## writes nothing to the mesh at all and only raises the label.
##
## A rigged model instance must NEVER be named by `body_path` while this is TRUE: its own child
## transform is the model's authored facing correction, and overwriting it would flip the
## character around and replace the material the model needs.
##
## See the ownership section in the class notes above.
@export var pose_body_meshes := true

@export_group("Wiring")
## The enemy's death state. Defaults to a sibling named "Death".
@export var death_path: NodePath = NodePath("../Death")
## The body whose mesh is posed. Defaults to the parent body.
@export var body_path: NodePath
## The animated visual that owns the pose when `pose_body_meshes` is FALSE. Left EMPTY, the
## visual is found the way the adapter finds it - the actor's own child in the `visual_driver`
## group - so a scene does not have to hand-wire the pair.
@export var visual_path: NodePath

## Print the presentation transition. Diagnostic.
@export var debug_logging := false

var _death: Node
var _body: Node3D
var _mesh: MeshInstance3D
var _label: Label3D
var _visual: Node
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


## THE OWNERSHIP DECLARATION, readable from outside. Names the ONE system that writes the
## defeated enemy's pose, so a probe can ASSERT the contract rather than infer it from a
## transform that a skeleton-driven pose and a transform-driven pose would report alike.
##
## A declaration with no reader is a comment, which is why this exists: the integration probe
## asserts exactly one owner is named AND that the named owner is the one that actually moved.
func pose_owner_name() -> String:
	if pose_body_meshes:
		return "EnemyDeathPresentationDebug(mesh+material)"
	var visual := _resolve_visual()
	if visual == null:
		return "(VISUAL OWNER DECLARED BUT NONE PRESENT)"
	return "visual:%s" % String(visual.name)


## Whether THIS component is the pose owner. False means a visual driver owns the pose and
## this component deliberately writes no transform and no material.
func owns_body_pose() -> bool:
	return pose_body_meshes


## Whether this component writes the body mesh's transform and material on THIS frame. The
## same declaration as `owns_body_pose()`, phrased for a reader asking about the write itself.
func writes_body_mesh() -> bool:
	return pose_body_meshes and _mesh != null


# --- Presentation -----------------------------------------------------------

func _on_defeated() -> void:
	_apply_defeat_pose()


func _apply_defeat_pose() -> void:
	if _posed:
		return
	_posed = true
	_resolve()
	# ONLY THE DECLARED OWNER WRITES. With an animated visual owning the pose, this
	# component still reports the defeat (is_showing, the label) but writes NOT ONE
	# transform or material - which is what makes the result order-independent rather
	# than two writers racing for the last word on the same frame.
	if pose_body_meshes and _mesh != null:
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
	# Guarded for the same reason the write is guarded: with the visual owning the pose,
	# `_mesh_transform` was never captured, so an unguarded restore would write an
	# IDENTITY transform onto a mesh this component does not own.
	if pose_body_meshes and _mesh != null:
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


## The visual that owns the pose, resolved by authored path when there is one, otherwise from
## the body's own children - the same `visual_driver` group the adapter scans. Returns null
## when the actor wears no visual, which `pose_owner_name()` reports rather than hides.
func _resolve_visual() -> Node:
	if _visual != null and is_instance_valid(_visual):
		return _visual
	if not String(visual_path).is_empty():
		_visual = get_node_or_null(visual_path)
	if _visual == null and _body != null and is_instance_valid(_body):
		for child in _body.get_children():
			var node := child as Node
			if node != null and node.is_in_group(GROUP_VISUAL_DRIVER):
				_visual = node
				break
	return _visual


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
