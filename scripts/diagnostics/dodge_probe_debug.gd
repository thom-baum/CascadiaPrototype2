class_name DodgeProbeDebug
extends Node3D
## Temporary Milestone 6 diagnostic (not production).
##
## Measures the dodge against its acceptance criteria, so each claim is checkable
## from output rather than taken on trust:
##
##   AC1 commitment  - a dodge cannot be steered, cannot be cancelled, and a
##                     second dodge during one is refused outright.
##   AC2 travel      - measured duration and distance match speed x duration.
##   AC3 cost        - exactly one stamina cost is charged, and an unaffordable
##                     dodge is refused, starts nothing and is counted.
##   AC4 i-frames    - damage is refused inside the window and applies outside it.
##   AC5 exclusion   - an attack cannot start during a dodge, and a dodge cannot
##                     start during an attack.
##   AC6 input path  - the physical dodge binding actually produces a dodge, via
##                     a real injected InputEventKey (not a direct call).
##
## AC6 matters because the attack probes could only ever call try_start() directly.
## This one injects the real key through the real input layer.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the physics scene to settle before the first phase.
const SETTLE_FRAMES := 12
## Hard stop, so a stuck phase reports instead of running forever.
const MAX_TOTAL_FRAMES := 3000
## Frames a wait predicate may fail before it is called stuck.
const MAX_WAIT_FRAMES := 240

## How far a measured phase duration may differ from the authored duration.
const DURATION_TOLERANCE := 0.06
## How far measured travel may differ from speed x duration. One frame of
## discretisation at dodge speed is 7.5/60 = 0.125 m, so this allows one frame.
const DISTANCE_TOLERANCE := 0.2
## A dodge must not deviate from its locked direction by more than this.
const STEER_TOLERANCE_DEGREES := 1.0

## Open ground with clear space all round: walls are at +/-20, the step lane is at
## x = -7 and the ramp lane at x = +7, and nothing sits between z 6.6 and 10 at x 0.
const DODGE_ORIGIN := Vector3(0.0, 0.3, 10.0)
## The direction every measured dodge is locked to.
const DODGE_DIRECTION := Vector3(0.0, 0.0, -1.0)

# Phase steps.
const S_SETTLE := 0
const S_AUDIT := 1
const S_TRAVEL_START := 2
const S_TRAVEL_RUN := 3
const S_TRAVEL_EVAL := 4
const S_SECOND_DODGE := 5
const S_UNAFFORDABLE := 6
const S_IFRAME_START := 7
const S_IFRAME_RUN := 8
const S_IFRAME_EVAL := 9
const S_ATTACK_DURING_DODGE := 10
const S_WAIT_ATTACK_END := 11
const S_DODGE_DURING_ATTACK := 12
const S_WAIT_DODGE_END := 13
const S_INPUT_PRESS := 14
const S_INPUT_POLL := 15
const S_INPUT_DONE := 16
const S_FINISH := 17

var _player: CharacterBody3D
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
var _stamina_refusal_signals := 0
var _iframe_refusal_signals := 0

# Travel phase accumulators.
var _start_frame := 0
var _last_position := Vector3.ZERO
var _travel := 0.0
## AC2's measured travel, kept for the summary: _travel itself is cleared by
## _reset_actor() before the later phases run, so the raw var reads 0 by the end.
var _measured_travel := 0.0
var _max_steer := 0.0
var _steer_samples := 0

# I-frame phase accumulators.
var _applied_while_vulnerable := 0
var _refused_while_invulnerable := 0
var _applied_while_invulnerable := 0
var _refused_while_vulnerable := 0
var _iframe_state_flips := 0
var _health_before_iframes := 0.0
var _hurt_refusals_before := 0

# Input-path accumulators.
var _dodges_before_input := 0


func _ready() -> void:
	# The arena ships a live test attacker for human playtesting. A probe measures
	# one system deterministically, so any ambient hostile is stood down here.
	# Group-based and duck-typed on purpose: this must not reference the attacker
	# class, whose newly added members are invisible until the class cache refreshes.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	_resolve()
	if _dodge == null or _combat == null or _stamina == null \
			or _health == null or _hurt == null or _player == null:
		_finish()
		return
	_dodge.dodge_started.connect(_on_dodge_started)
	_dodge.dodge_finished.connect(_on_dodge_finished)
	_dodge.dodge_refused_by_stamina.connect(_on_dodge_stamina_refused)
	_hurt.damage_refused_by_iframes.connect(_on_iframe_refused)
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
	_combat = main.get_node_or_null(base + "Player/Combat") as PlayerCombat
	_stamina = main.get_node_or_null(base + "Player/Stamina") as StaminaComponent
	_health = main.get_node_or_null(base + "Player/Health") as HealthComponent
	_hurt = main.get_node_or_null(base + "Player/Hurtbox") as HurtboxComponent
	_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput

	_expect(_player != null, "player found")
	_expect(_dodge != null, "player DodgeComponent found")
	_expect(_combat != null, "player Combat state machine found")
	_expect(_stamina != null, "player StaminaComponent found")
	_expect(_health != null, "player HealthComponent found")
	_expect(_hurt != null, "player HurtboxComponent found")
	_expect(_input != null, "CascadiaInput resolved at runtime through its group")


