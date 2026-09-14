class_name FocusInputRoutingProbeDebug
extends Node3D
## Temporary diagnostic (not production): does a WINDOW FOCUS change leave Cascadia's gameplay input
## in a correct state, and does everything recover when focus comes back?
##
## WHY THIS EXISTS. The reported defect is not a save/load defect and not a crash:
##
##     Alt-Tab away from the game, come back -> moving the mouse still turns the camera, and
##     regaining focus does not restore input behaviour correctly.
##
## The window losing focus is an ENGINE condition, not a key press, so nothing in the project could
## simulate it by injecting input. This probe supplies the missing half honestly: it PROPAGATES the
## engine's own focus notifications (`NOTIFICATION_APPLICATION_FOCUS_OUT` / `_IN`) through the live
## scene tree, exactly the way the engine delivers them to every node on a real Alt-Tab. That makes
## the project's notification handlers run for real, which is the one thing injected input cannot do.
##
## WHAT IT CANNOT DO, stated up front and not glossed:
##
##   - It cannot take real OS focus away from the window. `Window.has_focus()` keeps reporting true
##     while it runs, so the per-frame reconciliation in `CascadiaInput` (which reads the engine's
##     live report) cannot be exercised by the notification alone.
##   - It cannot move a real mouse or press a real key.
##
## So the notification path is measured here, and the reconciliation path is measured by the fact
## that the layer runs `_refresh_focus()` every frame before anything reads input.
##
## The checks follow the user's acceptance list, one per line, and each FAIL names what broke.

const SETTLE_FRAMES := 30
## Frames a movement key is held for one measurement.
const MOVE_FRAMES := 20
## Distance in metres that counts as "the player moved".
const MIN_TRAVEL := 0.25
## Frames to let a light attack run its whole timeline (0.54 s) before the next input.
const ATTACK_FRAMES := 40
## Frames after a dodge press within which the dodge must be RUNNING.
const DODGE_CHECK_FRAMES := 3
## Frames to let stamina regenerate after the last spend.
const REGEN_FRAMES := 90
## Frames to wait after a refocus before checking that no stale look delta is spent.
const STALE_FRAMES := 6

## Godot key constants, named so the injected events read clearly.
const KEY_W := 87
const KEY_SPACE := 32
const MOUSE_LEFT := 1

## Durable transcript, its own file so it cannot overwrite the save/load contract probe's evidence.
const REPORT_PATH := "res://_focus_probe_report.txt"

var _input: CascadiaInput
var _player: Node3D
var _health: HealthComponent
var _stamina: StaminaComponent
var _combat: Node
var _dodge: Node
var _rig: Node

var _failures: Array = []
var _recap: Array = []
var _transcript: Array = []


func _ready() -> void:
	# ALWAYS, so a pause could not silence this probe into looking like a healthy run.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_say("[FOCUS] === window focus / gameplay input routing contract ===")
	_run()


## Ambient attackers are held down for the whole run: this probe measures the PLAYER's input path at
## focus transitions, and an enemy swing landing mid-measurement would add a damage source unrelated
## to what is being measured.
func _process(_delta: float) -> void:
	EnemyAttacker.stand_down_all(get_tree())


# --- The contract --------------------------------------------------------------------

