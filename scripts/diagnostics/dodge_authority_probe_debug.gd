class_name DodgeAuthorityProbeDebug
extends Node3D
## Temporary diagnostic for the Dodge movement-authority pass (not production).
##
## Section 8F of the roadmap records a bounded pass: during a COMMITTED evasion the
## evasion owns the body's orientation and its displacement, and nothing that did
## not author the evasion may rewrite either. This probe measures that contract -
## and, because the pass also touches the evasion handoff, the properties that must
## NOT have moved: commitment, cost, i-frames and ordinary locomotion afterwards.
##
##   AC1 backstep facing - a NEUTRAL backstep driven through real input retreats
##                         while still facing the way the player faced. The body
##                         yaw does not turn around on any frame of the evasion.
##   AC2 dodge facing    - a DIRECTIONAL dodge driven through real input keeps the
##                         SAME locked facing even when that facing is pinned 180
##                         degrees away from the direction being dodged. The pin is
##                         deliberately adversarial: it is the clearest read of
##                         "orientation belongs to the locked facing, not velocity".
##   AC3 dodge travel    - on clear ground, travel equals speed x duration, and the
##                         per-frame distance never exceeds the speed the evasion
##                         authored - so unauthored displacement cannot hide inside
##                         a plausible total.
##   AC4 backstep travel - the same for the neutral backstep, which is slower.
##   AC5 dodge into step - an evasion driven into the 42 cm step stays at ground
##                         level and gains NO displacement beyond speed x duration.
##                         This is the position-arbitration case: the step correction
##                         used to add a probe-reach move in the middle of an evasion.
##   AC6 commitment      - an attack still refuses a dodge (mutex unchanged).
##   AC7 stamina         - exactly one 22 point cost per evasion (unchanged).
##   AC8 i-frames        - damage is still refused inside the window (unchanged).
##   AC9 handoff         - when the evasion ends, ordinary locomotion takes the body
##                         back at walking speed and the facing follows movement
##                         again. Authority is returned, not lost.
##
## The facing and travel phases drive the REAL InputMap actions, so the
## controller's own evasion selection is what runs. The remaining phases call the
## components directly, because they measure arbitration rather than input.
## Physical-device feel remains a human playtest.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Tag on every line this probe emits, so a mixed console is still readable.
const TAG := "[AUTHORITY]"
## Full transcript written on finish. A console read can be truncated by the host;
## a report file can be read whole, and a future session can re-check a claim
## without rerunning the whole probe.
const REPORT_PATH := "res://_dodge_authority_report.txt"

const SETTLE_FRAMES := 12
const MAX_PHASE_FRAMES := 360
## A single frame's horizontal travel above this is a positional correction rather
## than the evasion's own speed. A dodge frame is about 0.06 m and a walk frame
## about 0.07 m, while the step correction used to add about 0.48 m in one frame.
## The step probe uses 0.15 for the same detector.
const CORRECTION_JUMP := 0.20
## Tolerance in metres for "travel matches speed x duration". Far below the 0.48 m
## correction this exists to catch.
const TRAVEL_TOLERANCE := 0.10
## Tolerance in degrees for "the body kept the facing the evasion locked".
const FACING_TOLERANCE_DEG := 2.0
## Tolerance in degrees for "ordinary facing follows movement again afterwards".
const RESUMED_FACING_TOLERANCE_DEG := 15.0

enum Step {
	BACKSTEP_FACING,
	DIRECTIONAL_FACING,
	DODGE_TRAVEL,
	BACKSTEP_TRAVEL,
	DODGE_INTO_STEP,
	MUTEX_ATTACKING,
	STAMINA_COST,
	IFRAMES,
	LOCOMOTION_RESUMES,
	DONE,
}

var _player: PlayerController
var _dodge: DodgeComponent
var _stamina: StaminaComponent
var _health: HealthComponent
var _hurtbox: HurtboxComponent
var _combat: PlayerCombat

