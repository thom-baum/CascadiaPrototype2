class_name DeathDropCreditProbeDebug
extends Node3D
## Milestone 19 - the DEATH-DROP / RETRIEVAL loop, measured at runtime. Temporary diagnostic.
##
## WHAT THIS MEASURES. Milestone 18 made a death RESET the carried balance. That is a punishment
## with no retrieval path, which is only half of a Soulslike death loop. This pass adds the other
## half: a death DROPS the lost Credits as a retrievable stake at the place the player fell, a
## second death before the first was claimed DESTROYS the older stake, and walking back onto it
## returns the Credits.
##
## WHY A RUNTIME PROBE AND NOT A UNIT TEST. Every claim here is about the LEDGER'S STATE AFTER A
## REAL DEATH. A unit test can set a balance and call place_stake() and pass while the game never
## drops anything, because the question is not "does place_stake work" but "does the PLAYER DYING
## run it, at the right place, with the right amount, exactly once". So the death below goes through
## the real chain - `HurtboxComponent.receive_hit()` -> `HealthComponent.apply_damage()` ->
## `died` -> `DeathComponent._on_died()` -> `death_started` -> the ledger - and every assertion
## reads the ledger afterwards rather than a returned value.
##
## THE REVIVE IS THE REAL ONE. The probe never respawns the player by hand: it WAITS for the
## actor's own `death_delay` to elapse and its own auto-reset to run, because part of what must be
## proven is that the ordinary revive does NOT reset the balance a second time and does NOT place a
## second stake.
##
## THE STAKE POSITION IS A SPECIFIC SPOT, not wherever the arena happened to leave the player. The
## probe moves the player to a known point immediately before the lethal blow, so "the stake went
## down where the player fell" is checkable against a number instead of against a memory.
##
## THE ARENA IS KEPT QUIET: every enemy's auto-attack is stood down on every frame, so no enemy can
## kill the player mid-scenario and make the ledger's own reading ambiguous. That is the only thing
## stood down; the death circuit, the hurtbox chain, the ledger and the stake node are all REAL.
##
## WRITES A REPORT to REPORT_PATH as well as printing. The console tail is TRUNCATED, and a result a
## reader cannot see is not evidence, so the full transcript goes to a file the project can read
## directly - the same convention the other probes already use.

## Where this probe's report is written.
const REPORT_PATH := "res://death_drop_credit_probe_report.txt"
## Frames to let every _ready() in the arena run before anything is measured.
const SETTLE_FRAMES := 5
## Frames allowed for the actor's OWN revive to complete. Generously longer than the product's
## `death_delay` so a revive that FAILS to happen is observed as a failure rather than waited out.
const REVIVE_FRAME_BUDGET := 300
## Frames allowed for the player standing on a stake to claim it.
const CLAIM_FRAME_BUDGET := 30
## Damage for the lethal blow, high enough to defeat in one application.
const LETHAL := 9999.0
## Where the player is placed before each lethal blow, so the stake position is a known number.
const DEATH_POSITION := Vector3(6.0, 0.2, 6.0)
## The death position for scenario E, deliberately FAR from any standing stake. E's subject is a
## death that drops NOTHING and therefore destroys a stake it does not replace, so the player must
## not walk onto that stake on the way to dying. See `_die_at()`.
const E_DEATH_POSITION := Vector3(-6.0, 0.2, -6.0)
## A stake may not be recorded more than this far from the spot the player died on, in metres.
const POSITION_TOLERANCE := 0.05

var _main: Node3D
var _env: Node3D
var _player: CharacterBody3D
var _player_health: HealthComponent
var _player_hurtbox: HurtboxComponent
var _player_death: DeathComponent
var _attacker_body: CharacterBody3D

var _ledger: CreditLedger
var _stake: CreditStake

