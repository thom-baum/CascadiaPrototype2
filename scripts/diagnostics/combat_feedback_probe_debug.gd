class_name CombatFeedbackProbeDebug
extends Node3D
## Temporary diagnostic (Milestone 18 - combat feedback). Not production.
##
## Measures THREE fixes against the REAL runtime, because all three are the kind of thing
## where a function can exist, be called, and still produce no observable effect.
##
##   1. HITSTOP. A confirmed hit must take a participant's per-frame callbacks away for a real
##      duration. This probe does NOT accept "the service ran": it starts a real enemy attack so
##      the phase clock is genuinely ADVANCING, lands a real hit through the real hitbox, and then
##      measures that the phase clock and the body position do NOT advance while frozen - and DO
##      advance again once it releases. The hit used here is deliberately BELOW the archetype's
##      interruption threshold, so the attack is still running while it is frozen; without that
##      the frozen clock would read 0.000 for the trivial reason that the attack was cancelled.
##   2. INTERRUPTION. A hit at or above an archetype's stagger threshold must CANCEL that enemy's
##      committed attack and close its damage window. Below the threshold it must not. The two
##      archetypes carry different thresholds, so the gradient is measured rather than assumed.
##   3. CREDIT RESET ON DEATH. Death must return the carried balance to the run's starting value
##      and clear the per-run reward history, while leaving the lifetime counters alone.
##
## Hits are delivered through the REAL chain: the player's AttackHitbox activates, sweeps, and
## reaches the enemy's HurtboxComponent -> HealthComponent -> the actor's own reaction component
## -> its attack state machine. Nothing here pokes the enemy's attack state directly.
##
## TWO MEASUREMENT HAZARDS, both of which produced FALSE FAILURES on earlier runs of this probe
## and are handled explicitly below. Do not remove either.
##
##   - A TELEPORT AND A HITBOX ACTIVATION IN THE SAME FRAME DO NOT HIT. An Area3D's overlaps are
##     refreshed by the physics server, so moving the player and calling activate() in one frame
##     sweeps against the PREVIOUS frame's overlaps. That is the same engine behaviour
##     `HitboxComponent`'s own header documents. The probe therefore POSITIONS in one step and
##     LANDS several frames later, never both at once.
##   - A WALKING ENEMY MAKES THE MEASUREMENT NONDETERMINISTIC. Milestone 17 gave enemies their
##     own locomotion, so an unconstrained enemy can walk out from under the hitbox mid-measurement.
##     Locomotion is disabled for the duration, exactly as `stand_down_all()` disables the arena's
##     attacks: a probe must isolate the system it measures from the one it is not measuring.
##     Interruption and hitstop are NOT locomotion concerns and this does not weaken either claim.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const SETTLE_FRAMES := 10
## Upper bound on freezing-observation frames. The probe stretches the hitstop duration so the
## window is unambiguous instead of racing the shipped 0.075 s effect.
const OBSERVE_FRAMES := 60
## Frames allowed after release for the phase clock to visibly move again.
const RESUME_FRAMES := 8
## Frames allowed for a re-enabled auto-attack to start, which is the recovery proof.
const RECOVER_FRAMES := 240
## Upper bound on waiting out the interrupted attack's authored cooldown.
const COOLDOWN_FRAMES := 200
## Hitstop duration used FOR THIS MEASUREMENT ONLY, so "did the clock stop" is measurable across
## several frames instead of one.
const MEASURE_DURATION := 0.25
## Hit BELOW every archetype's threshold: a real confirmed hit that must NOT interrupt, which is
## what leaves an attack running long enough to prove the freeze.
const SMALL_HIT := 5.0
## The player's real LIGHT attack damage (PlayerCombat.LIGHT_DAMAGE).
const LIGHT_HIT := 15.0
## The player's real HEAVY attack damage (PlayerCombat.HEAVY_DAMAGE).
const HEAVY_HIT := 32.0
## Where the player stands so the attack hitbox spans the enemy capsule.
const STAND_DISTANCE := 1.8
## Lethal damage for the death-path checks.
const LETHAL := 9999.0
## How far a frozen actor may drift before the freeze was not a freeze.
const FROZEN_DRIFT := 0.001
## How far the phase clock may move while frozen.
const FROZEN_PHASE_SLACK := 0.001
## How little the phase clock may move after release to still count as resumed.
const RESUME_MIN := 0.002

