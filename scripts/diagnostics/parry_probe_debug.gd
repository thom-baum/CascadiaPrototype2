class_name ParryProbeDebug
extends Node3D
## Temporary Milestone 7 diagnostic (not production).
##
## Measures the parry against its acceptance criteria, so each claim is checkable
## from output rather than taken on trust:
##
##   AC1 timeline    - the parry runs STARTUP -> WINDOW -> RECOVERY in that order,
##                     for the authored total duration, and returns to idle by itself.
##   AC2 stationary  - a parry does not move the body, even with movement held.
##   AC3 cost        - exactly one stamina cost is charged, and an unaffordable
##                     parry is refused, starts nothing, spends nothing and is counted.
##   AC4 window      - damage is refused inside the window and applies during
##                     startup and recovery, so a mistimed parry is punished.
##   AC5 exclusion   - an attack or dodge cannot start during a parry, and a parry
##                     cannot start during an attack or a dodge.
##   AC6 input path  - the physical parry binding actually produces a parry, via a
##                     real injected InputEventKey (not a direct call).
##
## AC6 matters because a direct try_start() call would prove nothing about whether
## the input layer is actually wired to the parry. This injects the real key.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the physics scene to settle before the first phase.
const SETTLE_FRAMES := 12
## Hard stop, so a stuck phase reports instead of running forever.
const MAX_TOTAL_FRAMES := 3000
## Frames a wait predicate may fail before it is called stuck.
const MAX_WAIT_FRAMES := 240

## How far the measured total parry duration may differ from the authored one.
## The authored total is 0.60 s; one physics frame is 0.0167 s, so this allows
## roughly three frames of discretisation.
const DURATION_TOLERANCE := 0.06
## A parry is stationary: total horizontal travel must stay under this, in metres.
## One frame of residual slide at walk speed would be ~0.05 m, so this is tight
## enough to catch a parry that actually moved and loose enough to ignore drift.
const STATIONARY_TOLERANCE := 0.05

## Open ground with clear space all round: walls are at +/-20, the step lane is at
## x = -7 and the ramp lane at x = +7, and nothing sits between z 6.6 and 10 at x 0.
## The parry never moves, but starting on the same known-clear lane the dodge probe
## uses keeps the two probes comparable.
const PARRY_ORIGIN := Vector3(0.0, 0.3, 10.0)

# Phase steps.
const S_SETTLE := 0
const S_TIMELINE_START := 1
const S_TIMELINE_RUN := 2
const S_TIMELINE_EVAL := 3
const S_WINDOW_START := 4
const S_WINDOW_RUN := 5
const S_WINDOW_EVAL := 6
const S_UNAFFORDABLE := 7
const S_SECOND_PARRY := 8
const S_ATTACK_DURING_PARRY := 9
const S_WAIT_ATTACK := 10
const S_DODGE_DURING_PARRY := 11
const S_WAIT_DODGE := 12
const S_PARRY_DURING_ATTACK := 13
const S_WAIT_ATTACK_2 := 14
const S_PARRY_DURING_DODGE := 15
const S_WAIT_DODGE_2 := 16
const S_INPUT_PRESS := 17
const S_INPUT_POLL := 18
const S_INPUT_DONE := 19
const S_FINISH := 20

var _player: CharacterBody3D
var _parry: ParryComponent
var _dodge: DodgeComponent
var _combat: PlayerCombat
var _stamina: StaminaComponent
var _health: HealthComponent
var _hurt: HurtboxComponent
var _input: CascadiaInput

var _frame := 0
var _step := S_SETTLE
var _done := false
var _wait := 0
var _failures: Array = []

# Signal tallies, so "exactly one" claims are counted rather than assumed.
var _started_signals := 0
var _finished_signals := 0
var _last_finished_landed := false
var _stamina_refusal_signals := 0
var _parry_refusal_signals := 0

