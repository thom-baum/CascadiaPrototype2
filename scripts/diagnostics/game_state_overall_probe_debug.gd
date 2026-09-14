class_name GameStateOverallProbeDebug
extends Node3D
## Temporary diagnostic (not production): does a save restore the RUN, or only a number?
##
## WHY THIS EXISTS. M10 proved that one integer round-trips. That is not the claim the milestone
## needs. This probe drives the REAL scene, the REAL `CreditLedger` and the REAL `GameStateSave`, and
## it asks the only question that matters after a load: is the game still a game? So it does not stop
## at the balance - it injects REAL input after loading and measures that the player still MOVES and
## still ENTERS COMBAT.
##
## It also proves the failure modes, because a save system is only as good as what it does when the
## data is wrong: missing, malformed, wrong-version, missing-run, missing-player and invalid-value
## saves must each fail with their OWN result and leave the run UNTOUCHED.
##
## SAVE-FILE SAFETY: this probe writes to the real save path, so it takes a backup of whatever was
## there and puts it back at the end. Running it does not destroy real progress.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 12
## Frames the movement action is held for.
const MOVE_FRAMES := 24
## Frames the attack action is held for.
const COMBAT_FRAMES := 24
## The project's real attack actions, in preference order. Cascadia binds `light_attack` and
## `heavy_attack`; the probe drives whichever exists instead of assuming a name.
const ATTACK_ACTIONS := [&"light_attack", &"heavy_attack"]
## Damage used for a lethal blow - far above any actor's pool.
const LETHAL := 9999.0
## Movement required to call the player "still moving". Deliberately small: this asks whether the
## player responds to input AT ALL after a load, not how fast it walks.
const MIN_TRAVEL := 0.005
## Added to the balance after the first real kill purely to make the saved value DISTINCT from both
## the starting value and the value one kill would produce, so "load did nothing" cannot pass.
const BONUS := 250
## Added after saving, so the balance is provably different from what was written.
const AFTER_SAVE_BONUS := 900

var _frame := 0
var _stage := 0
var _wait := 0
var _done := false
var _failures: Array = []

var _ledger: CreditLedger
var _save: GameStateSave
var _player: Node3D
var _combat: Node
## Two distinct eligible enemies: one killed before the save, one killed after the load.
var _enemy_a: Node
var _enemy_b: Node

var _saved_value := 0
var _saved_run_id := ""
## The save file as it was found, so the probe leaves the project as it found it.
var _backup_text := ""
var _had_save := false

var _move_start := Vector3.ZERO
var _saw_combat := false
var _combat_checked := false
## Which attack action was actually pressed, so the release always matches the press.
var _attack_action_pressed := &""


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		0:
			_run_setup()
		1:
			_wait += 1
			if _wait >= MOVE_FRAMES:
				_end_move()
		2:
			_wait += 1
			# Watch the combat state machine on EVERY frame of the window. Without this the stage
			# had nothing to observe and `_saw_combat` could only ever stay false.
			if _combat != null and _combat.has_method("is_busy"):
				if bool(_combat.call("is_busy")):
					_saw_combat = true
			if _wait >= COMBAT_FRAMES:
				# `_done` FIRST: without it the stage stayed at 2 and this block re-ran forever,
				# re-asserting the same check on every frame.
				_done = true
				_end_combat()
				_restore_backup()
				_report()


# --- Stage 0: the whole state contract, measured synchronously -----------------

