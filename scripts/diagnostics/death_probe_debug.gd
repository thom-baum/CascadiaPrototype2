class_name DeathProbeDebug
extends Node3D
## Temporary death/reset diagnostic (not production).
##
## Why this exists: the death/reset circuit can be BUILT and still not be PROVEN.
## "The player died" and "the player came back" are both just a health number, and
## nothing about a still picture says whether input was genuinely refused while
## dead, whether an in-flight attack really ended, or whether the arena came back a
## second time. This probe drives the whole circuit deterministically and prints
## what happened:
##
##   - damage goes through HealthComponent.apply_damage(), the single place damage
##     lands, so the circuit never depends on the test attacker's cadence
##   - a LIVE swing is committed when the lethal hit lands, so "death cancels an
##     in-flight attack and closes its damage window" is measured, not assumed
##   - real input is injected while dead (movement and sprint held, dodge, parry and
##     attack pressed) and every one of them is proved to have ARRIVED before its
##     lack of effect is claimed
##   - the automatic reset is timed against the component's own authored delay
##   - a second death is ended by the RESTART input inside a window far shorter than
##     the automatic delay, so the timing itself proves which one fired
##   - health, stamina, position, control, combat usability and the test attacker
##     are read back after both resets
##
## It stands the arena's test attacker down on purpose: a probe measures ONE system
## and must never be fighting the arena at the same time. The attacker's usability
## is then measured directly, through its own API.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Physics frames allowed for the scene to settle before the sequence starts.
const SETTLE_FRAMES := 8
## Frames the dead state is held under injected input before it is graded.
const LOCK_FRAMES := 25
## Safety bound: the automatic reset must have fired within this many frames.
const AUTO_RESET_WINDOW_FRAMES := 300
## Frames allowed after a reset before the restored state is read back.
const RESET_SETTLE_FRAMES := 6
## Frames the player is given to move away from the spawn point after a reset.
const MOVE_FRAMES := 14
## Frames allowed for the post-reset attack to start and land.
const ATTACK_FRAMES := 26
## Frames waited after a restart press that must do nothing, while alive.
const LIVE_PRESS_FRAMES := 8
## Frame budget for the restart-driven reset, counted from the killing blow.
const RESTART_WINDOW_FRAMES := 40

## First, non-lethal hit. Leaves the actor alive so the living path is proved too.
const FIRST_DAMAGE := 20.0
## The kills are computed from the actor's CURRENT pool rather than a fixed number.
## Health is restored to full between rounds, so a hard-coded "lethal" hit stops
## being lethal on the second round and silently turns the rest of the run into a
## cascade of false failures.
## Damage applied after the final reset, to prove the actor is damageable again.
const AFTER_RESET_DAMAGE := 35.0
## Light attack damage from PlayerCombat.LIGHT_DAMAGE.
const LIGHT_DAMAGE := 15.0
## The stance-drain window. Damage must move it by nothing.
const STAMINA_DRIFT := 0.5

var _player: CharacterBody3D
var _health: HealthComponent
var _stamina: StaminaComponent
var _combat: PlayerCombat
var _dodge: DodgeComponent
var _parry: ParryComponent
var _death: DeathComponent
## Untyped on purpose, like the other probes here: it is reached through group /
## duck-typed access so this harness never depends on the attacker class cache.
var _attacker: Node

var _spawn := Vector3.ZERO
var _authored_delay := 0.0

var _frame := 0
var _step := 0
var _frame_in_step := 0
var _done := false
var _failures: Array = []

var _locked_position := Vector3.ZERO
var _play_attempts_before := 0
var _dodge_before := 0
var _parry_before := 0
var _stamina_spends_before := 0
var _stamina_before_death := 0.0
var _frames_since_death := 0
var _restart_frames := 0
var _move_reference := Vector3.ZERO
var _after_reset_health := 0.0
var _after_reset_started := 0
var _resets_before_live_press := 0
var _health_before_live_press := 0.0


func _ready() -> void:
	# The arena ships a live test attacker for human playtesting. A probe measures
	# one system deterministically, so any ambient hostile is stood down here.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	_resolve()
	if _player == null or _health == null:
		_finish()
		return
	_spawn = _player.global_position
	_authored_delay = _death.death_delay
	print("[DEATHPROBE] setup: health %.1f, stamina %.1f, death_delay %.2f s, spawn %s" % [
		_health.current_health, _stamina.current_stamina, _authored_delay, str(_spawn)])


