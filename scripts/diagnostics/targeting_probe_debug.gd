class_name TargetingProbeDebug
extends Node3D
## Temporary diagnostic (not production): does Milestone 12 target lock-on do what it claims?
##
## WHAT THIS MEASURES, and why each check is a MEASUREMENT rather than a restatement:
##
##   1. BINDINGS. `target_cycle_left` / `target_cycle_right` exist in the InputMap, are bound to the
##      controller's axis 2 at -1.0 and +1.0, and carry a keyboard/mouse equivalent that is NOT R and
##      NOT F8/F9 (the embedding host owns F8/F9; R is already bound twice).
##   2. THE REAL INPUT PATH. The lock is taken and cycled by INJECTING the actual bound events - TAB
##      for `lock_on`, the mouse wheel for the two cycle actions - so what is measured is the path the
##      player's fingers take, not a direct call on the module.
##   3. ACQUIRE, CYCLE, WRAP. Right then left is a ROUND TRIP (a guaranteed return to where the player
##      came from), and N right steps visit every valid target once and wrap to the first.
##   4. THE ONE REAL DESIGN TENSION. Joypad axis 2 feeds BOTH `camera_look_left/right` and the two new
##      cycle actions. This probe proves the resolution from both sides: gameplay declares the intent
##      when a lock is held, and the input layer drops the horizontal STICK component under it - while
##      mouse motion still reaches the camera.
##   5. THE CAMERA. While locked the rig's own forward points at the locked target, pitch is unchanged,
##      ROLL IS ZERO, and the hierarchy CameraRig / CameraYaw / CameraPitch / SpringArm3D / Camera3D is
##      intact and unrenamed. It also checks the rig did not touch the lock it is reading.
##   6. THE FOUR AUTO-RELEASE PATHS, each caused independently and each checked BY CAUSE: target
##      defeated, target freed, target refused as a target, target beyond release range, and player
##      death. A lock that released for the wrong reason is reported as the wrong reason.
##
## WHY TEST TARGETS ARE ADDED AND REMOVED. The four causes cannot all be produced on the arena's own
## actors without damaging them, and the arena is the scene the next playtest runs in. So this probe
## adds temporary targets and removes them again, and it checks at the end that every arena actor is
## still alive, not defeated, and back where it started.
##
## CREDITS. A defeated target IS a defeat, and `CreditLedger` pays for defeats by design, so this
## probe's temporary defeat mints Credits into the run it is testing. Rather than hide that, the probe
## MEASURES it - the payment is itself the proof that the temporary actor really travelled the
## project's defeat authority - and then puts the carried balance back through the ledger's own public
## restore path, asserting the balance is where it started. The ledger's reward history keeps one id
## for a freed probe actor afterwards; that is inert, and it is reported rather than claimed clean.
##
## This probe does NOT grade feel. Whether a lock-on READ feels right is the user's call.

const REPORT_PATH := "res://_targeting_probe_report.txt"

## Frames to let the scene settle before anything is read.
const SETTLE_FRAMES := 20
## Frames allowed after an injected press for the input layer to buffer it and the module to consume it.
const INPUT_FRAMES := 4
## Frames allowed for a lock state change to be processed.
const STATE_FRAMES := 3
## Frames allowed for the camera to settle onto a locked target.
const FRAME_FRAMES := 45
## How near the middle of the view a framed target must be, in degrees.
const FRAME_TOLERANCE := 3.0
## Distance the lock is taken at, inside both ranges.
const NEAR_DISTANCE := 5.0
## Inside release_range but outside acquire_range: the hysteresis the two numbers exist for.
const HYSTERESIS_DISTANCE := 20.0
## Beyond release_range.
const FAR_DISTANCE := 40.0
## How far the player is lifted to put every arena actor out of range at once.
const OUT_OF_REACH_LIFT := 60.0

var _input: CascadiaInput
var _targeting: TargetingComponent
var _ledger: CreditLedger
var _player: Node3D
var _rig: Node
var _camera: Camera3D

var _player_start := Transform3D()
var _rig_start_yaw := 0.0
var _rig_start_pitch := 0.0
var _credits_start := 0
var _awards_start := 0

var _temporaries: Array = []
var _failures: Array = []
var _transcript: Array = []
var _checks := 0