enum Step {
	SETUP,
	HITSTOP_POSITION, HITSTOP_LAND, HITSTOP_BEGIN, HITSTOP_OBSERVE, HITSTOP_ASSERT, HITSTOP_RESUME,
	INTERRUPT_POSITION, INTERRUPT_LAND, INTERRUPT_ASSERT,
	RECOVER_ARM, RECOVER_ASSERT,
	THRESHOLD_POSITION, THRESHOLD_LAND, THRESHOLD_ASSERT,
	EARN, KILL_PLAYER, CREDIT_ASSERT, DONE,
}

var _player: CharacterBody3D
var _player_health: HealthComponent
var _player_hitbox: HitboxComponent

var _attacker_body: CharacterBody3D
var _attacker: EnemyAttacker
var _attacker_health: HealthComponent
var _attacker_hurtbox: HurtboxComponent

var _brute_body: CharacterBody3D
var _brute: EnemyAttacker
var _brute_health: HealthComponent
var _brute_hurtbox: HurtboxComponent

var _ledger: CreditLedger
var _hit_stop: HitStop

var _step: int = Step.SETUP
var _frame := 0
var _done := false
var _failures: Array = []

## Freeze measurement.
var _frozen_frames := 0
var _phase_at_freeze := 0.0
var _phase_min := 0.0
var _phase_before_hit := 0.0
var _pos_at_freeze := Vector3.ZERO
var _max_frozen_drift := 0.0
var _freezes_before := 0
var _releases_before := 0
var _clock_ok := true
var _pause_ok := true

## Interruption measurement.
var _interrupted_before := 0
var _started_before := 0
var _brute_interrupted_before := 0
var _brute_started := false
var _health_before_hit := 0.0
var _balance_after_earn := 0
var _pending_awards := 0


func _ready() -> void:
	_resolve()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	match _step:
		Step.SETUP:
			_do_setup()
		Step.HITSTOP_POSITION:
			if _frame == 1:
				_stand_in_front(_attacker_body)
			if _frame >= SETTLE_FRAMES:
				_step = Step.HITSTOP_LAND
				_frame = 0
		Step.HITSTOP_LAND:
			_land(SMALL_HIT, Step.HITSTOP_BEGIN)
		Step.HITSTOP_BEGIN:
			_begin_freeze_measurement()
		Step.HITSTOP_OBSERVE:
			_observe_freeze()
		Step.HITSTOP_ASSERT:
			_assert_freeze()
		Step.HITSTOP_RESUME:
			if _frame >= RESUME_FRAMES:
				_assert_resumed()
		Step.INTERRUPT_POSITION:
			if _frame == 1:
				# End whatever the freeze test left running, then reposition and let the
				# physics server register the move before anything activates.
				_attacker.cancel_attack()
				_stand_in_front(_attacker_body)
			if _frame >= SETTLE_FRAMES:
				_step = Step.INTERRUPT_LAND
				_frame = 0
		Step.INTERRUPT_LAND:
			_interrupted_before = _attacker.attacks_interrupted
			_land(HEAVY_HIT, Step.INTERRUPT_ASSERT)
		Step.INTERRUPT_ASSERT:
			_assert_interrupt()
		Step.RECOVER_ARM:
			_started_before = _attacker.attacks_started
			_attacker.auto_attack = true
			_step = Step.RECOVER_ASSERT
			_frame = 0
		Step.RECOVER_ASSERT:
			if _attacker.attacks_started > _started_before:
				_attacker.auto_attack = false
				_expect(true, "AC7 the interrupted enemy RECOVERED and started a new attack")
				_step = Step.THRESHOLD_POSITION
				_frame = 0
			elif _frame >= RECOVER_FRAMES:
				_attacker.auto_attack = false
				_fail("AC7 the interrupted enemy never attacked again within %d frames" % RECOVER_FRAMES)
				_step = Step.THRESHOLD_POSITION
				_frame = 0
		Step.THRESHOLD_POSITION:
			if _frame == 1:
				_attacker.cancel_attack()
				_brute.cancel_attack()
				_stand_in_front(_brute_body)
			if _frame >= SETTLE_FRAMES:
				_step = Step.THRESHOLD_LAND
				_frame = 0
		Step.THRESHOLD_LAND:
			_brute_interrupted_before = _brute.attacks_interrupted
			_land_brute(LIGHT_HIT)
		Step.THRESHOLD_ASSERT:
			_assert_threshold()
		Step.EARN:
			_earn_credits()
		Step.KILL_PLAYER:
			_kill_player()
		Step.CREDIT_ASSERT:
			_assert_credit_reset()
		Step.DONE:
			_finish()