func _audit() -> void:
	print("[DODGEPROBE] --- wiring audit ---")
	print("[DODGEPROBE] dodge speed=%.2f duration=%.2f -> travel=%.3f m" % [
		_dodge.dodge_speed, _dodge.dodge_duration, _dodge.travel_distance()])
	print("[DODGEPROBE] i-frame window %.2f..%.2f (dodge lasts %.2f)" % [
		_dodge.iframes_start, _dodge.iframes_end, _dodge.dodge_duration])
	print("[DODGEPROBE] stamina cost=%.1f, pool=%.1f/%.1f" % [
		_dodge.stamina_cost, _stamina.current_stamina, _stamina.max_stamina])

	_expect(_dodge.is_in_group(DodgeComponent.GROUP_DODGE),
		"dodge joined its group")
	_expect(_dodge.stamina_path == NodePath("../Stamina"),
		"dodge stamina_path points at the sibling Stamina")
	_expect(_dodge.combat_path == NodePath("../Combat"),
		"dodge combat_path points at the sibling Combat")
	_expect(_dodge.get_node_or_null(_dodge.stamina_path) == _stamina,
		"dodge stamina_path resolves to the real StaminaComponent")
	_expect(_dodge.get_node_or_null(_dodge.combat_path) == _combat,
		"dodge combat_path resolves to the real PlayerCombat")
	# The i-frame claim is only meaningful if the hurtbox actually found the dodge.
	_expect(_hurt.invulnerability_source == _dodge,
		"player Hurtbox resolved its invulnerability source to the Dodge")
	_expect(_dodge.iframes_start < _dodge.iframes_end,
		"i-frame window starts before it ends")
	_expect(_dodge.iframes_end <= _dodge.dodge_duration,
		"i-frame window closes within the dodge (the tail is vulnerable)")
	_expect(_dodge.stamina_cost > 0.0, "the dodge has a positive stamina cost")
	_expect(not _dodge.is_dodging(), "dodge starts idle")


## Put the actor back on the clear lane with a full pool and nothing committed.
func _reset_actor() -> void:
	_dodge.reset()
	_stamina.reset()
	_player.global_position = DODGE_ORIGIN
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO
	_last_position = _player.global_position
	_travel = 0.0
	_max_steer = 0.0
	_steer_samples = 0


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
			_step = S_TRAVEL_START

		S_TRAVEL_START:
			_travel_start()

		S_TRAVEL_RUN:
			_travel_sample()

		S_TRAVEL_EVAL:
			_travel_eval()

		S_SECOND_DODGE:
			_second_dodge_refused()

		S_UNAFFORDABLE:
			_unaffordable_refused()

		S_IFRAME_START:
			_iframe_start()

		S_IFRAME_RUN:
			_iframe_sample()

		S_IFRAME_EVAL:
			_iframe_eval()

		S_ATTACK_DURING_DODGE:
			_attack_during_dodge()

		S_WAIT_ATTACK_END:
			if _combat.state == PlayerCombat.State.IDLE:
				_step = S_DODGE_DURING_ATTACK

		S_DODGE_DURING_ATTACK:
			_dodge_during_attack()

		S_WAIT_DODGE_END:
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


# --- AC1 + AC2: commitment, travel and duration -----------------------------

func _travel_start() -> void:
	_reset_actor()
	_start_frame = _frame
	_health.reset()
	var started := _dodge.try_start(DODGE_DIRECTION)
	_expect(started, "a dodge from idle on clear ground is accepted")
	_expect(_dodge.is_dodging(), "the dodge reports committed on the same frame")
	_expect(_dodge.direction().is_equal_approx(DODGE_DIRECTION),
		"the direction is locked to the requested direction at start")
	# Exactly one cost, measured immediately so no regeneration can hide in it.
	_expect(is_equal_approx(_stamina.current_stamina,
			_stamina.max_stamina - _dodge.stamina_cost),
		"exactly one stamina cost was charged (%.1f -> %.1f, expected -%.1f)" % [
			_stamina.max_stamina, _stamina.current_stamina, _dodge.stamina_cost])
	# Steer test: hold an input that would push the actor sideways. If the dodge
	# is genuinely committed the locked velocity wins and the path stays straight.
	Input.action_press(GameActions.MOVE_RIGHT)
	_step = S_TRAVEL_RUN


