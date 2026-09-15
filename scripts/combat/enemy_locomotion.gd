class_name EnemyLocomotion
extends Node
## One enemy's ENGAGEMENT MOVEMENT (Milestone 17 - minimal enemy engagement).
##
## WHY THIS EXISTS. Every enemy in Cascadia stood exactly where its scene placed it. The enemy body
## is a `CharacterBody3D` with NO script, so its `velocity` was permanently zero: it could not walk,
## and `ActorState.is_moving()` answered false for every enemy for the whole life of the arena. That
## also made the presentation intent `locomotion` unreachable for anything except the player.
##
## This component is the smallest thing that turns an enemy from a fixture into a CLOSING threat: it
## notices its target, walks to it, faces it, stops at the range its own attack commits from, and
## hands the body straight back to the existing attack loop. That is the whole behaviour.
##
## WHAT IT OWNS - exactly three things, and nothing else:
##
##   1. the body's HORIZONTAL VELOCITY
##   2. the body's YAW while no attack is committed
##   3. one small engagement state: IDLE / APPROACH / RETURNING
##
## WHAT IT DELIBERATELY DOES NOT DO:
##
##   - It does not attack, decide when to attack, or know what an attack phase is. `EnemyAttacker`
##     remains the single owner of the swing; this component only ever ASKS whether one is committed.
##   - It owns no health, no damage and no defeat. Defeat is asked of the same sibling component the
##     attack machine asks, duck-typed, and a defeated enemy simply stops walking.
##   - It does not select or validate targets. `CombatParticipant.is_usable_target()` is the project's
##     single target-validity authority and is asked here exactly as every other consumer asks it.
##   - It does NOT navigate. Steering is direct and flat, through `move_and_slide()`, which is enough
##     for an open arena with a few pillars. Navigation and pathfinding are a separate, deliberately
##     deferred system and are NOT introduced here.
##   - It does not save or load anything. The mark it returns to is the transform the SCENE authored,
##     captured at boot - not persisted world state.
##
## THE YAW CONTRACT, which is the one property two systems could fight over. The body's `rotation.y`
## has exactly ONE writer at any moment:
##
##   no attack committed   ->  this component turns the body at `turn_speed_degrees`
##   attack committed      ->  NEITHER writes. `EnemyAttacker` froze the facing when it committed and
##                             does not re-read it, and this component stops writing for the whole
##                             commitment - so a player who walks around a windup is genuinely
##                             walking around it.
##
## `EnemyAttacker._face_target()` asks `owns_uncommitted_facing()` before it touches yaw. With NO
## Locomotion component present that component behaves exactly as it always has, which is what keeps
## every archived scene, probe and recorded result valid.
##
## Attach one per moving enemy, as a direct child of the body, named "Locomotion".

## Every locomotion component joins this group, so tooling and a probe can enumerate engaged enemies
## without a hard-coded scene path - the same resolution pattern the attacker and targeting modules
## use.
const GROUP_LOCOMOTION := &"enemy_locomotion"

## Fall speed cap. The same value the NPC archetype uses.
const MAX_FALL_SPEED := 40.0

## IDLE is being at the mark and unaware. APPROACH is closing on a detected target. RETURNING is
## walking back to the recorded mark. There is deliberately no state for "attacking": a committed
## attack is a fact this component READS from its attacker, not a state it owns.
enum Engagement { IDLE, APPROACH, RETURNING }

@export_group("Data")
## The archetype data for this enemy's MOVEMENT: what this VARIANT is allowed to change.
##
## Copied into the exported fields below at `_ready()`, exactly as `EnemyAttacker` seeds itself from
## its own profile - one-way and one-time, so a variant is a new `.tres` rather than a copied scene.
## Leave it EMPTY and this component keeps its own exported values.
##
## ONLY THE `Locomotion` GROUP IS READ. The lifecycle fields on an `ActorProfile` (health, mortality,
## targetability, reaction) are owned by HealthComponent, EnemyDeathComponent, CombatParticipant and
## HealthReactionComponent, which are seeded from the scene. This resource is deliberately NOT a
## second source for any of them.
@export var profile: ActorProfile

@export_group("Movement")
## Ordinary ground speed while approaching. Fast enough to close on a player who stops, slow enough
## that a walking player outpaces it.
@export var move_speed := 2.4
## Acceleration toward the wanted velocity, and the rate the body is slowed when the wanted velocity
## is zero. ONE number for both, so an enemy cannot be tuned to glide faster than it can stop.
@export var acceleration := 12.0
## Degrees per second the body turns while no attack is committed.
@export var turn_speed_degrees := 260.0

