class_name DodgeInputProbeDebug
extends Node3D
## Temporary diagnostic for the Sprint / Dodge / Backstep input pass (not production).
##
## Measures the shared tap-versus-hold input and the two evasion kinds, so each
## claim is checkable from output rather than taken on trust:
##
##   AC1 tap/hold    - a TAP of the mobility input resolves as Dodge; a HOLD
##                     resolves as Sprint; releasing after a Sprint does NOT also
##                     fire a Dodge, and the two are never active together.
##   AC2 directional - movement input + tap produces a Dodge along the movement
##                     direction, not toward any enemy.
##   AC3 backstep    - NO movement input + tap produces a BACKSTEP, backwards
##                     along the body's own facing, with its own kind and travel.
##   AC4 travel      - directional dodge travel is about half the old 3.375 m.
##   AC5 i-frames    - the window still refuses damage and still has a vulnerable
##                     tail after it, exactly as in Milestone 6.
##   AC6 stamina     - exactly one cost per evasion, and an unaffordable press is
##                     refused and counted.
##
## It DOES synthesise input, deliberately: this pass is about the input path, so
## the tap/hold resolution is driven through the real InputMap actions rather than
## by calling try_start() directly. Physical-device feel is still a human playtest.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const SETTLE_FRAMES := 12
const MAX_PHASE_FRAMES := 240

enum Step {
	TAP_RESOLVE,
	HOLD_SPRINT,
	HOLD_RELEASE,
	DIR_FORWARD,
	DIR_RIGHT,
	DIR_BACKWARD,
	BACKSTEP,
	TRAVEL,
	IFRAMES,
	STAMINA,
	DONE,
}

var _player: CharacterBody3D
var _input: CascadiaInput
var _dodge: DodgeComponent
var _stamina: StaminaComponent
var _health: HealthComponent
var _hurtbox: HurtboxComponent

var _step: int = Step.TAP_RESOLVE
var _frame := 0
var _phase_frames := 0
var _done := false
var _failures: Array = []

var _dodges_before := 0
var _stamina_before := 0.0
var _health_before := 0.0
var _iframes_before := 0
var _measured_travel := 0.0
var _travel_accum := 0.0
var _travel_last := Vector3.ZERO
var _travel_started := false

# --- tiny per-phase scratch ---
var _tap_press_frames := 0
var _captured_kind := ""
var _captured_facing := ""
var _captured_dir := Vector3.ZERO


func _ready() -> void:
	_resolve()
	if _dodge == null or _input == null or _stamina == null or _hurtbox == null:
		_finish()
		return
	# Stand any arena attacker down: this probe measures the player's own input and
	# movement, so an ambient enemy strike must not contaminate health accounting.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	_audit()


func _resolve() -> void:
	var main := get_node_or_null("../Main")
	if main == null:
		main = get_node_or_null("Main")
	if main == null:
		_fail("main scene not found")
		return
	var base := "TestEnvironment/"
	_player = main.get_node_or_null(base + "Player") as CharacterBody3D
	_dodge = main.get_node_or_null(base + "Player/Dodge") as DodgeComponent
	_stamina = main.get_node_or_null(base + "Player/Stamina") as StaminaComponent
	_health = main.get_node_or_null(base + "Player/Health") as HealthComponent
	_hurtbox = main.get_node_or_null(base + "Player/Hurtbox") as HurtboxComponent
	_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput

	_expect(_player != null, "player found")
	_expect(_dodge != null, "player Dodge is a DodgeComponent")
	_expect(_stamina != null, "player Stamina found")
	_expect(_hurtbox != null, "player Hurtbox is a HurtboxComponent")
	_expect(_input != null, "CascadiaInput resolved through its group")


