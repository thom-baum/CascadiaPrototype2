class_name PlayerAttackReachProbeDebug
extends Node3D
## Temporary diagnostic (Milestone 18 follow-up - attack REACH vs enemy stand-off). Not production.
##
## WHY THIS EXISTS. `live_combat_credit_probe_debug` proves hitstop, interruption and the death
## credit reset all work through the player's REAL attack path, but it places the player at a FIXED
## 1.8 m from its target (its own `STAND_DISTANCE`). That distance is a probe convenience, not a
## distance any enemy actually fights at: each archetype's own Locomotion walks to its
## `stopping_distance()` and swings from there. A probe that fights from 1.8 m therefore cannot see
## a mismatch between the player's weapon and the stand-off the enemy chooses for itself - which is
## exactly the live-play report "my attacks do not interrupt".
##
## WHAT IT MEASURES, all read from the live scene rather than restated here:
##
##   1. The player's attack hitbox FORWARD EXTENT, composed from the box's own half-depth and its
##      live world offset, projected onto the player's facing. A re-tune of either is picked up.
##   2. Each archetype's REAL stand-off, read from its own `EnemyLocomotion.stopping_distance()`.
##   3. Whether a real player LIGHT attack - driven through `PlayerCombat.try_start()` and its own
##      STARTUP -> ACTIVE advance, never a direct `activate()` - actually DAMAGES that enemy while
##      the player stands exactly where that enemy's own AI stands off.
##   4. Whether the light hit INTERRUPTS the lighter archetype (its threshold is below the light
##      damage) and leaves the heavier one swinging (its threshold is above it - the heavy-only
##      contract the user confirmed).
##
## THE ISOLATION, and it is the ONLY one: the enemy under measurement has its Locomotion switched
## off, so the reading is about REACH and not about who drifted during the attack's startup. Without
## it the 2.60 m/s archetype walks 0.5 m during a 0.2 s startup and the probe would be reporting its
## walk rather than the player's weapon. Auto-attack is switched off with the project's own
## `stand_down_all()` so the other archetype cannot interfere; the swing under measurement is
## committed explicitly with `try_start()`, the same way the existing live probe arms its target.
##
## Prints console only; writes no report file.

## Frames allowed for a real attack to travel from try_start() to the moment damage lands.
const ATTACK_FRAME_BUDGET := 90
## Frames allowed for an armed enemy swing to actually commit. Sized to ALSO cover the wait for the
## player's own attack to finish recovering: the enemy swing cannot be meaningfully armed while the
## previous swing is still committed, so that wait must fit inside this budget.
const ARM_FRAME_BUDGET := 120
## Frames to let every _ready() in the arena run before anything is measured.
const SETTLE_FRAMES := 5
## A melee attack's near edge should start close to the body. Above this the weapon reads as a huge
## box rather than a swing, which is the "make it feel like a melee attack" guard.
const MAX_HITBOX_NEAR_EDGE := 0.9
## An upper bound on acceptable reach, so a fix cannot pass by making the weapon enormous.
const MAX_REACH := 3.0


enum Step {
	SETTLE,
	A_POSITION,
	A_ARM,
	A_ATTACK,
	A_WAIT,
	A_ASSERT,
	B_POSITION,
	B_ARM,
	B_ATTACK,
	B_WAIT,
	B_ASSERT,
	DONE,
}

var _main: Node3D
var _env: Node3D
var _player: CharacterBody3D
var _player_combat: PlayerCombat
var _player_hitbox: HitboxComponent

var _attacker_body: CharacterBody3D
var _attacker: EnemyAttacker
var _attacker_health: HealthComponent
var _attacker_loco: Node

var _brute_body: CharacterBody3D
var _brute: EnemyAttacker
var _brute_health: HealthComponent
var _brute_loco: Node

var _step: int = Step.SETTLE
var _frame := 0

var _passed := 0
var _failed := 0
var _finished := false
var _failure_labels: Array[String] = []

## Measured geometry, in metres, along the player's facing.
var _box_centre := 0.0
var _box_half := 0.0
var _reach := 0.0
var _near_edge := 0.0

var _attacker_stand := 0.0
var _brute_stand := 0.0
var _attacker_hurt_r := 0.0
var _brute_hurt_r := 0.0

var _health_before := 0.0
var _interrupted_before := 0
var _distance_at_attack := 0.0
var _player_path_opened := false
var _light_damage := 0.0
var _heavy_damage := 0.0
## Which swing the current scenario drives, for the reading label.
var _attack_label := "light"
## Whether the current scenario swings heavy rather than light.
var _heavy_swing := false


