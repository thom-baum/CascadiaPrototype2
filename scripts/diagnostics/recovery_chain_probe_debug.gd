class_name RecoveryChainProbeDebug
extends Node3D
## TEMPORARY DIAGNOSTIC (not production). Tests RECOVERY CHAINS, not isolated states.
##
## WHY IT EXISTS. The user's report is a CHAIN, not an action: Escape releases the mouse, clicking back
## does not always re-hook the game, and a LATER transition (Escape again, Alt-Tab again) suddenly
## makes it work. Every earlier pass measured ONE step at a time, and every one of those steps passed -
## which is exactly why the chain was never explained. An isolated check cannot show which step left
## the state half-finished, so this probe runs whole sequences and snapshots the state at EVERY step.
##
## WHAT IT CAN AND CANNOT DO - stated up front, not glossed at the end:
##
##   - It CAN propagate the engine's OWN focus notifications through the live tree, so the project's
##     real handlers run instead of a stand-in.
##   - It CAN drop the pointer lock behind the game's back (`Input.mouse_mode` written directly with
##     no focus change), which models a host releasing pointer lock while still reporting focus - the
##     state the earlier passes could only reason about.
##   - It CANNOT take real OS focus from the window: `Window.has_focus()` keeps reporting true, so a
##     simulated focus-out lasts exactly one tick before the per-frame reconciliation legitimately
##     restores input. That is a limit of the environment, reported rather than hidden.
##   - It CANNOT observe whether the HOST actually GRANTED pointer lock. `Input.mouse_mode` is the
##     engine's BELIEF, and the entire reported defect is that this belief can be wrong. Every
##     "mouse=2" below means the game believes it holds the cursor, NOT that the OS agrees.
##
## So a chain that passes here proves the GAME'S state machine is correct for that sequence of events.
## It does not prove the OS hook was granted. That half stays with the user's physical mouse.

const TAG := "[CHAIN]"
## Durable transcript, its own file so it cannot overwrite another probe's evidence.
const REPORT_PATH := "res://_recovery_chain_report.txt"

const SETTLE_FRAMES := 30
## Frames capture must STAY held after a recovery. A recovery that holds for one call stack and then
## flips back IS the reported "it hooked, then it did not", so it is sampled across frames.
const STABILITY_FRAMES := 20
## Frames a movement key is held for one measurement.
const MOVE_FRAMES := 20
## Distance in metres that counts as "the player moved".
const MIN_TRAVEL := 0.25
## Wall-clock seconds a movement key is held for one measurement, with an early exit the moment the
## body has clearly travelled. FRAMES ARE NOT A UNIT OF TIME IN THIS SCENE - it runs uncapped, and
## MEASURED 20 frames is only ~0.09 s, which measures the acceleration ramp from a dead stop (0.08-0.12
## m) instead of walking. Real time is what makes the check mean "can the player still walk".
const MOVE_TIMEOUT_SEC := 1.5
## Wall-clock seconds a dodge press is given to take effect before it is called a refusal. A dodge is
## accepted in `_physics_process` (60 Hz), so a three-RENDER-frame window can miss it entirely at a
## high frame rate.
const DODGE_WAIT_SEC := 0.25
## How long the SHARED mobility command is held for a TAP, in milliseconds. Must stay well inside
## `CascadiaInput.MOBILITY_TAP_MAX` (0.20 s), or the command resolves as a SPRINT hold instead.
const TAP_HOLD_MS := 50
## How long the game is given to come back to idle before a dodge is pressed. Generous on purpose: an
## attack that never finishes would otherwise read as "the dodge is broken" rather than as a
## measurement precondition that was never met.
const IDLE_WAIT_FRAMES := 180
## Frames after a dodge press within which the dodge must be RUNNING.
const DODGE_CHECK_FRAMES := 3
## Frames to let a light attack run its whole timeline before the next input.
const ATTACK_FRAMES := 40
## How long the stamina pool is WATCHED for growth after a spend. Frames are not a reliable unit of
## time in this scene - it runs uncapped - and the pool pauses for `regen_delay` after every spend, so
## the check polls until the value GROWS instead of assuming a frame count covers that delay.
const STAMINA_WAIT_FRAMES := 600
## How many frames the game is given to restore its OWN capture belief after a simulated host drop.
const SELF_HEAL_FRAMES := 10

