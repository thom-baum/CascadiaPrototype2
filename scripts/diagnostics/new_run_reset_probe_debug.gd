class_name NewRunResetProbeDebug
extends Node3D
## Temporary diagnostic (not production): does a NEW RUN actually restore EVERY enemy to the
## state a fresh boot produces - health AND defeat, not only the player?
##
## WHY THIS EXISTS. `game_state_save._reset_world()` enumerates the `damageable` group and calls
## each actor's OWN `HealthComponent.reset()` and `restore_defeated(false)`. Read statically that
## is correct - and reading is exactly what cannot settle it. The reported symptom was a second
## enemy variant keeping its damage across a New Run. A reset that works for one actor and not
## another is a MEASUREMENT question, so this probe damages and kills the real arena actors
## through the production damage path, asks the real save service for a new run, and reads every
## value on both sides of it.
##
## It runs TWO cycles, because they fail differently:
##   PARTIAL  - damage without death: isolates "does health come back?"
##   LETHAL   - a real kill: isolates "does the DEFEAT state come back?" (soulslike reset)
##
## Per actor it measures: current/max health, is_dead, the defeat state, the number of
## HealthComponents (a second would be a duplicate authority), and whether the archetype profile
## is still applied with its own tuning afterwards.
##
## Actors are discovered through the project's OWN groups - the `enemy_attacker` group for the
## enemies and the `actor_state` group for the NPC - so a newly added enemy is covered the moment
## it exists rather than being silently missed by a written list.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 20
## Frames allowed after a damage pass for health, defeat and presentation to land.
const HOLD_FRAMES := 6
## Damage used for the non-lethal pass - small enough that nothing dies.
const PARTIAL := 30.0
## Damage used for the lethal pass - far above any actor's pool, so "lethal" never depends on tuning.
const LETHAL := 9999.0

const REPORT_PATH := "res://new_run_reset_probe_report.txt"

var _frame := 0
var _stage := 0
var _wait := 0
var _done := false
var _passed := 0
var _failures: Array = []
## One record per actor examined, with its live component references and authored maximum.
var _subjects: Array = []
## The report body, written at the end so a readable result exists even when the console does not
## surface a running game's prints.
var _lines: Array = []


## EARLY MARKER. A marker still in the file means this script ran but never reached its report,
## which separates "never executed" from "measured and reported".
func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: new-run reset probe loaded and _ready() executed")
		file.close()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	if _wait > 0:
		_wait -= 1
		return
	_stage += 1
	match _stage:
		1:
			_begin()
		2:
			_apply_damage(PARTIAL)
			_wait = HOLD_FRAMES
		3:
			_measure("after PARTIAL damage (expect damaged but alive)")
		4:
			_new_run("partial damage")
		5:
			_verify_restored("NEW RUN after partial damage")
		6:
			_apply_damage(LETHAL)
			_wait = HOLD_FRAMES
		7:
			_measure("after LETHAL damage (expect dead / defeated)")
		8:
			_new_run("a kill")
		9:
			_verify_restored("NEW RUN after a kill")
		10:
			_report()


# --- Setup --------------------------------------------------------------------

func _begin() -> void:
	EnemyAttacker.stand_down_all(get_tree())
	_gather()
	_lines.append("CASCADIA - NEW RUN WORLD-RESET PROBE (measured, not asserted)")
	_lines.append("")
	_lines.append("Actors examined (%d), discovered through project groups:" % _subjects.size())
	for subject in _subjects:
		_lines.append("  %-14s kind=%-5s path=%s" % [
			String(subject["label"]), String(subject["kind"]), String(subject["path"])])
	_lines.append("")
	if _subjects.is_empty():
		_fail("no actors found - nothing could be measured")


## Every enemy from the `enemy_attacker` group and the NPC from the `actor_state` group, so the
## subject list is derived from the project's own structure rather than written by hand.
func _gather() -> void:
	var enemies: Array = []
	for node in get_tree().get_nodes_in_group(EnemyAttacker.GROUP_ATTACKER):
		var attacker := node as EnemyAttacker
		if attacker == null or not is_instance_valid(attacker):
			continue
		var body := attacker.get_parent() as Node3D
		if body != null:
			enemies.append(body)
	# Sorted so the report is deterministic rather than depending on group order.
	enemies.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return String(a.name) < String(b.name))
	for body in enemies:
		_add_subject(body, "enemy")

	for node in get_tree().get_nodes_in_group(ActorState.GROUP_ACTOR_STATE):
		var state := node as ActorState
		if state == null:
			continue
		var body := state.get_actor()
		if body != null and _script_class_of(body) == "PassiveNpc":
			_add_subject(body, "npc")


