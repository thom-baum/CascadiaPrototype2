class_name ActorDeathProbeDebug
extends Node3D
## Temporary diagnostic (not production): is the death path actually REUSABLE
## across the arena's damageable actors, or was it only ever wired on one of them?
##
## Why this exists: the defeat capability already existed as `EnemyDeathComponent`,
## but it was reachable by exactly ONE actor. A component that one actor uses is a
## feature on that actor; a component ANY actor can carry is a capability, and the
## difference is only observable by attaching it to a SECOND actor and measuring
## that the same state transitions happen there. That is what this probe measures.
##
## Deterministic by construction. Every blow goes through the existing
## `HurtboxComponent.receive_hit` -> `HealthComponent.apply_damage` chain, which is
## the single place all damage in Cascadia lands. Nothing here depends on attack
## timing, on the enemy's cadence, or on player input.
##
## It measures STATE TRANSITIONS, not labels:
##
##   AC1 wiring    the second mortal actor carries a defeat component at all
##   AC2 reuse     one lethal hit on that second actor produces exactly one defeat
##   AC3 once      further lethal damage after death adds no second defeat
##   AC4 immortal  damageable-but-immortal zeroes health and is NOT defeated
##   AC5 nodamage  a non-damageable actor refuses the hit and keeps its health
##   AC6 reset     the player's death + automatic reset does NOT revive the defeated
##   AC7 player    the player's own resettable circuit still reports dead then alive
##
## What it deliberately does NOT re-measure: the attacker-side defeat gate (a
## defeated attacker cannot continue or start an attack, refusal counted by cause)
## is already measured by `enemy_death_probe_debug`, which is re-run alongside this.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 12
## Frames allowed for the player's automatic reset. Generously longer than the
## player's authored `death_delay` (1.5 s at 60 Hz), so a timeout here is a real
## failure rather than a slow frame.
const RESET_WAIT_FRAMES := 300
## Damage used for a lethal blow - far above any actor's pool, so "lethal" is not
## a tuning value this probe depends on.
const LETHAL := 9999.0

var _frame := 0
var _done := false
var _stage := 0
var _wait := 0
var _failures: Array = []

# Resolved once, in _run().
var _player: Node3D
var _dummy: Node3D
var _immortal_target: Node3D
var _nodamage_target: Node3D
var _dummy_death: Node
var _player_death: Node


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _stage == 0:
		if _frame < SETTLE_FRAMES:
			return
		_stand_down_ambient_attackers()
		_run()
		return
	if _stage == 1:
		_tick_wait_for_player_reset()


## The arena's ambient attacker would otherwise attack the player during the wait
## below and re-kill it mid-measurement. Same stand-down the other probes use.
func _stand_down_ambient_attackers() -> void:
	for node in get_tree().get_nodes_in_group(EnemyAttacker.GROUP_ATTACKER):
		if node != null and "auto_attack" in node:
			node.auto_attack = false


func _run() -> void:
	print("[ACTORDEATH] --- reusable actor death capability audit (measured) ---")
	_resolve_actors()
	if _player == null or _dummy == null:
		_fail("could not resolve the player and/or the DummyActor")
		_done = true
		_report()
		return

	_dummy_death = _dummy.get_node_or_null("Death")
	_player_death = _player.get_node_or_null("Death")

	print("[ACTORDEATH] actors: player=%s  dummy=%s  immortal-target=%s  nodamage-target=%s" % [
		_name_of(_player), _name_of(_dummy),
		_name_of(_immortal_target), _name_of(_nodamage_target)])

	_check_wiring()
	_check_reuse()
	_check_once()
	_check_immortal()
	_check_nodamage()
	_check_player_circuit()

	# The player's reset takes real time, so the last check cannot resolve in this
	# frame. Hand over to the staged wait; the report is written when it resolves.
	print("[ACTORDEATH] killing the player; waiting up to %d frames for the automatic reset" % RESET_WAIT_FRAMES)
	_apply_lethal(_player)
	_stage = 1
	_wait = 0


# --- AC1: the capability is actually composed onto a second actor --------------

func _check_wiring() -> void:
	var player_ok := _player_death != null and "resets_actors" in _player_death
	var dummy_ok := _dummy_death != null and _dummy_death.has_method("is_defeated")
	var dummy_mortal := dummy_ok and _dummy_death.has_method("is_mortal") and bool(_dummy_death.call("is_mortal"))

	_expect(dummy_ok,
		"DummyActor carries a defeat component (reusable path is composed onto a second actor)")
	_expect(dummy_mortal,
		"DummyActor's defeat component reports mortal=true (it is a MORTAL actor, not decoration)")
	_expect(player_ok,
		"Player carries its own resettable death circuit")

	if dummy_ok:
		_expect(not bool(_dummy_death.call("is_defeated")),
			"DummyActor starts alive (is_defeated=false)")
		print("[ACTORDEATH] dummy defeat component: %s  mortal=%s  defeats=%d" % [
			_dummy_death.get_script().resource_path.get_file(),
			str(dummy_mortal), int(_dummy_death.get("defeats"))])


