class_name SaveLoadInputRuntimeProbeDebug
extends Node3D
## Temporary diagnostic (not production): does the save/load debug panel CONSUME gameplay
## mouse input, and does a MOUSE-BOUND attack still reach PlayerCombat after a load?
##
## WHY THIS EXISTS. A claim was made that the save/load panel swallows mouse clicks because
## its Control nodes default to MOUSE_FILTER_STOP, and that this is what makes the game look
## dead after a load. A claim is not evidence. This probe measures it against the LIVE tree
## and the LIVE input path, in three separate and clearly-labelled ways:
##
##   (a) HIERARCHY - walk the INSTANTIATED panel subtree and read every Control's
##       mouse_filter. Static, and labelled as such.
##   (b) GUI DELIVERY - connect to the `gui_input` signal of every Control in the tree, push
##       a real click, and count how many controls RECEIVED it. This is validated by a
##       POSITIVE CONTROL: a deliberately STOP control must be counted, or the detector is
##       reported as UNVERIFIED and the GUI results are reported as NOT MEASURABLE rather
##       than silently passing.
##   (c) END TO END - inject a real left mouse-button event through Input and observe whether
##       PlayerCombat actually starts an attack, BEFORE and AFTER a load. This is the test
##       that matters, because it does not care WHY a click is lost, only whether it is.
##
## NO `await` ANYWHERE, on purpose. An awaited call returns a coroutine, and a coroutine is
## truthy in an `if` - which would let an attack check pass without proving anything. Every
## wait here is an explicit frame count in the stage machine.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena and UI to settle before anything is measured.
const SETTLE_FRAMES := 15
## Frames to observe after a click, waiting for the attack to register.
const OBSERVE_FRAMES := 10
## Frames to wait for the combat machine to return to idle before the next attempt.
const MAX_IDLE_WAIT := 120
## Frames the player is driven forward to prove processing is still live after a load.
const MOVE_FRAMES := 20
## A player that moves less than this out of a load is not processing.
const MIN_TRAVEL := 0.02

var _frame := 0
var _stage := 0
var _done := false
var _failures: Array = []

var _ledger: CreditLedger
var _save: GameStateSave
var _player: Node3D
var _combat: Node
var _panel: Control

var _saved_value := 0
var _panel_rect := Rect2()
var _world_point := Vector2.ZERO

## GUI-delivery detector state. `_gui_detector_valid` gates whether (b) is trustworthy.
var _gui_detector_valid := false
var _gui_hits := 0
var _gui_hits_panel := -1
var _gui_hits_world := -1
var _prev_mouse_mode := 0

## Attempt queue state. Each attempt is {label, point, expect_attack}.
var _attempts_before: Array = []
var _attempts_after: Array = []
var _current: Dictionary = {}
var _current_phase := 0
var _wait := 0
var _busy_seen := false
var _press_sent := false
var _using_after := false
var _attempt_rows: Array = []

## Result of the controlled A/B: did a click at the panel centre start an attack with STOP forced?
var _stop_filter_attack_started := false

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
			_stage_setup()
		1:
			_stage_stop_filter_experiment()
		2:
			_stage_attempts()
		3:
			_stage_wait_idle_before_move()
		4:
			_stage_measure_movement()


# --- Stage 0: hierarchy, gui delivery, binding ---------------------------------