## Godot key constants, named so the injected events read clearly.
const KEY_ESCAPE := 4194305
const KEY_W := 87
const KEY_SPACE := 32
const MOUSE_LEFT := 1

var _layer: CascadiaInput
var _player: Node3D
var _health: HealthComponent
var _stamina: StaminaComponent
var _combat: Node
var _dodge: Node
var _rig: Node

## The player's transform at the moment the probe resolved it, used to put the body back on a
## known-clear spot before a movement measurement. See `_reset_to_clear_ground()`.
var _spawn_position := Vector3.ZERO
var _spawn_yaw := 0.0

var _failures: Array = []
var _lines: Array = []


func _ready() -> void:
	# ALWAYS, so a pause could not silence this probe into looking like a healthy run.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_say("%s === recovery chains: which step leaves the state wrong? ===" % TAG)
	_run()


## Ambient attackers are held down for the whole run: this probe measures the PLAYER's recovery path,
## and an enemy swing landing mid-chain would add a damage source unrelated to what is measured.
func _process(_delta: float) -> void:
	EnemyAttacker.stand_down_all(get_tree())


# --- The chains -----------------------------------------------------------------------

func _run() -> void:
	await _frames(SETTLE_FRAMES)
	if not _resolve():
		_report()
		return
	_say("%s baseline (no chain run yet):" % TAG)
	_snapshot("baseline")

	await _chain_1_escape_click()
	await _chain_2_escape_click_twice()
	await _chain_3_tab_away_back()
	await _chain_4_tab_away_click_tab_return()
	await _chain_5_tab_away_escape_click()
	await _chain_6_escape_tab_return_click()
	await _chain_7_click_away_back_escape_click()
	await _chain_8_tab_return_escape_click_tab_return()

	await _investigate_second_transition()
	await _full_battery("FINAL BATTERY")
	_report()


## 1. Escape -> click back.
func _chain_1_escape_click() -> void:
	var chain := "CHAIN 1 (Escape -> click back)"
	_say("%s --- %s ---" % [TAG, chain])
	_escape()
	var after := _snapshot("1a after Escape")
	_check(not bool(after["intent"]), "%s: Escape turns the capture INTENT off" % chain)
	_check(int(after["mouse"]) == Input.MOUSE_MODE_VISIBLE,
		"%s: Escape RELEASES the cursor (mouse=%d)" % [chain, int(after["mouse"])])
	# The free cursor must be inert: motion with the intent off may not turn the camera.
	_check(not await _measure_look(chain + " (intent off)"),
		"%s: mouse motion does NOT turn the camera while the cursor is free" % chain)
	_check_no_pause(chain)
	await _click_and_check(chain)
	await _after_chain(chain)


## 2. Escape -> click back -> Escape -> click back.
func _chain_2_escape_click_twice() -> void:
	var chain := "CHAIN 2 (Escape -> click -> Escape -> click)"
	_say("%s --- %s ---" % [TAG, chain])
	for pass_index in range(2):
		_escape()
		var after := _snapshot("2-%d after Escape" % (pass_index + 1))
		_check(not bool(after["intent"]),
			"%s: pass %d - Escape turns the INTENT off" % [chain, pass_index + 1])
		_check(int(after["mouse"]) == Input.MOUSE_MODE_VISIBLE,
			"%s: pass %d - Escape releases the cursor" % [chain, pass_index + 1])
		await _click_and_check("%s pass %d" % [chain, pass_index + 1])
	await _after_chain(chain)


## 3. Alt-Tab away -> Alt-Tab back.
func _chain_3_tab_away_back() -> void:
	var chain := "CHAIN 3 (Alt-Tab away -> back)"
	_say("%s --- %s ---" % [TAG, chain])
	_tab_away()
	# SYNCHRONOUS: the simulated focus-out lasts one tick, so the handler's effect is read in the
	# same call stack. Waiting a frame would measure the reconciliation instead, which is a
	# legitimate recovery and would hide whether the handler did its own work.
	var out := _snapshot("3a focus OUT")
	_check(not bool(out["active"]), "%s: the focus-out SUSPENDS gameplay input" % chain)
	_check(int(out["mouse"]) == Input.MOUSE_MODE_VISIBLE,
		"%s: the cursor is RELEASED on focus-out (mouse=%d)" % [chain, int(out["mouse"])])
	_check(bool(out["intent"]),
		"%s: the capture INTENT is KEPT across focus loss - Escape owns the intent, not focus" % chain)
	await _tab_back_and_check(chain)
	await _after_chain(chain)


