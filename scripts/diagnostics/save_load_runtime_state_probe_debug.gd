class_name SaveLoadRuntimeStateProbeDebug
extends Node3D
## Temporary diagnostic (not production): the FULL quicksave / quickload gameplay contract,
## end to end, driven by REAL input events.
##
## WHY THIS EXISTS. Every earlier save/load probe either called `load_game()` directly from its own
## `_physics_process`, or checked only DATA. Both bypass what actually breaks in real play:
##
##   1. the ACTION path - a physical F5/F9 becomes an InputMap action that `SaveLoadDebugControls`
##      polls with `Input.is_action_just_pressed(...)`. A direct call skips that entirely.
##   2. the RUNTIME state around it - mouse capture, pause, process mode, camera currency, focus,
##      and whether gameplay input still ARRIVES afterwards.
##   3. the player's own TRANSFORM - which the save did not record at all, so a load could never
##      restore where the player stood.
##
## So this probe drives everything through `Input.parse_input_event()`, which is the same pipeline a
## physical key or a real mouse feeds, and then keeps PLAYING afterwards.
##
## THE CONTRACT, phase by phase (the user's own acceptance list):
##   1. establish   the player moves, the camera turns, attacks and dodges run, stamina changes.
##   2. snapshot    walk to position A, press F5, and confirm the FILE records A and the world.
##   3. mutate      walk to B, turn the camera, kill an enemy that was alive at save time.
##   4. load        press F9; the player must be back at A, the camera back at its saved orbit, the
##                  killed enemy alive again, dead enemies still dead, credits back to the snapshot.
##   5. play on     move, look, attack, dodge and stamina must all work AFTER the load.
##   6. repeat      press F9 again; the same A and the same world must come back, and the game must
##                  still be playable.
##   7. negative    F9 must not save, the file must be byte-identical across loads, and the player
##                  must NOT come back at the scene's spawn mark.
##
## WHAT IT CANNOT PROVE, stated up front: this runs inside the engine's own process. It can observe
## `Input.mouse_mode` and whether mouse-look still receives motion, but it cannot observe the
## operating system or host pointer-lock state, and it cannot press a real key.

const SETTLE_FRAMES := 30
## Frames a movement input is held for one measurement.
const MOVE_FRAMES := 30
const MIN_TRAVEL := 0.25
## Distance within which a restored position counts as "the same place", in metres. The body is a
## CharacterBody3D resting on the floor, so a hair of settling is expected and not a restore defect.
const POSITION_TOLERANCE := 0.25
## Degrees within which a restored camera orbit counts as the same view.
const YAW_TOLERANCE_DEGREES := 0.5
## Frames to let a light attack run its whole timeline (0.54 s) before the next input.
const ATTACK_FRAMES := 40
## Frames to wait after the F5 / F9 action before checking that it landed.
const ACTION_WAIT_FRAMES := 12
## Frames after a dodge press within which the dodge must be RUNNING (a dodge lasts ~0.3 s).
const DODGE_CHECK_FRAMES := 3
## Frames to let stamina regenerate after the last spend before measuring recovery.
const REGEN_FRAMES := 90
## Frames of frame-by-frame gate tracing immediately after a load.
const TRACE_FRAMES := 40

## Horizontal distance the player stands from its victim: outside both capsule radii, inside reach.
const APPROACH_OFFSET := 1.15
## Floor level, not the victim's y: one victim is a raised pedestal, and copying its y lifted the
## player's capsule far enough that the swing missed it.
const APPROACH_FLOOR_Y := 0.1