func _physics_process(_delta: float) -> void:
	if _done or _player == null:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_frame_in_step += 1

	match _step:
		0: _prove_living_behaviour()
		1: _kill_while_attacking()
		2: _measure_locked_input()
		3: _settle_after_reset()
		4: _prove_movement_after_reset()
		5: _second_death_and_restart()
		6: _wait_for_restart_reset()
		7: _settle_after_reset()
		8: _prove_combat_after_reset()
		9: _restart_while_alive()
		10: _prove_attacker_usable()
		_: _finish()


# --- Steps ------------------------------------------------------------------

## The living half of the circuit. The pre-existing mechanics must be untouched,
## and the attack is deliberately LEFT RUNNING so the next step can prove that a
## death cancels a committed attack instead of leaving it swinging.
func _prove_living_behaviour() -> void:
	var health_before := _health.current_health
	var stamina_before := _stamina.current_stamina
	var started_before := _combat.attacks_started
	_health.apply_damage(_make_event(FIRST_DAMAGE))
	print("[DEATHPROBE] living damage: health %.1f -> %.1f, stamina %.1f -> %.1f, is_dead=%s" % [
		health_before, _health.current_health, stamina_before,
		_stamina.current_stamina, str(_health.is_dead)])
	_expect(_health.current_health < health_before, "a living actor still takes damage")
	_expect(not _health.is_dead, "non-lethal damage leaves the actor alive")
	_expect(_stamina.current_stamina >= stamina_before - STAMINA_DRIFT,
		"damage still does not spend stamina")

	# A real input event, through the production chain: the input layer buffers it,
	# PlayerCombat consumes it next physics frame and starts a real light attack.
	Input.action_press(GameActions.LIGHT_ATTACK)
	print("[DEATHPROBE] pressed the real light_attack action at frame %d (attack starts next frame)" % _frame)
	_expect(Input.is_action_pressed(GameActions.LIGHT_ATTACK),
		"the injected light_attack action arrived at the input system")
	_step_to(1)


## The lethal hit lands mid-swing. Death must process once and must take the
## committed attack down with it.
func _kill_while_attacking() -> void:
	var health_before := _health.current_health
	print("[DEATHPROBE] before the killing blow: combat state=%s, busy=%s, hitbox open=%s, attacks started=%d" % [
		_combat.state_name(), str(_combat.is_busy()), str(_combat.hitbox_is_open()),
		_combat.attacks_started])
	_expect(_combat.is_busy(), "the light attack from the previous frame is committed when death lands")
	_expect(_combat.attacks_started >= 1, "a living actor still starts attacks from real input")

	_health.apply_damage(_lethal_event())
	print("[DEATHPROBE] lethal hit: health %.1f -> %.1f, deaths=%d, is_dead=%s, combat state=%s, hitbox open=%s" % [
		health_before, _health.current_health, _death.deaths, str(_death.is_dead()),
		_combat.state_name(), str(_combat.hitbox_is_open())])

	_expect(_health.current_health <= 0.0, "health reaches zero")
	_expect(_health.is_dead, "the health component reports dead")
	_expect(_death.deaths == 1, "the death was processed exactly once (got %d)" % _death.deaths)
	_expect(_death.is_dead(), "the death state is active")
	_expect(_death.time_until_reset() > 0.0, "the reset delay is armed")
	_expect(not _combat.is_busy(), "death cancelled the committed attack")
	_expect(not _combat.hitbox_is_open(), "the interrupted attack left no open damage window")

	var presentation := _presentation()
	if presentation == null:
		_expect(false, "a death presentation exists in the scene")
	else:
		var text := String(presentation.call("status_text"))
		print("[DEATHPROBE] presentation text while dead: %s" % text)
		_expect(bool(presentation.call("is_showing")), "the death presentation is showing")
		_expect(not text.is_empty() and text.to_upper().contains("DIED"),
			"the presentation names the death on screen")

	_locked_position = _player.global_position
	_play_attempts_before = _combat.attacks_started
	_dodge_before = _dodge.dodges_started
	_parry_before = _parry.parries_started
	_stamina_spends_before = _stamina.spent_count
	_stamina_before_death = _stamina.current_stamina
	_frames_since_death = 0

	Input.action_release(GameActions.LIGHT_ATTACK)
	_lock_inputs()
	_step_to(2)


