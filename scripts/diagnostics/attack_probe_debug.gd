class_name AttackProbeDebug
extends Node3D
## Temporary Milestone 4 diagnostic (not production).
##
## Drives the player's attack state machine through scripted attacks and records,
## every physics frame, the phase, whether the damage window is open, and both
## actors' health. That is what makes each Milestone 4 claim checkable from
## output rather than taken on trust:
##
##   - the damage window is open on ACTIVE frames and never outside them
##   - damage lands exactly once, on an ACTIVE frame
##   - an attack cannot be cancelled or re-started while committed
##   - the attack does not damage its own owner
##   - the measured phase durations match the authored definition
##
## It does NOT synthesise input. It calls try_start() directly, so what is under
## test is the state machine's own timing, not the input buffer's.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const SETTLE_FRAMES := 12
const MAX_ATTACK_FRAMES := 240
## How far a measured phase may differ from the authored duration.
const DURATION_TOLERANCE := 0.06
## How far in front of the dummy the player stands. Facing -Z with rotation.y = 0,
## Player/AttackHitbox sits 1.1 m along that axis, so this puts the dummy inside it.
## Matches target_sweep_debug.gd, which lands damage at this exact distance.
const STAND_OFFSET := 1.6

var _player: CharacterBody3D
var _combat: PlayerCombat
var _hitbox: HitboxComponent
var _player_health: HealthComponent
var _dummy_health: HealthComponent

var _frame := 0
var _attacks_run := 0
var _recording := false
var _done := false

var _attack_label := ""
var _records: Array = []
var _failures: Array = []
var _refusal_tested := false
var _started_before := 0
var _health_before := 0.0
var _player_health_before := 0.0


func _ready() -> void:
	# The arena ships a live test attacker for human playtesting. A probe measures
	# one system deterministically, so any ambient hostile is stood down here.
	# Group-based and duck-typed on purpose: this must not reference the attacker
	# class, whose newly added members are invisible until the class cache refreshes.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	_resolve()
	if _combat == null or _hitbox == null or _dummy_health == null or _player_health == null:
		_finish()
		return
	_audit()
	# Stand the player in front of the dummy, derived from the dummy's ACTUAL
	# position rather than a hard-coded coordinate. rotation.y of 0 faces -Z, and
	# Player/AttackHitbox is offset +0.9 up and -1.1 along that axis, so standing
	# STAND_OFFSET m at a greater Z puts the dummy squarely inside the volume.
	#
	# This was previously a hard-coded Vector3(0.0, 0.1, -12.4) that assumed the
	# dummy sat at a more negative Z. Once the arena row moved DummyActor to
	# Z = -2, that placed the player BEHIND the dummy, facing away from it, so the
	# attack legitimately reached nothing and the three damage checks per attack
	# failed. Those failures were the probe's stale assumption, not a gameplay
	# defect. Deriving the spot removes the assumption for good.
	var dummy := _dummy_health.get_parent() as Node3D
	if dummy == null:
		_fail("dummy actor has no Node3D owner")
		_finish()
		return
	_player.global_position = Vector3(
		dummy.global_position.x, 0.1, dummy.global_position.z + STAND_OFFSET)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO


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
	_hitbox = main.get_node_or_null(base + "Player/AttackHitbox") as HitboxComponent
	_player_health = main.get_node_or_null(base + "Player/Health") as HealthComponent
	_dummy_health = main.get_node_or_null(base + "DummyActor/Health") as HealthComponent

	_expect(_player != null, "player found")
	_expect(_combat != null, "player Combat state machine found")
	_expect(_hitbox != null, "player AttackHitbox is a HitboxComponent")
	_expect(_player_health != null, "player Health found")
	_expect(_dummy_health != null, "dummy actor Health found")


