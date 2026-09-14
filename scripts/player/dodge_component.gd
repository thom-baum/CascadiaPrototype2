class_name DodgeComponent
extends Node
## One actor's dodge (Milestone 6).
##
## A committed, short, grounded burst of movement with a window in the middle
## where incoming damage is refused. It owns the dodge and nothing else: it does
## not read input, it does not move the body, and it does not know what an
## animation, a roll or a root motion is.
##
## Who does what:
##
##   DodgeComponent   owns the dodge's state, its timing, its direction lock,
##                    its i-frame window and the stamina it costs.
##   PlayerController reads the dodge input, chooses the direction, and applies
##                    the dodge's velocity to the body through move_and_slide().
##   PlayerCombat     refuses to start an attack while a dodge is committed.
##   HurtboxComponent refuses damage while the actor reports invulnerable.
##
## The dodge is GAMEPLAY timing, exactly like an attack. There is no animation,
## no root motion and no curve: speed x duration is the whole of the travel, and
## animation adapts to it later (Milestone 15).
##
## Commitment is structural, the same way attack commitment is. A dodge can only
## begin from a valid state (not dodging, not attacking, direction known,
## affordable), and once started there is no path out of it except letting it
## finish. It cannot be steered: the direction is locked at the moment it starts
## and is never re-read while it runs.
##
## i-frames are a WINDOW WITHIN the dodge, not the whole of it, so a dodge is not
## free invulnerability: late in the dodge the actor is vulnerable again, while
## still committed and still moving.
##
## Attach one per actor, as a direct child of the body, named "Dodge" so a
## consumer can find it without an explicit path. An actor with no
## DodgeComponent simply cannot dodge - every consumer treats a missing dodge as
## "not dodging" and "not invulnerable", so scenes without one keep working.

## Emitted once when a dodge is actually accepted.
signal dodge_started(direction: Vector3)

## Emitted once when a dodge completes on its own.
signal dodge_finished()

## Emitted when a dodge is refused ONLY because stamina was insufficient. The
## dodge does not start, is not queued, and costs nothing.
signal dodge_refused_by_stamina(cost: float)

## What kind of evasion this is. A dodge aimed by movement input is DIRECTIONAL;
## a neutral press with no movement input is a BACKSTEP, which travels backward
## along the actor's facing and covers less ground.
enum Kind { DIRECTIONAL, BACKSTEP }

## Which way the locked direction lies relative to the view the player was
## steering by (today the camera, later a lock-on target) at the moment the
## evasion started. Semantic and view-independent: a future animation adapter
## selects a clip from THIS value rather than re-deriving it from a raw vector,
## which is what stops every dodge from playing as one generic forward roll.
enum Facing { FORWARD, BACKWARD, LEFT, RIGHT }

@export_group("Dodge")
## Ground speed of the dodge burst, in metres per second.
## HALVED from 7.5 so the dodge covers about half its former ground. The duration
## is deliberately NOT what got shortened: the i-frame window is expressed in
## absolute seconds inside the dodge, so cutting the duration would have moved the
## window and weakened the defence.
@export var dodge_speed := 3.75
## How long a dodge lasts, in seconds. Once started it cannot be shortened.
@export var dodge_duration := 0.45

@export_group("Backstep")
## Ground speed of the neutral backstep. Slower than a dodge on purpose: a
## backstep is a compact reposition, not a roll.
@export var backstep_speed := 3.2
## How long a backstep lasts, in seconds.
@export var backstep_duration := 0.40

@export_group("I-Frames")
## Seconds into the dodge before damage starts being refused.
@export var iframes_start := 0.05
## Seconds into the dodge after which damage lands normally again. Deliberately
## shorter than dodge_duration: the tail of a dodge is vulnerable.
@export var iframes_end := 0.30

@export_group("Stamina")
## Stamina charged when a dodge is accepted. Charged by THIS component, not by
## the hurtbox: the cost belongs to the decision to dodge. An actor with no
## StaminaComponent is never charged and never refused.
@export var stamina_cost := 22.0
## The actor's stamina pool. Defaults to a sibling named "Stamina" on the owner.
@export var stamina_path: NodePath = NodePath("../Stamina")

@export_group("Commitment")
## The actor's attack state machine. A dodge is refused while an attack is
## committed, so an attack cannot be cancelled into a dodge. Defaults to a
## sibling named "Combat"; an actor without one simply never blocks a dodge.
@export var combat_path: NodePath = NodePath("../Combat")

## The actor's parry. A dodge is refused while a parry is committed (Milestone 7),
## so a parry cannot be cancelled into a dodge. Defaults to a sibling named
## "Parry"; an actor without one simply never blocks a dodge.
@export var parry_path: NodePath = NodePath("../Parry")

