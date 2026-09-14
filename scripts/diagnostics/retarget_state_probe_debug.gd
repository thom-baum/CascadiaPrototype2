class_name RetargetStateProbeDebug
extends Node3D
## Temporary diagnostic (not production): WHAT exactly blocks the game after a RETARGET?
##
## WHY THIS EXISTS. The reported failure after Alt-Tabbing back and clicking the window:
##
##   - retargeting succeeds, but the mouse is NOT captured (cursor stays free)
##   - camera movement STILL works
##   - player movement is completely unavailable
##   - light and heavy attack presses are accepted, but NO attack phase ever begins
##
## Those five facts are a very specific signature, and they rule things out. This probe exists to
## measure which one is true instead of arguing about it, because two candidate causes produce nearly
## identical symptoms and only DIFFERENT numbers can tell them apart:
##
##   CAUSE A - the input layer is suspended (focus gate closed).
##       REFUTED BY CONSTRUCTION, and this probe re-proves it: `get_look_delta()` returns ZERO while
##       suspended, so a camera that still turns proves the layer is ACTIVE. If the layer is active
##       then `get_move_vector()` and `consume_light_attack()` are NOT the thing refusing.
##
##   CAUSE B - the game's clock has stopped (delta 0) while frames keep rendering.
##       Mouse look is DELTA-INDEPENDENT in this project: `_update_look()` folds mouse motion with no
##       delta, and the rig applies `look.x * yaw_sensitivity` with no delta. Movement and every
##       attack phase ARE delta-driven (`_physics_process`). So a stopped clock leaves the camera
##       working while movement, attack phases and dodge completion all stand still - the exact
##       signature. This probe reports `Engine.time_scale`, the tree's pause state, and the layer's own
##       `clock_resumes` counter, which is the measurement that separates "our clock" from "the host
##       re-stopping it every frame".
##
##   CAUSE C - a committed action owns the body (attack stuck in a phase, dodge never finishing).
##       Reported directly: combat state, `is_busy`, and the dodge/parry flags.
##
## It also answers the parts of the report that are simply NOT TRUE of this build, so they stop being
## chased: this project has NO animation system (roadmap 8E.5 / deferred list), so there is no
## AnimationPlayer or AnimationTree to play an attack animation, and no attack animation to miss. What
## can be measured is whether the attack state machine ENTERS its phases, which is what gameplay
## actually promises. The probe counts animation nodes at runtime rather than asserting from memory.
##
## NOTHING HERE IS A FIX. It reports state and never changes gameplay behaviour.

const REPORT_PATH := "res://_retarget_probe_report.txt"
const SETTLE_FRAMES := 30
const MOVE_FRAMES := 20
const MIN_TRAVEL := 0.25
## Frames to watch one attack. Longer than the whole light timeline (0.54 s) so every phase is seen.
const ATTACK_FRAMES := 45
## Frames to keep watching after the button is released, to catch a late phase.
const ATTACK_TAIL_FRAMES := 10
const REGEN_FRAMES := 60
## Frames dumped in full after the retarget. This trace is what names the blocker.
const TRACE_FRAMES := 20

var _input: CascadiaInput
var _player: Node3D
var _health: HealthComponent
var _stamina: StaminaComponent
var _death: Node
var _combat: Node
var _dodge: Node
var _parry: Node
var _rig: Node

var _failures: Array = []
var _transcript: Array = []


func _ready() -> void:
	# ALWAYS, so a stopped clock or a pause cannot silence the probe that is measuring them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_say("[RETARGET] === what blocks the game after a retarget? ===")
	_run()


func _process(_delta: float) -> void:
	EnemyAttacker.stand_down_all(get_tree())


