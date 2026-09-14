class_name GameStateSaveLoadProbeDebug
extends Node3D
## Temporary diagnostic (not production): is Cascadia's FIRST persistence loop actually real?
##
## The whole claim of Milestone 10 is:
##
##     defeat enemies -> carry Credits -> save the real state -> change the state -> load it back
##
## A probe that built a dictionary and called JSON on it would prove nothing about the game. So this
## probe drives the REAL `CreditLedger` through its REAL API and the REAL `GameStateSave` against the
## REAL save path, and it earns Credits the same way the game does - by killing enemies through the
## damage chain.
##
## IT ALSO PROVES THE FAILURE MODES, because a save system is only as good as what it does when the
## data is wrong. Missing, malformed, wrong-version, missing-field and invalid-value saves must each
## fail with their OWN result and leave the carried balance UNTOUCHED.
##
## SAVE-FILE SAFETY: this probe writes to the real save path, so it takes a backup of whatever was
## there and puts it back at the end. Running it does not destroy real progress.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 12
## Damage used for a lethal blow - far above any actor's pool.
const LETHAL := 9999.0
## Added to the balance after the first real kill purely to make the saved value DISTINCT from both
## the starting value and the value one kill would produce, so "load did nothing" cannot pass.
const BONUS := 250
## Added after saving, so the balance is provably different from what was written.
const AFTER_SAVE_BONUS := 900

var _frame := 0
var _done := false
var _failures: Array = []

var _ledger: CreditLedger
var _save: GameStateSave
## Two distinct eligible enemies: one killed before the save, one killed after the load.
var _enemy_a: Node
var _enemy_b: Node
var _saved_value := 0
## The save file as it was found, so the probe leaves the project as it found it.
var _backup_text := ""
var _had_save := false


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_run()
	_done = true


func _run() -> void:
	print("[SAVEPROBE] --- game-state save/load audit (measured) ---")
	_enemy_a = null
	_enemy_b = null
	_resolve()

	if _ledger == null or _save == null or _enemy_a == null or _enemy_b == null:
		_fail("could not resolve the ledger, the save service and two eligible enemies")
		_report()
		return

	_stand_down_ambient_attackers()
	print("[SAVEPROBE] resolved: ledger=%s save=%s enemies=%s,%s path=%s" % [
		_ledger.name, _save.name, _name_of(_enemy_a), _name_of(_enemy_b), _save.save_path()])

	_check_no_save()
	_check_schema_and_save()
	_check_change_after_save()
	_check_load()
	_check_real_defeat_after_load()
	_check_bad_data()
	_check_new_run()
	_restore_backup()
	_report()


# --- The loop, step by step ---------------------------------------------------

## AC12 (first half): with no save present, loading fails CLEARLY and changes nothing.
func _check_no_save() -> void:
	_had_save = _save.has_save()
	if _had_save:
		_backup_text = _read_raw()
	_save.delete_save()

	var balance_before := _ledger.get_credits()
	var code := _save.load_game()
	print("[SAVEPROBE] no save present: load=%s  balance %d -> %d" % [
		GameStateSave.result_name(code), balance_before, _ledger.get_credits()])

	_expect(not _save.has_save(), "a fresh run genuinely has NO save file")
	_expect(code == GameStateSave.Result.NO_SAVE, "loading with no save reports NO_SAVE")
	_expect(_ledger.get_credits() == balance_before,
		"a failed load left the carried balance UNTOUCHED")


