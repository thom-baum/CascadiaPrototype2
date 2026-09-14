class_name GameStateMixedStateProbeDebug
extends Node3D
## Temporary diagnostic (not production): does a quicksave restore a MIXED world?
##
## WHY THIS EXISTS. The first world-restore probe saved a world in which EVERY actor was alive,
## killed everything, loaded, and saw everything alive. That is ONE case, and passing it proves
## almost nothing: with every actor alive at save time, "restore health to full" and "restore the
## death state" produce the SAME answer, so a restore that ignores the saved death state entirely
## still passes. The contract that matters is the MIXED one:
##
##     save with some actors DEAD and some ALIVE
##     mutate the world so it no longer matches
##     load
##     the SAME actors that were dead are dead, the SAME actors that were alive are alive
##
## So this probe runs that contract across FIVE snapshot densities (0, 1, 2, 3 and 5 defeated at
## save time). Every actor is tracked BY ITS SCENE PATH, never by array order or discovery order,
## and every per-actor field is logged at every stage, because "two are dead" is not the question -
## "are the SAME two dead" is.
##
## The restore must also stay SELF-CONSISTENT: health, is_dead, is_defeated, targetability and the
## defeat presentation must all agree with each other and with the snapshot, or the world is
## incoherent (a "dead" actor at full health, or a living actor nobody can target).

const SETTLE_FRAMES := 20
## Frames given to presentation adapters after a load. They poll on their own _process, so the
## restored world is not necessarily drawn on the frame the load returns.
const PRESENTATION_FRAMES := 6
const MOVE_FRAMES := 20
const LETHAL := 9999.0
const MIN_TRAVEL := 0.25

## Density of the snapshot: how many actors are DEFEATED at save time.
const CASE_DEFEATED_COUNT := [0, 1, 2, 3, 5]

var _frame := 0
var _done := false
var _stage := 0
var _case := 0
var _wait := 0
var _failures: Array = []

var _ledger: CreditLedger
var _save: GameStateSave
var _player: Node3D
var _player_health: HealthComponent
var _player_death: Node

## Every damageable actor with a defeat component, keyed by the scene path used as identity.
var _actors: Array = []
var _paths: Array = []

var _expect: Dictionary = {}
## Economy counters read IMMEDIATELY BEFORE the load. The claim under test is narrow and strong:
## the LOAD itself must pay nothing. The mutation before it legitimately EARNS Credits by killing
## actors, so measuring rewards across the mutation would charge the load for the mutation's own
## earnings - which is exactly the false failure this scoping fixes.
var _awards_before_load := 0
var _credits_before_load := 0
## One compact recap line per case, printed at the END so it survives the console tail cap. The
## per-case detail scrolls out otherwise, and the recap is the identity evidence that matters:
## WHICH actors were defeated, by name, before and after.
var _case_recap: Array = []
var _credits_at_save := 0
var _awards_at_save := 0
var _move_start := Vector3.ZERO
var _had_save := false
var _backup_text := ""


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		0:
			_run_case()
		1:
			# Presentation adapts on its own _process, measured after it has had frames.
			_wait += 1
			if _wait >= PRESENTATION_FRAMES:
				_verify_case()
		2:
			_wait += 1
			if _wait >= MOVE_FRAMES:
				_finish_movement()


# --- One mixed-state case ------------------------------------------------------