func _stage_setup() -> void:
	print("[SLINPUT] --- save/load panel input-routing audit (measured) ---")
	_resolve()
	if _save == null or _ledger == null or _player == null or _panel == null:
		_fail("could not resolve the save service, the ledger, the player and the panel")
		_finish()
		return

	_stand_down_ambient_attackers()
	_backup_existing()

	# ------------------------------------------------------------------ (a) HIERARCHY
	var controls := _all_controls()
	var offenders := _count_stop_controls(_panel)
	print("[SLINPUT] live tree: %d Control(s). save panel subtree: %d Control(s), %d STOP" % [
		controls.size(), _controls_under(_panel).size(), offenders])
	_expect(offenders == 0,
		"HIERARCHY: no Control in the live save-panel subtree uses MOUSE_FILTER_STOP (found %d)"
		% offenders)

	_panel_rect = _panel.get_global_rect()
	var view := get_viewport().get_visible_rect()
	_world_point = Vector2(view.size.x * 0.25, view.size.y * 0.75)
	print("[SLINPUT] panel rect=%s  visible=%s  viewport=%s" % [
		str(_panel_rect), str(_panel.is_visible_in_tree()), str(view.size)])
	_expect(_panel.is_visible_in_tree(), "the save panel is VISIBLE (the fix must not hide it)")
	_expect(_panel_rect.size.x > 0.0 and _panel_rect.size.y > 0.0,
		"the save panel occupies a real on-screen rectangle")
	_expect(view.intersects(_panel_rect),
		"the save panel OVERLAPS the gameplay viewport, so the click test is not vacuous")

	# -------------------------------------------------------------------- (b) GUI DELIVERY
	# GUI hit testing only happens with a visible cursor, so measure in that mode and put the
	# mouse mode back afterwards. This is the WORST CASE for the panel: if it were going to
	# consume a click, it would do it here.
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_gui_detector_valid = _validate_gui_detector(_panel_rect.get_center())
	if _gui_detector_valid:
		_gui_hits_panel = _gui_delivery_at(_panel_rect.get_center())
		_gui_hits_world = _gui_delivery_at(_world_point)
		print("[SLINPUT] GUI delivery: panel centre hits=%d  world point hits=%d" % [
			_gui_hits_panel, _gui_hits_world])
		_expect(_gui_hits_panel == 0,
			"GUI: no Control RECEIVED a click at the panel centre (got %d)" % _gui_hits_panel)
		_expect(_gui_hits_world == 0,
			"GUI: no Control received a click at the world point (got %d)" % _gui_hits_world)
	else:
		_skip("GUI DELIVERY NOT MEASURABLE: the positive control never received a click, "
			+ "so this harness cannot detect consumption either way")

	Input.mouse_mode = _prev_mouse_mode

	# ------------------------------------------------------------------------ BINDING
	var button := _mouse_button_for(&"light_attack")
	print("[SLINPUT] light_attack bound to mouse button=%d (1 == MOUSE_BUTTON_LEFT)" % button)
	_expect(button == MOUSE_BUTTON_LEFT,
		"light_attack IS bound to Mouse1, so a swallowed click would really cost an attack")

	# ------------------------------------------------------- (c) END-TO-END click queue
	# Four real-click attempts: panel and world, before and after the load.
	_attempts_before = [
		{"label": "world click BEFORE load", "point": _world_point},
		{"label": "panel click BEFORE load", "point": _panel_rect.get_center()},
	]
	_attempts_after = [
		{"label": "panel click AFTER load", "point": _panel_rect.get_center()},
		{"label": "world click AFTER load", "point": _world_point},
	]
	_stage = 1


# --- Stage 1: the CONTROLLED A/B - does the STOP filter actually cost an attack? -