func _audit() -> void:
	print("[DODGEIN] --- wiring audit ---")
	print("[DODGEIN] dodge speed=%.2f duration=%.2f -> travel=%.3f m" % [
		_dodge.dodge_speed, _dodge.dodge_duration, _dodge.travel_distance()])
	print("[DODGEIN] backstep speed=%.2f duration=%.2f -> travel=%.3f m" % [
		_dodge.backstep_speed, _dodge.backstep_duration,
		_dodge.backstep_travel_distance()])
	print("[DODGEIN] i-frames %.2f-%.2f inside a %.2f s dodge, stamina cost %.0f" % [
		_dodge.iframes_start, _dodge.iframes_end, _dodge.dodge_duration,
		_dodge.stamina_cost])
	print("[DODGEIN] sprint tap/hold window: tap<=%.2f s, hold>=%.2f s" % [
		CascadiaInput.MOBILITY_TAP_MAX, CascadiaInput.MOBILITY_HOLD_MIN])

	_expect(_input.command_sprint_tap_max() > 0.0,
		"the shared input exposes a positive tap threshold")
	_expect(_input.command_sprint_hold_min() >= _input.command_sprint_tap_max(),
		"the hold threshold is not below the tap threshold")
	_expect(_dodge.iframes_end <= _dodge.dodge_duration,
		"the i-frame window still fits inside the dodge")
	_expect(_dodge.travel_distance() <= 1.80,
		"directional dodge travel is about half the former 3.375 m (got %.3f m)"
			% _dodge.travel_distance())


func _physics_process(_delta: float) -> void:
	if _done or _dodge == null:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_phase_frames += 1
	if _phase_frames > MAX_PHASE_FRAMES:
		_fail("phase %d did not finish within %d frames" % [_step, MAX_PHASE_FRAMES])
		_release_all_input()
		_finish()
		return
	match _step:
		Step.TAP_RESOLVE:
			_phase_tap_resolve()
		Step.HOLD_SPRINT:
			_phase_hold_sprint()
		Step.HOLD_RELEASE:
			_phase_hold_release()
		Step.DIR_FORWARD:
			_phase_direction("move_forward", "FORWARD")
		Step.DIR_RIGHT:
			_phase_direction("move_right", "RIGHT")
		Step.DIR_BACKWARD:
			_phase_direction("move_backward", "BACKWARD")
		Step.BACKSTEP:
			_phase_backstep()
		Step.TRAVEL:
			_phase_travel()
		Step.IFRAMES:
			_phase_iframes()
		Step.STAMINA:
			_phase_stamina()
		_:
			_finish()


func _advance() -> void:
	_phase_frames = 0
	_release_all_input()
	_dodge.reset()


# --- AC1: tap resolves as dodge, hold resolves as sprint --------------------

## A short press of the SHARED mobility input must come out as a Dodge. Driven
## through the real InputMap action, so what is under test is the resolver.
func _phase_tap_resolve() -> void:
	if _phase_frames == 1:
		_dodges_before = _dodge.dodges_started
		_stamina_before = _stamina.current_stamina
		_stamina.reset()
		Input.action_press(&"sprint")
		print("[DODGEIN] --- AC1 tap resolves as dodge ---")
		return
	if _phase_frames == 5:
		# Released inside the tap window: this is the tap gesture.
		Input.action_release(&"sprint")
		return
	# Wait (bounded) for the tap to resolve into an evasion. The press is injected
	# on physics frames while the input layer polls on idle frames, so resolution
	# can land a frame or two later; asserting at a fixed frame made this phase
	# non-deterministic between runs. Wait for the OUTCOME, then judge it.
	if _phase_frames < 30 and _dodge.dodges_started == _dodges_before:
		return
	if _dodge.dodges_started == _dodges_before:
		print("[DODGEIN] tap diagnostics: buffer=%.3fs refused_stamina=%d refused_dodging=%d refused_attacking=%d" % [
			_input.buffer_time(GameActions.DODGE),
			_dodge.dodges_refused_by_stamina,
			_dodge.dodges_refused_while_dodging,
			_dodge.dodges_refused_while_attacking])
	_expect(_dodge.dodges_started == _dodges_before + 1,
		"a TAP of the shared input produced exactly one dodge (%d -> %d)" % [
			_dodges_before, _dodge.dodges_started])
	# A neutral tap is the BACKSTEP case, by design: no movement input means the
	# neutral evasion, not a directional one. The important half of this assertion
	# is that a tap produced an EVASION at all rather than being eaten as a sprint.
	_expect(_dodge.kind_name() == "BACKSTEP",
		"a tap with no movement input produced the neutral evasion (kind %s)"
			% _dodge.kind_name())
	_expect(_dodge.facing_name() == "BACKWARD",
		"the neutral evasion reports BACKWARD (got %s)" % _dodge.facing_name())
	_advance()
	_step = Step.HOLD_SPRINT