var _passed := 0
var _failed := 0
var _failure_labels: Array[String] = []
## Every line this probe emits, in order, so the report file is a faithful transcript rather than a
## second, separately-maintained summary that can disagree with the console.
var _lines: PackedStringArray = PackedStringArray()


func _ready() -> void:
	# The game root is a SIBLING of this probe, not a child: the run scene instances main.tscn
	# beside the probe so the probe is never itself inside the tree it measures.
	_main = get_node_or_null("../Main") as Node3D
	await _run()


## The whole measurement, in order. Written with `await` rather than the step machine the older
## probes use, because every scenario here is a WAIT for the game to do something and a linear
## reading is what keeps the ordering - and the reason for the ordering - obvious.
func _run() -> void:
	await _settle()
	if not _do_setup():
		_finish()
		return

	# --- A. A death with Credits in hand drops them at the spot the player fell ---------------
	var starting := _ledger.starting_credits
	_award(500, "scenario A")
	_expect(_ledger.get_credits() == starting + 500,
		"A the carried balance was 500 before the death (%d)" % _ledger.get_credits())
	_expect(not _ledger.has_stake(),
		"A no stake was standing before the death (has_stake=%s)" % str(_ledger.has_stake()))

	var placed_before := _ledger.stakes_placed
	var lost_before := _ledger.stakes_lost
	await _die()
	_expect(_player_death.is_dead(),
		"A the player really died through the hurtbox chain (is_dead=%s)" % str(_player_death.is_dead()))
	_expect(_ledger.stakes_placed == placed_before + 1,
		"A the DEATH placed exactly one stake (%d -> %d)" % [placed_before, _ledger.stakes_placed])
	_expect(_ledger.has_stake(), "A a stake is standing after the death")
	_expect(_ledger.stake_amount() == 500,
		"A the stake holds the balance the death took (%d)" % _ledger.stake_amount())
	_expect(_ledger.get_credits() == starting,
		"A the carried balance was emptied by the death (%d)" % _ledger.get_credits())
	_expect(_ledger.stake_position().distance_to(DEATH_POSITION) <= POSITION_TOLERANCE,
		"A the stake went down where the player FELL (%.3f m from the death spot)"
			% _ledger.stake_position().distance_to(DEATH_POSITION))
	_expect(_ledger.stakes_lost == lost_before,
		"A placing the first stake destroyed nothing (%d)" % _ledger.stakes_lost)
	_expect(_stake != null and _stake.is_armed() and _stake.visible,
		"A the stake NODE is armed and visible, so the player can see what to go back for")
	_expect(_stake != null and _stake.displayed_amount() == 500,
		"A the node displays the amount the death dropped (%d)"
			% (_stake.displayed_amount() if _stake != null else -1))

	# --- B. The ordinary revive must not touch the economy -------------------------------------
	var balance_at_death := _ledger.get_credits()
	var placed_at_death := _ledger.stakes_placed
	_expect(await _revive(), "B the actor's OWN auto-reset revived the player")
	_expect(_ledger.get_credits() == balance_at_death,
		"B the revive did NOT reset the balance a second time (%d)" % _ledger.get_credits())
	_expect(_ledger.stakes_placed == placed_at_death,
		"B the revive did NOT place a second stake (%d)" % _ledger.stakes_placed)
	_expect(_ledger.has_stake(), "B the stake is still standing after the revive")

	# --- C. Walking back onto the stake returns the Credits ------------------------------------
	var awards_before_claim := _ledger.awards
	var reclaimed_before := _ledger.stakes_reclaimed
	await _stand_on_stake()
	_expect(await _wait_for_claim(reclaimed_before),
		"C standing on the stake CLAIMED it (%d -> %d)"
			% [reclaimed_before, _ledger.stakes_reclaimed])
	_expect(_ledger.get_credits() == starting + 500,
		"C the reclaimed stake returned the Credits exactly (%d, expected %d)"
			% [_ledger.get_credits(), starting + 500])
	_expect(not _ledger.has_stake(), "C the stake is gone once claimed")
	_expect(_stake != null and not _stake.visible,
		"C the stake NODE is hidden once claimed")
	_expect(_ledger.awards == awards_before_claim,
		"C claiming is NOT an award: the lifetime award counter is untouched (%d)" % _ledger.awards)

	# --- D. ONE-STAKE RULE: a second death before the first is claimed destroys the first -------
	_award(200, "scenario D")
	await _die()
	var first_stake := _ledger.stake_amount()
	_expect(_ledger.has_stake() and first_stake == starting + 700,
		"D a second death dropped its own stake (%d)" % first_stake)
	_expect(await _revive(), "D the player revived again")
	var lost_before_replace := _ledger.stakes_lost
	_award(300, "scenario D second")
	await _die()
	_expect(_ledger.stakes_lost == lost_before_replace + 1,
		"D the second death DESTROYED the unclaimed stake (%d -> %d) - the one-stake rule"
			% [lost_before_replace, _ledger.stakes_lost])
	_expect(_ledger.stake_amount() == starting + 300,
		"D the new stake holds only the NEW balance, so nothing was double-dropped (%d)"
			% _ledger.stake_amount())
	_expect(await _revive(), "D the player revived after the replacement")

	# --- E. Dying with an EMPTY pocket must still destroy the standing stake -------------------
	# D's death left a stake standing and reset the balance to `starting`, so this next death has
	# NOTHING to drop - and that must not leave the old stake alive to be collected later.
	#
	# IT DIES AWAY FROM THE STAKE, which is what makes the scenario real. `_die()` kills from
	# DEATH_POSITION, the very spot D's stake stands on, so a LIVING player sent there would walk
	# onto it and CLAIM it before the lethal blow: measured, the balance came back at 300 with no
	# stake standing, and E failed four checks that were describing a correctly behaved product.
	var lost_before_emptied := _ledger.stakes_lost
	var placed_before_emptied := _ledger.stakes_placed
	# MEASURED PREMISE. E is only meaningful if the balance is back at the run's starting value AND
	# an earlier stake is still standing, so those two facts are STATED here rather than assumed.
	# Without this the scenario fails for a reason that is invisible in its own assertion text.
	_e_balance = _ledger.get_credits()
	_e_starting = _ledger.starting_credits
	_e_standing = _ledger.has_stake()
	_e_reclaimed = _ledger.stakes_reclaimed
	_e_placed = _ledger.stakes_placed
	_e_lost = _ledger.stakes_lost
	_say("E premise: balance=%d (starting %d), standing=%s, reclaimed=%d, placed=%d, lost=%d"
		% [_e_balance, _e_starting, str(_e_standing), _e_reclaimed, _e_placed, _e_lost])
	# The scenario checks its OWN precondition, so a future change that breaks the setup reports
	# that rather than looking like four product failures.
	_expect(_e_balance == _e_starting and _e_standing,
		"E premise holds: the balance is at the run's start (%d) AND an earlier stake is standing"
			% _e_starting)
	await _die_at(E_DEATH_POSITION)
	_expect(_ledger.stakes_lost == lost_before_emptied + 1,
		"E dying with nothing to drop DESTROYED the standing stake (%d -> %d)"
			% [lost_before_emptied, _ledger.stakes_lost])
	_expect(not _ledger.has_stake(),
		"E no stake is standing after an empty-pocket death (has_stake=%s)"
			% str(_ledger.has_stake()))
	_expect(_ledger.stakes_placed == placed_before_emptied,
		"E no new stake was created for a death that dropped nothing (%d)"
			% _ledger.stakes_placed)
	_expect(_stake != null and not _stake.visible,
		"E the stake NODE is hidden when nothing is standing")
	_expect(await _revive(), "E the player revived after the empty-pocket death")

	# --- F. NEW RUN clears a standing stake ----------------------------------------------------
	_award(250, "scenario F")
	await _die()
	_expect(_ledger.has_stake(), "F a stake is standing before the new run")
	_expect(await _revive(), "F the player revived before the new run")
	_ledger.reset_credits()
	_expect(not _ledger.has_stake(),
		"F a NEW RUN cleared the standing stake (has_stake=%s)" % str(_ledger.has_stake()))
	_expect(_ledger.get_credits() == _ledger.starting_credits,
		"F a new run begins at the documented starting balance (%d)" % _ledger.get_credits())
	_expect(_ledger.stakes_placed == 0 and _ledger.stakes_lost == 0,
		"F a new run begins with no stake history (%d placed, %d lost)"
			% [_ledger.stakes_placed, _ledger.stakes_lost])
	_expect(_stake != null and not _stake.visible,
		"F the stake NODE is hidden after a new run")

	# --- G. A LOAD clears a standing stake, and a load is not a death --------------------------
	_award(150, "scenario G")
	await _die()
	_expect(_ledger.has_stake(), "G a stake is standing before the load")
	_expect(await _revive(), "G the player revived before the load")
	var loads_before := _ledger.loads
	var death_resets_before := _ledger.death_resets
	_expect(_ledger.restore_carried_credits(999), "G the load's restore was accepted")
	_expect(_ledger.loads == loads_before + 1,
		"G the LOAD path ran, not the death path (%d -> %d)" % [loads_before, _ledger.loads])
	_expect(_ledger.death_resets == death_resets_before,
		"G the load did NOT run the death reset (%d death resets, unchanged)"
			% _ledger.death_resets)
	_expect(not _ledger.has_stake(),
		"G the load cleared the standing stake, so a loaded world cannot pay for a death it never saw")
	_expect(_ledger.get_credits() == 999,
		"G the restored balance is the saved value (%d)" % _ledger.get_credits())
	_expect(_stake != null and not _stake.visible,
		"G the stake NODE is hidden after a load")

	_say("final: balance=%d stake=%s placed=%d reclaimed=%d lost=%d death_resets=%d loads=%d"
		% [_ledger.get_credits(), str(_ledger.has_stake()), _ledger.stakes_placed,
			_ledger.stakes_reclaimed, _ledger.stakes_lost, _ledger.death_resets, _ledger.loads])
	_finish()