## AC1-AC4: establish a KNOWN value through the ledger, save it, and read the file back.
func _check_schema_and_save() -> void:
	# AC1. Reset to the documented starting value, then EARN through the real path: kill a real
	# enemy and let the existing defeat authority pay through the ledger's own signal handler.
	_ledger.reset_credits()
	var starting := _ledger.credits
	var reward := int(_ledger.reward_per_enemy)

	var killed := _kill(_enemy_a)
	print("[SAVEPROBE] established baseline: starting=%d  killed=%s (%s)  balance=%d" % [
		starting, str(killed), _name_of(_enemy_a), _ledger.get_credits()])
	_expect(killed, "the first eligible enemy was killed through the real damage chain")
	_expect(_ledger.get_credits() == starting + reward,
		"a real enemy defeat paid %d into the carried balance" % reward)

	# Make the value distinctive so a no-op load cannot pass by coincidence.
	_ledger.award_credits(BONUS, "probe")
	_saved_value = _ledger.get_credits()
	_expect(_saved_value == starting + reward + BONUS,
		"the known balance to be saved is %d" % _saved_value)

	# AC2. Save.
	var code := _save.save_game()
	_expect(code == GameStateSave.Result.OK, "saving succeeded")

	# AC3/AC4. The FILE itself carries the expected schema and the right value - read from disk,
	# not from the in-memory payload that produced it.
	_expect(_save.has_save(), "saving created a real save file on disk")
	var text := _read_raw()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		_fail("the written save file is not a JSON object")
		return
	var data: Dictionary = parsed
	var version := int(data.get("schema_version", -1))
	var stored := int(data.get("carried_credits", -1))
	print("[SAVEPROBE] save file: schema_version=%d  carried_credits=%d  bytes=%d" % [
		version, stored, text.length()])
	_expect(version == GameStateSave.SCHEMA_VERSION,
		"the save file carries schema_version %d" % GameStateSave.SCHEMA_VERSION)
	_expect(data.has("saved_at_unix"), "the save file records when it was written")
	_expect(stored == _saved_value,
		"the save file holds the carried balance that was saved (%d)" % _saved_value)


## AC5: change the balance AFTER saving. The file must not follow it.
func _check_change_after_save() -> void:
	_ledger.award_credits(AFTER_SAVE_BONUS, "probe")
	var live := _ledger.get_credits()
	print("[SAVEPROBE] after saving, balance changed to %d (save still holds %d)" % [
		live, _read_int_field("carried_credits")])

	_expect(live != _saved_value, "the live balance now differs from the saved one")
	_expect(_read_int_field("carried_credits") == _saved_value,
		"changing the balance did NOT rewrite the save (a save is a snapshot, not a mirror)")


## AC6-AC9 and AC13: load restores exactly, and is not an award.
func _check_load() -> void:
	var awards_before := _ledger.awards
	var rewarded_before := _ledger.rewarded_count()
	var earned_before := _ledger.credits_earned
	var loads_before := _ledger.loads
	var defeated_before := _is_defeated(_enemy_a)
	var balance_before := _ledger.get_credits()

	var code := _save.load_game()
	print("[SAVEPROBE] load: %s  balance %d -> %d  earned %d -> %d" % [
		GameStateSave.result_name(code), balance_before, _ledger.get_credits(),
		earned_before, _ledger.credits_earned])

	_expect(code == GameStateSave.Result.OK, "loading an intact save succeeds")
	_expect(_ledger.get_credits() == _saved_value,
		"loading restored the EXACT saved balance (%d)" % _saved_value)
	# AC8: a load is not a defeat. THESE two counters are the real proof - they must not move at all.
	_expect(_ledger.awards == awards_before, "loading granted NO award")
	_expect(_ledger.rewarded_count() == rewarded_before,
		"loading did NOT mark any actor as paid")
	# `credits_earned` is a DIAGNOSTIC of this run's earnings, and restore_carried_credits() deliberately
	# RE-BASES it to the restored total: the restored balance IS this run's earnings as of the save
	# point, so a frozen value would make earned and carried disagree. It is therefore checked for
	# CONSISTENCY with the restored balance rather than for being unchanged - the documented contract.
	_expect(_ledger.credits_earned == _ledger.get_credits(),
		"after a load the earned total agrees with the restored balance (%d)" % _ledger.credits_earned)
	_expect(_ledger.loads == loads_before + 1, "the ledger counted the restoration")
	# AC10: this milestone's save contract does NOT persist defeated enemies, so nothing revives them.
	# `_enemy_a` was killed BEFORE the save, so it must still be defeated after the load. (The earlier
	# form of this check inverted itself and could never pass; it is fixed here.)
	_expect(defeated_before and _is_defeated(_enemy_a),
		"the enemy defeated before the save is still defeated after the load")

	# AC11 (first half): repeat loads must not compound.
	var repeat_a := _save.load_game()
	var repeat_b := _save.load_game()
	_expect(repeat_a == GameStateSave.Result.OK and repeat_b == GameStateSave.Result.OK,
		"loading repeatedly keeps succeeding")
	_expect(_ledger.get_credits() == _saved_value,
		"repeated loads did not compound the balance (still %d)" % _saved_value)
	_expect(_ledger.awards == awards_before,
		"repeated loads granted no extra awards")