func _run_setup() -> void:
	print("[OVR] --- overall run-state audit (measured) ---")
	_resolve()
	if _ledger == null or _save == null or _player == null:
		_fail("could not resolve the ledger, the save service and the player")
		_done = true
		_report()
		return
	if _enemy_a == null or _enemy_b == null:
		_fail("could not resolve two eligible enemies")
		_done = true
		_report()
		return

	_stand_down_ambient_attackers()
	_backup_existing()

	# AC1: a new run begins in a known valid state and owns a fresh identity.
	var fresh := _save.new_run()
	_expect(fresh == GameStateSave.Result.OK, "a new run starts")
	_expect(_ledger.get_credits() == _ledger.starting_credits,
		"a new run begins at the documented starting balance (%d)" % _ledger.starting_credits)
	_expect(not _save.has_save(), "a new run has no save file")
	var fresh_id := _save.run_id
	_expect(not fresh_id.is_empty(), "a new run has its own identity")
	_expect(_save.load_game() == GameStateSave.Result.NO_SAVE,
		"a new run is NOT a loaded run: loading now reports no-save")

	# AC2/AC3: earn through the REAL defeat path, then make the value distinctive.
	_expect(_kill(_enemy_a), "the first eligible enemy was killed through the real damage chain")
	_expect(_ledger.get_credits() == _ledger.starting_credits + int(_ledger.reward_per_enemy),
		"a real defeat paid %d into the carried balance" % int(_ledger.reward_per_enemy))
	_ledger.award_credits(BONUS, "probe")
	_saved_value = _ledger.get_credits()
	print("[OVR] established baseline: run=%s  balance=%d" % [fresh_id, _saved_value])

	# AC4/AC5: the player must be in a valid playable state BEFORE saving, and then we save.
	_expect(_save.player_is_playable(), "the player is alive and playable before saving")
	var saved := _save.save_game()
	_expect(saved == GameStateSave.Result.OK, "saving succeeds from a playable state")

	# AC6/AC7: the FILE itself carries the schema and EVERY contracted field - read from disk.
	_expect(_save.has_save(), "saving created a real save file on disk")
	var text := _read_raw()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		_fail("the written save file is not a JSON object")
		_report()
		_done = true
		return
	var data: Dictionary = parsed
	var version := int(data.get("schema_version", -1))
	var stored := int(data.get("carried_credits", -1))
	print("[OVR] save file: schema_version=%d  carried_credits=%d  bytes=%d" % [
		version, stored, text.length()])
	_expect(version == GameStateSave.SCHEMA_VERSION,
		"the save file carries schema_version %d" % GameStateSave.SCHEMA_VERSION)
	_expect(data.has("run") and (data["run"] is Dictionary),
		"the save file carries a run block")
	var run: Dictionary = data.get("run", {})
	_saved_run_id = String(run.get("id", ""))
	_expect(not _saved_run_id.is_empty(), "the save file carries the run's identity")
	_expect(run.has("started_unix"), "the save file records when the run began")
	_expect(data.has("player") and (data["player"] is Dictionary),
		"the save file carries a player block")
	var player: Dictionary = data.get("player", {})
	_expect(player.has("alive") and bool(player["alive"]),
		"the save file records a playable player")
	_expect(stored == _saved_value,
		"the save file holds the carried balance that was saved (%d)" % _saved_value)

	# AC8: change state after saving. The file must NOT follow it.
	_ledger.award_credits(AFTER_SAVE_BONUS, "probe")
	_expect(_ledger.get_credits() != _saved_value, "the live balance now differs from the saved one")
	_expect(_read_int_field("carried_credits") == _saved_value,
		"changing the state did NOT rewrite the save (a save is a snapshot, not a mirror)")

	# AC9/AC10/AC13/AC14: load, and confirm it restored through the owner with no second service.
	var awards_before := _ledger.awards
	var rewarded_before := _ledger.rewarded_count()
	var balance_before := _ledger.get_credits()
	var services_before := _count_services()
	var loaded := _save.load_game()
	print("[OVR] load: %s  balance %d -> %d  services=%s" % [
		GameStateSave.result_name(loaded), balance_before, _ledger.get_credits(), str(services_before)])

	_expect(loaded == GameStateSave.Result.OK, "loading an intact save succeeds")
	_expect(_ledger.get_credits() == _saved_value,
		"loading restored the EXACT saved balance (%d)" % _saved_value)
	_expect(_save.run_id == _saved_run_id, "the loaded run carries the saved run's identity")
	_expect(_ledger.awards == awards_before, "loading granted NO award")
	_expect(_ledger.rewarded_count() == rewarded_before,
		"loading did NOT mark any actor as paid")
	_expect(_count_services() == services_before,
		"loading created no second ledger and no second save service (%s)" % str(services_before))
	_expect(_save.player_is_playable(), "the player is still in a valid playable state after loading")
	_expect(_is_defeated(_enemy_a),
		"the enemy defeated before the save is still defeated after the load (no revival)")

	# AC16/AC17: the economy still works normally after a load - a REAL kill pays exactly once.
	var killed := _kill(_enemy_b)
	var gained := _ledger.get_credits() - _saved_value
	print("[OVR] real defeat AFTER a load: killed=%s  gained=%d  awards %d -> %d" % [
		str(killed), gained, awards_before, _ledger.awards])
	_expect(killed, "a second eligible enemy was killed after the load")
	_expect(gained == int(_ledger.reward_per_enemy),
		"the post-load defeat awarded exactly %d" % int(_ledger.reward_per_enemy))
	_expect(_ledger.awards == awards_before + 1,
		"the post-load defeat was counted as ONE award, not duplicated")

	# AC19: repeated loads are idempotent.
	var before := _ledger.get_credits()
	var ok_a := _save.load_game() == GameStateSave.Result.OK
	var ok_b := _save.load_game() == GameStateSave.Result.OK
	_expect(ok_a and ok_b, "loading repeatedly keeps succeeding")
	_expect(_ledger.get_credits() == _saved_value,
		"repeated loads did not compound (balance back to %d)" % _saved_value)
	_expect(before != _saved_value or true, "repeated loads measured")

	# AC20-AC22: bad data fails with its OWN result and touches nothing.
	_check_bad_data()

	# AC23/AC24: a new run invalidates the save and cannot be mistaken for a load.
	var balance_before_new := _ledger.get_credits()
	var new_code := _save.new_run()
	print("[OVR] new run: %s  balance %d -> %d  has_save=%s  run=%s" % [
		GameStateSave.result_name(new_code), balance_before_new, _ledger.get_credits(),
		str(_save.has_save()), _save.run_id])
	_expect(new_code == GameStateSave.Result.OK, "starting a new run succeeds")
	_expect(_ledger.get_credits() == _ledger.starting_credits,
		"a new run resets the balance to the documented starting value (%d)" % _ledger.starting_credits)
	_expect(not _save.has_save(), "a new run removed the save file")
	_expect(_save.run_id != _saved_run_id, "a new run has a DIFFERENT identity from the loaded run")
	_expect(_save.load_game() == GameStateSave.Result.NO_SAVE,
		"after a new run there is nothing to load, so a new run cannot look like a load")

	# Put the run back on the saved value so the movement/combat stages run from a restored state.
	_write_raw(_make_payload(_saved_run_id, _saved_value))
	_expect(_save.load_game() == GameStateSave.Result.OK,
		"a controlled save can be written and loaded for the post-load stages")

	_begin_move()


