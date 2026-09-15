class_name EnemyEngagementProbeDebug
extends Node3D
## Temporary Milestone 17 diagnostic (not production).
##
## Drives the REAL engagement loop - no faked positions and no directly assigned state - and
## measures what actually happened every physics frame. It isolates the system under test with
## `EnemyAttacker.stand_down_all()`, the same convention every other probe in the project uses,
## so the arena is never fighting the measurement at the same time.
##
## What each check proves:
##
##   AC1 still      - outside detection_radius the enemy does not move at all.
##   AC2 approach   - inside detection_radius the distance to the player strictly decreases.
##   AC3 stop       - it stops at its own engage_range, and stops SHORT of it by stop_margin
##                    rather than oscillating across the threshold.
##   AC4 no overlap - it never walks into the player's capsule.
##   AC5 no jitter  - once stopped, the distance stays inside a band instead of cycling.
##   AC6 facing     - its yaw converges on the player while it walks.
##   AC7 state      - ActorState reports the enemy grounded, which needs real body physics.
##   AC8 committed  - during WINDUP the facing is LOCKED: moving the player laterally does not
##                    turn the enemy, which is what makes walking around a windup work.
##   AC9 defeated   - a defeated enemy does not move.
##   AC10 reset     - the ARENA reset path puts the enemy back on the mark its scene authored.
##   AC11 intent    - `locomotion` becomes a reachable intent for an enemy, and the adapter never
##                    reports an intent outside its own declared vocabulary.
##   AC12 UI/lock   - lock-on still acquires and releases, the health bars still track the same
##                    enemies, and the reveal rule is UNCHANGED (an undamaged enemy shows no bar).
##   AC13 data      - two archetypes with different profile numbers measurably move differently.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Physics frames allowed for the settlement after the probe repositions everything.
const SETTLE_FRAMES := 40
## Frames the enemy is observed at rest outside detection radius.
const IDLE_FRAMES := 40
## Frames the approach is sampled over.
const APPROACH_FRAMES := 90
## Hard cap on how long the enemy may take to arrive.
const ARRIVE_FRAMES := 420
## Frames the stopped distance is watched for jitter.
const JITTER_FRAMES := 45
## How much the distance may grow during an approach sample and still count as closing.
const CLOSING_EPSILON := 0.01
## How far the body's yaw may sit from the target yaw and still count as converged, in degrees.
const FACING_TOLERANCE_DEGREES := 8.0
## The enemy must stop at least this far from the player, so it never stands inside the capsule.
const MIN_SEPARATION := 1.0
## Allowed spread of the stopped distance over the jitter window, in metres.
const JITTER_BAND := 0.12
## How far the player is shifted sideways while a windup is running, in metres.
const LATERAL_SHIFT := 2.2
## Yaw may drift by no more than this while an attack is committed, in degrees.
const COMMIT_YAW_TOLERANCE_DEGREES := 0.5
## A defeated body may drift no further than this, in metres.
const DEAD_DRIFT := 0.02
## How close to its recorded mark an enemy must land, in metres.
const MARK_TOLERANCE := 0.15
## How different the two archetypes' peak approach speeds must be, in metres per second, to prove
## that movement really is driven by profile data rather than one hardcoded number.
const SPEED_DIFFERENCE := 0.3

enum Step {
	SETUP, IDLE_TEST, APPROACH, ARRIVE, JITTER, COMMIT, COMMIT_HOLD,
	DEFEAT, ARENA_RESET, ARENA_RESET_CONFIRM, BRUTE_SPEED, ADAPTER, UI, DONE,
}

var _player: CharacterBody3D
var _attacker_body: CharacterBody3D
var _brute_body: CharacterBody3D
var _attacker: EnemyAttacker
var _brute_attacker: EnemyAttacker
var _attacker_loco: EnemyLocomotion
var _brute_loco: EnemyLocomotion
var _attacker_health: HealthComponent
var _attacker_hurtbox: HurtboxComponent
var _attacker_state: ActorState
var _brute_state: ActorState
var _targeting: TargetingComponent
var _bars: EnemyHealthBars
var _death: Node

