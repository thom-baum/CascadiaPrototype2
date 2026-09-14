class_name StaminaProbeDebug
extends Node3D
## Temporary Milestone 5 diagnostic (not production).
##
## Drives the stamina pool through a scripted sequence and prints measured
## results, so each Milestone 5 claim is checkable from output rather than taken
## on trust:
##
##   - a fresh pool is full
##   - try_spend() debits exactly the cost, atomically
##   - an unaffordable spend is refused and changes NOTHING (no partial debit)
##   - regeneration stays paused for regen_delay after a spend, then resumes
##   - depletion is announced exactly once
##   - an attack the pool cannot afford is refused WITHOUT starting
##   - an affordable attack starts and debits exactly its own cost
##   - drain() empties continuously and reports the floor
##
## Deterministic checks switch regeneration OFF for their duration so a passing
## result cannot be an accident of timing. Regeneration is only re-enabled for
## the checks that are about regeneration.
##
## It does NOT synthesise input. It calls the component and the state machine
## directly, so what is under test is the pool's own arithmetic and the attack
## cost gate, not the input buffer's.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames to let the scene settle before the first check.
const SETTLE_FRAMES := 12
## Wall-clock tolerance for the regeneration checks, in seconds.
const REGEN_PAUSE_WINDOW := 0.30
const REGEN_RESUME_WINDOW := 1.60

var _player: CharacterBody3D
var _combat: PlayerCombat
var _controller: PlayerController
var _stamina: StaminaComponent

var _failures: Array = []
## Counted in a MEMBER, not a captured local. A GDScript lambda captures locals by
## value, so `depleted_signals += 1` inside the signal handler would increment a
## private copy and the outer counter would always read 0 - which looked exactly
## like the signal never firing. Counting into a member is what makes this check
## about the component rather than about closure semantics.
var _depleted_signals := 0


func _ready() -> void:
	# The arena ships a live test attacker for human playtesting. A probe measures
	# one system deterministically, so any ambient hostile is stood down here.
	# Group-based and duck-typed on purpose: this must not reference the attacker
	# class, whose newly added members are invisible until the class cache refreshes.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	_resolve()
	if _stamina == null or _combat == null or _controller == null:
		_finish()
		return
	_audit()
	_run()


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
	_controller = _player as PlayerController
	_combat = main.get_node_or_null(base + "Player/Combat") as PlayerCombat
	_stamina = main.get_node_or_null(base + "Player/Stamina") as StaminaComponent

	_expect(_player != null, "player found")
	_expect(_controller != null, "player PlayerController found")
	_expect(_combat != null, "player Combat state machine found")
	_expect(_stamina != null, "player Stamina component found as Player/Stamina")


func _audit() -> void:
	print("[STAMPROBE] --- wiring audit ---")
	print("[STAMPROBE] stamina max=%.1f regen=%.1f/s delay=%.2fs" % [
		_stamina.max_stamina, _stamina.regen_per_second, _stamina.regen_delay])
	print("[STAMPROBE] attack costs light=%.1f heavy=%.1f" % [
		_combat.light_stamina_cost, _combat.heavy_stamina_cost])
	print("[STAMPROBE] sprint drain=%.1f/s" % _controller.sprint_stamina_per_second)

	# Both consumers must actually resolve the SAME pool. A path that silently
	# misses would make the whole system inert while looking wired.
	_expect(_combat.get_node_or_null(_combat.stamina_path) == _stamina,
		"combat stamina_path resolves to the player's Stamina node")
	_expect(_controller.get_node_or_null(_controller.stamina_path) == _stamina,
		"controller stamina_path resolves to the player's Stamina node")
	_expect(_stamina.max_stamina > 0.0, "max_stamina is positive")
	_expect(_combat.light_stamina_cost > 0.0 and _combat.heavy_stamina_cost > 0.0,
		"both attacks carry a positive stamina cost")
	_expect(_combat.heavy_stamina_cost > _combat.light_stamina_cost,
		"heavy costs more than light (commitment is priced higher)")


