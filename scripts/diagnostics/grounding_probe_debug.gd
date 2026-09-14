class_name GroundingProbeDebug
extends Node3D
## Temporary diagnostic (not production): does every damageable actor actually
## stand on the surface beneath it?
##
## Why this exists: the test targets are placed by DIRECT TRANSFORM, and a
## StaticBody3D has no gravity, no floor detection and no floor snapping. Nothing
## grounds them, so a hard-coded Y silently sinks or floats an actor whenever the
## geometry underneath it changes. TargetA was moved into the step lane and kept
## its flat-ground Y (0.9), which put its 1.8 m cylinder 0.28 m INSIDE Step28,
## whose top surface is at 0.28.
##
## The player is unaffected because PlayerController applies gravity and calls
## move_and_slide(), which performs floor detection and floor snapping
## (floor_snap_length 0.4). The targets have no script at all, so they have none
## of that and are only ever correct by coincidence of the number typed into them.
##
## This measures, per actor, in real physics space:
##   - mesh vs collision alignment   (the visual and the collider must agree)
##   - collision vs surface gap      (the actor must REST on that surface)
##
## The surface is found with a downward ray that excludes the actor itself, so
## the result is measured against the real geometry rather than re-derived from
## the same hard-coded numbers that were wrong in the first place.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const SETTLE_FRAMES := 20
## Acceptable error, in metres, for both checks.
const TOLERANCE := 0.02

var _frame := 0
var _done := false
var _failures: Array = []


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_done = true
	_run()


func _run() -> void:
	print("[GROUND] --- actor grounding audit (measured) ---")
	var space := get_world_3d().direct_space_state
	var actors := get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE)
	print("[GROUND] damageable actors found: %d" % actors.size())
	if actors.is_empty():
		_fail("no damageable actors found")
		_report()
		return
	for node in actors:
		var health := node as HealthComponent
		if health == null:
			continue
		var actor := health.get_parent() as Node3D
		if actor == null:
			continue
		_audit(actor, space)
	_report()


func _audit(actor: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var label := String(actor.name)
	var collision_y := _lowest_y(actor, true)
	var mesh_y := _lowest_y(actor, false)
	if is_inf(collision_y) or is_inf(mesh_y):
		_fail("%s: no collision shape or no visual mesh found" % label)
		return

	var surface_y := _surface_below(actor, space)
	if is_nan(surface_y):
		_fail("%s: no surface found below" % label)
		return

	var mesh_vs_collision := absf(mesh_y - collision_y)
	# Positive means floating above the surface, negative means sunk into it.
	var collision_vs_surface := surface_y - collision_y

	print("[GROUND] %-12s surface=%.3f  collision=%.3f  mesh=%.3f  mesh-vs-collision=%.3f  float(+)/sunk(-)=%.3f" % [
		label, surface_y, collision_y, mesh_y, mesh_vs_collision, collision_vs_surface])

	_expect(mesh_vs_collision <= TOLERANCE,
		"%s: mesh aligned with collision (%.3f)" % [label, mesh_vs_collision])
	_expect(absf(collision_vs_surface) <= TOLERANCE,
		"%s: rests on the surface, not floating or sunk (%.3f)" % [label, collision_vs_surface])


## Lowest world Y of the actor's first CollisionShape3D (want_collision) or
## MeshInstance3D. Returns -INF when neither is found.
func _lowest_y(actor: Node3D, want_collision: bool) -> float:
	for child in actor.get_children():
		if want_collision and child is CollisionShape3D:
			var shape_node := child as CollisionShape3D
			var half := _half_height(shape_node.shape)
			if half >= 0.0:
				return shape_node.global_position.y - half
		elif not want_collision and child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			var half := _half_height(mesh_node.mesh)
			if half >= 0.0:
				return mesh_node.global_position.y - half
	return -INF


## Half-height of a primitive shape or mesh. -1.0 when unsupported.
func _half_height(resource: Resource) -> float:
	if resource is CylinderShape3D:
		return (resource as CylinderShape3D).height * 0.5
	if resource is CapsuleShape3D:
		return (resource as CapsuleShape3D).height * 0.5
	if resource is BoxShape3D:
		return (resource as BoxShape3D).size.y * 0.5
	if resource is SphereShape3D:
		return (resource as SphereShape3D).radius
	if resource is CylinderMesh:
		return (resource as CylinderMesh).height * 0.5
	if resource is CapsuleMesh:
		return (resource as CapsuleMesh).height * 0.5
	if resource is BoxMesh:
		return (resource as BoxMesh).size.y * 0.5
	if resource is SphereMesh:
		return (resource as SphereMesh).height * 0.5
	return -1.0


## World Y of the topmost surface under the actor. NAN when nothing is hit.
## The actor is excluded, otherwise the ray hits the actor's own collider.
func _surface_below(actor: Node3D, space: PhysicsDirectSpaceState3D) -> float:
	var from := actor.global_position + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0)
	query.collision_mask = GameLayers.WORLD
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return float(hit["position"].y)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[GROUND]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[GROUND]   FAIL  %s" % label)


func _report() -> void:
	print("[GROUND] --- summary ---")
	if _failures.is_empty():
		print("[GROUND] RESULT: ALL CHECKS PASSED")
	else:
		print("[GROUND] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