@export_group("Engagement")
## How far INSIDE `engage_range` the enemy aims to stop, in metres. Stopping exactly ON the commit
## threshold would leave the enemy oscillating across it, so the walk stops short and the remaining
## margin is the band the attack is committed from.
@export var stop_margin := 0.4
## Width of the slow-down band, in metres, measured outward from the stopping distance. Speed falls
## to zero AT the stopping distance and reaches full `move_speed` this far beyond it, which is what
## makes the stop smooth instead of a lurch - and what stops the enemy overshooting into the player.
@export var approach_band := 0.8
## How much further than `detection_radius` the target must get before an APPROACHING enemy gives up
## and returns to its mark. A small hysteresis, so an enemy cannot flap between walking in and
## walking home while the player stands on the detection boundary.
@export var release_margin := 1.5
## How close to its mark, in metres, the enemy must get in XZ before it has arrived and goes IDLE.
@export var return_tolerance := 0.3

@export_group("Wiring")
## The attacker whose committed attack locks the facing. Defaults to a sibling named "Attacker".
##
## This component also READS `detection_radius` and `engage_range` from it rather than keeping a
## second copy of either: an enemy's engagement tuning is ONE record, and the attacker (seeded from
## `EnemyAttackProfile`) already owns it. An enemy with no attacker never detects anything, which is
## correct - an enemy that cannot swing has nothing to close on.
@export var attacker_path: NodePath = NodePath("../Attacker")
## The defeat state that stops this enemy walking. Defaults to a sibling named "Death"; an enemy
## without one simply never stops for defeat.
@export var death_path: NodePath = NodePath("../Death")
## Explicit target override. Left empty, the target is resolved through `target_group`.
@export var target_path: NodePath
## The group the target belongs to. Deliberately the SAME group `EnemyAttacker` uses, so both
## components in one enemy always speak about the same actor.
@export var target_group: StringName = &"player_actor"

## Print each engagement state change. Diagnostic.
@export var debug_logging := false

## The current engagement state, one value of `Engagement`.
var _state: int = Engagement.IDLE
var _body: CharacterBody3D
var _attacker: EnemyAttacker
var _death: Node
var _target: Node3D
## The transform the scene authored, captured at boot. RECORDED rather than read back later, because
## by the time an enemy is engaged the fight has already moved and turned it. The same shape the NPC
## archetype uses for its own mark.
var _spawn_transform := Transform3D.IDENTITY
## The yaw the scene authored, for the return-to-mark facing.
var _home_yaw := 0.0

## How many times this enemy has noticed something to engage. Diagnostic: it separates "never
## detected" from "detected and returned", which one on-screen look cannot tell apart.
var detections := 0
## How many times this enemy has given up and walked home.
var returns_made := 0
## How many times the arena reset has put this enemy back on its mark.
var resets_to_mark := 0


func _ready() -> void:
	add_to_group(GROUP_LOCOMOTION)
	# The BODY is resolved FIRST, because this component is a separate child Node and does NOT own
	# the transform: every read and write below goes through `_body`. The NPC archetype can capture
	# its own `global_transform` because that script IS the body; this one is not.
	_body = get_parent() as CharacterBody3D
	if _body == null:
		push_warning("EnemyLocomotion %s: parent is not a CharacterBody3D; this enemy cannot move." % name)
		return
	_spawn_transform = _body.global_transform
	_home_yaw = _body.rotation.y
	_resolve()
	_apply_profile()


func _physics_process(delta: float) -> void:
	if _body == null:
		return

	# A DEFEATED ENEMY DOES NOT MOVE. Asked rather than cached, so a defeat takes effect on the frame
	# it happens. The body is STOPPED rather than left to coast, so one that was mid-stride does not
	# slide on after dying, and the engagement state is dropped so a corpse is never reported as
	# engaged.
	if _is_defeated():
		if _state != Engagement.IDLE:
			_enter(Engagement.IDLE)
		_body.velocity = Vector3.ZERO
		return

	_update_engagement()
	_update_facing(delta)
	_update_horizontal(delta)
	_apply_gravity(delta)
	_body.move_and_slide()


# --- The engagement state machine ---------------------------------------------

## The whole decision, and it is deliberately this small: notice, close, give up, go home.
func _update_engagement() -> void:
	match _state:
		Engagement.IDLE:
			if _target_within_detection():
				_enter(Engagement.APPROACH)
		Engagement.APPROACH:
			# Two ways to lose a target, and they are different facts: the target stopped being
			# USABLE (it died, was defeated, or is not a combat participant) or it simply got far
			# enough away. Both end the approach; neither is guessed at.
			if not _target_usable():
				_enter(Engagement.RETURNING)
			elif _distance_to_target() > detection_radius() + release_margin:
				_enter(Engagement.RETURNING)
		Engagement.RETURNING:
			if _target_within_detection():
				_enter(Engagement.APPROACH)
			elif _mark_reached():
				_snap_to_mark()
				_enter(Engagement.IDLE)


