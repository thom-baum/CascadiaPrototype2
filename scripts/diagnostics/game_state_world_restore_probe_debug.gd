class_name GameStateWorldRestoreProbeDebug
extends Node3D
## Temporary diagnostic (not production): does a LOAD put the WORLD back to the state the save
## recorded, not just the credited number?
##
## WHY THIS EXISTS. The reported defect was: save, then play on (enemies defeated, player dead),
## then load - and the game came back with `load: OK` while the arena was still showing DEFEATED
## over a dead player. Credits round-tripped; the WORLD did not.
##
## Two independent defects produced that, and this probe tests BOTH:
##   1. the save recorded no world state at all, so there was nothing to restore;
##   2. `enemy_death_presentation_debug` could only ever APPLY its defeat pose, never clear it, so
##      a DEFEATED label was permanent for the life of the instance even once the state changed.
##
## The sequence here is deliberately the reported one, and it is measured through the REAL owners:
##
##   save (world alive)  ->  kill two enemies AND the player  ->  load  ->  world must be back
##
## Every actor is discovered from the defeat authority's own group, so this probe does not depend
## on a hand-written list of who exists.

const SETTLE_FRAMES := 20
## Frames allowed for PRESENTATION adapters to read the restored state before it is measured.
const PRESENTATION_FRAMES := 4
const MOVE_FRAMES := 24
const MIN_TRAVEL := 0.15
const LETHAL := 9999.0

var _frame := 0
var _stage := 0
var _wait := 0
var _failures: Array = []
var _done := false

var _ledger: CreditLedger
var _save: GameStateSave
var _death: Node
var _player: Node3D
var _move_start := Vector3.ZERO

## Snapshot of who was alive at save time, so the load can be compared against it.
var _recorded: Array = []
var _credits_at_save := 0


func _ready() -> void:
	print("[WORLDRESTORE] --- world-state restore audit ---")


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		0:
			_run_audit()
		1:
			# Presentation is an ADAPTER that reads state in its own _process, so the restored
			# world is not necessarily DRAWN on the same frame the load returns. Measuring here
			# would report the adapter's one-frame lag as a restore defect.
			_wait += 1
			if _wait >= PRESENTATION_FRAMES:
				_verify_world()
				_begin_movement()
		2:
			_wait += 1
			if _wait >= MOVE_FRAMES:
				_finish_movement()


# --- The audit -----------------------------------------------------------------