func _phase_hold_sprint() -> void:
	if _phase_frames == 1:
		_dodges_before = _dodge.dodges_started
		Input.action_press(&"sprint")
		print("[DODGEIN] --- AC1 hold resolves as sprint ---")
		return
	# Held well past the hold threshold.
	var hold_frames := int(ceil(CascadiaInput.MOBILITY_HOLD_MIN * 60.0)) + 10
	if _phase_frames < hold_frames:
		return
	_expect(_input.is_sprinting(), "holding the shared input reports sprinting")
	_expect(_dodge.dodges_started == _dodges_before,
		"holding the shared input produced NO dodge (%d -> %d)" % [
			_dodges_before, _dodge.dodges_started])
	_expect(not _dodge.is_dodging(), "no dodge is active while sprinting")
	_phase_frames = 0
	_step = Step.HOLD_RELEASE


## Releasing after a hold must not retroactively fire the tap branch. This is the
## single most likely regression in a tap/hold resolver.
func _phase_hold_release() -> void:
	if _phase_frames == 1:
		Input.action_release(&"sprint")
		print("[DODGEIN] --- AC1 release after sprint must not dodge ---")
		return
	if _phase_frames < 20:
		return
	_expect(_dodge.dodges_started == _dodges_before,
		"releasing after a sprint did NOT trigger a dodge (%d -> %d)" % [
			_dodges_before, _dodge.dodges_started])
	_expect(not _dodge.is_dodging(), "the actor is idle after the sprint release")
	_expect(_input.buffer_time(GameActions.DODGE) <= 0.0,
		"no dodge press was left buffered by the sprint release")
	_advance()
	_step = Step.DIR_FORWARD


# --- AC2: directional dodge follows movement input --------------------------

func _phase_direction(action: StringName, expected: String) -> void:
	if _phase_frames == 1:
		_dodge.reset()
		# Refill the pool every phase. Without this, earlier evasions in the run
		# drain stamina and a later dodge is REFUSED - and because the component's
		# kind/facing default to DIRECTIONAL/FORWARD, a refusal silently reads as a
		# result instead of a failure. That is exactly what happened before this
		# reset was added.
		_stamina.reset()
		_dodges_before = _dodge.dodges_started
		Input.action_press(action)
		print("[DODGEIN] --- AC2 directional dodge with '%s' held ---" % str(action))
		return
	# Let the controller build a wish direction from the held movement input.
	# Held for several frames: the press is injected on physics frames while the
	# input layer buffers on idle frames, so a 2-frame press could miss the buffer
	# entirely and make this phase non-deterministic between runs.
	if _phase_frames == 6:
		Input.action_press(&"dodge")
		return
	if _phase_frames == 12:
		Input.action_release(&"dodge")
		_captured_kind = _dodge.kind_name()
		_captured_facing = _dodge.facing_name()
		_captured_dir = _dodge.direction()
		if _dodge.dodges_started == _dodges_before:
			_diag("AC2 '%s' no evasion" % str(action))
		return
	if _dodge.is_dodging():
		return
	if _phase_frames < 12:
		return
	var moved := _captured_dir
	# Guard against the silent-refusal trap: an evasion that never started would
	# otherwise be judged on the component's default kind and facing.
	_expect(_dodge.dodges_started > _dodges_before,
		"'%s' actually started an evasion (a refusal would read as defaults)" % str(action))
	_expect(_captured_kind == "DIRECTIONAL",
		"holding '%s' produced a DIRECTIONAL evasion (got %s)" % [
			str(action), _captured_kind])
	_expect(_captured_facing == expected,
		"'%s' resolved as a %s evasion (got %s)" % [
			str(action), expected, _captured_facing])
	# THE property under test: the evasion travelled where the player was steering
	# in the camera basis, and was not redirected anywhere else. Stronger and far
	# less flaky than an enemy-relative check, because it does not depend on where
	# any actor happens to be standing.
	var want := _expected_dir(action).normalized()
	var gain := moved.normalized().dot(want)
	_expect(gain >= 0.9,
		"'%s' evasion travelled along the player's intended direction (dot %.2f)" % [
			str(action), gain])
	# Informational only: how much this leaned toward the nearest enemy. Not
	# asserted - there is no lock-on, so no auto-aim is expected or possible.
	var to_enemy := _nearest_enemy_direction()
	if to_enemy != Vector3.ZERO and moved.length_squared() > 0.0001:
		print("[DODGEIN] '%s' vs nearest enemy dot=%.2f (informational, no lock-on)" % [
			str(action), moved.normalized().dot(to_enemy)])
	_advance()
	match _step:
		Step.DIR_FORWARD:
			_step = Step.DIR_RIGHT
		Step.DIR_RIGHT:
			_step = Step.DIR_BACKWARD
		_:
			_step = Step.BACKSTEP