var _step: int = Step.BACKSTEP_FACING
var _frame := 0
var _phase_frames := 0
var _done := false
var _failures: Array = []

# --- per-phase scratch ---
## The facing a committed evasion is expected to hold. Pinned onto the body while
## _pin_facing is set, and used as the yardstick the body's yaw is measured against.
var _yaw_locked := 0.0
var _pin_facing := false
var _max_yaw_dev := 0.0
var _travel := 0.0
var _travel_elapsed := 0.0
var _last_position := Vector3.ZERO
## Where the body stood when the evasion actually started. Travel is accumulated
## from the evasion's first sampled frame, so this is what separates travel the
## evasion authored from anything that happened before it began.
var _start_position := Vector3.ZERO
## The body position when the evasion ended.
var _end_position := Vector3.ZERO
var _max_frame_step := 0.0
## Lines reported by this probe, written to REPORT_PATH on finish.
var _lines: Array = []
var _evasion_seen := false
var _started := false
var _dodges_before := 0
var _stamina_before := 0.0
var _health_before := 0.0
var _iframes_before := 0
var _cruise_reached := false
var _walk_travel := 0.0
var _walk_elapsed := 0.0


func _ready() -> void:
	_resolve()
	if _player == null or _dodge == null:
		_finish()
		return
	# Stand any arena attacker down: this probe measures the player's own
	# arbitration, so an ambient strike must not contaminate health accounting.
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
	_player = main.get_node_or_null(base + "Player") as PlayerController
	_dodge = main.get_node_or_null(base + "Player/Dodge") as DodgeComponent
	_stamina = main.get_node_or_null(base + "Player/Stamina") as StaminaComponent
	_health = main.get_node_or_null(base + "Player/Health") as HealthComponent
	_hurtbox = main.get_node_or_null(base + "Player/Hurtbox") as HurtboxComponent
	_combat = main.get_node_or_null(base + "Player/Combat") as PlayerCombat

	_expect(_player != null, "player found and is a PlayerController")
	_expect(_dodge != null, "player Dodge is a DodgeComponent")
	_expect(_stamina != null, "player Stamina found")
	_expect(_health != null, "player Health found")
	_expect(_hurtbox != null, "player Hurtbox is a HurtboxComponent")
	_expect(_combat != null, "player Combat is a PlayerCombat")


## Read the authored numbers this probe is about to measure against, so the
## transcript is self-describing and a re-tune is visible rather than silent.
func _audit() -> void:
	_say("--- wiring audit (measured) ---")
	_say("directional: speed=%.2f m/s duration=%.2f s -> travel=%.3f m" % [
		_dodge.dodge_speed, _dodge.dodge_duration, _dodge.travel_distance()])
	_say("backstep:    speed=%.2f m/s duration=%.2f s -> travel=%.3f m" % [
		_dodge.backstep_speed, _dodge.backstep_duration, _dodge.backstep_travel_distance()])
	_say("i-frames %.2f-%.2f s inside a %.2f s dodge, stamina cost %.0f" % [
		_dodge.iframes_start, _dodge.iframes_end, _dodge.dodge_duration,
		_dodge.stamina_cost])
	_say("locomotion: walk=%.2f m/s sprint=%.2f m/s turn=%.0f deg/s" % [
		_player.move_speed, _player.sprint_speed, _player.turn_speed_degrees])
	_say("step contract: max_step_height=%.2f m, probe reach=%.2f x radius" % [
		_player.max_step_height, _player.step_probe_reach])