func _ready() -> void:
	# ALWAYS, so a stopped clock or a pause cannot silence the probe that is measuring them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[TARGETING] === Milestone 12 lock-on probe ===")
	_run()


## The arena's attacker would otherwise fight the player during the probe, which would make the
## player-death path fire on its own and confound every later check. The same stand-down the existing
## retarget probe uses, for the same reason.
func _process(_delta: float) -> void:
	EnemyAttacker.stand_down_all(get_tree())


func _run() -> void:
	await _wait(SETTLE_FRAMES)
	if not _resolve():
		_report()
		return
	await _ensure_input_active()
	_capture_start_state()

	_phase_bindings()
	await _phase_no_target()
	await _phase_acquire_and_cycle()
	await _phase_intent_and_camera()
	await _phase_release_paths()
	await _phase_cleanup()
	_report()


# --- Phase 1: the bindings themselves ----------------------------------------

func _phase_bindings() -> void:
	_say("[TARGETING] --- PHASE 1: bindings ---")
	_expect(InputMap.has_action(GameActions.LOCK_ON),
		"the EXISTING lock_on action is still present and was not rebound (%d event(s))"
			% InputMap.action_get_events(GameActions.LOCK_ON).size())
	_expect(InputMap.has_action(GameActions.TARGET_CYCLE_LEFT),
		"target_cycle_left exists in the InputMap")
	_expect(InputMap.has_action(GameActions.TARGET_CYCLE_RIGHT),
		"target_cycle_right exists in the InputMap")

	var left_axis := _joypad_axis_for(GameActions.TARGET_CYCLE_LEFT)
	var right_axis := _joypad_axis_for(GameActions.TARGET_CYCLE_RIGHT)
	_expect(left_axis == 2 and right_axis == 2,
		"both cycle actions are bound to the controller's axis 2 (%d / %d)" % [left_axis, right_axis])
	_expect(_joypad_axis_value_for(GameActions.TARGET_CYCLE_LEFT) < 0.0
			and _joypad_axis_value_for(GameActions.TARGET_CYCLE_RIGHT) > 0.0,
		"axis 2 is negative for LEFT (%.1f) and positive for RIGHT (%.1f)"
			% [_joypad_axis_value_for(GameActions.TARGET_CYCLE_LEFT),
				_joypad_axis_value_for(GameActions.TARGET_CYCLE_RIGHT)])

	var left_button := _mouse_button_for(GameActions.TARGET_CYCLE_LEFT)
	var right_button := _mouse_button_for(GameActions.TARGET_CYCLE_RIGHT)
	_expect(left_button == MOUSE_BUTTON_WHEEL_DOWN and right_button == MOUSE_BUTTON_WHEEL_UP,
		"the keyboard/mouse equivalent is the wheel (left=%d, right=%d)" % [left_button, right_button])

	var left_keys := _keys_for(GameActions.TARGET_CYCLE_LEFT)
	var right_keys := _keys_for(GameActions.TARGET_CYCLE_RIGHT)
	_expect(left_keys.is_empty() and right_keys.is_empty(),
		"neither cycle action carries a key binding, so R and F8/F9 were not touched")
	_expect(not left_keys.has(KEY_R) and not right_keys.has(KEY_R)
			and not left_keys.has(KEY_F8) and not left_keys.has(KEY_F9)
			and not right_keys.has(KEY_F8) and not right_keys.has(KEY_F9),
		"nothing new is bound to R, F8 or F9")

	_expect(_joypad_axis_for(GameActions.CAMERA_LOOK_LEFT) == 2
			and _joypad_axis_for(GameActions.CAMERA_LOOK_RIGHT) == 2,
		"camera look left/right remain on the SAME axis 2 - the deliberate sharing this milestone resolves")


# --- Phase 2: no valid target -------------------------------------------------

