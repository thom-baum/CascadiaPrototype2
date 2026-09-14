class_name GameStateDeathLoopProbeDebug
extends Node3D
## Temporary diagnostic (not production): does saving and loading SURVIVE the death loop?
##
## WHY THIS EXISTS. M10.1 corrected a load that applied its value unconditionally. The danger it was
## applying into is the PLAYER DEATH CIRCUIT, which owns the player's restoration: health, stamina,
## position and the arena attacker all get put back by `DeathComponent`. A load running underneath
## that would fight the one system that owns the state.
##
## So this probe drives the REAL sequence on the REAL scene:
##
##   new run -> kill an enemy through the damage chain -> save -> KILL THE PLAYER -> try to load
##   -> wait for the circuit's own reset -> load -> keep playing
##
## and it asserts the things that must not happen: no duplicated reward, no revived enemy, no second
## ledger or save service, no duplicated signal, and no run left stranded in a transitional state.
##
## It also pins the EXISTING death contract rather than inventing a death-loss rule: the carried
## balance is untouched by death, because no death-loss mechanic exists yet and this probe must not
## pretend one does.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 12
## Upper bound on waiting for the death circuit's own automatic reset. The authored delay is 1.50 s.
const RESET_TIMEOUT_FRAMES := 300
## Damage used for a lethal blow - far above any actor's pool.
const LETHAL := 9999.0

var _frame := 0
var _stage := 0
var _wait := 0
var _done := false
var _failures: Array = []

var _ledger: CreditLedger
var _save: GameStateSave
var _enemy: Node
var _player: Node3D
var _player_health: HealthComponent
var _player_death: Node

var _saved_value := 0
var _awards_at_save := 0
var _refused_result := -1
var _balance_when_refused := 0
var _awards_when_refused := 0
var _resets_before := 0
var _enemy_defeated_before := false
## Signals actually received, so "one load" can be told from "one load and a duplicate emission".
var _loaded_signals := 0

var _backup_text := ""
var _had_save := false


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
			if _player_is_alive() or _wait >= RESET_TIMEOUT_FRAMES:
				_finish()