func _physics_process(_delta: float) -> void:
	if _done or _player == null:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_phase_frames += 1

	# While an evasion is only ANTICIPATED, hold the body on the exact facing the
	# evasion is expected to lock. Ordinary facing would otherwise rotate the body
	# during the approach and destroy the reading. The moment the evasion is
	# running, the pin stops and every sample is a measurement of the real body.
	if _pin_facing and not _dodge.is_dodging():
		_player.rotation.y = _yaw_locked

	if _phase_frames > MAX_PHASE_FRAMES:
		_fail("phase %d did not finish within %d frames" % [_step, MAX_PHASE_FRAMES])
		_release_all_input()
		_finish()
		return

	match _step:
		Step.BACKSTEP_FACING:
			_phase_backstep_facing()
		Step.DIRECTIONAL_FACING:
			_phase_directional_facing()
		Step.DODGE_TRAVEL:
			_phase_dodge_travel()
		Step.BACKSTEP_TRAVEL:
			_phase_backstep_travel()
		Step.DODGE_INTO_STEP:
			_phase_dodge_into_step()
		Step.MUTEX_ATTACKING:
			_phase_mutex_attacking()
		Step.STAMINA_COST:
			_phase_stamina()
		Step.IFRAMES:
			_phase_iframes()
		Step.LOCOMOTION_RESUMES:
			_phase_locomotion_resumes()
		_:
			_finish()


# --- AC1: a neutral backstep keeps the locked facing -------------------------

func _phase_backstep_facing() -> void:
	if _phase_frames == 1:
		_say("--- AC1 neutral backstep keeps the locked facing ---")
		_reset_actor(Vector3(0.0, 0.3, 12.0), 0.0)
		_pin_facing = true
		_say("start yaw=%.2f deg, locked=%.2f deg" % [
			rad_to_deg(_player.rotation.y), rad_to_deg(_yaw_locked)])
		return
	# Held still until the tap, so the evasion is genuinely the first thing that
	# moves the body. A leftover coast would be measured as evasion travel.
	if _phase_frames < 24:
		_player.velocity = Vector3.ZERO
		return
	if _phase_frames == 24:
		_dodges_before = _dodge.dodges_started
		Input.action_press(&"dodge")
		return
	if _phase_frames == 30:
		Input.action_release(&"dodge")
		return
	if _track_evasion():
		return
	_pin_facing = false
	_report_facing("AC1", "a neutral tap produced a BACKSTEP", "BACKSTEP")
	_advance()
	_step = Step.DIRECTIONAL_FACING


# --- AC2: a directional dodge keeps the locked facing ------------------------

func _phase_directional_facing() -> void:
	if _phase_frames == 1:
		_say("--- AC2 directional dodge keeps the locked facing ---")
		# Clear ground on purpose. The arena's TestAttacker stands at (0, 0, 5), so
		# spawning at z=6 and dodging along camera-forward (-Z) drives the evasion
		# straight into it and the body stops after ~0.1 m. That measures the
		# attacker, not the dodge. z=16 keeps the whole 1.69 m burst unobstructed.
		_reset_actor(Vector3(0.0, 0.3, 16.0), 0.0)
		# Build a real wish direction from real input, so the evasion the controller
		# starts is the one a player would get.
		Input.action_press(&"move_forward")
		return
	if _phase_frames < 12:
		_player.velocity = Vector3.ZERO
		return
	if _phase_frames == 12:
		# Pin the body to face EXACTLY AWAY from the direction it is about to dodge.
		# Deliberately adversarial: if anything derives orientation from the evasion's
		# velocity, this is where it becomes impossible to miss.
		var wish := _camera_forward_flat()
		_player.rotation.y = atan2(wish.x, wish.z)
		_yaw_locked = _player.rotation.y
		_max_yaw_dev = 0.0
		_travel = 0.0
		_travel_elapsed = 0.0
		_max_frame_step = 0.0
		_evasion_seen = false
		_last_position = _player.global_position
		_pin_facing = true
		_say("dodge direction=%s, body pinned to face AWAY from it" % str(wish))
		_say("  pinned body yaw=%.1f deg, direction yaw=%.1f deg" % [
			rad_to_deg(_player.rotation.y), rad_to_deg(atan2(-wish.x, -wish.z))])
		return
	if _phase_frames == 18:
		_dodges_before = _dodge.dodges_started
		Input.action_press(&"dodge")
		return
	if _phase_frames == 24:
		Input.action_release(&"dodge")
		return
	if _track_evasion():
		return
	_pin_facing = false
	Input.action_release(&"move_forward")
	_report_facing("AC2", "a directional dodge resolved as DIRECTIONAL", "DIRECTIONAL")
	_advance()
	_step = Step.DODGE_TRAVEL


