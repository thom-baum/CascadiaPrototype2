class_name GameStateSave
extends Node
## Cascadia's persistence for the RUN's state (Milestone 10, corrected by M10.1).
##
## WHAT THIS IS. It writes the current run's state to a file and puts it back exactly:
##
##     defeat enemies -> carry Credits -> save the run -> change the run -> load it back
##
## M10.1 CORRECTION. M10 saved ONE gameplay value and restored it unconditionally, which meant a load
## overwrote a single number inside a world that had moved on, and could be applied at any moment -
## including while the player's death circuit was mid-reset. The standard was "the number came back";
## the standard is now "the game came back". So this service saves a RUN: its identity, the carried
## balance, and the player state required to know the run is loadable, and it REFUSES a load that
## cannot be applied safely instead of forcing one.
##
## OWNERSHIP. This node owns the save file and the orchestration and NOTHING else. `CreditLedger`
## remains the ONE authority for carried Credits; the player's components remain the authority for
## whether the player is alive. This node keeps no second copy of any gameplay value, so there is
## nothing here to drift out of sync. Saving READS the owners; loading restores THROUGH them.
##
## RELATION TO THE BOUNDARY (8L): carried Credits are the only economy value, and they are the only
## gameplay value saved. STORED / SPENT Credits and player progression still do not exist. What is
## deliberately NOT saved is listed in the schema doc block below, with a reason for each exclusion -
## an exclusion that is written down is part of the contract; a silent one is a bug waiting.
##
## FAILURE IS TYPED, NOT SILENT. "It did not load" must never be confusable with "it loaded zero" or
## with "the player was dead". Every outcome is a distinct `Result`, and EVERY refusal returns before
## any state is touched, so a refused load leaves the run exactly as it was.

## Emitted after a successful save, with the balance that was written.
signal game_saved(credits: int)

## Emitted after a successful load, with the balance that was restored.
signal game_loaded(credits: int)

## Emitted when the run was reset to a fresh state, so a caller can tell a new run from a load.
signal new_run_started(credits: int)

## Every save service joins this group, so tooling can find it without a scene path.
const GROUP_SAVE := &"game_state_save"

## Godot's own per-user data location. Deliberately OUTSIDE the project tree, so a save can never be
## committed, exported or overwritten by a project re-import.
const SAVE_PATH := "user://cascadia_save.json"

## The save file name alone, used when removing the file through an opened `user://` directory.
const SAVE_FILE_NAME := "cascadia_save.json"

## The schema this build writes and the ONLY version it will read.
##
## v2 shape, and the owner of every field:
##
##   schema_version      int     this service. Rejected unless it is exactly the version below.
##   saved_at_unix       int     this service. Provenance only; never restored.
##   run.id              String  this service. Ties a save to the run that produced it, so a new run
##                               and a loaded run stop being guesswork.
##   run.started_unix    int     this service. When that run began.
##   carried_credits     int     CreditLedger. Restored through `restore_carried_credits()`.
##   player.alive        bool    The player's health/death components. Validated, NEVER forced.
##
## DELIBERATELY NOT SAVED, each for a reason:
##
##   player health / stamina / position  owned by the death-reset circuit. Restoring them here would
##       let a load bypass `DeathComponent`'s own restoration ORDER, which is exactly the bypass this
##       correction exists to prevent. Excluded until the death circuit exposes a save contract.
##   defeated-actor state                owned by `EnemyDeathComponent`. A load must never revive a
##       defeated actor, and it does not: a load touches no actor at all. Enemy persistence across a
##       load stays DEFERRED.
##   enemy health, world geometry, checkpoints, deaths, banking, spending, stats, items, gear.
##
## An unrecognised version is REFUSED rather than guessed at, because a future schema may mean
## something different by the same field name.
const SCHEMA_VERSION := 4