## Hold the dead state open under injected input, then grade what the input did.
## Every injected action is proved to have arrived before its lack of effect is
## claimed, so "nothing happened" cannot be a key that was never pressed.
func _measure_locked_input() -> void:
	if _death.is_dead():
		_frames_since_death += 1
		if _frame_in_step == LOCK_FRAMES:
			_grade_locked_input()
		if _frame_in_step > AUTO_RESET_WINDOW_FRAMES:
			_fail("the death never reset itself within %d frames" % AUTO_RESET_WINDOW_FRAMES)
			_release_inputs()
			_finish()
		return

	var ticks := float(Engine.physics_ticks_per_second)
	var observed := float(_frames_since_death) / ticks
	print("[DEATHPROBE] automatic reset: %d frames = %.3f s (authored death_delay %.3f s)" % [
		_frames_since_death, observed, _authored_delay])
	_expect(absf(observed - _authored_delay) <= 3.0 / ticks,
		"the automatic reset fired on the authored delay (%.3f s vs %.3f s)" % [observed, _authored_delay])
	_expect(not _death.is_dead(), "the automatic reset cleared the dead state")
	_release_inputs()
	_step_to(3)


func _settle_after_reset() -> void:
	if _frame_in_step < RESET_SETTLE_FRAMES:
		return
	_grade_restored_arena("the automatic reset" if _step == 3 else "the restart input")
	_step_to(_step + 1)


## Control must genuinely come back, not merely be reported as restored: the body
## has to accept movement input again.
func _prove_movement_after_reset() -> void:
	if _frame_in_step == 1:
		_move_reference = _player.global_position
		Input.action_press(GameActions.MOVE_FORWARD)
		_expect(Input.is_action_pressed(GameActions.MOVE_FORWARD),
			"the movement input for the control check arrived at the input system")
		return
	if _frame_in_step < MOVE_FRAMES:
		return
	var moved := _player.global_position.distance_to(_move_reference)
	Input.action_release(GameActions.MOVE_FORWARD)
	print("[DEATHPROBE] control restored: the player moved %.2f m in %d frames with forward held" % [
		moved, MOVE_FRAMES])
	_expect(moved > 0.05, "the player accepts movement input again after the reset")
	_step_to(5)


## Second death, this time ended by the RESTART input rather than the delay.
func _second_death_and_restart() -> void:
	_release_inputs()
	_expect(_health.current_health >= _health.max_health - 0.001,
		"health was restored to maximum before the second death (%.1f)" % _health.current_health)
	Input.action_press(GameActions.LIGHT_ATTACK)
	_health.apply_damage(_lethal_event())
	Input.action_release(GameActions.LIGHT_ATTACK)
	print("[DEATHPROBE] second death: health %.1f, deaths=%d, dead=%s" % [
		_health.current_health, _death.deaths, str(_death.is_dead())])
	_expect(_death.deaths == 2, "the second death was processed exactly once too (got %d)" % _death.deaths)
	_expect(_death.is_dead(), "the player is dead again")
	_frames_since_death = 0
	_restart_frames = 0
	var expected := int(round(_authored_delay * float(Engine.physics_ticks_per_second)))
	print("[DEATHPROBE] pressing the real restart action; the automatic reset is about %d frames away" % expected)
	Input.action_press(GameActions.RESTART)
	_expect(Input.is_action_pressed(GameActions.RESTART),
		"the injected restart action arrived at the input system")
	_step_to(6)