func _add_subject(body: Node3D, kind: String) -> void:
	var health := _health_of(body)
	if health == null:
		_fail("%s: no HealthComponent" % String(body.name))
		return
	_subjects.append({
		"body": body,
		"kind": kind,
		"label": String(body.name),
		"path": String(body.get_path()),
		"health": health,
		"death": body.get_node_or_null("Death"),
		"profile": _profile_label(body, kind),
		"max": health.max_health,
	})


## The archetype's display name, read from whichever data layer this actor uses, so the report can
## show that the SAME archetype is still applied after a reset.
func _profile_label(body: Node3D, kind: String) -> String:
	if kind == "enemy":
		var attacker := body.get_node_or_null("Attacker") as EnemyAttacker
		if attacker != null and attacker.profile != null:
			return String(attacker.profile.display_name)
		return "NONE"
	if "profile" in body:
		var profile: Variant = body.get("profile")
		if profile != null:
			var name_value: Variant = profile.get("display_name")
			if name_value != null:
				return String(name_value)
	return "NONE"


# --- Actions -------------------------------------------------------------------

## One damage pass over every subject, through the real receiving volume - the same route a real
## attack takes - so this exercises the production chain rather than reaching around it.
func _apply_damage(amount: float) -> void:
	var applied := 0
	for subject in _subjects:
		var body: Node3D = subject["body"]
		if body == null or not is_instance_valid(body):
			continue
		var event := DamageEvent.new()
		event.amount = amount
		event.source = null
		var hurtbox := _hurtbox_of(body)
		if hurtbox != null:
			if hurtbox.receive_hit(event):
				applied += 1
		else:
			var health: HealthComponent = subject["health"]
			if health != null and health.apply_damage(event):
				applied += 1
	print("[NEWRUN] applied %.0f damage: %d subject(s) actually changed" % [amount, applied])
	_lines.append("Applied %.0f damage through the hurtbox chain: %d of %d subjects changed" % [
		amount, applied, _subjects.size()])
	_lines.append("")


## Ask the REAL service for a new run. Resolved by capability rather than by scene path so this
## probe keeps working if the service is moved.
func _new_run(label: String) -> void:
	var save := _save_service()
	if save == null:
		_fail("no New Run service found in the tree - the reset could not be asked for (%s)" % label)
		return
	var code: Variant = save.call("new_run")
	print("[NEWRUN] new_run() after %s returned %s" % [label, str(code)])
	_lines.append("new_run() after %s returned code %s" % [label, str(code)])
	_lines.append("")


# --- Measurement ---------------------------------------------------------------

func _measure(label: String) -> void:
	_lines.append("--- %s ---" % label)
	for subject in _subjects:
		_lines.append("  %-14s health=%.1f/%.1f is_dead=%s defeated=%s" % [
			String(subject["label"]), _current(subject), _max(subject),
			str(_is_dead(subject)), str(_is_defeated(subject))])
	_lines.append("")


## The load-bearing check: after a New Run every actor must be back at its OWN authored maximum,
## alive, with its defeat state cleared and its archetype intact.
func _verify_restored(label: String) -> void:
	_lines.append("--- %s: verification ---" % label)
	for subject in _subjects:
		var actor_label := String(subject["label"])
		var health: HealthComponent = subject["health"]
		if health == null or not is_instance_valid(health):
			_fail("%s: its HealthComponent is gone after the reset" % actor_label)
			continue
		var authored_max: float = float(subject["max"])
		_expect(is_equal_approx(health.current_health, authored_max),
			"%s: health restored to its authored maximum (%.1f / %.1f)" % [
				actor_label, health.current_health, authored_max])
		_expect(not health.is_dead, "%s: is_dead cleared by the reset" % actor_label)
		_expect(not _is_defeated(subject), "%s: defeat state cleared by the reset" % actor_label)
		_expect(_count_health(subject["body"]) == 1,
			"%s: still exactly ONE health authority" % actor_label)
		_lines.append("  %-14s health=%.1f/%.1f is_dead=%s defeated=%s archetype=%s" % [
			actor_label, health.current_health, health.max_health, str(health.is_dead),
			str(_is_defeated(subject)), String(subject["profile"])])
	_verify_profiles()
	_lines.append("")