## Print each phase transition and each refusal. Diagnostic.
@export var debug_logging := false

var _active := false
## Seconds spent in the current evasion.
var _elapsed := 0.0
## Locked at the moment the evasion started. Never re-read while it runs.
var _direction := Vector3.ZERO
## Which kind of evasion is running. Locked at start and exposed afterwards, so a
## consumer never has to infer it from a direction vector.
var _kind: int = Kind.DIRECTIONAL
## The locked direction's relationship to the view, locked at start.
var _facing: int = Facing.FORWARD
## Resolved from the kind at start. speed x duration is the whole of the travel.
var _speed := 0.0
var _duration := 0.0

## Dodges accepted since load.
var dodges_started := 0
## Dodges refused because stamina was insufficient. Diagnostic: this is what makes
## "an unaffordable dodge was refused" checkable, rather than looking identical to
## a dodge that was silently dropped.
var dodges_refused_by_stamina := 0
## Dodges refused because an attack was already committed. Counted separately
## from the stamina refusal so the two causes are never confused.
var dodges_refused_while_attacking := 0
## Dodges refused because the direction was unusable.
var dodges_refused_invalid_direction := 0
## Dodges refused because one was already running.
var dodges_refused_while_dodging := 0
## Dodges refused because a parry was already committed. Counted separately again,
## so the causes never collapse into one another.
var dodges_refused_while_parrying := 0

## Every dodge joins this group, so tooling can enumerate them.
const GROUP_DODGE := &"dodge"

var _stamina: StaminaComponent
var _combat: PlayerCombat
var _parry: ParryComponent


func _ready() -> void:
	add_to_group(GROUP_DODGE)
	# Advance BEFORE PlayerCombat (-1) and before PlayerController (0), so both
	# read this frame's dodge state rather than last frame's. Same reason
	# PlayerCombat runs before the controller: a commit must take effect on the
	# frame it starts, not one frame later.
	process_physics_priority = -2


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if _elapsed >= _duration:
		_finish()


# --- Queries ----------------------------------------------------------------

## True while a dodge is committed. Both PlayerController (movement) and
## PlayerCombat (attack refusal) read this.
func is_dodging() -> bool:
	return _active


## True only while the i-frame window is open. The hurtbox reads this to refuse
## damage.
func is_invulnerable() -> bool:
	if not _active:
		return false
	return _elapsed >= iframes_start and _elapsed < iframes_end


## The velocity this evasion wants applied to the body. Zero when not active.
## Uses the speed resolved from the kind at start, so a backstep really is slower
## rather than silently inheriting the dodge's burst.
func velocity() -> Vector3:
	if not _active:
		return Vector3.ZERO
	return _direction * _speed


## The locked direction. Zero when not dodging.
func direction() -> Vector3:
	return _direction


## Seconds left in the current evasion, or 0 while idle.
func remaining() -> float:
	if not _active:
		return 0.0
	return maxf(0.0, _duration - _elapsed)


## Seconds left in the i-frame window, or 0 when it is closed.
func iframes_remaining() -> float:
	if not is_invulnerable():
		return 0.0
	return maxf(0.0, iframes_end - _elapsed)


## Total travel one full DIRECTIONAL dodge produces, in metres. speed x duration
## is the whole of it - there is no distance curve to keep in sync. The MEANING of
## this value is unchanged from Milestone 6; only its numbers moved, because dodge
## travel was halved.
func travel_distance() -> float:
	return dodge_speed * dodge_duration


## Total travel one full neutral backstep produces, in metres.
func backstep_travel_distance() -> float:
	return backstep_speed * backstep_duration


## True while a neutral backstep is running, false while idle or mid-dodge.
func is_backstep() -> bool:
	return _active and _kind == Kind.BACKSTEP


## "DIRECTIONAL" or "BACKSTEP". The gameplay value a consumer branches on instead
## of inferring the kind from a direction vector.
func kind_name() -> String:
	return "BACKSTEP" if _kind == Kind.BACKSTEP else "DIRECTIONAL"


## Which way the evasion travels relative to the view the player steered by:
## FORWARD / BACKWARD / LEFT / RIGHT. A backstep is always BACKWARD.
func facing_name() -> String:
	match _facing:
		Facing.BACKWARD:
			return "BACKWARD"
		Facing.LEFT:
			return "LEFT"
		Facing.RIGHT:
			return "RIGHT"
		_:
			return "FORWARD"


func state_name() -> String:
	return kind_name() if _active else "IDLE"


# --- Starting a dodge -------------------------------------------------------