# Timeline phase accumulators.
var _start_frame := 0
var _phase_sequence: Array = []
var _window_samples := 0
var _window_flag_mismatch := 0
var _last_position := Vector3.ZERO
var _timeline_travel := 0.0
## AC2's measured travel, kept for the summary: _timeline_travel itself is cleared
## by _reset_actor() before the later phases run, so the raw var reads 0 by the end.
## (This mirrors the defect found in the dodge probe, where the summary printed the
## cleared accumulator and contradicted its own passing assertion.)
var _measured_travel := 0.0
var _finished_before := 0

# Window phase accumulators.
var _applied_in_startup := 0
var _refused_in_startup := 0
var _applied_in_window := 0
var _refused_in_window := 0
var _applied_in_recovery := 0
var _refused_in_recovery := 0
var _health_before_window := 0.0
var _hurt_parry_before := 0
var _parry_total_before := 0

# Input-path accumulators.
var _parries_before_input := 0


func _ready() -> void:
	# The arena ships a live test attacker for human playtesting. A probe measures
	# one system deterministically, so any ambient hostile is stood down here.
	# Group-based and duck-typed on purpose: this must not reference the attacker
	# class, whose newly added members are invisible until the class cache refreshes.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	_resolve()
	if _parry == null or _dodge == null or _combat == null or _stamina == null \
			or _health == null or _hurt == null or _player == null:
		_finish()
		return
	_parry.parry_started.connect(_on_parry_started)
	_parry.parry_finished.connect(_on_parry_finished)
	_parry.parry_refused_by_stamina.connect(_on_parry_stamina_refused)
	_hurt.damage_refused_by_parry.connect(_on_hit_refused_by_parry)
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
	_parry = main.get_node_or_null(base + "Player/Parry") as ParryComponent
	_dodge = main.get_node_or_null(base + "Player/Dodge") as DodgeComponent
	_combat = main.get_node_or_null(base + "Player/Combat") as PlayerCombat
	_stamina = main.get_node_or_null(base + "Player/Stamina") as StaminaComponent
	_health = main.get_node_or_null(base + "Player/Health") as HealthComponent
	_hurt = main.get_node_or_null(base + "Player/Hurtbox") as HurtboxComponent
	_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput

	_expect(_player != null, "player found")
	_expect(_parry != null, "player ParryComponent found")
	_expect(_dodge != null, "player DodgeComponent found")
	_expect(_combat != null, "player Combat state machine found")
	_expect(_stamina != null, "player StaminaComponent found")
	_expect(_health != null, "player HealthComponent found")
	_expect(_hurt != null, "player HurtboxComponent found")
	_expect(_input != null, "CascadiaInput resolved at runtime through its group")


func _audit() -> void:
	print("[PARRYPROBE] --- wiring audit ---")
	print("[PARRYPROBE] authored: startup=%.2f window=%.2f recovery=%.2f -> total=%.3fs" % [
		_parry.parry_startup, _parry.parry_window, _parry.parry_recovery,
		_parry.total_duration()])
	print("[PARRYPROBE] stamina cost=%.1f, pool=%.1f/%.1f" % [
		_parry.stamina_cost, _stamina.current_stamina, _stamina.max_stamina])

	_expect(_parry.is_in_group(ParryComponent.GROUP_PARRY),
		"parry joined its group")
	_expect(_parry.stamina_path == NodePath("../Stamina"),
		"parry stamina_path points at the sibling Stamina")
	_expect(_parry.combat_path == NodePath("../Combat"),
		"parry combat_path points at the sibling Combat")
	_expect(_parry.dodge_path == NodePath("../Dodge"),
		"parry dodge_path points at the sibling Dodge")
	_expect(_parry.get_node_or_null(_parry.stamina_path) == _stamina,
		"parry stamina_path resolves to the real StaminaComponent")
	_expect(_parry.get_node_or_null(_parry.combat_path) == _combat,
		"parry combat_path resolves to the real PlayerCombat")
	_expect(_parry.get_node_or_null(_parry.dodge_path) == _dodge,
		"parry dodge_path resolves to the real DodgeComponent")
	# The window claim is only meaningful if the hurtbox actually found the parry.
	_expect(_hurt.parry_source == _parry,
		"player Hurtbox resolved its parry source to the Parry")
	_expect(_parry.get_node_or_null(_parry.hurtbox_path) == _hurt,
		"parry hurtbox_path resolves to the real HurtboxComponent")
	# The exclusion claims are only meaningful if the other two found the parry too.
	_expect(_combat.get_node_or_null(_combat.parry_path) == _parry,
		"PlayerCombat parry_path resolves to the real ParryComponent")
	_expect(_dodge.get_node_or_null(_dodge.parry_path) == _parry,
		"DodgeComponent parry_path resolves to the real ParryComponent")

	_expect(_parry.parry_startup > 0.0, "the parry has a positive startup")
	_expect(_parry.parry_window > 0.0, "the parry has a positive window")
	_expect(_parry.parry_recovery > 0.0, "the parry has a positive recovery")
	_expect(_parry.stamina_cost > 0.0, "the parry has a positive stamina cost")
	_expect(not _parry.is_parrying(), "parry starts idle")
	_expect(not _parry.is_parry_window_open(), "the parry window starts closed")


