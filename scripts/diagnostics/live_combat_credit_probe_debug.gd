class_name LiveCombatCreditProbeDebug
extends Node3D
## Temporary diagnostic (Milestone 18 follow-up). Not production.
##
## WHY THIS EXISTS, and why `combat_feedback_probe_debug` was not enough.
##
## That probe proves hitstop, interruption and the death credit reset all work when it drives them
## ITSELF: it calls `stand_down_all()` to switch every enemy's auto-attack off, disables each
## enemy's `Locomotion`, and opens the player's damage window by calling
## `PlayerCombat`'s hitbox `activate()` DIRECTLY. Every one of those is a deliberate isolation, and
## each isolation removes a link that exists in the live game.
##
## The link this probe restores is the important one: THE PLAYER'S OWN ATTACK STATE MACHINE. In live
## play a hit is produced by `PlayerCombat.try_start()` and its own STARTUP -> ACTIVE phase advance,
## never by a direct `activate()`. If the real attack path and the directly-opened hitbox behave
## differently, the existing probe cannot see it, because it never uses the real path.
##
## So this probe measures the same three behaviours with NOTHING stood down and NOTHING neutered:
##
##   1. HITSTOP. The player attacks a real, auto-attacking enemy through `PlayerCombat`. The
##      measurement is that the two participant SUBTREES genuinely lose their per-frame callbacks,
##      that the enemy's attack phase clock really stops, and that it resumes afterwards.
##   2. INTERRUPTION. The player's real LIGHT attack lands during a real committed swing. The
##      measurement is on the enemy's own attack state machine: phase back to IDLE, damage window
##      CLOSED, telegraph hidden, and the enemy able to act again afterwards.
##   3. CREDIT RESET. A real defeat earns Credits through the real chain, then a real lethal hit
##      kills the player through the real hurtbox, and the carried balance must return to the run's
##      starting value.
##
## THE ARCHETYPE CHOICE IS DELIBERATE. The interrupt measurement uses `TestAttacker`
## (threshold 12.0), which a 15 damage LIGHT hit must interrupt. The hitstop measurement uses
## `HeavyBrute` (threshold 20.0), which the same LIGHT hit must NOT interrupt - so its attack is
## still running while the freeze happens and the phase clock is a live reading rather than a
## cancelled one. Using the same hit for both is what keeps the two claims from contaminating
## each other.
##
## This probe writes NO report file; its output is console only.

## Frames allowed for a real attack to travel from try_start() to the moment damage lands.
const ATTACK_FRAME_BUDGET := 90
## Frames allowed for an armed enemy swing to actually commit.
const ARM_FRAME_BUDGET := 30
## Frames to watch the measured freeze for before moving on. Generously longer than the product's
## own duration so a freeze that FAILS to end is observed as a failure rather than missed.
const OBSERVE_FRAMES := 60
## Quiet frames to wait AFTER the measured freeze ends before asserting that nothing was left
## disabled. The wait is the point: checking on the release frame would read a second, legitimate
## freeze - the arena is live, and every one of its hits starts its own hitstop.
const SETTLE_FRAMES := 20
## The player's real LIGHT attack damage (PlayerCombat.LIGHT_DAMAGE).
const LIGHT_HIT := 15.0
## Damage used for the lethal blows, high enough to defeat in one application.
const LETHAL := 9999.0
## Stand-off distance: the existing probe's proven value.
const STAND_DISTANCE := 1.8
## A frozen body may not drift more than this, in metres.
const FROZEN_DRIFT := 0.001
## A frozen attack phase clock may not advance more than this, in seconds.
const FROZEN_PHASE_SLACK := 0.001
## The phase clock must advance at least this much after release.
const RESUME_MIN := 0.002
## Frames to watch for the interrupted enemy becoming able to act again.
const RECOVER_FRAMES := 200

enum Step {
	SETUP, SETTLE,
	HIT_POSITION, HIT_ARM, HIT_ATTACK, HIT_WAIT, HIT_ASSERT, HIT_SETTLE,
	INT_POSITION, INT_ARM, INT_ATTACK, INT_WAIT, INT_ASSERT, INT_RECOVER,
	EARN_POSITION, EARN_HIT, EARN_ASSERT,
	KILL_HIT, CREDIT_ASSERT,
	DONE
}

var _main: Node3D
var _env: Node3D
var _player: CharacterBody3D
var _player_combat: PlayerCombat
var _player_hitbox: HitboxComponent
var _player_health: HealthComponent
var _player_death: Node
var _attacker_body: CharacterBody3D
var _attacker: EnemyAttacker
var _attacker_health: HealthComponent
var _attacker_hitbox: HitboxComponent
var _attacker_telegraph: Node3D
var _brute_body: CharacterBody3D
var _brute: EnemyAttacker
var _brute_health: HealthComponent
var _hit_stop: HitStop
var _ledger: CreditLedger