func _wait_for_restart_reset() -> void:
	if _death.is_dead():
		_restart_frames += 1
		if _restart_frames > RESTART_WINDOW_FRAMES:
			_fail("the restart input did not reset the player within %d frames" % RESTART_WINDOW_FRAMES)
			_release_inputs()
			_finish()
		return
	var seconds := float(_restart_frames) / float(Engine.physics_ticks_per_second)
	print("[DEATHPROBE] restart reset: %d frames = %.3f s after death (automatic delay is %.3f s)" % [
		_restart_frames, seconds, _authored_delay])
	_expect(seconds < _authored_delay,
		"the reset came from the restart input, not from the automatic delay")
	_expect(_death.resets_by_input == 1,
		"exactly one reset was recorded as input-driven (got %d)" % _death.resets_by_input)
	_expect(_death.resets == 2, "both resets were counted (got %d)" % _death.resets)
	Input.action_release(GameActions.RESTART)
	_release_inputs()
	_step_to(7)


## The arena must be genuinely usable again after the second reset, and a death
## must not process again without new damage.
func _prove_combat_after_reset() -> void:
	if _frame_in_step == 1:
		_after_reset_health = _health.current_health
		_after_reset_started = _combat.attacks_started
		var deaths := _death.deaths
		# Clamped to stay non-lethal on purpose: this step measures damage applying
		# after a reset, so it must not itself trigger another death.
		_health.apply_damage(_make_event(minf(AFTER_RESET_DAMAGE, _health.current_health * 0.5)))
		print("[DEATHPROBE] post-reset damage: health %.1f -> %.1f, deaths=%d (was %d)" % [
			_after_reset_health, _health.current_health, _death.deaths, deaths])
		_expect(_death.deaths == deaths, "damage after a reset does not process a death")
		Input.action_press(GameActions.LIGHT_ATTACK)
		_expect(Input.is_action_pressed(GameActions.LIGHT_ATTACK),
			"the post-reset attack input arrived at the input system")
		return
	if _frame_in_step < ATTACK_FRAMES:
		return
	var dealt := _after_reset_health - _health.current_health
	var started := _combat.attacks_started - _after_reset_started
	Input.action_release(GameActions.LIGHT_ATTACK)
	print("[DEATHPROBE] post-reset combat: attacks started=%d, health %.1f -> %.1f (dealt %.1f)" % [
		started, _after_reset_health, _health.current_health, dealt])
	_expect(started == 1, "the player can attack again after the reset (started %d)" % started)
	_expect(_health.current_health < _after_reset_health, "the player can be damaged again after the reset")
	_expect(_health.current_health >= _after_reset_health - AFTER_RESET_DAMAGE - LIGHT_DAMAGE - 0.001,
		"post-reset damage applied at most once (dealt %.1f)" % dealt)
	_step_to(9)


## A restart press while alive must do nothing at all: no reset, no state change.
func _restart_while_alive() -> void:
	if _frame_in_step == 1:
		_resets_before_live_press = _death.resets
		_health_before_live_press = _health.current_health
		Input.action_press(GameActions.RESTART)
		return
	if _frame_in_step < LIVE_PRESS_FRAMES:
		return
	Input.action_release(GameActions.RESTART)
	print("[DEATHPROBE] restart while alive: resets %d -> %d, health %.1f -> %.1f, dead=%s" % [
		_resets_before_live_press, _death.resets, _health_before_live_press,
		_health.current_health, str(_death.is_dead())])
	_expect(_death.resets == _resets_before_live_press, "the restart input does nothing while alive")
	_expect(is_equal_approx(_health.current_health, _health_before_live_press),
		"a restart while alive leaves health untouched")
	_expect(not _death.is_dead(), "the player is still alive")
	_step_to(10)


## The deterministic test attacker is part of the arena, so it must come back
## usable. Measured through its own API rather than by waiting for a swing.
func _prove_attacker_usable() -> void:
	if _attacker == null:
		_expect(false, "the test attacker was found in the arena")
		_finish()
		return
	if _frame_in_step == 1:
		# Step into the attacker's reach so its own range check can pass. The
		# attacker is left stood down, so the arena is not hostile to a probe.
		var body := _attacker.get_parent() as Node3D
		if body != null:
			_player.global_position = body.global_position + Vector3(0.0, 0.1, 1.5)
			_player.velocity = Vector3.ZERO
		return
	if _frame_in_step < 4:
		return
	var in_range := bool(_attacker.call("is_target_in_range"))
	var attacking_before := bool(_attacker.call("is_attacking"))
	print("[DEATHPROBE] test attacker: in range=%s, attacking=%s, auto_attack=%s" % [
		str(in_range), str(attacking_before), str(_attacker.get("auto_attack"))])
	_expect(not attacking_before, "the test attacker is idle after the resets")
	_expect(in_range, "the test attacker still resolves the player as a target")
	_expect(bool(_attacker.call("try_start")), "the test attacker can still start its attack")
	_attacker.call("reset")
	_expect(not bool(_attacker.call("is_attacking")), "the test attacker returns to its initial state")
	_finish()


