class_name FKeyHostOwnershipProbeDebug
extends Node3D
## Temporary diagnostic (not production): WHO OWNS F9 IN THIS HOST?
##
## WHY THIS EXISTS. The reported defect is a GAMEPLAY one:
##
##     F5 saves -> play on -> F9 -> the game does not come back playable
##
## The previous probe (`save_load_runtime_state_probe_debug`) reproduced the contract with injected
## key events and died at its FIRST injected F9: the debug session stopped, no script error, no
## trace, and the last line in its transcript was the `--- PHASE 4: F9 (load 1) ---` banner. Its
## injected F5 had worked (saves 0 -> 1). So something about F9 specifically ended the process, and
## there are exactly two candidate owners for that:
##
##   (a) THE HOST owns F9 (a debugger / suspend / stop key). The press never reaches the game and the
##       host acts on it. Nothing in the save/load path can fix that - only a rebind can.
##   (b) THE GAME OWNS F9, and `GameStateSave.load_game()` crashed, hung or was stopped while
##       restoring, i.e. the defect really is in the load path.
##
## Those look identical from the outside. This probe separates them by REMOVING the in-game consumer:
## `main.tscn`'s `SaveLoadControls` node (the only thing in the project that reads `quick_load`) is
## disabled BEFORE any key is injected. With no consumer alive, an F9 press has no in-game effect at
## all, so:
##
##   - the process still ends on F9 -> the cause is OUTSIDE the game (a). The load path is innocent.
##   - the process survives F9     -> the cause is INSIDE the load path (b). Rebinding would hide it.
##
## It also reports, per key, whether the GAME'S OWN `_input` saw the event. Delivery and survival are
## separate facts and this probe never conflates them: a key can be delivered and still kill the
## process, or be swallowed before delivery.
##
## F9 IS INJECTED LAST, deliberately. Every earlier key is measured before the suspect is touched, so
## whichever key ends the process is unambiguous from the transcript alone.
##
## It makes NO claim about gameplay after a load. It measures ownership and delivery only.

## Durable transcript. A separate file from the contract probe's, so neither overwrites the other's
## evidence - the last probe's transcript was destroyed by a re-run before it was read.
const REPORT_PATH := "res://_fkey_probe_report.txt"

## Frames to let a key land and its consequences settle before the next one.
const KEY_GAP_FRAMES := 40
## Frames to let the scene settle before the first injection.
const SETTLE_FRAMES := 30

## The keys, in the order they are injected. F9 is LAST on purpose (see the header comment).
## F2 is a control: Cascadia binds NOTHING to it, so a reaction to F2 would mean "any function key",
## not "F9 specifically".
## ORDER IS EVIDENCE. The owner of F9 is the question, so F9 is injected before the OTHER load key
## (F8) rather than after it: the first run of this probe ended the process on F8 and never reached
## the suspect at all, which left "F8 is host-owned" proven and "F9" unanswered.
## F9 APPEARS TWICE. The first press stops the clock; the second press is the experiment that says
## whether the host's stop is a TOGGLE (press F9 again to resume), which is the difference between
## "F9 corrupts the game" and "F9 is the host's pause key".
## The session-killers are LAST: F8 ended the debug session in two earlier runs, and F10 is untested,
## so every safe key is measured before either can end the run.
## ALREADY MEASURED, kept as the reference pair at the end: F9 press 1 stops the clock and frees the
## cursor while `paused` stays false (`delivered=1`, then `scale=0.000 mouse=0`), F9 press 2 is NOT
## delivered and resumes it (`delivered=0`, `scale=1.000 mouse=2`). F9 is the HOST'S PAUSE TOGGLE.
## F8 ends the debug session outright. F2 / F5 / F6 / F10 are safe and delivered.
##
## This run measures the REMAINING candidate keys, because the rebind must be chosen from measured
## keys rather than guessed. `K` is the control: a letter cannot be a host debugger shortcut, so if K
## survives, "delivered and safe" is achievable outside the function row.
## F9 is LAST so every candidate is measured before the known pause key stops the clock.
const KEYS: Array = [
	[KEY_K, "K (letter control - cannot be a host function key)"],
	[KEY_F1, "F1 (toggle_debug_overlay)"],
	[KEY_F3, "F3 (candidate)"],
	[KEY_F4, "F4 (candidate)"],
	[KEY_F7, "F7 (candidate)"],
	[KEY_F11, "F11 (candidate)"],
	[KEY_F12, "F12 (candidate)"],
	[KEY_F9, "F9 (known host pause key - reference)"],
]

