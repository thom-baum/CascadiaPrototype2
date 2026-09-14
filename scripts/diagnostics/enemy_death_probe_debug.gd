class_name EnemyDeathProbeDebug
extends Node3D
## Temporary enemy-death diagnostic (not production).
##
## The enemy counterpart of death_probe_debug, and it exists for the one claim a
## static read cannot make: that a DEFEATED enemy stays defeated when the player
## dies and the single-arena reset runs.
##
## Deterministic by construction. The killing blow goes through
## HealthComponent.apply_damage - the single place all damage lands - so the run
## never depends on combat timing or on the enemy's cadence, and the enemy's attack
## is committed BEFORE that blow, so "the committed attack was cancelled and its
## damage window closed" is measured rather than assumed.
##
## It stands the arena's test attacker down on purpose (it is the attacker under
## test here) and drives it by hand, so nothing in the run depends on cadence.
##
## The last step leaves the player standing in front of the defeated enemy. Every
## check has already been graded by then, so that step only chooses what the final
## frame shows, which is what makes the presentation inspectable by eye.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Physics frames allowed for the scene to settle before the sequence starts.
const SETTLE_FRAMES := 8
## Frames the player stands inside the enemy's reach after the defeat.
const IN_RANGE_FRAMES := 30
## Frames the player is given to settle after its own reset.
const RESET_SETTLE_FRAMES := 6
## Safety bound: the player's automatic reset must fire within this many frames.
const AUTO_RESET_WINDOW_FRAMES := 300
## How far in front of the enemy the player is placed. Inside engage_range (2.8).
const STAND_OFFSET := 1.9
## First hit on the enemy. Must NOT be lethal: the living path is proved with it.
const WOUND_DAMAGE := 40.0
## Damage dealt AFTER the enemy is defeated. Must change nothing at all.
const AFTER_DEATH_DAMAGE := 35.0

var _player: CharacterBody3D
var _player_health: HealthComponent
var _player_death: DeathComponent
var _enemy: Node3D
var _enemy_health: HealthComponent
## Untyped on purpose, like the other probes here: reached through duck-typed access
## so this harness never depends on the attacker's class cache.
var _attacker: Node
var _enemy_death: Node
var _presentation: Node

var _frame := 0
var _step := 0
var _frame_in_step := 0
var _done := false
var _failures: Array = []

var _enemy_applied_before := 0
var _player_health_before := 0.0
var _player_resets_before := 0
var _player_delay := 0.0
var _player_death_frames := 0
var _enemy_starts_at_defeat := 0


func _ready() -> void:
	# The arena ships a live test attacker for human playtesting, and it is the actor
	# under test here. A probe measures deterministically, so it is stood down and
	# then driven by hand rather than left to its own cadence.
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false
	_resolve()
	if _player == null or _enemy == null or _enemy_health == null:
		_finish()
		return
	if _attacker == null or _enemy_death == null:
		_finish()
		return
	print("[ENEMYDEATHPROBE] setup: enemy health %.1f, defeated=%s, player health %.1f, death_delay %.2f s" % [
		_enemy_health.current_health, str(_is_defeated()), _player_health.current_health,
		_player_death.death_delay if _player_death != null else -1.0])


func _physics_process(_delta: float) -> void:
	if _done or _enemy == null:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_frame_in_step += 1

	match _step:
		0: _step_living_enemy()
		1: _step_kill_mid_attack()
		2: _step_hold_in_range()
		3: _step_defeat_player()
		4: _step_wait_for_player_reset()
		5: _step_after_player_reset()
		6: _step_observation_hold()
		_: _finish()


# --- Steps ------------------------------------------------------------------