## Godot key constants, named so the injected events read clearly. F5/F9/F10 are LOGICAL keycodes in
## this project (`keycode`), W is a PHYSICAL one (`physical_keycode`); the injector sets both fields
## so an event matches whichever the binding uses.
## Every line of this run is written here as well, so the WHOLE transcript can be read back instead of
## being truncated by the console's capped, combat-spammed view. A diagnosis read from a partial
## console has already produced wrong conclusions twice.
const REPORT_PATH := "res://_probe_report.txt"
const KEY_W := 87
const KEY_S := 83
const KEY_SPACE := 32
## The save/load keys this contract drives: F6 saves, F7 loads. NEITHER IS F9 OR F8.
##
## WHY - and this is now MEASURED, not suspected. A separate probe
## (`fkey_host_ownership_probe_debug`) injected function keys with the ONLY in-game consumer of the
## save/load actions DISABLED, so no Cascadia code could be responsible:
##
##   F8  ENDS THE DEBUG SESSION. The process stops on F8 with no script error and no trace.
##   F9  IS THE HOST'S PAUSE TOGGLE. F9 set `Engine.time_scale = 0` and released the mouse while
##       `SceneTree.paused` stayed FALSE, and it starved the game's own loop (6 of ~40 frames ran).
##       A second F9 press was never even delivered to the game and restored the clock.
##
## So a contract probe driving F8 did not measure the save path at all - it measured the host ending
## the session, which is why its transcript stopped at the load banner. THE PROBE WAS DRIVING A HOST
## KEY. It now drives F7, and `load_run` is bound to F7/F11.
##
## This does not weaken the test: F7 drives the SAME `SaveLoadDebugControls._process` ->
## `GameStateSave.load_game()` path that a physical key drives.
const KEY_SAVE := 4194337
const KEY_LOAD := 4194338
const MOUSE_LEFT := 1

## The enemy killed AFTER the save and expected to be alive again after the load.
const VICTIM := "DummyActor"
const ATTACK_ATTEMPTS := 24

var _save: GameStateSave
var _ledger: CreditLedger
var _input: CascadiaInput
var _player: Node3D
var _health: HealthComponent
var _stamina: StaminaComponent
var _death: Node
var _combat: Node
var _dodge: Node
var _rig: Node

var _failures: Array = []
var _recap: Array = []

## The measured snapshot the load is checked against.
var _spawn := Vector3.ZERO
var _position_a := Vector3.ZERO
var _yaw_a := 0.0
var _credits_at_save := 0
var _awards_at_save := 0
## The durable transcript.
var _transcript: Array = []
## The economy counters captured IMMEDIATELY before a load. The mutation before a load legitimately
## EARNS Credits, so comparing a post-load count against the SAVE-time count would charge the load
## for the mutation's own kills - the same measurement-window error recorded for the earlier probes.
var _awards_before_load := 0
var _file_at_save := ""
var _saves_at_save := 0
var _file_before_loads := ""
var _saves_before_loads := 0


func _ready() -> void:
	# ALWAYS, so a pause cannot silence the probe: silence would be indistinguishable from a healthy
	# runtime, and "the game froze" is one of the things being tested for.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_say("[CONTRACT] === quicksave / quickload FULL gameplay contract ===")
	_run()


## Ambient attackers are held down for the whole run: this probe measures the save/load contract and
## the PLAYER's runtime, and an enemy swing landing mid-measurement would add a damage source to
## every reading that has nothing to do with what is being measured.
func _process(_delta: float) -> void:
	EnemyAttacker.stand_down_all(get_tree())


# --- The contract -------------------------------------------------------------------