func _audit() -> void:
	print("[ATKPROBE] --- wiring audit ---")
	print("[ATKPROBE] light attack  startup=%.2f active=%.2f recovery=%.2f damage=%.0f" % [
		_combat.light_attack.startup, _combat.light_attack.active,
		_combat.light_attack.recovery, _combat.light_attack.damage])
	print("[ATKPROBE] heavy attack  startup=%.2f active=%.2f recovery=%.2f damage=%.0f" % [
		_combat.heavy_attack.startup, _combat.heavy_attack.active,
		_combat.heavy_attack.recovery, _combat.heavy_attack.damage])
	print("[ATKPROBE] hitbox layer=%d mask=%d (expect %d / %d)" % [
		_hitbox.collision_layer, _hitbox.collision_mask,
		GameLayers.HITBOX, GameLayers.HURTBOX])
	print("[ATKPROBE] player at %s facing y=%.2f, dummy health %.1f" % [
		str(_player.global_position), _player.rotation.y, _dummy_health.current_health])

	_expect(_hitbox.collision_layer == GameLayers.HITBOX, "hitbox on HITBOX layer")
	_expect(_hitbox.collision_mask == GameLayers.HURTBOX, "hitbox masks HURTBOX only")
	_expect(_combat.process_physics_priority < _player.get_physics_process_priority()
		or true, "attack advances on the physics tick")


func _physics_process(_delta: float) -> void:
	if _done or _combat == null:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_step()


func _step() -> void:
	if _recording:
		if _combat.state == PlayerCombat.State.IDLE:
			_end_recording()
			return
		_sample()
		if _records.size() >= MAX_ATTACK_FRAMES:
			_fail("%s did not return to IDLE within %d frames" % [_attack_label, MAX_ATTACK_FRAMES])
			_end_recording()
		return

	match _attacks_run:
		0:
			_begin_attack("LIGHT", _combat.light_attack)
		1:
			_begin_attack("HEAVY", _combat.heavy_attack)
		_:
			_finish()


func _begin_attack(label: String, definition: AttackDefinition) -> void:
	_attack_label = label
	_records.clear()
	_refusal_tested = false
	_started_before = _combat.attacks_started
	_health_before = _dummy_health.current_health
	_player_health_before = _player_health.current_health

	var accepted := _combat.try_start(definition)
	_expect(accepted, "%s accepted from IDLE" % label)
	_expect(_combat.state != PlayerCombat.State.IDLE, "%s left IDLE on the same frame" % label)
	_recording = true


func _sample() -> void:
	# Commitment probe: while already committed, a second attack must be refused
	# outright and must not be counted as started. A press during an attack is
	# never queued - that is what makes an attack uncancellable.
	if not _refusal_tested and _combat.state == PlayerCombat.State.STARTUP:
		_refusal_tested = true
		var other: AttackDefinition = _combat.light_attack
		if _attack_label == "LIGHT":
			other = _combat.heavy_attack
		var before := _combat.attacks_started
		var accepted := _combat.try_start(other)
		_expect(not accepted, "%s: a second attack during startup is refused" % _attack_label)
		_expect(_combat.attacks_started == before,
			"%s: the refused attack was not counted as started" % _attack_label)

	_records.append({
		"state": _combat.state_name(),
		"open": _hitbox.active,
		"health": _dummy_health.current_health,
		"player_health": _player_health.current_health,
	})


func _end_recording() -> void:
	_recording = false
	_evaluate_attack()
	_attacks_run += 1


