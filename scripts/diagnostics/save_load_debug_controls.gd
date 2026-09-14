class_name SaveLoadDebugControls
extends CanvasLayer
## Temporary PROTOTYPE control for the Milestone 10 save/load loop (not final UI).
##
## WHY THIS EXISTS. The milestone requires a save/load path that is REAL and observable in the
## running game, and no menu system exists yet. This is the smallest honest thing that satisfies
## that: three keys, a result line, and the live carried balance next to them.
##
## PROTOTYPE CONTROL, NOT GAMEPLAY INPUT. Cascadia's rule is that GAMEPLAY reads semantic actions
## through `CascadiaInput`, never raw device input. Save/load is not gameplay and has no gameplay
## consequence, so this diagnostic reads its own InputMap actions directly and guards every lookup.
## When save/load becomes a real menu it MUST be routed through `CascadiaInput` like every other
## player action, and this node should be deleted - it is not the beginning of a menu framework.
##
## It owns NO balance and NO saved state: it calls `GameStateSave`, which calls `CreditLedger`.
## That chain is deliberate, and reading it is the fastest way to see who owns what.

## The semantic actions this prototype reads. Registered in the project InputMap.
const ACTION_SAVE := &"quick_save"
## LOAD IS **NOT** `quick_load` ANY MORE, AND THIS IS A MEASURED HOST CONSTRAINT, NOT A PREFERENCE.
##
## `quick_load`'s binding is F9, and F9 IS OWNED BY THE HOST THAT EMBEDS THIS GAME. Measured with the
## in-game consumer DISABLED, so no game code could be responsible: injecting F9 set
## `Engine.time_scale = 0` and released the mouse while `SceneTree.paused` stayed FALSE, and the
## game's own frame loop was starved (only 6 of ~40 frames processed). A SECOND F9 press was never
## delivered to the game (the host ate it) and restored the clock - F9 is the host's PAUSE TOGGLE.
## With zero time scale every delta-driven system stands still, so the game renders frames while being
## completely unplayable. That is precisely the reported "F9 breaks gameplay", and no code inside the
## game can win a race for a key the host consumes.
##
## `quick_load_alt`'s F8 is worse: it ENDS THE DEBUG SESSION. Measured: the process stopped on F8
## with no script error and no trace.
##
## So the load path reads actions bound ONLY to keys the host does not use. F7 and F11 were both
## measured: delivered to the game, `scale` stayed 1.000, `paused=false`, mouse stayed captured
## (mode 2), and no input frame was skipped. F1-F7, F10-F12 and ordinary letters are safe; only
## F8 and F9 are not. `quick_load` / `quick_load_alt` are left in the InputMap UNUSED rather than
## deleted - the removal of a binding is manual (see CASCADIA_DELETION_MANIFEST.md).
const ACTION_LOAD := &"load_run"
## The alternate load binding, kept for the same reason as before: two independent keys for one
## operation, so a key that fails to arrive can be told apart from an operation that fails to run.
const ACTION_LOAD_ALT := &"load_run_alt"
const ACTION_NEW_RUN := &"new_run"
## The alternate SAVE binding. Every key on this list was MEASURED safe in this host (delivered to the
## game, `scale` stayed 1.000, `paused=false`, mouse stayed captured, no input frame skipped).
##
## The alternate keys began as an EXPERIMENT - "F5/F9 are the classic host debugger keys, so if F6/F8
## work while F5/F9 do not, the host owns F5/F9 and the fix is a rebind rather than a code fix". That
## experiment has now been run and ANSWERED:
##
##   F5, F6, F10   delivered and safe.
##   F7, F11       delivered and safe.
##   F1, F3, F4    delivered and safe (F1 is `toggle_debug_overlay`, the other two are free).
##   F2            free, used as the control that proved "not every function key is special".
##   F8            ENDS THE DEBUG SESSION - the process stops, no script error, no trace.
##   F9            THE HOST'S PAUSE TOGGLE - stops the clock and frees the cursor while
##                 `SceneTree.paused` stays false, delivers nothing on the second press, and
##                 starved the game's own loop to 6 of ~40 frames.
##
## So the alternate bindings are no longer an experiment; they are two independent keys for the same
## operation, with the host-owned keys removed from the load path entirely.
const ACTION_SAVE_ALT := &"quick_save_alt"

const TEXT_DIM := Color(0.62, 0.66, 0.72, 1)
const TEXT_OK := Color(0.44, 0.85, 0.5, 1)
const TEXT_BAD := Color(0.9, 0.35, 0.32, 1)
const TEXT_VALUE := Color(0.95, 0.85, 0.45, 1)