func _run() -> void:
	await _frames(SETTLE_FRAMES)

	# --- P1 fresh pool is full ---------------------------------------------
	_stamina.regen_enabled = false
	_stamina.reset()
	print("[STAMPROBE] --- P1 fresh pool ---")
	_expect(is_equal_approx(_stamina.current_stamina, _stamina.max_stamina),
		"a reset pool is full (%.1f/%.1f)" % [_stamina.current_stamina, _stamina.max_stamina])
	_expect(_stamina.is_full(), "is_full() agrees the pool is full")
	_expect(is_equal_approx(_stamina.fraction(), 1.0), "fraction() is 1.0 when full")

	# --- P2 an affordable spend debits exactly the cost ---------------------
	print("[STAMPROBE] --- P2 affordable spend ---")
	var before := _stamina.current_stamina
	var spent_before := _stamina.spent_count
	var accepted := _stamina.try_spend(30.0)
	_expect(accepted, "try_spend(30) on a full pool is accepted")
	_expect(is_equal_approx(_stamina.current_stamina, before - 30.0),
		"exactly 30 was debited (%.1f -> %.1f)" % [before, _stamina.current_stamina])
	_expect(_stamina.spent_count == spent_before + 1,
		"the accepted spend was counted once")

	# --- P3 an unaffordable spend changes NOTHING ---------------------------
	print("[STAMPROBE] --- P3 refusal is atomic ---")
	_stamina.reset()
	_stamina.try_spend(_stamina.max_stamina - 5.0)   # leave 5
	var short := _stamina.current_stamina
	var refused_before := _stamina.refused_count
	var over := _stamina.try_spend(short + 10.0)
	_expect(not over, "try_spend for more than the pool holds is refused")
	_expect(is_equal_approx(_stamina.current_stamina, short),
		"the refused spend left the pool untouched (%.1f)" % _stamina.current_stamina)
	_expect(_stamina.refused_count == refused_before + 1,
		"the refusal was counted once")

	# --- P4 an unaffordable ATTACK does not start ---------------------------
	print("[STAMPROBE] --- P4 unaffordable attack is refused, not started ---")
	_stamina.reset()
	_stamina.try_spend(_stamina.max_stamina)         # empty the pool
	var started_before := _combat.attacks_started
	var atk_refused_before := _combat.attacks_refused_by_stamina
	var attack_ok := _combat.try_start(_combat.light_attack)
	_expect(not attack_ok, "a light attack with an empty pool is refused")
	_expect(_combat.state == PlayerCombat.State.IDLE,
		"the refused attack left the state machine IDLE (got %s)" % _combat.state_name())
	_expect(_combat.attacks_started == started_before,
		"the refused attack was NOT counted as started")
	_expect(_combat.attacks_refused_by_stamina == atk_refused_before + 1,
		"the refusal was recorded by the state machine")

	# --- P5 an affordable attack starts AND pays ----------------------------
	print("[STAMPROBE] --- P5 affordable attack starts and pays ---")
	_stamina.reset()
	var pool_before := _stamina.current_stamina
	var paid_started := _combat.attacks_started
	var light_ok := _combat.try_start(_combat.light_attack)
	_expect(light_ok, "a light attack on a full pool is accepted")
	_expect(_combat.attacks_started == paid_started + 1, "the attack was counted as started")
	_expect(is_equal_approx(_stamina.current_stamina, pool_before - _combat.light_stamina_cost),
		"exactly the light cost was debited (%.1f -> %.1f, expected -%.1f)" % [
			pool_before, _stamina.current_stamina, _combat.light_stamina_cost])
	# Let the attack finish so the state machine is free for the heavy check.
	var guard := 0
	while _combat.state != PlayerCombat.State.IDLE and guard < 240:
		guard += 1
		await _frames(1)

	_stamina.reset()
	var pool2 := _stamina.current_stamina
	var heavy_ok := _combat.try_start(_combat.heavy_attack)
	_expect(heavy_ok, "a heavy attack on a full pool is accepted")
	_expect(is_equal_approx(_stamina.current_stamina, pool2 - _combat.heavy_stamina_cost),
		"exactly the heavy cost was debited (%.1f -> %.1f, expected -%.1f)" % [
			pool2, _stamina.current_stamina, _combat.heavy_stamina_cost])
	guard = 0
	while _combat.state != PlayerCombat.State.IDLE and guard < 240:
		guard += 1
		await _frames(1)

	# --- P6 regeneration pauses, then resumes -------------------------------
	print("[STAMPROBE] --- P6 regeneration pause and resume ---")
	_stamina.reset()
	_stamina.regen_enabled = true
	_stamina.try_spend(40.0)
	var just_spent := _stamina.current_stamina
	var t0 := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < int(REGEN_PAUSE_WINDOW * 1000.0):
		await get_tree().process_frame
	var still := _stamina.current_stamina
	_expect(is_equal_approx(still, just_spent),
		"regeneration stays paused right after a spend (%.1f -> %.1f)" % [just_spent, still])

	while (Time.get_ticks_msec() - t0) < int(REGEN_RESUME_WINDOW * 1000.0):
		await get_tree().process_frame
	var after := _stamina.current_stamina
	_expect(after > still, "regeneration resumed after the delay (%.1f -> %.1f)" % [still, after])
	_expect(after <= _stamina.max_stamina, "regeneration never exceeds the maximum")

	# --- P7 depletion edge and continuous drain -----------------------------
	print("[STAMPROBE] --- P7 drain and depletion ---")
	# Regeneration is switched OFF for this section so the numbers are
	# deterministic. With it on, regen fights the drain and every threshold here
	# depends on frame timing, which is how a depletion check can end up only
	# accidentally right.
	_stamina.regen_enabled = false
	_stamina.reset()
	_depleted_signals = 0
	_stamina.depleted.connect(_on_depleted)

	# Deterministic crossing: spend exactly what the pool holds, reaching zero in
	# a single call. This does not depend on frame timing, so if depletion fails
	# to fire here the defect is in the component rather than in this harness.
	_stamina.try_spend(_stamina.current_stamina)
	print("[STAMPROBE] spend-to-zero: stamina=%.2f depleted=%d" % [
		_stamina.current_stamina, _depleted_signals])
	_expect(is_equal_approx(_stamina.current_stamina, 0.0),
		"spending the whole pool reaches zero (%.2f)" % _stamina.current_stamina)
	_expect(_depleted_signals == 1,
		"depleted fired on the deterministic zero crossing (got %d)" % _depleted_signals)

	# Draining an already-empty pool must not re-announce depletion. The handler
	# stays connected here on purpose - disconnecting first would make this check
	# unable to fail.
	_stamina.drain(50.0)
	_expect(_depleted_signals == 1,
		"draining an already-empty pool does not re-announce (got %d)" % _depleted_signals)
	_expect(not _stamina.drain(50.0), "drain() reports failure once the pool is empty")

	# Now the continuous drain from full. 50/s at 60 Hz is under a point per
	# frame, so this is a real drain rather than one big subtraction.
	_stamina.reset()
	_depleted_signals = 0
	var start_value := _stamina.current_stamina
	var drained_frames := 0
	while _stamina.current_stamina > 0.0 and drained_frames < 600:
		drained_frames += 1
		_stamina.drain(50.0 * (1.0 / float(Engine.physics_ticks_per_second)))
		await _frames(1)
	print("[STAMPROBE] continuous drain: start=%.2f end=%.2f frames=%d depleted=%d" % [
		start_value, _stamina.current_stamina, drained_frames, _depleted_signals])
	_expect(start_value > 0.0, "continuous drain started from a full pool")
	_expect(drained_frames > 0, "the drain loop actually ran")
	_expect(is_equal_approx(_stamina.current_stamina, 0.0),
		"continuous drain emptied the pool (%.2f)" % _stamina.current_stamina)
	_expect(_depleted_signals == 1,
		"depleted fired exactly once across the drain (got %d)" % _depleted_signals)
	_stamina.depleted.disconnect(_on_depleted)

	_finish()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _on_depleted() -> void:
	_depleted_signals += 1


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[STAMPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[STAMPROBE]   FAIL  %s" % label)


func _finish() -> void:
	print("[STAMPROBE] --- summary ---")
	if _stamina != null:
		print("[STAMPROBE] final stamina=%.1f/%.1f spent=%d refused=%d" % [
			_stamina.current_stamina, _stamina.max_stamina,
			_stamina.spent_count, _stamina.refused_count])
	if _combat != null:
		print("[STAMPROBE] attacks started=%d refused_by_stamina=%d" % [
			_combat.attacks_started, _combat.attacks_refused_by_stamina])
	if _failures.is_empty():
		print("[STAMPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[STAMPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