## 4. Alt-Tab away -> click the game -> Alt-Tab again -> return.
func _chain_4_tab_away_click_tab_return() -> void:
	var chain := "CHAIN 4 (Alt-Tab away -> click -> Alt-Tab again -> return)"
	_say("%s --- %s ---" % [TAG, chain])
	_tab_away()
	_snapshot("4a focus OUT")
	await _click_and_check(chain + " (while unfocused)")
	_tab_away()
	_snapshot("4b focus OUT again")
	await _tab_back_and_check(chain + " (second return)")
	await _after_chain(chain)


## 5. Alt-Tab away -> Escape -> click back.
func _chain_5_tab_away_escape_click() -> void:
	var chain := "CHAIN 5 (Alt-Tab away -> Escape -> click back)"
	_say("%s --- %s ---" % [TAG, chain])
	_tab_away()
	_escape()
	var after := _snapshot("5a after Escape")
	_check(not bool(after["intent"]), "%s: Escape while unfocused turns the INTENT off" % chain)
	_check(int(after["mouse"]) == Input.MOUSE_MODE_VISIBLE,
		"%s: the cursor stays released (mouse=%d)" % [chain, int(after["mouse"])])
	await _click_and_check(chain)
	await _after_chain(chain)


## 6. Escape -> Alt-Tab away -> return -> click.
func _chain_6_escape_tab_return_click() -> void:
	var chain := "CHAIN 6 (Escape -> Alt-Tab -> return -> click)"
	_say("%s --- %s ---" % [TAG, chain])
	_escape()
	_snapshot("6a after Escape")
	_tab_away()
	_snapshot("6b focus OUT")
	await _tab_back_and_check(chain + " (return with the intent still off)")
	await _click_and_check(chain)
	await _after_chain(chain)


## 7. Click away -> click back -> Escape -> click back.
func _chain_7_click_away_back_escape_click() -> void:
	var chain := "CHAIN 7 (click away -> click back -> Escape -> click back)"
	_say("%s --- %s ---" % [TAG, chain])
	_tab_away()
	await _click_and_check(chain + " (first click back)")
	_escape()
	_snapshot("7a after Escape")
	await _click_and_check(chain + " (second click back)")
	await _after_chain(chain)


## 8. Alt-Tab away -> return -> Escape -> click -> Alt-Tab away -> return.
func _chain_8_tab_return_escape_click_tab_return() -> void:
	var chain := "CHAIN 8 (Alt-Tab -> return -> Escape -> click -> Alt-Tab -> return)"
	_say("%s --- %s ---" % [TAG, chain])
	_tab_away()
	await _tab_back_and_check(chain + " (first return)")
	_escape()
	_snapshot("8a after Escape")
	await _click_and_check(chain)
	_tab_away()
	_snapshot("8b focus OUT")
	await _tab_back_and_check(chain + " (second return)")
	await _after_chain(chain)


# --- The reported pattern -------------------------------------------------------------