# --- Arming the scenarios ------------------------------------------------------

## Let every _ready() in the arena run, and stand every enemy's auto-attack down so the only death
## this probe measures is the one it causes.
func _settle() -> void:
	for _i in SETTLE_FRAMES:
		await get_tree().physics_frame


func _do_setup() -> bool:
	_resolve()
	_expect(_main != null, "AC0 the live game root was instanced")
	_expect(_env != null, "AC0 the live test environment resolved")
	_expect(_ledger != null, "AC0 the credit ledger service resolved")
	_expect(_stake != null, "AC0 the CreditStake node resolved from the live scene")
	_expect(_player != null and _player_health != null and _player_hurtbox != null
		and _player_death != null,
		"AC0 the player, its health, its hurtbox and its death circuit all resolved")
	if _ledger == null or _stake == null or _player == null or _player_health == null \
			or _player_hurtbox == null or _player_death == null:
		return false
	_expect(_ledger.drop_on_death,
		"AC0 the death-drop policy is ON in the live ledger (drop_on_death=%s)"
			% str(_ledger.drop_on_death))
	_say("AC0 ledger: starting=%d reward_per_enemy=%d | stake pickup radius %.2f m"
		% [_ledger.starting_credits, _ledger.reward_per_enemy, _stake.pickup_radius])
	_say("AC0 player death_delay %.2f s (the revive is the actor's own, never forced by this probe)"
		% _player_death.death_delay)
	# The stake's own account of what it did, alongside this probe's readings.
	_stake.debug_logging = true
	return true


