class_name MouseLookRoutingProbeDebug
extends Node3D
## TEMPORARY DIAGNOSTIC. Answers ONE question: when injected mouse motion does not turn the camera,
## does the motion fail to REACH the input layer, or does it arrive with nothing in it?
##
## WHY IT IS NEEDED. `focus_input_routing_probe_debug` reports its two look checks as FAILED with
## "yaw changed 0.0000 deg" while every other check passes (movement, attacks, dodge, stamina all
## work). The chain is:
##
##   InputEventMouseMotion -> [pipeline entry] -> _input -> [GUI] -> _unhandled_input
##     -> CascadiaInput._mouse_look_accum -> _look_accum -> ThirdPersonCamera._process -> _yaw
##
## A single end-to-end yaw reading cannot say which link failed. This probe measures each link:
##
##   1. ARRIVAL   - this probe records `relative` on the motion event as the unhandled stage
##                  delivers it. "The layer never saw it" and "the layer saw an EMPTY event" are
##                  different defects with different owners, and this is the number that separates
##                  them. The probe sees exactly the events the layer sees.
##   2. DELIVERY  - the camera rig is silenced, motion is injected, and the layer's OWN accumulators
##                  are read straight out. With nothing else consuming them, that IS what arrived.
##   3. ACCUM     - the same delivery with `Input.use_accumulated_input` both ways, because a
##                  synthetic event can be re-derived by the engine's accumulator.
##   4. DIRECT    - the layer's `_unhandled_input` is called straight with a real motion event,
##                  bypassing the engine's pipeline. This is the CONTROL: it proves whether the
##                  layer's own logic works when it is handed a non-empty event.
##   5. END-TO-END- with the rig processing again, does injected motion turn the camera?
##
## `_mouse_look_accum` is read RAW as well as through `get_look_delta()`: the accessor CONSUMES the
## delta, so reading it twice would report a false zero the second time.
##
## Nothing here is production code and it changes no gameplay value. `use_accumulated_input` and the
## rig's process mode are both restored before the run ends.

const TAG := "[MLOOK]"
const REPORT_PATH := "res://_mouse_look_report.txt"

## The injected motion, in pixel-equivalent units. Same magnitude the focus probe uses.
const MOTION := Vector2(240.0, 0.0)
const FIXED_POSITION := Vector2(640.0, 360.0)

## Named `_layer`, not `_input`: `_input` is the engine's own input callback and declaring a variable
## with that name is a parse error.
var _layer: CascadiaInput
var _rig: Node
var _lines: PackedStringArray = []
var _failures: PackedStringArray = []

## What the unhandled stage actually delivered, as this probe saw it. `_arrived_relative` is the
## decisive number: a non-empty event that the layer ignores is a layer bug, an EMPTY event is a
## delivery fact the layer can do nothing about.
var _arrived_count := 0
var _arrived_relative := Vector2.ZERO
var _arrived_position := Vector2.ZERO


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_arrived_count += 1
		_arrived_relative = motion.relative
		_arrived_position = motion.position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_arrived_count += 1
		_arrived_relative = motion.relative
		_arrived_position = motion.position


func _ready() -> void:
	_run()


func _run() -> void:
	await _frames(6)
	if not _resolve():
		_report()
		return

	_say("%s === mouse motion: delivered-but-empty, or never delivered? ===" % TAG)
	_say("%s baseline: input_active=%s mouse_mode=%d look_intent=%s ticks=%d accumulated=%s"
		% [TAG, str(_layer.is_input_active()), Input.mouse_mode,
			str(_layer.mouse_look_enabled), int(_layer.process_ticks),
			str(Input.use_accumulated_input)])

	# Nothing else may spend the delta while delivery is being measured.
	var was_processing := _rig.can_process()
	_rig.set_process(false)

	await _stage_delivery("accumulated ON (default)", FIXED_POSITION, false, null)
	await _stage_delivery("accumulated ON (default)", _center() + MOTION, false, null)

	Input.use_accumulated_input = false
	await _stage_delivery("accumulated OFF", FIXED_POSITION, false, null)
	await _stage_delivery("accumulated OFF", _center() + MOTION, false, null)
	await _stage_delivery("accumulated OFF, push_input", _center() + MOTION, true, null)
	Input.use_accumulated_input = true

	# THE CONTROL. Hand the layer a real, non-empty motion event with no pipeline in between.
	await _stage_delivery("DIRECT call into the layer (control)", _center(), false, MOTION)

	_rig.set_process(was_processing)
	await _stage_end_to_end()

	_report()