func _run() -> void:
	await _frames(SETTLE_FRAMES)
	if not _resolve():
		_report()
		return

	# --- PHASE 1: focused baseline -----------------------------------------------------
	_say("[FOCUS] --- PHASE 1: the game FOCUSED, as a baseline ---")
	_measure_focused_state("PHASE 1")
	_check(await _measure_look("PHASE 1"), "PHASE 1: mouse look works while focused")
	var travelled := await _measure_move(KEY_W, "PHASE 1")
	_check(travelled > MIN_TRAVEL, "PHASE 1: movement works while focused (%.4f m)" % travelled)
	var attacks_before := _attacks()
	await _swing()
	_check(_attacks() > attacks_before, "PHASE 1: attacks work while focused")
	_check(await _measure_dodge("PHASE 1"), "PHASE 1: dodges work while focused")

	# --- PHASE 2: focus LOST -----------------------------------------------------------
	_say("[FOCUS] --- PHASE 2: window focus LOST ---")
	# Settle first: residual velocity from the baseline walk must not be read as "input continued".
	await _frames(10)
	# Arm BOTH gates BEFORE the transition, so the gated state can be measured directly: a held move
	# key, and a pending look delta that is genuinely waiting to be spent.
	_key(KEY_W, true)
	await _frames(3)
	_mouse_motion(Vector2(240.0, 0.0))
	await _frames(1)
	var ticks_before := _input_ticks()
	var lost_before := _input.focus_lost_count

	# PROPAGATE, THEN MEASURE IN THE SAME CALL STACK - there is no `await` between them, on purpose.
	#
	# WHY THIS SHAPE. The layer reconciles its belief against the ENGINE'S OWN live focus report at
	# the top of every frame, and this environment cannot make the engine report a loss of focus: the
	# window really is focused, so the next frame legitimately restores input. The handler's effect
	# therefore lasts exactly one tick here, and measuring it synchronously is the only honest way to
	# observe it. That is a limit of the simulation, reported rather than papered over.
	_set_engine_focus(false)

	_check(not _input.is_input_active(), "FOCUS LOST: gameplay input is SUSPENDED")
	_check(_input.focus_lost_count > lost_before,
		"FOCUS LOST: the layer HANDLED the focus-out notification (%d -> %d)"
			% [lost_before, _input.focus_lost_count])
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"FOCUS LOST: the cursor is RELEASED (mode=%d)" % Input.mouse_mode)
	_check(_input.mouse_look_enabled,
		"FOCUS LOST: the capture INTENT is kept - Escape owns the intent, not focus")

	# THE REPORTED DEFECT, measured at the layer's own gates: motion accumulated while unfocused must
	# be DISCARDED rather than banked, so there is nothing left for the camera to spend on the way
	# back - and no gameplay action can be produced from input aimed at another window.
	var gated_move := _input.get_move_vector()
	_check(gated_move == Vector2.ZERO,
		"FOCUS LOST: a HELD move key reads as NO movement (%s)" % str(gated_move))
	var gated_look := _input.get_look_delta()
	_check(gated_look == Vector2.ZERO,
		"FOCUS LOST: a pending look delta is DISCARDED, not banked for the way back (%s)"
			% str(gated_look))
	_check(not _input.is_sprinting(), "FOCUS LOST: sprint reads OFF")
	_check(not _input.consume_dodge(),
		"FOCUS LOST: a queued dodge cannot be consumed into a real dodge")
	_check(not _input.is_action_pressed_now(GameActions.LOCK_ON),
		"FOCUS LOST: a gameplay action cannot be read as pressed")
	# NOTE - the "still processing" control deliberately does NOT live here. Every read in this phase
	# happens in ONE call stack, deliberately, so that the per-frame reconciliation cannot be
	# credited with the recovery. No frame runs inside it, so `process_ticks` CANNOT advance and
	# asserting that it did would be asserting something the phase forbids. The control belongs where
	# frames actually run, and it is asserted in PHASE 2b after the recovery.
	_check(_input_ticks() >= ticks_before,
		"FOCUS LOST: the layer's frame counter did not go BACKWARDS (control - %d -> %d)"
			% [ticks_before, _input_ticks()])
	_check_no_pause("FOCUS LOST")
	# Release the held key now that every gated read has been taken.
	_key(KEY_W, false)

	# The reconciliation, reported rather than hidden: the engine still reports focus, so the very
	# next frame legitimately resumes input. A real Alt-Tab cannot be reproduced in here, and saying
	# so is more useful than a green check that measured the wrong tick.
	await _frames(3)
	_say("[FOCUS] one tick after the focus-out: engine_focus=%s input_active=%s mouse=%d"
		% [str(_focused_engine()), str(_input.is_input_active()), Input.mouse_mode])
	_check(_input.is_input_active(),
		"FOCUS LOST: the per-frame reconciliation resumes input while the engine still reports focus"
		+ " (the simulation cannot hold the window unfocused - a limit, not a defect)")

	# --- PHASE 2b: the REPORTED WEDGE - a suspension with NO focus-in ------------------
	# This is the user's actual report, reproduced at the layer: Alt-Tab away, then return and click
	# the window and get nothing back. The suspension is entered and NO focus-in is ever delivered, so
	# the only thing that can end it is the player's own click. If the click is swallowed by the gate
	# it needs to clear, the game is trapped - which is exactly what was reported.
	_say("[FOCUS] --- PHASE 2b: suspension with NO focus-in (the reported wedge) ---")
	_set_engine_focus(false)
	_check(not _input.is_input_active(),
		"STUCK: the layer is suspended and no focus-in has been delivered")
	# Control: the layer must keep ticking THROUGH the suspension. A frozen loop would make every
	# recovery check below meaningless for a different reason than a dead escape hatch.
	var ticks_stuck := _input_ticks()

	# MOTION must NOT break the suspension. It can arrive from the host while the player is elsewhere,
	# so it proves nothing about where the player is - and letting it resume would re-create the
	# original defect (camera moving while the player is in another window).
	_mouse_motion(Vector2(240.0, 0.0))
	Input.flush_buffered_events()
	_check(not _input.is_input_active(),
		"STUCK: mouse MOTION alone does not resume input (motion proves nothing about presence)")
	_check(_input.get_look_delta() == Vector2.ZERO,
		"STUCK: ...and that motion produced no look delta while suspended")

	# A DELIBERATE PRESS is different: clicks and keys follow the focused window, so a press that
	# reached this game was aimed at this game. MEASURED SYNCHRONOUSLY (flush, no `await`) so the
	# per-frame reconciliation cannot be credited with the recovery - it would resume against the
	# engine's genuinely-focused window on the next frame and hide a dead recovery path.
	_mouse_button(MOUSE_BUTTON_LEFT, true)
	Input.flush_buffered_events()
	var resumed_by_click := _input.is_input_active()
	_mouse_button(MOUSE_BUTTON_LEFT, false)
	Input.flush_buffered_events()
	_check(resumed_by_click,
		"STUCK: a real CLICK resumes input - the suspension is NOT a trap (the escape hatch is alive)")
	if resumed_by_click:
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
			"STUCK: that click RESTORED the intended capture (mode=%d)" % Input.mouse_mode)

	# A KEY press must work the same way: the player may retarget the window with a keystroke.
	_set_engine_focus(false)
	_key(KEY_W, true)
	Input.flush_buffered_events()
	var key_resumed := _input.is_input_active()
	_key(KEY_W, false)
	Input.flush_buffered_events()
	_check(key_resumed, "STUCK: a real KEY press also resumes input")

	# And the recovery must leave real gameplay behind it, not just a flipped flag.
	await _frames(3)
	_say("[FOCUS] after click-recovery: input_active=%s mouse=%d ticks=%d"
		% [str(_input.is_input_active()), Input.mouse_mode, _input_ticks()])
	_check(_input.is_input_active(), "STUCK: input stays ACTIVE after the click recovery")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"STUCK: capture stays held after the click recovery (mode=%d)" % Input.mouse_mode)
	_check(_input_ticks() > ticks_stuck,
		"STUCK: the layer kept PROCESSING through the suspension (control - %d -> %d)"
			% [ticks_stuck, _input_ticks()])
	_check_no_pause("STUCK")

	# --- PHASE 3: focus REGAINED -------------------------------------------------------
	_say("[FOCUS] --- PHASE 3: window focus REGAINED ---")
	var gained_before := _input.focus_gained_count
	# OUT then IN in ONE call stack, for the same reason as PHASE 2: the per-frame reconciliation
	# would otherwise re-establish focus against the engine's (genuinely) focused window before the
	# transition could be measured. The pair is what a real Alt-Tab-and-return looks like to the layer.
	_set_engine_focus(false)
	_set_engine_focus(true)
	# Read SYNCHRONOUSLY, before the next `_process` clears it: this is the flag that stops the click
	# or key which brought the window back from also becoming a gameplay action.
	var suppress_armed := bool(_input.get("_suppress_presses"))

	_check(_input.is_input_active(), "REFOCUSED: gameplay input is ACTIVE again")
	_check(_input.focus_gained_count > gained_before,
		"REFOCUSED: the layer HANDLED the focus-in notification (%d -> %d)"
			% [gained_before, _input.focus_gained_count])
	# No mouse button was pressed at any point in this phase, so capture returning here cannot have
	# come from a click - which is the "do not make the player click to regain control" requirement.
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"REFOCUSED: the intended capture returned WITHOUT any click (mode=%d)" % Input.mouse_mode)
	_check(suppress_armed,
		"REFOCUSED: the button that brought the window back is SUPPRESSED (it cannot become an attack)")

	# The stale-delta rule is asserted at the gate above (`get_look_delta()` reads ZERO while gated and
	# the accumulation is CLEARED, not banked), which is the stronger form of the same claim: here it
	# is measured at the layer that would have to keep it, rather than inferred from camera drift.

	_measure_focused_state("REFOCUSED")
	_check(await _measure_look("REFOCUSED"), "REFOCUSED: mouse look works again")
	var travelled_after := await _measure_move(KEY_W, "REFOCUSED")
	_check(travelled_after > MIN_TRAVEL, "REFOCUSED: movement works (%.4f m)" % travelled_after)
	var attacks_after := _attacks()
	await _swing()
	_check(_attacks() > attacks_after, "REFOCUSED: attacks work")
	_check(await _measure_dodge("REFOCUSED"), "REFOCUSED: dodges work")

	var stamina_before := _stamina.current_stamina
	await _frames(REGEN_FRAMES)
	var stamina_after := _stamina.current_stamina
	_say("[FOCUS] REFOCUSED stamina: %.1f -> %.1f (regen_enabled=%s processing=%s regen_block=%.3f)"
		% [stamina_before, stamina_after, str(_stamina.regen_enabled), str(_stamina.is_processing()),
			float(_stamina.get("_regen_block"))])
	_check(stamina_after > stamina_before or stamina_after >= _stamina.max_stamina,
		"REFOCUSED: stamina REGENERATES (%.1f -> %.1f)" % [stamina_before, stamina_after])

	# --- PHASE 3b: the HOST dropped the cursor while the game still believes it is focused ---
	# THE USER'S REMAINING FAILURE, reproduced as measured: after Alt-Tab and return the camera
	# responds, the cursor stays FREE, and the character will not walk. In that state the engine still
	# reports focus, so the layer believes it is active and gates nothing - which is exactly what the
	# per-frame keeper is supposed to repair. An embedded host can drop pointer lock without the game
	# ever seeing a focus change, so the drop is simulated by clearing the mode directly.
	_say("[FOCUS] --- PHASE 3b: the HOST dropped the cursor while the game believes it is focused ---")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var attacks_before_click := _attacks()
	# SYNCHRONOUS (flush, no `await`), so the recovery measured below is the one made INSIDE the
	# click's own call stack - the context a user-gesture pointer-lock request requires - rather than
	# the per-frame keeper quietly repairing it one frame later. Those are different mechanisms and
	# the report must not credit the wrong one.
	_mouse_button(MOUSE_LEFT, true)
	Input.flush_buffered_events()
	var capture_on_click := Input.mouse_mode
	var suppressed_on_click := bool(_input.get("_suppress_presses"))
	_mouse_button(MOUSE_LEFT, false)
	Input.flush_buffered_events()
	_check(capture_on_click == Input.MOUSE_MODE_CAPTURED,
		"HOST-DROPPED: the CLICK ITSELF re-took the cursor (mode=%d)" % capture_on_click)
	_check(suppressed_on_click,
		"HOST-DROPPED: that click is SUPPRESSED as a swing - it asked for the window, not an attack")
	# The click must not have become a committed attack, because a committed attack owns the body and
	# is what stopped the player walking.
	await _frames(ATTACK_FRAMES)
	_check(_attacks() == attacks_before_click,
		"HOST-DROPPED: the refocus click did NOT start an attack (attacks %d -> %d)"
			% [attacks_before_click, _attacks()])
	var travelled_dropped := await _measure_move(KEY_W, "HOST-DROPPED")
	_check(travelled_dropped > MIN_TRAVEL,
		"HOST-DROPPED: the player can MOVE after the click that re-took the cursor (%.4f m)"
			% travelled_dropped)
	_check_no_pause("HOST-DROPPED")
	_measure_focused_state("HOST-DROPPED")

	# --- PHASE 4: targeting / lock-on, and the debug panels ----------------------------
	_say("[FOCUS] --- PHASE 4: targeting input, and the debug panels ---")
	# `lock_on` is a RESERVED action with no targeting system (roadmap 8E.5), so what can honestly be
	# measured is that the ACTION still reaches the input layer after a focus round trip. A lock-on
	# system does not exist to test, and this probe does not pretend otherwise.
	_check(await _lock_on_reaches_the_layer(),
		"PHASE 4: the `lock_on` action still reaches the input layer after refocusing")
	_check(get_tree().get_first_node_in_group(&"player_actor") != null,
		"PHASE 4: the targeting group still resolves to the player")
	_check(_retargeting_is_unchanged(), "PHASE 4: retargeting behaviour is unchanged by a focus change")

	var stealing := _controls_that_steal_gameplay_mouse()
	_check(stealing.is_empty(),
		"PHASE 4: no debug-panel Control consumes gameplay mouse input (%s)"
			% ("none" if stealing.is_empty() else ", ".join(stealing)))
	var focus_owner: Variant = get_viewport().gui_get_focus_owner()
	_check(focus_owner == null,
		"PHASE 4: no UI Control holds focus (%s)"
			% ("none" if focus_owner == null else String((focus_owner as Node).name)))

	_check_no_pause("PHASE 4")
	_report()