var _step: int = Step.SETUP
var _frame := 0
var _done := false
var _failures: Array = []

## Distance samples for the current observation window.
var _samples: Array = []
## Peak flat speed seen during an approach window.
var _peak_speed := 0.0
var _brute_peak_speed := 0.0
var _idle_mark := 0.0
## The yaw the enemy held when the attack committed.
var _committed_yaw := 0.0
## Frames the committed attack was observed for, so "it held" is not a single-frame accident.
var _commit_frames := 0
## Peak body speed observed WHILE the attack was committed. Sampled during the commitment rather
## than read after it, because the moment the attack ends a still-detected player puts the enemy
## straight back into APPROACH - a reading taken then would measure the next action.
var _commit_max_speed := 0.0
var _kill_done := false
var _dead_mark := Vector3.ZERO
var _mark_before := Transform3D.IDENTITY


func _ready() -> void:
	_resolve()
	if _attacker_body == null or _attacker_loco == null or _player == null:
		_finish()
		return
	# Deterministic: the probe drives every attack itself, and every enemy starts on its mark with
	# the player parked outside every detection radius.
	EnemyAttacker.stand_down_all(get_tree())
	_attacker_loco.reset_to_mark()
	_brute_loco.reset_to_mark()
	_park_player_far()
	_say("attacker: detect=%.1f engage=%.2f stop=%.2f speed=%.2f turn=%.0f" % [
		_attacker_loco.detection_radius(), _attacker_loco.engage_range(),
		_attacker_loco.stopping_distance(), _attacker_loco.move_speed,
		_attacker_loco.turn_speed_degrees])
	_say("brute:    detect=%.1f engage=%.2f stop=%.2f speed=%.2f turn=%.0f" % [
		_brute_loco.detection_radius(), _brute_loco.engage_range(),
		_brute_loco.stopping_distance(), _brute_loco.move_speed,
		_brute_loco.turn_speed_degrees])
	_expect(_attacker_loco.detection_radius() > 0.0, "AC13 the attacker has a real detection radius")
	_expect(_brute_loco.detection_radius() > 0.0, "AC13 the brute has a real detection radius")
	_expect(_attacker_loco.owns_uncommitted_facing(),
		"AC8 the locomotion component declares that it owns the uncommitted facing")


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	match _step:
		Step.SETUP:
			if _frame >= SETTLE_FRAMES:
				_step = Step.IDLE_TEST
				_frame = 0
				_peak_speed = 0.0
				_idle_mark = _distance_to_attacker()
		Step.IDLE_TEST:
			_peak_speed = maxf(_peak_speed, _flat_speed(_attacker_body))
			if _frame >= IDLE_FRAMES:
				var movement: float = absf(_distance_to_attacker() - _idle_mark)
				_expect(movement <= DEAD_DRIFT,
					"AC1 outside detection the attacker holds its mark (moved %.4f m)" % movement)
				_expect(_peak_speed <= 0.05,
					"AC1 and it is not moving at all (peak %.3f m/s)" % _peak_speed)
				_expect(not _attacker_loco.is_engaged(),
					"AC1 and it does not report itself engaged")
				_expect(_attacker_loco.state_name() == "IDLE",
					"AC1 and its engagement state is IDLE (got %s)" % _attacker_loco.state_name())
				_step = Step.APPROACH
				_frame = 0
				_samples.clear()
				_peak_speed = 0.0
				_move_player(_attacker_body.global_position + Vector3(0.0, 0.1, 0.0)
					+ _toward_centre(_attacker_body) * _inside_detection(_attacker_loco))
		Step.APPROACH:
			_samples.append(_distance_to_attacker())
			_peak_speed = maxf(_peak_speed, _flat_speed(_attacker_body))
			if _frame >= APPROACH_FRAMES:
				_check_closing()
				_expect(_attacker_loco.is_engaged(),
					"AC2 the attacker reports itself engaged while pursuing (%s)"
					% _attacker_loco.state_name())
				_expect(_peak_speed > 0.5,
					"AC13 and it actually moved under its own speed (peak %.2f m/s)" % _peak_speed)
				_step = Step.ARRIVE
				_frame = 0
		Step.ARRIVE:
			if _frame >= ARRIVE_FRAMES:
				_fail("AC3 the attacker never arrived (%.2f m after %d frames)"
					% [_distance_to_attacker(), ARRIVE_FRAMES])
				_finish_arrival()
			elif _attacker_loco.distance_to_target() <= _attacker_loco.engage_range() + 0.25 \
					and _flat_speed(_attacker_body) < 0.35:
				_finish_arrival()
		Step.JITTER:
			_samples.append(_distance_to_attacker())
			if _frame >= JITTER_FRAMES:
				_check_jitter()
				_step = Step.COMMIT
				_frame = 0
				_samples.clear()
		Step.COMMIT:
			# The player is in range and the enemy is stopped, so this is the real commit path.
			if not _attacker.try_start():
				_fail("AC8 the attacker refused to commit while in range (%.2f m, range %.2f)"
					% [_attacker_loco.distance_to_target(), _attacker.engage_range])
				_step = Step.DEFEAT
				_frame = 0
				return
			_expect(_attacker.is_attacking(), "AC8 the attacker committed an attack")
			_committed_yaw = _attacker_body.rotation.y
			_commit_frames = 0
			# Move the player SIDEWAYS while the windup runs. A committed attack owns the body, so
			# the yaw must not follow - this is what walking around a windup depends on.
			var away := _attacker_body.global_position - _player.global_position
			away.y = 0.0
			if away.length_squared() < 0.0001:
				away = Vector3(0.0, 0.0, 1.0)
			away = away.normalized()
			_move_player(_player.global_position + Vector3(-away.z, 0.0, away.x) * LATERAL_SHIFT)
			_say("AC8 shifted the player %.1f m sideways mid-windup" % LATERAL_SHIFT)
			_step = Step.COMMIT_HOLD
			_frame = 0
		Step.COMMIT_HOLD:
			if _attacker.is_attacking():
				_commit_frames += 1
				# Measured DURING the commitment, never after it: the moment the attack finishes a
				# still-detected player legitimately puts the enemy back into APPROACH, so a reading
				# taken afterwards would be measuring the next action rather than this one.
				_commit_max_speed = maxf(_commit_max_speed, _flat_speed(_attacker_body))
				var drift := absf(rad_to_deg(angle_difference(_committed_yaw,
					_attacker_body.rotation.y)))
				if drift > COMMIT_YAW_TOLERANCE_DEGREES:
					_fail("AC8 the committed facing MOVED (drifted %.2f deg over %d frames)"
						% [drift, _commit_frames])
					_step = Step.DEFEAT
					_frame = 0
					return
				return
			_expect(_commit_frames >= 5,
				"AC8 the committed facing held for the whole commitment (%d frames observed)"
				% _commit_frames)
			_expect(_commit_max_speed <= 0.35,
				"AC8 and no attack phase moved the body, so it cannot slide through its own swing"
				+ " (peak %.3f m/s while committed)" % _commit_max_speed)
			_step = Step.DEFEAT
			_frame = 0
		Step.DEFEAT:
			if not _kill_done:
				_kill_attacker()
				_kill_done = true
				_dead_mark = _attacker_body.global_position
				_frame = 0
				return
			if _frame >= 40:
				var moved := _attacker_body.global_position.distance_to(_dead_mark)
				_expect(moved <= DEAD_DRIFT,
					"AC9 a defeated enemy does not move (drifted %.4f m)" % moved)
				_expect(not _attacker_loco.is_engaged(),
					"AC9 and it does not report itself engaged")
				_expect(_flat_speed(_attacker_body) <= 0.05,
					"AC9 and its body was stopped rather than left coasting (%.3f m/s)"
					% _flat_speed(_attacker_body))
				_step = Step.ARENA_RESET
				_frame = 0
		Step.ARENA_RESET:
			# Displace the LIVE brute, then run the real arena reset path and require it home.
			_mark_before = _brute_loco.spawn_transform()
			_brute_body.global_position = _mark_before.origin + Vector3(4.0, 0.0, 3.0)
			_brute_body.rotation.y = 2.0
			if _death == null or not _death.has_method("reset_playable_state"):
				_fail("AC10 the arena reset path is unreachable")
				_step = Step.BRUTE_SPEED
				_frame = 0
				return
			_death.call("reset_playable_state", true)
			_say("AC10 ran the real arena reset path")
			# MEASURED ON THE FRAME THE RESET RUNS, and that timing is load-bearing rather than
			# convenient. The reset also sends the PLAYER back to spawn, and spawn is inside the
			# attacker's 12 m detection radius - so on the very next physics frame the revived
			# attacker legitimately starts pursuing again and walks off its mark. Sampling 25 frames
			# later measured that re-engagement (0.86 m, exactly what 2.6 m/s under acceleration
			# covers) and reported it as a failed restore. What this milestone claims is that the
			# reset PUTS the enemy back, so it is measured the instant it does.
			var brute_off := _brute_body.global_position.distance_to(_mark_before.origin)
			_expect(brute_off <= MARK_TOLERANCE,
				"AC10 the arena reset put the brute back on its mark (off by %.3f m)" % brute_off)
			var attacker_off := _attacker_body.global_position.distance_to(
				_attacker_loco.spawn_transform().origin)
			_expect(attacker_off <= MARK_TOLERANCE,
				"AC10 and the revived attacker is back on its mark too (off by %.3f m)"
				% attacker_off)
			_expect(_flat_speed(_attacker_body) <= 0.05,
				"AC10 and the reset stopped its body rather than leaving it moving (%.3f m/s)"
				% _flat_speed(_attacker_body))
			_step = Step.ARENA_RESET_CONFIRM
			_frame = 0
		Step.ARENA_RESET_CONFIRM:
			if _frame >= 25:
				# A revived enemy that still detects the player RESUME PURSUIT. Recorded as an
				# expected consequence rather than left to look like a drifted restore: spawn is
				# inside the attacker's detection radius and outside the brute's, so the two
				# enemies must NOT behave the same way here.
				_expect(not _attacker_health.is_dead,
					"AC10 and the reset restored it ALIVE, so position did not replace health")
				# The asymmetry is the point: spawn (0, 12) is 7 m from the attacker's mark
				# (0, 5), inside its 12 m detection radius, so the revived attacker pursues again.
				# It is ~19 m from the brute's mark (10, -4), outside that enemy's 9 m radius, so
				# the brute stays home. Same reset, same code, different DATA - which is exactly
				# what "the archetypes differ by profile" has to mean in observable behaviour.
				_expect(_attacker_loco.is_engaged(),
					"AC10 the revived attacker re-engaged from its mark (spawn is inside its %.0f m detection)"
					% _attacker.detection_radius)
				_expect(not _brute_loco.is_engaged(),
					"AC10 while the brute stayed home (spawn is outside its %.0f m detection)"
					% _brute_attacker.detection_radius)
				_step = Step.BRUTE_SPEED
				_frame = 0
				_brute_peak_speed = 0.0
				_move_player(_brute_body.global_position + Vector3(0.0, 0.1, 0.0)
					+ _toward_centre(_brute_body) * _inside_detection(_brute_loco))
		Step.BRUTE_SPEED:
			_brute_peak_speed = maxf(_brute_peak_speed, _flat_speed(_brute_body))
			if _frame >= APPROACH_FRAMES:
				_expect(_brute_peak_speed > 0.5,
					"AC13 the brute moved too (peak %.2f m/s)" % _brute_peak_speed)
				var difference: float = absf(_peak_speed - _brute_peak_speed)
				_expect(difference >= SPEED_DIFFERENCE,
					"AC13 the archetypes move at DIFFERENT speeds from profile data (%.2f vs %.2f)"
					% [_peak_speed, _brute_peak_speed])
				_step = Step.ADAPTER
				_frame = 0
		Step.ADAPTER:
			_check_adapter()
			_step = Step.UI
			_frame = 0
		Step.UI:
			_check_ui()
			_step = Step.DONE
			_frame = 0
		Step.DONE:
			_finish()