## Deliver a lethal blow through the REAL chain, with the player standing on a known spot.
##
## `HurtboxComponent.receive_hit()` is the same entry point the enemy's attack volume uses, so the
## damage travels the production path - it is the AREA overlap that is skipped, and overlap is not
## what this probe is testing.
func _die() -> void:
	await _die_at(DEATH_POSITION)


## Deliver a lethal blow with the player standing on `position`.
##
## THE POSITION IS THE CALLER'S CHOICE, and scenario E depends on that. This helper puts a LIVING
## player on the spot before killing them, so if a stake is standing there the walk itself CLAIMS it
## - MEASURED: E's death on DEATH_POSITION collected the very stake E existed to check, leaving a
## balance of 300 with no stake standing, and E then failed four checks that were all accurately
## describing a correctly behaved product. E kills somewhere else for that reason.
func _die_at(position: Vector3) -> void:
	# Keep the arena quiet on the frame of the blow too: an enemy that lands its own hit on the
	# player would start a second, legitimate death and make the ledger's reading ambiguous.
	EnemyAttacker.stand_down_all(get_tree())
	_player.global_position = position
	_player.velocity = Vector3.ZERO
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = _attacker_body
	event.victim = _player
	event.position = _player.global_position
	_player_hurtbox.receive_hit(event)
	await get_tree().physics_frame