## The panel this prototype draws. Kept as a member so the debug toggle can hide it: it shares the
## top-right corner with the gameplay HUD's Credits readout and sits on a HIGHER layer, so it is both
## positioned clear of that readout and switchable off with the same key as the other debug overlays.
var _panel: PanelContainer
var _label: Label
var _save: GameStateSave
var _ledger: CreditLedger
## The last thing the player asked for, shown verbatim so a refusal is never silent.
var _status := "no save/load action yet"


func _ready() -> void:
	layer = 3
	_build_ui()
	_resolve()
	_refresh()


func _process(_delta: float) -> void:
	_sync_debug_visibility()
	if _save == null or _ledger == null:
		_resolve()
	if _save == null or _ledger == null:
		return

	# Either binding fires the SAME operation, so the alternate keys are a drop-in replacement rather
	# than a second code path that could drift from the primary one.
	if _pressed(ACTION_SAVE) or _pressed(ACTION_SAVE_ALT):
		var code := _save.save_game()
		_status = _describe("save", code, _ledger.get_credits())
	elif _pressed(ACTION_LOAD) or _pressed(ACTION_LOAD_ALT):
		var code := _save.load_game()
		_status = _describe("load", code, _ledger.get_credits())
	elif _pressed(ACTION_NEW_RUN):
		var code := _save.new_run()
		_status = _describe("new run", code, _ledger.get_credits())

	_refresh()


## The same key that toggles the other debug overlays also toggles THIS one, so a single press clears
## the whole debug layer off the screen. That is the direct fix for the reported problem: the HUD's
## Credits readout shares the top-right corner, and this panel used to sit on top of it permanently.
## The two toggle together, so they cannot drift out of sync with each other.
func _sync_debug_visibility() -> void:
	if _panel == null:
		return
	if _pressed(GameActions.TOGGLE_DEBUG_OVERLAY):
		_panel.visible = not _panel.visible


## True only when the action exists AND was pressed, so a project without the binding shows a
## readable missing-binding hint instead of raining engine errors every frame.
func _pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	return Input.is_action_just_pressed(action)


## The save service and the ledger, resolved through their own groups so neither path is guessed.
func _resolve() -> void:
	_save = GameStateSave.find_save(get_tree())
	_ledger = CreditLedger.find_ledger(get_tree())


func _describe(verb: String, code: int, balance: int) -> String:
	if code == GameStateSave.Result.OK:
		return "%s: %s  (carried %d)" % [verb, GameStateSave.result_name(code), balance]
	return "%s FAILED: %s - %s" % [verb, GameStateSave.result_name(code), _save.last_error]


func _refresh() -> void:
	if _label == null:
		return
	var lines: Array = []
	lines.append("SAVE / LOAD  (prototype, not final UI)")
	lines.append("%s/%s save    %s/%s load    %s new run" % [
		_key_text(ACTION_SAVE), _key_text(ACTION_SAVE_ALT),
		_key_text(ACTION_LOAD), _key_text(ACTION_LOAD_ALT),
		_key_text(ACTION_NEW_RUN)])

	if _ledger == null:
		lines.append("carried credits: no CreditLedger in the tree")
	else:
		lines.append("carried credits %d" % _ledger.get_credits())

	if _save == null:
		lines.append("save: no GameStateSave in the tree")
	else:
		lines.append("save file: %s" % ("present" if _save.has_save() else "none yet"))
	lines.append(_status)

	_label.text = "\n".join(PackedStringArray(lines))
	_label.add_theme_color_override("font_color",
		TEXT_OK if _save != null and _save.last_result == GameStateSave.Result.OK else TEXT_DIM)


## The key actually bound to an action, read from the InputMap so this label cannot drift from the
## real binding.
func _key_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "%s(unbound)" % action
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).as_text_keycode()
	return "%s(no key)" % action


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	_panel = panel
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -330.0
	# BELOW the HUD's Credits readout, NOT on top of it. The HUD's credits panel occupies the top-right
	# corner from y = 10 down to roughly y = 54 (its label plus margins), and this panel is on a higher
	# layer, so at the original offset_top of 8 it covered the credits number completely. 62 clears it
	# on any viewport height, and costs nothing: this is a prototype readout, not placed gameplay UI.
	panel.offset_top = 62.0
	panel.offset_right = -8.0
	# CONTROL, DO NOT CONSUME. A Control defaults to MOUSE_FILTER_STOP, which would swallow every
	# mouse click landing inside this rectangle - and Cascadia's light and heavy attacks are bound to
	# MOUSE BUTTONS. A read-only status panel must never be able to eat an attack, so every Control in
	# this prototype ignores the mouse. Mouse filter is PER CONTROL, not inherited, so all three are
	# set rather than relying on the parent.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	_label = Label.new()
	_label.name = "Status"
	_label.add_theme_color_override("font_color", TEXT_DIM)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_label)

	# Keep the prototype text legible against the arena without touching any gameplay theme.
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