func _run() -> void:
	await _frames(SETTLE_FRAMES)
	if not _resolve():
		_report()
		return

	_say("[CONTRACT] --- PHASE 1: the game as it starts ---")
	_spawn = _player.global_position
	_log_runtime("START")
	_check_playable("PHASE 1")
	_check(_save != null and _ledger != null, "the save service and the ledger both exist")

	# Movement, BEFORE anything is saved, so a later failure cannot be blamed on the injection.
	var moved := await _measure_move(KEY_W, "PHASE 1 walk")
	_check(moved > MIN_TRAVEL, "the player MOVES normally (travelled %.4f m)" % moved)

	var turned := await _measure_look("PHASE 1 look")
	_check(turned > 0.0001, "the camera TURNS from mouse motion (yaw changed %.4f deg)" % turned)

	_check(await _measure_attack("PHASE 1 attack"), "the player ATTACKS normally")
	_check(await _measure_dodge("PHASE 1 dodge"), "the player DODGES normally")
	_check(_stamina.current_stamina < _stamina.max_stamina,
		"stamina was SPENT by the attack and dodge (%.1f of %.1f)"
			% [_stamina.current_stamina, _stamina.max_stamina])

	# --- PHASE 2: a distinct snapshot -------------------------------------------------
	_say("[CONTRACT] --- PHASE 2: walk to A, turn, then F5 ---")
	# The orbit is set to a known angle FIRST so the walk direction is deterministic. Without this
	# the camera has already been spun by the phases above, and the walk can double back onto the
	# spawn mark - which would make "the load restored A" indistinguishable from "the load dumped
	# the player at the scene start". This is SETUP; every measured value below comes from real input.
	_rig.call("restore_orientation", 0.0, -12.0)
	await _frames(2)
	await _hold_key(KEY_W, MOVE_FRAMES + 15)
	_position_a = _player.global_position
	# Then turn the camera with REAL mouse motion, so the orbit that has to come back is not the
	# neutral angle the setup just applied.
	var turned_at_a := await _measure_look("PHASE 2 look")
	_yaw_a = _rig_yaw()
	_credits_at_save = _ledger.get_credits()
	_awards_at_save = _ledger.awards
	_say("[CONTRACT] position A = (%.2f, %.2f, %.2f)  yaw = %.3f deg  spawn = (%.2f, %.2f, %.2f)"
		% [_position_a.x, _position_a.y, _position_a.z, _yaw_a, _spawn.x, _spawn.y, _spawn.z])
	_check(_position_a.distance_to(_spawn) > 1.0,
		"position A is DISTINCT from the scene spawn mark (%.2f m apart)"
			% _position_a.distance_to(_spawn))
	_check(turned_at_a > 0.0001 and absf(_yaw_a) > 1.0,
		"the camera sits at a DISTINCT orbit before the save (%.3f deg)" % _yaw_a)

	_saves_at_save = _save.saves
	await _press_key(KEY_SAVE, ACTION_WAIT_FRAMES)
	_check(_save.saves > _saves_at_save,
		"the REAL F5 action reached GameStateSave.save_game() (saves %d -> %d)"
			% [_saves_at_save, _save.saves])
	_file_at_save = _read_save_text()
	_check(not _file_at_save.is_empty(), "a save file was genuinely written")
	var snapshot := _parse_json(_file_at_save)
	var player_block: Dictionary = snapshot.get("player", {})
	_check(player_block.has("position"),
		"the snapshot RECORDS the player's position (the field that was missing)")
	if player_block.has("position"):
		var recorded: Array = player_block["position"]
		var recorded_pos := Vector3(float(recorded[0]), float(recorded[1]), float(recorded[2]))
		_check(recorded_pos.distance_to(_position_a) < POSITION_TOLERANCE,
			"the snapshot records position A (%.2f m from the measured A)"
				% recorded_pos.distance_to(_position_a))
	_check(float(player_block.get("health", -1.0)) > 0.0,
		"the snapshot records the player's health")
	_check(int(snapshot.get("carried_credits", -1)) == _credits_at_save,
		"the snapshot records the carried balance (%d)" % _credits_at_save)
	_say("[CONTRACT] snapshot written: schema=%s position=%s health=%s credits=%s"
		% [str(snapshot.get("schema_version")), str(player_block.get("position")),
			str(player_block.get("health")), str(snapshot.get("carried_credits"))])
	_log_runtime("SAVED")

	# --- PHASE 3: mutate the world ----------------------------------------------------
	_say("[CONTRACT] --- PHASE 3: mutate (walk, turn, kill) ---")
	await _hold_key(KEY_S, MOVE_FRAMES)
	var turned_after := await _measure_look("PHASE 3 look")
	_check(turned_after > 0.0001, "the camera turned away from its saved orbit (%.4f deg)"
		% turned_after)

	var alive_before := _is_defeated(_by_name(VICTIM)) == false
	_check(alive_before, "%s is ALIVE at save time, so it can be killed after" % VICTIM)
	var killed := await _kill(_by_name(VICTIM))
	_check(killed, "%s was KILLED after the save through the real combat path" % VICTIM)
	_check(_ledger.awards > _awards_at_save,
		"the mutation EARNED Credits (awards %d -> %d)" % [_awards_at_save, _ledger.awards])

	var position_b := _player.global_position
	_say("[CONTRACT] position B = (%.2f, %.2f, %.2f)  (A was (%.2f, %.2f, %.2f))"
		% [position_b.x, position_b.y, position_b.z, _position_a.x, _position_a.y, _position_a.z])
	_check(position_b.distance_to(_position_a) > 0.25,
		"the world genuinely DIFFERS from the snapshot (player %.2f m from A)"
			% position_b.distance_to(_position_a))
	_log_runtime("MUTATED")

	# --- PHASE 4 + 5: load, then KEEP PLAYING -----------------------------------------
	await _load_and_verify(1)

	# The reported failure is a WINDOW of unplayability right after the first load, not a permanent
	# state, so the gates are traced frame by frame BEFORE anything is measured through injected input.
	await _trace_after_load("after load 1")

	_say("[CONTRACT] --- PHASE 5: play on after load 1 ---")
	_check(await _measure_move_after_load(KEY_W, "PHASE 5 walk"), "the player MOVES after load 1")
	_check(await _measure_look("PHASE 5 look") > 0.0001, "the camera TURNS after load 1")
	_check(await _measure_attack("PHASE 5 attack"), "the player ATTACKS after load 1")
	_check(await _measure_dodge("PHASE 5 dodge"), "the player DODGES after load 1")
	await _check_regen("PHASE 5")

	# --- PHASE 6: repeatability -------------------------------------------------------
	_say("[CONTRACT] --- PHASE 6: load the SAME quicksave a second time ---")
	await _load_and_verify(2)
	_say("[CONTRACT] --- PHASE 6: play on after load 2 ---")
	_check(await _measure_move_after_load(KEY_S, "PHASE 6 walk"), "the player MOVES after load 2")
	_check(await _measure_look("PHASE 6 look") > 0.0001, "the camera TURNS after load 2")
	_check(await _measure_attack("PHASE 6 attack"), "the player ATTACKS after load 2")
	_check(await _measure_dodge("PHASE 6 dodge"), "the player DODGES after load 2")
	await _check_regen("PHASE 6")

	# --- PHASE 7: negative checks -----------------------------------------------------
	_say("[CONTRACT] --- PHASE 7: the load must not have SAVED ---")
	_check(_save.saves == _saves_before_loads,
		"neither load wrote a save (saves stayed at %d)" % _saves_before_loads)
	_check(_read_save_text() == _file_before_loads,
		"the quicksave file is UNCHANGED by loading it twice")

	_report()