func _run() -> void:
	await _frames(SETTLE_FRAMES)
	if not _resolve():
		_report()
		return

	_say("[RETARGET] --- PHASE 1: baseline, focused ---")
	_dump_state("BASELINE")
	_check(await _measure_look("BASELINE"), "BASELINE: the camera turns (the control for every later camera claim)")
	var moved := await _measure_move("BASELINE")
	_check(moved > MIN_TRAVEL, "BASELINE: the player MOVES (%.4f m)" % moved)
	var light := await _watch_attack(GameActions.LIGHT_ATTACK)
	_say("[RETARGET] BASELINE light attack: button=%d started=%d phases=%s"
		% [int(light["button"]), int(light["started"]), str(light["phases"])])
	_check(int(light["started"]) > 0, "BASELINE: a LIGHT attack starts")
	_check(_has_phase(light, "ACTIVE"), "BASELINE: the light attack reaches its ACTIVE phase")
	var heavy := await _watch_attack(GameActions.HEAVY_ATTACK)
	_say("[RETARGET] BASELINE heavy attack: button=%d started=%d phases=%s"
		% [int(heavy["button"]), int(heavy["started"]), str(heavy["phases"])])
	_check(int(heavy["started"]) > 0, "BASELINE: a HEAVY attack starts")
	_check(_has_phase(heavy, "ACTIVE"), "BASELINE: the heavy attack reaches its ACTIVE phase")

	# --- PHASE 2: the retarget --------------------------------------------------------
	_say("[RETARGET] --- PHASE 2: RETARGET (alt-tab away, click the window, come back) ---")
	var lost_before := _input.focus_lost_count
	var gained_before := _input.focus_gained_count
	var captures_before := _input.capture_requests_on_press
	_set_engine_focus(false)
	_check(_input.focus_lost_count > lost_before, "RETARGET: the layer saw focus LEAVE")
	# The click that retargets. Real mouse event through the engine's own pipeline, which is the same
	# path a physical click takes - and the ONLY context this host can grant pointer lock in.
	_mouse_button(MOUSE_BUTTON_LEFT, true)
	Input.flush_buffered_events()
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	Input.flush_buffered_events()
	_set_engine_focus(true)
	_check(_input.focus_gained_count > gained_before, "RETARGET: the layer saw focus RETURN")
	_check(_input.capture_requests_on_press > captures_before,
		"RETARGET: the click ASKED the host for the cursor (%d -> %d)"
			% [captures_before, _input.capture_requests_on_press])

	# --- PHASE 3: the state at the failure, frame by frame ----------------------------
	_say("[RETARGET] --- PHASE 3: state immediately after the retarget (%d frames) ---" % TRACE_FRAMES)
	for n in range(TRACE_FRAMES):
		_dump_state("POST-RETARGET %02d" % n)
		await _frames(1)

	# --- PHASE 4: the five reported facts ---------------------------------------------
	_say("[RETARGET] --- PHASE 4: the reported failures, re-tested after the retarget ---")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"POST-RETARGET: the mouse is CAPTURED (mode=%d)" % Input.mouse_mode)
	_check(_input.is_input_active(),
		"POST-RETARGET: the input layer is ACTIVE, so movement is NOT refused by the focus gate")
	var moved_after := await _measure_move("POST-RETARGET")
	_check(moved_after > MIN_TRAVEL, "POST-RETARGET: the player MOVES (%.4f m)" % moved_after)
	_check(await _measure_look("POST-RETARGET"), "POST-RETARGET: the camera still turns")
	var light_after := await _watch_attack(GameActions.LIGHT_ATTACK)
	_say("[RETARGET] POST-RETARGET light attack: button=%d started=%d phases=%s"
		% [int(light_after["button"]), int(light_after["started"]), str(light_after["phases"])])
	_check(int(light_after["started"]) > 0, "POST-RETARGET: a LIGHT attack starts")
	_check(_has_phase(light_after, "ACTIVE"), "POST-RETARGET: the light attack reaches ACTIVE")
	var heavy_after := await _watch_attack(GameActions.HEAVY_ATTACK)
	_say("[RETARGET] POST-RETARGET heavy attack: button=%d started=%d phases=%s"
		% [int(heavy_after["button"]), int(heavy_after["started"]), str(heavy_after["phases"])])
	_check(int(heavy_after["started"]) > 0, "POST-RETARGET: a HEAVY attack starts")
	_check(_has_phase(heavy_after, "ACTIVE"), "POST-RETARGET: the heavy attack reaches ACTIVE")

	# --- PHASE 5: no stale lock survived the transition -------------------------------
	_say("[RETARGET] --- PHASE 5: no stale gameplay lock survived the retarget ---")
	await _frames(REGEN_FRAMES)
	_check(String(_combat.call("state_name")) == "IDLE",
		"POST-RETARGET: the combat state machine is back to IDLE (%s)" % String(_combat.call("state_name")))
	_check(not bool(_combat.call("is_busy")), "POST-RETARGET: combat is NOT busy")
	_check(not bool(_dodge.call("is_dodging")), "POST-RETARGET: no dodge is stuck ACTIVE")
	_check(not _is_parrying(), "POST-RETARGET: no parry is stuck ACTIVE")
	_check(not _health.is_dead, "POST-RETARGET: the player is alive")
	_check(not bool(_call_or_absent(_death, "is_defeated", false)),
		"POST-RETARGET: the player is not defeated")
	_check_no_freeze("POST-RETARGET")
	_check(_input.clock_resumes == 0,
		"POST-RETARGET: the layer never had to put the clock back (%d resume(s)) - a NON-ZERO count"
		% _input.clock_resumes + " means something OUTSIDE stops the clock and no in-game code can win")
	_check(_stamina.current_stamina > 0.0 or _stamina.is_full(),
		"POST-RETARGET: stamina is not permanently drained (%.1f)" % _stamina.current_stamina)

	# --- PHASE 6: what does NOT exist, stated rather than chased ----------------------
	_say("[RETARGET] --- PHASE 6: systems the report assumes, measured rather than assumed ---")
	var animators := _count_animation_nodes()
	_say("[RETARGET] animation nodes on the player: %d (AnimationPlayer + AnimationTree)" % animators)
	_check(animators == 0,
		"PHASE 6: this build has NO animation system on the player, so 'no attack animation plays' is"
		+ " expected and is not a separate defect - the attack PHASES above are what gameplay promises")
	_check(_call_or_absent(_combat, "is_stunned", "ABSENT-METHOD") == "ABSENT-METHOD",
		"PHASE 6: `is_stunned` does not exist on PlayerCombat - reported, not invented")
	_check(_call_or_absent(_player, "can_control", "ABSENT-METHOD") == "ABSENT-METHOD",
		"PHASE 6: `can_control` does not exist on the player - reported, not invented")

	_report()