func _run_audit() -> void:
	_resolve()
	if _ledger == null or _save == null or _death == null or _player == null:
		_fail("could not resolve the ledger, the save service, the player's death circuit and the player")
		_done = true
		_report()
		return
	_stand_down_ambient_attackers()

	# Start from a known run so this probe never inherits a previous run's file.
	_save.new_run()
	_expect(_ledger.get_credits() == 0, "a new run begins at the documented balance (0)")

	# Give the run a distinctive balance so a restore is provable, not coincidental.
	_ledger.award_credits(250, "probe-seed")
	_credits_at_save = _ledger.get_credits()
	_expect(_credits_at_save == 250, "the run carries 250 Credits before the save")

	# --- SAVE with the world ALIVE -------------------------------------------------
	_recorded = _world_state()
	_expect(_recorded.size() >= 2,
		"at least two defeatable actors exist to test with (found %d)" % _recorded.size())
	for row in _recorded:
		_expect(not bool(row["defeated"]) and not bool(row["dead"]),
			"%s is ALIVE at save time" % String(row["label"]))

	var save_code := _save.save_game()
	print("[WORLDRESTORE] save: %s  credits=%d  actors_recorded=%d" % [
		GameStateSave.result_name(save_code), _credits_at_save, _recorded.size()])
	_expect(save_code == GameStateSave.Result.OK, "the save succeeded")

	# The file must actually CONTAIN the world, or there is nothing to restore.
	var on_disk := _read_save_file()
	_expect(on_disk.has("world"), "the save file records a world block")
	_expect(int(on_disk.get("schema_version", 0)) == GameStateSave.SCHEMA_VERSION,
		"the save file reports schema_version %d (got %s)" % [
			GameStateSave.SCHEMA_VERSION, str(on_disk.get("schema_version"))])
	var world: Dictionary = on_disk.get("world", {})
	var actors: Array = world.get("actors", [])
	_expect(actors.size() == _recorded.size(),
		"the save file records every defeatable actor (%d of %d)" % [actors.size(), _recorded.size()])

	# --- CHANGE the world: kill two enemies, then kill the player -------------------
	var killed := 0
	for row in _recorded:
		if killed >= 2:
			break
		var actor: Node3D = row["actor"]
		var hurtbox := _hurtbox_of(actor)
		if hurtbox == null:
			continue
		var event := DamageEvent.new()
		event.amount = LETHAL
		hurtbox.receive_hit(event)
		killed += 1
	_expect(killed >= 1, "at least one enemy was killed after the save (killed %d)" % killed)

	var changed := _world_state()
	var defeated_now := 0
	for row in changed:
		if bool(row["defeated"]):
			defeated_now += 1
	print("[WORLDRESTORE] after the save: enemies defeated=%d  credits=%d" % [
		defeated_now, _ledger.get_credits()])
	_expect(defeated_now >= 1, "the world actually CHANGED after the save (defeated=%d)" % defeated_now)

	# Kill the PLAYER too, so the load has to restore a dead run as well as a dead world.
	var player_hurtbox := _hurtbox_of(_player)
	if player_hurtbox != null:
		var lethal := DamageEvent.new()
		lethal.amount = LETHAL
		player_hurtbox.receive_hit(lethal)
	var player_dead_now := bool(_death.call("is_dead"))
	print("[WORLDRESTORE] player dead after the kill: %s" % str(player_dead_now))
	_expect(player_dead_now, "the player is DEAD at the moment the load is requested")

	# --- LOAD ----------------------------------------------------------------------
	var load_code := _save.load_game()
	print("[WORLDRESTORE] load: %s  credits=%d  error=%s" % [
		GameStateSave.result_name(load_code), _ledger.get_credits(), _save.last_error])
	_expect(load_code == GameStateSave.Result.OK, "the load succeeded")

	# The world is measured on a LATER frame, deliberately: see PRESENTATION_FRAMES.
	_stage = 1
	_wait = 0


# --- Is the WORLD back? ---------------------------------------------------------

func _verify_world() -> void:
	var after := _world_state()
	var revived := 0
	var still_defeated := 0
	for row in after:
		if bool(row["defeated"]):
			still_defeated += 1
		if not bool(row["defeated"]) and not bool(row["dead"]):
			revived += 1
	print("[WORLDRESTORE] after the load: alive=%d defeated=%d  credits=%d" % [
		revived, still_defeated, _ledger.get_credits()])

	_expect(_ledger.get_credits() == _credits_at_save,
		"the carried balance was restored EXACTLY (%d, got %d)"
			% [_credits_at_save, _ledger.get_credits()])
	_expect(still_defeated == 0,
		"NO actor is left defeated after a load of a world that was saved alive (left %d)"
			% still_defeated)
	for row in after:
		if bool(row["dead"]):
			continue
		_expect(not bool(row["defeated"]), "%s is alive again after the load" % String(row["label"]))
		_expect(is_equal_approx(float(row["health"]), float(row["max_health"])),
			"%s health was restored to %d (got %.1f)"
				% [String(row["label"]), int(row["max_health"]), float(row["health"])])
		_expect(not bool(row["presentation"]),
			"%s is NOT showing a DEFEATED label after the load" % String(row["label"]))

	# The player's own circuit must have done the restoring, not this probe.
	_expect(not bool(_death.call("is_dead")), "the PLAYER is alive again after the load")
	_expect(int(_death.get("resets")) >= 1,
		"the player was restored through its OWN death circuit (resets=%s)" % str(_death.get("resets")))

	# No duplicate services: a load must reconnect, not respawn the world.
	var ledgers := get_tree().get_nodes_in_group(CreditLedger.GROUP_LEDGER).size()
	var saves := get_tree().get_nodes_in_group(GameStateSave.GROUP_SAVE).size()
	print("[WORLDRESTORE] services after the load: ledgers=%d save-services=%d" % [ledgers, saves])
	_expect(ledgers == 1, "exactly ONE CreditLedger exists after the load (got %d)" % ledgers)
	_expect(saves == 1, "exactly ONE save service exists after the load (got %d)" % saves)