## The only way an evasion begins. Refused unless the actor can genuinely dodge,
## and every refusal is counted by cause so a refusal is never mistaken for a
## dropped input.
##
## `kind` and `facing` are decided by the CALLER, because the caller is what owns
## input and facing: the controller knows whether a movement stick was held and
## which way the player was steering. This component owns the CONSEQUENCES - the
## speed, the duration, the cost and the i-frame window - and exposes the two
## semantic values afterwards for the animation adapter and for diagnostics.
func try_start(direction: Vector3, kind: int = Kind.DIRECTIONAL,
		facing: int = Facing.FORWARD) -> bool:
	if _active:
		dodges_refused_while_dodging += 1
		_log("refused: already dodging")
		return false

	# Flatten first: a dodge is grounded movement, so any pitch in the requested
	# direction is discarded rather than launching the body.
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		dodges_refused_invalid_direction += 1
		_log("refused: no usable direction")
		return false
	flat = flat.normalized()

	# An attack commits the body for its whole timeline and cannot be cancelled,
	# so an attack cannot be escaped by dodging out of it.
	var combat := _get_combat()
	if combat != null and combat.is_busy():
		dodges_refused_while_attacking += 1
		_log("refused: attack in progress")
		return false

	# A parry commits the body in place for its whole timeline, so a parry cannot be
	# escaped by dodging out of it.
	var parry := _get_parry()
	if parry != null and parry.is_parrying():
		dodges_refused_while_parrying += 1
		_log("refused: parry in progress")
		return false

	# Stamina is checked BEFORE anything is accepted, so an unaffordable dodge
	# leaves this component completely untouched: not started, not queued, and
	# nothing spent.
	var stamina := _get_stamina()
	if stamina != null and not stamina.has(stamina_cost):
		dodges_refused_by_stamina += 1
		_log("refused: stamina %.1f < %.1f" % [stamina.current_stamina, stamina_cost])
		dodge_refused_by_stamina.emit(stamina_cost)
		return false
	if stamina != null:
		stamina.try_spend(stamina_cost)

	_direction = flat
	_kind = kind
	# A backstep is BACKWARD by definition, so the kind decides the facing rather
	# than trusting a caller to pass both consistently. A caller that names only
	# the kind (a future enemy AI, an animation adapter, a diagnostic) would
	# otherwise store a BACKSTEP that reports FORWARD, and that contradiction is
	# what an animation adapter reads to choose a clip.
	_facing = Facing.BACKWARD if kind == Kind.BACKSTEP else facing
	_speed = backstep_speed if kind == Kind.BACKSTEP else dodge_speed
	_duration = backstep_duration if kind == Kind.BACKSTEP else dodge_duration
	_elapsed = 0.0
	_active = true
	dodges_started += 1
	_log("started, direction %s" % str(_direction))
	dodge_started.emit(_direction)
	return true


# --- Internals --------------------------------------------------------------

func _finish() -> void:
	_active = false
	_elapsed = 0.0
	_direction = Vector3.ZERO
	_speed = 0.0
	_duration = 0.0
	_log("finished (%s %s)" % [kind_name(), facing_name()])
	dodge_finished.emit()


## Clear any dodge in progress without emitting dodge_finished. For tests and
## scene setup only - gameplay never calls this. Counters are left alone so a
## probe can still read deltas across a run.
func reset() -> void:
	_active = false
	_elapsed = 0.0
	_direction = Vector3.ZERO
	_speed = 0.0
	_duration = 0.0
	_kind = Kind.DIRECTIONAL
	_facing = Facing.FORWARD


## The actor's stamina pool, or null when there is none. A missing pool means
## "never charged" rather than "cannot dodge", so an actor without stamina keeps
## its old behaviour exactly, and no scene breaks by omitting the node.
func _get_stamina() -> StaminaComponent:
	if _stamina == null or not is_instance_valid(_stamina):
		if String(stamina_path).is_empty():
			return null
		_stamina = get_node_or_null(stamina_path) as StaminaComponent
	return _stamina


## The actor's attack state machine, or null when there is none. Read-only: this
## component only asks whether an attack is committed.
func _get_combat() -> PlayerCombat:
	if _combat == null or not is_instance_valid(_combat):
		if String(combat_path).is_empty():
			return null
		_combat = get_node_or_null(combat_path) as PlayerCombat
	return _combat


## The actor's parry, or null when there is none. Read-only: this component only asks
## whether a parry is committed.
func _get_parry() -> ParryComponent:
	if _parry == null or not is_instance_valid(_parry):
		if String(parry_path).is_empty():
			return null
		_parry = get_node_or_null(parry_path) as ParryComponent
	return _parry


func _log(message: String) -> void:
	if debug_logging:
		print("[DODGE] %s: %s" % [name, message])