# --- AC3 / AC4 / AC5: travel and position arbitration ------------------------

func _phase_dodge_travel() -> void:
	if _phase_frames == 1:
		_say("--- AC3 directional dodge travel on clear ground ---")
		_reset_actor(Vector3(0.0, 0.3, 14.0), 0.0)
		_pin_facing = false
		return
	if _phase_frames < 20:
		_player.velocity = Vector3.ZERO
		return
	if _phase_frames == 20:
		_stamina.reset()
		_start_evasion(Vector3(0.0, 0.0, -1.0))
		return
	if _track_evasion():
		return
	_say("measured travel=%.4f m over %.4f s (authored %.3f m in %.2f s)" % [
		_travel, _travel_elapsed, _dodge.travel_distance(), _dodge.dodge_duration])
	_expect(_started, "AC3 the directional dodge actually started")
	_expect_travel("AC3", _dodge.dodge_speed)
	_expect(_max_frame_step <= CORRECTION_JUMP,
		"AC3 no single frame carried unauthored displacement (max frame %.4f m, limit %.2f)" % [
			_max_frame_step, CORRECTION_JUMP])
	_advance()
	_step = Step.BACKSTEP_TRAVEL


func _phase_backstep_travel() -> void:
	if _phase_frames == 1:
		_say("--- AC4 neutral backstep travel ---")
		_reset_actor(Vector3(0.0, 0.3, 12.0), 0.0)
		_pin_facing = false
		return
	if _phase_frames < 20:
		_player.velocity = Vector3.ZERO
		return
	if _phase_frames == 20:
		_stamina.reset()
		_start_evasion(Vector3(0.0, 0.0, 1.0), DodgeComponent.Kind.BACKSTEP)
		return
	if _track_evasion():
		return
	_say("measured backstep travel=%.4f m over %.4f s (authored %.3f m)" % [
		_travel, _travel_elapsed, _dodge.backstep_travel_distance()])
	_expect(_started, "AC4 the backstep actually started")
	_expect_travel("AC4", _dodge.backstep_speed)
	_expect(_dodge.facing_name() == "BACKWARD",
		"AC4 the backstep still reports BACKWARD (got %s)" % _dodge.facing_name())
	_advance()
	_step = Step.DODGE_INTO_STEP


## The position-arbitration case. The body is driven straight into the 42 cm step
## at x=-7 from z=-6. The step correction used to fire mid-evasion, add a
## probe-reach move and drop the body onto the step, so the evasion both travelled
## further than it authored and ended up somewhere it never asked to be.
func _phase_dodge_into_step() -> void:
	if _phase_frames == 1:
		_say("--- AC5 dodge driven into the 42 cm step ---")
		_reset_actor(Vector3(-7.0, 0.3, -6.0), 0.0)
		_pin_facing = false
		return
	if _phase_frames < 24:
		_player.velocity = Vector3.ZERO
		return
	if _phase_frames == 24:
		_stamina.reset()
		_start_evasion(Vector3(0.0, 0.0, -1.0))
		return
	if _track_evasion():
		return
	var final_y: float = _player.global_position.y
	var authored := _dodge.dodge_speed * _travel_elapsed
	_say("travel=%.4f m over %.4f s (authored for that time %.4f m), final y=%.3f" % [
		_travel, _travel_elapsed, authored, final_y])
	_expect(_started, "AC5 the dodge into the step actually started")
	_expect(_travel <= authored + TRAVEL_TOLERANCE,
		"AC5 the obstruction added NO displacement the evasion did not author (%.4f m vs %.4f m)" % [
			_travel, authored])
	_expect(_max_frame_step <= CORRECTION_JUMP,
		"AC5 no single frame carried a step correction (max frame %.4f m, limit %.2f)" % [
			_max_frame_step, CORRECTION_JUMP])
	_expect(final_y < 0.30,
		"AC5 the evasion did not climb onto the step it ran into (final y %.3f, step top 0.42)" % final_y)
	_advance()
	_step = Step.MUTEX_ATTACKING