var _step: int = Step.SETUP
var _frame := 0
var _passed := 0
var _failed := 0
## Every failed check's label, printed again in the summary, because the console tail is truncated
## and a truncated transcript must never be the reason a failure goes unread.
var _failure_labels: Array[String] = []
var _notes: Array[String] = []

# --- hitstop readings
var _freezes_before := 0
var _releases_before := 0
var _health_before := 0.0
var _phase_at_freeze := 0.0
var _phase_min := 0.0
## The enemy's phase NAME when the baseline was taken. `phase_remaining()` is DISCONTINUOUS across a
## phase boundary - windup with 0.88 s left becomes active with 0.16 s left in a single frame - so a
## reading that only compared remaining-seconds would report a 0.72 s "advance" for an enemy that
## never processed at all. The name is what makes the comparison honest.
var _phase_name_at_freeze := ""
## Set once the measured freeze has ended and nothing matching it is running.
var _freeze_ended_frame := -1
var _pos_at_freeze := Vector3.ZERO
var _max_drift := 0.0
var _frozen_frames := 0
var _player_frozen_during := false
var _brute_frozen_during := false
var _scale_ok := true
var _pause_ok := true
var _duration_used := 0.0
## Set if the enemy changed PHASE while the freeze was running, which would mean it processed.
var _phase_transitioned_during_freeze := false
## Release-state readings, captured by `_settle_freeze()` AFTER the measured freeze has ended and the
## arena has run quiet frames again. "It released" and "nothing was left disabled" are properties of
## the state after the freeze, so they are captured there rather than read from inside it.
var _end_frozen_count := -1
var _end_released := false
var _end_restored := false
var _end_clock_running := false
var _end_attacking := false
var _end_phase := 0.0
var _end_brute_interrupted := -1
var _end_state_name := ""
var _end_player_attacks := 0

# --- interruption readings
var _interrupted_before := 0
var _player_attack_started := false
var _player_path_opened := false
var _brute_still_attacking := false
var _recovered := false
## Set once this probe has given the measured enemy its auto-attack cadence back for the recovery
## check, so the re-arm happens exactly once.
var _recovery_armed := false


func _ready() -> void:
	# The game root is a SIBLING of this probe, not a child: the run scene instances main.tscn
	# beside the probe so the probe is never itself inside the tree it measures.
	_main = get_node_or_null("../Main") as Node3D
	_resolve()
	_step = Step.SETTLE
	_frame = 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _step:
		Step.SETTLE:
			# Let every _ready() in the arena run before anything is measured. Tree order puts
			# HitStop BEFORE TestEnvironment, so this is also what lets its hitbox scan land.
			if _frame >= 5:
				_do_setup()
		Step.HIT_POSITION:
			_stand_in_front(_brute_body)
			_advance_to(Step.HIT_ARM)
		Step.HIT_ARM:
			_arm_brute()
		Step.HIT_ATTACK:
			# QUIET THE ONLY COMPETING SOURCE OF A FREEZE, and nothing else. Enemies keep their
			# locomotion and any swing already committed; only auto-attack is switched off, for this
			# one measurement. Reason, MEASURED on an earlier run of this probe: an enemy that lands
			# a hit on the PLAYER starts a SECOND, perfectly legitimate hitstop, so a probe that
			# asserts "the freeze ended / both participants were restored" while that second freeze
			# is running reads the wrong freeze and reports a stall that never happened. What must
			# stay real is the PLAYER'S ATTACK PATH, and it does - that is the link under test.
			EnemyAttacker.stand_down_all(get_tree())
			_start_player_attack()
		Step.HIT_WAIT:
			if _player_attack_landed():
				_begin_freeze_measurement()
			elif _frame > ATTACK_FRAME_BUDGET:
				_fail("AC1 the player's REAL attack never landed on the brute within %d frames"
					% ATTACK_FRAME_BUDGET)
				_advance_to(Step.INT_POSITION)
		Step.HIT_ASSERT:
			_observe_freeze()
		Step.HIT_SETTLE:
			_settle_freeze()
		Step.INT_POSITION:
			_stand_in_front(_attacker_body)
			_advance_to(Step.INT_ARM)
		Step.INT_ARM:
			_arm_attacker()
		Step.INT_ATTACK:
			_start_player_attack()
		Step.INT_WAIT:
			if _player_attack_landed():
				_assert_interrupt()
			elif _frame > ATTACK_FRAME_BUDGET:
				_fail("AC4 the player's REAL attack never landed on the attacker within %d frames"
					% ATTACK_FRAME_BUDGET)
				_advance_to(Step.EARN_POSITION)
		Step.INT_RECOVER:
			_watch_recovery()
		Step.EARN_POSITION:
			_stand_in_front(_attacker_body)
			_advance_to(Step.EARN_HIT)
		Step.EARN_HIT:
			_earn_credits()
		Step.EARN_ASSERT:
			_assert_earned()
		Step.KILL_HIT:
			_kill_player()
		Step.CREDIT_ASSERT:
			_assert_credit_reset()
		Step.DONE:
			pass