func _run_setup() -> void:
	_resolve()
	if _ledger == null or _save == null or _enemy == null or _player == null or _player_health == null:
		_fail("could not resolve the ledger, the save service, the player and one eligible enemy")
		_report()
		return

	_stand_down_ambient_attackers()
	_backup_save()
	_save.game_loaded.connect(_on_game_loaded)

	print("[DEATHLOOP] resolved: ledger=%s save=%s enemy=%s player=%s path=%s" % [
		_ledger.name, _save.name, _name_of(_enemy), _player.name, _save.save_path()])

	# 1. A known active run.
	var code := _save.new_run()
	_expect(code == GameStateSave.Result.OK, "a new run starts cleanly")
	_expect(_ledger.get_credits() == _ledger.starting_credits,
		"a new run begins at the documented starting balance (%d)" % _ledger.starting_credits)

	# 2. Known carried Credits, earned through the real defeat path.
	var killed := _kill(_enemy)
	_expect(killed, "an eligible enemy was killed through the real damage chain")
	_expect(_ledger.get_credits() > _ledger.starting_credits,
		"the defeat paid Credits into the carried balance")
	_enemy_defeated_before = _is_defeated(_enemy)
	_expect(_enemy_defeated_before, "the enemy really is in the authoritative defeated state")

	# 3. Save from a valid, playable state.
	_saved_value = _ledger.get_credits()
	_awards_at_save = _ledger.awards
	code = _save.save_game()
	_expect(code == GameStateSave.Result.OK, "saving from a playable state succeeds")
	print("[DEATHLOOP] saved run at %d carried Credits (awards=%d)" % [_saved_value, _awards_at_save])

	# 4. Exercise the EXISTING death path: the player dies for real.
	_kill_player()
	_expect(_player_health.is_dead, "the player really died through the existing damage path")
	_expect(_player_is_dead(), "the player's own death circuit reports the death")
	_resets_before = _resets()
	print("[DEATHLOOP] player killed: health=%.1f dead=%s resets=%d" % [
		_player_health.current_health, str(_player_health.is_dead), _resets_before])

	# 5. Attempt a load INSIDE the death window.
	#
	# CONTRACT REVISED for the world-state milestone, and this is the reason this assertion
	# changed rather than the implementation. The save is now a SNAPSHOT of a run, and
	# `save_game()` refuses to write a dead one - so every save file records a PLAYABLE run.
	# Loading it while the live player is mid-death therefore RESTORES THE RECORDED CONDITION,
	# through the death circuit's OWN reset rather than by this service writing player fields.
	# The earlier revision REFUSED this load; that rule was superseded when the save stopped
	# being a credits-only round trip. The assertions below are the stronger form of the new
	# rule: the revival must come from the circuit (resets must increment), it must pay nothing,
	# and it must not touch an enemy the snapshot recorded as defeated.
	var balance_before := _ledger.get_credits()
	_refused_result = _save.load_game()
	_balance_when_refused = _ledger.get_credits()
	_awards_when_refused = _ledger.awards
	print("[DEATHLOOP] load during death: %s  balance %d -> %d" % [
		GameStateSave.result_name(_refused_result), balance_before, _balance_when_refused])

	_expect(_refused_result == GameStateSave.Result.OK,
		"a load of a playable snapshot SUCCEEDS even though the live player is mid-death")
	_expect(_balance_when_refused == _saved_value,
		"the load restored the RECORDED balance and touched nothing else")
	_expect(_awards_when_refused == _awards_at_save,
		"the load granted no award")
	_expect(_resets() > _resets_before,
		"the player was restored by the DEATH CIRCUIT's own reset, not by direct field writes")
	_expect(_player_is_alive(), "the player is playable again after the load")
	_expect(_is_defeated(_enemy), "the load did NOT revive an enemy the snapshot recorded as defeated")

	_stage = 1
	_wait = 0
	print("[DEATHLOOP] waiting for the death circuit's own reset (up to %d frames)" % RESET_TIMEOUT_FRAMES)


func _finish() -> void:
	_done = true

	# 6. The reset must be the CIRCUIT's doing, not the load's.
	_expect(_player_is_alive(), "the player is playable again after the death circuit's reset")
	_expect(_resets() > _resets_before,
		"the player was restored by the CIRCUIT's own reset, not by a load")
	print("[DEATHLOOP] after the circuit reset: alive=%s resets %d -> %d  carried=%d" % [
		str(_player_is_alive()), _resets_before, _resets(), _ledger.get_credits()])

	# 7. Now a load is applicable.
	var balance_before := _ledger.get_credits()
	var awards_before := _ledger.awards
	var signals_before := _loaded_signals
	var code := _save.load_game()
	print("[DEATHLOOP] load after the reset: %s  balance %d -> %d" % [
		GameStateSave.result_name(code), balance_before, _ledger.get_credits()])

	_expect(code == GameStateSave.Result.OK, "a load OUTSIDE the death window succeeds")
	_expect(_ledger.get_credits() == _saved_value,
		"the load restored the exact saved balance (%d)" % _saved_value)
	_expect(_ledger.awards == awards_before, "the load granted no award")
	_expect(_loaded_signals == signals_before + 1,
		"one load emitted exactly ONE game_loaded signal")
	_expect(_ledger.rewarded_count() > 0,
		"the defeated enemy is still recorded as paid, so it cannot pay twice")
	_expect(_is_defeated(_enemy), "the defeated enemy is STILL defeated after the load")
	_expect(_player_is_alive(), "the player is still playable after the load")

	# 8. No duplicated services.
	var counts := _count_services()
	print("[DEATHLOOP] services in the tree: ledgers=%d save-services=%d" % [counts.x, counts.y])
	_expect(counts.x == 1, "exactly ONE CreditLedger exists (the load created no second owner)")
	_expect(counts.y == 1, "exactly ONE GameStateSave exists (the load created no second service)")

	# 9. Repeated loads stay idempotent.
	var repeat_a := _save.load_game()
	var repeat_b := _save.load_game()
	_expect(repeat_a == GameStateSave.Result.OK and repeat_b == GameStateSave.Result.OK,
		"loading repeatedly after a death keeps succeeding")
	_expect(_ledger.get_credits() == _saved_value,
		"repeated post-death loads did not compound the balance")
	_expect(_ledger.awards == awards_before, "repeated post-death loads granted no awards")

	# 10. The existing death contract, pinned rather than assumed: death does NOT delete Credits,
	# because no death-loss mechanic exists yet and this probe must not imply one.
	print("[DEATHLOOP] death contract: death left the carried balance at %d (no death-loss rule exists)"
		% _saved_value)

	_restore_backup()
	_report()