# --- AC6-AC8: the properties that must NOT have moved ------------------------

func _phase_mutex_attacking() -> void:
	if _phase_frames == 1:
		_say("--- AC6 an attack still refuses a dodge ---")
		_reset_actor(Vector3(0.0, 0.3, 12.0), 0.0)
		_pin_facing = false
		return
	if _phase_frames < 12:
		_player.velocity = Vector3.ZERO
		return
	if _phase_frames == 12:
		_expect(_combat.light_attack != null, "the light attack definition exists")
		_expect(_combat.try_start(_combat.light_attack), "a light attack started")
		_expect(_combat.is_busy(), "the attack commits the body")
		_dodges_before = _dodge.dodges_started
		_stamina.reset()
		var refused_before := _dodge.dodges_refused_while_attacking
		var accepted := _dodge.try_start(Vector3(0.0, 0.0, -1.0))
		_expect(not accepted, "a dodge during an attack is refused")
		_expect(_dodge.dodges_refused_while_attacking == refused_before + 1,
			"the refusal was counted as an attack-mutex refusal (%d -> %d)" % [
				refused_before, _dodge.dodges_refused_while_attacking])
		_expect(_dodge.dodges_started == _dodges_before,
			"the refused dodge was not counted as started")
		_expect(not _dodge.is_dodging(), "the refused dodge left the actor idle")
		return
	# The attack still owns the body for its whole timeline: let it finish rather
	# than cancelling, so the mutex is measured against a real committed attack.
	if _combat.is_busy():
		return
	_expect(_dodge.dodges_started == _dodges_before,
		"no dodge leaked out of the attack it was refused during")
	_advance()
	_step = Step.STAMINA_COST


func _phase_stamina() -> void:
	if _phase_frames == 1:
		_say("--- AC7 exactly one stamina cost per evasion ---")
		_reset_actor(Vector3(0.0, 0.3, 14.0), 0.0)
		_pin_facing = false
		return
	if _phase_frames < 16:
		_player.velocity = Vector3.ZERO
		return
	if _phase_frames == 16:
		_dodges_before = _dodge.dodges_started
		_stamina_before = _stamina.current_stamina
		var accepted := _dodge.try_start(Vector3(0.0, 0.0, -1.0))
		_expect(accepted, "an affordable dodge started")
		_expect(_dodge.dodges_started == _dodges_before + 1,
			"the accepted dodge was counted once (%d -> %d)" % [
				_dodges_before, _dodge.dodges_started])
		_say("stamina %.1f -> %.1f (cost %.0f)" % [
			_stamina_before, _stamina.current_stamina, _dodge.stamina_cost])
		_expect(is_equal_approx(_stamina.current_stamina, _stamina_before - _dodge.stamina_cost),
			"exactly one stamina cost was charged (%.1f -> %.1f, expected -%.0f)" % [
				_stamina_before, _stamina.current_stamina, _dodge.stamina_cost])
		return
	if _dodge.is_dodging():
		return
	if _phase_frames < 20:
		return
	_expect(is_equal_approx(_stamina.current_stamina, _stamina_before - _dodge.stamina_cost),
		"the cost was charged once, not once per frame (%.1f)" % _stamina.current_stamina)
	_advance()
	_step = Step.IFRAMES