# --- AC2/AC3: the second mortal actor dies, exactly once -----------------------

func _check_reuse() -> void:
	var health := _health_of(_dummy)
	var hurtbox := _hurtbox_of(_dummy)
	if health == null or hurtbox == null:
		_fail("DummyActor has no Health and/or Hurtbox to damage through")
		return

	var applied := _apply_lethal(_dummy)
	var defeated := bool(_dummy_death.call("is_defeated"))
	var defeats := int(_dummy_death.get("defeats"))

	print("[ACTORDEATH] second mortal actor: receive_hit->apply_damage=%s  health=%.1f  is_dead=%s  is_defeated=%s  defeats=%d" % [
		str(applied), health.current_health, str(health.is_dead), str(defeated), defeats])

	_expect(applied, "lethal hit on the SECOND mortal actor was accepted through the existing damage chain")
	_expect(health.is_dead and is_zero_approx(health.current_health),
		"the second mortal actor reached zero health and is marked dead by HealthComponent")
	_expect(defeated and defeats == 1,
		"the SAME defeat component produced exactly one defeat on the second actor (defeats=1)")


func _check_once() -> void:
	if _dummy_death == null:
		return
	var before := int(_dummy_death.get("defeats"))
	var health := _health_of(_dummy)
	var applied := _apply_lethal(_dummy)
	var after := int(_dummy_death.get("defeats"))

	print("[ACTORDEATH] post-death damage: applied=%s  defeats %d -> %d  lethal_refusals=%d" % [
		str(applied), before, after, int(_dummy_death.get("lethal_refusals"))])

	_expect(not applied,
		"damage after death was refused (HealthComponent already refuses damage to a dead actor)")
	_expect(after == before and after == 1,
		"post-death damage produced NO duplicate defeat processing (still defeats=1)")


# --- AC4: damageable but IMMORTAL is a genuinely different configuration -------

func _check_immortal() -> void:
	if _immortal_target == null:
		_fail("no static damageable target available to configure as immortal")
		return
	var health := _health_of(_immortal_target)
	if health == null:
		_fail("immortal target has no HealthComponent")
		return

	# Smallest possible test configuration: one runtime component with the policy
	# flag flipped, so the two axes are proved against the SAME damage chain the
	# mortal actor used. Nothing is added to any scene file for this.
	var component := EnemyDeathComponent.new()
	component.name = "ImmortalPolicyProbe"
	component.mortal = false
	component.health_path = NodePath("../Health")
	_immortal_target.add_child(component)

	var applied := _apply_lethal(_immortal_target)
	var defeated := bool(component.call("is_defeated"))
	var defeats := int(component.get("defeats"))
	var refusals := int(component.get("lethal_refusals"))

	print("[ACTORDEATH] immortal actor: apply_damage=%s  health=%.1f  is_dead=%s  is_mortal=%s  is_defeated=%s  defeats=%d  lethal_refusals=%d" % [
		str(applied), health.current_health, str(health.is_dead), str(component.call("is_mortal")),
		str(defeated), defeats, refusals])

	_expect(applied and health.is_dead,
		"a damageable-but-IMMORTAL actor still takes damage and still reaches zero health")
	_expect(not defeated and defeats == 0,
		"a damageable-but-IMMORTAL actor is NOT defeated (is_defeated=false, defeats=0)")
	_expect(refusals == 1,
		"the immortal refusal is counted by cause (lethal_refusals=1), so it cannot be mistaken for a defeat")

	# Leave the arena as found: the component was this probe's own configuration.
	_immortal_target.remove_child(component)
	component.queue_free()


# --- AC5: non-damageable is a permanent refusal, not a timed one --------------

func _check_nodamage() -> void:
	if _nodamage_target == null:
		_fail("no static damageable target available to configure as non-damageable")
		return
	var health := _health_of(_nodamage_target)
	var hurtbox := _hurtbox_of(_nodamage_target)
	if health == null or hurtbox == null:
		_fail("non-damageable target has no Health and/or Hurtbox")
		return

	var before := health.current_health
	hurtbox.damageable = false
	var applied := hurtbox.receive_hit(_lethal_event())
	var after := health.current_health
	var refusals := hurtbox.refusals_by_policy
	hurtbox.damageable = true

	print("[ACTORDEATH] non-damageable actor: applied=%s  health %.1f -> %.1f  refusals_by_policy=%d" % [
		str(applied), before, after, refusals])

	_expect(not applied, "a NON-DAMAGEABLE actor refuses the hit at the hurtbox")
	_expect(is_equal_approx(before, after),
		"a NON-DAMAGEABLE actor's health is untouched by the refused hit")
	_expect(refusals == 1,
		"the permanent refusal is counted separately (refusals_by_policy=1), not as a dodge or a parry")


# --- AC7: the player's own circuit is unchanged -------------------------------

