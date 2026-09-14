class_name DamageProbeDebug
extends CharacterBody3D
## Temporary Milestone 2 diagnostic (not production).
##
## Drives the damage plumbing through a fixed scripted sequence and prints what
## actually happened, so each Milestone 2 claim is checkable from output rather
## than taken on trust. It exists because a still frame cannot prove that damage
## applies exactly once, or that death happens at zero health.
##
## It carries its own neutral HitboxComponent, parked overlapping a target's
## hurtbox, and opens and closes windows on a frame schedule. It does NOT read
## input and is NOT part of the main scene.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const STEP_FRAMES := 10
const MAX_DEATH_WINDOWS := 12

var _hitbox: HitboxComponent
var _target: Node3D
var _health: HealthComponent
var _hurtbox: HurtboxComponent

var _frame := 0
var _phase := 0
var _phase_frame := 0
var _done := false

var _damaged_signals := 0
var _died_signals := 0
var _death_windows := 0
var _failures: Array = []

## The player is a separate damageable actor with its own Health/Hurtbox. Proving
## it takes damage exercises the same plumbing through a second actor, which is
## what catches a hurtbox whose Health lookup by name silently failed.
var _player_health: HealthComponent
var _player_damaged := 0


func _ready() -> void:
	# The arena ships a live test attacker for human playtesting. A probe measures
	# one system deterministically, so any ambient hostile is stood down here.
	# Group-based and duck-typed on purpose: this must not reference the attacker
	# class, whose newly added members are invisible until the class cache refreshes.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	# A pure carrier: this body must never take part in physics or combat itself.
	collision_layer = 0
	collision_mask = 0
	_build_hitbox()
	_resolve_target()
	if _health == null:
		return
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_audit_layers()


func _build_hitbox() -> void:
	_hitbox = HitboxComponent.new()
	_hitbox.name = "TestHitbox"
	_hitbox.damage = 25.0
	_hitbox.debug_logging = true
	add_child(_hitbox)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 3.0, 3.0)
	shape.shape = box
	_hitbox.add_child(shape)


func _resolve_target() -> void:
	var node: Node = null
	var main := get_node_or_null("../Main")
	if main != null:
		node = main.get_node_or_null("TestEnvironment/Targets/TargetB")
	if node == null:
		node = get_node_or_null("../Main/TestEnvironment/Targets/TargetA")
	_target = node as Node3D
	if _target == null:
		_fail("target not found")
		return

	_health = _target.get_node_or_null("Health") as HealthComponent
	_hurtbox = _target.get_node_or_null("Hurtbox") as HurtboxComponent
	if _health == null:
		_fail("target has no HealthComponent")
	if _hurtbox == null:
		_fail("target has no HurtboxComponent")

	# Park the carrier so the two volumes overlap. 1.5 m apart, with a 3 m box
	# against a 1.3 m box, is a guaranteed overlap.
	global_position = _target.global_position + Vector3(0.0, 0.0, 1.5)


## Move the carrier onto the player and wire the player's health. The player's
## HurtboxComponent resolves its HealthComponent by the node name "Health", so a
## null here means that lookup failed and every hit on the player would be
## silently dropped.
func _begin_player_phase() -> void:
	var main := get_node_or_null("../Main")
	var player: Node = null
	if main != null:
		player = main.get_node_or_null("TestEnvironment/Player")
	if player == null:
		_fail("player not found")
		return

	_player_health = player.get_node_or_null("Health") as HealthComponent
	if _player_health == null:
		_fail("player has no HealthComponent")
		return
	_player_health.damaged.connect(_on_player_damaged)
	global_position = (player as Node3D).global_position


## Prints the layer/type separation, which is what proves physical collision and
## combat collision are genuinely different concerns.
func _audit_layers() -> void:
	print("[DMGPROBE] --- layer audit ---")
	print("[DMGPROBE] hitbox  is Area3D=%s layer=%d mask=%d (expect layer=%d mask=%d)" % [
		str(_hitbox is Area3D), _hitbox.collision_layer, _hitbox.collision_mask,
		GameLayers.HITBOX, GameLayers.HURTBOX])
	print("[DMGPROBE] hurtbox is Area3D=%s layer=%d mask=%d (expect layer=%d mask=%d)" % [
		str(_hurtbox is Area3D), _hurtbox.collision_layer, _hurtbox.collision_mask,
		GameLayers.HURTBOX, 0])
	print("[DMGPROBE] target body class=%s layer=%d mask=%d" % [
		_target.get_class(), _target.collision_layer, _target.collision_mask])

	if _hitbox.collision_layer != GameLayers.HITBOX:
		_fail("hitbox layer wrong")
	if _hitbox.collision_mask != GameLayers.HURTBOX:
		_fail("hitbox mask wrong")
	if _hurtbox.collision_layer != GameLayers.HURTBOX:
		_fail("hurtbox layer wrong")
	if _hurtbox.collision_mask != 0:
		_fail("hurtbox should mask nothing")
	if _hurtbox is not Area3D:
		_fail("hurtbox is not an Area3D")
	if _target is CollisionObject3D and _target.collision_layer & GameLayers.combat_layers() != 0:
		_fail("target physical body is on a combat layer")