func _enter(next: int) -> void:
	if next == _state:
		return
	_state = next
	match next:
		Engagement.APPROACH:
			detections += 1
			_log("-> APPROACH (target at %.2f m)" % _distance_to_target())
		Engagement.RETURNING:
			returns_made += 1
			_log("-> RETURNING (target at %.2f m)" % _distance_to_target())
		_:
			_log("-> IDLE (at mark)")


# --- Movement -----------------------------------------------------------------

## THE YAW CONTRACT, as an explicit declaration rather than a name check.
##
## This component claims the body's yaw while no attack is committed. `EnemyAttacker` asks this
## before writing `rotation.y`; a component that does not answer it leaves the attacker owning yaw
## exactly as it did before this milestone.
func owns_uncommitted_facing() -> bool:
	return true


## Turn the body toward whatever it is currently doing. A body with `rotation.y = 0` faces -Z, so
## facing a flat direction `d` is `atan2(-d.x, -d.z)`. Roll and pitch are never touched - the horizon
## stays upright, as everywhere else in Cascadia.
##
## NOTHING IS WRITTEN WHILE AN ATTACK IS COMMITTED. That single guard is the whole yaw contract.
func _update_facing(delta: float) -> void:
	if not _attack_is_committed():
		var yaw := _home_yaw
		match _state:
			Engagement.APPROACH:
				var to := _flat_to_target()
				# The guard is not cosmetic: atan2 of a zero-length vector still returns a number,
				# and adopting it would snap the body to an arbitrary yaw when the target stands
				# exactly on top of this actor.
				if to.length_squared() > 0.0001:
					yaw = atan2(-to.x, -to.z)
			Engagement.RETURNING:
				var to_mark := _spawn_transform.origin - _body.global_position
				to_mark.y = 0.0
				if to_mark.length_squared() > 0.0001:
					yaw = atan2(-to_mark.x, -to_mark.z)
		_body.rotation.y = rotate_toward(_body.rotation.y, yaw, deg_to_rad(turn_speed_degrees) * delta)
		return


## The horizontal velocity for this frame.
##
## NO ATTACKING WHILE MOVING. A committed attack owns the body, so the wanted velocity for the whole
## commitment is zero and the enemy decelerates to a stop instead of sliding through its own swing.
## This is the movement half of the same rule that locks the facing.
func _update_horizontal(delta: float) -> void:
	var wanted := Vector3.ZERO
	if not _attack_is_committed():
		match _state:
			Engagement.APPROACH:
				wanted = _approach_velocity()
			Engagement.RETURNING:
				wanted = _return_velocity()
	var flat := Vector3(_body.velocity.x, 0.0, _body.velocity.z)
	var next := flat.move_toward(wanted, acceleration * delta)
	_body.velocity.x = next.x
	_body.velocity.z = next.z


## The velocity that walks this enemy to its stopping distance and no further.
##
## SPEED FALLS TO ZERO AT THE STOPPING DISTANCE rather than being cut off there, and that is what
## removes the two failure modes of the obvious version: an enemy that overshoots into the player's
## capsule, and an enemy that jitters across the boundary because it keeps arriving at full speed.
func _approach_velocity() -> Vector3:
	var to := _flat_to_target()
	var distance := to.length()
	if distance <= 0.0001:
		return Vector3.ZERO
	var span := distance - stopping_distance()
	if span <= 0.0:
		return Vector3.ZERO
	return to / distance * (move_speed * clampf(span / approach_band, 0.0, 1.0))


## The velocity that walks this enemy back onto its mark, easing off over the last approach_band
## metres so it arrives instead of overrunning and turning round.
func _return_velocity() -> Vector3:
	var to := _spawn_transform.origin - _body.global_position
	to.y = 0.0
	var distance := to.length()
	if distance <= 0.0001:
		return Vector3.ZERO
	return to / distance * (move_speed * clampf(distance / approach_band, 0.0, 1.0))