## The decisive experiment. The shipped panel uses MOUSE_FILTER_IGNORE. This stage puts
## MOUSE_FILTER_STOP back on every panel Control, fires the SAME real click at the SAME point, and
## asks whether an attack still starts.
##
## Both outcomes are informative and neither is assumed:
##   attack still starts  -> the filter cannot block a mouse-bound attack at all, so Problem A was
##                           never the cause of the reported symptom;
##   attack does NOT start -> the filter DOES cost attacks, and the IGNORE fix is the cause.
func _stage_stop_filter_experiment() -> void:
	if _current_phase == 0:
		_wait += 1
		if _combat_busy():
			if _wait > MAX_IDLE_WAIT:
				_fail("STOP-filter experiment: the combat machine never returned to idle")
				_finish()
			return
		_set_panel_filter(Control.MOUSE_FILTER_STOP)
		_fire_click(_panel_rect.get_center())
		_current_phase = 1
		_wait = 0
		return

	_wait += 1
	if _wait == 2 and _press_sent:
		_release_click(_panel_rect.get_center())
	if _combat_busy():
		_stop_filter_attack_started = true
	if _wait < OBSERVE_FRAMES:
		return

	# Put the shipped filter back, so every later stage measures the real panel.
	_set_panel_filter(Control.MOUSE_FILTER_IGNORE)
	print("[SLINPUT] (d) CONTROLLED A/B at the panel centre: with MOUSE_FILTER_STOP the click %s an attack"
		% ("STILL started" if _stop_filter_attack_started else "did NOT start"))
	print("[SLINPUT]     => the filter %s the cause of a lost attack" % (
		"WAS" if not _stop_filter_attack_started else "was NOT"))
	_expect(true, "the STOP-filter A/B experiment ran (so the comparison is not silently skipped)")

	_stage = 2
	_wait = 0


## Force one mouse filter across every Control in the live save panel.
func _set_panel_filter(mode: int) -> void:
	for control in _controls_under(_panel):
		control.mouse_filter = mode


# --- Stage 2: run each real-click attempt, then save/load in between ------------

func _stage_attempts() -> void:
	if _current.is_empty():
		var list: Array = _attempts_after if _using_after else _attempts_before
		if list.is_empty():
			if not _using_after:
				_do_save_load()
				_using_after = true
				return
			_begin_movement()
			return
		_current = list.pop_front()
		_current_phase = 0
		_wait = 0
		_busy_seen = false
		_press_sent = false
		return

	if _current_phase == 0:
		# Wait for the machine to be idle so the next observation is unambiguous.
		_wait += 1
		if _combat_busy():
			if _wait > MAX_IDLE_WAIT:
				_fail("%s: the combat machine never returned to idle" % String(_current["label"]))
				_current = {}
			return
		_fire_click(_current["point"])
		_current_phase = 1
		_wait = 0
		return

	# Observing: did the click start an attack?
	_wait += 1
	if _wait == 2 and _press_sent:
		_release_click(_current["point"])
	if _combat_busy():
		_busy_seen = true
	if _wait < OBSERVE_FRAMES:
		return

	var label := String(_current["label"])
	_attempt_rows.append("%s: attack_started=%s" % [label, str(_busy_seen)])
	_expect(_busy_seen,
		"END TO END: a real Mouse1 click at the %s started an attack" % label)
	_current = {}


# --- Save and load, with the runtime checked around them -----------------------

func _do_save_load() -> void:
	_ledger.reset_credits()
	_ledger.award_credits(100, "probe")
	_saved_value = _ledger.get_credits()
	var save_code := _save.save_game()
	_expect(save_code == GameStateSave.Result.OK, "saving succeeds")
	_ledger.award_credits(900, "probe")
	_expect(_ledger.get_credits() != _saved_value,
		"the balance really changed after saving, so a no-op load cannot pass")

	var services_before := _count_services()
	var load_code := _save.load_game()
	print("[SLINPUT] load: %s  balance -> %d (saved %d)" % [
		GameStateSave.result_name(load_code), _ledger.get_credits(), _saved_value])
	_expect(load_code == GameStateSave.Result.OK, "loading an intact save succeeds")
	_expect(_ledger.get_credits() == _saved_value,
		"loading restored the exact saved balance (%d)" % _saved_value)

	# The load must not disable the runtime.
	_expect(not get_tree().paused, "the scene tree is NOT paused after the load")
	_expect(_player.is_physics_processing(),
		"the player's physics processing is still ENABLED after the load")
	_expect(is_instance_valid(_player) and not _player.is_queued_for_deletion(),
		"the player instance is still valid and not queued for deletion after the load")
	var services_after := _count_services()
	print("[SLINPUT] services before=%s after=%s" % [str(services_before), str(services_after)])
	_expect(services_after == services_before,
		"the load created NO second ledger and NO second save service")


