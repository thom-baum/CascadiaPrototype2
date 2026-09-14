class_name ActorProbeDebug
extends Node3D
## Temporary Milestone 3 diagnostic (not production).
##
## Proves that an actor's PHYSICAL body and its COMBAT volumes are genuinely
## separate concerns, by measuring rather than asserting:
##
##   1. a physical body driven hard at the actor is actually BLOCKED by it, and
##   2. a combat hitbox still damages that same actor while sitting inside the
##      body's own volume, because combat volumes never take part in physical
##      collision.
##
## The second half is the real content of this milestone. It is easy to have a
## hitbox that works only because nothing is standing in the way; this checks the
## opposite case deliberately.
##
## It carries its own carrier body and its own neutral hitbox. It does not read
## input and is not part of the main scene.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const APPROACH_FRAMES := 90
const DRIVE_SPEED := 5.0
const START_GAP := 2.5
## Combined capsule radii are 0.4 + 0.4, so a blocked carrier should settle near
## 0.8 m from the actor's centre. The bar is set a little below that.
const MIN_BLOCKED_GAP := 0.6

var _carrier: CharacterBody3D
var _hitbox: HitboxComponent
var _dummy: Node3D
var _dummy_body: CollisionObject3D
var _dummy_health: HealthComponent
var _dummy_hurtbox: HurtboxComponent

var _frame := 0
var _phase := 0
var _phase_frame := 0
var _done := false
var _failures: Array = []

var _approach_end_z := 0.0
var _final_gap := 0.0
var _passed_through := false
var _applied_before_combat := 0
var _damage_signals := 0


func _ready() -> void:
	# The arena ships a live test attacker for human playtesting. A probe measures
	# one system deterministically, so any ambient hostile is stood down here.
	# Group-based and duck-typed on purpose: this must not reference the attacker
	# class, whose newly added members are invisible until the class cache refreshes.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	_build_carrier()
	_build_hitbox()
	_resolve_dummy()
	if _dummy == null:
		return
	_audit_layers()


func _build_carrier() -> void:
	_carrier = CharacterBody3D.new()
	_carrier.name = "Carrier"
	# A real physical actor body: ACTOR layer, and it collides with the world and
	# with other actors. This is what must be blocked by the dummy.
	_carrier.collision_layer = GameLayers.ACTOR
	_carrier.collision_mask = GameLayers.WORLD | GameLayers.ACTOR
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.92, 0.0)
	_carrier.add_child(shape)
	add_child(_carrier)


func _build_hitbox() -> void:
	_hitbox = HitboxComponent.new()
	_hitbox.name = "TestHitbox"
	_hitbox.damage = 25.0
	_hitbox.debug_logging = true
	add_child(_hitbox)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	shape.shape = box
	_hitbox.add_child(shape)


func _resolve_dummy() -> void:
	var main := get_node_or_null("../Main")
	if main == null:
		_fail("main scene not found")
		return
	_dummy = main.get_node_or_null("TestEnvironment/DummyActor") as Node3D
	if _dummy == null:
		_fail("dummy actor not found at TestEnvironment/DummyActor")
		return
	_dummy_body = _dummy as CollisionObject3D
	_dummy_health = _dummy.get_node_or_null("Health") as HealthComponent
	_dummy_hurtbox = _dummy.get_node_or_null("Hurtbox") as HurtboxComponent
	if _dummy_health == null:
		_fail("dummy has no HealthComponent")
	if _dummy_hurtbox == null:
		_fail("dummy has no HurtboxComponent")
	if _dummy_health != null:
		_dummy_health.damaged.connect(_on_damaged)


## The static half of the proof: what lives on which layer, and what type.
func _audit_layers() -> void:
	print("[ACTORPROBE] --- layer audit ---")
	print("[ACTORPROBE] dummy body    class=%s layer=%d mask=%d" % [
		_dummy_body.get_class(), _dummy_body.collision_layer, _dummy_body.collision_mask])
	print("[ACTORPROBE] dummy hurtbox is Area3D=%s layer=%d mask=%d" % [
		str(_dummy_hurtbox is Area3D), _dummy_hurtbox.collision_layer, _dummy_hurtbox.collision_mask])
	print("[ACTORPROBE] carrier       layer=%d mask=%d" % [
		_carrier.collision_layer, _carrier.collision_mask])
	print("[ACTORPROBE] test hitbox   layer=%d mask=%d" % [
		_hitbox.collision_layer, _hitbox.collision_mask])

	_expect(_dummy_body.collision_layer == GameLayers.ACTOR,
		"dummy physical body is on ACTOR")
	_expect(_dummy_body.collision_layer & GameLayers.combat_layers() == 0,
		"dummy physical body is on NO combat layer")
	_expect(_dummy_hurtbox.collision_layer == GameLayers.HURTBOX,
		"dummy hurtbox is on HURTBOX")
	_expect(_dummy_hurtbox.collision_mask == 0,
		"dummy hurtbox masks nothing (it can never detect or push)")
	_expect(_dummy_hurtbox is Area3D,
		"dummy hurtbox is an Area3D, not a physics body")
	_expect(_hitbox.collision_mask == GameLayers.HURTBOX,
		"hitbox masks HURTBOX")
	_expect(_hitbox.collision_mask & (GameLayers.WORLD | GameLayers.ACTOR) == 0,
		"hitbox cannot see the physical world or actor bodies")