## Wait for the actor's OWN death to register, without forcing anything.
func _wait_until_dead() -> bool:
	var frames := 0
	while not _player_death.is_dead() and frames < REVIVE_FRAME_BUDGET:
		frames += 1
		await get_tree().physics_frame
	return _player_death.is_dead()


## Wait for the actor's OWN auto-reset. The delay is counted down in the actor's _physics_process,
## so this is the product reviving itself rather than the probe restoring state.
func _revive() -> bool:
	var frames := 0
	while _player_death.is_dead() and frames < REVIVE_FRAME_BUDGET:
		frames += 1
		await get_tree().physics_frame
	return not _player_death.is_dead()


## Put the player on the standing stake. The claim itself is the stake node's own job - this probe
## moves a body and then waits, it never calls reclaim_stake().
func _stand_on_stake() -> void:
	if not _ledger.has_stake():
		return
	_player.global_position = _ledger.stake_position() + Vector3(0.0, 0.1, 0.0)
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	_say("C standing on the stake: stake at %s, player at %s, distance %.3f m, armed=%s"
		% [str(_ledger.stake_position()), str(_player.global_position),
			_stake.distance_to_player(), str(_stake.is_armed())])


func _wait_for_claim(reclaimed_before: int) -> bool:
	var frames := 0
	while _ledger.stakes_reclaimed == reclaimed_before and frames < CLAIM_FRAME_BUDGET:
		frames += 1
		await get_tree().physics_frame
	if _ledger.stakes_reclaimed == reclaimed_before:
		_say("C claim did NOT happen in %d frames: standing=%s player=%s distance=%.3f armed=%s"
			% [CLAIM_FRAME_BUDGET, str(_ledger.has_stake()), str(_player.global_position),
				_stake.distance_to_player(), str(_stake.is_armed())])
		# The gate's OWN reasons, read from the stake rather than inferred from a missing log line.
		if _stake.has_method("claim_state"):
			_say("C gate at the failure point: %s" % str(_stake.claim_state()))
	return _ledger.stakes_reclaimed > reclaimed_before


## Move the balance through the ledger's own public API. Deliberately NOT an enemy defeat: the
## subject of this milestone is what DEATH does to a balance, so the balance is set up the shortest
## honest way rather than by staging five kills.
func _award(amount: int, source: String) -> void:
	_ledger.award_credits(amount, source)


# --- Resolution ----------------------------------------------------------------