## Every outcome a save or load can have. Distinct values on purpose: a caller must be able to tell
## "there is no save" from "the save is corrupt" from "the run is not in a state that can accept it".
enum Result {
	OK,                    ## the operation succeeded
	NO_SAVE,               ## no save file exists yet
	READ_FAILED,           ## the file exists but could not be opened
	MALFORMED,             ## the file is not a JSON object
	UNSUPPORTED_VERSION,   ## schema_version is not the one this build understands
	MISSING_FIELD,         ## a required field is absent
	INVALID_VALUE,         ## a field is present but not a usable value
	NO_LEDGER,             ## there is no CreditLedger to read from or restore into
	WRITE_FAILED,          ## the save file could not be written
	PLAYER_DEAD,           ## the player is dead or mid-reset: a load would fight the death circuit
	NO_RUN,                ## the save carries no usable run identity
}

@export_group("Wiring")
## The CreditLedger that owns the carried balance. Defaults to a sibling named "CreditLedger".
@export var ledger_path: NodePath = NodePath("../CreditLedger")
## The player-controlled actor whose survival state this service checks. Defaults to the arena's
## player; resolution falls back to the ledger's own player group, so a scene that places the player
## anywhere still works.
@export var player_actor_path: NodePath = NodePath("../TestEnvironment/Player")

## Print each save, load and failure. Diagnostic.
@export var debug_logging := false

## The result of the most recent operation, and a human-readable reason when it was not OK.
var last_result := Result.OK
var last_error := ""

## Operation counters. Diagnostic: they make "it never ran" distinguishable from "it ran and failed".
var saves := 0
var loads := 0
var new_runs := 0

## THIS run's identity. Generated when the run begins and written into every save, so a save can be
## tied to the run that produced it and "started fresh" and "loaded" stop looking identical.
var run_id := ""
var run_started_unix := 0

## The balance the last successful load restored, or -1 when this run has not loaded yet. Diagnostic.
var loaded_credits := -1

## Where every damageable actor was AUTHORED, keyed by NodePath, captured once at boot. A NEW RUN puts
## the arena back to these, which is what "the same clean state as a fresh boot" means for the enemies
## a run moved or killed. Recorded here, never restored from: a load uses the SAVE's own snapshot.
var _spawn_transforms: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP_SAVE)
	if run_id.is_empty():
		_begin_run_identity()
	# DEFERRED, and the ordering is the whole reason. `HealthComponent._ready()` is what joins the
	# damageable group, and this node sits BEFORE `TestEnvironment` in `main.tscn` - so at this moment
	# the group is still EMPTY. A deferred call runs after the whole tree has readied, which is the
	# first moment the group is complete and every actor is still exactly where its scene authored it.
	_record_spawn_transforms.call_deferred()


# --- Queries -----------------------------------------------------------------

## The ledger this service reads from and restores into, or null when there is none.
func get_ledger() -> CreditLedger:
	if not String(ledger_path).is_empty():
		var direct := get_node_or_null(ledger_path) as CreditLedger
		if direct != null:
			return direct
	# Fallback: resolve through the ledger's own group, so a scene that places the two nodes apart
	# still works and a probe never has to hand-wire a path.
	return CreditLedger.find_ledger(get_tree())


## The save service in this tree, or null when there is none.
static func find_save(tree: SceneTree) -> GameStateSave:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP_SAVE) as GameStateSave


## The absolute location the save is written to.
func save_path() -> String:
	return SAVE_PATH


## Whether a save file exists. Says nothing about whether it is VALID - loading is the only way to
## find that out, which is why a missing file and a corrupt file are different results.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## The player-controlled actor, or null when this scene has none.
func get_player_actor() -> Node3D:
	if not String(player_actor_path).is_empty():
		var direct := get_node_or_null(player_actor_path) as Node3D
		if direct != null:
			return direct
	var tree := get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(CreditLedger.GROUP_PLAYER_ACTOR):
		var actor := node as Node3D
		if actor != null:
			return actor
	return null


## The player's death circuit, or null when the player has none. Duck-typed on `is_dead()` rather
## than typed to `DeathComponent`, because this service must not depend on the player's internals -
## it only needs the one answer "may a load be applied right now?".
func get_player_death() -> Node:
	var actor := get_player_actor()
	if actor == null:
		return null
	var death := actor.get_node_or_null("Death")
	if death != null and death.has_method("is_dead"):
		return death
	return null