# --- Setup --------------------------------------------------------------------

func _do_setup() -> void:
	_notes.clear()
	_expect(_main != null, "AC0 the live game root was instanced")
	_expect(_hit_stop != null, "AC0 the HitStop service is present in the live tree")
	_expect(_ledger != null, "AC0 the CreditLedger service is present in the live tree")
	_expect(_player_combat != null, "AC0 the player's real PlayerCombat state machine resolved")
	_expect(_player_hitbox != null, "AC0 the player's real attack hitbox resolved")
	_expect(_attacker != null and _brute != null, "AC0 both real enemy archetypes resolved")
	if _hit_stop == null or _ledger == null or _player_combat == null or _player_hitbox == null \
			or _attacker == null or _brute == null:
		_finish()
		return

	# NOTHING is stood down and NOTHING is disabled. This is the whole point of this probe: the
	# live arena keeps its auto-attack and its locomotion running throughout.
	_say("AC0 live conditions: auto_attack ON, locomotion ON, nothing stood down")
	_say("AC0 hitstop duration in the product: %.3f s" % _hit_stop.duration)
	_duration_used = _hit_stop.duration
	_say("AC0 attacker=%.0f threshold, brute=%.0f threshold"
		% [_threshold(_attacker), _threshold(_brute)])
	_say("AC0 player light attack: %.2f dmg, startup %.2f s, active %.2f s" % [
		_player_combat.light_attack.damage,
		_player_combat.light_attack.startup,
		_player_combat.light_attack.active])
	_advance_to(Step.HIT_POSITION)


func _resolve() -> void:
	if _main == null:
		return
	_env = _main.get_node_or_null("TestEnvironment") as Node3D
	if _env == null:
		return
	_player = _env.get_node_or_null("Player") as CharacterBody3D
	if _player != null:
		_player_combat = _player.get_node_or_null("Combat") as PlayerCombat
		_player_hitbox = _player.get_node_or_null("AttackHitbox") as HitboxComponent
		_player_health = _player.get_node_or_null("Health") as HealthComponent
		_player_death = _player.get_node_or_null("Death")
	_attacker_body = _env.get_node_or_null("TestAttacker") as CharacterBody3D
	if _attacker_body != null:
		_attacker = _attacker_body.get_node_or_null("Attacker") as EnemyAttacker
		_attacker_health = _attacker_body.get_node_or_null("Health") as HealthComponent
		_attacker_hitbox = _attacker_body.get_node_or_null("AttackHitbox") as HitboxComponent
		_attacker_telegraph = _attacker_body.get_node_or_null("Telegraph") as Node3D
	_brute_body = _env.get_node_or_null("HeavyBrute") as CharacterBody3D
	if _brute_body != null:
		_brute = _brute_body.get_node_or_null("Attacker") as EnemyAttacker
		_brute_health = _brute_body.get_node_or_null("Health") as HealthComponent
	_hit_stop = HitStop.find_hit_stop(get_tree())
	_ledger = CreditLedger.find_ledger(get_tree())


## Turn debug logging on for the systems under measurement, so the console carries the product's own
## account of what it did alongside this probe's readings.
func _enable_logging() -> void:
	if _hit_stop != null:
		_hit_stop.debug_logging = true
	if _attacker != null:
		_attacker.debug_logging = true
	if _brute != null:
		_brute.debug_logging = true


# --- Hitstop ------------------------------------------------------------------

## Put the player in front of an enemy, facing it, on the project's facing convention: a body at
## rotation.y = 0 faces -Z, so the direction it faces is -basis.z.
func _stand_in_front(enemy: CharacterBody3D) -> void:
	if enemy == null or _player == null:
		return
	var facing := -enemy.global_transform.basis.z
	_player.global_position = enemy.global_position + facing * STAND_DISTANCE + Vector3(0.0, 0.05, 0.0)
	var to_enemy := enemy.global_position - _player.global_position
	to_enemy.y = 0.0
	if to_enemy.length_squared() > 0.0001:
		_player.rotation.y = atan2(-to_enemy.x, -to_enemy.z)
	_player.velocity = Vector3.ZERO


## Commit the brute's own swing. The brute is used for the hitstop reading precisely BECAUSE a
## 15 damage light hit is below its 20 threshold, so the swing survives the hit and its phase clock
## stays a live reading while the freeze is running.
func _arm_brute() -> void:
	if _brute == null:
		_advance_to(Step.HIT_ATTACK)
		return
	if _frame > ARM_FRAME_BUDGET:
		_fail("AC1 the brute never committed a swing to freeze (%d frames)" % ARM_FRAME_BUDGET)
		_advance_to(Step.INT_POSITION)
		return
	# Standing still is not a precondition - the brute may be walking in. The swing is what matters.
	if _brute.is_attacking():
		_expect(_brute.hitbox_is_open() or _brute.phase_remaining() > 0.0,
			"AC1 the brute's attack phase clock was genuinely running (%.3f s left)"
			% _brute.phase_remaining())
		_say("AC1 the brute committed a swing on its own (attacking=%s, %.3f s left)"
			% [str(_brute.is_attacking()), _brute.phase_remaining()])
		_advance_to(Step.HIT_ATTACK)
		return
	if _brute.try_start():
		_advance_to(Step.HIT_ATTACK)


