class_name PlayerController
extends CharacterBody3D
## Milestone 1 - grounded player movement.
##
## Soulslike locomotion on primitive geometry. Gameplay owns speed, timing and
## state; presentation adapts later (Milestone 15). This controller deliberately
## implements NO jumping: Cascadia's foundation has no airborne mobility, no
## platforming and no traversal. `jump` stays a reserved input slot with no
## implementation anywhere in this file.
##
## What this owns:
##   - camera-relative directional input
##   - acceleration and deceleration, at different rates on purpose
##   - facing: the body turns toward its movement direction, EXCEPT while a
##     committed evasion owns the body, when it holds the locked gameplay facing
##     instead of re-deriving yaw from the evasion's own velocity, and EXCEPT
##     while a target is locked and no committed action owns the body, when the
##     body faces the locked target (Milestone 13 - see _sync_lock_orientation
##     and _apply_facing)
##   - gravity and floor settling
##   - slopes (up to floor_max_angle) and low steps (max_step_height), outside a
##     committed evasion, which owns its own displacement
##   - a fall-recovery floor so a bad fall can never soft-lock the session
##
## What this does NOT own (it reads their state, it does not implement them):
##   - attack timing and stamina bookkeeping (PlayerCombat, StaminaComponent)
##   - the dodge's own timing, cost and i-frames (DodgeComponent)
##   - lock-on facing, enemy AI, parry
##
## Input reaches this class ONLY through CascadiaInput semantic queries. No
## physical key, mouse button or joypad button is read here.

@export_group("Speed")
## Ground speed with no sprint. Soulslike default locomotion is a jog.
@export var move_speed := 4.2
## Ground speed while sprinting. Milestone 7 adds stamina drain and tuning.
@export var sprint_speed := 6.8

@export_group("Acceleration")
## How fast horizontal velocity builds toward the target, in units/s^2.
@export var acceleration := 22.0
## How fast velocity bleeds off when input stops. Higher than acceleration so
## stopping feels crisp without making starts feel twitchy.
@export var deceleration := 30.0
## Fraction of acceleration available while airborne.
@export var air_control := 0.35

@export_group("Facing")
## Degrees per second the body turns toward its movement direction.
@export var turn_speed_degrees := 720.0

@export_group("Gravity")
## Multiplier on the project's default 3D gravity.
@export var gravity_scale := 1.6
## Terminal downward speed, so a long fall stays stable.
@export var max_fall_speed := 40.0

@export_group("Traversal")
## Tallest ledge the body will step up onto. Anything taller blocks movement.
@export var max_step_height := 0.5
## Forward reach of the step probe, as a multiple of the capsule radius.
@export var step_probe_reach := 1.2
## Fraction of intended horizontal travel that still counts as moving freely.
## A frame achieving less than this is treated as obstructed and a step-up is
## attempted. On the 20 degree ramp the body keeps about 88 percent of its
## intended travel, so the ramp is never corrected.
@export var blocked_travel_ratio := 0.5
## Fall below this Y and the player returns to spawn instead of falling forever.
@export var respawn_below_y := -25.0

@export_group("Combat")
## The player's attack state machine. While it reports busy the body is committed
## to the attack and will not move. Kept in PlayerCombat so locomotion never has
## to know what an attack is, only that one is in progress.
## Where the attack state machine lives. Defaults to a child named "Combat";
## an actor without one simply never commits to an attack.
@export var combat_path: NodePath = NodePath("Combat")

@export_group("Stamina")
## Stamina drained per second while sprinting. An actor with no StaminaComponent
## is never charged and never gated, so it simply sprints as it always did.
@export var sprint_stamina_per_second := 18.0
## The actor's stamina pool. Defaults to a child named "Stamina".
@export var stamina_path: NodePath = NodePath("Stamina")

@export_group("Dodge")
## The actor's dodge. Defaults to a child named "Dodge". An actor without one
## simply cannot dodge; it still moves, sprints and attacks exactly as before.
@export var dodge_path: NodePath = NodePath("Dodge")

@export_group("Parry")
## The actor's parry. Defaults to a child named "Parry". An actor without one simply
## cannot parry; it still moves, sprints, dodges and attacks exactly as before.
@export var parry_path: NodePath = NodePath("Parry")

@export_group("Death")
## The actor's death circuit. Read ONLY to know whether the actor may take input.
## Defaults to a child named "Death"; an actor without one is simply never dead.
@export var death_path: NodePath = NodePath("Death")