func _phase_iframes() -> void:
	if _phase_frames == 1:
		_say("--- AC8 the i-frame window still refuses damage ---")
		_reset_actor(Vector3(0.0, 0.3, 14.0), 0.0)
		_pin_facing = false
		_health.reset()
		_health_before = _health.current_health
		_iframes_before = _hurtbox.refusals_by_iframes
		# Damage outside any window must land normally, or "refused" proves nothing.
		_damage(7.0)
		_expect(is_equal_approx(_health.current_health, _health_before - 7.0),
			"damage outside any window applies normally (%.1f -> %.1f)" % [
				_health_before, _health.current_health])
		return
	if _phase_frames == 6:
		_stamina.reset()
		_start_evasion(Vector3(0.0, 0.0, -1.0))
		return
	if _phase_frames >= 8 and _phase_frames <= 24 and _dodge.is_invulnerable():
		var before := _health.current_health
		_damage(9.0)
		_expect(is_equal_approx(_health.current_health, before),
			"damage inside the i-frame window was refused")
		_expect(_hurtbox.refusals_by_iframes > _iframes_before,
			"the refusal was counted as an i-frame refusal (%d -> %d)" % [
				_iframes_before, _hurtbox.refusals_by_iframes])
		_phase_frames = 0
		_step = Step.LOCOMOTION_RESUMES
		return
	if _phase_frames > 24:
		_fail("never reached the i-frame window inside the evasion")
		_advance()
		_step = Step.LOCOMOTION_RESUMES


# --- AC9: authority is returned, not lost ------------------------------------

func _phase_locomotion_resumes() -> void:
	if _phase_frames == 1:
		_say("--- AC9 ordinary locomotion takes the body back ---")
		_reset_actor(Vector3(0.0, 0.3, 14.0), 0.0)
		_pin_facing = false
		# Face the body AWAY from where it is about to walk, so "the facing follows
		# movement again" is a real change rather than a reading that cannot move.
		_player.rotation.y = PI
		return
	if _phase_frames < 20:
		_player.velocity = Vector3.ZERO
		_player.rotation.y = PI
		return
	if _phase_frames == 20:
		Input.action_press(&"move_forward")
		_cruise_reached = false
		_walk_travel = 0.0
		_walk_elapsed = 0.0
		_last_position = _player.global_position
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if not _cruise_reached:
		# Frame counts are not time in a scene that renders uncapped, so wait for the
		# acceleration ramp to finish and then measure over a WALL-CLOCK window.
		_last_position = _player.global_position
		if speed >= _player.move_speed * 0.98:
			_cruise_reached = true
		return
	_walk_travel += _flat_distance(_player.global_position, _last_position)
	_walk_elapsed += get_physics_process_delta_time()
	_last_position = _player.global_position
	if _walk_elapsed < 0.5:
		return
	Input.action_release(&"move_forward")
	var expected := _player.move_speed * _walk_elapsed
	_say("walked %.4f m in %.3f s at %.2f m/s (expected %.4f m)" % [
		_walk_travel, _walk_elapsed, speed, expected])
	_expect(_cruise_reached, "AC9 the body reached walking speed again after the evasion")
	_expect(absf(_walk_travel - expected) <= TRAVEL_TOLERANCE,
		"AC9 travel matches walking speed (%.4f m vs %.4f m)" % [_walk_travel, expected])
	var forward := _camera_forward_flat()
	var want_yaw := atan2(-forward.x, -forward.z)
	var deviation := absf(rad_to_deg(wrapf(_player.rotation.y - want_yaw, -PI, PI)))
	_say("facing=%.1f deg, movement direction=%.1f deg, deviation=%.1f deg" % [
		rad_to_deg(_player.rotation.y), rad_to_deg(want_yaw), deviation])
	_expect(deviation <= RESUMED_FACING_TOLERANCE_DEG,
		"AC9 the facing follows movement again after the evasion (deviation %.1f deg)" % deviation)
	_advance()
	_step = Step.DONE