func _check_player_circuit() -> void:
	if _player_death == null:
		_fail("player has no death circuit to check")
		return
	var resettable := bool(_player_death.get("resets_actors"))
	print("[ACTORDEATH] player circuit: resets_actors=%s  dead_before=%s" % [
		str(resettable), str(bool(_player_death.call("is_dead")))])
	_expect(resettable,
		"the player still owns the resettable circuit (resets_actors=true) - respawn stays player-specific")
	_expect(not bool(_player_death.call("is_dead")),
		"the player is alive before the death being measured")


# --- AC6: the player's reset must not revive a defeated actor -----------------

func _tick_wait_for_player_reset() -> void:
	if _player_death == null:
		_done = true
		_report()
		return
	_wait += 1
	var dead := bool(_player_death.call("is_dead"))
	if dead and _wait < RESET_WAIT_FRAMES:
		return

	var health := _health_of(_player)
	var dummy_health := _health_of(_dummy)
	var dummy_defeated := bool(_dummy_death.call("is_defeated"))
	var dummy_defeats := int(_dummy_death.get("defeats"))
	var resets := int(_player_death.get("resets"))

	print("[ACTORDEATH] after %.2f s: player_dead=%s  player_health=%.1f  resets=%d" % [
		float(_wait) / 60.0, str(dead), health.current_health if health != null else -1.0, resets])
	print("[ACTORDEATH] after reset: dummy is_defeated=%s  defeats=%d  health=%.1f  is_dead=%s" % [
		str(dummy_defeated), dummy_defeats,
		dummy_health.current_health if dummy_health != null else -1.0,
		str(dummy_health.is_dead) if dummy_health != null else "n/a"])
	_report_attacker_observation()

	_expect(not dead and resets >= 1,
		"the player's automatic reset ran (the player is playable again)")
	if health != null:
		_expect(not health.is_dead and health.current_health > 0.0,
			"the player's health was restored by the reset")
	_expect(dummy_defeated and dummy_defeats == 1,
		"the player's reset did NOT revive the defeated actor (still is_defeated, defeats=1)")
	if dummy_health != null:
		_expect(dummy_health.is_dead and is_zero_approx(dummy_health.current_health),
			"the defeated actor's health is still zero after the player's reset")

	_done = true
	_report()


## The arena resetting its scripted test attacker IS documented test-environment
## behaviour, not the world-persistence model. Printed rather than asserted, so it
## is visible in the output without this probe pretending it is a requirement.
func _report_attacker_observation() -> void:
	var attacker := get_tree().get_first_node_in_group(EnemyAttacker.GROUP_ATTACKER)
	if attacker == null:
		print("[ACTORDEATH] observation: no ambient attacker present")
		return
	print("[ACTORDEATH] observation (test-environment behaviour, NOT a persistence model): arena attacker phase=%s attacking=%s" % [
		str(attacker.call("phase_name")), str(bool(attacker.call("is_attacking")))])


# --- Damage -------------------------------------------------------------------

func _lethal_event() -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = null
	return event


## One lethal blow through the existing receiving volume, which is the same route
## a real attack takes. Falls back to the health component only if the actor has no
## hurtbox at all, so a missing volume is reported rather than silently worked
## around.
func _apply_lethal(actor: Node3D) -> bool:
	if actor == null:
		return false
	var hurtbox := _hurtbox_of(actor)
	if hurtbox != null:
		return hurtbox.receive_hit(_lethal_event())
	var health := _health_of(actor)
	if health != null:
		return health.apply_damage(_lethal_event())
	return false


# --- Resolution ---------------------------------------------------------------

func _resolve_actors() -> void:
	_player = get_tree().get_first_node_in_group("player_actor") as Node3D
	if _player == null:
		_player = _actor_named("Player")
	_dummy = _actor_named("DummyActor")

	# Two distinct static targets, so the immortal and non-damageable checks never
	# fight over the same actor's health.
	var statics := _static_targets()
	if statics.size() >= 1:
		_immortal_target = statics[0]
	if statics.size() >= 2:
		_nodamage_target = statics[1]


func _actor_named(actor_name: String) -> Node3D:
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var body := health.get_parent() as Node3D
		if body != null and String(body.name) == actor_name:
			return body
	return null


## Static (non-grounding) damageable actors, sorted by name so the choice is
## deterministic instead of depending on group insertion order.
func _static_targets() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var body := health.get_parent()
		if body is StaticBody3D:
			out.append(body)
	out.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.name) < String(b.name))
	return out


func _health_of(actor: Node) -> HealthComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null


func _hurtbox_of(actor: Node) -> HurtboxComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is HurtboxComponent:
			return child as HurtboxComponent
	return null


func _name_of(actor: Node) -> String:
	return String(actor.name) if actor != null else "none"


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[ACTORDEATH]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ACTORDEATH]   FAIL  %s" % label)


func _report() -> void:
	print("[ACTORDEATH] --- summary ---")
	if _failures.is_empty():
		print("[ACTORDEATH] RESULT: ALL CHECKS PASSED")
	else:
		print("[ACTORDEATH] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