## THE SEQUENCE THE USER ACTUALLY HITS, taken apart:
##   Escape -> click back -> "it did not re-hook" -> Escape again or Alt-Tab again -> it works.
##
## The OS hook is not visible from in here, so this measures the three things that COULD differ and
## ARE visible: whether the game saw the click at all, whether that click asked for a real capture
## TRANSITION, and - the decisive one for this report - whether the game's internal state after the
## FIRST recovery and after the SECOND are actually different.
func _investigate_second_transition() -> void:
	_say("%s --- the reported pattern: first recovery does not hook, a later transition does ---" % TAG)
	_escape()
	_snapshot("P1 after Escape")
	var clicks_before: int = _layer.capture_requests_on_press
	var reasserts_before: int = _layer.capture_reasserted_by_click
	var first := _click_and_check_now("P2 first click back")
	_say("%s PATTERN: the game SAW the first click: %s (+%d request(s))"
		% [TAG, str(_layer.capture_requests_on_press > clicks_before),
			_layer.capture_requests_on_press - clicks_before])
	_say("%s PATTERN: that click asked for a real capture TRANSITION: %s (+%d)"
		% [TAG, str(_layer.capture_reasserted_by_click > reasserts_before),
			_layer.capture_reasserted_by_click - reasserts_before])
	var after_first := _snapshot("P2 after the first recovery")

	# Now the second transition the user says fixes it.
	_escape()
	_snapshot("P3 after a second Escape")
	_click_and_check_now("P4 second click back")
	var after_second := _snapshot("P4 after the second recovery")

	var changed := _state_diff(after_first, after_second)
	if changed.is_empty():
		_say("%s PATTERN: the internal state after the FIRST recovery and after the SECOND are IDENTICAL."
			% TAG)
		_say("%s PATTERN: -> nothing in the game's state differs, so the game cannot be what made the"
			% TAG)
		_say("%s PATTERN:    second transition work. That points OUTSIDE the game (the host's grant of"
			% TAG)
		_say("%s PATTERN:    pointer lock, or a first click the host consumed to activate the window)." % TAG)
	else:
		_say("%s PATTERN: the states DIFFER - the second transition changed: %s" % [TAG, ", ".join(changed)])
		var blocking := _first_blocking_difference(after_first)
		if not blocking.is_empty():
			_fail("PATTERN: after the first recovery the game was left in a blocking state: %s" % blocking)

	_check(int(first["mouse"]) == Input.MOUSE_MODE_CAPTURED,
		"PATTERN: the game's capture belief returned on the first click")
	_host_drop_capture()
	_snapshot("P5 host dropped the lock behind the game's back")
	var healed := -1
	for i in range(SELF_HEAL_FRAMES):
		await _frames(1)
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			healed = i + 1
			break
	# CONTROL, and its limit is stated: this measures the engine's BELIEF being put back, which the
	# per-frame keeper can do on its own. It cannot show whether the host GRANTED the lock.
	if healed >= 0:
		_say("%s PATTERN (control): the game restored its OWN capture BELIEF %d frame(s) after the drop"
			% [TAG, healed])
	else:
		_fail("PATTERN (control): the game did NOT restore its own capture belief within %d frames"
			% SELF_HEAL_FRAMES)
	_say("%s PATTERN (limit): whether the OS actually granted the lock is NOT observable in here." % TAG)


# --- Shared chain steps ---------------------------------------------------------------

## A recovery click, with every promise a recovery click makes checked at once.
func _click_and_check(chain: String) -> void:
	_click_and_check_now(chain)


## Same, but returns the synchronous reading so a caller can compare states across the click.
func _click_and_check_now(chain: String) -> Dictionary:
	var click := _click_back()
	_check(bool(click["saw_click"]), "%s: the game SAW the click (it is not lost to the host here)" % chain)
	_check(int(click["mouse"]) == Input.MOUSE_MODE_CAPTURED,
		"%s: the click RE-TOOK the cursor (mouse=%d)" % [chain, int(click["mouse"])])
	_check(bool(click["intent"]), "%s: the click restored the capture INTENT" % chain)
	_check(bool(click["suppressed"]),
		"%s: that click is SUPPRESSED - it asked for the window, not a swing" % chain)
	return click


## The focus-in half, and the measurement that matters most for the reported flakiness: capture must
## not merely return, it must STAY.
func _tab_back_and_check(chain: String) -> void:
	var reasserts_before: int = _layer.focus_reasserts
	var gained_before: int = _layer.focus_gained_count
	_set_engine_focus(true)
	var back := _snapshot("   focus IN")
	_check(bool(back["active"]), "%s: the focus-in RESUMES gameplay input" % chain)
	# INTENT-AWARE, and this is not a weakened assertion - it is the correct one. A focus-in restores
	# the capture the player still WANTS. When the player released the cursor with Escape, the intent
	# is OFF and the correct behaviour is to hand back a FREE cursor: capture returning there would be
	# the defect (the game stealing the pointer after the player asked for it). So the expectation
	# follows the intent, and both directions are asserted.
	var want_capture: bool = _layer.mouse_look_enabled
	if want_capture:
		_check(int(back["mouse"]) == Input.MOUSE_MODE_CAPTURED,
			"%s: the focus-in re-took the cursor with NO click (mouse=%d)" % [chain, int(back["mouse"])])
	else:
		_check(int(back["mouse"]) != Input.MOUSE_MODE_CAPTURED,
			"%s: the focus-in correctly did NOT capture - the player had released the cursor with Escape (mouse=%d)"
				% [chain, int(back["mouse"])])
	_check(bool(back["suppress"]),
		"%s: the press that brought the window back is SUPPRESSED" % chain)
	await _frames(10)
	_say("%s %s: the focus-in ran %d re-assert frame(s) and %d focus-gain handler(s)"
		% [TAG, chain, _layer.focus_reasserts - reasserts_before,
			_layer.focus_gained_count - gained_before])
	var settled := int(_snapshot("   +10 frames")["mouse"])
	if want_capture:
		_check(settled == Input.MOUSE_MODE_CAPTURED,
			"%s: capture is STILL held 10 frames after the return" % chain)
	else:
		_check(settled != Input.MOUSE_MODE_CAPTURED,
			"%s: capture is still correctly NOT held 10 frames after the return (mouse=%d)"
				% [chain, settled])