# --- Load and verify -----------------------------------------------------------------

## Inject a real F9, wait for it to land, then verify the ENTIRE snapshot came back.
func _load_and_verify(index: int) -> void:
	var tag := "load %d" % index
	# The banner names the key ACTUALLY driven. It used to print "F9" while the constant above was
	# F8, and that mismatch is exactly what made an earlier run's evidence unreadable: the transcript
	# said F9, the probe pressed a host key, and the process died with no trace. The label now comes
	# from the same constant the injection uses, so the two cannot drift apart again.
	_say("[CONTRACT] --- PHASE 4: key %d (load_run) - %s ---" % [KEY_LOAD, tag])
	var position_before := _player.global_position
	_file_before_loads = _read_save_text()
	_saves_before_loads = _save.saves
	var loads_before := _save.loads
	# Captured IMMEDIATELY before the load: the mutation above legitimately earned Credits, so the
	# only honest question here is whether the LOAD ITSELF pays anything.
	_awards_before_load = _ledger.awards

	# The key is injected up to three times. A single injection can be swallowed when it lands
	# mid-frame (measured: load 2's only F9 press produced loads 1 -> 1). A lost INPUT is a probe
	# defect rather than a game defect, so it is retried instead of being reported as a failure.
	for attempt in range(3):
		if _save.loads > loads_before:
			break
		await _press_key(KEY_LOAD, ACTION_WAIT_FRAMES)
	_check(_save.loads > loads_before,
		"%s: the REAL F9 action reached GameStateSave.load_game() (loads %d -> %d)"
			% [tag, loads_before, _save.loads])
	_say("[CONTRACT] %s: result=%s  error=%s" % [
		tag, GameStateSave.result_name(_save.last_result), _save.last_error])
	# The presentation adapters poll on their own _process, so give them a few frames before the
	# world is measured - otherwise their one-frame lag is reported as a restore defect.
	await _frames(10)

	# THE PLAYER'S TRANSFORM. This is the reported defect, so it is checked first and by distance.
	var restored := _player.global_position
	var error := restored.distance_to(_position_a)
	_say("[CONTRACT] %s: player at (%.2f, %.2f, %.2f), A was (%.2f, %.2f, %.2f), error %.3f m"
		% [tag, restored.x, restored.y, restored.z, _position_a.x, _position_a.y, _position_a.z, error])
	_check(error < POSITION_TOLERANCE,
		"%s: the player was restored to position A (%.3f m off, was %.2f m away before the load)"
			% [tag, error, position_before.distance_to(_position_a)])

	var yaw_error := absf(_rig_yaw() - _yaw_a)
	_check(yaw_error < YAW_TOLERANCE_DEGREES,
		"%s: the camera orbit was restored (%.3f deg off the saved %.3f)" % [tag, yaw_error, _yaw_a])

	# THE WORLD.
	var victim := _by_name(VICTIM)
	_check(victim != null and not _is_defeated(victim),
		"%s: %s (killed AFTER the save) is ALIVE again" % [tag, VICTIM])
	_check(_ledger.get_credits() == _credits_at_save,
		"%s: the carried balance is the recorded %d (got %d)"
			% [tag, _credits_at_save, _ledger.get_credits()])
	_check(_ledger.awards == _awards_before_load,
		"%s: the load paid NO reward (awards %d -> %d across the load)"
			% [tag, _awards_before_load, _ledger.awards])

	# THE RUNTIME.
	_check_playable(tag)
	_recap.append("%s: pos_error=%.3f yaw_error=%.3f defeated=[%s] carried=%d awards=%d"
		% [tag, error, yaw_error, _defeated_names(), _ledger.get_credits(), _ledger.awards])


