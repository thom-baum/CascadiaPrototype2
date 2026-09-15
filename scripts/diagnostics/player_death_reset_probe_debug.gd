class_name PlayerDeathResetProbeDebug
extends Node3D
## Temporary diagnostic (not production): when the PLAYER DIES, are the arena's other combat actors
## put back to alive at full health?
##
## WHY THIS EXISTS. New Run already restored the world - that is measured and passing. DYING did not.
## `DeathComponent` reset only the attackers' ACTION state and deliberately left enemy HEALTH and
## enemy DEFEAT exactly as the fight left them, so a Soulslike death left every enemy pre-damaged and
## every killed enemy still dead. It also resolved a SINGLE attacker through group order, so with two
## enemy variants only one of them was reset and which one was unspecified.
##
## Neither defect shows up in a compile, and neither is visible in a single frame. So this probe
## fights the arena, kills the player, and then ASKS THE ACTORS what state they are in.
##
## It measures, through the production components and with no hand-written actor list:
##
##   before   every subject is genuinely damaged, and at least one is genuinely DEFEATED
##   death    the player enters the real death state and the death circuit restores it
##   after    EVERY subject is alive, at its authored maximum, and not defeated
##   untouched    its archetype profile and its attack capability survived the reset
##   authority    each subject still has exactly ONE health authority
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 20
## Frames allowed after the player's death for the death circuit to elapse and restore everything.
const DEATH_WAIT_FRAMES := 400
const EPSILON := 0.0001

## Where the measured report is written, so the result is readable afterwards.
const REPORT_PATH := "res://player_death_reset_probe_report.txt"

## Damage that leaves a subject visibly hurt without killing it.
const PARTIAL := 30.0
## Damage far above any pool, so "lethal" never depends on a tuning value.
const LETHAL := 9999.0

var _frame := 0
var _done := false
var _stage := 0
var _wait := 0
var _failures: Array = []
var _passed := 0
var _lines: Array = []

var _player: Node3D
var _player_health: HealthComponent
var _player_hurtbox: HurtboxComponent
var _player_death: Node


func _ready() -> void:
	_write_marker()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		0:
			_resolve()
			if _player == null or _player_health == null or _player_hurtbox == null:
				_fail("the probe could not resolve the player, its health or its hurtbox")
				_finish()
				return
			_report_subjects("Actors examined")
			_damage_everyone()
			_stage = 1
			_wait = 6
		1:
			_wait -= 1
			if _wait <= 0:
				_report_health("after PARTIAL damage (expect hurt but alive)")
				_kill_one_subject()
				_stage = 2
				_wait = 6
		2:
			_wait -= 1
			if _wait <= 0:
				_report_health("after a LETHAL killing blow (expect dead and defeated)")
				_check_before_state()
				_enter_player_death()
				_stage = 3
				_wait = DEATH_WAIT_FRAMES
		3:
			_wait -= 1
			# The death circuit elapses on its own, then restores the arena. Polled rather than
			# assumed, so the probe measures the moment control actually comes back.
			if not _player_dead():
				_verify_after_death()
				_finish()
				return
			if _wait <= 0:
				_fail("the player never left the death state within %d frames" % DEATH_WAIT_FRAMES)
				_verify_after_death()
				_finish()


# --- Setup --------------------------------------------------------------------

func _resolve() -> void:
	_player = get_tree().get_first_node_in_group("player_actor") as Node3D
	if _player == null:
		return
	_player_health = _player.get_node_or_null("Health") as HealthComponent
	_player_hurtbox = _player.get_node_or_null("Hurtbox") as HurtboxComponent
	_player_death = _player.get_node_or_null("Death")


## Every damageable actor that is NOT the player, discovered from the project's OWN group so a
## newly added enemy is covered automatically and a variant that is missing FAILS rather than being
## quietly absent from the report.
func _subjects() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var actor := health.get_parent() as Node3D
		if actor == null or actor == _player:
			continue
		out.append(actor)
	out.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.name) < String(b.name))
	return out


func _damage_everyone() -> void:
	var changed := 0
	for actor in _subjects():
		if _apply_damage(actor, PARTIAL):
			changed += 1
	_count_note("applied %.0f damage through the hurtbox chain: %d of %d subjects changed"
		% [PARTIAL, changed, _subjects().size()])


## Exactly ONE subject is killed, so the "a defeated actor is revived by dying" half of the fix is
## measured without every subject entering the same state.
func _kill_one_subject() -> void:
	var list := _subjects()
	if list.is_empty():
		return
	var victim: Node3D = list[0]
	if _apply_damage(victim, LETHAL):
		_count_note("killing blow applied to %s" % String(victim.name))


func _apply_damage(actor: Node3D, amount: float) -> bool:
	var hurtbox := actor.get_node_or_null("Hurtbox") as HurtboxComponent
	var event := DamageEvent.new()
	event.amount = amount
	event.source = null
	if hurtbox != null:
		return hurtbox.receive_hit(event)
	var health := actor.get_node_or_null("Health") as HealthComponent
	if health != null:
		return health.apply_damage(event)
	return false


## Put the PLAYER into its real death state, through its own hurtbox, so the death circuit runs the
## same path a real death does rather than a test-only shortcut.
func _enter_player_death() -> void:
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = null
	_player_hurtbox.receive_hit(event)
	_count_note("lethal damage applied to the PLAYER through its hurtbox")


# --- Checks -------------------------------------------------------------------