## ARRIVAL + DELIVERY for one entry point. `direct_relative` non-null means "call the layer's own
## `_unhandled_input` directly with this relative value", bypassing the engine pipeline entirely.
func _stage_delivery(label: String, position: Vector2, use_push: bool, direct_relative: Variant) -> void:
	_clear_accumulators()
	_arrived_count = 0
	_arrived_relative = Vector2.ZERO
	var before_ticks := int(_layer.process_ticks)

	if direct_relative != null:
		var direct := InputEventMouseMotion.new()
		direct.relative = direct_relative
		direct.position = position
		direct.global_position = position
		_layer.call("_unhandled_input", direct)
		await _frames(1)
	else:
		_inject(MOTION, position, use_push)
		Input.flush_buffered_events()
		await _frames(2)

	var raw_mouse: Vector2 = _layer.get("_mouse_look_accum")
	var raw_look: Vector2 = _layer.get("_look_accum")
	var via_accessor := _layer.get_look_delta()
	var advanced := int(_layer.process_ticks) - before_ticks

	_say("%s --- %s (position %s) ---" % [TAG, label, str(position)])
	_say("%s   ARRIVAL: count=%d relative=%s position=%s"
		% [TAG, _arrived_count, str(_arrived_relative), str(_arrived_position)])
	_say("%s   LAYER: raw_mouse=%s raw_look=%s accessor=%s ; frames=%d ; active=%s intent=%s"
		% [TAG, str(raw_mouse), str(raw_look), str(via_accessor), advanced,
			str(_layer.is_input_active()), str(_layer.mouse_look_enabled)])

	if _arrived_count == 0 and direct_relative == null:
		_say("%s   -> the event NEVER entered the pipeline" % TAG)
	elif _arrived_relative.length() < 0.0001 and direct_relative == null:
		_say("%s   -> the event ARRIVED EMPTY: the pipeline delivered relative=(0,0)" % TAG)
	else:
		_say("%s   -> the event arrived with real motion" % TAG)

	var received := raw_mouse.length() + raw_look.length() + via_accessor.length()
	_check(received > 0.0001,
		"DELIVERY (%s): the layer RECEIVED the injected motion (raw %s / %s, accessor %s)"
		% [label, str(raw_mouse), str(raw_look), str(via_accessor)])


## The real path, rig processing again: does injected motion turn the camera?
func _stage_end_to_end() -> void:
	_clear_accumulators()
	var before := _rig_yaw()
	_inject(MOTION, _center() + MOTION, false)
	await _frames(4)
	var turned: float = absf(_rig_yaw() - before)
	_say("%s --- END TO END: injected motion with the rig processing ---" % TAG)
	_say("%s   camera turned %.4f deg" % [TAG, turned])
	_check(turned > 0.0001,
		"END TO END: the camera TURNS for injected motion (%.4f deg)" % turned)


## Drain both accumulators so each stage starts from a known zero. `get_look_delta()` is the only
## accessor that consumes, so it is the one used here.
func _clear_accumulators() -> void:
	_layer.get_look_delta()


func _inject(relative: Vector2, position: Vector2, use_push: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = position
	event.global_position = position
	if use_push:
		get_viewport().push_input(event)
	else:
		Input.parse_input_event(event)


func _center() -> Vector2:
	return get_viewport().get_visible_rect().size * 0.5


func _resolve() -> bool:
	_layer = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	if _layer == null:
		_fail("no CascadiaInput in the tree")
		return false
	_rig = _find_camera_rig()
	if _rig == null:
		_fail("no camera rig with current_yaw_degrees in the tree")
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


func _rig_yaw() -> float:
	if _rig == null:
		return 0.0
	return float(_rig.call("current_yaw_degrees"))


# --- Reporting ----------------------------------------------------------------------

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