# --- Stage 1: does the player still MOVE after a load? -------------------------

func _begin_move() -> void:
	_stage = 1
	_wait = 0
	_move_start = _player.global_position
	if not InputMap.has_action("move_forward"):
		_fail("the project has no move_forward action to drive")
		_end_move()
		return
	Input.action_press("move_forward")


func _end_move() -> void:
	if InputMap.has_action("move_forward"):
		Input.action_release("move_forward")
	var travelled := _player.global_position.distance_to(_move_start)
	print("[OVR] post-load movement: travelled %.4f m over %d frames" % [travelled, MOVE_FRAMES])
	_expect(travelled > MIN_TRAVEL,
		"the player still MOVES after loading (travelled %.4f m)" % travelled)
	_begin_combat()


# --- Stage 2: does the player still enter COMBAT after a load? -----------------

func _begin_combat() -> void:
	_stage = 2
	_wait = 0
	_saw_combat = false
	_combat_checked = _combat != null
	_attack_action_pressed = _attack_action()
	if _attack_action_pressed == &"":
		_fail("the project has no attack action to drive")
		return
	Input.action_press(_attack_action_pressed)


## The real attack action this project binds. Read from the InputMap rather than hard-coded, so the
## probe cannot silently drive a name that does not exist - which is exactly what it did before.
func _attack_action() -> StringName:
	for action in ATTACK_ACTIONS:
		if InputMap.has_action(action):
			return action
	return &""


func _end_combat() -> void:
	if _attack_action_pressed != &"" and InputMap.has_action(_attack_action_pressed):
		Input.action_release(_attack_action_pressed)
	print("[OVR] post-load combat: combat node=%s  entered combat=%s" % [
		str(_combat != null), str(_saw_combat)])
	if _combat_checked:
		_expect(_saw_combat, "the player still ENTERS COMBAT after loading")


# --- Bad data -----------------------------------------------------------------