var _input: CascadiaInput
var _wish_direction := Vector3.ZERO
var _wish_magnitude := 0.0
## The body yaw this controller last authored while no evasion owned the body, and
## whether an evasion was already active on the previous frame. Together they are
## the yardstick a committed evasion holds its facing against, so the locked
## gameplay facing survives the evasion instead of being re-derived from the
## evasion's own velocity. See _apply_facing() and _sync_evasion_authority().
var _locked_yaw := 0.0
## True while an evasion was already owning the body on the previous frame, so the
## frame where it ENDS can be recognised and the handoff handled exactly once.
var _was_dodging := false
var _spawn_position := Vector3.ZERO
var _spawn_yaw := 0.0
var _combat: PlayerCombat
var _stamina: StaminaComponent
var _dodge: DodgeComponent
var _parry: ParryComponent
var _death: DeathComponent
## The targeting module this actor's lock belongs to. Resolved through the module's own group, so no
## scene path is hard-coded and a scene with no targeting module simply never locks. READ-ONLY: this
## controller never takes, cycles or releases a lock - it only faces what the module says is locked.
var _targeting: TargetingComponent


func _ready() -> void:
	_spawn_position = global_position
	_spawn_yaw = rotation.y
	# The authored yaw is the first yardstick, so a body that has not moved yet
	# still has a facing an evasion can hold.
	_locked_yaw = _spawn_yaw
	if not GameActions.all_actions().is_empty():
		pass


func _physics_process(delta: float) -> void:
	# Facing arbitration happens at the TOP of the frame, before anything can move
	# the body. The yardstick an evasion holds must be the facing that was authored
	# while the actor still owned its own orientation, so it is refreshed here and
	# never re-derived from the evasion's own velocity further down the frame.
	_sync_evasion_authority()
	# Lock-on orientation is settled next, and both calls are deliberately at the TOP of the step:
	# the facing a committed action holds must be the facing that was authored while the actor still
	# owned its own orientation, never one re-derived after the action has begun.
	_sync_lock_orientation()

	# A dead actor is not asked for input at all. Gating HERE rather than inside each
	# reader is deliberate: there is then no input path that can be forgotten, so a
	# death cannot be escaped by a dodge, a parry or a swing. The body stops where it
	# fell - gravity still applies, so a death in the air comes down. The death
	# circuit is the only thing that gives control back.
	if _is_dead():
		_wish_direction = Vector3.ZERO
		_wish_magnitude = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	# Read the committed actions first: either can commit the body on this frame, and
	# _read_wish_direction() and _apply_horizontal() must see that immediately rather
	# than one frame late. Dodge is attempted before parry, so a frame that presses
	# both attempts the dodge first and the parry is then refused by the mutex -
	# deterministic, and one of the two always wins cleanly.
	_read_dodge()
	_read_parry()
	_read_wish_direction()
	_apply_gravity(delta)
	_apply_horizontal(delta)

	# Step-up has to know whether this frame's move was actually obstructed, so
	# capture what was asked for before the slide and compare it afterwards.
	var before := global_position
	var intended := Vector3(velocity.x, 0.0, velocity.z) * delta
	move_and_slide()
	_resolve_step_up(before, intended)

	_update_stamina(delta)
	_apply_facing(delta)
	_check_fall_recovery()


# --- Movement input ---------------------------------------------------------

## Turn the semantic movement vector into a world-space direction using the
## camera's yaw only. Pitch is discarded, so looking down never slows movement.
func _read_wish_direction() -> void:
	var input := _get_input()
	if input == null:
		_wish_direction = Vector3.ZERO
		_wish_magnitude = 0.0
		return

	# A dead actor takes no movement input: the body belongs to the death state
	# until the reset hands it back. Checked before commitment because a death has
	# no exception to it.
	if _is_dead():
		_wish_direction = Vector3.ZERO
		_wish_magnitude = 0.0
		return

	# An attack commits the body. Movement input is ignored for the whole attack,
	# so a swing cannot be steered or slid out of.
	if _is_committed():
		_wish_direction = Vector3.ZERO
		_wish_magnitude = 0.0
		return

	var move := input.get_move_vector()
	_wish_magnitude = minf(move.length(), 1.0)
	if _wish_magnitude <= 0.001:
		_wish_direction = Vector3.ZERO
		_wish_magnitude = 0.0
		return

	var basis := _camera_basis()
	var forward := -basis.z
	_wish_direction = (basis.x * move.x + forward * move.y).normalized()