func _travel_sample() -> void:
	if not _dodge.is_dodging():
		Input.action_release(GameActions.MOVE_RIGHT)
		_step = S_TRAVEL_EVAL
		return

	var position: Vector3 = _player.global_position
	var moved := Vector3(position.x - _last_position.x, 0.0, position.z - _last_position.z)
	_travel += moved.length()
	_last_position = position

	var horizontal := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	if horizontal.length() > 0.1:
		_steer_samples += 1
		var deviation := rad_to_deg(horizontal.normalized().angle_to(DODGE_DIRECTION))
		_max_steer = maxf(_max_steer, deviation)


func _travel_eval() -> void:
	var measured_duration := float(_frame - _start_frame) / float(Engine.physics_ticks_per_second)
	var authored_travel := _dodge.travel_distance()
	_measured_travel = _travel
	print("[DODGEPROBE] --- AC2 travel ---")
	print("[DODGEPROBE] measured duration=%.3fs (authored %.3fs), travel=%.3fm (authored %.3fm)" % [
		measured_duration, _dodge.dodge_duration, _travel, authored_travel])
	print("[DODGEPROBE] steering: %d samples, max deviation %.3f deg (while holding move_right)" % [
		_steer_samples, _max_steer])

	_expect(absf(measured_duration - _dodge.dodge_duration) <= DURATION_TOLERANCE,
		"measured dodge duration matches the authored duration")
	_expect(absf(_travel - authored_travel) <= DISTANCE_TOLERANCE,
		"measured travel matches speed x duration")
	_expect(_steer_samples > 0, "the dodge was actually moving while sampled")
	_expect(_max_steer <= STEER_TOLERANCE_DEGREES,
		"the dodge could not be steered: path stayed on the locked direction")
	_expect(_finished_signals == 1,
		"dodge_finished was emitted exactly once (got %d)" % _finished_signals)
	_expect(not _dodge.is_dodging(), "the dodge returned to idle on its own")
	_expect(not _dodge.is_invulnerable(), "no i-frames remain once the dodge is over")

	_step = S_SECOND_DODGE


# --- AC1: a second dodge during a dodge is refused --------------------------

func _second_dodge_refused() -> void:
	_reset_actor()
	var started_before := _dodge.dodges_started
	var refused_before := _dodge.dodges_refused_while_dodging
	_expect(_dodge.try_start(DODGE_DIRECTION), "first dodge of the pair accepted")
	var second := _dodge.try_start(Vector3(0.0, 0.0, 1.0))
	_expect(not second, "a second dodge during the first is refused")
	_expect(_dodge.dodges_started == started_before + 1,
		"the refused dodge was not counted as started")
	_expect(_dodge.dodges_refused_while_dodging == refused_before + 1,
		"the refusal was counted by cause (already dodging)")
	_expect(_dodge.direction().is_equal_approx(DODGE_DIRECTION),
		"the refused second dodge did not re-aim the committed one")
	_dodge.reset()
	_step = S_UNAFFORDABLE


# --- AC3: an unaffordable dodge is refused atomically ----------------------

func _unaffordable_refused() -> void:
	_reset_actor()
	# Leave less than the cost but more than zero, so "refused" cannot be
	# confused with "the pool was already empty".
	var target := _dodge.stamina_cost - 5.0
	_stamina.drain(_stamina.current_stamina - target)
	var pool_before := _stamina.current_stamina
	var started_before := _dodge.dodges_started
	var refused_before := _dodge.dodges_refused_by_stamina

	var started := _dodge.try_start(DODGE_DIRECTION)
	print("[DODGEPROBE] --- AC3 cost/refusal ---")
	print("[DODGEPROBE] pool %.1f vs cost %.1f: dodge accepted=%s" % [
		pool_before, _dodge.stamina_cost, str(started)])

	_expect(pool_before < _dodge.stamina_cost, "the pool really is short of the cost")
	_expect(not started, "an unaffordable dodge is refused")
	_expect(not _dodge.is_dodging(), "the refused dodge started nothing")
	_expect(_dodge.dodges_started == started_before,
		"the refused dodge was not counted as started")
	_expect(_dodge.dodges_refused_by_stamina == refused_before + 1,
		"the refusal was counted by cause (insufficient stamina)")
	_expect(is_equal_approx(_stamina.current_stamina, pool_before),
		"the refused dodge spent nothing (%.1f -> %.1f)" % [
			pool_before, _stamina.current_stamina])
	_expect(_stamina_refusal_signals == 1,
		"the stamina-refusal signal fired exactly once (got %d)" % _stamina_refusal_signals)

	_stamina.reset()
	_step = S_IFRAME_START