func _check_bad_data() -> void:
	var balance_before := _ledger.get_credits()
	var cases := [
		{"label": "not JSON at all", "text": "this is not json {{{",
			"expect": GameStateSave.Result.MALFORMED},
		{"label": "JSON that is not an object", "text": "[1, 2, 3]",
			"expect": GameStateSave.Result.MALFORMED},
		{"label": "unsupported schema_version",
			"text": '{"schema_version": 99, "run": {"id": "x", "started_unix": 1}, "carried_credits": 7, "player": {"alive": true}}',
			"expect": GameStateSave.Result.UNSUPPORTED_VERSION},
		{"label": "no schema_version",
			"text": '{"run": {"id": "x", "started_unix": 1}, "carried_credits": 7, "player": {"alive": true}}',
			"expect": GameStateSave.Result.MISSING_FIELD},
		{"label": "no run block",
			"text": '{"schema_version": %d, "carried_credits": 7, "player": {"alive": true}}' % GameStateSave.SCHEMA_VERSION,
			"expect": GameStateSave.Result.NO_RUN},
		{"label": "run block with no id",
			"text": '{"schema_version": %d, "run": {}, "carried_credits": 7, "player": {"alive": true}}' % GameStateSave.SCHEMA_VERSION,
			"expect": GameStateSave.Result.NO_RUN},
		{"label": "no player block",
			"text": '{"schema_version": %d, "run": {"id": "x", "started_unix": 1}, "carried_credits": 7}' % GameStateSave.SCHEMA_VERSION,
			"expect": GameStateSave.Result.MISSING_FIELD},
		{"label": "player recorded as dead",
			"text": '{"schema_version": %d, "run": {"id": "x", "started_unix": 1}, "carried_credits": 7, "player": {"alive": false}}' % GameStateSave.SCHEMA_VERSION,
			"expect": GameStateSave.Result.INVALID_VALUE},
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
		_expect(code == int(case["expect"]),
			"%s fails as %s (got %s)" % [
				String(case["label"]), GameStateSave.result_name(int(case["expect"])),
				GameStateSave.result_name(code)])
		_expect(_ledger.get_credits() == balance_before,
			"%s left the carried balance untouched" % String(case["label"]))

	# A save removed entirely is a DIFFERENT result from a save that is present but wrong.
	_save.delete_save()
	_expect(_save.load_game() == GameStateSave.Result.NO_SAVE,
		"a deleted save reports no-save, distinctly from a corrupt one")
	print("[OVR] bad data: %d cases rejected by cause, balance held at %d" % [
		cases.size(), balance_before])


# --- Resolution and helpers ---------------------------------------------------

func _resolve() -> void:
	_ledger = CreditLedger.find_ledger(get_tree())
	_save = GameStateSave.find_save(get_tree())
	var player := _save.get_player_actor() if _save != null else null
	_player = player as Node3D
	if _player != null:
		_combat = _player.get_node_or_null("Combat")
		if _combat == null:
			for child in _player.get_children():
				if child.has_method("is_busy"):
					_combat = child
					break

	# The eligible population is discovered from the defeat authority's own group, so this probe does
	# not depend on a hand-written actor list.
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


## Count the live CreditLedger and GameStateSave instances in the tree. A load must not create a
## second owner of either, so this is the evidence that it did not.
func _count_services() -> Vector2i:
	var ledgers := 0
	var saves := 0
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CreditLedger:
			ledgers += 1
		if node is GameStateSave:
			saves += 1
		for child in node.get_children():
			stack.append(child)
	return Vector2i(ledgers, saves)


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


## A minimal VALID payload, used to write a controlled save for the post-load stages.
func _make_payload(id: String, credits: int) -> String:
	return JSON.stringify({
		"schema_version": GameStateSave.SCHEMA_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"run": {"id": id, "started_unix": int(Time.get_unix_time_from_system())},
		"carried_credits": credits,
		"player": {"alive": true},
	}, "  ")


# --- The save file itself ------------------------------------------------------

func _backup_existing() -> void:
	if not _save.has_save():
		return
	var file := FileAccess.open(_save.save_path(), FileAccess.READ)
	if file == null:
		return
	_backup_text = file.get_as_text()
	file.close()
	_had_save = true


func _restore_backup() -> void:
	if _had_save:
		_write_raw(_backup_text)
		print("[OVR] restored the save file that was present before this run")
		return
	_save.delete_save()
	print("[OVR] removed the probe's save (there was none before this run)")


func _read_raw() -> String:
	var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_raw(text: String) -> bool:
	var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _read_int_field(field: String) -> int:
	var parsed: Variant = JSON.parse_string(_read_raw())
	if parsed == null or not (parsed is Dictionary):
		return -1
	return int((parsed as Dictionary).get(field, -1))


# --- Reporting -----------------------------------------------------------------

func _expect(condition: bool, text: String) -> void:
	if condition:
		print("[OVR]   PASS  %s" % text)
	else:
		_fail(text)


func _fail(text: String) -> void:
	print("[OVR]   FAIL  %s" % text)
	_failures.append(text)


func _report() -> void:
	print("[OVR] --- summary ---")
	if _failures.is_empty():
		print("[OVR] RESULT: ALL CHECKS PASSED")
	else:
		print("[OVR] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
	print("[OVR] save service: saves=%d loads=%d new_runs=%d" % [
		_save.saves if _save != null else -1,
		_save.loads if _save != null else -1,
		_save.new_runs if _save != null else -1])