## Horizontal right / up / backward basis taken from the active camera. Falls
## back to identity so the player still moves if no camera exists.
func _camera_basis() -> Basis:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Basis.IDENTITY

	var back := camera.global_transform.basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		return Basis.IDENTITY
	back = back.normalized()

	var right := Vector3.UP.cross(back).normalized()
	return Basis(right, Vector3.UP, back)


# --- Dodge ------------------------------------------------------------------

## Consume the dodge press and start an evasion.
##
## WHICH evasion is decided here, because this is what owns input and facing:
##
##   movement input held -> DIRECTIONAL dodge, in the direction being asked for
##   no movement input   -> neutral BACKSTEP, backward along the actor's facing
##
## The direction is never re-aimed at an enemy or at a lock-on target. Whatever
## the player pressed is what the body does, which is what makes a lateral dodge
## a lateral dodge instead of an accidental lunge forward.
##
## The component owns every refusal (already dodging, attacking, unaffordable,
## unusable direction) and counts each cause, so nothing here has to decide what
## a refusal means.
func _read_dodge() -> void:
	var dodge := _get_dodge()
	if dodge == null:
		return
	var input := _get_input()
	if input == null:
		return
	if not input.consume_dodge():
		return
	if _wish_direction.length_squared() > 0.0001:
		dodge.try_start(_wish_direction, DodgeComponent.Kind.DIRECTIONAL,
			_facing_of(_wish_direction))
		return
	dodge.try_start(_backstep_direction(), DodgeComponent.Kind.BACKSTEP,
		DodgeComponent.Facing.BACKWARD)


## Straight backward along the body's own facing axis. Godot's convention is that
## -basis.z is world forward, so +basis.z is backward. This is the actor's facing,
## not a world-space offset and not a reversal of some previous dodge.
func _backstep_direction() -> Vector3:
	var back := global_transform.basis.z
	back.y = 0.0
	if back.length_squared() < 0.0001:
		return Vector3.BACK
	return back.normalized()


## Which way a locked direction lies relative to the CAMERA, resolved once when
## the evasion starts so the value cannot drift while it runs.
##
## Camera-relative rather than body-relative on purpose: the body turns to chase
## its own movement, so classifying against the body would collapse a sustained
## left-strafe into "FORWARD" the moment the body caught up. Against the camera
## the answer is stable and matches the input the player actually gave:
##
##   W -> FORWARD   S -> BACKWARD   A -> LEFT   D -> RIGHT
##
## When lock-on arrives, the lock-on basis replaces the camera basis HERE and
## nothing else has to change - which is exactly why the classification lives at
## this seam rather than inside the dodge component.
func _facing_of(direction: Vector3) -> int:
	var basis := _camera_basis()
	var along := direction.dot(-basis.z)
	var side := direction.dot(basis.x)
	if absf(along) >= absf(side):
		return DodgeComponent.Facing.FORWARD if along >= 0.0 else DodgeComponent.Facing.BACKWARD
	return DodgeComponent.Facing.RIGHT if side >= 0.0 else DodgeComponent.Facing.LEFT


# --- Parry ------------------------------------------------------------------

## Consume the parry press and start a parry.
##
## No direction is passed, and that is the point: a parry is stationary. The parry
## component owns every refusal (already parrying, attacking, dodging,
## unaffordable) and counts each cause, so nothing here decides what a refusal means.
func _read_parry() -> void:
	var parry := _get_parry()
	if parry == null:
		return
	var input := _get_input()
	if input == null:
		return
	if not input.consume_parry():
		return
	parry.try_start()


# --- Physics ----------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	velocity.y = maxf(velocity.y - gravity * gravity_scale * delta, -max_fall_speed)


func _apply_horizontal(delta: float) -> void:
	# A dodge owns horizontal movement outright for its whole duration. The
	# velocity is SET, not blended, so the burst is exactly speed x duration and
	# cannot be steered, slowed or accelerated out of by holding a direction.
	var dodge := _get_dodge()
	if dodge != null and dodge.is_dodging():
		var burst := dodge.velocity()
		velocity.x = burst.x
		velocity.z = burst.z
		return

	var target := _wish_direction * _target_speed() * _wish_magnitude
	var current := Vector3(velocity.x, 0.0, velocity.z)

	var rate := acceleration if _wish_direction != Vector3.ZERO else deceleration
	if not is_on_floor():
		rate *= air_control

	current = current.move_toward(target, rate * delta)
	velocity.x = current.x
	velocity.z = current.z