# --- Setup --------------------------------------------------------------------

func _do_setup() -> void:
	if not _failures.is_empty():
		_finish()
		return
	# The arena must not be swinging at the player while the probe measures one exchange.
	EnemyAttacker.stand_down_all(get_tree())
	# ISOLATION, stated rather than hidden: locomotion is disabled for the measurement so a walking
	# enemy cannot drift out from under the hitbox between positioning and the hit. This probe
	# measures HITSTOP and INTERRUPTION, neither of which is a locomotion concern.
	_disable_locomotion(_attacker_body)
	_disable_locomotion(_brute_body)
	_expect(_hit_stop.enabled, "AC1 the hitstop service is enabled")
	_hit_stop.duration = MEASURE_DURATION
	_say("AC1 hitstop duration set to %.3f s for measurement; hitboxes=%d" % [
		MEASURE_DURATION,
		get_tree().get_nodes_in_group(HitboxComponent.GROUP_HITBOX).size()])
	_step = Step.HITSTOP_POSITION
	_frame = 0


func _disable_locomotion(body: CharacterBody3D) -> void:
	var loco := body.get_node_or_null("Locomotion")
	if loco == null:
		return
	if loco.has_method("set_physics_process"):
		loco.call("set_physics_process", false)
	_say("AC1 locomotion disabled on %s so it cannot walk mid-measurement" % body.name)


## Stand the player in front of an enemy, facing it, so the player's own attack hitbox spans that
## enemy's capsule. The facing convention is the project's: a body at rotation.y = 0 faces -Z, so
## the direction an actor faces is -basis.z. CALLER MUST ALLOW FRAMES TO PASS BEFORE ACTIVATING.
func _stand_in_front(enemy: CharacterBody3D) -> void:
	var facing := -enemy.global_transform.basis.z
	_player.global_position = enemy.global_position + facing * STAND_DISTANCE + Vector3(0.0, 0.05, 0.0)
	var to_enemy := enemy.global_position - _player.global_position
	to_enemy.y = 0.0
	if to_enemy.length_squared() > 0.0001:
		_player.rotation.y = atan2(-to_enemy.x, -to_enemy.z)
	# Zero any residual motion so the player does not coast through the enemy after the teleport.
	_player.velocity = Vector3.ZERO


## Commit the enemy's own attack, then land a real hit on it, then continue at `next_step`.
## Order matters: the attack must be RUNNING before the hit, so there is a live phase clock to
## freeze and a committed action to interrupt.
func _land(amount: float, next_step: int) -> void:
	var started := _attacker.try_start()
	_expect(started, "AC2 the attacker committed an attack")
	_phase_before_hit = _attacker.phase_remaining()
	if started:
		_expect(_phase_before_hit > 0.0,
			"AC2 its phase clock was genuinely running before the hit (%.3f s left)"
			% _phase_before_hit)
	_health_before_hit = _attacker_health.current_health
	# The freeze counter is read BEFORE the hit: `hit_landed` starts the freeze synchronously inside
	# the hitbox sweep, so reading it afterwards would capture the already-incremented value and the
	# "was it counted" check could never pass.
	_freezes_before = _hit_stop.freezes
	_land_hit(amount)
	var landed := _attacker_health.current_health < _health_before_hit
	_expect(landed, "AC2 the hit genuinely landed (health %.0f -> %.0f)" % [
		_health_before_hit, _attacker_health.current_health])
	_say("AC2 landed a %.0f damage hit on the attacker" % amount)
	_step = next_step
	_frame = 0


func _land_brute(amount: float) -> void:
	var started := _brute.try_start()
	_brute_started = started
	_expect(started, "AC6 the brute committed an attack")
	_health_before_hit = _brute_health.current_health
	_land_hit(amount)
	var landed := _brute_health.current_health < _health_before_hit
	_expect(landed, "AC6 the hit genuinely landed on the brute (health %.0f -> %.0f)" % [
		_health_before_hit, _brute_health.current_health])
	_say("AC6 landed a %.0f damage hit on the brute (threshold %.0f)" % [
		amount, _brute_threshold()])
	_step = Step.THRESHOLD_ASSERT
	_frame = 0