func _run_case() -> void:
	if _case >= CASE_DEFEATED_COUNT.size():
		_begin_movement()
		return

	if _case == 0:
		_resolve()
		if _ledger == null or _save == null or _player == null or _player_health == null:
			_fail("could not resolve the ledger, the save service and the player")
			_done = true
			_report()
			return
		if _actors.size() < 5:
			_fail("expected at least 5 defeatable actors, found %d" % _actors.size())
			_done = true
			_report()
			return
		_stand_down_ambient_attackers()
		_backup_existing()

	var wanted := int(CASE_DEFEATED_COUNT[_case])
	print("[MIXED] === case %d/%d: save with %d of %d defeated ===" % [
		_case + 1, CASE_DEFEATED_COUNT.size(), wanted, _actors.size()])

	# START CLEAN: every actor alive, so each case begins from a known world and cannot inherit
	# the previous case's damage.
	_restore_all_alive()

	# KILL EXACTLY `wanted` ACTORS, chosen by SORTED PATH so the choice is deterministic and does
	# not depend on group or node discovery order.
	var killed_paths: Array = []
	for i in range(mini(wanted, _actors.size())):
		var actor: Node3D = _actors[i]
		if _kill(actor):
			killed_paths.append(_paths[i])
	print("[MIXED] defeated at save time: %s" % [_path_list(killed_paths)])

	# THE SNAPSHOT: what every actor must look like after the load, keyed by path.
	_expect = {}
	for i in range(_actors.size()):
		_expect[_paths[i]] = _state(_actors[i])

	_credits_at_save = _ledger.get_credits()
	_awards_at_save = _ledger.awards
	var save_code := _save.save_game()
	_check(save_code == GameStateSave.Result.OK,
		"case %d: the save succeeded" % _case)
	_log_row("SAVED", _expect)

	# MUTATE: change the world so it no longer matches the snapshot. Kill actors that were ALIVE
	# in the snapshot; if the snapshot has none left, REVIVE one instead, so the world always
	# genuinely differs from the snapshot either way.
	var mutated := 0
	var wanted_mutations := 2
	for i in range(_actors.size()):
		if mutated >= wanted_mutations:
			break
		var actor: Node3D = _actors[i]
		if bool(_expect[_paths[i]]["defeated"]):
			continue
		if _kill(actor):
			mutated += 1
	if mutated == 0:
		# Every actor was defeated at save time; bring one BACK so the world still differs.
		for i in range(_actors.size()):
			var actor: Node3D = _actors[i]
			var health := _health_of(actor)
			var death := _death_of(actor)
			if health != null:
				health.restore_to(health.max_health, false)
			if death != null:
				death.call("restore_defeated", false)
			mutated += 1
			break

	# And kill the PLAYER, so the load also has to bring the run back to playable.
	_kill_player()

	var live_after_mutation := _live_world()
	var differs := _differs_from_check(live_after_mutation)
	print("[MIXED] mutated: %d actors changed, player dead=%s, world differs from snapshot=%s" % [
		mutated, str(_player_health.is_dead), str(differs)])
	_check(differs, "case %d: the world genuinely differs from the snapshot before the load" % _case)
	_log_row("MUTATED", live_after_mutation)

	# Capture the economy counters IMMEDIATELY BEFORE the load. Everything above is setup and
	# deliberate mutation, and the mutation EARNS Credits by killing actors - so the only honest
	# question is whether the load itself pays anything.
	_awards_before_load = _ledger.awards
	_credits_before_load = _ledger.get_credits()

	# LOAD.
	var load_code := _save.load_game()
	print("[MIXED] load: %s  credits=%d  error=%s" % [
		GameStateSave.result_name(load_code), _ledger.get_credits(), _save.last_error])
	_check(load_code == GameStateSave.Result.OK, "case %d: the load succeeded" % _case)

	_stage = 1
	_wait = 0


# --- Is the exact recorded world back? ------------------------------------------