## Ordinary gravity, the same shape the NPC archetype and the player use. It matters for more than
## staying on the floor: the body's velocity is what `ActorState.is_moving()`, `is_grounded()` and
## `has_ground_report()` read, so this is what makes those answers REAL for an enemy rather than a
## permanent false.
func _apply_gravity(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	_body.velocity.y = maxf(_body.velocity.y - gravity * delta, -MAX_FALL_SPEED)


# --- Queries ------------------------------------------------------------------

## Whether this enemy is currently PURSUING a target. This is a real engagement authority rather
## than the damage-recently-or-locked stand-in the health bars used before this milestone.
func is_engaged() -> bool:
	return _state == Engagement.APPROACH


## The engagement state in one word, for a debug readout or a probe report.
func state_name() -> String:
	match _state:
		Engagement.APPROACH:
			return "APPROACH"
		Engagement.RETURNING:
			return "RETURNING"
		_:
			return "IDLE"


## The radius at which this enemy notices a target, read from the attacker that owns the value.
func detection_radius() -> float:
	if _attacker == null:
		return 0.0
	return _attacker.detection_radius


## The range this enemy commits an attack from, read from the attacker that owns it.
func engage_range() -> float:
	if _attacker == null:
		return 0.0
	return _attacker.engage_range


## Where this enemy stops walking: inside its own commit range by `stop_margin`.
func stopping_distance() -> float:
	return maxf(0.0, engage_range() - stop_margin)


## Flat distance to the current target, or INF when there is none.
func distance_to_target() -> float:
	return _distance_to_target()


## Flat distance to the recorded mark.
func distance_to_mark() -> float:
	var to := _spawn_transform.origin - _body.global_position
	to.y = 0.0
	return to.length()


## The transform the scene authored, captured at boot.
func spawn_transform() -> Transform3D:
	return _spawn_transform


# --- Reset --------------------------------------------------------------------

## Put this enemy back on the transform its scene authored, and stop it.
##
## The ONE reset this component has. It is called by the arena reset path - the same path that
## refills an enemy's health and clears its defeat - so a player who dies does not come back to an
## arena the previous fight had rearranged.
##
## It deliberately does NOT touch health, defeat or the attack state: each of those has exactly one
## owner and none of them is this component.
func reset_to_mark() -> void:
	_snap_to_mark()
	_enter(Engagement.IDLE)
	resets_to_mark += 1
	_log("reset to mark")


func _snap_to_mark() -> void:
	if _body == null:
		return
	_body.global_transform = _spawn_transform
	_body.velocity = Vector3.ZERO


# --- Internals ----------------------------------------------------------------

## Whether an attack currently owns this body. Asked of the owner rather than cached, so a commitment
## takes effect on the frame it happens.
func _attack_is_committed() -> bool:
	if _attacker == null:
		return false
	return _attacker.is_attacking()


func _flat_to_target() -> Vector3:
	var target := _get_target()
	if target == null or _body == null:
		return Vector3.ZERO
	var to := target.global_position - _body.global_position
	to.y = 0.0
	return to


func _distance_to_target() -> float:
	var target := _get_target()
	if target == null or _body == null:
		return INF
	return _flat_to_target().length()


## Whether the target is both USABLE and inside the detection radius. Usability is asked first and
## through the project's single validity authority, so a dead or defeated target is never detected -
## the same rule every other consumer of that authority obeys.
func _target_within_detection() -> bool:
	if not _target_usable():
		return false
	var radius := detection_radius()
	if radius <= 0.0:
		return false
	return _distance_to_target() <= radius


func _target_usable() -> bool:
	return CombatParticipant.is_usable_target(_get_target())


func _mark_reached() -> bool:
	return distance_to_mark() <= return_tolerance


## Whether the enemy is defeated and must not move. An enemy with no death state is never defeated,
## so a scene without one keeps its previous behaviour exactly.
func _is_defeated() -> bool:
	if _death == null or not is_instance_valid(_death):
		_death = get_node_or_null(death_path) if not String(death_path).is_empty() else null
	if _death == null:
		return false
	if not _death.has_method(&"is_defeated"):
		return false
	return bool(_death.call(&"is_defeated"))


# --- Resolution ---------------------------------------------------------------

func _resolve() -> void:
	_attacker = get_node_or_null(attacker_path) as EnemyAttacker
	_death = get_node_or_null(death_path)


## Copy the archetype's MOVEMENT data into this component's own exported fields, once, at `_ready()`.
##
## The `> 0.0` guards are the project's existing convention for this resource: `ActorProfile`'s
## locomotion defaults are 0.0, which means "not authored", so a field left at 0 is not written and
## this component keeps its own value. Wiring a profile can therefore change numbers but can never
## zero out a working enemy.
func _apply_profile() -> void:
	if profile == null:
		return
	if profile.move_speed > 0.0:
		move_speed = profile.move_speed
	if profile.acceleration > 0.0:
		acceleration = profile.acceleration
	if profile.turn_speed_degrees > 0.0:
		turn_speed_degrees = profile.turn_speed_degrees


## The target actor, or null when there is none. Found by group so this component depends on no
## particular player class: it only needs a Node3D answering to `target_group`.
func _get_target() -> Node3D:
	if _target == null or not is_instance_valid(_target):
		if not String(target_path).is_empty():
			_target = get_node_or_null(target_path) as Node3D
		elif get_tree() != null:
			_target = get_tree().get_first_node_in_group(target_group) as Node3D
	return _target


func _log(message: String) -> void:
	if debug_logging:
		print("[LOCOMOTION] %s: %s" % [name, message])