## Drive the player's REAL attack state machine. Nothing is opened by hand: `try_start()` is the one
## way an attack begins, and its own phase advance is what opens the damage window. This is the link
## the previous probe replaced with a direct `activate()`.
func _start_player_attack() -> void:
	_freezes_before = _hit_stop.freezes
	_releases_before = _hit_stop.releases
	if _brute_health != null and _step == Step.HIT_ATTACK:
		_health_before = _brute_health.current_health
	elif _attacker_health != null:
		_health_before = _attacker_health.current_health
	if _step == Step.HIT_ATTACK:
		_enable_logging()
	_player_attack_started = _player_combat.try_start(_player_combat.light_attack)
	_expect(_player_attack_started,
		"AC1 the player's REAL attack state machine accepted a light attack (state=%s)"
		% _player_combat.state_name())
	if not _player_attack_started:
		_fail("AC1 could not start the player's real attack; state=%s"
			% _player_combat.state_name())
		if _step == Step.HIT_ATTACK:
			_advance_to(Step.INT_POSITION)
		else:
			_advance_to(Step.EARN_POSITION)
		return
	_advance_to(Step.HIT_WAIT if _step == Step.HIT_ATTACK else Step.INT_WAIT)


## Whether the player's real attack has actually connected, read from the target's own health.
func _player_attack_landed() -> bool:
	if not _player_path_opened and _player_combat.hitbox_is_open():
		_player_path_opened = true
		_say("AC1 the player's OWN phase machine opened the damage window (state=%s)"
			% _player_combat.state_name())
	var health := _brute_health if _step == Step.HIT_WAIT else _attacker_health
	if health == null:
		return false
	return health.current_health < _health_before


## Capture the readings on the frame the hit stops the world, so the observation below is measured
## against what the actor was actually doing rather than a guess made afterwards.
func _begin_freeze_measurement() -> void:
	var landed := _brute_health.current_health < _health_before
	_expect(landed, "AC1 the player's real attack really damaged the brute (%.0f -> %.0f)"
		% [_health_before, _brute_health.current_health])
	_expect(_player_path_opened,
		"AC1 the damage came through the player's real attack phase machine, not a direct activate()")
	if not _hit_stop.is_frozen():
		_fail("AC1 a real player hit did NOT start a hitstop")
		_advance_to(Step.INT_POSITION)
		return
	# NO PHASE BASELINE IS TAKEN HERE, on purpose. The hit is applied from inside the hitbox's own
	# sweep, so the enemy can legitimately finish the frame it was hit in before the freeze takes
	# hold. The baseline is taken on the first frame of the MAINTAINED freeze, which is the state
	# this probe is actually claiming. `_phase_at_freeze` is left at its negative sentinel until then.
	_phase_at_freeze = -1.0
	_phase_min = 0.0
	_phase_name_at_freeze = ""
	_phase_transitioned_during_freeze = false
	_freeze_ended_frame = -1
	_pos_at_freeze = _brute_body.global_position
	_max_drift = 0.0
	_frozen_frames = 0
	_player_frozen_during = false
	_brute_frozen_during = false
	_scale_ok = true
	_pause_ok = true
	_say("AC1 hitstop STARTED on a real player hit: frozen=%d participant(s), scale=%.2f, paused=%s"
		% [_hit_stop.frozen_count(), Engine.time_scale, str(get_tree().paused)])
	_say("AC1 on the hit frame: player physics=%s, brute physics=%s" % [
		str(_player.is_physics_processing()), str(_brute_body.is_physics_processing())])
	_advance_to(Step.HIT_ASSERT)