## The enemy must be a genuinely live enemy first, or "it stopped acting" would prove
## nothing. Its attack is committed here and left committed for the next step, so the
## kill lands mid-attack.
func _step_living_enemy() -> void:
	_expect(not _is_defeated(), "the enemy starts alive (not defeated)")
	_expect(not _enemy_health.is_dead, "the enemy's health component starts alive")
	_expect(is_equal_approx(_enemy_health.current_health, _enemy_health.max_health),
		"the enemy starts at full health (%.1f)" % _enemy_health.current_health)
	_expect(_defeats() == 0, "no defeat has been processed yet (got %d)" % _defeats())

	_position_player_in_reach()
	var distance := _attacker_distance()
	print("[ENEMYDEATHPROBE] player placed %.2f m from the enemy (engage_range %.2f)" % [
		distance, _attacker_engage_range()])
	_expect(distance <= _attacker_engage_range(),
		"the player is inside the enemy's engage range (%.2f m)" % distance)
	_expect(_attacker_in_range(), "the enemy considers the player to be in range")

	# A first, NON-lethal hit: the living half of the damage path must still work, so
	# "damage is refused" later cannot be confused with damage that never worked.
	_enemy_applied_before = _enemy_health.applied_count
	var health_before := _enemy_health.current_health
	_enemy_health.apply_damage(_make_event(WOUND_DAMAGE, _enemy))
	print("[ENEMYDEATHPROBE] wounding hit on the living enemy: %.1f -> %.1f (applied_count %d -> %d)" % [
		health_before, _enemy_health.current_health, _enemy_applied_before,
		_enemy_health.applied_count])
	_expect(is_equal_approx(_enemy_health.current_health, health_before - WOUND_DAMAGE),
		"a living enemy takes damage through the normal chain")
	_expect(not _enemy_health.is_dead, "the wounding hit did not kill the enemy")
	_expect(not _is_defeated(), "a wounded enemy is not defeated")

	_expect(not _presentation_showing(), "the defeat presentation is hidden while the enemy lives")

	_expect(_attacker_try_start(), "a live enemy can commit an attack")
	_expect(_attacker_attacking(), "the enemy attack is committed")
	_step_to(1)


## The killing blow lands mid-attack. Defeat must process once and must take the
## committed attack down with it.
func _step_kill_mid_attack() -> void:
	_expect(_attacker_attacking(), "the enemy is still committed when the killing blow lands")
	print("[ENEMYDEATHPROBE] before the killing blow: health %.1f, phase=%s, hitbox open=%s" % [
		_enemy_health.current_health, _attacker_phase(), str(_attacker_hitbox_open())])

	var applied_before_lethal := _enemy_health.applied_count
	var starts_before := _attacker_starts()
	var refused_before := _attacker_refused_defeated()
	var health_before := _enemy_health.current_health

	_enemy_health.apply_damage(_make_event(health_before + 1.0, _enemy))
	print("[ENEMYDEATHPROBE] lethal hit: %.1f -> %.1f, deaths=%d, defeated=%s, phase=%s, hitbox open=%s, telegraph=%s" % [
		health_before, _enemy_health.current_health, _defeats(), str(_is_defeated()),
		_attacker_phase(), str(_attacker_hitbox_open()), str(_telegraph_visible())])

	_expect(_enemy_health.current_health <= 0.0, "the enemy's health reaches zero")
	_expect(_enemy_health.is_dead, "the enemy's health component reports dead")
	_expect(_defeats() == 1, "the defeat was processed exactly once (got %d)" % _defeats())
	_expect(_is_defeated(), "the enemy is in the defeated state")
	_expect(_enemy_health.applied_count == applied_before_lethal + 1,
		"the lethal hit was applied exactly once")

	# The committed attack died with the enemy.
	_expect(not _attacker_attacking(), "the defeat cancelled the committed attack")
	_expect(not _attacker_hitbox_open(), "the cancelled attack left no open damage window")
	_expect(not _telegraph_visible(), "the cancelled attack switched its telegraph off")

	# Further damage must change nothing at all: refused by the health component, and
	# no second defeat processed.
	var applied_after_lethal := _enemy_health.applied_count
	_enemy_health.apply_damage(_make_event(AFTER_DEATH_DAMAGE, _enemy))
	print("[ENEMYDEATHPROBE] damage after the defeat: health %.1f, applied_count %d -> %d, deaths=%d" % [
		_enemy_health.current_health, applied_after_lethal,
		_enemy_health.applied_count, _defeats()])
	_expect(is_equal_approx(_enemy_health.current_health, 0.0),
		"further damage is refused (health stays 0)")
	_expect(_enemy_health.applied_count == applied_after_lethal,
		"further damage is not applied at all (applied_count unchanged)")
	_expect(_defeats() == 1, "no second defeat was processed (got %d)" % _defeats())

	# A defeated enemy refuses every start, and the refusal is recorded by CAUSE.
	_expect(_attacker_starts() == starts_before, "no new attack started after the defeat")
	_expect(not _attacker_try_start(), "a defeated enemy cannot start an attack")
	_expect(_attacker_refused_defeated() == refused_before + 1,
		"the refused start was counted as a DEFEAT refusal (%d -> %d)" % [
			refused_before, _attacker_refused_defeated()])

	_expect(_presentation != null, "a defeat presentation exists in the scene")
	if _presentation != null:
		var text := String(_presentation.call("status_text"))
		print("[ENEMYDEATHPROBE] presentation text while defeated: %s" % text)
		_expect(_presentation_showing(), "the defeat presentation is showing")
		_expect(not text.is_empty() and text.to_upper().contains("DEFEAT"),
			"the presentation names the defeat on screen")

	_player_health_before = _player_health.current_health
	_enemy_starts_at_defeat = _attacker_starts()
	_step_to(2)


