class_name DefeatCoverageProbeDebug
extends Node3D
## Temporary diagnostic (not production): does EVERY damageable enemy in the arena
## end in a real DEFEATED state, with a defeat presentation showing, once its health
## reaches zero?
##
## Why this exists: the reusable defeat path was proven actor by actor, by hand. No
## probe asserted the property ACROSS the arena, so a damageable actor could reach
## zero health, process no defeat at all, and still pass every other probe - because
## every other probe only inspects the actors it was told about by name.
##
## This is the missing check, and it is deliberately driven by ENUMERATION rather
## than by a hard-coded list:
##
##   - it walks the arena's `damageable` group, so a newly added enemy is covered
##     the moment it exists in the scene;
##   - an actor wired without a defeat path FAILS here, instead of being discovered
##     by hand in the running game.
##
## The PLAYER is deliberately excluded from the coverage set. It is not an enemy: its
## death is a RESETTABLE circuit owned by DeathComponent (health restored, body put
## back on its mark) and is already measured by `death_probe_debug`. This probe covers
## every OTHER damageable actor - the enemies and the test fixtures - and requires each
## to reach a genuine defeated state.
##
## What it measures per enemy, all of it through the existing production chain:
##
##   health.is_dead + zero health   the lethal hit landed (via hurtbox -> health)
##   mortal                          the actor is a defeatable enemy, not a fixture
##   is_defeated()                   the EXISTING defeat path processed it
##   defeats == 1                    processed exactly once
##   a defeat presentation           one exists, and `is_showing()` is true
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 12
## Frames allowed after the killing blows for the deaths and their presentations to
## land. The presentation polls, so it needs at least one frame.
const HOLD_FRAMES := 8
## Damage used for a lethal blow - far above any actor's pool, so "lethal" never
## depends on a tuning value.
const LETHAL := 9999.0

var _frame := 0
var _done := false
var _stage := 0
var _wait := 0
var _failures: Array = []
var _candidates: Array = []


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _stage == 0:
		if _frame < SETTLE_FRAMES:
			return
		_stand_down_ambient_attackers()
		_kill_all()
		_stage = 1
		_wait = 0
		return
	_wait += 1
	if _wait >= HOLD_FRAMES:
		_verify_all()


## The arena's ambient attacker would otherwise swing at the player during the hold
## below and re-kill it mid-measurement. Same stand-down the other probes use.
func _stand_down_ambient_attackers() -> void:
	EnemyAttacker.stand_down_all(get_tree())


func _kill_all() -> void:
	print("[DEFCOV] --- arena defeat coverage audit (measured) ---")
	_candidates = _enemy_candidates()
	var total := get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE).size()
	print("[DEFCOV] damageable actors in the arena: %d  (enemies to cover: %d, player excluded)" % [
		total, _candidates.size()])
	if _candidates.is_empty():
		_fail("no enemies found - the arena has nothing to cover")
		_done = true
		_report()
		return
	for body in _candidates:
		var applied := _apply_lethal(body)
		var health := _health_of(body)
		print("[DEFCOV] killed %-14s applied=%s health=%.1f" % [
			String(body.name), str(applied), health.current_health if health != null else -1.0])


func _verify_all() -> void:
	print("[DEFCOV] --- verifying the defeated state %d frames after the killing blows ---" % HOLD_FRAMES)
	var covered := 0
	for body in _candidates:
		var label := String(body.name)
		var health := _health_of(body)
		var death: Node = body.get_node_or_null("Death")
		var presentation := _presentation_of(body)

		if health == null:
			_fail("%s: no HealthComponent" % label)
			continue
		if death == null:
			_fail("%s: reached zero health with NO defeat component - nothing processes its death" % label)
			continue
		if not death.has_method("is_defeated"):
			_fail("%s: its Death node does not answer is_defeated()" % label)
			continue

		var defeated := bool(death.call("is_defeated"))
		var defeats := int(death.get("defeats")) if "defeats" in death else -1
		var mortal := true
		if death.has_method("is_mortal"):
			mortal = bool(death.call("is_mortal"))
		var showing := false
		if presentation != null and presentation.has_method("is_showing"):
			showing = bool(presentation.call("is_showing"))

		var shown := "MISSING"
		if presentation != null:
			shown = "showing" if showing else "present but NOT showing"
		print("[DEFCOV] %-14s health=%.1f is_dead=%s mortal=%s is_defeated=%s defeats=%d presentation=%s" % [
			label, health.current_health, str(health.is_dead), str(mortal), str(defeated),
			defeats, shown])

		_expect(health.is_dead and is_zero_approx(health.current_health),
			"%s: reached zero health through the existing damage chain" % label)
		_expect(mortal,
			"%s: is configured MORTAL - a defeatable enemy, not an unkillable fixture" % label)
		_expect(defeated,
			"%s: entered the DEFEATED state through the existing death path" % label)
		_expect(defeats == 1,
			"%s: processed exactly ONE defeat" % label)
		_expect(presentation != null,
			"%s: carries a defeat presentation" % label)
		_expect(showing,
			"%s: its defeat presentation is VISIBLY showing" % label)
		covered += 1

	print("[DEFCOV] enemies covered by the defeat path: %d / %d" % [covered, _candidates.size()])
	_expect(covered == _candidates.size(),
		"EVERY damageable enemy in the arena is covered by the defeat path")
	_done = true
	_report()


# --- Resolution ---------------------------------------------------------------

## Every damageable actor that is NOT the player: the arena's enemies. Enumeration,
## not a name list, so a new enemy is covered automatically.
func _enemy_candidates() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var body := health.get_parent()
		if body == null:
			continue
		if _is_player(body):
			continue
		out.append(body)
	# Sorted so the report is deterministic rather than depending on group order.
	out.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.name) < String(b.name))
	return out


## The player is the one actor whose Death component owns a RESET circuit. That flag
## is what makes it a player rather than an enemy, so it is what this asks.
func _is_player(body: Node) -> bool:
	var death := body.get_node_or_null("Death")
	if death == null:
		return false
	return "resets_actors" in death


func _presentation_of(body: Node) -> Node:
	var direct := body.get_node_or_null("DeathPresentation")
	if direct != null:
		return direct
	for child in body.get_children():
		if child.has_method("is_showing"):
			return child
	return null


# --- Damage -------------------------------------------------------------------

## One lethal blow through the existing receiving volume, which is the same route a
## real attack takes.
func _apply_lethal(actor: Node) -> bool:
	var hurtbox := _hurtbox_of(actor)
	if hurtbox != null:
		return hurtbox.receive_hit(_lethal_event())
	var health := _health_of(actor)
	if health != null:
		return health.apply_damage(_lethal_event())
	return false


func _lethal_event() -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = null
	return event


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


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[DEFCOV]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[DEFCOV]   FAIL  %s" % label)


func _report() -> void:
	print("[DEFCOV] --- summary ---")
	if _failures.is_empty():
		print("[DEFCOV] RESULT: ALL CHECKS PASSED")
	else:
		print("[DEFCOV] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