## Start the movement measurement, so the probe proves the restored run is PLAYABLE.
func _begin_movement() -> void:
	_move_start = _player.global_position
	if InputMap.has_action(&"move_forward"):
		Input.action_press(&"move_forward")
	_stage = 2
	_wait = 0


func _finish_movement() -> void:
	if InputMap.has_action(&"move_forward"):
		Input.action_release(&"move_forward")
	var travelled := _player.global_position.distance_to(_move_start)
	print("[WORLDRESTORE] post-load movement: travelled %.4f m over %d frames" % [travelled, MOVE_FRAMES])
	_expect(travelled > MIN_TRAVEL,
		"the player MOVES after the load (travelled %.4f m)" % travelled)
	_save.delete_save()
	_done = true
	_report()


# --- World reading --------------------------------------------------------------

## One row per actor carrying a defeat authority: the live state AND its presentation, so a
## restored state that is not VISIBLY restored cannot pass.
func _world_state() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var actor := node.get_parent()
		if actor == null or not is_instance_valid(actor):
			continue
		var health := actor.get_node_or_null("Health") as HealthComponent
		var presentation := actor.get_node_or_null("DeathPresentation")
		var showing := false
		if presentation != null and presentation.has_method("is_showing"):
			showing = bool(presentation.call("is_showing"))
		out.append({
			"actor": actor,
			"label": String(actor.name),
			"defeated": bool(node.call("is_defeated")),
			"dead": health != null and health.is_dead,
			"health": health.current_health if health != null else 0.0,
			"max_health": health.max_health if health != null else 0.0,
			"presentation": showing,
		})
	out.sort_custom(func(a, b): return String(a["label"]) < String(b["label"]))
	return out


func _read_save_file() -> Dictionary:
	var path := String(_save.SAVE_PATH) if "SAVE_PATH" in _save else ""
	if path.is_empty():
		return {}
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary:
		return parsed
	return {}


# --- Resolution and helpers -----------------------------------------------------

func _resolve() -> void:
	_ledger = CreditLedger.find_ledger(get_tree())
	_save = GameStateSave.find_save(get_tree())
	_player = _find_player()

	# The player is the actor carrying the RESETTABLE death circuit, so it is identified by
	# ARCHETYPE rather than by name.
	for node in get_tree().get_nodes_in_group(DeathComponent.GROUP_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		_death = node
		_player = node.get_parent() as Node3D
		break


func _find_player() -> Node3D:
	for node in get_tree().get_nodes_in_group(DeathComponent.GROUP_DEATH):
		if node != null and is_instance_valid(node):
			return node.get_parent() as Node3D
	return null


func _stand_down_ambient_attackers() -> void:
	EnemyAttacker.stand_down_all(get_tree())


func _hurtbox_of(actor: Node) -> HurtboxComponent:
	if actor == null:
		return null
	var hurtbox := actor.get_node_or_null("Hurtbox")
	if hurtbox is HurtboxComponent:
		return hurtbox
	return null


# --- Reporting ------------------------------------------------------------------

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[WORLDRESTORE]   PASS  %s" % message)
	else:
		_failures.append(message)
		print("[WORLDRESTORE]   FAIL  %s" % message)


func _fail(message: String) -> void:
	_failures.append(message)
	print("[WORLDRESTORE]   FAIL  %s" % message)


func _report() -> void:
	print("[WORLDRESTORE] --- summary ---")
	if _failures.is_empty():
		print("[WORLDRESTORE] RESULT: ALL CHECKS PASSED")
	else:
		print("[WORLDRESTORE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
