class_name CreditEconomyProbeDebug
extends Node3D
## Temporary diagnostic (not production): does ONE eligible enemy defeat award Credits EXACTLY ONCE,
## through the AUTHORITATIVE defeat path, for EVERY eligible enemy in the arena?
##
## WHY THIS EXISTS. Milestone 9's whole claim is "an enemy defeat pays, once". A probe that called
## `award_credits()` directly would prove the ledger can add integers and nothing about the economy.
## So this probe never adds Credits itself: it kills enemies through the REAL damage chain
## (`HurtboxComponent.receive_hit` -> `HealthComponent.apply_damage` -> `died` ->
## `EnemyDeathComponent.defeated` -> the ledger's signal handler) and then reads the balance. If the
## signal subscription, the eligibility rule or the duplicate guard were wrong, the balance would not
## move and this run would fail.
##
## ENUMERATION, NOT A NAME LIST. Carried forward from the 8K.12 lesson: a name list proves the actors
## you remembered, enumeration proves the actors you forgot. The eligible population is discovered by
## walking the defeat authority's own group, so a newly added enemy is covered the moment it exists
## and an enemy that can be defeated without paying FAILS this run.
##
## It also proves the EXCLUSIONS are real rather than assumed: the player, a non-mortal actor, an
## actor that is not actually defeated, and a freed reference must all pay nothing, each counted by
## cause so "it did not pay" can never be confused with "it was never asked".
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 12
## Frames the balance is watched after every enemy is dead. If a duplicate award were possible from a
## repeated signal or a per-frame check, it would land inside this window.
const HOLD_FRAMES := 90
## Damage used for a lethal blow - far above any actor's pool.
const LETHAL := 9999.0

var _frame := 0
var _done := false
var _stage := 0
var _wait := 0
var _failures: Array = []

var _ledger: CreditLedger
## Balance and counters captured at the start of the hold, so the window can be compared against it.
var _hold_credits := 0
var _hold_awards := 0
var _hold_rewarded := 0
## The eligible population discovered by enumeration.
var _eligible: Array = []
var _reward_per_enemy := 0


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	match _stage:
		0:
			if _frame < SETTLE_FRAMES:
				return
			_stand_down_ambient_attackers()
			_run()
		1:
			_tick_hold()


## The arena's ambient attacker would otherwise swing at the player during the hold below.
func _stand_down_ambient_attackers() -> void:
	EnemyAttacker.stand_down_all(get_tree())


func _run() -> void:
	print("[CREDITPROBE] --- enemy-defeat credit economy audit (measured) ---")
	_ledger = CreditLedger.find_ledger(get_tree())
	if _ledger == null:
		_fail("no CreditLedger in the tree - the economy has no owner")
		_done = true
		_report()
		return

	_reward_per_enemy = int(_ledger.reward_per_enemy)
	print("[CREDITPROBE] ledger found: starting=%d  reward_per_enemy=%d" % [
		_ledger.starting_credits, _reward_per_enemy])

	_check_initial_state()
	_check_not_defeated_refusal()
	_check_invalid_references()
	_check_population_and_exclusions()
	_check_rewards()
	_check_duplicates()
	_check_player_exclusion()
	_check_non_mortal_exclusion()
	_check_totals()

	# Everything above is synchronous, so the only thing left to prove is that NOTHING pays again on
	# a later frame. Hand over to the hold and report when it closes.
	_hold_credits = _ledger.get_credits()
	_hold_awards = _ledger.awards
	_hold_rewarded = _ledger.rewarded_count()
	print("[CREDITPROBE] every eligible enemy is dead; holding %d frames to prove no second award" % HOLD_FRAMES)
	_stage = 1
	_wait = 0


# --- Initial state ------------------------------------------------------------

func _check_initial_state() -> void:
	# The probe must never inherit a balance left behind by a previous run, so the documented reset
	# is exercised FIRST and the run measures from there.
	_ledger.reset_credits()
	var start := _ledger.get_credits()
	print("[CREDITPROBE] after reset: carried=%d  awards=%d  rewarded=%d" % [
		start, _ledger.awards, _ledger.rewarded_count()])
	_expect(start == _ledger.starting_credits,
		"the carried balance returns to the documented initial value (%d)" % start)
	_expect(_ledger.awards == 0 and _ledger.credits_earned == 0,
		"a reset clears the award counters, so this run starts from a known state")
	_expect(_ledger.rewarded_count() == 0,
		"a reset forgets which enemies were paid, so this run is not relying on stale state")