func _ready() -> void:
	# The game root is a SIBLING of this probe, not a child: the run scene instances main.tscn
	# beside the probe so the probe is never itself inside the tree it measures.
	_main = get_node_or_null("../Main") as Node3D
	_step = Step.SETTLE
	_frame = 0


func _physics_process(_delta: float) -> void:
	_frame += 1
	match _step:
		Step.SETTLE:
			if _frame >= SETTLE_FRAMES:
				_do_setup()
		Step.A_POSITION:
			if _attacker_body == null:
				_advance_to(Step.B_POSITION)
				return
			_disable_locomotion(_attacker_loco)
			_stand_at(_attacker_body, _attacker_stand)
			_advance_to(Step.A_ARM)
		Step.A_ARM:
			_arm(_attacker, "AC1 TestAttacker", Step.A_ATTACK, Step.B_POSITION)
		Step.A_ATTACK:
			_swing()
		Step.A_WAIT:
			_wait_for_damage(_attacker_health, Step.A_ASSERT)
		Step.A_ASSERT:
			_assert_lighter()
		Step.B_POSITION:
			if _brute_body == null:
				_advance_to(Step.DONE)
				_finish()
				return
			_disable_locomotion(_brute_loco)
			_stand_at(_brute_body, _brute_stand)
			_advance_to(Step.B_ARM)
		Step.B_ARM:
			_arm(_brute, "AC3 HeavyBrute", Step.B_ATTACK, Step.DONE)
		Step.B_ATTACK:
			_swing()
		Step.B_WAIT:
			_wait_for_damage(_brute_health, Step.B_ASSERT)
		Step.B_ASSERT:
			_assert_heavier()
		Step.DONE:
			_finish()


# --- Setup --------------------------------------------------------------------

func _do_setup() -> void:
	_resolve()
	_expect(_main != null, "AC0 the live game root was instanced")
	_expect(_env != null, "AC0 the live test environment resolved")
	_expect(_player != null and _player_combat != null and _player_hitbox != null,
		"AC0 the player, its real PlayerCombat state machine and its real attack hitbox resolved")
	_expect(_attacker != null and _brute != null, "AC0 both real enemy archetypes resolved")
	if _player == null or _player_combat == null or _player_hitbox == null \
			or _attacker == null or _brute == null:
		_finish()
		return

	_measure_geometry()
	_attacker_stand = _stopping_distance(_attacker_body)
	_brute_stand = _stopping_distance(_brute_body)
	_attacker_hurt_r = _hurt_radius(_attacker_body)
	_brute_hurt_r = _hurt_radius(_brute_body)
	_light_damage = _player_combat.light_attack.damage
	_heavy_damage = _player_combat.heavy_attack.damage

	_expect(_reach > 0.0,
		"AC0 the player's attack reach was MEASURED from the live scene (%.3f m forward)" % _reach)
	_expect(_attacker_stand > 0.0 and _brute_stand > 0.0,
		"AC0 each archetype's OWN stand-off was read from its Locomotion (%.3f m / %.3f m)"
			% [_attacker_stand, _brute_stand])
	if _reach <= 0.0 or _attacker_stand <= 0.0 or _brute_stand <= 0.0:
		_finish()
		return

	_say("AC0 player attacks: light %.2f / heavy %.2f dmg | thresholds: TestAttacker %.0f, HeavyBrute %.0f"
		% [_light_damage, _heavy_damage, _threshold(_attacker), _threshold(_brute)])
	_say("AC0 player hitbox: centre %.3f m, half-depth %.3f m -> spans %.3f m to %.3f m forward"
		% [_box_centre, _box_half, _near_edge, _reach])
	_say("AC0 connect surface: TestAttacker %.3f m (stand %.3f), HeavyBrute %.3f m (stand %.3f)"
		% [_reach + _attacker_hurt_r, _attacker_stand, _reach + _brute_hurt_r, _brute_stand])

	# GEOMETRY COVERAGE, asserted before the runtime scenarios so a reach that cannot even reach
	# the stand-off is reported as a geometry failure rather than only as a missed hit.
	_expect(_reach + _attacker_hurt_r >= _attacker_stand,
		"AC1 reach covers TestAttacker's stand-off (%.3f + %.3f >= %.3f)"
			% [_reach, _attacker_hurt_r, _attacker_stand])
	_expect(_reach + _brute_hurt_r >= _brute_stand,
		"AC3 reach covers HeavyBrute's stand-off (%.3f + %.3f >= %.3f)"
			% [_reach, _brute_hurt_r, _brute_stand])
	# THE FEEL GUARD: the weapon must not pass the near test by becoming enormous.
	_expect(_near_edge <= MAX_HITBOX_NEAR_EDGE,
		"AC4 the hitbox still starts near the body (%.3f m <= %.3f), so it reads as a swing"
			% [_near_edge, MAX_HITBOX_NEAR_EDGE])
	_expect(_reach <= MAX_REACH,
		"AC4 the reach stayed within a melee-sized bound (%.3f m <= %.3f)" % [_reach, MAX_REACH])

	_advance_to(Step.A_POSITION)


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
	_attacker_body = _env.get_node_or_null("TestAttacker") as CharacterBody3D
	if _attacker_body != null:
		_attacker = _attacker_body.get_node_or_null("Attacker") as EnemyAttacker
		_attacker_health = _attacker_body.get_node_or_null("Health") as HealthComponent
		_attacker_loco = _attacker_body.get_node_or_null("Locomotion")
	_brute_body = _env.get_node_or_null("HeavyBrute") as CharacterBody3D
	if _brute_body != null:
		_brute = _brute_body.get_node_or_null("Attacker") as EnemyAttacker
		_brute_health = _brute_body.get_node_or_null("Health") as HealthComponent
		_brute_loco = _brute_body.get_node_or_null("Locomotion")