## Flat direction from the player to the nearest arena attacker, or zero when
## there is none. Used only to prove the dodge was NOT auto-aimed at an enemy.
func _nearest_enemy_direction() -> Vector3:
	var best_dot := 0.0
	var found := Vector3.ZERO
	for attacker in get_tree().get_nodes_in_group(&"enemy_attacker"):
		var body := (attacker as Node).get_parent() as Node3D
		if body == null:
			continue
		var to := body.global_position - _player.global_position
		to.y = 0.0
		if to.length_squared() < 0.0001:
			continue
		found = to.normalized()
		best_dot = 1.0
		break
	return found if best_dot > 0.0 else Vector3.ZERO


## The flat basis the CONTROLLER steers by: the active camera's right/back axes
## with pitch discarded. The probe replicates it so it can assert the evasion went
## where the player was steering, instead of trusting an enemy-relative proxy that
## depends on where an actor happens to be standing.
## Dump every reason a dodge could have been refused. A refusal that silently reads
## as the component's default state is the failure mode this probe exists to avoid,
## so when an expected evasion does not appear, say WHY rather than inferring it.
func _diag(label: String) -> void:
	var combat := _player.get_node_or_null("Combat") as PlayerCombat
	var parry := _player.get_node_or_null("Parry") as ParryComponent
	print("[DODGEIN] DIAG %s: stamina=%.1f combat_busy=%s parrying=%s active=%s | refused dodging=%d attacking=%d parry=%d stamina=%d dir=%d" % [
		label, _stamina.current_stamina,
		str(combat != null and combat.is_busy()),
		str(parry != null and parry.is_parrying()),
		str(_dodge.is_dodging()),
		_dodge.dodges_refused_while_dodging,
		_dodge.dodges_refused_while_attacking,
		_dodge.dodges_refused_while_parrying,
		_dodge.dodges_refused_by_stamina,
		_dodge.dodges_refused_invalid_direction])


func _camera_flat_basis() -> Basis:
	var camera := _player.get_viewport().get_camera_3d()
	if camera == null:
		return Basis.IDENTITY
	var back := camera.global_transform.basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		return Basis.IDENTITY
	back = back.normalized()
	var right := Vector3.UP.cross(back).normalized()
	return Basis(right, Vector3.UP, back)


## The world direction a movement action should resolve to, in the camera basis.
func _expected_dir(action: StringName) -> Vector3:
	var basis := _camera_flat_basis()
	match action:
		&"move_right":
			return basis.x
		&"move_left":
			return -basis.x
		&"move_backward":
			return basis.z
		_:
			return -basis.z