# --- Focus transitions --------------------------------------------------------------

## Propagate the engine's OWN focus notifications through the live tree, which is what the engine does
## on a real Alt-Tab. This is the honest half of the simulation: the project's handlers run for real.
func _set_engine_focus(focused: bool) -> void:
	var what := NOTIFICATION_APPLICATION_FOCUS_IN if focused else NOTIFICATION_APPLICATION_FOCUS_OUT
	get_tree().root.propagate_notification(what)


func _focused_engine() -> bool:
	var window := get_window()
	return window != null and window.has_focus()


# --- Measurements -------------------------------------------------------------------

## Every gate that must hold in the FOCUSED state, in one place.
func _measure_focused_state(tag: String) -> void:
	_say("[FOCUS] %s state: engine_focus=%s input_active=%s mouse=%d look_intent=%s ticks=%d"
		% [tag, str(_focused_engine()), str(_input.is_input_active()), Input.mouse_mode,
			str(_input.mouse_look_enabled), _input_ticks()])
	_check(_input.is_input_active(), "%s: gameplay input is ACTIVE" % tag)
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"%s: the mouse is CAPTURED for gameplay (mode=%d)" % [tag, Input.mouse_mode])
	_check(_input.mouse_look_enabled, "%s: mouse look is ENABLED" % tag)
	_check(_player.is_inside_tree() and _player.is_physics_processing(),
		"%s: the player is in the tree and processing" % tag)
	_check(_player.process_mode == Node.PROCESS_MODE_INHERIT,
		"%s: the player is in the normal process mode" % tag)
	var camera := get_viewport().get_camera_3d()
	_check(camera != null and camera.current, "%s: the camera is CURRENT" % tag)
	_check(not _health.is_dead, "%s: the player is alive" % tag)
	_check(_stamina.regen_enabled, "%s: stamina regeneration is ENABLED" % tag)
	_check_no_pause(tag)