## Compose the player's forward attack reach from the live hitbox: the world offset of the hitbox
## from the body, projected onto the player's own facing, plus the box's half-depth. Both halves are
## read from the scene, so re-tuning either one is reflected without editing this probe.
func _measure_geometry() -> void:
	var shape_node := _player_hitbox.get_node_or_null("Shape") as CollisionShape3D
	if shape_node == null:
		return
	var box := shape_node.shape as BoxShape3D
	if box == null:
		return
	var forward: Vector3 = -_player.global_transform.basis.z
	var centre := _player_hitbox.global_position - _player.global_position
	_box_centre = centre.dot(forward)
	_box_half = box.size.z * 0.5
	_reach = _box_centre + _box_half
	_near_edge = _box_centre - _box_half


# --- Scenarios ----------------------------------------------------------------

## Commit the target's own swing, so there is a real committed attack for a hit to interrupt.
## `next` is the swing step; `fallback` is where this scenario goes if no swing can be armed.
func _arm(attacker: EnemyAttacker, label: String, next: int, fallback: int) -> void:
	if attacker == null:
		_advance_to(fallback)
		return
	EnemyAttacker.stand_down_all(get_tree())
	# DO NOT OPEN A SWING WHILE THE PLAYER'S OWN MACHINE IS STILL COMMITTED. MEASURED on this
	# probe's first run: the second scenario asked for a swing while PlayerCombat was still ACTIVE,
	# which that machine correctly REFUSED - and the refusal was then reported as a probe
	# scheduling failure. The enemy swing is armed only once the player can actually answer it,
	# and this wait is not charged against the enemy's own commit budget.
	if _player_combat != null and _player_combat.is_busy():
		return
	if attacker.is_attacking() or attacker.try_start():
		_say("%s committed a swing (attacking=%s, %.3f s left)"
			% [label, str(attacker.is_attacking()), attacker.phase_remaining()])
		_advance_to(next)
		return
	if _frame > ARM_FRAME_BUDGET:
		_fail("%s never committed a swing to interrupt (%d frames)" % [label, ARM_FRAME_BUDGET])
		_advance_to(fallback)


## Drive the player's REAL attack state machine from the enemy's OWN stand-off distance. Nothing is
## opened by hand: `try_start()` is the one way an attack begins, and its own phase advance is what
## opens the damage window.
func _swing() -> void:
	var body := _attacker_body if _step == Step.A_ATTACK else _brute_body
	var health := _attacker_health if _step == Step.A_ATTACK else _brute_health
	var attacker := _attacker if _step == Step.A_ATTACK else _brute
	if body == null or health == null or attacker == null:
		_advance_to(Step.B_POSITION if _step == Step.A_ATTACK else Step.DONE)
		if _step == Step.DONE:
			_finish()
		return
	# Re-assert the standing distance on the frame of the swing, so the measurement is against the
	# distance the attack actually started from rather than one a frame or two earlier.
	_stand_at(body, _stopping_distance(body))
	_distance_at_attack = _flat_distance(body)
	_health_before = health.current_health
	_interrupted_before = attacker.attacks_interrupted
	_player_path_opened = false
	# SCENARIO B SWINGS HEAVY ON PURPOSE. The heavy-only contract the user kept means the HeavyBrute
	# deliberately REFUSES a light hit, so a light swing there would only re-prove the refusal. The
	# half still worth measuring is that a HEAVY hit does interrupt it.
	_heavy_swing = _step == Step.B_ATTACK
	_attack_label = "heavy" if _heavy_swing else "light"
	var definition := _player_combat.heavy_attack if _heavy_swing else _player_combat.light_attack
	var started := _player_combat.try_start(definition)
	_expect(started, "%s the player's REAL attack state machine accepted a %s attack from %.2f m"
		% [_ac_label(), _attack_label, _distance_at_attack])
	if not started:
		_fail("%s could not start the player's real attack; state=%s"
			% [_ac_label(), _player_combat.state_name()])
		_advance_to(Step.B_POSITION if _step == Step.A_ATTACK else Step.DONE)
		return
	_advance_to(Step.A_WAIT if _step == Step.A_ATTACK else Step.B_WAIT)