# --- Injected input ---------------------------------------------------------

## Hold and press everything a living player would use. Movement and sprint are
## HELD so the body has every chance to drift; dodge, parry, restart and attack are
## pressed so the committed-action gate and the attack gate both get a try.
func _lock_inputs() -> void:
	Input.action_press(GameActions.MOVE_FORWARD)
	Input.action_press(GameActions.SPRINT)
	Input.action_press(GameActions.DODGE)
	Input.action_press(GameActions.PARRY)
	Input.action_press(GameActions.LIGHT_ATTACK)
	# Each one must have genuinely arrived, or the measurement below would be
	# measuring a key that was never pressed.
	var arrived := true
	for action in [GameActions.MOVE_FORWARD, GameActions.SPRINT, GameActions.DODGE,
			GameActions.PARRY, GameActions.LIGHT_ATTACK]:
		if not (InputMap.has_action(action) and Input.is_action_pressed(action)):
			arrived = false
			_fail("injected action '%s' did not arrive at the input system" % String(action))
	if arrived:
		print("[DEATHPROBE] all five actions injected while dead arrived at the input system")
	_expect(arrived, "every input injected while dead reached the input system")
	Input.action_release(GameActions.DODGE)
	Input.action_release(GameActions.PARRY)


func _release_inputs() -> void:
	for action in [GameActions.MOVE_FORWARD, GameActions.SPRINT, GameActions.DODGE,
			GameActions.PARRY, GameActions.LIGHT_ATTACK, GameActions.RESTART]:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			Input.action_release(action)


# --- Grading ----------------------------------------------------------------

func _grade_locked_input() -> void:
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	var locked := Vector2(_locked_position.x, _locked_position.z)
	var drift := here.distance_to(locked)
	print("[DEATHPROBE] while dead: drift %.3f m | attacks +%d, dodges +%d, parries +%d, stamina spends +%d | stamina %.1f/%.1f" % [
		drift, _combat.attacks_started - _play_attempts_before,
		_dodge.dodges_started - _dodge_before, _parry.parries_started - _parry_before,
		_stamina.spent_count - _stamina_spends_before,
		_stamina.current_stamina, _stamina.max_stamina])
	_expect(Input.is_action_pressed(GameActions.MOVE_FORWARD),
		"the movement input is still held while the dead state is measured")
	_expect(drift < 0.05, "held movement input does not move a dead player (drift %.3f m)" % drift)
	_expect(_combat.attacks_started == _play_attempts_before,
		"attack input cannot start an attack while dead")
	_expect(_dodge.dodges_started == _dodge_before, "dodge input cannot start a dodge while dead")
	_expect(_parry.parries_started == _parry_before, "parry input cannot start a parry while dead")
	_expect(_stamina.spent_count == _stamina_spends_before, "no stamina is spent while dead")
	_expect(_stamina.current_stamina >= _stamina_before_death - 0.001,
		"stamina does not drain while dead (%.1f -> %.1f)" % [
			_stamina_before_death, _stamina.current_stamina])