## Open the player's real attack window for one frame and close it again. `activate()` performs the
## overlap sweep synchronously, which is why the caller must have let the teleport settle first.
func _land_hit(amount: float) -> void:
	_player_hitbox.damage = amount
	_player_hitbox.activate()
	_player_hitbox.deactivate()


# --- Hitstop ------------------------------------------------------------------

## Capture the reference readings on the frame the freeze is active, so the observation below is
## measured against what the actor was actually doing rather than a guess.
func _begin_freeze_measurement() -> void:
	_releases_before = _hit_stop.releases
	if not _hit_stop.is_frozen():
		_fail("AC2 a confirmed hit did NOT start a hitstop")
		_step = Step.HITSTOP_ASSERT
		_frame = 0
		return
	_phase_at_freeze = _attacker.phase_remaining()
	_phase_min = _phase_at_freeze
	_pos_at_freeze = _attacker_body.global_position
	_max_frozen_drift = 0.0
	_frozen_frames = 0
	_say("AC2 hitstop started: frozen=%d, phase remaining=%.3f s, attacking=%s, clocks scale=%.1f paused=%s" % [
		_hit_stop.frozen_count(), _phase_at_freeze, str(_attacker.is_attacking()),
		Engine.time_scale, str(get_tree().paused)])
	_step = Step.HITSTOP_OBSERVE
	_frame = 0


## Sample ONLY while the freeze is active. Accumulating outside it would measure ordinary gameplay
## and prove nothing.
func _observe_freeze() -> void:
	if _hit_stop.is_frozen():
		_frozen_frames += 1
		_phase_min = minf(_phase_min, _attacker.phase_remaining())
		_max_frozen_drift = maxf(_max_frozen_drift,
			_attacker_body.global_position.distance_to(_pos_at_freeze))
		if not is_equal_approx(Engine.time_scale, 1.0):
			_clock_ok = false
		if get_tree().paused:
			_pause_ok = false
	if _hit_stop.is_frozen() and _frame < OBSERVE_FRAMES:
		return
	_step = Step.HITSTOP_ASSERT
	_frame = 0


func _assert_freeze() -> void:
	if _hit_stop.is_frozen():
		_hit_stop.release_now()
	_say("AC2 observed %d frozen frame(s), drift %.4f m, phase moved %.4f s" % [
		_frozen_frames, _max_frozen_drift, absf(_phase_at_freeze - _phase_min)])
	# The freeze was REAL, not merely a counter.
	_expect(_phase_before_hit > 0.0,
		"AC2 the attack was still RUNNING when it was frozen, so the clock measurement is real")
	_expect(_frozen_frames >= 3,
		"AC2 the freeze lasted several frames (%d frames observed)" % _frozen_frames)
	_expect(absf(_phase_at_freeze - _phase_min) <= FROZEN_PHASE_SLACK,
		"AC2 the enemy's attack phase clock did NOT advance while frozen (moved %.4f s)"
		% absf(_phase_at_freeze - _phase_min))
	_expect(_max_frozen_drift <= FROZEN_DRIFT,
		"AC2 the enemy body did NOT move while frozen (drifted %.4f m)" % _max_frozen_drift)
	_expect(_hit_stop.freezes > _freezes_before,
		"AC2 the hitstop was counted (%d freezes)" % _hit_stop.freezes)
	# Neither forbidden mechanism was used.
	_expect(_clock_ok, "AC3 Engine.time_scale stayed exactly 1.0 for the whole freeze")
	_expect(_pause_ok, "AC3 the tree was never paused for the freeze")
	# It released and left nothing disabled.
	_expect(not _hit_stop.is_frozen(), "AC4 the freeze ended within the observation window")
	_expect(_hit_stop.frozen_count() == 0, "AC4 no participant is left in the frozen set")
	_expect(_hit_stop.releases > _releases_before,
		"AC4 the release was counted (%d releases)" % _hit_stop.releases)
	_expect(_player.is_physics_processing(), "AC4 the PLAYER's physics processing was restored")
	_expect(_attacker_body.is_physics_processing(),
		"AC4 the enemy's physics processing was restored")
	_expect(_player.process_mode == Node.PROCESS_MODE_INHERIT,
		"AC4 the player's process_mode was never changed (still INHERIT)")
	_expect(_attacker_body.process_mode == Node.PROCESS_MODE_INHERIT,
		"AC4 the enemy's process_mode was never changed (still INHERIT)")
	_step = Step.HITSTOP_RESUME
	_frame = 0