## Put the actor back on the clear lane with a full pool and nothing committed.
func _reset_actor() -> void:
	_parry.reset()
	_dodge.reset()
	_stamina.reset()
	_player.global_position = PARRY_ORIGIN
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_last_position = _player.global_position
	_timeline_travel = 0.0


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > MAX_TOTAL_FRAMES:
		_fail("probe did not finish within %d frames" % MAX_TOTAL_FRAMES)
		_finish()
		return
	if _frame < SETTLE_FRAMES:
		return

	match _step:
		S_SETTLE:
			_step = S_TIMELINE_START

		S_TIMELINE_START:
			_timeline_start()

		S_TIMELINE_RUN:
			_timeline_sample()

		S_TIMELINE_EVAL:
			_timeline_eval()

		S_WINDOW_START:
			_window_start()

		S_WINDOW_RUN:
			_window_sample()

		S_WINDOW_EVAL:
			_window_eval()

		S_UNAFFORDABLE:
			_unaffordable_refused()

		S_SECOND_PARRY:
			_second_parry_refused()

		S_ATTACK_DURING_PARRY:
			_attack_during_parry()

		S_WAIT_ATTACK:
			if _combat.state == PlayerCombat.State.IDLE:
				_step = S_DODGE_DURING_PARRY

		S_DODGE_DURING_PARRY:
			_dodge_during_parry()

		S_WAIT_DODGE:
			if not _dodge.is_dodging():
				_step = S_PARRY_DURING_ATTACK

		S_PARRY_DURING_ATTACK:
			_parry_during_attack()

		S_WAIT_ATTACK_2:
			if _combat.state == PlayerCombat.State.IDLE:
				_step = S_PARRY_DURING_DODGE

		S_PARRY_DURING_DODGE:
			_parry_during_dodge()

		S_WAIT_DODGE_2:
			if not _dodge.is_dodging():
				_step = S_INPUT_PRESS

		S_INPUT_PRESS:
			_input_press()

		S_INPUT_POLL:
			_input_poll()

		S_INPUT_DONE:
			_input_finish()

		_:
			_finish()


# --- AC1 + AC2: timeline, phase order and stationarity ----------------------

func _timeline_start() -> void:
	_reset_actor()
	_health.reset()
	_phase_sequence = []
	_window_samples = 0
	_window_flag_mismatch = 0
	_timeline_travel = 0.0
	_last_position = _player.global_position
	_finished_before = _finished_signals
	_start_frame = _frame

	var started := _parry.try_start()
	print("[PARRYPROBE] --- AC1 timeline + AC2 stationary ---")
	_expect(started, "a parry from idle with a full pool is accepted")
	_expect(_parry.is_parrying(), "the parry reports committed on the same frame")
	_expect(_parry.state_name() == "STARTUP", "the parry begins in startup")
	_expect(not _parry.is_parry_window_open(),
		"the window is not open during startup")
	# Exactly one cost, measured immediately so no regeneration can hide in it.
	_expect(is_equal_approx(_stamina.current_stamina,
			_stamina.max_stamina - _parry.stamina_cost),
		"exactly one stamina cost was charged (%.1f -> %.1f, expected -%.1f)" % [
			_stamina.max_stamina, _stamina.current_stamina, _parry.stamina_cost])
	# Stationarity test: hold an input that would walk the actor away. If the parry
	# is genuinely stationary the commitment wins and the body does not move.
	Input.action_press(GameActions.MOVE_RIGHT)
	_step = S_TIMELINE_RUN