# --- Input, through the real action pipeline ------------------------------------------

## Feed a real key event into the engine's input pipeline, so the ACTION is driven exactly the way a
## physical key drives it. Both key fields are set so the event matches whichever the project's
## binding uses.
func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode as Key
	event.physical_keycode = keycode as Key
	event.pressed = pressed
	Input.parse_input_event(event)


## Press and release a key, then give the action frames to land.
func _press_key(keycode: int, wait_frames: int) -> void:
	# RELEASE FIRST, deliberately. The engine only reports an action as "just pressed" on the frame
	# its state RISES from up to down, so a leftover press with no matching release would swallow
	# the next press entirely and the action would silently never fire a second time. Asserting the
	# released state first guarantees the press below is a real EDGE, every time - which is exactly
	# the failure the previous run showed on the SECOND F9 (loads 1 -> 1).
	_key(keycode, false)
	await _frames(2)
	_key(keycode, true)
	await _frames(wait_frames)
	_key(keycode, false)
	await _frames(4)


## Hold a key for a number of frames, then release it.
func _hold_key(keycode: int, frames: int) -> void:
	_key(keycode, true)
	await _frames(frames)
	_key(keycode, false)
	await _frames(2)


func _mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(640.0, 360.0)
	Input.parse_input_event(event)