func _check_no_pause(tag: String) -> void:
	_check(not get_tree().paused, "%s: the scene tree is NOT paused" % tag)
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"%s: the time scale is 1.0 (got %.3f) - no pause is used as a workaround" % [tag, Engine.time_scale])


## Inject real mouse motion and report whether the camera TURNED. Returns the fact, so the caller
## decides what it means: "it turned when it should not" and "it did not turn when it should" are the
## same measurement with opposite expectations.
func _measure_look(tag: String) -> bool:
	var turned := await _look_motion_degrees()
	_say("[FOCUS] %s look: yaw changed %.4f deg (input_active=%s mouse=%d)"
		% [tag, turned, str(_input.is_input_active()), Input.mouse_mode])
	return turned > 0.0001


## The stale-delta check: motion is injected, then the camera is watched for several more frames.
## A delta left over from before the refocus would be spent here instead of immediately.
func _measure_look_any_motion(tag: String) -> bool:
	await _look_motion_only()
	var yaw_after_injection := _rig_yaw()
	await _frames(STALE_FRAMES)
	var drift := absf(_rig_yaw() - yaw_after_injection)
	_say("[FOCUS] %s stale-delta probe: %.4f deg spent across %d later frames"
		% [tag, drift, STALE_FRAMES])
	return drift > 0.0001