# --- Eligibility: an actor that is NOT defeated must not pay -------------------

func _check_not_defeated_refusal() -> void:
	var component := _first_enemy_component()
	if component == null:
		_fail("no enemy defeat authority found to test the not-defeated refusal")
		return
	var before := _ledger.get_credits()
	var refusals_before := _ledger.awards_refused_not_defeated
	var paid := bool(_ledger.handle_defeat(component))
	var refusals_after := _ledger.awards_refused_not_defeated
	print("[CREDITPROBE] alive enemy offered as a defeat: paid=%s  balance=%d  not_defeated refusals %d -> %d" % [
		str(paid), _ledger.get_credits(), refusals_before, refusals_after])
	_expect(not paid, "an enemy that has NOT been defeated is refused")
	_expect(_ledger.get_credits() == before, "a refused award leaves the balance untouched")
	_expect(refusals_after > refusals_before,
		"the refusal is counted by cause (not_defeated), not silently dropped")


# --- Eligibility: invalid and freed references must fail safely ----------------

func _check_invalid_references() -> void:
	var before := _ledger.get_credits()
	var refusals_before := _ledger.awards_refused_invalid

	_expect(not bool(_ledger.handle_defeat(null)),
		"a null reference is refused without paying")
	_expect(_ledger.get_credits() == before,
		"a null reference leaves the balance untouched")

	# The classic stale reference. A freed node must not raise, and must not pay.
	var doomed := Node.new()
	doomed.name = "FreedDefeatAuthority"
	add_child(doomed)
	doomed.free()
	var freed_paid := bool(_ledger.handle_defeat(doomed))

	print("[CREDITPROBE] invalid references: freed paid=%s  balance=%d  invalid refusals %d -> %d" % [
		str(freed_paid), _ledger.get_credits(), refusals_before, _ledger.awards_refused_invalid])
	_expect(not freed_paid, "a freed reference is refused without raising")
	_expect(_ledger.get_credits() == before, "a freed reference cannot generate a reward")
	_expect(_ledger.awards_refused_invalid > refusals_before,
		"invalid references are counted by cause")


# --- Enumeration: who is eligible, and who is excluded by rule -----------------

## The intended reward population, discovered by ENUMERATION rather than declared as a name list.
func _eligible_enemies() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("is_defeated") or not node.has_method("is_mortal"):
			continue
		if not bool(node.call("is_mortal")):
			continue
		var actor := node.get_parent()
		if actor == null or not is_instance_valid(actor):
			continue
		if actor.is_in_group(CreditLedger.GROUP_PLAYER_ACTOR):
			continue
		out.append(node)
	out.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.get_parent().name) < String(b.get_parent().name))
	return out


func _check_population_and_exclusions() -> void:
	_eligible = _eligible_enemies()
	print("[CREDITPROBE] eligible enemies discovered by enumeration: %d" % _eligible.size())
	for node in _eligible:
		print("[CREDITPROBE]   eligible: %s" % String(node.get_parent().name))

	_expect(_eligible.size() >= 1,
		"at least one eligible enemy exists (an empty population would make every reward check vacuous)")

	# The PLAYER must not be in the reward population: the player carries the resettable
	# DeathComponent, not an EnemyDeathComponent, so it is structurally absent - not merely skipped.
	var player := get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR)
	if player == null:
		_fail("no player-controlled actor found to check the exclusion")
		return
	var player_death := player.get_node_or_null("Death")
	print("[CREDITPROBE] player exclusion: player=%s  has Death=%s" % [
		String(player.name), str(player_death != null)])
	_expect(not player.is_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH),
		"the player is NOT in the enemy defeat population (excluded by archetype, not by a name check)")
	if player_death != null:
		_expect(not player_death.is_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH),
			"the player's own death circuit is not a reward source either")


# --- The core claim: every eligible enemy pays exactly once --------------------

func _check_rewards() -> void:
	for node in _eligible:
		_kill_and_verify(node)