## The player stands inside a defeated enemy's reach. Nothing may reach it: the only
## thing that could was the attack, and that path is closed.
func _step_hold_in_range() -> void:
	if _frame_in_step < IN_RANGE_FRAMES:
		if _attacker_hitbox_open():
			_fail("a defeated enemy opened a damage window while the player stood in reach")
		return
	var dealt := _player_health_before - _player_health.current_health
	print("[ENEMYDEATHPROBE] %d frames with the player %.2f m from the defeated enemy: player health %.1f -> %.1f (dealt %.1f)" % [
		IN_RANGE_FRAMES, _attacker_distance(), _player_health_before,
		_player_health.current_health, dealt])
	_expect(is_equal_approx(dealt, 0.0), "a defeated enemy cannot damage the player")
	_expect(not _player_health.is_dead, "the player is alive after standing in reach")
	_expect(_attacker_starts() == _enemy_starts_at_defeat,
		"a defeated enemy started no attack while the player stood in reach")
	_step_to(3)


## Now kill the PLAYER, so the reset that follows is the real circuit doing its job.
## The defeated enemy must survive it.
func _step_defeat_player() -> void:
	_expect(_player_death != null, "the player's death circuit is present")
	if _player_death == null:
		_finish()
		return
	_expect(not _player_health.is_dead, "the player is alive before the reset test")
	_player_resets_before = _player_death.resets
	_player_delay = _player_death.death_delay
	var health_before := _player_health.current_health
	_player_health.apply_damage(_make_event(health_before + 1.0, _player))
	print("[ENEMYDEATHPROBE] player killed for the reset test: %.1f -> %.1f, dead=%s, death resets=%d" % [
		health_before, _player_health.current_health, str(_player_health.is_dead),
		_player_death.resets])
	_expect(_player_health.is_dead, "the player died")
	_expect(_player_death.is_dead(), "the player's death circuit is active")
	_expect(_is_defeated(), "the enemy is still defeated while the player dies")
	_player_death_frames = 0
	_step_to(4)


## Wait for the player's own automatic reset, then read the enemy back. Proving the
## player came back is what makes "the enemy did not" mean something.
func _step_wait_for_player_reset() -> void:
	if _player_death.is_dead():
		_player_death_frames += 1
		if _player_death_frames > AUTO_RESET_WINDOW_FRAMES:
			_fail("the player's automatic reset never fired within %d frames" % AUTO_RESET_WINDOW_FRAMES)
			_finish()
		return
	var ticks := float(Engine.physics_ticks_per_second)
	var observed := float(_player_death_frames) / ticks
	print("[ENEMYDEATHPROBE] player automatic reset: %d frames = %.3f s (authored %.3f s)" % [
		_player_death_frames, observed, _player_delay])
	_expect(absf(observed - _player_delay) <= 3.0 / ticks,
		"the player's automatic reset fired on the authored delay (%.3f s vs %.3f s)" % [
			observed, _player_delay])
	_expect(_player_death.resets == _player_resets_before + 1,
		"the player's reset ran (resets %d -> %d)" % [_player_resets_before, _player_death.resets])
	_expect(_player_health.current_health >= _player_health.max_health - 0.001,
		"the player is playable again (health %.1f)" % _player_health.current_health)
	_step_to(5)


## The claim this whole pass exists for: the reset that restored the player did NOT
## restore the enemy.
func _step_after_player_reset() -> void:
	if _frame_in_step < RESET_SETTLE_FRAMES:
		return
	print("[ENEMYDEATHPROBE] after the player's reset: enemy health %.1f, is_dead=%s, defeated=%s, phase=%s, deaths=%d" % [
		_enemy_health.current_health, str(_enemy_health.is_dead), str(_is_defeated()),
		_attacker_phase(), _defeats()])
	_expect(is_equal_approx(_enemy_health.current_health, 0.0),
		"the player's reset did not restore the enemy's health (%.1f)" % _enemy_health.current_health)
	_expect(_enemy_health.is_dead, "the enemy is still dead after the player's reset")
	_expect(_is_defeated(), "the enemy is still defeated after the player's reset")
	_expect(_defeats() == 1, "the player's reset did not process another defeat (got %d)" % _defeats())
	_expect(not _attacker_attacking(), "the defeated enemy is still not attacking")
	_expect(not _attacker_hitbox_open(), "the defeated enemy still has no open damage window")
	_expect(_attacker_starts() == _enemy_starts_at_defeat,
		"the defeated enemy still has not started an attack")
	var refused_before := _attacker_refused_defeated()
	_expect(not _attacker_try_start(), "a defeated enemy still refuses to start an attack")
	_expect(_attacker_refused_defeated() == refused_before + 1,
		"the post-reset refusal is still recorded as a DEFEAT refusal, not a distance one (%d -> %d)" % [
			refused_before, _attacker_refused_defeated()])
	_expect(_presentation_showing(), "the defeated enemy still reads as defeated on screen")
	_step_to(6)