func _timeline_sample() -> void:
	if not _parry.is_parrying():
		Input.action_release(GameActions.MOVE_RIGHT)
		_step = S_TIMELINE_EVAL
		return

	var phase := _parry.state_name()
	if _phase_sequence.is_empty() or _phase_sequence[-1] != phase:
		_phase_sequence.append(phase)

	# The hurtbox must agree with the component about the window, otherwise one of
	# them is wrong and the refusal claim below would be measuring the wrong thing.
	if _hurt.is_parry_window_open() != _parry.is_parry_window_open():
		_window_flag_mismatch += 1
	if _parry.is_parry_window_open():
		_window_samples += 1

	var position: Vector3 = _player.global_position
	var moved := Vector3(position.x - _last_position.x, 0.0, position.z - _last_position.z)
	_timeline_travel += moved.length()
	_last_position = position


func _timeline_eval() -> void:
	var measured_duration := float(_frame - _start_frame) / float(Engine.physics_ticks_per_second)
	var authored_total := _parry.total_duration()
	_measured_travel = _timeline_travel
	print("[PARRYPROBE] phases seen: %s" % ",".join(_phase_sequence))
	print("[PARRYPROBE] measured duration=%.3fs (authored %.3fs), travel=%.3fm (while holding move_right)" % [
		measured_duration, authored_total, _measured_travel])

	_expect(",".join(_phase_sequence) == "STARTUP,WINDOW,RECOVERY",
		"the parry ran startup -> window -> recovery in order")
	_expect(absf(measured_duration - authored_total) <= DURATION_TOLERANCE,
		"measured parry duration matches the authored total")
	_expect(_window_samples > 0, "the window was open for sampled frames")
	_expect(_window_flag_mismatch == 0,
		"the hurtbox and the parry agreed on the window every frame")
	_expect(_finished_signals == _finished_before + 1,
		"parry_finished was emitted exactly once (got +%d)" % (
			_finished_signals - _finished_before))
	_expect(_last_finished_landed == false,
		"a parry that refused nothing reports landed=false")
	_expect(not _parry.is_parrying(), "the parry returned to idle on its own")
	_expect(not _parry.is_parry_window_open(), "the window is closed once the parry is over")
	_expect(_measured_travel <= STATIONARY_TOLERANCE,
		"the parry did not move the body: travel %.3fm <= %.3fm" % [
			_measured_travel, STATIONARY_TOLERANCE])

	_step = S_WINDOW_START


# --- AC4: the parry window --------------------------------------------------

func _window_start() -> void:
	_reset_actor()
	_health.reset()
	_health_before_window = _health.current_health
	_hurt_parry_before = _hurt.refusals_by_parry
	_parry_total_before = _parry.total_hits_refused
	_parry_refusal_signals = 0
	_applied_in_startup = 0
	_refused_in_startup = 0
	_applied_in_window = 0
	_refused_in_window = 0
	_applied_in_recovery = 0
	_refused_in_recovery = 0
	_finished_before = _finished_signals
	_expect(_parry.try_start(), "parry for the window test accepted")
	_step = S_WINDOW_RUN