func _kill_and_verify(component: Node) -> void:
	var actor := component.get_parent() as Node3D
	if actor == null:
		_fail("an eligible enemy has no actor body")
		return
	var label := String(actor.name)
	var balance_before := _ledger.get_credits()
	var awards_before := _ledger.awards
	var rewarded_before := _ledger.rewarded_count()
	var health := _health_of(actor)

	# The REAL path. Nothing here calls the ledger directly.
	var applied := _apply_lethal(actor)
	var defeated := bool(component.call("is_defeated"))
	var balance_after := _ledger.get_credits()
	var gained := balance_after - balance_before
	var defeats := int(component.get("defeats")) if "defeats" in component else -1

	print("[CREDITPROBE] %-12s lethal=%s health=%.1f is_dead=%s defeated=%s defeats=%d | credits %d -> %d (+%d) awards %d -> %d rewarded %d -> %d" % [
		label, str(applied), health.current_health if health != null else -1.0,
		str(health.is_dead) if health != null else "n/a", str(defeated), defeats,
		balance_before, balance_after, gained,
		awards_before, _ledger.awards, rewarded_before, _ledger.rewarded_count()])

	_expect(defeated, "%s: entered the authoritative defeated state" % label)
	_expect(gained == _reward_per_enemy,
		"%s: the defeat awarded exactly %d Credits (got %d)" % [label, _reward_per_enemy, gained])
	_expect(_ledger.awards == awards_before + 1,
		"%s: exactly ONE award was granted for the defeat" % label)
	_expect(_ledger.rewarded_count() == rewarded_before + 1,
		"%s: the enemy is now recorded as paid, so it cannot pay twice" % label)


# --- Duplicate prevention -----------------------------------------------------

func _check_duplicates() -> void:
	var balance_before := _ledger.get_credits()
	var awards_before := _ledger.awards
	var refusals_before := _ledger.awards_refused_duplicate
	var all_refused := true
	for node in _eligible:
		if bool(_ledger.handle_defeat(node)):
			all_refused = false

	print("[CREDITPROBE] duplicate check: balance %d -> %d  awards %d -> %d  duplicate refusals %d -> %d" % [
		balance_before, _ledger.get_credits(), awards_before, _ledger.awards,
		refusals_before, _ledger.awards_refused_duplicate])

	_expect(all_refused, "re-observing the SAME defeat on every eligible enemy paid nothing")
	_expect(_ledger.get_credits() == balance_before,
		"repeated death observations did not move the balance")
	_expect(_ledger.awards == awards_before,
		"repeated death observations granted no extra award")
	_expect(_ledger.awards_refused_duplicate > refusals_before,
		"the duplicate refusal is counted by cause, not silently dropped")


# --- Exclusion: the player ----------------------------------------------------

func _check_player_exclusion() -> void:
	var player := get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR)
	if player == null:
		_fail("no player-controlled actor found for the exclusion check")
		return
	var player_death := player.get_node_or_null("Death")
	if player_death == null:
		_fail("the player has no death circuit to offer as a false reward source")
		return

	var balance_before := _ledger.get_credits()
	var refusals_before := _ledger.awards_refused_player
	var paid := bool(_ledger.handle_defeat(player_death))

	print("[CREDITPROBE] player exclusion: paid=%s  balance %d -> %d  player refusals %d -> %d" % [
		str(paid), balance_before, _ledger.get_credits(),
		refusals_before, _ledger.awards_refused_player])

	_expect(not paid, "the player is NEVER an enemy reward source")
	_expect(_ledger.get_credits() == balance_before,
		"offering the player as a defeated enemy did not move the balance")
	_expect(_ledger.awards_refused_player > refusals_before,
		"the player refusal is counted by cause")


# --- Exclusion: a non-mortal actor --------------------------------------------