## Every raw key press the GAME ITSELF receives, counted by keycode. This is the delivery record.
var _received := {}
var _transcript: PackedStringArray = []
var _main: Node = null
var _controls: Node = null
var _controls_disabled := false


func _ready() -> void:
	# ALWAYS, so a host-side pause cannot silence the probe into looking like a healthy run.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# RESOLVED FROM THE PARENT, not from this node. The Probe is a SIBLING of the instanced Main, so
	# `get_node_or_null("Main")` resolves to `Probe/Main` and silently finds nothing. The FIRST run of
	# this probe hit exactly that bug: it reported "main.tscn NOT FOUND" and left the consumer ENABLED,
	# so nothing was isolated. The lookup below is correct, and the children actually found are printed
	# so a future failure to find the consumer is visible in the transcript rather than assumed.
	_main = get_parent().get_node_or_null("Main")
	_disable_consumer()
	_say("[FKEY] === who owns F9 in this host? ===")
	_say("[FKEY] scene root children: %s"
		% str(_child_names(get_parent() if get_parent() != null else self)))
	_say("[FKEY] in-game consumer (main.tscn/SaveLoadControls): %s" % _consumer_state())
	_log_bindings()
	_run()


func _run() -> void:
	await _frames(SETTLE_FRAMES)
	_say("[FKEY] settled: scale=%.3f paused=%s mouse=%d window_focused=%s"
		% [Engine.time_scale, str(get_tree().paused), Input.mouse_mode, str(_focused())])

	for entry in KEYS:
		var keycode: int = entry[0]
		var label: String = entry[1]
		_received.erase(keycode)
		_say("[FKEY] INJECTING %s (keycode %d)" % [label, keycode])
		_key(keycode, true)
		await _frames(2)
		_key(keycode, false)
		await _frames(KEY_GAP_FRAMES)
		# `input_ticks` IS THE DECISIVE NUMBER. `CascadiaInput._process` re-asserts a running clock and
		# a captured mouse at the top of EVERY frame, so:
		#   input_ticks ADVANCES while scale reads 0.000 -> the game's loop is alive and the layer is
		#       running, but something OUTSIDE it re-writes the stop every frame. No in-game code can win.
		#   input_ticks FROZEN while scale reads 0.000   -> the host has stopped the loop itself.
		# Reading `scale` alone cannot tell those apart, which is exactly why this counter is printed.
		_say("[FKEY] SURVIVED %s | delivered_to_game=%s | scale=%.3f paused=%s mouse=%d | input_ticks=%d look_enabled=%s | saves=%d loads=%d"
			% [label, str(_received.get(keycode, 0)), Engine.time_scale, str(get_tree().paused),
				Input.mouse_mode, _input_ticks(),
				str(_look_enabled()), _counter("saves"), _counter("loads")])

	_say("[FKEY] every key was injected and the process is still running")

	# --- THE DIRECT CONTROL ---------------------------------------------------------------
	# The load path with NO KEY INVOLVED. This is the second half of the ownership question:
	#   keys survive AND this survives -> the keys themselves are the problem, NOT the load path
	#   keys survive BUT this ends the process -> the game's own load path is the defect
	# Nothing here is touched by the host, so a failure here cannot be blamed on a shortcut.
	var save := GameStateSave.find_save(get_tree())
	if save == null:
		_say("[FKEY] DIRECT: no GameStateSave in the tree - cannot run the control")
	else:
		var code := save.save_game()
		_say("[FKEY] DIRECT save_game() -> %s (saves=%d)"
			% [GameStateSave.result_name(code), save.saves])
		await _frames(KEY_GAP_FRAMES)
		code = save.load_game()
		_say("[FKEY] DIRECT load_game() -> %s (loads=%d) | scale=%.3f paused=%s mouse=%d"
			% [GameStateSave.result_name(code), save.loads, Engine.time_scale,
				str(get_tree().paused), Input.mouse_mode])
		await _frames(KEY_GAP_FRAMES)
		_say("[FKEY] SURVIVED a direct save+load with no key involved")

	_say("[FKEY] RESULT: ownership separation complete - read the last line reached above")
	_flush()