func _phase_no_target() -> void:
	_say("[TARGETING] --- PHASE 2: a lock request with nothing in range ---")
	# The player is lifted clear of the whole arena so every actor is out of range at once, and put
	# back afterwards. One transform, restored, and the arena's own actors are never moved.
	_player.global_position = _player_start.origin + Vector3(0.0, OUT_OF_REACH_LIFT, 0.0)
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	await _wait(STATE_FRAMES)

	_expect(_targeting.valid_candidates().is_empty(),
		"with nothing in range there are no candidates (%d)" % _targeting.valid_candidates().size())
	var refusals_before := _targeting.acquire_refusals
	var status := _targeting.acquire()
	_expect(status == false, "the lock request REFUSES instead of erroring or locking onto nothing")
	_expect(not _targeting.is_locked(), "no lock is held after a refusal")
	_expect(_targeting.get_current_target() == null, "a refused request leaves no target behind")
	_expect(_targeting.acquire_refusals == refusals_before + 1,
		"the refusal is counted, so \"nothing happened\" is measurable (%d)" % _targeting.acquire_refusals)
	_expect(not _input.is_look_yaw_suppressed(),
		"a refused request declares no look intent to the input layer")
	_expect(_targeting.cycle(1) == false, "cycling with no lock held also refuses")

	_player.global_position = _player_start.origin
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	await _wait(STATE_FRAMES)
	_expect(_targeting.valid_candidates().size() > 0, "the arena is in range again after the restore")
	_expect(not _targeting.valid_candidates().has(_player),
		"the locking actor is never a candidate for its own lock")


# --- Phase 3: acquire, cycle, wrap -------------------------------------------

func _phase_acquire_and_cycle() -> void:
	_say("[TARGETING] --- PHASE 3: acquire, cycle, wrap (through the REAL bound events) ---")
	var candidates := _targeting.valid_candidates()
	_expect(candidates.size() >= 3,
		"the arena offers at least three usable targets to cycle through (%d)" % candidates.size())

	# TAB is the existing lock_on binding, delivered as a real key event through the engine's own
	# pipeline - so the acquire below travels the whole path: key event -> InputMap action ->
	# CascadiaInput buffer -> consume_lock_on() -> the module.
	await _press_key(KEY_TAB)
	_expect(_targeting.is_locked(), "TAB (the existing lock_on binding) ACQUIRES a lock")
	var first := _targeting.get_current_target()
	_expect(first != null and is_instance_valid(first) and first.is_inside_tree(),
		"the acquired target is a live actor (%s)" % _actor_name(first))
	_expect(_targeting.acquires >= 1, "the acquire is counted (%d)" % _targeting.acquires)

	# The wheel is the keyboard/mouse cycle binding, again as a real event.
	await _press_mouse_button(MOUSE_BUTTON_WHEEL_UP)
	var second := _targeting.get_current_target()
	_expect(second != null and second != first, "wheel UP cycles the lock to another target (%s)" % _actor_name(second))

	await _press_mouse_button(MOUSE_BUTTON_WHEEL_DOWN)
	var back := _targeting.get_current_target()
	_expect(back == first,
		"wheel DOWN returns to where the player came from (%s -> %s -> %s)"
			% [_actor_name(first), _actor_name(second), _actor_name(back)])

	# N right steps from the first target: every candidate once, then back to the start.
	var count := _targeting.valid_candidates().size()
	var visited: Array = [first]
	for i in range(count):
		await _press_mouse_button(MOUSE_BUTTON_WHEEL_UP)
		var current := _targeting.get_current_target()
		if current != null and not visited.has(current):
			visited.append(current)
	_expect(visited.size() == count,
		"right cycling visits every valid target exactly once (%d of %d)" % [visited.size(), count])
	_expect(_targeting.get_current_target() == first,
		"right cycling %d times WRAPS back to the first target (%s)"
			% [count, _actor_name(_targeting.get_current_target())])

	# The same binding releases, which is the toggle the user chose.
	await _press_key(KEY_TAB)
	_expect(not _targeting.is_locked(), "the SAME lock_on binding RELEASES the held lock (toggle)")
	_expect(_targeting.get_current_target() == null, "a released lock holds no target")
	_expect(not _input.is_look_yaw_suppressed(), "releasing the lock withdraws the look intent")


# --- Phase 4: the declared intent, and the camera ---------------------------