func _wait_for_damage(health: HealthComponent, next: int) -> void:
	if health == null:
		_fail("%s the target has no HealthComponent to read" % _ac_label())
		_advance_to(next)
		return
	if not _player_path_opened and _player_combat.hitbox_is_open():
		_player_path_opened = true
		_say("%s the player's OWN phase machine opened the damage window (state=%s)"
			% [_ac_label(), _player_combat.state_name()])
	if health.current_health < _health_before:
		_advance_to(next)
		return
	if _frame > ATTACK_FRAME_BUDGET:
		_fail("%s the player's REAL attack never landed from %.2f m within %d frames"
			% [_ac_label(), _distance_at_attack, ATTACK_FRAME_BUDGET])
		_advance_to(next)


## The lighter archetype: its threshold is below the light damage, so the hit must BOTH land at the
## stand-off and interrupt the committed swing.
func _assert_lighter() -> void:
	_expect(_attacker_health.current_health < _health_before,
		"AC1 a real light attack DAMAGED TestAttacker at its own stand-off (%.2f m, was %.0f -> %.0f)"
			% [_distance_at_attack, _health_before, _attacker_health.current_health])
	_expect(_player_path_opened,
		"AC1 the damage came through the player's real attack phase machine, not a direct activate()")
	_expect(_attacker.attacks_interrupted > _interrupted_before,
		"AC2 the light hit INTERRUPTED TestAttacker's committed swing (%d -> %d)"
			% [_interrupted_before, _attacker.attacks_interrupted])
	_say("AC2 after the interrupt: phase=%s, attacking=%s, damage window open=%s"
		% [_attacker.phase_name(), str(_attacker.is_attacking()), str(_attacker.hitbox_is_open())])
	_expect(not _attacker.hitbox_is_open(),
		"AC2 the interrupted swing's damage window is CLOSED (open=%s)"
			% str(_attacker.hitbox_is_open()))
	_advance_to(Step.B_POSITION)


## The heavier archetype: its threshold is ABOVE the light damage, so the hit must land at the
## stand-off and must NOT interrupt. This is the heavy-only contract.
func _assert_heavier() -> void:
	_expect(_brute_health.current_health < _health_before,
		"AC3 a real HEAVY attack DAMAGED HeavyBrute at its own stand-off (%.2f m, was %.0f -> %.0f)"
			% [_distance_at_attack, _health_before, _brute_health.current_health])
	_expect(_player_path_opened,
		"AC3 the damage came through the player's real attack phase machine, not a direct activate()")
	_expect(_brute.attacks_interrupted > _interrupted_before,
		"AC3 the HEAVY hit INTERRUPTED HeavyBrute's committed swing (%d -> %d)"
			% [_interrupted_before, _brute.attacks_interrupted])
	_say("AC3 after the interrupt: phase=%s, attacking=%s, damage window open=%s"
		% [_brute.phase_name(), str(_brute.is_attacking()), str(_brute.hitbox_is_open())])
	_expect(not _brute.hitbox_is_open(),
		"AC3 the interrupted swing's damage window is CLOSED (open=%s)" % str(_brute.hitbox_is_open()))
	_assert_heavy_only_contract()
	_advance_to(Step.DONE)


## The heavy-only contract the user chose, asserted from the archetype's OWN data rather than
## restated here. The Reaction component is the single owner of the threshold decision, so its
## `would_stagger()` is asked directly. Without this, "the light hit was refused" could mean the
## contract held OR that the light hit simply never landed, and those are not the same fact.
func _assert_heavy_only_contract() -> void:
	if _brute_body == null:
		return
	var reaction := _brute_body.get_node_or_null("Reaction")
	if reaction == null or not reaction.has_method("would_stagger"):
		_expect(false, "AC3 the HeavyBrute's Reaction component exposes would_stagger()")
		return
	_expect(not bool(reaction.call("would_stagger", _light_damage)),
		"AC3 the HeavyBrute REFUSES a light hit (%.0f dmg) - the heavy-only contract held"
			% _light_damage)
	_expect(bool(reaction.call("would_stagger", _heavy_damage)),
		"AC3 the HeavyBrute ACCEPTS a heavy hit (%.0f dmg), which is what makes it interruptible"
			% _heavy_damage)