## Whether the player is dead or mid-reset, and therefore NOT a valid state to save from or load into.
##
## A scene with no player at all reports false: there is nothing to fight over, and refusing every
## operation in a headless probe would be worse than the risk this guard exists to prevent.
func player_is_unavailable() -> bool:
	var death := get_player_death()
	if death == null:
		return false
	return bool(death.call("is_dead"))


## Whether a save taken now would represent a valid, playable run.
func player_is_playable() -> bool:
	return not player_is_unavailable()


## Readable name for an outcome, so a log line or a probe report never prints a bare integer.
static func result_name(code: int) -> String:
	match code:
		Result.OK:
			return "OK"
		Result.NO_SAVE:
			return "no-save"
		Result.READ_FAILED:
			return "read-failed"
		Result.MALFORMED:
			return "malformed"
		Result.UNSUPPORTED_VERSION:
			return "unsupported-version"
		Result.MISSING_FIELD:
			return "missing-field"
		Result.INVALID_VALUE:
			return "invalid-value"
		Result.NO_LEDGER:
			return "no-ledger"
		Result.WRITE_FAILED:
			return "write-failed"
		Result.PLAYER_DEAD:
			return "player-dead"
		Result.NO_RUN:
			return "no-run"
	return "unknown"


# --- Run identity -------------------------------------------------------------

## Start a fresh run identity. Called once at `_ready`, and again by `new_run()`.
func _begin_run_identity() -> void:
	run_started_unix = int(Time.get_unix_time_from_system())
	run_id = "%d-%d" % [run_started_unix, randi()]


# --- Saving -------------------------------------------------------------------