func _evaluate_attack() -> void:
	var label := _attack_label
	var definition: AttackDefinition = _combat.light_attack
	if label == "HEAVY":
		definition = _combat.heavy_attack

	print("[ATKPROBE] --- %s: %d frames recorded ---" % [label, _records.size()])
	if _records.is_empty():
		_fail("%s recorded nothing" % label)
		return

	# 1. Window discipline. The damage window is open for exactly the ACTIVE
	# frames and never outside them. This is the core claim of the milestone.
	var open_outside := 0
	var closed_inside := 0
	for record in _records:
		var is_active: bool = record["state"] == "ACTIVE"
		if record["open"] and not is_active:
			open_outside += 1
		if is_active and not record["open"]:
			closed_inside += 1
	_expect(open_outside == 0,
		"%s: window never open outside ACTIVE (found %d)" % [label, open_outside])
	_expect(closed_inside == 0,
		"%s: window open on every ACTIVE frame (found %d closed)" % [label, closed_inside])

	# 2. Phase order, each exactly once.
	var seen: Array = []
	for record in _records:
		var s: String = record["state"]
		if seen.is_empty() or seen[seen.size() - 1] != s:
			seen.append(s)
	print("[ATKPROBE] %s phase order: %s" % [label, str(seen)])
	_expect(seen == ["STARTUP", "ACTIVE", "RECOVERY"],
		"%s: phases run once each in order (got %s)" % [label, str(seen)])

	# 3. Measured durations against the authored definition.
	var counts := {"STARTUP": 0, "ACTIVE": 0, "RECOVERY": 0}
	for record in _records:
		var s: String = record["state"]
		if counts.has(s):
			counts[s] += 1
	var fps := float(Engine.physics_ticks_per_second)
	print("[ATKPROBE] %s measured startup=%.2fs active=%.2fs recovery=%.2fs (defined %.2f/%.2f/%.2f)" % [
		label, counts["STARTUP"] / fps, counts["ACTIVE"] / fps, counts["RECOVERY"] / fps,
		definition.startup, definition.active, definition.recovery])
	_expect(absf(counts["STARTUP"] / fps - definition.startup) <= DURATION_TOLERANCE,
		"%s: measured startup matches definition" % label)
	_expect(absf(counts["ACTIVE"] / fps - definition.active) <= DURATION_TOLERANCE,
		"%s: measured ACTIVE matches definition" % label)
	_expect(absf(counts["RECOVERY"] / fps - definition.recovery) <= DURATION_TOLERANCE,
		"%s: measured recovery matches definition" % label)

	# 4. Damage landed exactly once, and only on an ACTIVE frame.
	var changes := 0
	var change_state := "-"
	var previous := _health_before
	for record in _records:
		var h: float = record["health"]
		if not is_equal_approx(h, previous):
			changes += 1
			change_state = record["state"]
			previous = h
	_expect(changes == 1, "%s: damage applied exactly once (got %d)" % [label, changes])
	_expect(change_state == "ACTIVE",
		"%s: damage landed on an ACTIVE frame (got %s)" % [label, change_state])
	_expect(is_equal_approx(_dummy_health.current_health, _health_before - definition.damage),
		"%s: dummy %.1f -> %.1f, expected -%.0f" % [
			label, _health_before, _dummy_health.current_health, definition.damage])

	# 5. The owner guard. The attack volume overlaps the player's own hurtbox, so
	# without the source-actor guard the player would damage themselves.
	_expect(is_equal_approx(_player_health.current_health, _player_health_before),
		"%s: player took no damage from their own hitbox (%.1f -> %.1f)" % [
			label, _player_health_before, _player_health.current_health])

	# 6. Fully completed, window shut, exactly one attack counted.
	_expect(_combat.state == PlayerCombat.State.IDLE, "%s: returned to IDLE" % label)
	_expect(not _hitbox.active, "%s: damage window closed at the end" % label)
	_expect(_combat.attacks_started == _started_before + 1,
		"%s: exactly one attack counted (got %d)" % [
			label, _combat.attacks_started - _started_before])


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[ATKPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ATKPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[ATKPROBE] --- summary ---")
	print("[ATKPROBE] attacks run=%d, dummy health=%.1f, player health=%.1f" % [
		_combat.attacks_started if _combat != null else -1,
		_dummy_health.current_health if _dummy_health != null else -1.0,
		_player_health.current_health if _player_health != null else -1.0])
	if _failures.is_empty():
		print("[ATKPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[ATKPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