# --- State reporting -----------------------------------------------------------------

## Every value the report asked for, in one durable line. `absent` is printed where a method does not
## exist, because inventing a plausible number for a method that is not there is how a false diagnosis
## gets written.
func _dump_state(tag: String) -> void:
	var focus := false
	var window := get_window()
	if window != null:
		focus = window.has_focus()
	var move := _input.get_move_vector() if _input != null else Vector2.ZERO
	_say("[RETARGET] %-18s mouse=%d focus=%s input_active=%s scale=%.3f paused=%s | "
		% [tag, Input.mouse_mode, str(focus), str(_input.is_input_active()), Engine.time_scale,
			str(get_tree().paused)]
		+ "ticks=%d clock_resumes=%d look_intent=%s | combat=%s busy=%s attacks=%d | "
		% [_input.process_ticks, _input.clock_resumes, str(_input.mouse_look_enabled),
			String(_combat.call("state_name")), str(bool(_combat.call("is_busy"))), _attacks()]
		+ "dodge=%s parry=%s dead=%s defeated=%s | move=(%.2f,%.2f) committed=%s | "
		% [str(bool(_dodge.call("is_dodging"))), str(_is_parrying()), str(_health.is_dead),
			str(bool(_call_or_absent(_death, "is_defeated", false))), move.x, move.y,
			str(bool(_call_or_absent(_player, "_is_committed", false)))]
		+ "phys_process=%s mode=%d | attack_buffer=%.2f stam=%.1f"
		% [str(_player.is_physics_processing()), _player.process_mode,
			_input.buffer_time(GameActions.LIGHT_ATTACK), _stamina.current_stamina])


func _check_no_freeze(tag: String) -> void:
	_check(not get_tree().paused, "%s: the scene tree is NOT paused" % tag)
	_check(Engine.time_scale > 0.0,
		"%s: the clock is RUNNING (scale=%.3f) - a 0.000 freezes movement and every attack phase"
			% [tag, Engine.time_scale])