func _resolve() -> void:
	var main := get_node_or_null("../Main")
	if main == null:
		main = get_node_or_null("Main")
	if main == null:
		_fail("main scene not found")
		return
	var env := main.get_node_or_null("TestEnvironment")
	if env == null:
		_fail("TestEnvironment not found")
		return
	_player = env.get_node_or_null("Player") as CharacterBody3D
	_attacker_body = env.get_node_or_null("TestAttacker") as CharacterBody3D
	_brute_body = env.get_node_or_null("HeavyBrute") as CharacterBody3D
	if _attacker_body == null:
		_fail("the arena has no TestAttacker")
		return
	_attacker = _attacker_body.get_node_or_null("Attacker") as EnemyAttacker
	_attacker_loco = _attacker_body.get_node_or_null("Locomotion") as EnemyLocomotion
	_attacker_health = _attacker_body.get_node_or_null("Health") as HealthComponent
	_attacker_hurtbox = _attacker_body.get_node_or_null("Hurtbox") as HurtboxComponent
	_attacker_state = ActorState.find_for(_attacker_body)
	if _brute_body == null:
		_fail("the arena has no HeavyBrute")
		return
	_brute_attacker = _brute_body.get_node_or_null("Attacker") as EnemyAttacker
	_brute_loco = _brute_body.get_node_or_null("Locomotion") as EnemyLocomotion
	_brute_state = ActorState.find_for(_brute_body)
	if _player == null:
		_fail("the arena has no Player")
		return
	_death = _player.get_node_or_null("Death")
	_targeting = main.get_node_or_null("Targeting") as TargetingComponent
	if _targeting == null and get_tree() != null:
		_targeting = get_tree().get_first_node_in_group(
			TargetingComponent.GROUP_TARGETING) as TargetingComponent
	if get_tree() != null:
		_bars = get_tree().get_first_node_in_group(
			EnemyHealthBars.GROUP_ENEMY_HEALTH_BARS) as EnemyHealthBars
	if _attacker_loco == null:
		_fail("the attacker has no Locomotion component")
	if _brute_loco == null:
		_fail("the brute has no Locomotion component")


