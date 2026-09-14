class_name PauseMenu
extends CanvasLayer
## Milestone 13 - pause, and the panel that owns it.
##
## WHAT PAUSE IS HERE: `get_tree().paused = true` and nothing else. That is the engine's real pause, so
## every node whose process mode is the default stands still - movement, stamina regeneration, attack
## phases, enemy AI - and the game cannot look alive while being unplayable. CascadiaInput already
## tolerates this state: its clock reconciliation skips its work while the tree is paused, so a pause
## neither looks like the externally-stopped clock that caused the earlier F9 defect nor fights it.
##
## THIS FILE OWNS NO GAMEPLAY STATE. It owns one boolean, derived from `get_tree().paused`, and the
## panel's own visibility. It does not own Credits, health, stamina, the lock, or any save data: the
## controls below CALL the existing services and DISPLAY what those services return.
##
## WHY THE PANEL IS HIDDEN AND NOT MERELY TRANSPARENT. `focus_input_routing_probe_debug` enumerates
## every VISIBLE Control under every CanvasLayer and fails if one with a non-IGNORE mouse filter
## overlaps the centre of the viewport - correctly, because Cascadia's light and heavy attacks are
## bound to MOUSE BUTTONS and such a Control eats them. The panel sits in the centre of the screen by
## design, so it uses visible = false while unpaused (it is not in the hit-test path at all) and
## MOUSE_FILTER_IGNORE on every decorative Control inside it. Only the four Buttons keep their default
## STOP filter, because a button MUST be clickable - and a Button can only be reached while the panel
## is deliberately open, which is an explicit choice the player made.
##
## WHY THE BUTTONS ARE WIRED DIRECTLY AND NOT TAKEN THROUGH THE INPUT LAYER. Project rule: gameplay
## reads semantic actions through CascadiaInput, never raw device input. A menu button is not gameplay
## and has no gameplay consequence, and Godot's own Control input path is the only thing that can
## deliver a click to it. The one input this class reads itself is the PAUSE gesture, which IS a
## gameplay-adjacent flow action, and it is read as the semantic `ui_cancel` action rather than as the
## physical Escape key (`menu` is the same intent but is bound to a joypad button, so `ui_cancel` is
## the one gesture that works on a keyboard today).
##
## WHY ui_cancel IS HANDLED IN `_input` AND MARKED HANDLED. Escape is already wired:
## `CascadiaInput._unhandled_input` maps it to `set_mouse_look(false)`, which frees the cursor. Pause
## must cooperate with that rather than fight it, and the cooperation is ORDER: this class sees the
## event first, takes it, and then applies the SAME intent the input layer would have applied (look
## off, cursor free). Marking the event handled is what stops the input layer from also acting on it,
## so the cursor cannot be released twice or re-captured by the same key press on the way back up.
## The `menu` action still works through the normal unhandled path, so a controller is unaffected.
##
## WHERE THE CURSOR IS PUT, AND WHY. While paused the cursor must be free - the player is using a menu.
## While playing the cursor must be captured, and the project rule is that capture requested OUTSIDE a
## real input event can be silently dropped by the host, so the request is made from inside the Escape
## press itself (which is a real input event). Two further paths are handled explicitly:
##   - `_process` re-frees the cursor for as long as the panel is open, because CascadiaInput's own
##     click recovery deliberately takes the pointer back on ANY mouse press and is not gated on the
##     pause. Without this, one click anywhere in the panel would capture the cursor and the player
##     could not reach the buttons. The panel, not the input layer, is the authority here.
##   - Resume re-enables gameplay's declared intent through `set_mouse_look(true)`, which is the
##     input layer's own API, so the layer's per-frame keeper then holds the cursor as normal.
##
## NOTHING HERE STACKS. There is exactly one pauseMenu node, one boolean and one visibility state; the
## toggle is idempotent per state, so a repeated open cannot add a second panel or a second pause, and
## `close()` on an already-closed panel does nothing.

## The semantic action for "open the game menu". Bound to a joypad button only, so it is offered in
## addition to `ui_cancel` rather than instead of it.
const MENU_ACTION := &"menu"
## The semantic action for Escape, and the only keyboard gesture that opens this panel.
const CANCEL_ACTION := &"ui_cancel"