## Everything the chain must leave behind, measured rather than assumed.
func _after_chain(chain: String) -> void:
	var state := _snapshot("   end of chain")
	_check(int(state["mouse"]) == Input.MOUSE_MODE_CAPTURED,
		"%s: capture is HELD at the end of the chain (mouse=%d)" % [chain, int(state["mouse"])])
	_check(bool(state["intent"]), "%s: the capture INTENT is ON at the end of the chain" % chain)
	_check(bool(state["active"]), "%s: gameplay input is ACTIVE at the end of the chain" % chain)
	var stable := true
	for i in range(STABILITY_FRAMES):
		await _frames(1)
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			stable = false
			break
	_check(stable, "%s: capture STAYS held across %d frames" % [chain, STABILITY_FRAMES])
	_check(await _measure_look(chain), "%s: mouse look turns the camera after the chain" % chain)
	var travelled := await _measure_move(KEY_W, chain)
	_check(travelled > MIN_TRAVEL, "%s: movement works after the chain (%.4f m)" % [chain, travelled])
	_check_no_pause(chain)


## Attack, dodge and stamina, in one place, run after the whole chain set.
func _full_battery(tag: String) -> void:
	_say("%s --- %s: attack, dodge, stamina ---" % [TAG, tag])
	var attacks_before := _attacks()
	await _swing()
	_check(_attacks() > attacks_before, "%s: attacks work" % tag)
	_check(await _measure_dodge(tag + " backstep"), "%s: a backstep works" % tag)
	_check(await _measure_dodge(tag + " directional", true), "%s: a directional dodge works" % tag)
	var stamina_before := _stamina.current_stamina
	# Poll for GROWTH rather than waiting a fixed frame count: the pool pauses for `regen_delay` after
	# every spend and this scene runs uncapped, so a frame count is not a reliable amount of time. The
	# extra readings are the point - a flat pool has to explain ITSELF rather than look like a bug.
	var stamina_after := stamina_before
	var grew_after := -1
	for i in range(STAMINA_WAIT_FRAMES):
		await _frames(1)
		stamina_after = _stamina.current_stamina
		if stamina_after > stamina_before:
			grew_after = i + 1
			break
	_say("%s %s stamina: %.1f -> %.1f (grew_after=%d f, regen_enabled=%s block=%.3f max=%.1f processing=%s)"
		% [TAG, tag, stamina_before, stamina_after, grew_after, str(_stamina.regen_enabled),
			float(_stamina.get("_regen_block")), _stamina.max_stamina, str(_stamina.is_processing())])
	_check(stamina_after > stamina_before or stamina_after >= _stamina.max_stamina,
		"%s: stamina REGENERATES (%.1f -> %.1f, regen_enabled=%s block=%.3f)"
		% [tag, stamina_before, stamina_after, str(_stamina.regen_enabled),
			float(_stamina.get("_regen_block"))])


# --- State comparison -----------------------------------------------------------------

## Every state key that CHANGED between two snapshots, ignoring the counters - a counter going up is
## proof that something ran, not a state difference.
func _state_diff(before: Dictionary, after: Dictionary) -> Array:
	var counters := ["clicks", "by_click", "reasserts", "lost", "gained"]
	var changed: Array = []
	for key in before.keys():
		if key == "label" or counters.has(key):
			continue
		if before[key] != after[key]:
			changed.append("%s %s -> %s" % [key, str(before[key]), str(after[key])])
	return changed