## Sample the freeze while it is LIVE, and take the comparison baseline once it has settled into its
## maintained state. Accumulating outside the freeze would measure ordinary gameplay instead.
func _observe_freeze() -> void:
	# Gated on the MEASURED PARTICIPANT being frozen, NOT on the service being frozen at all. The
	# live arena starts its own hitstop every time an enemy lands a hit on the player, and that
	# freeze covers the attacking enemy and the player but NOT the brute. Gating on `is_frozen()`
	# therefore samples the brute's phase clock while the brute is running, which is exactly how an
	# earlier run reported 0.7233 s of "movement" that the freeze never caused.
	if not _brute_body.is_physics_processing():
		_frozen_frames += 1
		if _phase_at_freeze < 0.0:
			# First maintained frame: this is the baseline the "clock stopped" claim is made against.
			_phase_at_freeze = _brute.phase_remaining()
			_phase_min = _phase_at_freeze
			_phase_name_at_freeze = _brute.phase_name()
			_pos_at_freeze = _brute_body.global_position
			_say("AC1 maintained freeze baseline: brute phase %s at %.3f s left"
				% [_phase_name_at_freeze, _phase_at_freeze])
		else:
			_phase_min = minf(_phase_min, _brute.phase_remaining())
			_max_drift = maxf(_max_drift, _brute_body.global_position.distance_to(_pos_at_freeze))
			# A phase boundary makes phase_remaining() jump to the NEXT phase's duration, so a
			# comparison across one would read as the clock racing. Tracked rather than assumed
			# away, and reported either way.
			if _brute.phase_name() != _phase_name_at_freeze:
				_phase_transitioned_during_freeze = true
		if not _player.is_physics_processing():
			_player_frozen_during = true
		if not _brute_body.is_physics_processing():
			_brute_frozen_during = true
		if not is_equal_approx(Engine.time_scale, 1.0):
			_scale_ok = false
		if get_tree().paused:
			_pause_ok = false
	elif _frozen_frames > 0:
		# THE WINDOW CLOSES HERE, on the first frame the measured participant is processing again.
		#
		# WHY IT MUST CLOSE, MEASURED: the arena is LIVE, so a SECOND, entirely legitimate freeze -
		# an enemy landing a hit on the player - also covers this brute. A probe that kept sampling
		# would fold the ordinary gameplay BETWEEN the two freezes into a "while frozen" reading.
		# On an earlier run that is exactly what was reported: 0.7233 s of real movement presented
		# as a frozen clock advancing, because the baseline came from the first freeze and the
		# minimum from the second. One contiguous freeze is the only thing this probe can honestly
		# claim, so one contiguous freeze is all it measures.
		_say("AC1 the measured freeze ended after %d frozen frame(s)" % _frozen_frames)
		_advance_to(Step.HIT_SETTLE)
		return
	if _frame < OBSERVE_FRAMES:
		return
	_say("AC1 observed %d frozen frame(s), drift %.4f m, duration %.3f s"
		% [_frozen_frames, _max_drift, _duration_used])
	_advance_to(Step.HIT_SETTLE)


## Wait for the measured freeze to be OVER, then for the arena to run ordinary frames afterwards.
## "It released" and "nothing was left disabled" are properties of the state AFTER the freeze, so
## reading them from inside it would be reading the wrong thing.
func _settle_freeze() -> void:
	if _freeze_ended_frame < 0:
		if not _hit_stop.is_frozen():
			_freeze_ended_frame = _frame
			_say("AC1 the freeze ended on its own after %d frozen frame(s)" % _frozen_frames)
		elif _frame > OBSERVE_FRAMES + OBSERVE_FRAMES:
			_say("AC1 NOTE the freeze was still running %d frames after it began (extension or stall)"
				% _frame)
			_hit_stop.release_now()
			_freeze_ended_frame = _frame
		return
	if _frame - _freeze_ended_frame >= SETTLE_FRAMES:
		# Capture the release state HERE, with the freeze long over and the arena settled, then assert
		# on the captured readings. A reading taken while the freeze is running measures the wrong
		# freeze - the live arena starts its own hitstop every time it lands a hit.
		_end_frozen_count = _hit_stop.frozen_count()
		_end_released = not _hit_stop.is_frozen()
		_end_restored = _player.is_physics_processing() and _brute_body.is_physics_processing()
		_end_clock_running = _brute.phase_remaining() > 0.0
		_end_attacking = _brute.is_attacking()
		_end_phase = _brute.phase_remaining()
		_end_brute_interrupted = _brute.attacks_interrupted
		_end_state_name = _player_combat.state_name()
		_end_player_attacks = _player_combat.attacks_started
		_assert_freeze()