# --- Stage 2: is the runtime still processing? ---------------------------------

func _begin_movement() -> void:
	_stage = 3
	_wait = 0


## Wait for the last click's attack to FINISH before driving movement.
##
## WHY: a committed attack is authoritative over its own movement by Cascadia's own rule, so
## pressing move_forward while one is still in its recovery measures THAT rule rather than
## whether the runtime is processing. The first run of this probe failed here for exactly that
## reason - a probe artifact, not a game defect. Removed the confound instead of weakening the
## assertion, so a genuine processing failure would still be caught.
func _stage_wait_idle_before_move() -> void:
	_wait += 1
	if _combat_busy():
		if _wait > MAX_IDLE_WAIT:
			_fail("movement stage: the combat machine never returned to idle")
			_finish()
		return
	_move_start = _player.global_position
	if InputMap.has_action(&"move_forward"):
		Input.action_press(&"move_forward")
	_stage = 3
	_wait = 0


func _stage_measure_movement() -> void:
	_wait += 1
	if _wait < MOVE_FRAMES:
		return
	if InputMap.has_action(&"move_forward"):
		Input.action_release(&"move_forward")
	var travelled := _player.global_position.distance_to(_move_start)
	print("[SLINPUT] post-load movement: travelled %.4f m over %d frames" % [travelled, MOVE_FRAMES])
	_expect(travelled > MIN_TRAVEL,
		"the runtime is still PROCESSING after the load (player moved %.4f m)" % travelled)
	_finish()


# --- The three measurement mechanisms ------------------------------------------

## (b) How many Controls RECEIVED a click at this point, via the real GUI path.
func _gui_delivery_at(point: Vector2) -> int:
	_gui_hits = 0
	var connected: Array = []
	for control in _all_controls():
		if not control.gui_input.is_connected(_on_probe_gui_input):
			control.gui_input.connect(_on_probe_gui_input)
			connected.append(control)

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	event.global_position = point
	get_viewport().push_input(event)

	for control in connected:
		if control.gui_input.is_connected(_on_probe_gui_input):
			control.gui_input.disconnect(_on_probe_gui_input)
	return _gui_hits


func _on_probe_gui_input(_event: InputEvent) -> void:
	_gui_hits += 1


## (b) validation: a deliberately STOP control MUST be counted, or the detector is useless.
func _validate_gui_detector(point: Vector2) -> bool:
	var layer := CanvasLayer.new()
	layer.name = "ProbePositiveControl"
	layer.layer = 95
	var control := Control.new()
	control.name = "StopControl"
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.position = point - Vector2(20, 20)
	control.size = Vector2(40, 40)
	layer.add_child(control)
	add_child(layer)

	var hits := _gui_delivery_at(point)
	print("[SLINPUT] positive control: STOP control at %s received a click: hits=%d" % [
		str(point), hits])

	remove_child(layer)
	layer.queue_free()
	return hits > 0


## (c) A REAL mouse click fed through Input, the same route an OS click takes.
func _fire_click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	_press_sent = true


func _release_click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = point
	event.global_position = point
	Input.parse_input_event(event)
	_press_sent = false


# --- Tree helpers ---------------------------------------------------------------

func _all_controls() -> Array:
	var found: Array = []
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Control:
			found.append(node)
		for child in node.get_children():
			stack.append(child)
	return found


func _controls_under(root: Control) -> Array:
	var found: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var control: Control = stack.pop_back()
		found.append(control)
		for child in control.get_children():
			if child is Control:
				stack.append(child)
	return found