## Frame the defeated enemy for inspection by eye. Every check above has already been
## graded, so this only chooses what the final frame shows.
func _step_observation_hold() -> void:
	_position_player_in_reach()
	print("[ENEMYDEATHPROBE] observation hold: player placed in front of the defeated enemy")
	_step_to(7)


# --- Helpers ----------------------------------------------------------------

func _position_player_in_reach() -> void:
	_player.global_position = Vector3(
		_enemy.global_position.x, 0.1, _enemy.global_position.z + STAND_OFFSET)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO


## The same path every point of damage in Cascadia takes. Injected directly rather
## than waited for, so the circuit is provable without depending on the test
## attacker's cadence.
func _make_event(amount: float, victim: Node3D) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	event.victim = victim
	event.position = victim.global_position
	return event


# --- Enemy state (duck-typed) ----------------------------------------------

func _is_defeated() -> bool:
	if _enemy_death == null:
		return false
	return bool(_enemy_death.call("is_defeated"))


func _defeats() -> int:
	if _enemy_death == null:
		return 0
	return int(_enemy_death.get("defeats"))


func _presentation_showing() -> bool:
	if _presentation == null:
		return false
	return bool(_presentation.call("is_showing"))


# --- Attacker state (duck-typed) -------------------------------------------

func _attacker_attacking() -> bool:
	return bool(_attacker.call("is_attacking"))


func _attacker_hitbox_open() -> bool:
	return bool(_attacker.call("hitbox_is_open"))


func _attacker_try_start() -> bool:
	return bool(_attacker.call("try_start"))


func _attacker_phase() -> String:
	return String(_attacker.call("phase_name"))


func _attacker_distance() -> float:
	return float(_attacker.call("distance_to_target"))


func _attacker_in_range() -> bool:
	return bool(_attacker.call("is_target_in_range"))


func _attacker_engage_range() -> float:
	return float(_attacker.get("engage_range"))


func _attacker_starts() -> int:
	return int(_attacker.get("attacks_started"))


func _attacker_refused_defeated() -> int:
	return int(_attacker.get("attacks_refused_while_defeated"))


func _telegraph_visible() -> bool:
	var telegraph := _enemy.get_node_or_null("Telegraph") as Node3D
	return telegraph != null and telegraph.visible


# --- Resolution -------------------------------------------------------------

func _resolve() -> void:
	var main := get_node_or_null("../Main")
	if main == null:
		main = get_node_or_null("Main")
	if main == null:
		_fail("main scene not found")
		return
	var base := "TestEnvironment/"
	_player = main.get_node_or_null(base + "Player") as CharacterBody3D
	_enemy = main.get_node_or_null(base + "TestAttacker") as Node3D
	if _player == null:
		_fail("player not found")
	if _enemy == null:
		_fail("test attacker not found")
	if _player == null or _enemy == null:
		return

	_player_health = _player.get_node_or_null("Health") as HealthComponent
	_player_death = _player.get_node_or_null("Death") as DeathComponent
	_enemy_health = _enemy.get_node_or_null("Health") as HealthComponent
	_attacker = _enemy.get_node_or_null("Attacker")
	_enemy_death = _enemy.get_node_or_null("Death")
	_presentation = _enemy.get_node_or_null("DeathPresentation")

	_expect(_player_health != null, "player Health found")
	_expect(_player_death != null, "player Death circuit found")
	_expect(_enemy_health != null, "enemy Health found")
	_expect(_attacker != null, "enemy Attacker found")
	_expect(_enemy_death != null, "enemy Death state found")
	_expect(_presentation != null, "enemy defeat presentation found")


func _step_to(next: int) -> void:
	_step = next
	_frame_in_step = 0


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[ENEMYDEATHPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ENEMYDEATHPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	print("[ENEMYDEATHPROBE] --- summary ---")
	if _failures.is_empty():
		print("[ENEMYDEATHPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[ENEMYDEATHPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