# --- Measurements -------------------------------------------------------------

func _park_player_far() -> void:
	# 26 m from the attacker at (0,0,5): outside every detection radius in the arena.
	_move_player(Vector3(0.0, 0.1, -21.0))


func _inside_detection(loco: EnemyLocomotion) -> float:
	return maxf(1.0, loco.detection_radius() - 4.0)


## Which way to place the player from an enemy: toward the arena centre, so a test position never
## lands outside the walls.
func _toward_centre(enemy: Node3D) -> Vector3:
	if enemy == null:
		return Vector3(0.0, 0.0, 1.0)
	var p := enemy.global_position
	if absf(p.x) > absf(p.z):
		return Vector3(-signf(p.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, -signf(p.z))


func _move_player(to: Vector3) -> void:
	if _player == null:
		return
	_player.global_position = Vector3(
		clampf(to.x, -18.0, 18.0), to.y, clampf(to.z, -18.0, 18.0))
	_player.velocity = Vector3.ZERO


func _distance_to_attacker() -> float:
	return _flat_distance(_attacker_body.global_position, _player.global_position)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	var d := a - b
	return Vector2(d.x, d.z).length()


func _flat_speed(body: CharacterBody3D) -> float:
	if body == null:
		return 0.0
	return Vector2(body.velocity.x, body.velocity.z).length()


func _yaw_toward(from: Vector3, to: Vector3) -> float:
	var d := to - from
	d.y = 0.0
	return atan2(-d.x, -d.z)


func _yaw_error_degrees(body: CharacterBody3D, target: Node3D) -> float:
	if body == null or target == null:
		return 999.0
	var want := _yaw_toward(body.global_position, target.global_position)
	return absf(rad_to_deg(angle_difference(want, body.rotation.y)))


## Whether a committed attack displaced the body. The enemy is measured where it stopped, and an
## attack is not allowed to move it - the same rule the player's committed actions obey.
func _attack_moved_the_body() -> bool:
	return _flat_speed(_attacker_body) > 0.35 and _attacker_loco.is_engaged()


# --- Checks -------------------------------------------------------------------

## AC2: the distance must fall and must not rise by more than the noise floor.
func _check_closing() -> void:
	if _samples.size() < 2:
		_fail("AC2 no distance samples were taken")
		return
	var first: float = _samples[0]
	var last: float = _samples[_samples.size() - 1]
	var worst_rise := 0.0
	for i in range(1, _samples.size()):
		worst_rise = maxf(worst_rise, float(_samples[i]) - float(_samples[i - 1]))
	_expect(last < first - 0.5,
		"AC2 the distance to the player strictly decreased (%.2f -> %.2f m)" % [first, last])
	_expect(worst_rise <= CLOSING_EPSILON,
		"AC2 and it never backed away during the approach (worst rise %.4f m)" % worst_rise)


## AC3, AC4, AC6, AC7: stopped at its own range, short of the threshold, never inside the capsule,
## facing the player, and reporting its own physics through ActorState.
func _finish_arrival() -> void:
	var distance := _attacker_loco.distance_to_target()
	var stop := _attacker_loco.stopping_distance()
	var engage := _attacker_loco.engage_range()
	_expect(distance <= engage + 0.25,
		"AC3 it stopped at its own engage_range (%.2f m, range %.2f)" % [distance, engage])
	_expect(distance >= stop - 0.3,
		"AC3 and stopped SHORT of the commit threshold (%.2f m, stop %.2f)" % [distance, stop])
	_expect(distance >= MIN_SEPARATION,
		"AC4 it never walked into the player's capsule (%.2f m apart)" % distance)
	_expect(_yaw_error_degrees(_attacker_body, _player) <= FACING_TOLERANCE_DEGREES,
		"AC6 its facing converged on the player (%.1f deg off)"
		% _yaw_error_degrees(_attacker_body, _player))
	if _attacker_state == null:
		_fail("AC7 the attacker has no ActorState")
	else:
		_expect(_attacker_state.has_ground_report(),
			"AC7 ActorState reports that a grounding answer is available for the enemy")
		_expect(_attacker_state.is_grounded(),
			"AC7 and reports the enemy grounded, which needs real body physics")
		_expect(absf(_attacker_state.facing_yaw() - _attacker_body.rotation.y) < 0.0001,
			"AC7 and ActorState.facing_yaw() reads the body's own yaw")
	_step = Step.JITTER
	_frame = 0
	_samples.clear()


## AC5: held still rather than cycling in and out of range.
func _check_jitter() -> void:
	if _samples.size() < 2:
		_fail("AC5 no jitter samples were taken")
		return
	var low: float = _samples[0]
	var high: float = _samples[0]
	for s in _samples:
		low = minf(low, float(s))
		high = maxf(high, float(s))
	_expect(high - low <= JITTER_BAND,
		"AC5 the stopped distance is stable, not jittering (band %.3f m over %d frames)"
		% [high - low, JITTER_FRAMES])
	_expect(_flat_speed(_attacker_body) < 0.35,
		"AC5 and the body is genuinely stopped (%.3f m/s)" % _flat_speed(_attacker_body))


## AC11: the adapter gained the intent this milestone makes reachable, and never invented one.
func _check_adapter() -> void:
	var adapters := get_tree().get_nodes_in_group(AnimationAdapter.GROUP_ANIMATION_ADAPTER)
	_expect(adapters.size() > 0, "AC11 animation adapters are present (%d)" % adapters.size())
	var vocabulary := AnimationAdapter.intent_vocabulary()
	for node in adapters:
		var adapter := node as AnimationAdapter
		if adapter == null:
			continue
		for value in adapter.history_values():
			if not vocabulary.has(String(value)):
				_fail("AC11 %s reported an intent outside its own vocabulary: %s"
					% [adapter.name, str(value)])
	_expect(_history_has_locomotion(adapters),
		"AC11 `locomotion` is now a reachable intent for an ENEMY, not only the player")


func _history_has_locomotion(adapters: Array) -> bool:
	for node in adapters:
		var adapter := node as AnimationAdapter
		if adapter == null:
			continue
		var actor := adapter.get_actor()
		if actor != _attacker_body and actor != _brute_body:
			continue
		if adapter.history_values().has(AnimationAdapter.INTENT_LOCOMOTION):
			_say("AC11 %s recorded: %s" % [adapter.name, str(adapter.history_values())])
			return true
	return false


## AC12: the accepted UI and lock-on behaviour is untouched by this milestone.
func _check_ui() -> void:
	if _bars == null:
		_fail("AC12 the enemy health bars module is unreachable")
	else:
		_expect(_bars.tracked_count() >= 2,
			"AC12 both enemies are still tracked by the health bars (%d)" % _bars.tracked_count())
		_expect(_bars.is_tracked(_attacker_body) and _bars.is_tracked(_brute_body),
			"AC12 and both are the ACTUAL actors, not a count that happens to match")
		# THE REVEAL RULE IS DELIBERATELY UNCHANGED. This milestone added an engagement authority
		# but did NOT wire it into what makes a bar appear, so an enemy that has never been damaged
		# and is not locked shows nothing. The brute has never been damaged in this run.
		_expect(not _bars.is_showing(_brute_body),
			"AC12 the reveal rule is unchanged: an undamaged, unlocked enemy shows NO bar")
	if _targeting == null:
		_fail("AC12 the targeting module is unreachable")
		return
	# Park the player where a target is inside acquire_range, then exercise the real toggle.
	_move_player(Vector3(0.0, 0.1, 12.0))
	_targeting.release()
	var acquired := _targeting.acquire()
	_expect(acquired and _targeting.is_locked(),
		"AC12 lock-on still acquires a target beside a MOVING enemy")
	var locked := _targeting.get_current_target()
	_expect(locked != null and is_instance_valid(locked),
		"AC12 and the locked target is a real actor")
	_targeting.release()
	_expect(not _targeting.is_locked(), "AC12 and releasing the lock clears it")


# --- Defeat -------------------------------------------------------------------

func _kill_attacker() -> void:
	if _attacker_hurtbox == null or _attacker_health == null:
		return
	_attacker_hurtbox.receive_hit(_lethal_event(_attacker_health.current_health + 50.0))
	_say("AC9 killed the attacker through the real hurtbox chain (health %.1f/%.1f)"
		% [_attacker_health.current_health, _attacker_health.max_health])
	_expect(_attacker_health.is_dead, "AC9 the lethal hit really landed")


func _lethal_event(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	event.source = _player
	return event


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[ENGAGEMENT]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ENGAGEMENT]   FAIL  %s" % label)


func _say(message: String) -> void:
	print("[ENGAGEMENT] %s" % message)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _attacker != null:
		_attacker.auto_attack = false
	if _brute_attacker != null:
		_brute_attacker.auto_attack = false
	print("[ENGAGEMENT] --- summary ---")
	print("[ENGAGEMENT] attacker speed=%.2f detect=%.1f | brute speed=%.2f detect=%.1f | peak %.2f vs %.2f"
		% [
			_attacker_loco.move_speed if _attacker_loco != null else -1.0,
			_attacker_loco.detection_radius() if _attacker_loco != null else -1.0,
			_brute_loco.move_speed if _brute_loco != null else -1.0,
			_brute_loco.detection_radius() if _brute_loco != null else -1.0,
			_peak_speed, _brute_peak_speed])
	if _failures.is_empty():
		print("[ENGAGEMENT] RESULT: ALL CHECKS PASSED")
	else:
		print("[ENGAGEMENT] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