func _target_speed() -> float:
	if _can_sprint():
		return sprint_speed
	return move_speed


## Sprinting needs the input, a direction, and stamina left in the pool. An actor
## with no StaminaComponent is never gated, so a scene without one still sprints.
func _can_sprint() -> bool:
	var input := _get_input()
	if input == null or not input.is_sprinting() or _wish_direction == Vector3.ZERO:
		return false
	var stamina := _get_stamina()
	if stamina == null:
		return true
	return stamina.current_stamina > 0.0


## Whether this actor is SPRINTING right now, as gameplay state rather than as a raw input read.
##
## A read-only accessor over the exact rule locomotion itself uses, so the shared actor contract
## (ActorState) can report sprint from its OWNER instead of re-deriving it from speed or reading
## input behind this controller's back. It owns nothing, decides nothing and changes nothing: the
## answer is the same one that already decides the body's speed this frame.
##
## Deliberately NOT a new authority. Holding sprint while standing still is not sprinting, because
## this controller only sprints while it has a direction to sprint in - and this reports that same
## fact rather than a second opinion about it.
func is_sprinting() -> bool:
	return _can_sprint()


## Drain while actually sprinting. When the pool empties, _can_sprint() starts
## returning false, so the speed falls back to move_speed on its own - there is
## no separate "exhausted" state to keep in sync.
func _update_stamina(delta: float) -> void:
	if not _can_sprint():
		return
	var stamina := _get_stamina()
	if stamina != null:
		stamina.drain(sprint_stamina_per_second * delta)


## Rotate the body toward its own horizontal velocity. Using velocity rather than
## the raw wish direction means the body keeps facing its travel direction while
## decelerating, instead of snapping around the moment the stick is released.
func _apply_facing(delta: float) -> void:
	# A committed evasion owns the body's orientation for its whole duration. The
	# velocity during an evasion IS the evasion burst, so deriving yaw from it turns
	# the body around mid-backstep and swings it toward a lateral dodge. The locked
	# gameplay facing is restored instead, and the facing is NOT re-derived here:
	# body orientation during a committed evasion belongs to the locked facing.
	if _is_evading():
		rotation.y = _locked_yaw
		return
	# While a target is locked and NO committed action owns the body, the body faces
	# the locked target (Milestone 13 - the tweak carried over from the Milestone 12
	# playtest). This branch sits BELOW the evasion branch on purpose: a committed
	# action's facing outranks the lock, and this line is never reached while one is
	# running. The yaw itself was resolved at the top of the step by
	# _sync_lock_orientation(), so there is exactly one place that decides it.
	if _is_locked_on():
		rotation.y = _locked_yaw
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if horizontal.length_squared() < 0.01:
		return
	var target_yaw := atan2(-horizontal.x, -horizontal.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, deg_to_rad(turn_speed_degrees) * delta)


## True while a committed evasion owns the body's movement and orientation.
## DodgeComponent is the single authority; a scene without one is never evading.
func _is_evading() -> bool:
	var dodge := _get_dodge()
	return dodge != null and dodge.is_dodging()


## Keep the committed-evasion contract honest, at the TOP of the physics step before
## anything else in the frame can move or re-orient the body.
##
## Two things happen here, and both are about an evasion owning the body for exactly
## its own duration and not one frame longer:
##
##   1. The facing yardstick. While no evasion owns the body, the lock tracks the yaw
##      the actor authored for itself; once an evasion IS active the lock is frozen,
##      so the locked gameplay facing survives the evasion instead of being
##      re-derived from the evasion's own velocity.
##   2. The end-of-evasion handoff. The evasion owns its displacement for its whole
##      duration, so the burst velocity it authored must not outlive it. Left on the
##      body, that velocity keeps driving BOTH the slide and - because ordinary
##      facing follows the body's travel direction - the body's orientation. After a
##      backstep it points the wrong way, so the actor would visibly turn around
##      after an evasion that is already over and already paid for.
func _sync_evasion_authority() -> void:
	# A dead actor authors no orientation, so nothing here may hand one back while the body belongs to
	# the death state. Without this, the reconcile below would stamp the dead actor's current yaw back
	# over the transform the death circuit is restoring, and a respawned player would face wherever it
	# happened to fall rather than the facing its own reset authored.
	if _is_dead():
		return
	if _is_evading():
		_was_dodging = true
		return
	if _was_dodging:
		_was_dodging = false
		velocity.x = 0.0
		velocity.z = 0.0
	_locked_yaw = rotation.y