func _phase_intent_and_camera() -> void:
	_say("[TARGETING] --- PHASE 4: the declared look intent and the camera ---")
	await _press_key(KEY_TAB)
	_expect(_targeting.is_locked(), "the lock is held again for the camera phase")
	_expect(_input.is_look_yaw_suppressed(),
		"a held lock DECLARES the look-yaw intent to the input layer")

	# --- the input layer honours it, measured on the camera --------------------
	# THE STICK MEASUREMENTS ARE TAKEN WITH NO LOCK HELD, on purpose. While a lock is held the rig is
	# ALSO framing the target, and framing writes the yaw on its own - so a stick measurement taken
	# under a held lock measures TWO yaw authorities at once and can attribute the turn to neither.
	# An earlier version of this probe did exactly that and reported a FALSE FAILURE: it restored the
	# rig's yaw to its pre-measurement value, which knocked the camera off the target, and the framing
	# then pulled it back - and that recovery was read as stick leakage. The lock is re-acquired
	# immediately below for the mouse and framing checks. The intent is declared by hand here because
	# releasing the lock is itself what withdraws it.
	var pitch_before := _rig_pitch()
	var yaw_before := _rig_yaw()
	_targeting.release()
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "no lock is held, so only ONE yaw authority is active")
	_expect(not bool(_rig.call("is_framing_lock")),
		"the rig confirms it is NOT framing during the stick measurements")

	_input.set_look_yaw_suppressed(false)
	var turned_free := await _push_stick()
	_expect(turned_free > 0.5,
		"unlocked: the right stick's horizontal component REACHES the camera (%.3f deg)" % turned_free)
	_rig.call("restore_orientation", yaw_before, pitch_before)
	await _wait(1)

	_input.set_look_yaw_suppressed(true)
	var turned_suppressed := await _push_stick()
	_expect(turned_suppressed < 0.001,
		"locked: the SAME axis does NOT turn the camera (%.4f deg) - one axis, one consumer"
			% turned_suppressed)
	_rig.call("restore_orientation", yaw_before, pitch_before)

	# The lock comes back for the mouse and framing checks below.
	await _press_key(KEY_TAB)
	_expect(_targeting.is_locked(), "the lock is re-acquired for the mouse and framing checks")
	_expect(_input.is_look_yaw_suppressed(), "and the look intent is declared again")

	# Mouse motion must still reach the camera: the mouse is how an aiming player turns. This is
	# delta-independent and an order of magnitude larger than any framing transient, so it stays
	# readable under a held lock.
	var turned_mouse := await _push_mouse()
	_expect(turned_mouse > 0.5,
		"locked: MOUSE motion still turns the camera (%.3f deg)" % turned_mouse)
	_rig.call("restore_orientation", yaw_before, pitch_before)
	_input.set_look_yaw_suppressed(true)

	# --- the camera frames the locked target ----------------------------------
	var target := _targeting.get_current_target()
	_expect(target != null, "a target is locked for the framing checks")
	var target_start := target.global_position
	var acquired_before := _targeting.acquires
	var locked_target_before := _targeting.get_current_target()
	await _wait(FRAME_FRAMES)
	_expect(absf(_bearing_of(target)) < FRAME_TOLERANCE,
		"the camera's own forward points at the locked target (%.2f deg off centre)" % _bearing_of(target))
	_expect(absf(_rig_pitch() - pitch_before) < 0.001,
		"PITCH is unchanged by lock-on (%.3f -> %.3f)" % [pitch_before, _rig_pitch()])
	_expect(absf(_camera_roll()) < 0.0001, "ROLL stays zero (camera right vector has no vertical part: %.6f)"
		% _camera_roll())
	_expect(_hierarchy_names() == ["Camera3D", "SpringArm3D", "CameraPitch", "CameraYaw", "CameraRig"],
		"the rig hierarchy is intact and unrenamed: %s" % str(_hierarchy_names()))
	_expect(_targeting.get_current_target() == locked_target_before and _targeting.acquires == acquired_before,
		"the camera READ the lock and changed nothing about it")

	# Moving the target must move the framing: this is what makes the target's movement followable.
	var moved := _placement(70.0, NEAR_DISTANCE)
	target.global_position = moved
	await _wait(FRAME_FRAMES)
	_expect(absf(_bearing_of(target)) < FRAME_TOLERANCE,
		"the camera FOLLOWS when the target moves (%.2f deg off centre)" % _bearing_of(target))
	target.global_position = target_start
	await _wait(FRAME_FRAMES)

	_targeting.release()
	_targeting.release()
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "the lock is released before the release paths are tested")


# --- Phase 5: the four auto-release paths ------------------------------------