func _verify_case() -> void:
	var wanted := int(CASE_DEFEATED_COUNT[_case])
	var live := _live_world()
	_log_row("AFTER LOAD", live)

	# PER-ACTOR, BY PATH: the same actors, each with the exact recorded state.
	var wrong: Array = []
	var defeated_now := 0
	for path in _expect.keys():
		if not live.has(path):
			wrong.append("%s MISSING" % path)
			continue
		var want: Dictionary = _expect[path]
		var got: Dictionary = live[path]
		if bool(got["defeated"]):
			defeated_now += 1
		if bool(want["defeated"]) != bool(got["defeated"]):
			wrong.append("%s defeated %s!=%s" % [path, str(want["defeated"]), str(got["defeated"])])
		elif bool(want["dead"]) != bool(got["dead"]):
			wrong.append("%s dead %s!=%s" % [path, str(want["dead"]), str(got["dead"])])
		elif not is_equal_approx(float(want["health"]), float(got["health"])):
			wrong.append("%s health %.1f!=%.1f" % [path, float(want["health"]), float(got["health"])])

	_check(wrong.is_empty(),
		"case %d: every actor was restored to the EXACT state the snapshot recorded (%s)"
			% [_case, ", ".join(wrong)] if not wrong.is_empty() else
			"case %d: every actor was restored to the EXACT state the snapshot recorded" % _case)
	_check(defeated_now == wanted,
		"case %d: exactly %d actors are defeated after the load (got %d)" % [_case, wanted, defeated_now])

	# SELF-CONSISTENCY: the fields must agree with each other, not merely with the snapshot.
	var incoherent: Array = []
	for path in live.keys():
		var row: Dictionary = live[path]
		var defeated := bool(row["defeated"])
		var dead := bool(row["dead"])
		var targetable := bool(row["targetable"])
		if not defeated and not dead and float(row["health"]) <= 0.0:
			incoherent.append("%s alive with 0 health" % path)
		if defeated and not dead:
			incoherent.append("%s defeated but health is not dead" % path)
		if (defeated or dead) and targetable:
			incoherent.append("%s unusable but still targetable" % path)
		if not defeated and not dead and not targetable:
			incoherent.append("%s alive but not targetable" % path)
		# The presentation must MATCH the state: showing only while defeated.
		if defeated != bool(row["showing"]):
			incoherent.append("%s presentation showing=%s while defeated=%s"
				% [path, str(row["showing"]), str(defeated)])
	_check(incoherent.is_empty(),
		"case %d: health, death, defeat, targetability and presentation all AGREE (%s)"
			% [_case, ", ".join(incoherent)] if not incoherent.is_empty() else
			"case %d: health, death, defeat, targetability and presentation all AGREE" % _case)

	# The player, the balance and the economy.
	_check(not _player_health.is_dead, "case %d: the player is playable after the load" % _case)
	_check(_ledger.get_credits() == _credits_at_save,
		"case %d: the carried balance is the recorded value (got %d, want %d)"
			% [_case, _ledger.get_credits(), _credits_at_save])
	_check(_ledger.awards == _awards_before_load,
		"case %d: the load paid NO reward (awards %d -> %d ACROSS THE LOAD)"
			% [_case, _awards_before_load, _ledger.awards])
	_check(_count_ledgers() == 1 and _count_saves() == 1,
		"case %d: still exactly one ledger and one save service" % _case)

	_case_recap.append("case %d: defeated at SAVE [%s] -> defeated AFTER LOAD [%s]  alive=%d  rewards_across_load=%d  incoherent=%d  exact_state=%s" % [
		_case, _defeated_names(_expect), _defeated_names(live), _actors.size() - defeated_now,
		_ledger.awards - _awards_before_load, incoherent.size(), str(wrong.is_empty())])

	_case += 1
	_stage = 0
	_wait = 0


# --- Movement, after every case has been restored -------------------------------

func _begin_movement() -> void:
	_restore_all_alive()
	_move_start = _player.global_position
	if InputMap.has_action(&"move_forward"):
		Input.action_press(&"move_forward")
	_stage = 2
	_wait = 0


func _finish_movement() -> void:
	if InputMap.has_action(&"move_forward"):
		Input.action_release(&"move_forward")
	var travelled := _player.global_position.distance_to(_move_start)
	print("[MIXED] final movement after all loads: travelled %.4f m over %d frames" % [
		travelled, MOVE_FRAMES])
	_check(travelled > MIN_TRAVEL,
		"the player still MOVES after repeated loads (travelled %.4f m)" % travelled)
	_done = true
	_restore_existing()
	_report()


# --- World helpers -------------------------------------------------------------

## One actor's full observable state. Every field the contract names, read from its OWN owners.
func _state(actor: Node3D) -> Dictionary:
	var health := _health_of(actor)
	var death := _death_of(actor)
	var row := {
		"health": health.current_health if health != null else -1.0,
		"max_health": health.max_health if health != null else -1.0,
		"dead": health.is_dead if health != null else false,
		"defeated": bool(death.call("is_defeated")) if death != null and death.has_method("is_defeated") else false,
		"targetable": bool(CombatParticipant.is_usable_target(actor)),
		"showing": _presentation_showing(actor),
	}
	return row


func _live_world() -> Dictionary:
	var out: Dictionary = {}
	for i in range(_actors.size()):
		out[_paths[i]] = _state(_actors[i])
	return out


func _differs_from_check(live: Dictionary) -> bool:
	for path in _expect.keys():
		if not live.has(path):
			return true
		var want: Dictionary = _expect[path]
		var got: Dictionary = live[path]
		if bool(want["defeated"]) != bool(got["defeated"]):
			return true
		if not is_equal_approx(float(want["health"]), float(got["health"])):
			return true
	return false


func _restore_all_alive() -> void:
	for actor in _actors:
		var health := _health_of(actor)
		if health != null:
			health.restore_to(health.max_health, false)
		var death := _death_of(actor)
		if death != null and death.has_method("restore_defeated"):
			death.call("restore_defeated", false)
	if _player_health != null:
		_player_health.restore_to(_player_health.max_health, false)
	if _player_death != null and _player_death.has_method("reset_playable_state"):
		_player_death.call("reset_playable_state", false)