# --- phase plumbing ----------------------------------------------------------

## Wait for the evasion under test. Returns true while the phase should keep
## waiting: either the evasion has not appeared yet, or it is still running.
## A bounded wait is deliberate - a REFUSED evasion must not read as a hung probe,
## so after the bound the phase proceeds and fails on "no evasion started".
func _track_evasion() -> bool:
	if _dodge.is_dodging():
		if not _evasion_seen:
			# Anchor the measurement to the evasion's OWN first frame. The phases
			# that drive real input hold a movement key before the tap, so the body
			# is already walking when the evasion begins; counting that approach
			# would report travel the evasion never authored (measured: 1.9150 m
			# against an authored 1.6875 m) and would print waypoints describing the
			# wrong window. _start_position is also set here rather than only in
			# _start_evasion, because the real-input phases never call that helper.
			_evasion_seen = true
			_start_position = _player.global_position
			_last_position = _start_position
			_travel = 0.0
			_travel_elapsed = 0.0
			_max_frame_step = 0.0
			_max_yaw_dev = 0.0
		_sample_evasion()
		return true
	if _evasion_seen:
		return false
	if _phase_frames >= 40:
		_diag("no evasion appeared")
		return false
	return true


func _sample_evasion() -> void:
	var position: Vector3 = _player.global_position
	var frame_step := _flat_distance(position, _last_position)
	_last_position = position
	if frame_step > _max_frame_step:
		_max_frame_step = frame_step
	_travel += frame_step
	_travel_elapsed += get_physics_process_delta_time()
	var deviation := absf(rad_to_deg(wrapf(_player.rotation.y - _yaw_locked, -PI, PI)))
	if deviation > _max_yaw_dev:
		_max_yaw_dev = deviation


func _start_evasion(direction: Vector3, kind: int = DodgeComponent.Kind.DIRECTIONAL) -> void:
	_evasion_seen = false
	_started = false
	_travel = 0.0
	_travel_elapsed = 0.0
	_max_frame_step = 0.0
	_max_yaw_dev = 0.0
	_start_position = _player.global_position
	_last_position = _start_position
	_dodges_before = _dodge.dodges_started
	_started = _dodge.try_start(direction, kind)
	if not _started:
		_diag("try_start refused %s" % str(direction))


func _report_facing(label: String, kind_expectation: String, kind_wanted: String) -> void:
	_say("%s evasion=%s facing=%s travel=%.4f m over %.4f s" % [
		label, _dodge.kind_name(), _dodge.facing_name(), _travel, _travel_elapsed])
	# Print the waypoints, so a travel reading that comes out short can be told
	# apart from an evasion that was genuinely blocked by arena geometry.
	_say("%s from=%s to=%s (flat %.3f m)" % [
		label, _flat_string(_start_position), _flat_string(_player.global_position),
		_flat_distance(_start_position, _player.global_position)])
	_expect(_evasion_seen, "%s an evasion actually started (a refusal reads as defaults)" % label)
	_expect(_dodge.dodges_started > _dodges_before,
		"%s an evasion was counted as started" % label)
	_expect(_dodge.kind_name() == kind_wanted,
		"%s %s (got %s)" % [label, kind_expectation, _dodge.kind_name()])
	_expect(_max_yaw_dev <= FACING_TOLERANCE_DEG,
		"%s the body kept the locked facing for the whole evasion (max deviation %.2f deg, limit %.1f)" % [
			label, _max_yaw_dev, FACING_TOLERANCE_DEG])
	# The evasion's own direction must still be the one it set out on: nothing
	# downstream is allowed to rewrite it.
	_say("%s locked facing %.1f deg, max body deviation %.2f deg over the evasion" % [
		label, rad_to_deg(_yaw_locked), _max_yaw_dev])