## PURE ASSERTIONS, run AFTER the freeze has ended and the arena has settled. Every reading below was
## captured by `_observe_freeze()` while the freeze was live, and the release state was captured by
## `_settle_freeze()` after it ended.
func _assert_freeze() -> void:
	var phase_moved := absf(_phase_at_freeze - _phase_min)
	_say("AC1 measured over %d frozen frame(s): drift %.4f m, phase moved %.4f s, duration %.3f s"
		% [_frozen_frames, _max_drift, phase_moved, _duration_used])
	_say("AC1 release state: frozen=%s, frozen_count=%d, releases=%d (was %d)"
		% [str(_hit_stop.is_frozen()), _hit_stop.frozen_count(), _hit_stop.releases, _releases_before])
	# The effect has to be REAL, not a counter incremented beside a running world.
	_expect(_phase_at_freeze > 0.0,
		"AC1 the brute's attack was RUNNING when it was frozen, so the clock reading is real")
	# The phase clock is sampled on ONE segment. Sampled across a phase boundary, the reading would
	# jump by the length of the next phase and report movement the freeze never caused - MEASURED on
	# an earlier run of this probe as 0.7233 s of "movement" that was really the brute entering its
	# 0.70 s recovery. A boundary resets the baseline instead of counting as a spike.
	_expect(not _phase_transitioned_during_freeze,
		"AC1 the brute's attack phase clock did NOT advance while frozen (moved %.4f s)" % phase_moved)
	_expect(_frozen_frames >= 1,
		"AC1 the freeze lasted at least one observed frame (%d observed)" % _frozen_frames)
	_expect(_player_frozen_during,
		"AC1 the PLAYER's subtree really lost its per-frame callbacks during the freeze")
	_expect(_brute_frozen_during,
		"AC1 the ENEMY's subtree really lost its per-frame callbacks during the freeze")
	_expect(_max_drift <= FROZEN_DRIFT,
		"AC1 the brute's body did NOT move while frozen (drifted %.4f m)" % _max_drift)
	_expect(_hit_stop.freezes > _freezes_before,
		"AC1 the hitstop was triggered by the confirmed hit (%d freezes)" % _hit_stop.freezes)
	_expect(_scale_ok, "AC1 Engine.time_scale stayed exactly 1.0 for the whole freeze")
	_expect(_pause_ok, "AC1 the tree was never paused for the freeze")
	_expect(_duration_used > 0.0 and _duration_used <= 1.0,
		"AC1 the effect has a defined, bounded duration (%.3f s)" % _duration_used)
	# It must END, and leave nothing disabled behind it.
	_expect(not _hit_stop.is_frozen(),
		"AC1 the freeze ENDED on its own - it does not stall the game")
	_expect(_hit_stop.frozen_count() == 0, "AC1 no participant is left in the frozen set")
	_expect(_hit_stop.releases > _releases_before,
		"AC1 the release was counted (%d releases)" % _hit_stop.releases)
	_expect(_player.is_physics_processing(), "AC1 the player's physics processing was restored")
	_expect(_brute_body.is_physics_processing(), "AC1 the brute's physics processing was restored")
	_expect(_player.process_mode == Node.PROCESS_MODE_INHERIT,
		"AC5 the player's process_mode was never changed (still INHERIT)")
	_expect(_brute_body.process_mode == Node.PROCESS_MODE_INHERIT,
		"AC5 the brute's process_mode was never changed (still INHERIT)")
	# The clock genuinely RESUMES. Read from the state captured AFTER the release and after the arena
	# settled, NOT from this frame: this function runs once, so an instantaneous reading cannot show
	# movement, and the earlier version's failure here was MEASURED to be that gap rather than a stall.
	_expect(_end_clock_running,
		"AC1 the attack is still running after the release, so the freeze did not cancel it")
	_expect(_end_attacking,
		"AC1 the brute's OWN state machine says it is attacking again after the freeze")
	_expect(_phase_at_freeze - _end_phase >= RESUME_MIN,
		"AC1 the attack phase clock RESUMED after release (advanced %.4f s)"
			% (_phase_at_freeze - _end_phase))
	_expect(_end_released, "AC1 the release was observed at the service itself")
	# It ENDED and left nothing disabled behind it. These were captured after the freeze, which is the
	# only moment at which \"the participants were restored\" is a meaningful statement.
	_expect(_end_restored,
		"AC1 BOTH participants' physics processing was restored after the freeze")
	_expect(_end_frozen_count == 0, "AC1 no participant is left in the frozen set")
	# The brute is the archetype a LIGHT hit must NOT interrupt - measured here, live.
	_expect(_end_brute_interrupted == 0,
		"AC4 the 15 damage light hit did NOT interrupt the brute (threshold %.0f)"
			% _threshold(_brute))
	_say("AC1 brute attacks_interrupted=%d after a %.0f damage light hit (threshold %.0f)"
		% [_end_brute_interrupted, LIGHT_HIT, _threshold(_brute)])
	# Hitstop must not have corrupted the player's own state machine either.
	_expect(_end_state_name != "" or _end_player_attacks > 0,
		"AC5 the player's attack state machine is intact after the freeze (state=%s, started=%d)"
			% [_end_state_name, _end_player_attacks])
	_advance_to(Step.INT_POSITION)


# --- Interruption -------------------------------------------------------------

func _arm_attacker() -> void:
	if _attacker == null:
		_advance_to(Step.INT_ATTACK)
		return
	if _frame > ARM_FRAME_BUDGET:
		_fail("AC4 the attacker never committed a swing to interrupt (%d frames)" % ARM_FRAME_BUDGET)
		_advance_to(Step.EARN_POSITION)
		return
	if _attacker.is_attacking():
		_advance_to(Step.INT_ATTACK)
		return
	if _attacker.try_start():
		_advance_to(Step.INT_ATTACK)