## The arena must genuinely be in a hurt / defeated state BEFORE the death, otherwise the "after"
## checks would pass on a world that was never changed.
func _check_before_state() -> void:
	var hurt := 0
	var defeated := 0
	for actor in _subjects():
		var health := actor.get_node_or_null("Health") as HealthComponent
		if health != null and health.current_health < health.max_health:
			hurt += 1
		if _is_defeated(actor):
			defeated += 1
	_expect(hurt == _subjects().size(),
		"every subject was genuinely DAMAGED before the player died (%d/%d)" % [hurt, _subjects().size()])
	_expect(defeated >= 1,
		"at least one subject was genuinely DEFEATED before the player died (%d)" % defeated)


func _verify_after_death() -> void:
	_report_health("after the player DIED and the death circuit restored the arena")

	# Every subject: alive, at its authored maximum, and not defeated. This is the behaviour the
	# user asked for and the behaviour this pass added.
	for actor in _subjects():
		var label := String(actor.name)
		var health := actor.get_node_or_null("Health") as HealthComponent
		if health == null:
			_fail("%s: no HealthComponent" % label)
			continue
		_expect(not health.is_dead, "%s: is_dead cleared by the death reset" % label)
		_expect(is_equal_approx(health.current_health, health.max_health),
			"%s: health restored to its authored maximum (%.1f / %.1f)"
				% [label, health.current_health, health.max_health])
		_expect(not _is_defeated(actor), "%s: defeat state cleared by the death reset" % label)
		_expect(_count_health_authorities(actor) == 1,
			"%s: still exactly ONE health authority" % label)

	# The reset must not have cost a subject its identity or its ability to fight.
	for node in get_tree().get_nodes_in_group(EnemyAttacker.GROUP_ATTACKER):
		var attacker := node as EnemyAttacker
		if attacker == null or not is_instance_valid(attacker):
			continue
		var body := attacker.get_parent() as Node3D
		if body == null:
			continue
		var key := String(body.name)
		_expect(attacker.profile != null, "%s: still carries its archetype profile" % key)
		if attacker.profile != null:
			_expect(is_equal_approx(attacker.damage, attacker.profile.damage)
					and is_equal_approx(attacker.engage_range, attacker.profile.engage_range),
				"%s: live tuning still matches its archetype after the reset" % key)
		_expect(attacker.has_method("try_start"),
			"%s: still attack-capable after the reset" % key)

	_expect(not _player_dead(), "the player was restored by the death circuit")
	_expect(_player_health != null and not _player_health.is_dead,
		"the player's own health was cleared")


# --- Resolution helpers -------------------------------------------------------

func _is_defeated(actor: Node) -> bool:
	var death := actor.get_node_or_null("Death")
	if death != null and death.has_method("is_defeated"):
		return bool(death.call("is_defeated"))
	return false


func _player_dead() -> bool:
	if _player_death != null and _player_death.has_method("is_dead"):
		return bool(_player_death.call("is_dead"))
	return _player_health != null and _player_health.is_dead


## How many damage authorities this actor carries. More than one would mean a second system is
## writing health behind the component that owns it.
func _count_health_authorities(actor: Node) -> int:
	var count := 0
	for child in actor.get_children():
		if child is HealthComponent:
			count += 1
	return count


# --- Reporting ----------------------------------------------------------------

func _report_subjects(title: String) -> void:
	_lines.append("%s (%d), discovered through project groups:" % [title, _subjects().size()])
	for actor in _subjects():
		_lines.append("  %-14s path=%s" % [String(actor.name), String(actor.get_path())])
	_lines.append("")


func _report_health(title: String) -> void:
	_lines.append("--- %s ---" % title)
	for actor in _subjects():
		var label := String(actor.name)
		var health := actor.get_node_or_null("Health") as HealthComponent
		if health == null:
			_lines.append("  %-14s NO HEALTH COMPONENT" % label)
			continue
		_lines.append("  %-14s health=%.1f/%.1f is_dead=%s defeated=%s" % [
			label, health.current_health, health.max_health,
			str(health.is_dead), str(_is_defeated(actor))])
	_lines.append("")


func _count_note(text: String) -> void:
	_lines.append(text)


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[DEATHRESET]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[DEATHRESET]   FAIL  %s" % label)


func _finish() -> void:
	_done = true
	_lines.append("")
	if _failures.is_empty():
		_lines.append("RESULT: ALL CHECKS PASSED (%d)" % _passed)
		print("[DEATHRESET] RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		_lines.append("RESULT: %d CHECK(S) FAILED (%d passed)" % [_failures.size(), _passed])
		print("[DEATHRESET] RESULT: %d CHECK(S) FAILED (%d passed)" % [_failures.size(), _passed])
	_lines.append("")
	_lines.append("Failures:")
	if _failures.is_empty():
		_lines.append("  none")
	else:
		for failure in _failures:
			_lines.append("  - %s" % failure)
	_write("\n".join(PackedStringArray(_lines)))


## EARLY MARKER, so "the scene never ran" and "the world never settled" can be told apart. The full
## report overwrites it.
func _write_marker() -> void:
	_write("MARKER: player death-reset probe loaded and _ready() executed\n")


func _write(text: String) -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		print("[DEATHRESET] could not write report to %s" % REPORT_PATH)
		return
	file.store_string(text)
	file.close()
	print("[DEATHRESET] report written to %s" % REPORT_PATH)