func _physics_process(_delta: float) -> void:
	if _done or _dummy == null:
		return
	_frame += 1
	if _frame < 20:
		return
	_phase_frame += 1
	if _phase_frame < 3:
		return
	_phase_frame = 0
	_run_phase()


func _run_phase() -> void:
	match _phase:
		0:
			print("[ACTORPROBE] --- P1 physical body is blocked by the actor ---")
			_run_approach()
		1:
			_expect(not _passed_through,
				"carrier did not pass through the actor's physical body")
			_expect(_final_gap >= MIN_BLOCKED_GAP,
				"carrier stopped at a real separation (gap %.3f >= %.2f)"
					% [_final_gap, MIN_BLOCKED_GAP])
			_expect(_final_gap < 2.0,
				"carrier actually reached the actor (gap %.3f < 2.0)" % _final_gap)
		2:
			print("[ACTORPROBE] --- P2 move a hitbox INSIDE the actor's body volume ---")
			_applied_before_combat = _dummy_health.applied_count
			# Park the hitbox on the actor's centre. The carrier could never get
			# here - it was just blocked 0.8 m out - which is the whole point.
			_hitbox.global_position = _dummy.global_position + Vector3(0.0, 0.92, 0.0)
			var inside := (
				_hitbox.global_position - (_dummy.global_position + Vector3(0.0, 0.92, 0.0))
			).length()
			print("[ACTORPROBE] hitbox offset from body centre = %.3f m (carrier stopped %.3f m out)"
				% [inside, _final_gap])
		3:
			_hitbox.activate()
		4:
			print("[ACTORPROBE] --- P3 combat damage landed through the physical body ---")
			var gained := _dummy_health.applied_count - _applied_before_combat
			_expect(gained == 1,
				"exactly 1 application from a hitbox inside the body volume (got %d)" % gained)
			_expect(_damage_signals == 1,
				"exactly 1 damaged signal on the actor (got %d)" % _damage_signals)
			_expect(_dummy_health.current_health == 75.0,
				"actor health 100 -> 75 (got %.1f)" % _dummy_health.current_health)
			_expect(not _dummy_health.is_dead, "actor still alive after one hit")
		5:
			print("[ACTORPROBE] --- P4 held window must not re-apply ---")
			_expect(_dummy_health.applied_count - _applied_before_combat == 1,
				"still exactly 1 application while the window is held open")
			_hitbox.deactivate()
			_finish()
		_:
			_finish()
	_phase += 1


## Drive the carrier straight at the actor for a fixed number of frames and record
## where it actually ends up. Manual frames are deliberate: physical blocking is
## immediate, so this is deterministic and does not need real elapsed time.
func _run_approach() -> void:
	var dummy_z := _dummy.global_position.z
	_carrier.global_position = Vector3(_dummy.global_position.x, 0.05, dummy_z + START_GAP)
	_carrier.velocity = Vector3.ZERO

	for _i in APPROACH_FRAMES:
		_carrier.velocity = Vector3(0.0, -0.5, -DRIVE_SPEED)
		_carrier.move_and_slide()

	_approach_end_z = _carrier.global_position.z
	_final_gap = _approach_end_z - dummy_z
	_passed_through = _approach_end_z < dummy_z
	print("[ACTORPROBE] drove %.0f frames at %.1f m/s: start z=%.3f end z=%.3f actor z=%.3f gap=%.3f" % [
		float(APPROACH_FRAMES), DRIVE_SPEED,
		dummy_z + START_GAP, _approach_end_z, dummy_z, _final_gap])


func _on_damaged(_event: DamageEvent, current: float, _maximum: float) -> void:
	_damage_signals += 1
	print("[ACTORPROBE]   actor damaged signal #%d -> %.1f" % [_damage_signals, current])


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[ACTORPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ACTORPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[ACTORPROBE] --- summary ---")
	print("[ACTORPROBE] final actor health=%.1f applied=%d" % [
		_dummy_health.current_health, _dummy_health.applied_count])
	if _failures.is_empty():
		print("[ACTORPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[ACTORPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