## The keys that would leave the player unable to play: the shape of a half-finished recovery.
func _first_blocking_difference(state: Dictionary) -> String:
	if not bool(state["intent"]):
		return "the capture INTENT was still OFF"
	if not bool(state["active"]):
		return "gameplay input was still SUSPENDED"
	if int(state["mouse"]) != Input.MOUSE_MODE_CAPTURED:
		return "the cursor was still NOT captured (mouse=%d)" % int(state["mouse"])
	return ""


# --- Injection ------------------------------------------------------------------------

## The engine's own focus notification, propagated through the live tree, which is what the engine
## does on a real Alt-Tab. This is the honest half of the simulation: the project's handler runs.
func _set_engine_focus(focused: bool) -> void:
	var what := NOTIFICATION_APPLICATION_FOCUS_IN if focused else NOTIFICATION_APPLICATION_FOCUS_OUT
	get_tree().root.propagate_notification(what)


## "Alt-Tab away": the engine's focus-OUT notification. Named for what the player does, so a chain
## reads as the sequence the player performs rather than as raw notification plumbing.
func _tab_away() -> void:
	_set_engine_focus(false)


## A real Escape key press, through the engine's input pipeline, so the project's own `ui_cancel`
## handler is what runs - not a call to `set_mouse_look()`, which would test nothing.
func _escape() -> void:
	_key(KEY_ESCAPE, true)
	Input.flush_buffered_events()
	_key(KEY_ESCAPE, false)
	Input.flush_buffered_events()


func _click_back() -> Dictionary:
	var clicks_before: int = _layer.capture_requests_on_press
	_mouse_button(MOUSE_LEFT, true)
	Input.flush_buffered_events()
	var reading := {
		"mouse": Input.mouse_mode,
		"intent": _layer.mouse_look_enabled,
		"saw_click": _layer.capture_requests_on_press > clicks_before,
		"suppressed": bool(_layer.get("_suppress_presses")),
	}
	_mouse_button(MOUSE_LEFT, false)
	Input.flush_buffered_events()
	return reading


## Model the host releasing the pointer lock with NO focus change - the state the earlier passes had
## to reason about, and the one the dashboard cannot distinguish from a real capture.
func _host_drop_capture() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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


# --- Measurements ---------------------------------------------------------------------

## One line per step, carrying every state the report has to account for.
func _snapshot(label: String) -> Dictionary:
	var pending := _layer.peek_look_delta()
	var state := {
		"label": label,
		"focus": _focused_engine(),
		"mouse": Input.mouse_mode,
		"intent": _layer.mouse_look_enabled,
		"active": _layer.is_input_active(),
		"suppress": bool(_layer.get("_suppress_presses")),
		"pending": pending,
		"clicks": _layer.capture_requests_on_press,
		"by_click": _layer.capture_reasserted_by_click,
		"reasserts": _layer.focus_reasserts,
		"lost": _layer.focus_lost_count,
		"gained": _layer.focus_gained_count,
	}
	_say("%s %-34s focus=%-5s mouse=%d intent=%-5s active=%-5s suppress=%-5s pending=(%.1f,%.1f) clicks=%d byClick=%d reasserts=%d lost=%d gained=%d"
		% [TAG, label, str(state["focus"]), int(state["mouse"]), str(state["intent"]),
			str(state["active"]), str(state["suppress"]), pending.x, pending.y,
			int(state["clicks"]), int(state["by_click"]), int(state["reasserts"]),
			int(state["lost"]), int(state["gained"])])
	return state


func _focused_engine() -> bool:
	var window := get_window()
	return window != null and window.has_focus()


## Inject motion and report whether the camera TURNED. Returns the fact so the caller decides what it
## means: "it turned when it should not" and "it did not turn when it should" are one measurement.
func _measure_look(tag: String) -> bool:
	var before := _rig_yaw()
	_mouse_motion(Vector2(240.0, 0.0))
	await _frames(3)
	var turned: float = absf(_rig_yaw() - before)
	_say("%s %s look: yaw changed %.4f deg (active=%s mouse=%d)"
		% [TAG, tag, turned, str(_layer.is_input_active()), Input.mouse_mode])
	return turned > 0.0001