func _log_row(tag: String, world: Dictionary) -> void:
	for path in world.keys():
		var row: Dictionary = world[path]
		print("[MIXED]   %-10s %-34s hp=%6.1f/%-6.1f dead=%-5s defeated=%-5s targetable=%-5s showing=%s" % [
			tag, _short(path), float(row["health"]), float(row["max_health"]),
			str(row["dead"]), str(row["defeated"]), str(row["targetable"]), str(row["showing"])])


## The DEFEATED actors in a world map, by short name, so a recap names WHICH actors rather than
## only counting them. Identity is the whole point of the mixed-state contract.
func _defeated_names(world: Dictionary) -> String:
	var names: Array = []
	for path in world.keys():
		if bool((world[path] as Dictionary)["defeated"]):
			names.append(_short(String(path)))
	return ",".join(names) if not names.is_empty() else "none"


func _short(path: String) -> String:
	var parts := path.split("/")
	return parts[parts.size() - 1] if parts.size() > 0 else path


func _path_list(paths: Array) -> String:
	var short: Array = []
	for path in paths:
		short.append(_short(String(path)))
	return ", ".join(short) if not short.is_empty() else "none"


# --- Resolution ----------------------------------------------------------------

func _resolve() -> void:
	_ledger = CreditLedger.find_ledger(get_tree())
	_save = GameStateSave.find_save(get_tree())
	_player = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	if _player != null:
		_player_health = _health_of(_player)
		_player_death = _player.get_node_or_null("Death")

	# Identity is the SCENE PATH, and the list is sorted by it so an actor's index is stable.
	var found: Array = []
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var actor := node.get_parent() as Node3D
		if actor == null or not is_instance_valid(actor):
			continue
		if actor == _player:
			continue
		found.append(actor)
	found.sort_custom(func(a, b): return String(a.get_path()) < String(b.get_path()))
	for actor in found:
		_actors.append(actor)
		_paths.append(String(actor.get_path()))


func _kill(actor: Node3D) -> bool:
	var hurtbox := actor.get_node_or_null("Hurtbox")
	if hurtbox != null and hurtbox.has_method("receive_hit"):
		var event := DamageEvent.new()
		event.amount = LETHAL
		event.source = null
		return bool(hurtbox.call("receive_hit", event))
	var health := _health_of(actor)
	if health == null:
		return false
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = null
	return health.apply_damage(event)


func _kill_player() -> void:
	if _player == null:
		return
	var hurtbox := _player.get_node_or_null("Hurtbox")
	if hurtbox != null and hurtbox.has_method("receive_hit"):
		var event := DamageEvent.new()
		event.amount = LETHAL
		event.source = null
		hurtbox.call("receive_hit", event)


func _health_of(actor: Node) -> HealthComponent:
	if actor == null:
		return null
	return actor.get_node_or_null("Health") as HealthComponent


func _death_of(actor: Node) -> Node:
	if actor == null:
		return null
	var death := actor.get_node_or_null("Death")
	if death != null and death.has_method("is_defeated"):
		return death
	return null


func _presentation_showing(actor: Node) -> bool:
	var node := actor.get_node_or_null("DeathPresentation")
	if node != null and node.has_method("is_showing"):
		return bool(node.call("is_showing"))
	return false


func _count_ledgers() -> int:
	return get_tree().get_nodes_in_group(CreditLedger.GROUP_LEDGER).size()


func _count_saves() -> int:
	return get_tree().get_nodes_in_group(GameStateSave.GROUP_SAVE).size()


func _stand_down_ambient_attackers() -> void:
	EnemyAttacker.stand_down_all(get_tree())


# --- Save-file hygiene ----------------------------------------------------------

func _backup_existing() -> void:
	_had_save = _save.has_save()
	if _had_save:
		var file := FileAccess.open(_save.save_path(), FileAccess.READ)
		if file != null:
			_backup_text = file.get_as_text()
			file.close()


func _restore_existing() -> void:
	if _had_save:
		var file := FileAccess.open(_save.save_path(), FileAccess.WRITE)
		if file != null:
			file.store_string(_backup_text)
			file.close()
		print("[MIXED] restored the save file that existed before this run")
	else:
		if _save.delete_save():
			print("[MIXED] removed the probe's save (there was none before this run)")


# --- Reporting ------------------------------------------------------------------

func _check(ok: bool, label: String) -> void:
	if ok:
		print("[MIXED]   PASS  %s" % label)
		return
	_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[MIXED]   FAIL  %s" % label)


func _report() -> void:
	print("[MIXED] --- summary ---")
	for line in _case_recap:
		print("[MIXED] %s" % line)
	if _failures.is_empty():
		print("[MIXED] RESULT: ALL CHECKS PASSED")
	else:
		print("[MIXED] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