## Milestone 13 - the facing yardstick while a target is locked, integrated with the project's
## MOVEMENT AUTHORITY rule rather than layered on top of it.
##
## While a lock is held AND no committed action owns the body, the body faces what it is locked onto.
## The facing is written through `_locked_yaw` - the SAME yardstick a committed evasion already holds
## - so there is one facing contract in this file and not a second rotation path that could disagree
## with the first.
##
## A COMMITTED action (dodge, backstep, attack, parry) is never re-oriented by the lock. That is the
## whole reason this function returns immediately while `_is_committed()` is true: the yardstick then
## keeps the yaw it had when the action began, which is the lock-facing the body already held. This
## uses the project's EXISTING commitment arbitration as its definition of "an action owns the body";
## a lock must not invent a second one.
##
## Order matters and is deliberate: `_is_committed()` is checked before anything else, because the
## general refusal is the honest one. A committed action owns its facing; a dodge is committed; the
## dodge-specific check in `_sync_evasion_authority()` handles the end-of-evasion handoff.
##
## With NO lock - or with no targeting module in the scene - this returns immediately and `_locked_yaw`
## goes on being exactly what it was before this milestone: the yaw this controller authored for
## itself. Nothing about ordinary locomotion changes.
func _sync_lock_orientation() -> void:
	if _is_committed():
		return
	var target := _get_lock_target()
	if target == null:
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		# Directly overhead: there is no horizontal direction to face, so the current facing stands
		# rather than snapping to a value derived from a zero-length vector.
		return
	# Godot's convention is that -basis.z is world forward, matching _apply_facing()'s own formula.
	_locked_yaw = atan2(-to_target.x, -to_target.z)


## Climb ledges no taller than max_step_height. CharacterBody3D does not climb
## steps on its own, so the rise is resolved explicitly here.
##
## This runs ONLY on a frame whose move was genuinely obstructed, and that is what
## separates a step face from a walkable slope. On the 20 degree ramp the body
## keeps nearly all of its intended horizontal travel - it simply also rises - so
## nothing is corrected and the ramp is climbed by ordinary sliding. On a step
## face the body achieves almost none of it.
##
## Two earlier gates were wrong; both are recorded so they are not reintroduced.
## Gating on is_on_wall() never opened: measured on this project, move_and_slide()
## reports zero slide collisions and is_on_wall() stays false on every frame the
## body travels at full speed toward a step. Gating on a forward test_move() alone
## fired on every single frame of the ramp - a slope rises into a horizontal
## probe, so it read as an obstacle - which teleported the body 0.48 m forward per
## frame and launched the player up the ramp.
func _resolve_step_up(before: Vector3, intended: Vector3) -> void:
	# A committed evasion owns its own displacement, and a step-up correction is
	# sized by the probe reach rather than by the evasion's authored travel. Running
	# it during an evasion would add displacement the evasion never asked for, so the
	# correction stands down and the evasion keeps exactly the travel it authored.
	if _is_evading():
		return
	if not is_on_floor():
		return

	var intended_length := intended.length()
	if intended_length < 0.0001:
		return

	var achieved := global_position - before
	var achieved_length := Vector3(achieved.x, 0.0, achieved.z).length()
	if achieved_length >= intended_length * blocked_travel_ratio:
		return

	var direction := intended / intended_length
	var reach := _capsule_radius() * step_probe_reach

	# Confirm something is really in the way ahead before moving.
	if not test_move(global_transform, direction * reach):
		return

	var rise := Vector3.UP * max_step_height

	# Is there headroom to rise at all?
	if test_move(global_transform, rise):
		return

	# Having risen, is the space ahead actually free? A real wall still blocks.
	var raised := global_transform.translated(rise)
	if test_move(raised, direction * reach):
		return

	# Move forward as well as up. Rising alone is not enough: a capsule touches a
	# step edge roughly one radius short of the edge itself, so a single frame of
	# walking speed (a few centimetres) leaves the body still hanging over the
	# floor it came from, and the settle below then drops it straight back down.
	# Translating by the probe reach puts the capsule over the new surface, which
	# both the rise check and this move have already proven clear.
	global_position = raised.origin + direction * reach
	velocity.y = 0.0
	move_and_slide()
	_settle_after_step()