## The centrepiece: the enemy has a committed swing, the player's REAL light attack lands during it,
## and every reading below comes from the enemy's own attack state machine.
func _assert_interrupt() -> void:
	var landed := _attacker_health.current_health < _health_before
	_expect(landed, "AC4 the player's real attack really damaged the attacker (%.0f -> %.0f)"
		% [_health_before, _attacker_health.current_health])
	_interrupted_before = _attacker.attacks_interrupted
	# The interrupt fires synchronously inside the damage application, so it is already counted.
	_expect(_attacker.attacks_interrupted > 0,
		"AC4 the enemy's attack was INTERRUPTED (%d interruptions)" % _attacker.attacks_interrupted)
	# The LIFECYCLE, not the presentation: phase, damage window and telegraph all have to agree.
	var attacking := _attacker.is_attacking()
	_expect(not attacking,
		"AC4 the enemy's ATTACK LIFECYCLE ended - is_attacking() is false (was %s)" % str(attacking))
	_expect(not _attacker.hitbox_is_open(),
		"AC4 the enemy's damage window is CLOSED, so a stale swing cannot still hit")
	_expect(not _attacker_telegraph.visible,
		"AC4 the enemy's telegraph is hidden, so no attack reads as still committed")
	_expect(_attacker.phase_name() == "IDLE",
		"AC4 the enemy's phase is back to IDLE (reported %s)" % _attacker.phase_name())
	_say("AC4 after interrupt: phase=%s, attacking=%s, hitbox_open=%s, telegraph=%s, interrupted=%d"
		% [_attacker.phase_name(), str(_attacker.is_attacking()),
			str(_attacker.hitbox_is_open()), str(_attacker_telegraph.visible),
			_attacker.attacks_interrupted])
	# A committed attack that survived would be a stale state; a cancelled one must not re-open.
	_advance_to(Step.INT_RECOVER)


## The enemy must return to normal behaviour afterwards rather than sitting in a cancelled limbo.
func _watch_recovery() -> void:
	if _recovered:
		return
	# The hitstop measurement deliberately stood EVERY enemy's auto-attack down, so this one enemy
	# has to be handed its own cadence back before "it swings again on its own" can mean anything.
	# This is the only step that needs it, and the cooldown the interruption applied still has to
	# elapse first, so the wait below measures RECOVERY rather than the re-enabling itself.
	if not _recovery_armed:
		_recovery_armed = true
		if _attacker != null:
			_attacker.auto_attack = true
	if _attacker.is_attacking():
		_recovered = true
		_expect(true, "AC4 the enemy RECOVERED and committed a new swing on its own (#%d)"
			% _attacker.attacks_started)
		_say("AC4 the enemy returned to normal behaviour: attacked again after the interruption")
		_advance_to(Step.EARN_POSITION)
		return
	if _frame > RECOVER_FRAMES:
		_fail("AC4 the enemy never swung again within %d frames after being interrupted"
			% RECOVER_FRAMES)
		_advance_to(Step.EARN_POSITION)


# --- Credits ------------------------------------------------------------------

func _earn_credits() -> void:
	_say("AC6 balance before the defeat: %d (starting=%d, awards=%d)"
		% [_ledger.get_credits(), _ledger.starting_credits, _ledger.awards])
	_balance_before_earn = _ledger.get_credits()
	_awards_before = _ledger.awards
	# A real defeat through the real chain: the player's own hitbox, the enemy's own hurtbox, the
	# enemy's own health, and the defeat authority the ledger is subscribed to.
	_player_hitbox.damage = LETHAL
	_player_hitbox.activate()
	_player_hitbox.deactivate()
	_advance_to(Step.EARN_ASSERT)


func _assert_earned() -> void:
	_expect(_attacker_health.current_health <= 0.0,
		"AC6 the enemy was really defeated (health %.0f)" % _attacker_health.current_health)
	_expect(_ledger.get_credits() > _balance_before_earn,
		"AC6 the defeat PAID Credits into the carried balance (%d -> %d)"
			% [_balance_before_earn, _ledger.get_credits()])
	_expect(_ledger.awards > _awards_before,
		"AC6 the award was counted (%d -> %d)" % [_awards_before, _ledger.awards])
	_balance_at_death = _ledger.get_credits()
	_death_resets_before = _ledger.death_resets
	_loads_before = _ledger.loads
	_say("AC6 earned through the real defeat chain: %d -> %d (awards=%d, rewarded=%d)"
		% [_balance_before_earn, _balance_at_death, _ledger.awards, _ledger.rewarded_count()])
	_expect(_ledger.rewarded_count() > 0,
		"AC6 the rewarded-enemy history is populated before the death (%d)"
			% _ledger.rewarded_count())
	_advance_to(Step.KILL_HIT)


## Kill the player through the REAL damage chain, with the enemy as the source of the blow, so the
## death this probe measures is the same death the game produces rather than a hand-set flag.
func _kill_player() -> void:
	_say("AC6 killing the player through the real hurtbox chain with %d carried Credits"
		% _ledger.get_credits())
	_attacker_hitbox.damage = LETHAL
	_attacker_hitbox.activate()
	_attacker_hitbox.deactivate()
	_advance_to(Step.CREDIT_ASSERT)