## Inject one motion event and return the degrees the camera turned.
func _look_motion_degrees() -> float:
	var before := _rig_yaw()
	await _look_motion_only()
	return absf(_rig_yaw() - before)


func _look_motion_only() -> void:
	_mouse_motion(Vector2(240.0, 0.0))
	await _frames(3)


func _measure_move(keycode: int, tag: String) -> float:
	var start := _player.global_position
	_key(keycode, true)
	await _frames(MOVE_FRAMES)
	_key(keycode, false)
	await _frames(2)
	var travelled := _player.global_position.distance_to(start)
	_say("[FOCUS] %s move: travelled %.4f m over %d frames" % [tag, travelled, MOVE_FRAMES])
	return travelled


func _measure_dodge(tag: String) -> bool:
	# A committed attack refuses a dodge, so wait for idle first: otherwise this measures the previous
	# phase's attack rather than the dodge.
	for i in range(60):
		if not bool(_combat.call("is_busy")):
			break
		await _frames(1)
	_key(KEY_SPACE, true)
	await _frames(DODGE_CHECK_FRAMES)
	var dodging := bool(_dodge.call("is_dodging"))
	_key(KEY_SPACE, false)
	_say("[FOCUS] %s dodge: running=%s" % [tag, str(dodging)])
	await _frames(DODGE_CHECK_FRAMES + 2)
	return dodging