## A step-up leaves the body a full max_step_height above whatever it climbed.
## Walk it back down onto that surface inside the same physics frame, so a low
## step reads as a step and not a hop. Without this the player rises a fixed
## 0.5 m and then drops onto a 14 cm step over the following frames.
func _settle_after_step() -> void:
	var probe := 0.02
	var dropped := 0.0
	while dropped < max_step_height:
		var from := global_transform.translated(Vector3(0.0, -dropped, 0.0))
		if test_move(from, Vector3(0.0, -probe, 0.0)):
			break
		dropped += probe
	if dropped > 0.0:
		global_position.y -= dropped


func _capsule_radius() -> float:
	for child in get_children():
		if child is CollisionShape3D:
			var capsule := (child as CollisionShape3D).shape as CapsuleShape3D
			if capsule != null:
				return capsule.radius
	return 0.4


func _check_fall_recovery() -> void:
	if global_position.y >= respawn_below_y:
		return
	global_position = _spawn_position
	rotation.y = _spawn_yaw
	# The respawn authors a new facing, so the yardstick moves with it. Without this
	# the next evasion would hold the pre-fall yaw instead of the spawn yaw.
	_locked_yaw = _spawn_yaw
	velocity = Vector3.ZERO


# --- Input layer access -----------------------------------------------------

func _get_input() -> CascadiaInput:
	if _input == null or not is_instance_valid(_input):
		_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	return _input


# --- Combat commitment ------------------------------------------------------

## True while the actor is committed to an attack or a dodge and must not accept
## movement input. A missing component simply means never committed, so a scene
## without PlayerCombat or DodgeComponent still moves normally.
func _is_committed() -> bool:
	var combat := _get_combat()
	if combat != null and combat.is_busy():
		return true
	var dodge := _get_dodge()
	if dodge != null and dodge.is_dodging():
		return true
	var parry := _get_parry()
	return parry != null and parry.is_parrying()


func _get_stamina() -> StaminaComponent:
	if _stamina == null or not is_instance_valid(_stamina):
		if String(stamina_path).is_empty():
			return null
		_stamina = get_node_or_null(stamina_path) as StaminaComponent
	return _stamina


func _get_combat() -> PlayerCombat:
	if _combat == null or not is_instance_valid(_combat):
		if String(combat_path).is_empty():
			return null
		_combat = get_node_or_null(combat_path) as PlayerCombat
	return _combat


# --- Mobility access --------------------------------------------------------

## The actor's dodge, or null when there is none. A missing dodge means "cannot
## dodge" rather than an error, so a scene without the node keeps working.
func _get_dodge() -> DodgeComponent:
	if _dodge == null or not is_instance_valid(_dodge):
		if String(dodge_path).is_empty():
			return null
		_dodge = get_node_or_null(dodge_path) as DodgeComponent
	return _dodge


## The actor's parry, or null when there is none. A missing parry means "cannot
## parry" rather than an error, so a scene without the node keeps working.
func _get_parry() -> ParryComponent:
	if _parry == null or not is_instance_valid(_parry):
		if String(parry_path).is_empty():
			return null
		_parry = get_node_or_null(parry_path) as ParryComponent
	return _parry


# --- Lock-on access (Milestone 13) ------------------------------------------

## The actor currently locked by the targeting module, or null when no lock is held. Read through the
## module's own query, so this is the module's state and never a copy of it. A scene with no targeting
## module answers null, and the controller then behaves exactly as it did before this milestone.
func _get_lock_target() -> Node3D:
	var targeting := _get_targeting()
	if targeting == null or not targeting.is_locked():
		return null
	return targeting.get_current_target()


## Whether a usable locked target exists right now.
func _is_locked_on() -> bool:
	return _get_lock_target() != null


func _get_targeting() -> TargetingComponent:
	if _targeting == null or not is_instance_valid(_targeting):
		var tree := get_tree()
		if tree == null:
			return null
		_targeting = tree.get_first_node_in_group(TargetingComponent.GROUP_TARGETING) as TargetingComponent
	return _targeting


# --- Death access -----------------------------------------------------------

## The actor's death circuit, or null when there is none. Read-only: the
## controller only ever asks whether the actor is dead, so a scene without a
## DeathComponent keeps its previous movement behaviour exactly.
func _get_death() -> DeathComponent:
	if _death == null or not is_instance_valid(_death):
		if String(death_path).is_empty():
			return null
		_death = get_node_or_null(death_path) as DeathComponent
	return _death


## True while the actor is dead and must take no input at all.
func _is_dead() -> bool:
	var death := _get_death()
	return death != null and death.is_dead()