func _physics_process(_delta: float) -> void:
	if _done or _health == null:
		return
	_frame += 1
	if _frame < 20:
		return
	_phase_frame += 1
	if _phase_frame < STEP_FRAMES:
		return
	_phase_frame = 0
	_run_phase()


func _run_phase() -> void:
	match _phase:
		0:
			print("[DMGPROBE] --- P0 idle state ---")
			_expect(_health.current_health == _health.max_health, "starts at full health")
			_expect(not _health.is_dead, "starts alive")
			_expect(_health.applied_count == 0, "no damage applied yet")
			_expect(_damaged_signals == 0, "no damaged signal yet")
		1:
			print("[DMGPROBE] --- P1 open window 1 ---")
			_hitbox.activate()
		2:
			print("[DMGPROBE] --- P2 window 1 still open (must not re-apply) ---")
			_expect(_health.applied_count == 1, "exactly 1 application in window 1")
			_expect(_damaged_signals == 1, "exactly 1 damaged signal in window 1")
			_expect(_health.current_health == 75.0, "health 100 -> 75")
		3:
			print("[DMGPROBE] --- P3 close, then open window 2 ---")
			_hitbox.deactivate()
			_hitbox.activate()
		4:
			print("[DMGPROBE] --- P4 window 2 result ---")
			_expect(_health.applied_count == 2, "exactly 2 applications after two windows")
			_expect(_health.current_health == 50.0, "health 75 -> 50")
		5:
			print("[DMGPROBE] --- P5 drive to death, one window per step ---")
			_hitbox.deactivate()
		6:
			if _health.is_dead:
				print("[DMGPROBE] --- P6 death state ---")
				_expect(_health.is_dead, "is_dead true at zero health")
				_expect(_health.current_health == 0.0, "health clamped to 0")
				_expect(_died_signals == 1, "died emitted exactly once")
				print("[DMGPROBE] windows needed to kill: %d" % _death_windows)
				_phase = 8
			elif _death_windows >= MAX_DEATH_WINDOWS:
				_fail("target never died after %d windows" % MAX_DEATH_WINDOWS)
				_phase = 8
			else:
				_hitbox.activate()
				_death_windows += 1
		7:
			if _health.is_dead:
				_phase = 8
			else:
				_hitbox.deactivate()
				_phase = 5
		9:
			print("[DMGPROBE] --- P7 damage after death (must be refused) ---")
			var before := _health.applied_count
			_hitbox.activate()
			_hitbox.deactivate()
			_expect(_health.applied_count == before, "no application after death")
			_expect(_died_signals == 1, "death did not re-emit")
			_begin_player_phase()
		10:
			print("[DMGPROBE] --- P8 open window on the PLAYER ---")
			_hitbox.activate()
		11:
			print("[DMGPROBE] --- P9 player damage result (a held window must not re-apply) ---")
			_expect(_player_health != null, "player HealthComponent found")
			if _player_health != null:
				_expect(_player_damaged == 1, "exactly 1 damaged signal on the player")
				_expect(_player_health.applied_count == 1, "exactly 1 application on the player")
				_expect(_player_health.current_health == 75.0, "player health 100 -> 75")
				_expect(not _player_health.is_dead, "player alive after one hit")
			_hitbox.deactivate()
			_finish()
		_:
			_finish()
	_phase += 1


func _on_damaged(_event: DamageEvent, current: float, _maximum: float) -> void:
	_damaged_signals += 1
	print("[DMGPROBE]   damaged signal #%d -> %.1f" % [_damaged_signals, current])


func _on_died(_event: DamageEvent) -> void:
	_died_signals += 1
	print("[DMGPROBE]   died signal #%d" % _died_signals)


func _on_player_damaged(_event: DamageEvent, current: float, _maximum: float) -> void:
	_player_damaged += 1
	print("[DMGPROBE]   PLAYER damaged signal #%d -> %.1f" % [_player_damaged, current])


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[DMGPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[DMGPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[DMGPROBE] --- summary ---")
	print("[DMGPROBE] final health=%.1f/%d applied=%d damaged=%d died=%d" % [
		_health.current_health, int(_health.max_health),
		_health.applied_count, _damaged_signals, _died_signals])
	if _failures.is_empty():
		print("[DMGPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[DMGPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