func _expect_travel(label: String, speed: float) -> void:
	var authored := speed * _travel_elapsed
	var authored_total := speed * (
		_dodge.backstep_duration if _dodge.kind_name() == "BACKSTEP" else _dodge.dodge_duration)
	_say("%s measured=%.4f m, speed x elapsed=%.4f m, authored total=%.4f m" % [
		label, _travel, authored, authored_total])
	_expect(absf(_travel - authored) <= TRAVEL_TOLERANCE,
		"%s travel matches the evasion's own speed over the evasion's own duration (%.4f vs %.4f)" % [
			label, _travel, authored])
	_expect(absf(_travel - authored_total) <= 0.20,
		"%s travel matches the authored total (%.4f vs %.4f)" % [
			label, _travel, authored_total])


func _reset_actor(at: Vector3, yaw: float) -> void:
	_release_all_input()
	_dodge.reset()
	if _stamina != null:
		_stamina.reset()
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	_player.rotation.y = yaw
	_yaw_locked = yaw
	_max_yaw_dev = 0.0
	_travel = 0.0
	_travel_elapsed = 0.0
	_max_frame_step = 0.0
	_evasion_seen = false
	_started = false
	_last_position = at


func _advance() -> void:
	_phase_frames = 0
	_pin_facing = false
	_release_all_input()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Position on the GROUND PLANE only, as (x, z). An evasion is grounded movement,
## so the height a capsule sits at is noise in a travel reading; showing x and z
## alone is what makes a short travel read obvious as "blocked by geometry" rather
## than "the evasion did not move".
func _flat_string(at: Vector3) -> String:
	return "(%.2f, %.2f)" % [at.x, at.z]


## The flat forward the CONTROLLER steers by: the active camera's forward with
## pitch discarded. Replicated here so the probe can pin the body relative to the
## same basis the dodge direction is resolved in.
func _camera_forward_flat() -> Vector3:
	var camera := _player.get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(0.0, 0.0, -1.0)
	var back := camera.global_transform.basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return -back.normalized()


## Dump every reason an evasion could have been refused. A refusal that silently
## reads as the component's default state is the failure mode this probe exists to
## avoid, so when an expected evasion does not appear, say WHY.
func _diag(label: String) -> void:
	var parry := _player.get_node_or_null("Parry") as ParryComponent
	_say("DIAG %s: stamina=%.1f busy=%s parrying=%s active=%s | refused dodging=%d attacking=%d parry=%d stamina=%d dir=%d" % [
		label,
		_stamina.current_stamina if _stamina != null else -1.0,
		str(_combat != null and _combat.is_busy()),
		str(parry != null and parry.is_parrying()),
		str(_dodge.is_dodging()),
		_dodge.dodges_refused_while_dodging,
		_dodge.dodges_refused_while_attacking,
		_dodge.dodges_refused_while_parrying,
		_dodge.dodges_refused_by_stamina,
		_dodge.dodges_refused_invalid_direction])


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


## Emit one tagged line to the console AND to the transcript buffer. Every line
## this probe produces goes through here, so the file on disk is the whole run
## and not a hand-picked subset of it.
func _say(line: String) -> void:
	var tagged := "%s %s" % [TAG, line]
	print(tagged)
	_lines.append(tagged)


func _expect(condition: bool, label: String) -> void:
	if condition:
		_say("  PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	_say("  FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	_release_all_input()
	_say("--- summary ---")
	_say("evasion authority: facing locked during the evasion, displacement"
		+ " authored only by the evasion, ordinary locomotion restored afterwards")
	if _failures.is_empty():
		_say("RESULT: ALL CHECKS PASSED")
	else:
		_say("RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
	_write_report()


## Leave the whole transcript on disk, the way the recovery-chain probe does. A
## console read can be truncated by the host; a report file can be read whole,
## and a future session can re-check a claim without rerunning the probe.
func _write_report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("\n".join(_lines) + "\n")
	file.close()
