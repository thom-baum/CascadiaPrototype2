class_name HealthReactionComponent
extends Node
## One actor's HIT REACTION (Milestone 15 - shared combatant foundation).
##
## WHY THIS EXISTS. Cascadia could already damage an actor and could already DEFEAT one, but
## it had no answer to the question in between: "this actor was just hit - is it still doing
## what it was doing?" Every actor needs that answer, and the future animation adapter needs
## it most, because a hit that does not interrupt still has to PLAY as a hit. This is the
## smallest honest version of that answer: a hit is always FELT, and a big enough hit
## INTERRUPTS.
##
## WHAT IT OWNS: two timers, and the classification of an incoming DamageEvent against one
## threshold. Nothing else. It holds no health, applies no damage, starts no attack and moves
## nothing.
##
## WHAT IT DELIBERATELY DOES NOT DO.
##
##   - It does not cancel a committed action, stop a movement or knock a body back. Whether a
##     committed ATTACK survives a hit is an interrupt-armor decision that belongs to the
##     actor's own action state machine, not to a reaction timer, and Cascadia has no poise,
##     no hitstun and no knockback system yet. Building them here would have been a second
##     authority over an actor's action - the exact duplication this pass exists to remove.
##   - It does not stack, and it does not retune itself mid-flinch.
##   - It is NOT balance. `stagger_threshold` defaults to 0.0, which means NO hit ever
##     staggers: the default is deliberately inert, so WIRING THIS COMPONENT CANNOT CHANGE HOW
##     ANY ACTOR BEHAVES until a real threshold is authored for that actor. A hit still moves
##     health and nothing else, which is what every actor in the project does today.
##
## NOT AGGRO. "Reacting" and "staggered" are LOCAL, TIMED facts about this actor's own body.
## They are not an opinion about who its enemy is, and nothing in the project asks them that.
##
## Attach one per actor, as a direct child of the body, named "Reaction". An actor without one
## simply never reacts - which is how every actor in the project behaved before it existed.

## Emitted once when a hit is FELT: the actor begins reacting.
signal reaction_started(amount: float)

## Emitted once when a hit reaches the stagger threshold.
signal staggered(amount: float)

## Deliberately NO group constant here. `ActorState` owns the `actor_state` group and is the
## only node that joins it, so enumerating that group yields exactly one state node per actor.
## This component joining it too would have put a second, non-state node in a group whose whole
## contract is "one state node per actor".
@export_group("Wiring")
## The HealthComponent whose damage is reacted to. Defaults to a sibling named "Health".
@export var health_path: NodePath = NodePath("../Health")

@export_group("Reaction")
## Seconds of FLINCH after any hit at all. Purely presentational state: a flinch does not
## stop this actor from acting, moving or attacking, because nothing in Cascadia consumes it
## as an interruption yet.
@export var reaction_seconds := 0.30
## Seconds of STAGGER after a hit at or above `stagger_threshold`. Longer than a flinch on
## purpose: a stagger is the interrupted state, a flinch is only the acknowledgement.
@export var stagger_seconds := 0.60
## Damage at or above which a hit staggers instead of merely being felt. 0.0 means NO hit
## staggers, which is the default and the pre-existing behaviour.
@export var stagger_threshold := 0.0

## Print each reaction. Diagnostic.
@export var debug_logging := false

## Hits felt since load.
var reactions := 0
## Hits that reached the stagger threshold, counted separately from the flinches so "it was
## hit" and "it was interrupted" can never blur into one number.
var staggers := 0

var _health: HealthComponent
## Seconds left of the current flinch.
var _react_left := 0.0
## Seconds left of the current stagger. Always <= _react_left while both are running, because
## a stagger sets both.
var _stagger_left := 0.0


func _ready() -> void:
	_health = _get_health()
	if _health == null:
		push_warning("HealthReactionComponent %s: no HealthComponent found; this actor can never react." % name)
		return
	# The actor's own damage report is the ONLY input to this component. Nothing here watches
	# a hitbox, re-derives damage from a health difference, or hears about an attacker.
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	_react_left = maxf(0.0, _react_left - delta)
	_stagger_left = maxf(0.0, _stagger_left - delta)


# --- Queries -----------------------------------------------------------------

## Whether this actor is feeling a hit right now, flinch or stagger.
func is_reacting() -> bool:
	return _stagger_left > 0.0 or _react_left > 0.0


## Whether this actor was INTERRUPTED by a hit, as opposed to merely acknowledging one.
func is_staggered() -> bool:
	return _stagger_left > 0.0


## Seconds left of the current reaction, whichever kind is running.
func remaining() -> float:
	return maxf(_react_left, _stagger_left)


## The current reaction in one word: "none", "stagger" or "hurt". A WORD rather than a bare
## boolean, so a debug readout and an animation adapter can tell an interruption from an
## acknowledgement without asking two questions.
func reaction_name() -> String:
	if is_staggered():
		return "stagger"
	if is_reacting():
		return "hurt"
	return "none"


## Whether a hit of `amount` would stagger this actor.
func would_stagger(amount: float) -> bool:
	return stagger_threshold > 0.0 and amount >= stagger_threshold


## Put the reaction state back to none. Called by the arena reset path through the same
## convention every other component uses; safe to call at any time.
func reset() -> void:
	_react_left = 0.0
	_stagger_left = 0.0


# --- Reaction ----------------------------------------------------------------

## One hit was applied to this actor. `reaction_seconds` always starts; `stagger_seconds`
## starts INSTEAD of it when the hit reaches the threshold.
##
## A stagger REPLACES the flinch rather than adding to it, so the two timers can never
## disagree about which state the actor is in, and the shorter flinch can never outlive the
## longer stagger and report "still flinching" after the interruption has ended.
func _on_damaged(event: DamageEvent, _current: float, _maximum: float) -> void:
	var amount := event.amount if event != null else 0.0
	if would_stagger(amount):
		_stagger_left = stagger_seconds
		_react_left = stagger_seconds
		staggers += 1
		_log("staggered by %.1f (threshold %.1f, %.2fs)" % [amount, stagger_threshold, stagger_seconds])
		staggered.emit(amount)
		return
	_react_left = reaction_seconds
	reactions += 1
	_log("felt %.1f (%.2fs)" % [amount, reaction_seconds])
	reaction_started.emit(amount)


## A corpse does not flinch. Cleared rather than left to expire, so a lethal hit can never
## leave an actor reporting a live reaction state while it is dead.
func _on_died(_event: DamageEvent) -> void:
	reset()


# --- Resolution --------------------------------------------------------------

func _get_health() -> HealthComponent:
	if _health == null or not is_instance_valid(_health):
		if String(health_path).is_empty():
			return null
		_health = get_node_or_null(health_path) as HealthComponent
	return _health


func _log(message: String) -> void:
	if debug_logging:
		print("[REACTION] %s: %s" % [name, message])
