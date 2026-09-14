class_name TargetSweepDebug
extends Node3D
## Temporary Milestone 4 diagnostic (not production).
##
## The attack probe only ever exercised ONE dummy. This probe walks EVERY
## damageable actor in the test environment and proves each one is genuinely
## attackable by the player's own attack volume: real hitbox, real overlap, real
## health reduction, through a real attack.
##
## It does NOT synthesise input. It calls try_start() directly, so what is under
## test is whether each target is reachable and damageable, not the input path.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the physical scene to settle before the first target.
const SETTLE_FRAMES := 15
## Frames to let the physics server register the teleport before attacking. Overlaps
## are only recomputed on a physics step, so attacking on the teleport frame would
## test nothing.
const POSITION_WAIT := 4
## Frames to wait for an attack to finish before calling it stuck.
const MAX_WAIT_PER_TARGET := 240
## Frames between finishing one target and starting the next.
const BETWEEN_TARGETS := 3
## How far in front of a target the player stands. Facing -Z with rotation.y = 0.
const STAND_OFFSET := 1.6

var _player: CharacterBody3D
var _combat: PlayerCombat
var _player_health: HealthComponent
var _targets: Array = []

var _index := 0
var _phase := 0
var _wait := 0
var _stage_frames := 0
var _before := 0.0
var _done := false
var _failures: Array = []
var _passed: Array = []


func _ready() -> void:
	_resolve()
	_wait = SETTLE_FRAMES


func _resolve() -> void:
	# This probe is a sibling of Main, so Main is reached through the parent.
	var main := get_node_or_null("../Main")
	if main == null:
		main = get_node_or_null("Main")
	if main == null:
		_fail("main scene not found")
		return

	var base := "TestEnvironment/"
	_player = main.get_node_or_null(base + "Player") as CharacterBody3D
	_combat = main.get_node_or_null(base + "Player/Combat") as PlayerCombat
	_player_health = main.get_node_or_null(base + "Player/Health") as HealthComponent

	_expect(_player != null, "player found")
	_expect(_combat != null, "player Combat state machine found")
	_expect(_player_health != null, "player Health found")
	if _player == null or _combat == null or _player_health == null:
		_finish()
		return

	# Discover every damageable actor through the group rather than by name, so a
	# target that is not wired shows up as a failure instead of being skipped.
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null or health == _player_health:
			continue
		var owner_node := health.get_parent()
		if owner_node is Node3D:
			_targets.append(health)

	_targets.sort_custom(func(a, b): return String(a.get_parent().name) < String(b.get_parent().name))

	print("[SWEEP] damageable targets discovered: %d" % _targets.size())
	for health in _targets:
		print("[SWEEP]   target: %s at %s (health %.1f)" % [
			health.get_parent().name, str((health.get_parent() as Node3D).global_position),
			health.current_health])
	_expect(_targets.size() >= 4, "at least 4 damageable targets are wired")


func _physics_process(_delta: float) -> void:
	if _done or _combat == null:
		return
	if _wait > 0:
		_wait -= 1
		return
	_stage_frames += 1
	if _index >= _targets.size():
		_finish()
		return
	match _phase:
		0:
			_stage_position()
		1:
			_stage_attack()
		2:
			_stage_wait()


## Stand the player in front of the current target and remember its health.
func _stage_position() -> void:
	var health := _targets[_index] as HealthComponent
	var owner_node := health.get_parent() as Node3D
	if owner_node == null:
		_fail("target %d has no Node3D owner" % _index)
		_index += 1
		return
	_player.global_position = Vector3(
		owner_node.global_position.x, 0.1, owner_node.global_position.z + STAND_OFFSET)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_before = health.current_health
	_phase = 1
	_stage_frames = 0
	_wait = POSITION_WAIT


func _stage_attack() -> void:
	var accepted := _combat.try_start(_combat.light_attack)
	_expect(accepted, "%s: light attack accepted" % _target_name())
	_phase = 2
	_stage_frames = 0


func _stage_wait() -> void:
	if _combat.state != PlayerCombat.State.IDLE:
		if _stage_frames > MAX_WAIT_PER_TARGET:
			_fail("%s: attack never returned to IDLE" % _target_name())
			_advance()
		return
	_evaluate()
	_advance()


func _evaluate() -> void:
	var health := _targets[_index] as HealthComponent
	var after := health.current_health
	var dealt := _before - after
	var expected := _combat.light_attack.damage
	var ok := is_equal_approx(dealt, expected)
	print("[SWEEP] %-12s %.1f -> %.1f  (dealt %.1f, expected %.1f)  %s" % [
		_target_name(), _before, after, dealt, expected, "PASS" if ok else "FAIL"])
	if ok:
		_passed.append(_target_name())
	else:
		_fail("%s took %.1f damage, expected %.1f" % [_target_name(), dealt, expected])


func _advance() -> void:
	_index += 1
	_phase = 0
	_stage_frames = 0
	_wait = BETWEEN_TARGETS


func _target_name() -> String:
	if _index >= _targets.size():
		return "?"
	var health := _targets[_index] as HealthComponent
	if health.get_parent() == null:
		return "?"
	return String(health.get_parent().name)


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[SWEEP]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[SWEEP]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[SWEEP] --- summary ---")
	print("[SWEEP] targets attacked and damaged: %d / %d" % [_passed.size(), _targets.size()])
	if _failures.is_empty():
		print("[SWEEP] RESULT: ALL CHECKS PASSED")
	else:
		print("[SWEEP] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