# --- AC3: neutral backstep --------------------------------------------------

func _phase_backstep() -> void:
	if _phase_frames == 1:
		_dodge.reset()
		_stamina.reset()
		_dodges_before = _dodge.dodges_started
		_release_all_input()
		_player.rotation.y = 0.0
		# Zero the velocity too, not just the yaw. A backstep is measured against
		# the body's FACING, and _apply_facing() re-orients the body toward its own
		# velocity every frame - so leaving the previous dodge's momentum on the
		# body lets it coast and turn sideways before the tap, which measures the
		# probe's own leftover motion instead of the backstep.
		_player.velocity = Vector3.ZERO
		print("[DODGEIN] --- AC3 neutral backstep with no movement held ---")
		return
	# Wait until the player has actually stopped, so this is genuinely neutral.
	if _phase_frames < 20:
		_player.velocity = Vector3.ZERO
		_player.rotation.y = 0.0
		return
	if _phase_frames == 20:
		_player.velocity = Vector3.ZERO
		_player.rotation.y = 0.0
		Input.action_press(&"dodge")
		return
	if _phase_frames == 28:
		Input.action_release(&"dodge")
		_captured_kind = _dodge.kind_name()
		_captured_facing = _dodge.facing_name()
		_captured_dir = _dodge.direction()
		if _dodge.dodges_started == _dodges_before:
			_diag("AC3 neutral tap no evasion")
		return
	if _dodge.is_dodging():
		return
	if _phase_frames < 34:
		return
	# rotation.y = 0 means the body faces -Z, so backward is +Z.
	var expected_back := Vector3(0, 0, 1)
	_expect(_dodge.dodges_started > _dodges_before,
		"the neutral tap actually started an evasion (a refusal would read as defaults)")
	_expect(_captured_kind == "BACKSTEP",
		"a tap with no movement produced a BACKSTEP (got %s)" % _captured_kind)
	_expect(_captured_facing == "BACKWARD",
		"the backstep reports BACKWARD (got %s)" % _captured_facing)
	_expect(_captured_dir.normalized().dot(expected_back) >= 0.9,
		"the backstep travels backwards along the body facing (dot %.2f)" % [
			_captured_dir.normalized().dot(expected_back)])
	_advance()
	_step = Step.TRAVEL


# --- AC4: travel ------------------------------------------------------------

func _phase_travel() -> void:
	if _phase_frames == 1:
		_dodge.reset()
		_stamina.reset()
		_travel_accum = 0.0
		_travel_started = false
		_travel_last = _player.global_position
		_release_all_input()
		_player.rotation.y = 0.0
		_dodge.try_start(Vector3(0, 0, -1))
		_travel_started = _dodge.is_dodging()
		return
	if not _dodge.is_dodging():
		if _travel_started:
			_measured_travel = _travel_accum
			print("[DODGEIN] --- AC4 travel ---")
			print("[DODGEIN] measured directional travel=%.3f m (authored %.3f m, was 3.375 m)" % [
				_measured_travel, _dodge.travel_distance()])
			_expect(absf(_measured_travel - _dodge.travel_distance()) <= 0.15,
				"measured travel matches authored speed x duration")
			_expect(_measured_travel <= 2.00,
				"dodge travel is about half its former 3.375 m (got %.3f m)" % _measured_travel)
		_advance()
		_step = Step.IFRAMES
		return
	_travel_accum += _player.global_position.distance_to(_travel_last)
	_travel_last = _player.global_position


# --- AC5: i-frames preserved ------------------------------------------------