## The clock must genuinely RESUME. Measured a few frames AFTER the release rather than on the
## release frame, where the attack has not had a chance to advance yet.
func _assert_resumed() -> void:
	var now := _attacker.phase_remaining()
	_say("AC4 phase clock after release: %.3f -> %.3f s" % [_phase_at_freeze, now])
	_expect(_attacker.is_attacking(),
		"AC4 the attack is still running, so the freeze did not cancel it")
	_expect(_phase_at_freeze - now >= RESUME_MIN,
		"AC4 the phase clock RESUMED after release (advanced %.4f s)" % (_phase_at_freeze - now))
	_say("AC4 release verified: player physics=%s enum=%d" % [
		str(_player.is_physics_processing()), _player.process_mode])
	_step = Step.INTERRUPT_POSITION
	_frame = 0


# --- Interruption -------------------------------------------------------------

func _assert_interrupt() -> void:
	var cancelled := not _attacker.is_attacking()
	var window_closed := not _attacker.hitbox_is_open()
	_say("AC5 after a %.0f damage hit: attacking=%s window_open=%s interrupted=%d" % [
		HEAVY_HIT, str(_attacker.is_attacking()), str(_attacker.hitbox_is_open()),
		_attacker.attacks_interrupted - _interrupted_before])
	_expect(cancelled, "AC5 a heavy hit CANCELLED the enemy's committed attack")
	_expect(window_closed,
		"AC5 and its damage window was CLOSED, so the stale attack cannot deal damage")
	_expect(_attacker.attacks_interrupted > _interrupted_before,
		"AC5 the interruption was counted as an interruption and not as a completed attack")
	_step = Step.RECOVER_ARM
	_frame = 0


# --- Threshold gradient --------------------------------------------------------

func _attacker_threshold() -> float:
	var reaction := _attacker_body.get_node_or_null("Reaction")
	if reaction == null:
		return -1.0
	return float(reaction.get("stagger_threshold"))


func _brute_threshold() -> float:
	var reaction := _brute_body.get_node_or_null("Reaction")
	if reaction == null:
		return -1.0
	return float(reaction.get("stagger_threshold"))


func _assert_threshold() -> void:
	var attacker_threshold := _attacker_threshold()
	var brute_threshold := _brute_threshold()
	_say("AC6 archetype thresholds: attacker=%.0f brute=%.0f" % [
		attacker_threshold, brute_threshold])
	_expect(attacker_threshold > 0.0 and brute_threshold > 0.0,
		"AC6 both enemy archetypes declare a real interruption threshold")
	_expect(brute_threshold != attacker_threshold,
		"AC6 the two archetypes carry DIFFERENT thresholds, so this is data-driven (%.0f vs %.0f)"
		% [attacker_threshold, brute_threshold])
	_expect(HEAVY_HIT >= attacker_threshold,
		"AC6 the heavy hit is at or above the lighter archetype's threshold (%.0f >= %.0f)"
		% [HEAVY_HIT, attacker_threshold])
	_expect(LIGHT_HIT < brute_threshold,
		"AC6 the light hit is BELOW the heavier archetype's threshold (%.0f < %.0f)"
		% [LIGHT_HIT, brute_threshold])
	_expect(_brute.attacks_interrupted == _brute_interrupted_before,
		"AC6 a below-threshold hit did NOT interrupt the heavier archetype")
	if _brute_started:
		_expect(_brute.is_attacking(),
			"AC6 and its committed attack is STILL RUNNING, exactly as an uninterruptible swing should")
	_step = Step.EARN
	_frame = 0


# --- Credits ------------------------------------------------------------------

## Earn Credits through the REAL defeat chain, so the balance under test was produced by the
## project's own reward path rather than assigned by the probe.
func _earn_credits() -> void:
	var before := _ledger.get_credits()
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = _player
	_brute_hurtbox.receive_hit(event)
	_balance_after_earn = _ledger.get_credits()
	_say("AC8 earned Credits through the real defeat chain: %d -> %d (awards=%d)" % [
		before, _balance_after_earn, _ledger.awards])
	_expect(_balance_after_earn > _ledger.starting_credits,
		"AC8 the defeat paid Credits into the carried balance (%d)" % _balance_after_earn)
	_expect(_ledger.rewarded_count() > 0,
		"AC8 the rewarded-enemy history is populated before the death (%d)" % _ledger.rewarded_count())
	_step = Step.KILL_PLAYER
	_frame = 0