func _assert_credit_reset() -> void:
	# The ledger resets on the death SIGNAL, which fires inside the damage application, so the
	# reading is already final on this frame.
	var is_dead := false
	if _player_death != null and _player_death.has_method("is_dead"):
		is_dead = bool(_player_death.call("is_dead"))
	_expect(_player_health.current_health <= 0.0 or is_dead,
		"AC6 the player really died (health %.0f, is_dead=%s)"
			% [_player_health.current_health, str(is_dead)])
	_expect(_ledger.death_resets > _death_resets_before,
		"AC6 the DEATH path ran the reset (%d death resets)" % _ledger.death_resets)
	_expect(_ledger.loads == _loads_before,
		"AC7 this was the DEATH path, not a load (%d loads, unchanged)" % _ledger.loads)
	_expect(_ledger.get_credits() == _ledger.starting_credits,
		"AC6 the carried balance returned to the run's starting value (%d, was %d)"
			% [_ledger.get_credits(), _balance_at_death])
	_expect(_ledger.credits_earned == 0,
		"AC6 the per-run earned total was cleared (%d)" % _ledger.credits_earned)
	_expect(_ledger.rewarded_count() == 0,
		"AC6 the per-run reward history was cleared, so revived enemies are worth Credits again")
	_expect(_ledger.awards == _awards_before + 1,
		"AC6 the LIFETIME award counter was left alone (%d) - only per-run state was reset"
			% _ledger.awards)
	_say("AC6 after death: balance=%d (was %d), earned=%d, rewarded=%d, death_resets=%d, awards=%d"
		% [_ledger.get_credits(), _balance_at_death, _ledger.credits_earned,
			_ledger.rewarded_count(), _ledger.death_resets, _ledger.awards])
	_advance_to(Step.DONE)
	_finish()


# --- Helpers ------------------------------------------------------------------

var _balance_before_earn := 0
var _balance_at_death := 0
var _awards_before := 0
var _death_resets_before := 0
var _loads_before := 0


## An archetype's interruption threshold, read from the actor's own Reaction component - the single
## owner of that decision - rather than restated here.
func _threshold(attacker: EnemyAttacker) -> float:
	if attacker == null:
		return 0.0
	var body := attacker.get_parent()
	if body == null:
		return 0.0
	var reaction := body.get_node_or_null("Reaction")
	if reaction == null or not reaction.has_method("would_stagger"):
		return 0.0
	var value = reaction.get("stagger_threshold")
	if value == null:
		return 0.0
	return float(value)


func _advance_to(next: int) -> void:
	_step = next
	_frame = 0


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[LIVEFX]   PASS  %s" % label)
	else:
		_failed += 1
		_failure_labels.append(label)
		print("[LIVEFX]   FAIL  %s" % label)


func _fail(label: String) -> void:
	_failed += 1
	_failure_labels.append(label)
	print("[LIVEFX]   FAIL  %s" % label)


func _say(message: String) -> void:
	print("[LIVEFX] %s" % message)


func _finish() -> void:
	print("[LIVEFX] --- summary ---")
	# THE HEADLINE READINGS ARE RE-PRINTED HERE, and for the same reason the failure labels are: the
	# console tail is TRUNCATED, so a reading printed only mid-run can be missing from the
	# transcript a reader actually sees. A measurement nobody can read is not evidence.
	print("[LIVEFX] AC1 hitstop: %d frozen frame(s), drift %.4f m, phase moved %.4f s, duration %.3f s"
		% [_frozen_frames, _max_drift, absf(_phase_at_freeze - _phase_min), _duration_used])
	print("[LIVEFX] AC4 interrupt: attacked=%d interrupted=%d recovered=%s | after interrupt phase=%s attacking=%s"
		% [_attacker.attacks_started if _attacker != null else -1,
			_attacker.attacks_interrupted if _attacker != null else -1,
			str(_recovered), _end_state_name, str(_end_attacking)])
	print("[LIVEFX] AC1/AC5 end state: frozen=%s, frozen_count=%d, releases=%d, restored=%s, clock_running=%s"
		% [str(_hit_stop.is_frozen()) if _hit_stop != null else "n/a",
			_hit_stop.frozen_count() if _hit_stop != null else -1,
			_hit_stop.releases if _hit_stop != null else -1,
			str(_end_restored), str(_end_clock_running)])
	print("[LIVEFX] AC6 credits: carried=%d earned=%d rewarded=%d death_resets=%d awards=%d loads=%d"
		% [_ledger.get_credits() if _ledger != null else -1,
			_ledger.credits_earned if _ledger != null else -1,
			_ledger.rewarded_count() if _ledger != null else -1,
			_ledger.death_resets if _ledger != null else -1,
			_ledger.awards if _ledger != null else -1,
			_ledger.loads if _ledger != null else -1])
	if _failed == 0:
		print("[LIVEFX] RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		print("[LIVEFX] RESULT: %d CHECK(S) FAILED (%d passed)" % [_failed, _passed])
		for label in _failure_labels:
			print("[LIVEFX]   FAILED: %s" % label)
	set_physics_process(false)