## Offer one point of damage every frame of the parry and classify the answer
## against the component's own window report. The classification IS the test:
## damage must be refused exactly while the window is open, and must land during
## startup and recovery - that is what makes a mistimed parry punishable.
func _window_sample() -> void:
	if not _parry.is_parrying():
		_step = S_WINDOW_EVAL
		return

	var phase := _parry.state_name()
	var window_open: bool = _parry.is_parry_window_open()
	# Cross-check the phase name against the flag the hurtbox actually reads.
	if (phase == "WINDOW") != window_open:
		_window_flag_mismatch += 1

	var event := DamageEvent.new()
	event.amount = 1.0
	var applied: bool = _hurt.receive_hit(event)

	if window_open:
		if applied:
			_applied_in_window += 1
		else:
			_refused_in_window += 1
	match phase:
		"STARTUP":
			if applied:
				_applied_in_startup += 1
			else:
				_refused_in_startup += 1
		"RECOVERY":
			if applied:
				_applied_in_recovery += 1
			else:
				_refused_in_recovery += 1


func _window_eval() -> void:
	var applied_total := _applied_in_startup + _applied_in_recovery + _applied_in_window
	print("[PARRYPROBE] --- AC4 window ---")
	print("[PARRYPROBE] window open: refused=%d applied=%d" % [
		_refused_in_window, _applied_in_window])
	print("[PARRYPROBE] startup: applied=%d refused=%d" % [
		_applied_in_startup, _refused_in_startup])
	print("[PARRYPROBE] recovery: applied=%d refused=%d" % [
		_applied_in_recovery, _refused_in_recovery])
	print("[PARRYPROBE] health %.1f -> %.1f, hurtbox parry refusals +%d" % [
		_health_before_window, _health.current_health,
		_hurt.refusals_by_parry - _hurt_parry_before])

	_expect(_refused_in_window > 0, "damage inside the parry window was refused")
	_expect(_applied_in_window == 0, "no damage ever landed while the window was open")
	_expect(_refused_in_startup == 0, "startup never refused damage")
	_expect(_refused_in_recovery == 0, "recovery never refused damage")
	_expect(_applied_in_startup > 0,
		"damage during startup applied (startup is vulnerable)")
	_expect(_applied_in_recovery > 0,
		"damage during recovery applied (recovery is vulnerable)")
	_expect(_window_flag_mismatch == 0,
		"the phase name and the window flag agreed every frame")
	_expect(_hurt.refusals_by_parry - _hurt_parry_before == _refused_in_window,
		"the hurtbox counted exactly the refusals it performed")
	_expect(_parry_refusal_signals == _refused_in_window,
		"the parry-refusal signal fired once per refusal (got %d vs %d)" % [
			_parry_refusal_signals, _refused_in_window])
	_expect(_parry.total_hits_refused - _parry_total_before == _refused_in_window,
		"the parry counted exactly the hits it refused")
	_expect(_last_finished_landed == true,
		"a parry that refused a hit reports landed=true")
	_expect(is_equal_approx(_health.current_health,
			_health_before_window - float(applied_total)),
		"health lost exactly the damage that applied (%.1f -> %.1f)" % [
			_health_before_window, _health.current_health])

	_health.reset()
	_step = S_UNAFFORDABLE


# --- AC3: an unaffordable parry is refused atomically ----------------------

func _unaffordable_refused() -> void:
	_reset_actor()
	# Leave less than the cost but more than zero, so "refused" cannot be confused
	# with "the pool was already empty".
	var target := _parry.stamina_cost - 5.0
	_stamina.drain(_stamina.current_stamina - target)
	var pool_before := _stamina.current_stamina
	var started_before := _parry.parries_started
	var refused_before := _parry.parries_refused_by_stamina
	_stamina_refusal_signals = 0

	var started := _parry.try_start()
	print("[PARRYPROBE] --- AC3 cost/refusal ---")
	print("[PARRYPROBE] pool %.1f vs cost %.1f: parry accepted=%s" % [
		pool_before, _parry.stamina_cost, str(started)])

	_expect(pool_before < _parry.stamina_cost, "the pool really is short of the cost")
	_expect(not started, "an unaffordable parry is refused")
	_expect(not _parry.is_parrying(), "the refused parry started nothing")
	_expect(_parry.parries_started == started_before,
		"the refused parry was not counted as started")
	_expect(_parry.parries_refused_by_stamina == refused_before + 1,
		"the refusal was counted by cause (insufficient stamina)")
	_expect(is_equal_approx(_stamina.current_stamina, pool_before),
		"the refused parry spent nothing (%.1f -> %.1f)" % [
			pool_before, _stamina.current_stamina])
	_expect(_stamina_refusal_signals == 1,
		"the stamina-refusal signal fired exactly once (got %d)" % _stamina_refusal_signals)

	_stamina.reset()
	_step = S_SECOND_PARRY


