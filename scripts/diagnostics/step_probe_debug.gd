class_name StepProbeDebug
extends Node
## Temporary Milestone 1 movement probe. NOT shipping code.
##
## Drives the real PlayerController through each course station by holding a
## semantic input action, and reports measured position, floor state and the
## maximum per-frame horizontal displacement.
##
## maxFrameStep is the launch detector. Walking speed is 4.2 m/s, so a normal
## frame advances ~0.07 m. A step-up correction advances ~0.48 m, so a single
## 0.48 m frame is a legitimate step and many of them in a row is a launch.
## The over-threshold frame count is what separates the two.
##
## The ramp is probed from BOTH ends in separate phases, because which end is
## walkable is a question about the geometry and is not worth guessing.

@export var player_path: NodePath
@export var warmup_frames := 30

## Threshold above which a single frame's horizontal travel counts as a
## correction rather than walking.
const STEP_JUMP := 0.15

const PHASES := [
	{
		"label": "A 14cm step north",
		"from": Vector3(-7.0, 0.3, 11.0),
		"action": &"move_forward",
		"frames": 100,
	},
	{
		"label": "B 28cm step north",
		"from": Vector3(-7.0, 0.3, 2.4),
		"action": &"move_forward",
		"frames": 110,
	},
	{
		"label": "C 42cm step north",
		"from": Vector3(-7.0, 0.3, -5.8),
		"action": &"move_forward",
		"frames": 130,
	},
	{
		"label": "D 1m ledge north",
		"from": Vector3(7.0, 0.3, -3.0),
		"action": &"move_forward",
		"frames": 120,
	},
	{
		"label": "E ramp from SOUTH driving north",
		"from": Vector3(7.0, 0.3, 13.0),
		"action": &"move_forward",
		"frames": 140,
	},
	{
		"label": "F ramp from NORTH driving south",
		"from": Vector3(7.0, 0.3, 2.0),
		"action": &"move_backward",
		"frames": 140,
	},
]

var _player: PlayerController
var _frame := 0
var _phase := -1
var _done := false
var _prev := Vector3.ZERO
var _max_step := 0.0
var _max_step_frame := 0
var _jump_frames := 0
var _samples: Array = []


func _ready() -> void:
	_player = get_node_or_null(player_path) as PlayerController
	if _player == null:
		push_error("StepProbeDebug: no PlayerController at %s" % str(player_path))
		set_physics_process(false)
		return
	print("[PROBE] armed; %d phases after %d warmup frames" % [PHASES.size(), warmup_frames])


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1

	if _phase < 0:
		if _frame >= warmup_frames:
			_enter_phase(0)
		return

	Input.action_press(PHASES[_phase]["action"])

	var position: Vector3 = _player.global_position
	var step := Vector2(position.x - _prev.x, position.z - _prev.z).length()
	if step > _max_step:
		_max_step = step
		_max_step_frame = _frame
	if step > STEP_JUMP:
		_jump_frames += 1
	_prev = position

	if _frame % 25 == 0:
		_samples.append("f%d z%.2f y%.3f" % [_frame, position.z, position.y])

	if _frame < int(PHASES[_phase]["frames"]):
		return

	_report()
	Input.action_release(PHASES[_phase]["action"])
	if _phase + 1 >= PHASES.size():
		print("[PROBE] ALL PHASES DONE")
		_done = true
		set_physics_process(false)
	else:
		_enter_phase(_phase + 1)


func _enter_phase(index: int) -> void:
	_phase = index
	_frame = 0
	_max_step = 0.0
	_max_step_frame = 0
	_jump_frames = 0
	_samples.clear()
	var start: Vector3 = PHASES[index]["from"]
	_player.global_position = start
	_player.velocity = Vector3.ZERO
	_prev = start
	print("[PROBE] --- %s from %s ---" % [PHASES[index]["label"], str(start)])


func _report() -> void:
	var position: Vector3 = _player.global_position
	var verdict := "smooth"
	if _jump_frames == 1:
		verdict = "one step-up frame (expected on a step)"
	elif _jump_frames > 2:
		verdict = "REPEATED JUMPS - LAUNCH"
	print("[PROBE] %s || final=(%.2f,%.3f,%.2f) floor=%s || maxStep=%.4f@f%d jumpFrames=%d [%s] || %s" % [
		PHASES[_phase]["label"],
		position.x, position.y, position.z,
		str(_player.is_on_floor()),
		_max_step, _max_step_frame, _jump_frames, verdict,
		", ".join(_samples),
	])