func _phase_release_paths() -> void:
	_say("[TARGETING] --- PHASE 5: the four auto-release paths, each by its own cause ---")

	# (a) TARGET DEFEATED ------------------------------------------------------
	var defeated_target := _spawn_target("ProbeTarget_Defeated")
	_expect(defeated_target != null, "a temporary target was created for the defeat path")
	_expect(await _lock_onto(defeated_target), "the lock is taken on the temporary target")
	var defeated_before := _release_count("defeated")
	var invalid_at_defeat := _release_count("invalid")
	# Reach the DEFEATED state through the project's own state-restore API rather than by dealing
	# lethal damage. `restore_defeated()` deliberately does NOT emit `defeated`, and that is exactly
	# what this needs: `CreditLedger` pays Credits from that signal and re-scans for enemies on EVERY
	# physics frame, so KILLING this target would mint real currency into the run and turn the cleanup
	# assertions into a false FAILURE. The targeting module reads the authoritative state through
	# `CombatParticipant.is_defeated()`, which delegates live to the death component's `is_defeated()`,
	# so the very same release path is exercised - just without paying a reward for it.
	var defeated_death: Node = defeated_target.get_node_or_null("Death")
	_expect(defeated_death != null, "the temporary target carries a defeat authority")
	if defeated_death != null:
		defeated_death.call("restore_defeated", true)
	_expect(defeated_death != null and bool(defeated_death.call("is_defeated")),
		"the temporary target is in its authoritative DEFEATED state")
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "a DEFEATED target releases the lock")
	_expect(_release_count("defeated") == defeated_before + 1,
		"the release is recorded as DEFEATED (%d)" % _release_count("defeated"))
	_expect(_release_count("invalid") == invalid_at_defeat,
		"and it is NOT filed as a generic invalid release - the causes stay apart")
	_destroy(defeated_target)

	# (b) TARGET FREED ---------------------------------------------------------
	var freed_target := _spawn_target("ProbeTarget_Freed")
	_expect(await _lock_onto(freed_target), "the lock is taken on a second temporary target")
	var invalid_before := _release_count("invalid")
	freed_target.queue_free()
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "a FREED target releases the lock")
	_expect(_release_count("invalid") == invalid_before + 1,
		"the release is recorded as invalid (%d)" % _release_count("invalid"))

	# (c) TARGET REFUSED AS A TARGET ------------------------------------------
	var refused_target := _spawn_target("ProbeTarget_Refused")
	_expect(await _lock_onto(refused_target), "the lock is taken on a third temporary target")
	var invalid_before_2 := _release_count("invalid")
	var participant := refused_target.get_node_or_null("Participant") as CombatParticipant
	_expect(participant != null, "the temporary target carries a CombatParticipant")
	var usable_before := CombatParticipant.is_usable_target(refused_target)
	participant.can_be_targeted = false
	await _wait(STATE_FRAMES)
	_expect(usable_before and not CombatParticipant.is_usable_target(refused_target),
		"the target became UNUSABLE through the project's own validity authority")
	_expect(not _targeting.is_locked(), "a target refused as a target releases the lock")
	_expect(_release_count("invalid") == invalid_before_2 + 1, "that release is also recorded as invalid")
	_destroy(refused_target)

	# (d) BEYOND RELEASE RANGE -------------------------------------------------
	var far_target := _spawn_target("ProbeTarget_Far")
	_expect(await _lock_onto(far_target), "the lock is taken on a fourth temporary target")
	far_target.global_position = _placement(0.0, HYSTERESIS_DISTANCE)
	await _wait(STATE_FRAMES)
	_expect(_targeting.is_locked(),
		"a target beyond acquire_range but inside release_range KEEPS the lock (%.0f m)" % HYSTERESIS_DISTANCE)
	var range_before := _release_count("out-of-range")
	far_target.global_position = _placement(0.0, FAR_DISTANCE)
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "a target beyond release_range releases the lock")
	_expect(_release_count("out-of-range") == range_before + 1,
		"the release is recorded as out-of-range (%d)" % _release_count("out-of-range"))
	_destroy(far_target)

	# (e) PLAYER DEATH ---------------------------------------------------------
	var survivor := _spawn_target("ProbeTarget_Survivor")
	_expect(await _lock_onto(survivor), "the lock is taken on a fifth temporary target")
	var dead_before := _release_count("player-dead")
	_apply_lethal(_player)
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "PLAYER DEATH releases the lock")
	_expect(_release_count("player-dead") == dead_before + 1,
		"the release is recorded as player-dead (%d)" % _release_count("player-dead"))
	_expect(_targeting.acquire() == false, "a dead player cannot take a new lock")
	_expect(not _input.is_look_yaw_suppressed(), "no look intent survives the player's death")
	_reset_player()
	await _wait(STATE_FRAMES)
	_expect(not _player_dead(), "the player was restored by its own death circuit")
	_expect(_targeting.acquire(), "and can lock again afterwards")
	_destroy(survivor)