# --- Helpers ------------------------------------------------------------------

## Put the player in front of an enemy, facing it, on the project's facing convention: a body at
## rotation.y = 0 faces -Z, so the direction it faces is -basis.z.
func _stand_at(enemy: CharacterBody3D, distance: float) -> void:
	if enemy == null or _player == null:
		return
	var facing := -enemy.global_transform.basis.z
	_player.global_position = enemy.global_position + facing * distance + Vector3(0.0, 0.05, 0.0)
	var to_enemy := enemy.global_position - _player.global_position
	to_enemy.y = 0.0
	if to_enemy.length_squared() > 0.0001:
		_player.rotation.y = atan2(-to_enemy.x, -to_enemy.z)
	_player.velocity = Vector3.ZERO


func _disable_locomotion(loco: Node) -> void:
	if loco != null:
		loco.set_physics_process(false)


func _flat_distance(enemy: Node3D) -> float:
	if enemy == null or _player == null:
		return 0.0
	var offset := enemy.global_position - _player.global_position
	offset.y = 0.0
	return offset.length()


## The range this enemy commits an attack from, read from the enemy that owns it.
func _stopping_distance(body: Node) -> float:
	if body == null:
		return 0.0
	var loco := body.get_node_or_null("Locomotion")
	if loco == null or not loco.has_method("stopping_distance"):
		return 0.0
	return float(loco.call("stopping_distance"))


## The enemy's hurtbox outer radius: the surface the player's hitbox must actually touch.
func _hurt_radius(body: Node) -> float:
	if body == null:
		return 0.0
	var hurt := body.get_node_or_null("Hurtbox")
	if hurt == null:
		return 0.0
	var shape_node := hurt.get_node_or_null("Shape") as CollisionShape3D
	if shape_node == null:
		return 0.0
	var capsule := shape_node.shape as CapsuleShape3D
	if capsule == null:
		return 0.0
	return capsule.radius


## An archetype's interruption threshold, read from the actor's own Reaction component - the single
## owner of that decision - rather than restated here.
func _threshold(attacker: EnemyAttacker) -> float:
	if attacker == null:
		return 0.0
	var body := attacker.get_parent()
	if body == null:
		return 0.0
	var reaction := body.get_node_or_null("Reaction")
	if reaction == null:
		return 0.0
	var value = reaction.get("stagger_threshold")
	if value == null:
		return 0.0
	return float(value)


func _ac_label() -> String:
	if _step == Step.A_ATTACK or _step == Step.A_WAIT:
		return "AC1"
	return "AC3"


func _advance_to(next: int) -> void:
	_step = next
	_frame = 0


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[REACH]   PASS  %s" % label)
	else:
		_failed += 1
		_failure_labels.append(label)
		print("[REACH]   FAIL  %s" % label)


func _fail(label: String) -> void:
	_failed += 1
	_failure_labels.append(label)
	print("[REACH]   FAIL  %s" % label)


func _say(message: String) -> void:
	print("[REACH] %s" % message)


## Idempotent by guard, so the summary prints exactly once however the probe reaches its end.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("[REACH] --- summary ---")
	# The headline readings are re-printed here because the console tail is truncated: a
	# measurement printed only mid-run can be missing from the transcript a reader actually sees.
	print("[REACH] geometry: reach %.3f m, spans %.3f m -> %.3f m forward"
		% [_reach, _near_edge, _reach])
	print("[REACH] stand-off: TestAttacker %.3f m (surface %.3f m), HeavyBrute %.3f m (surface %.3f m)"
		% [_attacker_stand, _reach + _attacker_hurt_r, _brute_stand, _reach + _brute_hurt_r])
	if _attacker != null:
		print("[REACH] TestAttacker: attacks=%d interrupted=%d"
			% [_attacker.attacks_started, _attacker.attacks_interrupted])
	if _brute != null:
		print("[REACH] HeavyBrute: attacks=%d interrupted=%d"
			% [_brute.attacks_started, _brute.attacks_interrupted])
	if _failed == 0:
		print("[REACH] RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		print("[REACH] RESULT: %d CHECK(S) FAILED (%d passed)" % [_failed, _passed])
		for label in _failure_labels:
			print("[REACH]   FAILED: %s" % label)
	set_physics_process(false)