## AC9: the defeat economy still works normally AFTER a load - a real kill pays exactly once.
func _check_real_defeat_after_load() -> void:
	var awards_before := _ledger.awards
	var balance_before := _ledger.get_credits()
	var reward := int(_ledger.reward_per_enemy)

	var killed := _kill(_enemy_b)
	var gained := _ledger.get_credits() - balance_before
	print("[SAVEPROBE] real defeat AFTER a load: killed=%s  gained=%d  awards %d -> %d" % [
		str(killed), gained, awards_before, _ledger.awards])

	_expect(killed, "a second eligible enemy was killed after the load")
	_expect(gained == reward, "the post-load defeat awarded exactly %d" % reward)
	_expect(_ledger.awards == awards_before + 1,
		"the post-load defeat was counted as ONE award, not duplicated")


## AC11: missing, malformed, wrong-version, missing-field and invalid-value saves each fail with
## their OWN result, and none of them touches the balance.
func _check_bad_data() -> void:
	var balance_before := _ledger.get_credits()

	var cases := [
		{"label": "not JSON at all", "text": "this is not json {{{",
			"expect": GameStateSave.Result.MALFORMED},
		{"label": "JSON that is not an object", "text": "[1, 2, 3]",
			"expect": GameStateSave.Result.MALFORMED},
		{"label": "unsupported schema_version", "text": '{"schema_version": 99, "carried_credits": 7}',
			"expect": GameStateSave.Result.UNSUPPORTED_VERSION},
		{"label": "no schema_version", "text": '{"carried_credits": 7}',
			"expect": GameStateSave.Result.MISSING_FIELD},
		# These three carry a VALID schema and a complete run and player block, so they reach the
		# carried_credits check their label names. An earlier version hardcoded schema_version 1 and
		# omitted run/player, so all three stopped at unsupported-version and tested nothing.
		{"label": "no carried_credits",
			"text": '{"schema_version": %d, "run": {"id": "x", "started_unix": 1}, "player": {"alive": true}}' % GameStateSave.SCHEMA_VERSION,
			"expect": GameStateSave.Result.MISSING_FIELD},
		{"label": "carried_credits is text",
			"text": '{"schema_version": %d, "run": {"id": "x", "started_unix": 1}, "carried_credits": "lots", "player": {"alive": true}}' % GameStateSave.SCHEMA_VERSION,
			"expect": GameStateSave.Result.INVALID_VALUE},
		{"label": "carried_credits is negative",
			"text": '{"schema_version": %d, "run": {"id": "x", "started_unix": 1}, "carried_credits": -5, "player": {"alive": true}}' % GameStateSave.SCHEMA_VERSION,
			"expect": GameStateSave.Result.INVALID_VALUE},
		{"label": "empty file", "text": "",
			"expect": GameStateSave.Result.MALFORMED},
	]

	for case in cases:
		_write_raw(String(case["text"]))
		var code := _save.load_game()
		print("[SAVEPROBE] bad data (%s): %s  balance %d -> %d" % [
			String(case["label"]), GameStateSave.result_name(code),
			balance_before, _ledger.get_credits()])
		_expect(code == int(case["expect"]),
			"%s fails as %s (got %s)" % [
				String(case["label"]), GameStateSave.result_name(int(case["expect"])),
				GameStateSave.result_name(code)])
		_expect(_ledger.get_credits() == balance_before,
			"%s left the carried balance untouched" % String(case["label"]))

	# A save removed entirely is a different result from a save that is present but wrong.
	_save.delete_save()
	var missing := _save.load_game()
	_expect(missing == GameStateSave.Result.NO_SAVE,
		"a deleted save reports NO_SAVE, distinctly from a corrupt one")


