class_name HurtboxComponent
extends Area3D
## A volume that can receive damage (Milestone 2).
##
## Deliberately separate from the actor's physical collision: this Area3D sits
## on GameLayers.HURTBOX and nothing else, so it can never push a body around
## and a body can never block a hit.
##
## The hurtbox decides nothing. It finds its HealthComponent and hands the event
## over. Whether the damage lands is entirely the health component's call, which
## is why receive_hit() forwards that answer rather than assuming success.

## Emitted when a hit was refused because the actor was inside an i-frame window.
signal damage_refused_by_iframes(event: DamageEvent)

## Emitted when a hit was refused because the actor's parry window was open. Kept
## separate from the i-frame signal so a parried hit and a dodged hit are never
## conflated: they are different defensive outcomes with different causes.
signal damage_refused_by_parry(event: DamageEvent)

## The actor this hurtbox belongs to. Defaults to the parent body.
@export var actor_path: NodePath
## The HealthComponent that receives damage. Defaults to a sibling named
## "Health" under the owning actor.
@export var health_path: NodePath
## The component that knows whether the actor is currently invulnerable - the
## actor's dodge (Milestone 6). Defaults to a sibling named "Dodge". An empty
## path, or an actor with no dodge, simply never refuses damage this way, so an
## actor without one keeps its previous behaviour exactly.
@export var invulnerable_path: NodePath = NodePath("../Dodge")
## The component that knows whether the actor's parry window is open (Milestone 7).
## Defaults to a sibling named "Parry". An empty path, or an actor with no parry,
## simply never refuses damage this way.
@export var parry_path: NodePath = NodePath("../Parry")
## Whether this actor can be damaged at all.
##
## true  - the configured DEFAULT, so every existing actor behaves exactly as before
##         and a hit reaches the HealthComponent with nothing added in front of it.
## false - NON-DAMAGEABLE: receive_hit() refuses every hit HERE, before health and
##         before any defensive window, and counts the refusal as a policy refusal.
##         This is the damageable / non-damageable axis made explicit and per-actor,
##         instead of being implied by the accidental absence of a HealthComponent
##         (a misconfiguration, which is still warned about separately).
##
## This is NOT invulnerability. An i-frame window or a parry window is a TIMED
## refusal owned by the dodge or the parry; this is a permanent statement about the
## actor that no amount of attack timing can open.
@export var damageable := true

## Resolved HealthComponent, or null when the hurtbox is misconfigured.
var health: HealthComponent
## Resolved owning actor. Used to stop an attack hitting its own source.
var actor: Node
## Resolved invulnerability source (the actor's dodge), or null when there is
## none. Read-only: the hurtbox only ever asks whether the actor is invulnerable.
var invulnerability_source: Node
## How many hits were refused by an open i-frame window. Diagnostic: this is what
## makes "a dodged hit was refused" checkable rather than inferred from health
## that merely failed to move.
var refusals_by_iframes := 0
## Resolved parry source, or null when there is none. Read-only, the same way the
## dodge source is.
var parry_source: Node
## How many hits were refused by an open parry window. Counted separately from
## refusals_by_iframes so the two outcomes stay distinguishable.
var refusals_by_parry := 0
## How many hits were refused because the actor is configured non-damageable
## (damageable = false). Counted separately from both timed refusals, so a permanent
## policy refusal can never be mistaken for a dodged or a parried hit.
var refusals_by_policy := 0


func _ready() -> void:
	# Layer assignment lives here so the layers have exactly one source of truth.
	collision_layer = GameLayers.HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true
	_resolve()


func _resolve() -> void:
	if String(actor_path).is_empty():
		actor = get_parent()
	else:
		actor = get_node_or_null(actor_path)

	if String(health_path).is_empty():
		if actor != null:
			health = actor.get_node_or_null("Health") as HealthComponent
	else:
		health = get_node_or_null(health_path) as HealthComponent

	if health == null:
		push_warning("HurtboxComponent %s: no HealthComponent found." % name)

	if String(invulnerable_path).is_empty():
		invulnerability_source = null
	else:
		invulnerability_source = get_node_or_null(invulnerable_path)

	if String(parry_path).is_empty():
		parry_source = null
	else:
		parry_source = get_node_or_null(parry_path)


## Called by a HitboxComponent. Returns whether the damage actually applied.
##
## An open i-frame window refuses the hit HERE, before health is consulted, so a
## dodged hit is refused for the right reason and is counted as such instead of
## looking like a hit that quietly failed to move health.
##
## The check is duck-typed rather than typed against DodgeComponent so the hurtbox
## does not depend on the dodge system: any invulnerability source that answers
## is_invulnerable() works.
func receive_hit(event: DamageEvent) -> bool:
	# The permanent damageability policy is checked FIRST, before any timed window. A
	# non-damageable actor refuses for a reason that has nothing to do with i-frames or
	# parry, so the refusal must not be counted as either.
	if not damageable:
		refusals_by_policy += 1
		return false
	# A parry window is checked first and is counted as a PARRY. The two are mutually
	# exclusive commitments, so at most one of these gates can ever be open - the
	# order is not load-bearing, but the separate counters are what make the two
	# defensive outcomes tellable apart afterwards.
	if is_parry_window_open():
		refusals_by_parry += 1
		damage_refused_by_parry.emit(event)
		return false
	if is_invulnerable():
		refusals_by_iframes += 1
		damage_refused_by_iframes.emit(event)
		return false
	if health == null:
		return false
	return health.apply_damage(event)


## Whether this actor accepts damage at all. The PERMANENT policy, deliberately
## separate from the timed refusals below: an actor authored non-damageable reports
## false here for its entire life, however well timed an attack is.
func is_damageable() -> bool:
	return damageable


## True while the actor is inside an i-frame window. False when there is no
## invulnerability source at all.
func is_invulnerable() -> bool:
	return _query_flag(invulnerability_source, &"is_invulnerable")


## True while the actor's parry window is open. False when there is no parry source.
func is_parry_window_open() -> bool:
	return _query_flag(parry_source, &"is_parry_window_open")


## Ask a duck-typed source for a boolean. Kept duck-typed so the hurtbox depends on
## neither the dodge nor the parry system - any source answering the named method
## works, and a missing source is simply false.
func _query_flag(source: Node, method: StringName) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	if not source.has_method(method):
		return false
	return bool(source.call(method))