func _count_stop_controls(root: Control) -> int:
	var offenders := 0
	for control in _controls_under(root):
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			offenders += 1
			print("[SLINPUT]   offender: %s filter=STOP rect=%s" % [
				control.name, str(control.get_global_rect())])
	return offenders


func _count_services() -> Vector2i:
	var ledgers := 0
	var saves := 0
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CreditLedger:
			ledgers += 1
		elif node is GameStateSave:
			saves += 1
		for child in node.get_children():
			stack.append(child)
	return Vector2i(ledgers, saves)


func _combat_busy() -> bool:
	if _combat == null or not is_instance_valid(_combat):
		return false
	if _combat.has_method("is_busy"):
		return bool(_combat.call("is_busy"))
	return false


func _mouse_button_for(action: StringName) -> int:
	if not InputMap.has_action(action):
		return -1
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			return (event as InputEventMouseButton).button_index
	return -1


# --- Resolution and save-file safety -------------------------------------------

func _resolve() -> void:
	_ledger = CreditLedger.find_ledger(get_tree())
	_save = GameStateSave.find_save(get_tree())
	_player = _find_player()
	_panel = _find_save_panel()
	_combat = null
	if _player != null:
		_combat = _player.get_node_or_null("Combat")
		if _combat == null:
			for child in _player.get_children():
				if child.has_method("is_busy"):
					_combat = child
					break


func _find_player() -> Node3D:
	for node in get_tree().get_nodes_in_group(CreditLedger.GROUP_PLAYER_ACTOR):
		if node is Node3D:
			return node as Node3D
	return null


func _find_save_panel() -> Control:
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is SaveLoadDebugControls:
			var panel := node.get_node_or_null("Panel") as Control
			if panel != null:
				return panel
		for child in node.get_children():
			stack.append(child)
	return null


func _stand_down_ambient_attackers() -> void:
	EnemyAttacker.stand_down_all(get_tree())


func _backup_existing() -> void:
	_had_save = _save.has_save()
	if _had_save:
		var file := FileAccess.open(_save.save_path(), FileAccess.READ)
		if file != null:
			_backup_text = file.get_as_text()
			file.close()


func _restore_backup() -> void:
	if _had_save and not _backup_text.is_empty():
		var file := FileAccess.open(_save.save_path(), FileAccess.WRITE)
		if file != null:
			file.store_string(_backup_text)
			file.close()
		print("[SLINPUT] restored the save file that existed before this run")
	else:
		_save.delete_save()
		print("[SLINPUT] removed the probe's save (there was none before this run)")


# --- Reporting -----------------------------------------------------------------

func _finish() -> void:
	_done = true
	Input.mouse_mode = _prev_mouse_mode
	_restore_backup()
	_report()


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("[SLINPUT]   PASS  %s" % description)
	else:
		_fail(description)


func _fail(description: String) -> void:
	_failures.append(description)
	print("[SLINPUT]   FAIL  %s" % description)


## A check this harness cannot make. Recorded as UNVERIFIED, never as a pass.
func _skip(description: String) -> void:
	print("[SLINPUT]   SKIP  %s" % description)


func _report() -> void:
	print("[SLINPUT] --- summary ---")
	print("[SLINPUT] (a) HIERARCHY: panel Controls=%d  STOP offenders=%d" % [
		_controls_under(_panel).size(), _count_stop_controls(_panel)])
	print("[SLINPUT] (b) GUI DELIVERY validated=%s  panel hits=%d  world hits=%d" % [
		str(_gui_detector_valid), _gui_hits_panel, _gui_hits_world])
	print("[SLINPUT] (c) END TO END real-click attempts:")
	for row in _attempt_rows:
		print("[SLINPUT]       %s" % String(row))
	var services := _count_services()
	print("[SLINPUT] services at end: ledgers=%d save-services=%d" % [services.x, services.y])
	if _failures.is_empty():
		print("[SLINPUT] RESULT: ALL CHECKS PASSED")
	else:
		print("[SLINPUT] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