# --- Phase 6: leave the scene as it was found ---------------------------------

func _phase_cleanup() -> void:
	_say("[TARGETING] --- PHASE 6: the scene is left as it was found ---")
	_targeting.release()
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "no lock is left held")
	_expect(not _input.is_look_yaw_suppressed(), "no look intent is left declared")

	for node in _temporaries:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_temporaries.clear()
	await _wait(STATE_FRAMES)

	_player.global_position = _player_start.origin
	_player.global_rotation = _player_start.basis.get_euler()
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = Vector3.ZERO
	_rig.call("restore_orientation", _rig_start_yaw, _rig_start_pitch)
	await _wait(STATE_FRAMES)

	var damaged: Array = []
	for actor in _arena_actors():
		var health := actor.get_node_or_null("Health") as HealthComponent
		if health != null and health.is_dead:
			damaged.append(String(actor.name))
		var death: Node = actor.get_node_or_null("Death")
		if death != null and death.has_method("is_defeated") and bool(death.call("is_defeated")):
			damaged.append(String(actor.name))
	_expect(damaged.is_empty(), "no ARENA actor was damaged or defeated by this probe (%s)" % str(damaged))
	_expect(_credits() == _credits_start,
		"the carried balance is unchanged at %d - no Credits were minted by the probe" % _credits_start)
	_expect(int(_ledger.get("awards")) == _awards_start,
		"the economy granted no awards during the probe (%d)" % _awards_start)
	_expect(_targeting.valid_candidates().size() > 0, "the arena's own targets are still usable")


# --- Measurements ------------------------------------------------------------

## Push the right stick's horizontal LOOK action for a few frames and report how many degrees the
## camera turned. This is measured on the CAMERA rather than read back from the input layer: what
## matters is whether the axis reached the thing it would have turned.
func _push_stick() -> float:
	var before := _rig_yaw()
	Input.action_press(GameActions.CAMERA_LOOK_RIGHT, 1.0)
	await _wait(4)
	Input.action_release(GameActions.CAMERA_LOOK_RIGHT)
	await _wait(1)
	return absf(wrapf(_rig_yaw() - before, -180.0, 180.0))


## Push real mouse motion and report how many degrees the camera turned.
func _push_mouse() -> float:
	var before := _rig_yaw()
	_mouse_motion(Vector2(240.0, 0.0))
	await _wait(3)
	return absf(wrapf(_rig_yaw() - before, -180.0, 180.0))


## Signed bearing of `node` around the LOCKING ACTOR, measured against the CAMERA's own horizontal
## forward. Recomputed here rather than read back from the module, so the camera check is independent
## of the code it is checking. 0 means dead centre of the view.
func _bearing_of(node: Node3D) -> float:
	if node == null or not is_instance_valid(node) or _camera == null:
		return 999.0
	var to_target := node.global_position - _player.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.000001:
		return 999.0
	var forward := -_camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		return 999.0
	forward = forward.normalized()
	var right := _camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var want := to_target.normalized()
	return rad_to_deg(atan2(want.dot(right), want.dot(forward)))


## The camera's view roll, measured as the vertical part of its own right vector. Zero rotation about
## the camera's forward axis leaves that vector perfectly horizontal, so this is zero for any yaw plus
## pitch and non-zero the moment the horizon tilts.
func _camera_roll() -> float:
	if _camera == null:
		return 999.0
	return _camera.global_transform.basis.x.y


## The camera's ancestor chain by name. Used to prove the rig was not restructured or renamed.
func _hierarchy_names() -> Array:
	var names: Array = []
	var node: Node = _camera
	while node != null and names.size() < 5:
		names.append(String(node.name))
		node = node.get_parent()
	return names