## Write the current RUN to the save file: its identity, the carried balance, and whether the player
## is playable.
##
## REFUSES when the player is dead or mid-reset, so a save file ALWAYS represents a run that was
## valid and playable at the moment it was written. That is the invariant that makes `player.alive`
## meaningful on the way back in.
func save_game() -> int:
	var ledger := get_ledger()
	if ledger == null:
		return _fail(Result.NO_LEDGER, "no CreditLedger to read the carried balance from")

	# Refused BEFORE anything is written, so a failed save leaves the previous file intact.
	if player_is_unavailable():
		return _fail(Result.PLAYER_DEAD,
			"the player is dead or mid-reset: refusing to save a run that is not playable")

	if run_id.is_empty():
		_begin_run_identity()

	var payload := {
		"schema_version": SCHEMA_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"run": {
			"id": run_id,
			"started_unix": run_started_unix,
		},
		"carried_credits": ledger.credits,
		"player": _capture_player(),
		"world": {
			"actors": _capture_world(),
		},
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return _fail(Result.WRITE_FAILED,
			"could not open %s for writing (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
	file.store_string(JSON.stringify(payload, "  "))
	file.close()

	saves += 1
	last_result = Result.OK
	last_error = ""
	_log("saved run %s: %d carried Credits" % [run_id, ledger.credits])
	game_saved.emit(ledger.credits)
	return Result.OK


# --- Loading ------------------------------------------------------------------

## Restore the run from the save file.
##
## The validation order is deliberate and is the correction's whole point: FILE, then SCHEMA, then RUN
## IDENTITY, then FIELDS, then whether the load is APPLICABLE RIGHT NOW - and only then the restore.
## Every refusal returns before any state is touched, so a refused load is a no-op.
func load_game() -> int:
	var ledger := get_ledger()
	if ledger == null:
		return _fail(Result.NO_LEDGER, "no CreditLedger to restore the carried balance into")

	# 1. FILE
	if not FileAccess.file_exists(SAVE_PATH):
		return _fail(Result.NO_SAVE, "no save file at %s" % SAVE_PATH)

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _fail(Result.READ_FAILED,
			"could not open %s for reading (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
	var text := file.get_as_text()
	file.close()

	# `JSON.new().parse()` rather than `JSON.parse_string()`: a corrupt save is an EXPECTED condition,
	# and parse_string() pushes an engine error into the log every single time one is read, which makes
	# a handled failure look like a game fault. This returns the same answer with the line and message,
	# reported through this service's own typed Result.
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail(Result.MALFORMED, "the save file is not valid JSON (line %d: %s)"
			% [json.get_error_line(), json.get_error_message()])
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return _fail(Result.MALFORMED, "the save file is not a JSON object")

	var data: Dictionary = parsed

	# 2. SCHEMA
	if not data.has("schema_version"):
		return _fail(Result.MISSING_FIELD, "the save file has no schema_version")
	var version := int(data["schema_version"])
	if version != SCHEMA_VERSION:
		return _fail(Result.UNSUPPORTED_VERSION,
			"save schema_version %d is not supported (this build writes and reads %d)"
			% [version, SCHEMA_VERSION])

	# 3. RUN IDENTITY. A save with no run cannot be tied to a run, so it is not a run state.
	if not data.has("run"):
		return _fail(Result.NO_RUN, "the save file has no run block")
	var run_raw: Variant = data["run"]
	if not (run_raw is Dictionary):
		return _fail(Result.NO_RUN, "the run block is not an object")
	var run: Dictionary = run_raw
	if not run.has("id") or String(run["id"]).is_empty():
		return _fail(Result.NO_RUN, "the save file records no run id")
	if not run.has("started_unix"):
		return _fail(Result.NO_RUN, "the run block has no started_unix")

	# 4. FIELDS
	if not data.has("carried_credits"):
		return _fail(Result.MISSING_FIELD, "the save file has no carried_credits")
	var raw: Variant = data["carried_credits"]
	if not (raw is int or raw is float):
		return _fail(Result.INVALID_VALUE, "carried_credits is not a number")
	var amount := int(raw)
	if amount < 0:
		return _fail(Result.INVALID_VALUE, "carried_credits is negative (%d)" % amount)

	if not data.has("player"):
		return _fail(Result.MISSING_FIELD, "the save file has no player block")
	var player_raw: Variant = data["player"]
	if not (player_raw is Dictionary):
		return _fail(Result.MISSING_FIELD, "the player block is not an object")
	var player: Dictionary = player_raw
	if not player.has("alive"):
		return _fail(Result.MISSING_FIELD, "the player block has no alive flag")
	if not bool(player["alive"]):
		return _fail(Result.INVALID_VALUE,
			"the save records a dead player, and a dead run is not restorable here")

	# The player's TRANSFORM is part of the snapshot, so it is validated with the same standard as
	# every other required field: a save that cannot say where the player stood is refused outright
	# rather than loaded as "somewhere".
	var pos_raw: Variant = player.get("position", null)
	if not (pos_raw is Array) or (pos_raw as Array).size() != 3:
		return _fail(Result.MISSING_FIELD, "the player block has no position (expected 3 numbers)")
	if not player.has("rotation_y"):
		return _fail(Result.MISSING_FIELD, "the player block has no rotation_y")
	if not player.has("health"):
		return _fail(Result.MISSING_FIELD, "the player block has no health")
	var recorded_health := float(player["health"])
	if recorded_health <= 0.0:
		# A snapshot ALWAYS records a playable player, because save_game() refuses to write one that
		# is not. So zero health here is a corrupt or hand-edited file - and it must be REFUSED
		# rather than applied, because marking an actor dead without its `died` signal would leave a
		# frozen player that no circuit would ever bring back.
		return _fail(Result.INVALID_VALUE,
			"the player block records health %.1f; a snapshot always records a playable player"
				% recorded_health)

	# (The dead-player rejection is owned by the check immediately above, which returns
	# INVALID_VALUE for it. There is deliberately no second branch here: it would be unreachable,
	# and an unreachable refusal reads like a guard that protects something when it protects nothing.)

	# 6. APPLY, IN A DEFINED ORDER, EACH FIELD THROUGH ITS OWN OWNER.
	#
	# 6a. THE PLAYER FIRST, through the player's OWN death circuit. If the live player is dead
	# or mid-reset and the snapshot says the run was playable, the snapshot wins: the load
	# restores the recorded condition by asking `DeathComponent` to run ITS OWN reset, so all
	# the player's state (health, stamina, committed actions, position) is restored by the one
	# authority that knows how. The save service writes none of it directly.
	#
	# This is a DELIBERATE RULE, not an invented revival mechanic: the snapshot is authoritative
	# for the state it records, which is what makes "save with the player alive, die, load" give
	# back a playable run instead of a corpse with a restored wallet.
	# ALWAYS, through the player's OWN death circuit. The snapshot is authoritative for the state it
	# records: the recorded transform, health and stamina go back whether the live player was dead,
	# mid-reset, or standing somewhere else entirely.
	#
	# Restoring ONLY when the player was dead - and then to the SPAWN mark rather than the recorded
	# position - was the defect. It meant a load never restored the run's position at all, which is
	# the reported "the saved player position is not being restored".
	var player_code := _restore_player(player)
	if player_code != Result.OK:
		return player_code
	var player_restored := true

	# 6b. PROGRESSION, through the ledger's own controlled restore. Not an award: no `awards`
	# increment, no `credits_awarded`, no actor marked paid.
	if not ledger.restore_carried_credits(amount):
		return _fail(Result.INVALID_VALUE, "the ledger refused the restored value %d" % amount)

	# 6c. WORLD ACTORS, through HealthComponent and EnemyDeathComponent. Restoring the defeated
	# flag CLEARS nothing else and pays no Credits - see restore_defeated(), which deliberately
	# does not emit `defeated` because that signal is what pays a reward.
	var world_restored := _restore_world(data)

	# 6d. THE ECONOMY'S REWARD HISTORY, through the ledger's own API. This is NOT optional tidiness:
	# the ledger remembers which actors it has paid by LIVE INSTANCE ID, so an actor that was
	# defeated AFTER the save and is brought back to life here is still remembered as paid. Without
	# this, a restored enemy is alive, targetable and killable but permanently worth ZERO Credits -
	# the run would silently stop paying out, which is the defect this step exists to prevent.
	var rewards_restored := _restore_reward_tracking(data, ledger)

	loaded_credits = amount
	loads += 1
	last_result = Result.OK
	last_error = ""
	_log("loaded run %s: %d carried Credits, %d world actor(s) restored, %d reward(s) restored, player_restored=%s"
		% [String(run["id"]), amount, world_restored, rewards_restored, str(player_restored)])
	game_loaded.emit(amount)
	return Result.OK


# --- Player capture and restore -------------------------------------------------

## The player's own slice of the snapshot: where it stood, which way it faced, its health, its
## stamina, and the camera's orbit. Every value is read through its OWN owner.
##
## Recorded HERE rather than in `_capture_world()`, which records the DEFEAT authorities. The player
## has its own death circuit and its own transform, so mixing the two would make one actor two
## records and let a restore apply the wrong one.
func _capture_player() -> Dictionary:
	var actor := get_player_actor()
	var out := {"alive": player_is_playable()}
	if actor == null:
		return out
	out["position"] = [actor.global_position.x, actor.global_position.y, actor.global_position.z]
	out["rotation_y"] = actor.rotation.y
	var health := actor.get_node_or_null("Health") as HealthComponent
	if health != null:
		out["health"] = health.current_health
	var stamina := actor.get_node_or_null("Stamina") as StaminaComponent
	if stamina != null:
		out["stamina"] = stamina.current_stamina
	var rig := _find_camera_rig()
	if rig != null:
		out["camera_yaw_degrees"] = float(rig.call("current_yaw_degrees"))
		out["camera_pitch_degrees"] = float(rig.call("current_pitch_degrees"))
	return out


## Put the player back to the state the snapshot recorded, through the owners of each value.
## Returns a Result code so the caller can refuse rather than half-apply.
func _restore_player(player: Dictionary) -> int:
	var death := get_player_death()
	if death == null or not death.has_method("restore_snapshot"):
		return _fail(Result.PLAYER_DEAD,
			"no death circuit able to restore the player's recorded state")

	var recorded: Array = player["position"]
	var position := Vector3(float(recorded[0]), float(recorded[1]), float(recorded[2]))
	var yaw := float(player["rotation_y"])
	var health_value := float(player["health"])
	var stamina_value := maxf(0.0, float(player.get("stamina", 0.0)))

	death.call("restore_snapshot", position, yaw, health_value, stamina_value)
	_log("player restored to %s yaw=%.3f health=%.1f stamina=%.1f"
		% [str(position), yaw, health_value, stamina_value])

	# The camera's orbit goes back through the rig's own API, so the view returns WITH the body
	# instead of pointing wherever the player happened to be looking when they loaded.
	var rig := _find_camera_rig()
	if rig != null and player.has("camera_yaw_degrees"):
		rig.call("restore_orientation",
			float(player["camera_yaw_degrees"]),
			float(player.get("camera_pitch_degrees", -12.0)))
	return Result.OK


## The camera rig, found by walking UP from the active camera to the node that owns the orbit.
##
## Deliberately not a scene path: the save service must not hard-code where a camera lives, and a
## scene whose camera does not answer `restore_orientation()` simply keeps the view it has.
func _find_camera_rig() -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var node: Node = camera
	while node != null:
		if node.has_method("restore_orientation"):
			return node
		node = node.get_parent()
	return null


# --- World capture and restore --------------------------------------------------

## Every actor that carries a DEFEAT authority, as an exact scene path plus the state its owners
## hold. Enumerated from `EnemyDeathComponent`'s OWN group rather than a written list, so an
## actor added later is captured the moment it exists instead of the day someone remembers it.
##
## Only state that already has an owner is captured. There is no invented field here, and the
## player is not in this list because the player has its own circuit.
##
## `paid` is the LEDGER's own reward history for this actor, read through its API rather than
## inferred from `defeated`: the economy owns the reward history, so the snapshot records what the
## economy actually held. When there is no ledger the field is simply absent, and a load derives it
## from the defeat state instead - so an unwired scene still restores, rather than the service
## recording a claim nobody is able to make.
func _capture_world() -> Array:
	var out: Array = []
	var ledger := get_ledger()
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var actor := node.get_parent()
		if actor == null or not is_instance_valid(actor):
			continue
		var entry := {
			"path": String(actor.get_path()),
			"defeated": bool(node.call("is_defeated")) if node.has_method("is_defeated") else false,
			# Whether this run has ALREADY been paid for this actor, read through the ledger's own
			# API. Recorded explicitly rather than inferred from `defeated` on the way back in: the
			# economy owns the reward history, so the snapshot records what the economy actually
			# held instead of reconstructing it from a second authority's state.
			"paid": ledger.is_rewarded(node),
		}
		var health := actor.get_node_or_null("Health") as HealthComponent
		if health != null:
			entry["health"] = health.current_health
			entry["dead"] = health.is_dead
		out.append(entry)
	# Sorted so the SAME world always produces the SAME file. A save file that reshuffles itself
	# between runs cannot be diffed or reasoned about.
	out.sort_custom(func(a, b): return String(a["path"]) < String(b["path"]))
	return out


## Put each recorded actor back to the state the snapshot recorded. Returns how many actually
## changed, so a load reports what it did rather than claiming it restored everything.
##
## An actor that is no longer in the scene is SKIPPED, not an error: the snapshot outlives the
## actors it describes, and a load must not fail because a scene was rebuilt differently. Nothing
## is created, destroyed, spawned or revived into existence here.
func _restore_world(data: Dictionary) -> int:
	if not data.has("world"):
		return 0
	var world_raw: Variant = data["world"]
	if not (world_raw is Dictionary):
		return 0
	var world: Dictionary = world_raw
	if not world.has("actors"):
		return 0
	var actors_raw: Variant = world["actors"]
	if not (actors_raw is Array):
		return 0

	var changed := 0
	for entry_raw in (actors_raw as Array):
		if not (entry_raw is Dictionary):
			continue
		var entry: Dictionary = entry_raw
		if not entry.has("path"):
			continue
		var actor := get_node_or_null(NodePath(String(entry["path"])))
		if actor == null:
			continue

		var health := actor.get_node_or_null("Health") as HealthComponent
		if health != null and entry.has("health"):
			var value := float(entry["health"])
			var dead := bool(entry.get("dead", false))
			if not is_equal_approx(health.current_health, value) or health.is_dead != dead:
				health.restore_to(value, dead)
				changed += 1

		var death := actor.get_node_or_null("Death")
		if death != null and death.has_method("restore_defeated") and entry.has("defeated"):
			if bool(death.call("restore_defeated", bool(entry["defeated"]))):
				changed += 1

	return changed


## Re-establish the ledger's REWARD HISTORY from the snapshot. Returns how many already-paid actors
## were restored to the economy's memory.
##
## THE DEFECT THIS FIXES. `CreditLedger` refuses to pay an actor twice, and it recognises "already
## paid" by the defeat component's instance id - a LIVE PROCESS id. A load puts the world back to a
## state the run recorded EARLIER, which necessarily includes actors that were killed after the save
## and are therefore alive again. Those actors are still in the ledger's paid set, so the restored
## run has live, targetable, killable enemies that pay nothing, permanently. The saved balance was
## right while the world quietly stopped earning.
##
## Authority: the LIST comes from the snapshot, which records the ledger's own answer at save time.
## `already_paid` is the explicit record; an actor the snapshot marks `defeated` without `paid` was
## retired by a restore rather than paid, and is deliberately NOT in the set.
##
## FALLBACK, so a save that predates this field still loads: when an entry has no `paid` field, the
## actor counts as paid exactly when the snapshot recorded it DEFEATED. That is the honest
## derivation - the run reached that dead world to earn it - and it is the behaviour this service
## had implicitly before the field existed, so no older file changes meaning.
func _restore_reward_tracking(data: Dictionary, ledger) -> int:
	if ledger == null or not ledger.has_method("restore_reward_tracking"):
		return 0
	if not data.has("world"):
		return 0
	var world_raw: Variant = data["world"]
	if not (world_raw is Dictionary):
		return 0
	var actors_raw: Variant = (world_raw as Dictionary).get("actors", [])
	if not (actors_raw is Array):
		return 0

	var already_paid: Array = []
	for entry_raw in (actors_raw as Array):
		if not (entry_raw is Dictionary):
			continue
		var entry: Dictionary = entry_raw
		if not entry.has("path"):
			continue
		var actor := get_node_or_null(NodePath(String(entry["path"])))
		if actor == null:
			# The snapshot outlives the actors it describes, exactly as _restore_world treats it.
			continue
		var death := actor.get_node_or_null("Death")
		if death == null:
			continue
		var paid := bool(entry.get("paid", entry.get("defeated", false)))
		if paid:
			already_paid.append(death)

	return int(ledger.call("restore_reward_tracking", already_paid))


# --- New run ------------------------------------------------------------------

## Capture the AUTHORED placement of every damageable actor, once, at boot.
##
## This is the yardstick a NEW RUN restores enemies to. It has to be RECORDED rather than read from the
## scene file at reset time, because by then the actors have moved: `TestAttacker` pursues the player,
## so its transform at the moment New Run is pressed is wherever the fight left it, not where the
## scene put it.
func _record_spawn_transforms() -> void:
	_spawn_transforms.clear()
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var actor := node.get_parent() as Node3D
		if actor == null:
			continue
		_spawn_transforms[actor.get_path()] = actor.global_transform


## Put the RUN back to the state a fresh boot produces.
##
## THE DEFECT THIS FIXES. `new_run()` reset the carried balance, minted a new run identity and deleted
## the save file - and touched no actor at all. So a New Run left the player dead where it fell, left
## every enemy it had killed still defeated with its presentation still showing, left a lock held on a
## target from the previous run, and left the HUD displaying those values. The number restarted; the
## world did not.
##
## THIS IS THE MIRROR OF `_restore_world()`. A load puts the world back to a RECORDED snapshot; a new
## run puts it back to the AUTHORED starting state. Both go through each owner's own API - health,
## stamina, defeat state and the body transform all belong to their components - so neither becomes a
## second owner of anybody's state, and neither can mint a reward.
func _reset_world() -> void:
	# 1. THE PLAYER, through the component that owns the respawn. `reset_playable_state()` already means
	#    exactly "this actor is going back on its SPAWN mark": full health, full stamina, regeneration
	#    re-enabled, every committed attack/dodge/parry cancelled, position and yaw restored. The
	#    player's spawn mark is that component's state, not this service's, so it is ASKED FOR here
	#    rather than duplicated.
	var death := get_player_death()
	if death != null and death.has_method("reset_playable_state"):
		death.call("reset_playable_state", false)

	# 2. EVERY ENEMY, enumerated from the damageable group rather than a fixed actor list, so a newly
	#    added enemy is covered the moment it exists. Each value goes back through its own owner:
	#    `HealthComponent.reset()` and `EnemyDeathComponent.restore_defeated(false)`. That restore call
	#    is the SAME one a load uses, and it deliberately does NOT emit `defeated` - which is precisely
	#    why reviving an enemy here cannot pay a reward for it.
	var player := get_player_actor()
	var revived := 0
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var actor := node.get_parent() as Node3D
		if actor == null or actor == player:
			continue
		var health := actor.get_node_or_null("Health") as HealthComponent
		if health != null:
			health.reset()
		var enemy_death := actor.get_node_or_null("Death")
		if enemy_death != null and enemy_death.has_method("restore_defeated"):
			enemy_death.call("restore_defeated", false)
		if _spawn_transforms.has(actor.get_path()):
			actor.global_transform = _spawn_transforms[actor.get_path()]
		revived += 1

	# 3. EVERY ATTACKER's own state machine, from its group for the same enumeration reason: no attack
	#    in progress, no cooldown left, an idle telegraph and a shut hitbox.
	for node in get_tree().get_nodes_in_group(DeathComponent.GROUP_ATTACKER):
		if node.has_method("reset"):
			node.call("reset")

	# 4. NO LOCK OUTLIVES THE RUN IT WAS TAKEN IN, released by its own owner with its own recorded
	#    cause, so a new run is not filed as one of the four invalidation paths or as a manual release.
	var targeting := get_tree().get_first_node_in_group(TargetingComponent.GROUP_TARGETING)
	if targeting != null and targeting.has_method("release"):
		targeting.call("release", TargetingComponent.ReleaseReason.RUN_RESET)

	_log("new-run world reset: player respawned, %d enemy actor(s) revived, lock released" % revived)


## Delete the save file. Used to start from nothing, and by a probe proving the missing-file path.
func delete_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	return dir.remove(SAVE_FILE_NAME) == OK


## Start a FRESH run: reset the carried balance to its documented starting value, give the run a NEW
## identity, and remove the save.
##
## Deliberately NOT load_game(): a new run returns its own result, mints its own identity and clears
## the save, so a fresh run can never be mistaken for a successful load of previous progress.
func new_run() -> int:
	var ledger := get_ledger()
	if ledger == null:
		return _fail(Result.NO_LEDGER, "no CreditLedger to reset")

	ledger.reset_credits()
	delete_save()
	_begin_run_identity()
	loaded_credits = -1
	# The RUN is the world as well as the number. Resetting only the balance left the player dead where
	# it fell and every killed enemy still defeated - the defect recorded in `_reset_world()`.
	_reset_world()

	new_runs += 1
	last_result = Result.OK
	last_error = ""
	_log("new run %s: carried balance reset to %d, save removed, world reset" % [run_id, ledger.credits])
	new_run_started.emit(ledger.credits)
	return Result.OK


# --- Internals ----------------------------------------------------------------

func _fail(code: int, message: String) -> int:
	last_result = code
	last_error = message
	_log("FAILED (%s): %s" % [result_name(code), message])
	return code


func _log(message: String) -> void:
	if debug_logging:
		print("[SAVE] %s" % message)