func _resolve() -> void:
	if _main == null:
		return
	_env = _main.get_node_or_null("TestEnvironment") as Node3D
	if _env == null:
		return
	_player = _env.get_node_or_null("Player") as CharacterBody3D
	if _player != null:
		_player_health = _player.get_node_or_null("Health") as HealthComponent
		_player_hurtbox = _player.get_node_or_null("Hurtbox") as HurtboxComponent
		_player_death = _player.get_node_or_null("Death") as DeathComponent
	_attacker_body = _env.get_node_or_null("TestAttacker") as CharacterBody3D
	_ledger = CreditLedger.find_ledger(get_tree())
	# The GROUP is the primary resolver, so the stake is found the same way any other consumer finds
	# it; the direct path is a fallback that keeps the probe usable if the group ever changes.
	_stake = get_tree().get_first_node_in_group(CreditStake.GROUP_STAKE) as CreditStake
	if _stake == null:
		_stake = _env.get_node_or_null("CreditStake") as CreditStake


# --- Report --------------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		_lines.append("PASS  %s" % label)
		print("[DROP]   PASS  %s" % label)
	else:
		_failed += 1
		_failure_labels.append(label)
		_lines.append("FAIL  %s" % label)
		print("[DROP]   FAIL  %s" % label)


func _say(message: String) -> void:
	_lines.append("      %s" % message)
	print("[DROP] %s" % message)


# Scenario E's measured premise, captured at its own death so the summary can restate it. Held here
# rather than only printed mid-run because the console tail is truncated.
var _e_balance := 0
var _e_starting := 0
var _e_standing := false
var _e_reclaimed := 0
var _e_placed := 0
var _e_lost := 0


func _finish() -> void:
	print("[DROP] --- summary ---")
	if _ledger != null:
		_say("credits: carried=%d earned=%d placed=%d reclaimed=%d lost=%d death_resets=%d loads=%d awards=%d"
			% [_ledger.get_credits(), _ledger.credits_earned, _ledger.stakes_placed,
				_ledger.stakes_reclaimed, _ledger.stakes_lost, _ledger.death_resets,
				_ledger.loads, _ledger.awards])
	# THE CLAIM GATE'S OWN REASONS, reprinted here for the same reason: "the claim did not happen" is
	# a symptom, and this is the measurement that says why.
	if _stake != null and _stake.has_method("claim_state"):
		_say("claim gate at the end: %s" % str(_stake.claim_state()))
	# E'S PREMISE, reprinted for the same reason: the scenario is only meaningful if the balance is
	# back at the run's starting value while an earlier stake is still standing.
	_say("E premise at its death: balance=%d starting=%d standing=%s reclaimed=%d placed=%d lost=%d"
		% [_e_balance, _e_starting, str(_e_standing), _e_reclaimed, _e_placed, _e_lost])
	# THE C READINGS ARE RE-PRINTED HERE, for the same reason the failure labels are: the console
	# tail is TRUNCATED, so a reading printed only mid-run can be missing from the transcript a
	# reader actually sees. A measurement nobody can read is not evidence.
	if _ledger != null and _stake != null and _player != null:
		var dead_now := false
		if _player_death != null:
			dead_now = _player_death.is_dead()
		_say("C state: has_stake=%s armed=%s visible=%s stake_pos=%s player_pos=%s distance=%.3f player_dead=%s"
			% [str(_ledger.has_stake()), str(_stake.is_armed()), str(_stake.visible),
				str(_ledger.stake_position()), str(_player.global_position),
				_stake.distance_to_player(), str(dead_now)])
	if _failed == 0:
		_say("RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		_say("RESULT: %d CHECK(S) FAILED (%d passed)" % [_failed, _passed])
		for label in _failure_labels:
			_say("  FAILED: %s" % label)
	_write_report()
	set_physics_process(false)


## Write the whole transcript to REPORT_PATH. Best-effort, and a report that cannot be written is
## REPORTED rather than silently skipped, so the console never implies a file that does not exist.
func _write_report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		print("[DROP] could not write report to %s" % REPORT_PATH)
		return
	file.store_string("\n".join(_lines))
	file.close()
	print("[DROP] report written to %s" % REPORT_PATH)