func _measure_move(keycode: int, tag: String) -> float:
	_reset_to_clear_ground()
	var start := _player.global_position
	_key(keycode, true)
	# WALL-CLOCK, with an early exit. The question is "can the player still walk", so the key is held
	# until the body has clearly travelled or the timeout expires - never for a fixed frame count,
	# which is an arbitrary slice of time in an uncapped scene.
	var began := Time.get_ticks_msec()
	var deadline := began + int(MOVE_TIMEOUT_SEC * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await _frames(1)
		if _player.global_position.distance_to(start) >= MIN_TRAVEL:
			break
	var elapsed := (Time.get_ticks_msec() - began) / 1000.0
	_key(keycode, false)
	await _frames(2)
	var travelled := _player.global_position.distance_to(start)
	# The extra readings are the point: a shortfall has to explain ITSELF. A low number with the body
	# still on the floor and accelerating is a real input failure; a low number with the body wedged or
	# off the floor is the measurement's fault, and the two must not read the same.
	_say("%s %s move: travelled %.4f m in %.3f s (start=%s floor=%s vel=%s)"
		% [TAG, tag, travelled, elapsed, str(start.floor()), str(_on_floor()),
			str(_player.get("velocity"))])
	return travelled


## Put the body back on the spawn spot with a level camera before measuring movement.
##
## WHY THIS IS NOT CHEATING. Movement is CAMERA-RELATIVE and the chains deliberately turn the camera
## (~240 deg each), so a walk measured from wherever the previous chain left the player is really a
## measurement of accumulated geometry collisions and a rotated heading - MEASURED at 0.08-0.11 m
## against 1.09 m from a clean start, which is the same input path in both cases. Returning the body
## to a known-clear spot makes the number mean the thing it is supposed to mean: "can the player still
## walk after this chain". Every state the chains actually change (focus, capture, intent, look) is
## left exactly as the chain left it.
func _reset_to_clear_ground() -> void:
	if _player == null:
		return
	_player.set("velocity", Vector3.ZERO)
	_player.global_position = _spawn_position
	if _rig != null and _rig.has_method("restore_orientation"):
		_rig.call("restore_orientation", _spawn_yaw, 0.0)


func _on_floor() -> bool:
	if _player == null or not _player.has_method("is_on_floor"):
		return false
	return bool(_player.call("is_on_floor"))


func _measure_dodge(tag: String, hold_move: bool = false) -> bool:
	# A committed attack refuses a dodge, so wait for idle first, or this measures the attack instead.
	# The wait REPORTS itself: an attack that never finishes is a measurement precondition that was
	# never met, and it must not read the same as a dodge the game actually refused.
	var idle_frames := -1
	for i in range(IDLE_WAIT_FRAMES):
		if not bool(_combat.call("is_busy")):
			idle_frames = i
			break
		await _frames(1)
	if idle_frames < 0:
		_say("%s %s dodge: SKIPPED - the game never returned to idle within %d frames"
			% [TAG, tag, IDLE_WAIT_FRAMES])
		_fail("%s: the game did not return to idle within %d frames, so the dodge precondition was never met"
			% [tag, IDLE_WAIT_FRAMES])
		return false
	var before := _dodge_refusals()
	var stamina_before := _stamina.current_stamina
	# The TWO DOCUMENTED PATHS, and they are deliberately different commands (Cascadia input rules):
	#   DIRECTIONAL dodge - the dedicated dodge key (Space) WITH a movement key held.
	#   BACKSTEP         - a TAP of the SHARED mobility command (Left Shift / controller Circle) with
	#                      NO movement input. Space with nothing held is NOT the backstep path, so
	#                      testing it that way measured a scenario the specification never defines.
	var dodge_key: int = KEY_SPACE if hold_move else KEY_SHIFT
	if hold_move:
		_key(KEY_W, true)
		await _frames(2)
	_key(dodge_key, true)
	# A tap is PRESS+RELEASE inside `MOBILITY_TAP_MAX` (0.20 s), and the SHARED command only resolves
	# into a DODGE when it is released that quickly. MEASURED: holding it through the whole poll window
	# produced NO dodge and NO refusal - because the command had resolved as a SPRINT hold, so the
	# dodge path was never entered. The shared command is therefore released BEFORE the dodge is looked
	# for; the dedicated dodge key (Space) needs no such handling and stays held across the poll.
	if not hold_move:
		await _hold_briefly(TAP_HOLD_MS)
	_key(dodge_key, false)

	# WALL-CLOCK poll. The dodge is accepted in `_physics_process` (60 Hz), so a fixed count of RENDER
	# frames can fall entirely between two physics ticks at a high frame rate and read as a refusal.
	var began := Time.get_ticks_msec()
	var deadline := began + int(DODGE_WAIT_SEC * 1000.0)
	var dodging := false
	while Time.get_ticks_msec() < deadline:
		await _frames(1)
		if bool(_dodge.call("is_dodging")):
			dodging = true
			break
	if hold_move:
		_key(KEY_W, false)
	var after := _dodge_refusals()
	_say("%s %s dodge(%s via %s): running=%s stamina=%.1f cost=%.1f busy=%s floor=%s refusals %s -> %s"
		% [TAG, tag, "directional" if hold_move else "backstep (shared-command tap)",
			"Space" if hold_move else "Shift", str(dodging), stamina_before,
			float(_dodge.get("stamina_cost")), str(bool(_combat.call("is_busy"))), str(_on_floor()),
			str(before), str(after)])
	await _frames(DODGE_CHECK_FRAMES + 2)
	return dodging


## Hold a key for a WALL-CLOCK duration rather than a frame count, so a tap stays a tap no matter how
## fast this scene is rendering. MEASURED reason it exists: this scene renders uncapped, so a 3-frame
## poll was ~14 ms here - and when the SAME command was held for a fixed 250 ms poll window instead,
## it exceeded MOBILITY_TAP_MAX (0.20 s) and resolved as a HOLD (sprint), which is why the backstep
## read as "no dodge and no refusal": the tap never happened at all.
func _hold_briefly(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while Time.get_ticks_msec() < until:
		await _frames(1)


## Every cause a dodge can be refused for, so a refusal NAMES itself instead of reading as a mystery.
## Read from the component's own counters, which are kept separate exactly so the causes never
## collapse into one another.
func _dodge_refusals() -> Dictionary:
	return {
		"stamina": int(_dodge.get("dodges_refused_by_stamina")),
		"attacking": int(_dodge.get("dodges_refused_while_attacking")),
		"direction": int(_dodge.get("dodges_refused_invalid_direction")),
		"dodging": int(_dodge.get("dodges_refused_while_dodging")),
		"parrying": int(_dodge.get("dodges_refused_while_parrying")),
	}


func _swing() -> void:
	_mouse_button(MOUSE_LEFT, true)
	await _frames(2)
	_mouse_button(MOUSE_LEFT, false)
	await _frames(ATTACK_FRAMES)


func _attacks() -> int:
	return int(_combat.get("attacks_started"))


func _rig_yaw() -> float:
	if _rig == null:
		return 0.0
	return float(_rig.call("current_yaw_degrees"))


func _check_no_pause(tag: String) -> void:
	_check(not get_tree().paused, "%s: the scene tree is NOT paused" % tag)
	_check(is_equal_approx(Engine.time_scale, 1.0),
		"%s: the time scale is 1.0 (got %.3f)" % [tag, Engine.time_scale])


# --- Resolution -----------------------------------------------------------------------

func _resolve() -> bool:
	_layer = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	_player = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	if _player == null:
		_fail("no player actor in the tree - the arena is not composed into this scene")
		return false
	_health = _player.get_node_or_null("Health") as HealthComponent
	_stamina = _player.get_node_or_null("Stamina") as StaminaComponent
	_combat = _player.get_node_or_null("Combat")
	_dodge = _player.get_node_or_null("Dodge")
	_rig = _find_camera_rig()
	for pair in [["input layer", _layer], ["player health", _health], ["player stamina", _stamina],
			["player combat", _combat], ["player dodge", _dodge], ["camera rig", _rig]]:
		if pair[1] == null:
			_fail("could not resolve the %s" % pair[0])
			return false
	_spawn_position = _player.global_position
	_spawn_yaw = float(_rig.call("current_yaw_degrees"))
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

func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _say(line: String) -> void:
	print(line)
	_lines.append(line)


func _check(condition: bool, message: String) -> void:
	if condition:
		_say("%s   PASS  %s" % [TAG, message])
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	_say("%s   FAIL  %s" % [TAG, message])


func _report() -> void:
	_say("%s --- summary ---" % TAG)
	if _failures.is_empty():
		_say("%s RESULT: ALL CHECKS PASSED" % TAG)
	else:
		_say("%s RESULT: %d FAILED -> %s" % [TAG, _failures.size(), str(_failures)])
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines) + "\n")
		file.close()