const TEXT_OK := Color(0.44, 0.85, 0.5, 1)
const TEXT_BAD := Color(0.92, 0.42, 0.38, 1)
const TEXT_DIM := Color(0.78, 0.81, 0.86, 1)

## The panel root. HIDDEN while unpaused - see the class comment.
var panel: Control
## The four controls. Public because they ARE the interface a probe exercises: a probe fires the real
## `pressed` signal rather than calling a shortcut that a button might not be wired to.
var save_button: Button
var load_button: Button
var new_run_button: Button
var resume_button: Button
## The status line, and the text that was last written into it. The two are compared by a probe to
## prove the displayed feedback comes from the returned Result code.
var status_label: Label
var last_status_text := ""
## What the last control did, and the Result code it got back. These are a REPORT of the service's
## answer, not a copy of any stored game state.
var last_action := "none"
var last_result_code := -1
## How many property assignments this class has made to `get_tree().paused`. A probe reads it to prove
## the toggle does not re-apply the same state over and over.
var pause_writes := 0
## How many times the panel was actually shown. A probe reads it to prove that a repeated open did not
## create a second panel.
var opens := 0

var _save: GameStateSave
var _ledger: CreditLedger
## Named `_input_layer` and NOT `_input`: a member variable called `_input` collides with the engine's
## own `_input(event)` virtual, and GDScript refuses the file outright with
## "Function _input has the same name as a previously declared variable".
var _input_layer: CascadiaInput


func _ready() -> void:
	# The panel must stay interactive while the tree is paused, so this layer and its children keep
	# processing. PROCESS_MODE_ALWAYS on the layer covers its children.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8
	_build_ui()
	panel.visible = false
	visible = true
	_resolve()
	_set_status("ready" if _get_save() != null else "no save service in the tree", true)


func _process(_delta: float) -> void:
	if panel == null or not panel.visible:
		return
	# The panel is open, so the cursor must be usable. See the class comment for why this has to be
	# re-asserted rather than set once.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- The pause gesture ------------------------------------------------------

## Pause / resume from the semantic Escape action. Handled in `_input` so it runs before
## `CascadiaInput._unhandled_input`, and marked handled so the input layer does not act on the same
## press a second time.
## SUPERSEDED DESIGN, RECORDED SO IT IS NOT RE-INTRODUCED. This used to be LAYERED: the first Escape
## was left to `CascadiaInput._unhandled_input` (which maps `ui_cancel` to `set_mouse_look(false)`) and
## the panel opened on the SECOND Escape. That avoided competing with the input layer, but it put the
## pause two presses away and made Escape look like it did nothing but free the mouse. The user asked
## for one press.
##
## ONE PRESS NOW DOES BOTH, because the two jobs were never in conflict - they are the same intent.
## `open()` performs the release itself through `set_mouse_look(false)`, so the capture intent goes off
## and the cursor is freed exactly as before, and the press is marked handled so the input layer does
## not repeat that work on the way up. The release behaviour is unchanged; only the number of presses
## is. `mouse_look_enabled` is still owned by the input layer and by the click that re-takes the cursor
## - this class calls that layer's own API rather than writing the flag.
func _input(event: InputEvent) -> void:
	if not InputMap.has_action(CANCEL_ACTION):
		return
	if not event.is_action_pressed(CANCEL_ACTION):
		return
	# ESCAPE OPENS THE PAUSE ON ITS FIRST PRESS (changed 2026-09-14 at the user's request). The earlier
	# version was LAYERED: the first Escape only released the cursor, left to the input layer, and the
	# SECOND opened the panel. That put the pause two presses away and made Escape look like it did
	# nothing but free the mouse. This takes the press outright and marks it handled, so the input
	# layer does not act on the same press a second time.
	#
	# NOTHING Escape used to do is lost. Its old job was `set_mouse_look(false)` plus a free cursor, and
	# `open()` performs exactly that through the input layer's own API; `close()` reverses it. One
	# press, one owner, one cursor change - and the capture is re-requested from inside a real input
	# event, which is the condition this host requires before it will grant pointer lock back.
	get_viewport().set_input_as_handled()
	toggle_pause()