# --- AC5: a second parry during a parry is refused --------------------------

func _second_parry_refused() -> void:
	_reset_actor()
	var started_before := _parry.parries_started
	var refused_before := _parry.parries_refused_while_parrying
	_expect(_parry.try_start(), "first parry of the pair accepted")
	var second := _parry.try_start()
	print("[PARRYPROBE] --- AC5 second parry during parry ---")
	print("[PARRYPROBE] second parry accepted=%s" % str(second))
	_expect(not second, "a second parry during the first is refused")
	_expect(_parry.parries_started == started_before + 1,
		"the refused parry was not counted as started")
	_expect(_parry.parries_refused_while_parrying == refused_before + 1,
		"the refusal was counted by cause (already parrying)")
	_expect(_parry.is_parrying(), "the committed parry was left untouched by the refusal")
	_parry.reset()
	_step = S_ATTACK_DURING_PARRY


# --- AC5: mutual exclusion, both directions ---------------------------------

func _attack_during_parry() -> void:
	_reset_actor()
	var attacks_before := _combat.attacks_started
	var refused_before := _combat.attacks_refused_while_parrying
	_expect(_parry.try_start(), "parry for the exclusion test accepted")
	# Called directly, not through input: the exclusion must be structural, so
	# there must be no route into an attack out of a parry from code either.
	var attack := _combat.try_start(_combat.light_attack)
	print("[PARRYPROBE] --- AC5 attack during parry ---")
	print("[PARRYPROBE] attack accepted while parrying=%s" % str(attack))
	_expect(not attack, "an attack during a committed parry is refused")
	_expect(_combat.attacks_started == attacks_before,
		"the refused attack was not counted as started")
	_expect(_combat.attacks_refused_while_parrying == refused_before + 1,
		"the attack refusal during a parry was counted by cause")
	_expect(_combat.state == PlayerCombat.State.IDLE,
		"the attack state machine was left untouched by the refusal")
	_parry.reset()
	_step = S_DODGE_DURING_PARRY


func _dodge_during_parry() -> void:
	_reset_actor()
	var dodges_before := _dodge.dodges_started
	var refused_before := _dodge.dodges_refused_while_parrying
	_expect(_parry.try_start(), "parry for the dodge-exclusion test accepted")
	var dodge := _dodge.try_start(Vector3(0.0, 0.0, -1.0))
	print("[PARRYPROBE] --- AC5 dodge during parry ---")
	print("[PARRYPROBE] dodge accepted while parrying=%s" % str(dodge))
	_expect(not dodge, "a dodge during a committed parry is refused")
	_expect(not _dodge.is_dodging(), "the refused dodge started nothing")
	_expect(_dodge.dodges_started == dodges_before,
		"the refused dodge was not counted as started")
	_expect(_dodge.dodges_refused_while_parrying == refused_before + 1,
		"the dodge refusal during a parry was counted by cause")
	_parry.reset()
	_step = S_PARRY_DURING_ATTACK


func _parry_during_attack() -> void:
	_reset_actor()
	var started_before := _parry.parries_started
	var refused_before := _parry.parries_refused_while_attacking
	_expect(_combat.try_start(_combat.light_attack), "attack for the exclusion test accepted")
	var parry := _parry.try_start()
	print("[PARRYPROBE] --- AC5 parry during attack ---")
	print("[PARRYPROBE] parry accepted while attacking=%s" % str(parry))
	_expect(not parry, "a parry during a committed attack is refused")
	_expect(not _parry.is_parrying(), "the refused parry started nothing")
	_expect(_parry.parries_started == started_before,
		"the refused parry was not counted as started")
	_expect(_parry.parries_refused_while_attacking == refused_before + 1,
		"the parry refusal during an attack was counted by cause")
	_step = S_WAIT_ATTACK_2