func _kill_player() -> void:
	_pending_awards = _ledger.awards
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = null
	_player_health.apply_damage(event)
	_say("AC9 killed the player through its own health chain (is_dead=%s)" %
		str(_player_health.is_dead))
	_step = Step.CREDIT_ASSERT
	_frame = 0


func _assert_credit_reset() -> void:
	_expect(_player_health.is_dead, "AC9 the lethal hit really landed on the player")
	_expect(_ledger.reset_on_death, "AC9 the ledger is configured to reset on death")
	_expect(_ledger.death_resets > 0, "AC9 death actually reached the ledger (%d resets)"
		% _ledger.death_resets)
	_expect(_ledger.get_credits() == _ledger.starting_credits,
		"AC9 death returned the carried balance to the run's starting value (%d, was %d)"
		% [_ledger.get_credits(), _balance_after_earn])
	_expect(_ledger.rewarded_count() == 0,
		"AC9 death CLEARED the per-run reward history, so revived enemies are worth Credits again")
	_expect(_ledger.awards == _pending_awards,
		"AC9 the LIFETIME award counter was left alone (%d) - only per-run state was reset"
		% _ledger.awards)
	_step = Step.DONE
	_frame = 0


# --- Resolution ---------------------------------------------------------------

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
	_ledger = main.get_node_or_null("CreditLedger") as CreditLedger
	_hit_stop = HitStop.find_hit_stop(get_tree())

	if _player == null:
		_fail("the arena has no Player")
		return
	if _attacker_body == null or _brute_body == null:
		_fail("the arena is missing an enemy archetype")
		return
	if _ledger == null:
		_fail("no CreditLedger in the tree")
		return

	_player_health = _player.get_node_or_null("Health") as HealthComponent
	_player_hitbox = _player.get_node_or_null("AttackHitbox") as HitboxComponent
	_attacker = _attacker_body.get_node_or_null("Attacker") as EnemyAttacker
	_attacker_health = _attacker_body.get_node_or_null("Health") as HealthComponent
	_attacker_hurtbox = _attacker_body.get_node_or_null("Hurtbox") as HurtboxComponent
	_brute = _brute_body.get_node_or_null("Attacker") as EnemyAttacker
	_brute_health = _brute_body.get_node_or_null("Health") as HealthComponent
	_brute_hurtbox = _brute_body.get_node_or_null("Hurtbox") as HurtboxComponent

	if _player_health == null or _player_hitbox == null:
		_fail("the player is missing its Health or AttackHitbox")
	if _player.get_node_or_null("Death") == null:
		_fail("the player has no Death circuit")
	if _attacker == null or _brute == null:
		_fail("an enemy is missing its Attacker")
	if _attacker_health == null or _brute_health == null:
		_fail("an enemy is missing its Health")
	if _attacker_hurtbox == null or _brute_hurtbox == null:
		_fail("an enemy is missing its Hurtbox")
	if _hit_stop == null:
		_fail("no HitStop service in the tree - the hitstop fix is not wired")
	_say("resolved: player=%s attacker=%s brute=%s ledger=%s hitstop=%s" % [
		_player.name, _attacker_body.name, _brute_body.name,
		_ledger.name, str(_hit_stop != null)])


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[COMBATFX]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[COMBATFX]   FAIL  %s" % label)


func _say(message: String) -> void:
	print("[COMBATFX] %s" % message)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[COMBATFX] --- summary ---")
	print("[COMBATFX] hitstop freezes=%d releases=%d extensions=%d | attacker interrupted=%d | balance=%d" % [
		_hit_stop.freezes if _hit_stop != null else -1,
		_hit_stop.releases if _hit_stop != null else -1,
		_hit_stop.extensions if _hit_stop != null else -1,
		_attacker.attacks_interrupted if _attacker != null else -1,
		_ledger.get_credits() if _ledger != null else -1])
	if _failures.is_empty():
		print("[COMBATFX] RESULT: ALL CHECKS PASSED")
	else:
		print("[COMBATFX] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