## A reset must not retune anybody. Each enemy must still carry its own archetype and the exact
## tuning that archetype describes.
func _verify_profiles() -> void:
	for subject in _subjects:
		if String(subject["kind"]) != "enemy":
			continue
		var actor_label := String(subject["label"])
		var body: Node3D = subject["body"]
		var attacker := body.get_node_or_null("Attacker") as EnemyAttacker
		if attacker == null:
			_fail("%s: no attack machine after the reset" % actor_label)
			continue
		if attacker.profile == null:
			_fail("%s: its archetype profile is no longer assigned after the reset" % actor_label)
			continue
		var profile: EnemyAttackProfile = attacker.profile
		_expect(is_equal_approx(attacker.windup, profile.windup)
				and is_equal_approx(attacker.damage, profile.damage)
				and is_equal_approx(attacker.engage_range, profile.engage_range)
				and is_equal_approx(attacker.attack_cooldown, profile.attack_cooldown),
			"%s: live tuning still matches its archetype after the reset" % actor_label)
		_expect(attacker.attack != null,
			"%s: still attack-capable after the reset" % actor_label)
		_lines.append("  %-14s archetype=%s live(windup=%.2f damage=%.1f range=%.2f)" % [
			actor_label, String(profile.display_name), attacker.windup,
			attacker.damage, attacker.engage_range])


# --- Resolution ----------------------------------------------------------------

func _save_service() -> Node:
	var direct := get_node_or_null("Main/GameStateSave")
	if direct != null:
		return direct
	# Capability search, so this probe does not depend on a const name or a scene layout.
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_method("new_run") and node.has_method("delete_save"):
			return node
		for child in node.get_children():
			stack.append(child)
	return null


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


## How many HealthComponents this actor body carries. More than one would be a duplicate damage
## authority, which is the thing this pass must not introduce.
func _count_health(actor: Node) -> int:
	var count := 0
	if actor == null:
		return 0
	for child in actor.get_children():
		if child is HealthComponent:
			count += 1
	return count


func _script_class_of(body: Node) -> String:
	var script: Script = body.get_script() as Script
	if script == null:
		return ""
	return String(script.get_global_name())


func _current(subject: Dictionary) -> float:
	var health: HealthComponent = subject["health"]
	if health == null or not is_instance_valid(health):
		return -1.0
	return health.current_health


func _max(subject: Dictionary) -> float:
	var health: HealthComponent = subject["health"]
	if health == null or not is_instance_valid(health):
		return -1.0
	return health.max_health


func _is_dead(subject: Dictionary) -> bool:
	var health: HealthComponent = subject["health"]
	if health == null or not is_instance_valid(health):
		return true
	return health.is_dead


func _is_defeated(subject: Dictionary) -> bool:
	var death: Node = subject["death"]
	if death == null or not is_instance_valid(death):
		return false
	if not death.has_method("is_defeated"):
		return false
	return bool(death.call("is_defeated"))


# --- Reporting -----------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[NEWRUN]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[NEWRUN]   FAIL  %s" % label)


func _report() -> void:
	_lines.append("")
	if _failures.is_empty():
		_lines.append("RESULT: ALL CHECKS PASSED (%d)" % _passed)
		print("[NEWRUN] RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		_lines.append("RESULT: %d CHECK(S) FAILED (%d passed)" % [_failures.size(), _passed])
		print("[NEWRUN] RESULT: %d CHECK(S) FAILED (%d passed)" % [_failures.size(), _passed])
	_lines.append("")
	_lines.append("Failures:")
	if _failures.is_empty():
		_lines.append("  none")
	else:
		for failure in _failures:
			_lines.append("  - %s" % failure)

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		print("[NEWRUN] could not write report to %s" % REPORT_PATH)
		_done = true
		return
	file.store_string("\n".join(PackedStringArray(_lines)))
	file.close()
	print("[NEWRUN] report written to %s" % REPORT_PATH)
	_done = true