func _check_non_mortal_exclusion() -> void:
	# Built at runtime on purpose: no arena actor declares itself non-mortal, and manufacturing a
	# scene actor just to sit in the arena would be worse than building one for the measurement.
	var holder := Node3D.new()
	holder.name = "NonMortalProbeActor"
	var health := HealthComponent.new()
	health.name = "Health"
	health.debug_logging = false
	holder.add_child(health)
	var death := EnemyDeathComponent.new()
	death.name = "Death"
	death.mortal = false
	death.debug_logging = false
	holder.add_child(death)
	add_child(holder)

	var signals := [0]
	death.defeated.connect(func() -> void: signals[0] += 1)

	var balance_before := _ledger.get_credits()
	var refusals_before := _ledger.awards_refused_non_mortal

	# A lethal hit through the real chain. The actor is damageable and DOES reach zero health.
	health.apply_damage(_lethal_event(LETHAL))
	var defeated := bool(death.call("is_defeated"))
	var signal_count: int = signals[0]

	# And the direct query, so the refusal is proven to be a rule rather than a moot case.
	var offered := bool(_ledger.handle_defeat(death))

	print("[CREDITPROBE] non-mortal actor: health=%.1f is_dead=%s mortal=%s is_defeated=%s defeated_signals=%d offered=%s | non_mortal refusals %d -> %d" % [
		health.current_health, str(health.is_dead), str(bool(death.call("is_mortal"))),
		str(defeated), signal_count, str(offered),
		refusals_before, _ledger.awards_refused_non_mortal])

	_expect(is_zero_approx(health.current_health) and health.is_dead,
		"the non-mortal actor still takes damage and still reaches zero health")
	_expect(not defeated,
		"a non-mortal actor never enters the mortal defeat path (is_defeated=false)")
	_expect(signal_count == 0,
		"a non-mortal actor never emits the defeated signal, so it cannot pay even in principle")
	_expect(not offered and _ledger.awards_refused_non_mortal > refusals_before,
		"offering it directly is refused AS non-mortal and counted by cause")
	_expect(_ledger.get_credits() == balance_before,
		"a non-mortal actor cannot generate a reward")

	remove_child(holder)
	holder.queue_free()


# --- Balance ------------------------------------------------------------------

func _check_totals() -> void:
	var expected := _eligible.size() * _reward_per_enemy
	var carried := _ledger.get_credits()
	print("[CREDITPROBE] totals: %d eligible x %d = %d expected; carried=%d earned=%d awards=%d rewarded=%d" % [
		_eligible.size(), _reward_per_enemy, expected, carried, _ledger.credits_earned,
		_ledger.awards, _ledger.rewarded_count()])
	_expect(carried == expected,
		"the carried balance equals the sum of eligible rewards (%d == %d)" % [carried, expected])
	_expect(_ledger.credits_earned == expected,
		"the earned total matches the carried balance, so nothing was lost on the way in")
	_expect(_ledger.awards == _eligible.size(),
		"exactly one award per eligible enemy (%d == %d)" % [_ledger.awards, _eligible.size()])
	_expect(_ledger.rewarded_count() == _eligible.size(),
		"every eligible enemy is recorded as paid (%d of %d)" % [
			_ledger.rewarded_count(), _eligible.size()])


# --- The hold: nothing pays again on a later frame -----------------------------

func _tick_hold() -> void:
	_wait += 1
	if _wait < HOLD_FRAMES:
		return

	var carried := _ledger.get_credits()
	print("[CREDITPROBE] after %d held frames: carried %d -> %d  awards %d -> %d  rewarded %d -> %d" % [
		HOLD_FRAMES, _hold_credits, carried, _hold_awards, _ledger.awards,
		_hold_rewarded, _ledger.rewarded_count()])
	_expect(carried == _hold_credits,
		"%d frames after every defeat, the carried balance is unchanged" % HOLD_FRAMES)
	_expect(_ledger.awards == _hold_awards,
		"%d frames after every defeat, no further award was granted" % HOLD_FRAMES)
	_expect(_ledger.rewarded_count() == _hold_rewarded,
		"the paid-enemy set did not grow on later frames")

	_done = true
	_report()


# --- Damage -------------------------------------------------------------------

func _lethal_event(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	event.source = null
	return event


## One lethal blow through the existing receiving volume, which is the same route a real attack takes.
func _apply_lethal(actor: Node3D) -> bool:
	var hurtbox := _hurtbox_of(actor)
	if hurtbox != null:
		return hurtbox.receive_hit(_lethal_event(LETHAL))
	var health := _health_of(actor)
	if health != null:
		return health.apply_damage(_lethal_event(LETHAL))
	return false


# --- Resolution ---------------------------------------------------------------

func _first_enemy_component() -> Node:
	var all := get_tree().get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH)
	for node in all:
		if node != null and is_instance_valid(node):
			return node
	return null


func _health_of(actor: Node) -> HealthComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null


func _hurtbox_of(actor: Node) -> HurtboxComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is HurtboxComponent:
			return child as HurtboxComponent
	return null


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[CREDITPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[CREDITPROBE]   FAIL  %s" % label)


func _report() -> void:
	print("[CREDITPROBE] --- summary ---")
	print("[CREDITPROBE] eligible enemies=%d  carried=%d  awards=%d" % [
		_eligible.size(), _ledger.get_credits() if _ledger != null else -1,
		_ledger.awards if _ledger != null else -1])
	if _failures.is_empty():
		print("[CREDITPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[CREDITPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