func _grade_restored_arena(label: String) -> void:
	print("[DEATHPROBE] --- arena state %s ---" % label)
	_expect(not _death.is_dead(), "%s: the dead state is cleared" % label)
	_expect(_death.time_until_reset() <= 0.0, "%s: the reset timer is cleared" % label)
	_expect(_health.current_health >= _health.max_health - 0.001,
		"%s: health restored to %.1f/%.1f" % [label, _health.current_health, _health.max_health])
	_expect(_stamina.current_stamina >= _stamina.max_stamina - 0.001,
		"%s: stamina restored to %.1f/%.1f" % [label, _stamina.current_stamina, _stamina.max_stamina])
	_expect(_stamina.regen_enabled, "%s: stamina regeneration is re-enabled" % label)
	# Horizontal distance is the real claim: the body is put back on the spawn mark
	# and then settles the last centimetres onto the floor under gravity, so an
	# exact 3D comparison would measure the settle rather than the reset.
	var offset := _player.global_position - _spawn
	var away := Vector2(offset.x, offset.z).length()
	_expect(away < 0.05, "%s: the player is back at the spawn point (%.2f m away horizontally)" % [label, away])
	_expect(absf(offset.y) < 0.3, "%s: the player is back at the spawn height (%.2f m off)" % [label, offset.y])
	var rest := Vector2(_player.velocity.x, _player.velocity.z).length()
	_expect(rest < 0.05,
		"%s: the player's horizontal velocity is cleared (%.3f)" % [label, rest])
	_expect(not _combat.is_busy(), "%s: no attack state remains" % label)
	_expect(not _combat.hitbox_is_open(), "%s: no damage window remains" % label)
	_expect(not _dodge.is_dodging(), "%s: no dodge state remains" % label)
	_expect(not _parry.is_parrying(), "%s: no parry state remains" % label)
	var presentation := _presentation()
	if presentation == null:
		_expect(false, "%s: a death presentation exists in the scene" % label)
	else:
		_expect(not bool(presentation.call("is_showing")),
			"%s: the death presentation is cleared" % label)


# --- Helpers ----------------------------------------------------------------

## The same path every point of damage in Cascadia takes. Injected directly rather
## than waited for, so the circuit is provable without depending on the test
## attacker's cadence.
## A hit that is lethal from the actor's CURRENT health. Never a constant: the
## pool is restored between rounds, so a fixed number would stop killing anything.
func _lethal_event() -> DamageEvent:
	return _make_event(_health.current_health + 1.0)


func _make_event(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	event.victim = _player
	event.position = _player.global_position
	return event


func _presentation() -> Node:
	return get_tree().get_first_node_in_group(&"death_presentation")


func _resolve() -> void:
	var main := get_node_or_null("../Main")
	if main == null:
		main = get_node_or_null("Main")
	if main == null:
		_fail("main scene not found")
		return
	var base := "TestEnvironment/"
	_player = main.get_node_or_null(base + "Player") as CharacterBody3D
	if _player == null:
		_fail("player not found")
		return
	_health = _player.get_node_or_null("Health") as HealthComponent
	_stamina = _player.get_node_or_null("Stamina") as StaminaComponent
	_combat = _player.get_node_or_null("Combat") as PlayerCombat
	_dodge = _player.get_node_or_null("Dodge") as DodgeComponent
	_parry = _player.get_node_or_null("Parry") as ParryComponent
	_death = _player.get_node_or_null("Death") as DeathComponent

	_expect(_health != null, "player Health found")
	_expect(_stamina != null, "player Stamina found")
	_expect(_combat != null, "player Combat state machine found")
	_expect(_dodge != null, "player Dodge found")
	_expect(_parry != null, "player Parry found")
	_expect(_death != null, "player Death circuit found")
	_resolve_attacker(main, base)


## Resolved by path first and by group as a fallback, so a reshuffled arena still
## finds it. Deliberately untyped: the group is the same one the other probes use.
func _resolve_attacker(main: Node, base: String) -> void:
	var node := main.get_node_or_null(base + "TestAttacker")
	if node == null:
		node = main.get_node_or_null(base + "TestAttacker/Attacker")
	if node != null and not node.has_method("try_start"):
		node = node.get_node_or_null("Attacker")
	if node == null:
		var found := get_tree().get_first_node_in_group(&"enemy_attacker")
		node = found
	_attacker = node
	_expect(_attacker != null, "test attacker found in the arena")


func _step_to(next: int) -> void:
	_step = next
	_frame_in_step = 0


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[DEATHPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[DEATHPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	_release_inputs()
	print("[DEATHPROBE] --- summary ---")
	print("[DEATHPROBE] deaths=%d, resets=%d (input-driven %d)" % [
		_death.deaths, _death.resets, _death.resets_by_input])
	if _failures.is_empty():
		print("[DEATHPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[DEATHPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