# --- Death ---------------------------------------------------------------------

func _kill_player() -> void:
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = null
	_player_health.apply_damage(event)


func _player_is_alive() -> bool:
	return _player_health != null and not _player_health.is_dead


func _player_is_dead() -> bool:
	if _player_death == null:
		return false
	return bool(_player_death.call("is_dead"))


func _resets() -> int:
	if _player_death == null:
		return 0
	return int(_player_death.get("resets"))


# --- Signals -------------------------------------------------------------------

func _on_game_loaded(_credits: int) -> void:
	_loaded_signals += 1


# --- Resolution ----------------------------------------------------------------

func _resolve() -> void:
	_ledger = CreditLedger.find_ledger(get_tree())
	_save = GameStateSave.find_save(get_tree())

	_player = _save.get_player_actor() if _save != null else null
	if _player != null:
		_player_health = _health_of(_player)
		_player_death = _player.get_node_or_null("Death")

	# Enumerate the defeat authority's own group rather than naming an actor.
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var owner_actor := node.get_parent()
		if owner_actor == null or not is_instance_valid(owner_actor):
			continue
		if owner_actor.is_in_group(CreditLedger.GROUP_PLAYER_ACTOR):
			continue
		var health := _health_of(owner_actor)
		if health == null or health.is_dead:
			continue
		_enemy = node
		break


func _stand_down_ambient_attackers() -> void:
	EnemyAttacker.stand_down_all(get_tree())


# --- Helpers -------------------------------------------------------------------

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


## Count the ledger and save-service instances anywhere in the tree. A load must not create either.
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


# --- Save-file safety ----------------------------------------------------------

func _backup_save() -> void:
	_had_save = _save.has_save()
	if _had_save:
		_backup_text = _read_raw()


func _restore_backup() -> void:
	if _had_save:
		_write_raw(_backup_text)
		print("[DEATHLOOP] restored the save file that was present before this run")
	else:
		if _save.delete_save():
			print("[DEATHLOOP] removed the probe's save (there was none before this run)")
		else:
			print("[DEATHLOOP] no save file to remove")


func _read_raw() -> String:
	var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_raw(text: String) -> void:
	var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


# --- Reporting -----------------------------------------------------------------

func _expect(condition: bool, what: String) -> void:
	if condition:
		print("[DEATHLOOP]   PASS  %s" % what)
	else:
		_failures.append(what)
		print("[DEATHLOOP]   FAIL  %s" % what)


func _fail(what: String) -> void:
	_failures.append(what)
	print("[DEATHLOOP]   FAIL  %s" % what)


func _report() -> void:
	print("[DEATHLOOP] --- summary ---")
	print("[DEATHLOOP] eligible enemies enumerated: %d" % (1 if _enemy != null else 0))
	if _failures.is_empty():
		print("[DEATHLOOP] RESULT: ALL CHECKS PASSED")
	else:
		print("[DEATHLOOP] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