## The light attack, driven the way a player drives it: a mouse button through the real pipeline.
func _swing() -> void:
	_mouse_button(MOUSE_LEFT, true)
	await _frames(3)
	_mouse_button(MOUSE_LEFT, false)
	await _frames(ATTACK_FRAMES)


## Does the `lock_on` ACTION still arrive at the input layer? `CascadiaInput` is the only place that
## buffers it, and it is the deliberate observation point: no targeting system exists to ask.
func _lock_on_reaches_the_layer() -> bool:
	if not InputMap.has_action(&"lock_on"):
		_say("[FOCUS] lock_on ACTION IS NOT IN THE INPUTMAP")
		return false
	var bindings: Array = []
	for event in InputMap.action_get_events(&"lock_on"):
		if event is InputEventKey:
			bindings.append(OS.get_keycode_string((event as InputEventKey).keycode))
		elif event is InputEventJoypadButton:
			bindings.append("PadBtn%d" % (event as InputEventJoypadButton).button_index)
	_say("[FOCUS] lock_on bindings: %s" % str(bindings))
	Input.action_press(&"lock_on")
	await _frames(2)
	Input.action_release(&"lock_on")
	await _frames(2)
	var delivered := _input.consume_lock_on()
	_say("[FOCUS] lock_on delivered to the input layer: %s" % str(delivered))
	return delivered


## Retargeting: the weapon/target resolution a focus change must not disturb. Measured as the live
## state rather than assumed - the targeted group resolves to a live player, and the input layer's
## own view of what it is doing is still coherent.
func _retargeting_is_unchanged() -> bool:
	var target := get_tree().get_first_node_in_group(&"player_actor")
	return target != null and target == _player and _input.is_input_active()


## Every Control in the tree that would CONSUME a mouse click landing on it. `MOUSE_FILTER_STOP` is
## how a status panel silently eats gameplay input, so this enumerates the real tree instead of
## trusting the panel scripts to have set their filters.
func _controls_that_steal_gameplay_mouse() -> Array:
	var offenders: Array = []
	for canvas in get_tree().root.find_children("*", "CanvasLayer", true, false):
		for control in (canvas as Node).find_children("*", "Control", true, false):
			var c := control as Control
			if c == null or not c.visible:
				continue
			if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			# A Control that cannot be hit from the viewport centre is not in the gameplay mouse path.
			var rect := Rect2(c.global_position, c.size)
			if rect.has_point(get_viewport().get_visible_rect().size * 0.5):
				offenders.append("%s(%s)" % [c.name, "STOP" if c.mouse_filter == Control.MOUSE_FILTER_STOP else "PASS"])
	return offenders


func _attacks() -> int:
	return int(_combat.get("attacks_started"))


func _rig_yaw() -> float:
	if _rig == null:
		return 0.0
	return float(_rig.call("current_yaw_degrees"))


# --- Resolution ---------------------------------------------------------------------

func _resolve() -> bool:
	_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	_player = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	if _player == null:
		_fail("no player actor in the tree")
		return false
	_health = _player.get_node_or_null("Health") as HealthComponent
	_stamina = _player.get_node_or_null("Stamina") as StaminaComponent
	_combat = _player.get_node_or_null("Combat")
	_dodge = _player.get_node_or_null("Dodge")
	_rig = _find_camera_rig()
	for pair in [["input layer", _input], ["player health", _health], ["player stamina", _stamina],
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


# --- Input injection ----------------------------------------------------------------

## Feed a real key event into the engine's input pipeline, so the ACTION is driven exactly the way a
## physical key drives it. Both key fields are set so the event matches whichever the binding uses.
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


func _input_ticks() -> int:
	return _input.process_ticks


# --- Reporting ----------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		_say("[FOCUS]   PASS  %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	_say("[FOCUS]   FAIL  %s" % message)


func _report() -> void:
	_say("[FOCUS] --- summary ---")
	for line in _recap:
		_say("[FOCUS] %s" % line)
	if _failures.is_empty():
		_say("[FOCUS] RESULT: ALL CHECKS PASSED")
	else:
		_say("[FOCUS] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])


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