# --- AC4: the i-frame window ------------------------------------------------

func _iframe_start() -> void:
	_reset_actor()
	_stamina.reset()
	_health.reset()
	_health_before_iframes = _health.current_health
	_hurt_refusals_before = _hurt.refusals_by_iframes
	_applied_while_vulnerable = 0
	_refused_while_invulnerable = 0
	_applied_while_invulnerable = 0
	_refused_while_vulnerable = 0
	_iframe_state_flips = 0
	_expect(_dodge.try_start(DODGE_DIRECTION), "dodge for the i-frame test accepted")
	_step = S_IFRAME_RUN


## Offer one point of damage every frame of the dodge and classify the answer
## against the component's own invulnerable report. The classification IS the
## test: damage must land exactly when the actor is not invulnerable.
func _iframe_sample() -> void:
	if not _dodge.is_dodging():
		_step = S_IFRAME_EVAL
		return

	var invulnerable: bool = _dodge.is_invulnerable()
	# The hurtbox must agree with the component, otherwise one of them is wrong.
	if _hurt.is_invulnerable() != invulnerable:
		_iframe_state_flips += 1

	var event := DamageEvent.new()
	event.amount = 1.0
	var applied: bool = _hurt.receive_hit(event)

	if invulnerable and not applied:
		_refused_while_invulnerable += 1
	elif invulnerable and applied:
		_applied_while_invulnerable += 1
	elif not invulnerable and applied:
		_applied_while_vulnerable += 1
	else:
		_refused_while_vulnerable += 1


func _iframe_eval() -> void:
	print("[DODGEPROBE] --- AC4 i-frames ---")
	print("[DODGEPROBE] inside window: refused=%d applied=%d" % [
		_refused_while_invulnerable, _applied_while_invulnerable])
	print("[DODGEPROBE] outside window: applied=%d refused=%d" % [
		_applied_while_vulnerable, _refused_while_vulnerable])
	print("[DODGEPROBE] health %.1f -> %.1f, hurtbox refusals +%d" % [
		_health_before_iframes, _health.current_health,
		_hurt.refusals_by_iframes - _hurt_refusals_before])

	_expect(_refused_while_invulnerable > 0,
		"damage inside the i-frame window was refused")
	_expect(_applied_while_invulnerable == 0,
		"no damage ever landed while the actor reported invulnerable")
	_expect(_applied_while_vulnerable > 0,
		"damage outside the window applied normally")
	_expect(_refused_while_vulnerable == 0,
		"no damage was refused while the actor was vulnerable")
	_expect(_iframe_state_flips == 0,
		"the hurtbox and the dodge agreed on invulnerability every frame")
	_expect(_hurt.refusals_by_iframes - _hurt_refusals_before == _refused_while_invulnerable,
		"the hurtbox counted exactly the refusals it performed")
	_expect(_iframe_refusal_signals == _refused_while_invulnerable,
		"the i-frame refusal signal fired once per refusal (got %d vs %d)" % [
			_iframe_refusal_signals, _refused_while_invulnerable])
	_expect(is_equal_approx(_health.current_health,
			_health_before_iframes - float(_applied_while_vulnerable)),
		"health lost exactly the damage that applied (%.1f -> %.1f)" % [
			_health_before_iframes, _health.current_health])

	_health.reset()
	_step = S_ATTACK_DURING_DODGE


# --- AC5: mutual exclusion, both directions ---------------------------------

func _attack_during_dodge() -> void:
	_reset_actor()
	_stamina.reset()
	var attacks_before := _combat.attacks_started
	var refused_before := _combat.attacks_refused_while_dodging
	_expect(_dodge.try_start(DODGE_DIRECTION), "dodge for the exclusion test accepted")
	# Called directly, not through input: the exclusion must be structural, so
	# there must be no route into an attack out of a dodge from code either.
	var attack := _combat.try_start(_combat.light_attack)
	print("[DODGEPROBE] --- AC5 attack during dodge ---")
	print("[DODGEPROBE] attack accepted while dodging=%s" % str(attack))
	_expect(not attack, "an attack during a committed dodge is refused")
	_expect(_combat.attacks_started == attacks_before,
		"the refused attack was not counted as started")
	_expect(_combat.attacks_refused_while_dodging == refused_before + 1,
		"the attack refusal during a dodge was counted by cause")
	_expect(_combat.state == PlayerCombat.State.IDLE,
		"the attack state machine was left untouched by the refusal")
	_step = S_WAIT_DODGE_END