func _parry_during_dodge() -> void:
	_reset_actor()
	var started_before := _parry.parries_started
	var refused_before := _parry.parries_refused_while_dodging
	_expect(_dodge.try_start(Vector3(0.0, 0.0, -1.0)), "dodge for the exclusion test accepted")
	var parry := _parry.try_start()
	print("[PARRYPROBE] --- AC5 parry during dodge ---")
	print("[PARRYPROBE] parry accepted while dodging=%s" % str(parry))
	_expect(not parry, "a parry during a committed dodge is refused")
	_expect(not _parry.is_parrying(), "the refused parry started nothing")
	_expect(_parry.parries_started == started_before,
		"the refused parry was not counted as started")
	_expect(_parry.parries_refused_while_dodging == refused_before + 1,
		"the parry refusal during a dodge was counted by cause")
	_dodge.reset()
	_step = S_INPUT_PRESS


# --- AC6: the physical input path -------------------------------------------

func _input_press() -> void:
	_reset_actor()
	_parries_before_input = _parry.parries_started
	var event := _parry_key_event(true)
	if event == null:
		_fail("the parry action has no keyboard binding to inject")
		_step = S_INPUT_DONE
		return
	print("[PARRYPROBE] --- AC6 physical input path ---")
	print("[PARRYPROBE] injecting key press for action '%s' (keycode %d)" % [
		str(GameActions.PARRY), event.keycode])
	Input.parse_input_event(event)
	_wait = 0
	_step = S_INPUT_POLL


func _input_poll() -> void:
	_wait += 1
	# Release on the frame after the press, so exactly one press is delivered.
	if _wait == 1:
		var release := _parry_key_event(false)
		if release != null:
			Input.parse_input_event(release)
	if _parry.parries_started > _parries_before_input:
		_step = S_INPUT_DONE
		return
	if _wait > MAX_WAIT_FRAMES:
		_fail("the injected parry key produced no parry after %d frames" % MAX_WAIT_FRAMES)
		_step = S_INPUT_DONE


func _input_finish() -> void:
	var started := _parry.parries_started - _parries_before_input
	print("[PARRYPROBE] injected parry key produced %d parry(s)" % started)
	_expect(started == 1,
		"the physical parry binding produced exactly one parry (got %d)" % started)
	_expect(_started_signals > 0,
		"parry_started fired at least once across the run")
	_step = S_FINISH


## The first keyboard event bound to the parry action, rebuilt as a fresh event so
## the probe drives the real InputMap binding rather than a hard-coded key.
func _parry_key_event(pressed: bool) -> InputEventKey:
	if not InputMap.has_action(GameActions.PARRY):
		return null
	for bound in InputMap.action_get_events(GameActions.PARRY):
		var key: InputEventKey = bound as InputEventKey
		if key != null:
			var event := InputEventKey.new()
			event.keycode = key.keycode
			event.physical_keycode = key.physical_keycode
			event.pressed = pressed
			return event
	return null


# --- Signal handlers --------------------------------------------------------

func _on_parry_started() -> void:
	_started_signals += 1


func _on_parry_finished(landed: bool) -> void:
	_finished_signals += 1
	_last_finished_landed = landed


func _on_parry_stamina_refused(_cost: float) -> void:
	_stamina_refusal_signals += 1


func _on_hit_refused_by_parry(_event: DamageEvent) -> void:
	_parry_refusal_signals += 1


# --- Reporting --------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[PARRYPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[PARRYPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	Input.action_release(GameActions.MOVE_RIGHT)
	print("[PARRYPROBE] --- summary ---")
	print("[PARRYPROBE] parries started=%d, finished signals=%d, measured travel=%.3fm" % [
		_parry.parries_started if _parry != null else -1,
		_finished_signals, _measured_travel])
	if _failures.is_empty():
		print("[PARRYPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[PARRYPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