## The same toggle from the `menu` action, which has no keyboard binding. It arrives here only when
## nothing else consumed it, which is the normal unhandled path.
func _unhandled_input(event: InputEvent) -> void:
	if not InputMap.has_action(MENU_ACTION):
		return
	if not event.is_action_pressed(MENU_ACTION):
		return
	get_viewport().set_input_as_handled()
	toggle_pause()


## Pause when playing, resume when paused. Returns whether the game is paused afterwards.
func toggle_pause() -> bool:
	if is_game_paused():
		close()
		return false
	open()
	return true


## Pause the game and show the panel. Idempotent: opening an open panel changes nothing, so a repeated
## gesture cannot stack a second panel or a second pause.
func open() -> void:
	if is_game_paused() and panel.visible:
		return
	_set_paused(true)
	panel.visible = true
	_set_buttons_clickable(true)
	opens += 1
	# The cursor belongs to the menu now. `set_mouse_look(false)` is the input layer's own API: it is
	# the same intent Escape declares, so the layer is not being bypassed.
	var input := _get_input()
	if input != null:
		input.set_mouse_look(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_save_hint()
	if resume_button != null:
		resume_button.grab_focus()


## Resume the game and hide the panel. Idempotent in the same way.
func close() -> void:
	if not is_game_paused() and not panel.visible:
		return
	_set_paused(false)
	panel.visible = false
	_set_buttons_clickable(false)
	# Hand the cursor back to gameplay by re-declaring gameplay's intent through the input layer, which
	# is what re-enables its per-frame keeper. That call is made from inside the Escape press when the
	# pause was opened and from inside the button press when it was closed, so it is always inside a
	# real input event - which is the condition this host requires before it will grant pointer lock.
	var input := _get_input()
	if input != null:
		input.set_mouse_look(true)


## Whether the game is paused right now. Read from the tree, because the tree is the owner: it is
## never cached in a second boolean here.
func is_game_paused() -> bool:
	var tree := get_tree()
	return tree != null and tree.paused


func _set_paused(paused: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.paused == paused:
		return
	tree.paused = paused
	pause_writes += 1


# --- Save and load ----------------------------------------------------------

## Save through the EXISTING service, and report what it returned. The Result code is the only thing
## that decides whether the status line says success, so a refusal can never be shown as one.
func save_via_service() -> int:
	var save := _get_save()
	if save == null:
		last_action = "save"
		last_result_code = -1
		_set_status("SAVE UNAVAILABLE: no GameStateSave in the tree", false)
		return -1
	var code: int = save.save_game()
	last_action = "save"
	last_result_code = code
	_report("SAVE", code, save)
	return code


## Load through the EXISTING service, and report what it returned. The HUD does not need to be told
## anything here: a successful load restores through each value's own owner, those owners report the
## change on their own signals, and the HUD re-reads them. That is what keeps loaded numbers from
## arriving next to stale ones.
func load_via_service() -> int:
	var save := _get_save()
	if save == null:
		last_action = "load"
		last_result_code = -1
		_set_status("LOAD UNAVAILABLE: no GameStateSave in the tree", false)
		return -1
	var code: int = save.load_game()
	last_action = "load"
	last_result_code = code
	_report("LOAD", code, save)
	return code


## Start a fresh run through the existing service, for the same reason: this UI owns no run state.
func new_run_via_service() -> int:
	var save := _get_save()
	if save == null:
		last_action = "new run"
		last_result_code = -1
		_set_status("NEW RUN UNAVAILABLE: no GameStateSave in the tree", false)
		return -1
	var code: int = save.new_run()
	last_action = "new run"
	last_result_code = code
	_report("NEW RUN", code, save)
	return code


## The status line for a returned Result code. One place decides the wording, so every outcome reads
## differently and none of them can be mistaken for another.
func _report(verb: String, code: int, save: GameStateSave) -> void:
	if code == GameStateSave.Result.OK:
		var balance := -1
		var ledger := _get_ledger()
		if ledger != null:
			balance = ledger.get_credits()
		_set_status("%s OK  (carried %d Credits)" % [verb, balance], true)
		return
	_set_status("%s REFUSED: %s - %s" % [verb, GameStateSave.result_name(code), save.last_error], false)


## Enable or disable mouse input on the four buttons. Every Control in this file is otherwise IGNORE;
## these four are STOP only while the panel is open, because a button that ignores the mouse is not a
## button. See `_build_button` for why this is a state rather than a fixed filter.
func _set_buttons_clickable(clickable: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	for button in [resume_button, save_button, load_button, new_run_button]:
		if button != null:
			button.mouse_filter = filter
	if not clickable:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner != null and is_ancestor_of(focus_owner):
			focus_owner.release_focus()


func _set_status(text: String, ok: bool) -> void:
	last_status_text = text
	if status_label == null:
		return
	status_label.text = text
	status_label.add_theme_color_override("font_color", TEXT_OK if ok else TEXT_BAD)


func _refresh_save_hint() -> void:
	var save := _get_save()
	if save == null:
		return
	if status_label != null and last_status_text.is_empty():
		_set_status("no save yet" if not save.has_save() else "a save file is present", true)


# --- Scaling ----------------------------------------------------------------

func scale_images(scale: float) -> void:
	if panel != null:
		panel.scale = Vector2(scale, scale)


# --- Resolution -------------------------------------------------------------

func _get_save() -> GameStateSave:
	if _save == null or not is_instance_valid(_save):
		_resolve()
	return _save


func _get_ledger() -> CreditLedger:
	if _ledger == null or not is_instance_valid(_ledger):
		_resolve()
	return _ledger


func _get_input() -> CascadiaInput:
	if _input_layer == null or not is_instance_valid(_input_layer):
		if get_tree() != null:
			_input_layer = get_tree().get_first_node_in_group(
				CascadiaInput.ACTION_GROUP) as CascadiaInput
	return _input_layer


func _resolve() -> void:
	if get_tree() == null:
		return
	if _save == null or not is_instance_valid(_save):
		_save = GameStateSave.find_save(get_tree())
	if _ledger == null or not is_instance_valid(_ledger):
		_ledger = CreditLedger.find_ledger(get_tree())


# --- UI construction --------------------------------------------------------

## A centred panel with a result line and four controls. Anchored and laid out by containers, so it
## fits any viewport including the in-editor Play view.
func _build_ui() -> void:
	panel = Control.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The full-rect container itself must not consume a click: it covers the whole screen while open.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	var centre := CenterContainer.new()
	centre.name = "Centre"
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(centre)

	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.custom_minimum_size = Vector2(420.0, 0.0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(frame)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Rows"
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	var title := Label.new()
	title.name = "Title"
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Escape resumes"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hint)

	resume_button = _build_button(column, "ResumeButton", "Resume  (Escape)")
	save_button = _build_button(column, "SaveButton", "Save run  (F5)")
	load_button = _build_button(column, "LoadButton", "Load run  (F7)")
	new_run_button = _build_button(column, "NewRunButton", "New run  (F10)")

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(360.0, 40.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", TEXT_DIM)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status_label)


## One button. The default STOP mouse filter is kept here and ONLY here: a button must be clickable,
## and the intent argument above is the whole reason no other Control in this file keeps it.
func _build_button(parent: Control, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	# CLOSED MEANS INERT, and this is not cosmetic. `Control.visible` is a LOCAL flag: a Button inside a
	# hidden panel still reports `visible == true`, so the project's focus-routing check - which
	# enumerates every visible Control with a non-IGNORE filter that overlaps the centre of the view -
	# counts it and fails. The panel is centred by design, so a STOP-filtered Button in it is exactly
	# the shape that check exists to catch. `_set_buttons_clickable()` therefore keeps every button at
	# IGNORE while the panel is closed and switches it to STOP only while the panel is genuinely open,
	# which is also the honest statement: a hidden control cannot take a click.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(button)
	match node_name:
		"ResumeButton":
			button.pressed.connect(_on_resume_pressed)
		"SaveButton":
			button.pressed.connect(_on_save_pressed)
		"LoadButton":
			button.pressed.connect(_on_load_pressed)
		"NewRunButton":
			button.pressed.connect(_on_new_run_pressed)
	return button


func _on_resume_pressed() -> void:
	close()


func _on_save_pressed() -> void:
	save_via_service()


func _on_load_pressed() -> void:
	load_via_service()


func _on_new_run_pressed() -> void:
	new_run_via_service()