# --- AC5, other direction: a dodge during an attack is refused --------------

func _dodge_during_attack() -> void:
	_reset_actor()
	_stamina.reset()
	var started_before := _dodge.dodges_started
	var refused_before := _dodge.dodges_refused_while_attacking
	_expect(_combat.try_start(_combat.light_attack), "attack for the exclusion test accepted")
	var dodge := _dodge.try_start(DODGE_DIRECTION)
	print("[DODGEPROBE] --- AC5 dodge during attack ---")
	print("[DODGEPROBE] dodge accepted while attacking=%s" % str(dodge))
	_expect(not dodge, "a dodge during a committed attack is refused")
	_expect(not _dodge.is_dodging(), "the refused dodge started nothing")
	_expect(_dodge.dodges_started == started_before,
		"the refused dodge was not counted as started")
	_expect(_dodge.dodges_refused_while_attacking == refused_before + 1,
		"the dodge refusal during an attack was counted by cause")
	_step = S_WAIT_ATTACK_END


# --- AC6: the physical input path ------------------------------------------

func _input_press() -> void:
	_reset_actor()
	_stamina.reset()
	_dodges_before_input = _dodge.dodges_started
	var event := _dodge_key_event(true)
	if event == null:
		_fail("the dodge action has no keyboard binding to inject")
		_step = S_FINISH
		return
	print("[DODGEPROBE] --- AC6 physical input path ---")
	print("[DODGEPROBE] injecting key press for action '%s' (keycode %d)" % [
		str(GameActions.DODGE), event.keycode])
	Input.parse_input_event(event)
	_wait = 0
	_step = S_INPUT_POLL


func _input_poll() -> void:
	_wait += 1
	# Release on the frame after the press, so exactly one press is delivered.
	if _wait == 1:
		var release := _dodge_key_event(false)
		if release != null:
			Input.parse_input_event(release)
	if _dodge.dodges_started > _dodges_before_input:
		_step = S_INPUT_DONE
		return
	if _wait > MAX_WAIT_FRAMES:
		_fail("the injected dodge key produced no dodge after %d frames" % MAX_WAIT_FRAMES)
		_step = S_INPUT_DONE


func _input_finish() -> void:
	var started := _dodge.dodges_started - _dodges_before_input
	print("[DODGEPROBE] injected dodge key produced %d dodge(s)" % started)
	_expect(started == 1,
		"the physical dodge binding produced exactly one dodge (got %d)" % started)
	_expect(_dodge.is_dodging() or started == 1,
		"the injected dodge actually committed the actor")
	_step = S_FINISH


## The first keyboard event bound to the dodge action, rebuilt as a fresh event so
## the probe drives the real InputMap binding rather than a hard-coded key.
func _dodge_key_event(pressed: bool) -> InputEventKey:
	if not InputMap.has_action(GameActions.DODGE):
		return null
	for bound in InputMap.action_get_events(GameActions.DODGE):
		var key: InputEventKey = bound as InputEventKey
		if key != null:
			var event := InputEventKey.new()
			event.keycode = key.keycode
			event.physical_keycode = key.physical_keycode
			event.pressed = pressed
			return event
	return null


# --- Signal handlers --------------------------------------------------------

func _on_dodge_started(_direction: Vector3) -> void:
	_started_signals += 1


func _on_dodge_finished() -> void:
	_finished_signals += 1


func _on_dodge_stamina_refused(_cost: float) -> void:
	_stamina_refusal_signals += 1


func _on_iframe_refused(_event: DamageEvent) -> void:
	_iframe_refusal_signals += 1


# --- Reporting --------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[DODGEPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[DODGEPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	Input.action_release(GameActions.MOVE_RIGHT)
	print("[DODGEPROBE] --- summary ---")
	print("[DODGEPROBE] dodges started=%d, finished signals=%d, measured travel=%.3fm" % [
		_dodge.dodges_started if _dodge != null else -1,
		_finished_signals, _measured_travel])
	if _failures.is_empty():
		print("[DODGEPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[DODGEPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