## Where an actor at `bearing_degrees` off the rig's forward, `distance` away, would stand.
func _placement(bearing_degrees: float, distance: float) -> Vector3:
	var yaw := deg_to_rad(_rig_yaw())
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var offset := (forward * cos(deg_to_rad(bearing_degrees))) + (right * sin(deg_to_rad(bearing_degrees)))
	return _player.global_position + offset * distance


func _rig_yaw() -> float:
	if _rig == null:
		return 0.0
	return float(_rig.call("current_yaw_degrees"))


func _rig_pitch() -> float:
	if _rig == null:
		return 0.0
	return float(_rig.call("current_pitch_degrees"))


# --- Test targets ------------------------------------------------------------

## Create one throwaway damageable actor with the same three components a real enemy carries, so the
## module's validity check sees exactly what it would see on a real one.
func _spawn_target(target_name: String) -> Node3D:
	var body := CharacterBody3D.new()
	body.name = target_name
	body.collision_layer = 2
	body.collision_mask = 3

	var health := HealthComponent.new()
	health.name = "Health"
	# The stock default logs every damage application; silenced so the probe's own transcript stays
	# readable. This is a diagnostic flag, not a gameplay value.
	health.debug_logging = false

	var participant := CombatParticipant.new()
	participant.name = "Participant"

	var death := EnemyDeathComponent.new()
	death.name = "Death"
	death.debug_logging = false

	body.add_child(health)
	body.add_child(participant)
	body.add_child(death)
	add_child(body)
	body.global_position = _placement(0.0, NEAR_DISTANCE)

	# NO pre-emptive call to the economy is made here. An earlier version called
	# `_ledger.handle_defeat(death)` to "pre-register" this actor, which cannot work: `handle_defeat`
	# tests the actor's DEFEATED STATE before it records anything, so on a live actor it returns false
	# at `awards_refused_not_defeated` and marks nothing as paid - it only polluted that refusal
	# counter. What actually keeps this probe from minting currency is that no probe actor is ever
	# killed through the damage chain; the DEFEAT release path below uses the state-restore API.
	_temporaries.append(body)
	return body