## The scene root's own children, so a failed node lookup shows up in the transcript instead of
## being silently assumed. `_main` is resolved from these names.
func _child_names(parent: Node) -> Array:
	var names: Array = []
	if parent == null:
		return names
	for child in parent.get_children():
		names.append(String(child.name))
	return names


## Turn OFF the only node in the project that reads `quick_load` / `quick_save` / `new_run`.
## PROCESS_MODE_DISABLED stops its `_process`, which is where those actions are polled, so the
## InputMap actions become inert without deleting or editing any project file.
func _disable_consumer() -> void:
	if _main == null:
		return
	_controls = _main.get_node_or_null("SaveLoadControls")
	if _controls == null:
		return
	_controls.process_mode = Node.PROCESS_MODE_DISABLED
	_controls_disabled = true


func _consumer_state() -> String:
	if _main == null:
		return "main.tscn NOT FOUND - the probe cannot isolate the load path"
	if _controls == null:
		return "NOT PRESENT (nothing consumes quick_load)"
	if not _controls_disabled:
		return "PRESENT and NOT disabled - isolation FAILED"
	return "PRESENT but DISABLED (process_mode=DISABLED) - quick_load has no consumer"


## The real InputMap bindings, read from the live project rather than assumed, so "F9 is bound to
## quick_load" is a measurement and not a comment.
func _log_bindings() -> void:
	for action in [&"quick_save", &"quick_save_alt", &"quick_load", &"quick_load_alt", &"new_run"]:
		if not InputMap.has_action(action):
			_say("[FKEY] binding %s: ACTION DOES NOT EXIST" % action)
			continue
		var names: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				names.append(OS.get_keycode_string((event as InputEventKey).keycode))
			elif event is InputEventMouseButton:
				names.append("Mouse%d" % (event as InputEventMouseButton).button_index)
			else:
				names.append(event.as_text())
		_say("[FKEY] binding %s -> %s" % [action, str(names)])


## THE DELIVERY RECORD. Only fires if the event reaches the game's own input handling, which is the
## question this probe exists to answer.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo:
			_received[key.keycode] = int(_received.get(key.keycode, 0)) + 1
			_say("[FKEY] GAME RECEIVED key %s (keycode %d)"
				% [OS.get_keycode_string(key.keycode), key.keycode])


## Feed a key into the engine's input pipeline exactly the way the previous probe did, so the two
## runs are comparable. Both key fields are set so the event matches whichever field the binding uses.
func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode as Key
	event.physical_keycode = keycode as Key
	event.pressed = pressed
	Input.parse_input_event(event)


## The input layer, resolved from the instanced main scene so the two live counters below are read
## from the REAL node rather than assumed.
func _input_layer() -> Node:
	if _main == null:
		return null
	return _main.get_node_or_null("CascadiaInput")


## How many idle frames `CascadiaInput._process` has actually run. A frozen value means the game's
## own loop stopped being called; an advancing value means the loop is alive.
func _input_ticks() -> int:
	var layer := _input_layer()
	if layer == null:
		return -1
	return int(layer.get("process_ticks"))


## Whether gameplay still WANTS the cursor captured. If this reads false, `_keep_mouse_captured`
## correctly does nothing, and a released cursor is the game's own decision rather than the host's.
func _look_enabled() -> Variant:
	var layer := _input_layer()
	if layer == null:
		return "n/a"
	return bool(layer.get("mouse_look_enabled"))


func _counter(property: String) -> int:
	var save := GameStateSave.find_save(get_tree())
	if save == null:
		return -1
	return int(save.get(property))


func _focused() -> bool:
	var window := get_window()
	return window != null and window.has_focus()


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


## Print immediately AND keep for the durable transcript. The immediate print is what identifies the
## last line reached if the process is ended mid-run - which is exactly the case being measured.
func _say(message: String) -> void:
	var stamped := "[i%d p%d] %s" % [Engine.get_process_frames(), Engine.get_physics_frames(), message]
	_transcript.append(stamped)
	print(stamped)


func _flush() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		print("[FKEY] could not write %s" % REPORT_PATH)
		return
	file.store_string("\n".join(_transcript))
	file.close()
	print("[FKEY] transcript written: %s" % REPORT_PATH)