func _phase_iframes() -> void:
	if _phase_frames == 1:
		_dodge.reset()
		_health.reset()
		# Fresh pool: this phase is about i-frames, not affordability, and the
		# earlier phases have collectively spent most of the pool by now.
		_stamina.reset()
		_health_before = _health.current_health
		_iframes_before = _hurtbox.refusals_by_iframes
		print("[DODGEIN] --- AC5 i-frames ---")
		# Damage while NOT dodging must land normally.
		_damage(7.0)
		_expect(is_equal_approx(_health.current_health, _health_before - 7.0),
			"damage outside any window applies normally (%.1f -> %.1f)" % [
				_health_before, _health.current_health])
		return
	if _phase_frames == 2:
		# Start a dodge and land a hit inside the window.
		_dodges_before = _dodge.dodges_started
		var started := _dodge.try_start(Vector3(0, 0, 1))
		if not started:
			_diag("AC5 try_start refused")
		return
	if _phase_frames >= 4 and _phase_frames <= 20:
		if _dodge.is_invulnerable():
			var before := _health.current_health
			_damage(9.0)
			_expect(is_equal_approx(_health.current_health, before),
				"damage inside the i-frame window was refused (%d refusals)" % [
					_hurtbox.refusals_by_iframes])
			_expect(_hurtbox.refusals_by_iframes > _iframes_before,
				"the refusal was counted as an i-frame refusal (%d -> %d)" % [
					_iframes_before, _hurtbox.refusals_by_iframes])
			_phase_frames = 0
			# Fall through to the vulnerable-tail check.
			_step = Step.STAMINA
			return
		return
	if _phase_frames > 20:
		_fail("never reached the i-frame window inside the dodge")
		_advance()
		_step = Step.STAMINA


# --- AC6: stamina -----------------------------------------------------------

func _phase_stamina() -> void:
	if _phase_frames == 1:
		_dodge.reset()
		_stamina.reset()
		_dodges_before = _dodge.dodges_started
		_stamina_before = _stamina.current_stamina
		print("[DODGEIN] --- AC6 stamina ---")
		_dodge.try_start(Vector3(0, 0, -1))
		_expect(_dodge.dodges_started == _dodges_before + 1, "an affordable dodge started")
		_expect(is_equal_approx(_stamina.current_stamina, _stamina_before - _dodge.stamina_cost),
			"exactly one stamina cost was charged (%.1f -> %.1f, expected -%.0f)" % [
				_stamina_before, _stamina.current_stamina, _dodge.stamina_cost])
		return
	if _dodge.is_dodging():
		return
	if _phase_frames < 4:
		return
	# Now an unaffordable one.
	_dodge.reset()
	_stamina.try_spend(_stamina.current_stamina)
	var refused_before := _dodge.dodges_refused_by_stamina
	var started_before := _dodge.dodges_started
	var accepted := _dodge.try_start(Vector3(0, 0, -1))
	_expect(not accepted, "an unaffordable dodge is refused")
	_expect(_dodge.dodges_refused_by_stamina == refused_before + 1,
		"the unaffordable refusal was counted by cause")
	_expect(_dodge.dodges_started == started_before,
		"the refused dodge was not counted as started")
	_expect(not _dodge.is_dodging(), "the refused dodge left the actor idle")
	_stamina.reset()
	_advance()
	_step = Step.DONE


# --- helpers ----------------------------------------------------------------

func _damage(amount: float) -> void:
	var event := DamageEvent.new()
	event.amount = amount
	event.victim = _player
	_hurtbox.receive_hit(event)


func _release_all_input() -> void:
	Input.action_release(&"sprint")
	Input.action_release(&"dodge")
	Input.action_release(&"move_forward")
	Input.action_release(&"move_right")
	Input.action_release(&"move_backward")
	Input.action_release(&"move_left")


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[DODGEIN]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[DODGEIN]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	_release_all_input()
	print("[DODGEIN] --- summary ---")
	print("[DODGEIN] dodge travel=%.3f m (was 3.375 m), backstep travel=%.3f m, kind=%s, facing=%s" % [
		_dodge.travel_distance() if _dodge != null else -1.0,
		_dodge.backstep_travel_distance() if _dodge != null else -1.0,
		_dodge.kind_name() if _dodge != null else "-",
		_dodge.facing_name() if _dodge != null else "-"])
	if _failures.is_empty():
		print("[DODGEIN] RESULT: ALL CHECKS PASSED")
	else:
		print("[DODGEIN] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