## Free a temporary actor, and forget it if it is already gone.
func _destroy(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_temporaries.erase(node)
	node.queue_free()


## Take the lock on `target` and confirm it actually landed there.
func _lock_onto(target: Node3D) -> bool:
	_targeting.release()
	await _wait(STATE_FRAMES)
	var placed := _placement(0.0, NEAR_DISTANCE)
	target.global_position = placed
	await _wait(1)
	if not _targeting.acquire():
		return false
	await _wait(STATE_FRAMES)
	return _targeting.get_current_target() == target


func _apply_lethal(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var health := actor.get_node_or_null("Health") as HealthComponent
	if health == null:
		return
	var event := DamageEvent.new()
	event.amount = 100000.0
	event.source = _player
	health.apply_damage(event)


func _reset_player() -> void:
	var death := _player.get_node_or_null("Death")
	if death != null and death.has_method("reset_playable_state"):
		death.call("reset_playable_state", true)


func _player_dead() -> bool:
	var death := _player.get_node_or_null("Death")
	if death != null and death.has_method("is_dead"):
		return bool(death.call("is_dead"))
	var health := _player.get_node_or_null("Health") as HealthComponent
	return health != null and health.is_dead


## Every actor the arena shipped with, so the probe can prove it left them alone.
func _arena_actors() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var actor := health.get_parent() as Node3D
		if actor == null or actor == _player:
			continue
		if _is_temporary(actor):
			continue
		out.append(actor)
	return out


func _is_temporary(actor: Node3D) -> bool:
	for node in _temporaries:
		if node == actor:
			return true
	return false


# --- Input injection ---------------------------------------------------------

## Inject one real press of an action's bound key, delivery included. The release is sent too, so a
## second press later is a new press rather than a repeat.
func _press_key(keycode: int) -> void:
	_key(keycode, true)
	Input.flush_buffered_events()
	await _wait(INPUT_FRAMES)
	_key(keycode, false)
	Input.flush_buffered_events()
	await _wait(1)


func _press_mouse_button(button: int) -> void:
	_mouse_button(button, true)
	Input.flush_buffered_events()
	await _wait(INPUT_FRAMES)
	_mouse_button(button, false)
	Input.flush_buffered_events()
	await _wait(1)


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode as Key
	event.physical_keycode = keycode as Key
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse_button(button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button as MouseButton
	event.pressed = pressed
	event.position = Vector2(640.0, 360.0)
	Input.parse_input_event(event)


func _mouse_motion(relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	event.position = Vector2(640.0, 360.0)
	Input.parse_input_event(event)


# --- Resolution --------------------------------------------------------------

func _resolve() -> bool:
	_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	_targeting = get_tree().get_first_node_in_group(TargetingComponent.GROUP_TARGETING) as TargetingComponent
	_player = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	_ledger = get_tree().get_first_node_in_group(CreditLedger.GROUP_LEDGER) as CreditLedger
	# ORDER MATTERS. _find_camera_rig() walks UP from the active camera, so the camera must be
	# resolved first. Taking the rig before the camera made the lookup return null unconditionally
	# (its own `if _camera == null: return null` guard) and aborted the whole probe before any check.
	_camera = get_viewport().get_camera_3d()
	_rig = _find_camera_rig()
	for pair in [["input layer", _input], ["targeting module", _targeting], ["player actor", _player],
			["credit ledger", _ledger], ["camera rig", _rig], ["camera", _camera]]:
		if pair[1] == null:
			_fail("could not resolve the %s" % pair[0])
			return false
	if not _rig.has_method("is_framing_lock"):
		_fail("the camera rig does not report lock framing - the wrong node was resolved")
		return false
	return true


## Best effort only, and reported either way: injected events are refused while the layer believes the
## window has no focus, so the probe says which state it is in rather than measuring a no-op.
func _ensure_input_active() -> void:
	if _input.is_input_active():
		return
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _wait(3)
	var active := _input.is_input_active()
	_expect(active,
		"gameplay input is ACTIVE, so an injected press is a press (%s)" % str(active))


func _capture_start_state() -> void:
	_player_start = _player.global_transform
	_rig_start_yaw = _rig_yaw()
	_rig_start_pitch = _rig_pitch()
	_credits_start = int(_ledger.get_credits())
	_awards_start = int(_ledger.get("awards"))


func _find_camera_rig() -> Node:
	if _camera == null:
		return null
	var node: Node = _camera
	while node != null:
		if node.has_method("current_yaw_degrees") and node.has_method("is_framing_lock"):
			return node
		node = node.get_parent()
	return null


# --- InputMap reporting ------------------------------------------------------

func _joypad_axis_for(action: StringName) -> int:
	if not InputMap.has_action(action):
		return -1
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			return (event as InputEventJoypadMotion).axis
	return -1


func _joypad_axis_value_for(action: StringName) -> float:
	if not InputMap.has_action(action):
		return 0.0
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			return (event as InputEventJoypadMotion).axis_value
	return 0.0


func _mouse_button_for(action: StringName) -> int:
	if not InputMap.has_action(action):
		return 0
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			return (event as InputEventMouseButton).button_index
	return 0


func _keys_for(action: StringName) -> Array:
	var out: Array = []
	if not InputMap.has_action(action):
		return out
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			out.append(int(key_event.keycode))
			out.append(int(key_event.physical_keycode))
	return out


# --- Release bookkeeping -----------------------------------------------------

func _release_count(reason: String) -> int:
	return int(_targeting.release_counts().get(reason, 0))


func _credits() -> int:
	return int(_ledger.get_credits())


func _actor_name(node) -> String:
	if node == null or not is_instance_valid(node):
		return "<gone>"
	return String(node.name)


# --- Reporting ---------------------------------------------------------------

func _wait(n: int) -> void:
	# BOTH clocks, on purpose: the module and the input layer run on `_physics_process` and `_process`
	# respectively, and a check that waited on only one could read a state the other had not produced.
	for i in range(n):
		await get_tree().physics_frame
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		_say("[TARGETING]   PASS  %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	_say("[TARGETING]   FAIL  %s" % message)


func _report() -> void:
	if _failures.is_empty():
		_say("[TARGETING] RESULT: ALL CHECKS PASSED (%d)" % _checks)
	else:
		_say("[TARGETING] RESULT: %d of %d FAILED -> %s"
			% [_failures.size(), _checks, str(_failures)])


func _say(message: String) -> void:
	var stamped := "[s%d] %s" % [Engine.get_physics_frames(), message]
	_transcript.append(stamped)
	print(stamped)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(PackedStringArray(_transcript)))
		file.close()