## AC12: a new run is distinguishable from a load, and cannot masquerade as one.
func _check_new_run() -> void:
	var code := _save.new_run()
	var balance := _ledger.get_credits()
	print("[SAVEPROBE] new run: %s  balance=%d  starting=%d  has_save=%s" % [
		GameStateSave.result_name(code), balance, _ledger.starting_credits,
		str(_save.has_save())])

	_expect(code == GameStateSave.Result.OK, "starting a new run succeeds")
	_expect(balance == _ledger.starting_credits,
		"a new run resets the balance to the documented starting value (%d)" % _ledger.starting_credits)
	_expect(balance != _saved_value, "a new run is NOT the saved state")
	_expect(not _save.has_save(), "a new run removed the save file")

	var after := _save.load_game()
	_expect(after == GameStateSave.Result.NO_SAVE,
		"after a new run there is nothing to load, so a fresh run cannot look like a load")
	_expect(_ledger.get_credits() == _ledger.starting_credits,
		"the refused post-reset load left the fresh balance alone")


# --- Resolution ---------------------------------------------------------------

func _resolve() -> void:
	_ledger = CreditLedger.find_ledger(get_tree())
	_save = GameStateSave.find_save(get_tree())

	# The eligible population is discovered from the defeat authority's own group, so this probe
	# does not depend on a hand-written actor list.
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var actor := node.get_parent()
		if actor == null or not is_instance_valid(actor):
			continue
		if actor.is_in_group(CreditLedger.GROUP_PLAYER_ACTOR):
			continue
		var health := _health_of(actor)
		if health == null or health.is_dead:
			continue
		if _enemy_a == null:
			_enemy_a = node
		elif _enemy_b == null:
			_enemy_b = node
			break


func _stand_down_ambient_attackers() -> void:
	EnemyAttacker.stand_down_all(get_tree())


# --- Helpers ------------------------------------------------------------------

func _kill(component: Node) -> bool:
	var actor := component.get_parent()
	if actor == null:
		return false
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = null
	var hurtbox := _hurtbox_of(actor)
	if hurtbox != null:
		return hurtbox.receive_hit(event)
	var health := _health_of(actor)
	if health == null:
		return false
	return health.apply_damage(event)


func _is_defeated(component: Node) -> bool:
	if component == null or not component.has_method("is_defeated"):
		return false
	return bool(component.call("is_defeated"))


func _health_of(actor: Node) -> HealthComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		var health := child as HealthComponent
		if health != null:
			return health
	return null


func _hurtbox_of(actor: Node) -> HurtboxComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		var hurtbox := child as HurtboxComponent
		if hurtbox != null:
			return hurtbox
	return null


func _name_of(component: Node) -> String:
	if component == null:
		return "?"
	var actor := component.get_parent()
	return "?" if actor == null else String(actor.name)


## The save file's raw text, read from DISK so the measurement is of the artifact, not of memory.
func _read_raw() -> String:
	var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _read_int_field(field: String) -> int:
	var parsed: Variant = JSON.parse_string(_read_raw())
	if parsed == null or not (parsed is Dictionary):
		return -1
	return int((parsed as Dictionary).get(field, -1))


func _write_raw(text: String) -> bool:
	var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


## Put the save file back the way it was found, so running a diagnostic is not destructive.
func _restore_backup() -> void:
	if _had_save:
		_write_raw(_backup_text)
		print("[SAVEPROBE] restored the pre-existing save file (%d bytes)" % _backup_text.length())
	else:
		_save.delete_save()
		print("[SAVEPROBE] removed the probe's save (there was none before this run)")


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, text: String) -> void:
	if condition:
		print("[SAVEPROBE]   PASS  %s" % text)
	else:
		_failures.append(text)
		print("[SAVEPROBE]   FAIL  %s" % text)


func _fail(text: String) -> void:
	_failures.append(text)
	print("[SAVEPROBE]   FAIL  %s" % text)


func _report() -> void:
	print("[SAVEPROBE] --- summary ---")
	if _failures.is_empty():
		print("[SAVEPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[SAVEPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
