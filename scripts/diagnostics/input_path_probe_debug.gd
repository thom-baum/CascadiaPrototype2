class_name InputPathProbeDebug
extends Node3D
## Temporary Milestone 4 diagnostic (not production).
##
## Why this exists: attack_probe_debug.gd calls PlayerCombat.try_start()
## directly, so it proves the attack STATE MACHINE but says nothing about the
## physical input path. The roadmap records that gap honestly: light and heavy
## attacks are bound to mouse buttons and the real path was never exercised.
##
## This probe closes it by synthesising REAL InputEvents through
## Input.parse_input_event(), so each event travels the whole production chain:
##
##   injected InputEvent -> InputMap action -> CascadiaInput buffer
##     -> PlayerCombat.consume_light_attack() -> try_start() -> hitbox -> damage
##
## Nothing here calls try_start(), and nothing calls CascadiaInput.consume_*().
## The only thing this probe does is press a mouse button, exactly as a player
## would, and then measure whether an attack happened and damage landed.
##
## It also answers the open "Identifier GameActions not declared" question: if
## CascadiaInput resolves in the group and reports no missing actions, then the
## GameActions class loads at runtime and the editor entry is stale.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const SETTLE_FRAMES := 15
## Frames allowed for an attack to begin and finish before it is called stuck.
const MAX_WAIT_FRAMES := 240
## How far in front of the dummy the player stands. rotation.y = 0 faces -Z.
const STAND_OFFSET := 1.6
## Light attack damage from PlayerCombat.LIGHT_DAMAGE.
const LIGHT_DAMAGE := 15.0
## Heavy attack damage from PlayerCombat.HEAVY_DAMAGE.
const HEAVY_DAMAGE := 32.0

var _player: CharacterBody3D
var _combat: PlayerCombat
var _dummy_health: HealthComponent
var _input: CascadiaInput

var _frame := 0
var _step := 0
var _timeout := 0
var _saw_attack := false
var _before_damage := 0.0
var _before_started := 0
var _done := false
var _failures: Array = []


func _ready() -> void:
	_resolve()
	if _combat == null or _dummy_health == null or _player == null:
		_finish()
		return
	_audit_input_layer()
	_audit_bindings()
	_position_in_front_of_dummy()


## The runtime answer to "does GameActions actually load?". A CascadiaInput that
## failed to compile would carry no script and never join the group, so a null
## lookup here IS the failure mode the editor warning predicts.
func _audit_input_layer() -> void:
	_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	_expect(_input != null,
		"CascadiaInput resolved at runtime through its group (script loaded)")
	if _input == null:
		return
	_expect(_input.get_script() != null, "CascadiaInput node has its script attached")
	var missing := _input.missing_actions()
	_expect(missing.is_empty(),
		"every GameActions name is present in the InputMap (missing: %s)" % str(missing))
	print("[INPROBE] CascadiaInput mobility=%s, mouse_look=%s" % [
		_input.mobility_state_name(), str(_input.mouse_look_enabled)])


func _audit_bindings() -> void:
	var light_ok := _has_mouse_binding(GameActions.LIGHT_ATTACK, MOUSE_BUTTON_LEFT)
	var heavy_ok := _has_mouse_binding(GameActions.HEAVY_ATTACK, MOUSE_BUTTON_RIGHT)
	print("[INPROBE] light_attack bound to mouse button 1: %s" % str(light_ok))
	print("[INPROBE] heavy_attack bound to mouse button 2: %s" % str(heavy_ok))
	_expect(light_ok, "light_attack is bound to mouse button 1")
	_expect(heavy_ok, "heavy_attack is bound to mouse button 2")


func _has_mouse_binding(action: StringName, button: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _position_in_front_of_dummy() -> void:
	var dummy := _dummy_health.get_parent() as Node3D
	if dummy == null:
		_fail("dummy actor has no Node3D owner")
		return
	_player.global_position = Vector3(
		dummy.global_position.x, 0.1, dummy.global_position.z + STAND_OFFSET)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	print("[INPROBE] player placed at %s facing y=%.2f, dummy health %.1f" % [
		str(_player.global_position), _player.rotation.y, _dummy_health.current_health])


func _physics_process(_delta: float) -> void:
	if _done or _combat == null:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return

	match _step:
		0:
			_start_attack("LIGHT", MOUSE_BUTTON_LEFT, 1)
		1:
			_release(MOUSE_BUTTON_LEFT)
			_step = 2
		2:
			_watch_attack("LIGHT", LIGHT_DAMAGE, 3)
		3:
			_start_attack("HEAVY", MOUSE_BUTTON_RIGHT, 4)
		4:
			_release(MOUSE_BUTTON_RIGHT)
			_step = 5
		5:
			_watch_attack("HEAVY", HEAVY_DAMAGE, 6)
		_:
			_finish()


## Remember the pre-attack numbers, then press the real mouse button.
func _start_attack(label: String, button: int, next_step: int) -> void:
	_before_damage = _dummy_health.current_health
	_before_started = _combat.attacks_started
	_saw_attack = false
	_timeout = 0
	_press(button)
	print("[INPROBE] %s: injected mouse button %d press at frame %d" % [label, button, _frame])
	_step = next_step


## Wait for the attack to begin and then complete, then grade it. An attack that
## never begins is a failure of the input path, which is the whole point.
func _watch_attack(label: String, expected_damage: float, next_step: int) -> void:
	_timeout += 1
	if _combat.state != PlayerCombat.State.IDLE:
		_saw_attack = true
	if _saw_attack and _combat.state == PlayerCombat.State.IDLE:
		_evaluate(label, expected_damage)
		_step = next_step
		_timeout = 0
		return
	if _timeout > MAX_WAIT_FRAMES:
		_fail("%s: no attack was produced by the injected mouse button" % label)
		_finish()


func _evaluate(label: String, expected_damage: float) -> void:
	var started := _combat.attacks_started - _before_started
	var dealt := _before_damage - _dummy_health.current_health
	print("[INPROBE] %s result: attacks started=%d, dummy %.1f -> %.1f (dealt %.1f, expected %.1f)" % [
		label, started, _before_damage, _dummy_health.current_health, dealt, expected_damage])
	_expect(started == 1,
		"%s: the injected mouse button started exactly one attack (got %d)" % [label, started])
	_expect(is_equal_approx(dealt, expected_damage),
		"%s: the injected mouse button dealt %.1f damage" % [label, expected_damage])


func _press(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)


func _release(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)


func _resolve() -> void:
	# This probe is a sibling of Main, so Main is reached through the parent.
	var main := get_node_or_null("../Main")
	if main == null:
		main = get_node_or_null("Main")
	if main == null:
		_fail("main scene not found")
		return
	var base := "TestEnvironment/"
	_player = main.get_node_or_null(base + "Player") as CharacterBody3D
	_combat = main.get_node_or_null(base + "Player/Combat") as PlayerCombat
	_dummy_health = main.get_node_or_null(base + "DummyActor/Health") as HealthComponent

	_expect(_player != null, "player found")
	_expect(_combat != null, "player Combat state machine found")
	_expect(_dummy_health != null, "dummy actor Health found")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[INPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[INPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[INPROBE] --- summary ---")
	if _failures.is_empty():
		print("[INPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[INPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