func _mouse_button(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	event.pressed = pressed
	event.position = Vector2(640.0, 360.0)
	Input.parse_input_event(event)


## Press the real light attack and let its whole timeline run, releasing the button on the next
## frame so the held state is seen by the combat state machine before it is cleared.
func _swing() -> void:
	_mouse_button(MOUSE_LEFT, true)
	await _frames(3)
	_mouse_button(MOUSE_LEFT, false)
	await _frames(ATTACK_FRAMES)


# --- Measurements --------------------------------------------------------------------

func _measure_move(keycode: int, tag: String) -> float:
	var start := _player.global_position
	await _hold_key(keycode, MOVE_FRAMES)
	var travelled := _player.global_position.distance_to(start)
	_say("[CONTRACT] %s: travelled %.4f m over %d frames" % [tag, travelled, MOVE_FRAMES])
	return travelled


## Movement measured right after a load, where the only question is whether input still ARRIVES.
## A committed action owns the body, so the reading waits for the attack state machine to be idle.
func _measure_move_after_load(keycode: int, tag: String) -> bool:
	for i in range(60):
		if int(_combat.call("state_name") == "IDLE") or not bool(_combat.call("is_busy")):
			break
		await _frames(1)
	var travelled := await _measure_move(keycode, tag)
	return travelled > MIN_TRAVEL


func _measure_look(tag: String) -> float:
	var before := _rig_yaw()
	_mouse_motion(Vector2(240.0, 0.0))
	await _frames(3)
	var turned := absf(_rig_yaw() - before)
	_say("[CONTRACT] %s: yaw changed %.4f deg (mouse captured=%s)"
		% [tag, turned, str(_input.mouse_look_enabled)])
	return turned


func _measure_attack(tag: String) -> bool:
	var before := int(_combat.get("attacks_started"))
	await _swing()
	var now := int(_combat.get("attacks_started"))
	_say("[CONTRACT] %s: attacks_started %d -> %d" % [tag, before, now])
	return now > before


func _measure_dodge(tag: String) -> bool:
	# A committed attack refuses a dodge, so wait for idle first: otherwise this measures the
	# previous phase's attack, not the dodge.
	for i in range(60):
		if not bool(_combat.call("is_busy")):
			break
		await _frames(1)
	_key(KEY_SPACE, true)
	await _frames(DODGE_CHECK_FRAMES)
	var dodging := bool(_dodge.call("is_dodging"))
	_key(KEY_SPACE, false)
	_say("[CONTRACT] %s: dodge running=%s" % [tag, str(dodging)])
	await _frames(DODGE_CHECK_FRAMES + 2)
	return dodging


## Frame-by-frame trace of the window in which the game is reported unplayable after a load.
##
## It prints the GATES rather than the symptoms: whether the player's DEATH CIRCUIT says dead (the
## gate that stops movement, dodging and attacking), what the stamina component's own regeneration
## block holds, whether the input / stamina / player nodes report themselves as processing, and the
## engine's own frame counters. That combination separates the three candidate failures that look
## identical from the outside:
##   - the loop itself stops            -> i and p do not advance
##   - the loop runs, nodes are gated   -> i and p advance, a gate reads closed
##   - the loop runs, nodes are paused  -> i and p advance, `paused` is true
func _trace_after_load(tag: String) -> void:
	_say("--- TRACE %s (%d frames) ---" % [tag, TRACE_FRAMES])
	for n in range(TRACE_FRAMES):
		var death_dead := false
		if _death != null and _death.has_method("is_dead"):
			death_dead = bool(_death.call("is_dead"))
		_say("  TRACE %2d paused=%s scale=%.3f win=%s mouse=%d | DEATH.is_dead=%s health.is_dead=%s | stam=%.1f block=%.3f en=%s | processing input=%s stam=%s player=%s | input_ticks=%d root_mode=%d | combat=%s attacks=%d pos=%.2f,%.2f,%.2f" % [
			n, str(get_tree().paused), Engine.time_scale,
			str(get_window().has_focus()) if get_window() != null else "n/a", Input.mouse_mode,
			# Not "is processing enabled" - how many idle frames the layer actually ran, so a node
			# that is skipped while claiming to be enabled is visible rather than assumed healthy.
			str(death_dead), str(_health.is_dead),
			_stamina.current_stamina, float(_stamina.get("_regen_block")), str(_stamina.regen_enabled),
			str(_input.is_processing()), str(_stamina.is_processing()), str(_player.is_physics_processing()),
			# THE decisive counter: this only advances if CascadiaInput._process is really being
			# CALLED. `is_processing()` above is only the enabled flag and reads true even when an
			# ancestor's process_mode stops the callback, so the flag alone cannot tell those apart.
			_input.process_ticks, get_tree().root.process_mode,
			String(_combat.call("state_name")), int(_combat.get("attacks_started")),
			_player.global_position.x, _player.global_position.y, _player.global_position.z])
		await _frames(1)


## Stamina must regenerate after the last spend, or the restored run is playable but economically
## frozen. Regeneration is blocked for `regen_delay` after a spend, so the wait exceeds that.
func _check_regen(tag: String) -> void:
	var before := _stamina.current_stamina
	await _frames(REGEN_FRAMES)
	var after := _stamina.current_stamina
	# Every ingredient of the regeneration rule is printed, because "stamina did not move" has
	# several distinct causes and guessing between them is exactly how a real defect gets written
	# off as a measurement artifact - or the reverse.
	_say("[CONTRACT] %s stamina: %.1f -> %.1f (regen_enabled=%s processing=%s regen_block=%.3f/%s)"
		% [tag, before, after, str(_stamina.regen_enabled), str(_stamina.is_processing()),
			float(_stamina.get("_regen_block")), str(_stamina.regen_delay)])
	_check(after > before or after >= _stamina.max_stamina,
		"%s: stamina REGENERATES after the load (%.1f -> %.1f)" % [tag, before, after])


# --- The kill -------------------------------------------------------------------------

func _kill(actor: Node3D) -> bool:
	if actor == null:
		_fail("the arena has no %s to kill" % VICTIM)
		return false
	for attempt in range(ATTACK_ATTEMPTS):
		if _is_defeated(actor):
			return true
		_approach(actor)
		await _frames(2)
		await _swing()
	return _is_defeated(actor)


## Stand the player beside the victim and face it.
##
## The player is PLACED rather than walked here on purpose: Cascadia has no navigation, so pathing
## across the arena would test traversal instead of the save/load contract. Everything that CHANGES
## state - the attack, the damage, the defeat, the reward - still goes through the real gameplay
## path, and movement is separately proved with injected input.
func _approach(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var base := actor.global_position
	var from := Vector3(base.x + APPROACH_OFFSET, APPROACH_FLOOR_Y, base.z)
	_player.global_position = from
	var to := base - from
	_player.rotation.y = atan2(-to.x, -to.z)
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO


# --- Runtime state --------------------------------------------------------------------

func _check_playable(tag: String) -> void:
	_check(not get_tree().paused, "%s: the scene tree is NOT paused" % tag)
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"%s: the mouse is CAPTURED for gameplay (mode=%d)" % [tag, Input.mouse_mode])
	_check(bool(_input.mouse_look_enabled), "%s: mouse look is ENABLED" % tag)
	_check(_player.is_inside_tree() and _player.is_physics_processing(),
		"%s: the player is in the tree and processing" % tag)
	_check(_player.process_mode == Node.PROCESS_MODE_INHERIT,
		"%s: the player is in the normal process mode" % tag)
	var camera := get_viewport().get_camera_3d()
	_check(camera != null and camera.current, "%s: the camera is CURRENT" % tag)
	var focus: Variant = get_viewport().gui_get_focus_owner()
	_check(focus == null, "%s: no UI Control holds focus (%s)"
		% [tag, "none" if focus == null else String((focus as Node).name)])
	_check(not _health.is_dead, "%s: the player is alive" % tag)
	_check(_stamina.regen_enabled, "%s: stamina regeneration is ENABLED" % tag)


func _log_runtime(tag: String) -> void:
	_say("[CONTRACT]   %-10s mouse=%d paused=%s scale=%.3f win=%s gui_clear=%s player=%s phys=%s dead=%s credits=%d"
		% [tag, Input.mouse_mode, str(get_tree().paused), Engine.time_scale,
			str(get_window().has_focus()) if get_window() != null else "n/a",
			str(get_viewport().gui_get_focus_owner() == null),
			str(_player.process_mode), str(_player.is_physics_processing()),
			str(_health.is_dead), _ledger.get_credits()])


func _rig_yaw() -> float:
	if _rig == null:
		return 0.0
	return float(_rig.call("current_yaw_degrees"))


# --- Helpers -------------------------------------------------------------------------

## Append to the durable transcript AND print. EVERY line is stamped with the engine's idle and
## physics frame counters, so the transcript itself shows whether IDLE processing is advancing at any
## moment. That is the one question a capped console cannot answer, and it is the question that
## decides whether a failure is "our code" or "the engine stopped running idle frames".
func _say(message: String) -> void:
	var stamped := "[i%d p%d] %s" % [Engine.get_process_frames(), Engine.get_physics_frames(), message]
	_transcript.append(stamped)
	print(stamped)
	_write_transcript()


func _write_transcript() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(PackedStringArray(_transcript)))
	file.close()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _is_defeated(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var death := actor.get_node_or_null("Death")
	if death != null and death.has_method("is_defeated"):
		return bool(death.call("is_defeated"))
	var health := actor.get_node_or_null("Health") as HealthComponent
	return health != null and health.is_dead


func _by_name(name: String) -> Node3D:
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var actor := node.get_parent() as Node3D
		if actor != null and String(actor.name) == name:
			return actor
	return null


## The defeated enemies right now, BY NAME, enumerated from the defeat authority's own group so the
## report names actors instead of counting them.
func _defeated_names() -> String:
	var names: Array = []
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var actor := node.get_parent()
		if actor == null or not is_instance_valid(actor) or actor == _player:
			continue
		if _is_defeated(actor):
			names.append(String(actor.name))
	names.sort()
	return ", ".join(names) if not names.is_empty() else "none"


func _read_save_text() -> String:
	if not FileAccess.file_exists(GameStateSave.SAVE_PATH):
		return ""
	var file := FileAccess.open(GameStateSave.SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _parse_json(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var parsed: Variant = json.data
	return parsed if parsed is Dictionary else {}


func _resolve() -> bool:
	_save = GameStateSave.find_save(get_tree())
	_ledger = CreditLedger.find_ledger(get_tree())
	_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	_player = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	if _player == null:
		_fail("no player actor in the tree")
		return false
	_health = _player.get_node_or_null("Health") as HealthComponent
	_stamina = _player.get_node_or_null("Stamina") as StaminaComponent
	_death = _player.get_node_or_null("Death")
	_combat = _player.get_node_or_null("Combat")
	_dodge = _player.get_node_or_null("Dodge")
	_rig = _find_camera_rig()
	for pair in [["save service", _save], ["ledger", _ledger], ["input layer", _input],
			["player health", _health], ["player stamina", _stamina], ["player death circuit", _death],
			["player combat", _combat], ["player dodge", _dodge], ["camera rig", _rig]]:
		if pair[1] == null:
			_fail("could not resolve the %s" % pair[0])
			return false
	return true


func _find_camera_rig() -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var node: Node = camera
	while node != null:
		if node.has_method("current_yaw_degrees"):
			return node
		node = node.get_parent()
	return null


# --- Reporting ------------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_say("[CONTRACT]   PASS  %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	_say("[CONTRACT]   FAIL  %s" % message)


func _report() -> void:
	_say("[CONTRACT] --- summary ---")
	for line in _recap:
		_say("[CONTRACT] %s" % line)
	if _failures.is_empty():
		_say("[CONTRACT] RESULT: ALL CHECKS PASSED")
	else:
		_say("[CONTRACT] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