# --- Measurements --------------------------------------------------------------------

func _watch_attack(action: StringName) -> Dictionary:
	var button := _bound_mouse_button(action)
	var started_before := _attacks()
	var phases: Array = []
	if button == 0:
		return {"button": 0, "started": 0, "phases": phases}
	_mouse_button(button, true)
	for i in range(ATTACK_FRAMES):
		_note_phase(phases)
		await _frames(1)
	_mouse_button(button, false)
	for i in range(ATTACK_TAIL_FRAMES):
		_note_phase(phases)
		await _frames(1)
	await _frames(4)
	return {"button": button, "started": _attacks() - started_before, "phases": phases}


func _note_phase(phases: Array) -> void:
	var name := String(_combat.call("state_name"))
	if not phases.has(name):
		phases.append(name)


func _has_phase(result: Dictionary, phase: String) -> bool:
	return (result["phases"] as Array).has(phase)


func _measure_move(tag: String) -> float:
	var start := _player.global_position
	_key(KEY_W, true)
	await _frames(MOVE_FRAMES)
	_key(KEY_W, false)
	await _frames(2)
	var travelled := _player.global_position.distance_to(start)
	_say("[RETARGET] %s move: travelled %.4f m over %d frames" % [tag, travelled, MOVE_FRAMES])
	return travelled


func _measure_look(tag: String) -> bool:
	var before := _rig_yaw()
	_mouse_motion(Vector2(240.0, 0.0))
	await _frames(3)
	var turned := absf(_rig_yaw() - before)
	_say("[RETARGET] %s look: yaw changed %.4f deg" % [tag, turned])
	return turned > 0.0001


# --- Helpers -------------------------------------------------------------------------

func _resolve() -> bool:
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
	_parry = _player.get_node_or_null("Parry")
	_rig = _find_camera_rig()
	for pair in [["input layer", _input], ["player health", _health], ["player stamina", _stamina],
			["player death circuit", _death], ["player combat", _combat], ["player dodge", _dodge],
			["camera rig", _rig]]:
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


func _is_parrying() -> bool:
	if _parry == null or not is_instance_valid(_parry):
		return false
	return bool(_call_or_absent(_parry, "is_parrying", false))


## Call a method if it exists, else return `fallback`. Used so a missing method is REPORTED as missing
## instead of being read as a healthy false.
func _call_or_absent(node: Node, method: String, fallback: Variant) -> Variant:
	if node == null or not is_instance_valid(node) or not node.has_method(method):
		return fallback
	return node.call(method)


func _attacks() -> int:
	if _combat == null:
		return -1
	return int(_combat.get("attacks_started"))


func _count_animation_nodes() -> int:
	var found := 0
	for node in _player.find_children("*", "AnimationPlayer", true, false):
		if node != null:
			found += 1
	for node in _player.find_children("*", "AnimationTree", true, false):
		if node != null:
			found += 1
	return found


func _rig_yaw() -> float:
	if _rig == null:
		return 0.0
	return float(_rig.call("current_yaw_degrees"))


func _bound_mouse_button(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			return (event as InputEventMouseButton).button_index
	return 0


func _set_engine_focus(focused: bool) -> void:
	var what := NOTIFICATION_APPLICATION_FOCUS_IN if focused else NOTIFICATION_APPLICATION_FOCUS_OUT
	get_tree().root.propagate_notification(what)


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode as Key
	event.physical_keycode = keycode as Key
	event.pressed = pressed
	Input.parse_input_event(event)


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


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		_say("[RETARGET]   PASS  %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	_say("[RETARGET]   FAIL  %s" % message)


func _report() -> void:
	if _failures.is_empty():
		_say("[RETARGET] RESULT: ALL CHECKS PASSED")
	else:
		_say("[RETARGET] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])


func _say(message: String) -> void:
	var stamped := "[i%d p%d] %s" % [Engine.get_process_frames(), Engine.get_physics_frames(), message]
	_transcript.append(stamped)
	print(stamped)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(PackedStringArray(_transcript)))
		file.close()
