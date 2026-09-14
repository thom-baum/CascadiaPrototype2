class_name CombatParticipant
extends Node
## One actor's answer to "am I a valid combat participant RIGHT NOW?" (Milestone 8K family).
##
## WHY THIS EXISTS. The death pass left every concept correct but SCATTERED:
## "alive" lived on HealthComponent, "damageable" on HurtboxComponent, "mortal" and
## "defeated" on EnemyDeathComponent, "can act" nowhere at all, and a TARGET was
## resolved by bare group membership - so a dead actor was still a legal target and
## the enemy would turn its body to face a corpse. Every consumer had to re-assemble
## the same four answers itself, which means every consumer could get it subtly wrong.
##
## This node does not replace or duplicate any of those components. It ASKS them and
## reports ONE answer, so a consumer never has to know where the pieces live.
##
## What it owns: the QUERY, and nothing else. It holds no health, applies no damage,
## starts no attack, and never mutates another actor's state.
##
## A MISSING CombatParticipant is NOT a refusal. Every static query below falls back
## to the same health-based answer the project used before this component existed, so
## an actor nobody has wired yet behaves exactly as it did. The component REFINES an
## answer where it is present; it never becomes a new gate.
##
## The distinctions are deliberately kept APART rather than collapsed into one flag:
##   damageable  - HurtboxComponent.damageable   (can a hit land at all)
##   mortal      - EnemyDeathComponent.mortal    (can this actor be defeated)
##   dead        - HealthComponent.is_dead       (has health reached zero)
##   defeated    - the defeat component's state  (is this actor out of the fight)
##   attack-capable - the actor has an attack component
##   targetable  - this component's own policy
##   resettable  - DeathComponent.resets_actors  (player-only; NOT queried here)
##   persistent  - NOTHING. Not implemented, not implied, not queried.
##
## Attach one per combat actor, as a direct child of the body, named "Participant".

## Why a node is NOT a usable combat target. A countable cause, so a consumer can
## record WHY it refused instead of lumping every refusal into one bucket.
enum Refusal {
	NONE,              ## usable right now
	MISSING,           ## no node, or the node is gone
	NOT_PARTICIPANT,   ## not a combat actor at all (no health, not a Node3D)
	DEAD,              ## health has reached zero
	DEFEATED,          ## out of the fight
	NOT_TARGETABLE,    ## a participant, but its policy refuses targeting
}

## Every participant joins this group, so a static query can find an actor's own
## component without a scene path.
const GROUP_PARTICIPANT := &"combat_participant"

@export_group("Wiring")
## The actor this participant speaks for. Defaults to the parent body.
@export var actor_path: NodePath
## The HealthComponent that owns alive/dead. Defaults to a sibling "Health".
@export var health_path: NodePath = NodePath("../Health")
## The HurtboxComponent that owns the damageability policy. Defaults to a sibling
## "Hurtbox". An actor without one is damageable if it has health at all.
@export var hurtbox_path: NodePath = NodePath("../Hurtbox")
## The defeat component, if any. Defaults to a sibling "Death". An actor with NO
## defeat component cannot be defeated by anything, so it reports NON-mortal: naming a
## defeat path that does not exist would be a false claim about the actor.
@export var death_path: NodePath = NodePath("../Death")
## The attack component, if any. Defaults to empty, because a sibling is named
## "Attacker" on an enemy and "Combat" on the player - there is no safe guess, so
## leave this empty on a non-attacker and set it explicitly on an attacker.
@export var attack_path: NodePath

@export_group("Policy")
## Whether this actor may be selected as a target. This is the one axis that had no
## owner anywhere before this component: it is a statement about the actor, not about
## any attack, and it is deliberately separate from being alive or damageable. An
## actor can be perfectly alive and damageable and still never be a legal target
## (a future neutral bystander, a scripted actor, a cutscene stand-in).
@export var can_be_targeted := true

## Print wiring problems. Diagnostic.
@export var debug_logging := false

var _actor: Node3D
var _health: HealthComponent
var _hurtbox: HurtboxComponent
var _death: Node
var _attack: Node


func _ready() -> void:
	add_to_group(GROUP_PARTICIPANT)
	_resolve()
	if _health == null:
		push_warning("CombatParticipant %s: no HealthComponent found; this actor cannot be a combat participant." % name)


# --- Queries about THIS actor -------------------------------------------------

## The actor this participant speaks for, or null when unwired.
func get_actor() -> Node3D:
	return _resolve_actor()


## True when this participant found the components it needs. An unwired actor is not
## silently reported as a valid participant - the wiring problem is visible.
func is_wired() -> bool:
	return _get_health() != null


## True once health has reached zero. False when there is no health to ask.
func is_dead() -> bool:
	var health := _get_health()
	return health != null and health.is_dead


## The inverse of is_dead() for a wired actor. An actor with no health is NOT alive -
## it is not a combat participant at all, which is a different statement.
func is_alive() -> bool:
	var health := _get_health()
	return health != null and not health.is_dead


## Whether a hit can land on this actor at all. The hurtbox owns this policy; an
## actor without a hurtbox is damageable exactly when it has health to take.
func is_damageable() -> bool:
	var hurtbox := _get_hurtbox()
	if hurtbox != null:
		return hurtbox.is_damageable()
	return _get_health() != null


## Whether this actor can be DEFEATED, as opposed to merely damaged. Read from the
## defeat component so there is exactly one authority for this policy.
func is_mortal() -> bool:
	var death := _get_death()
	if death == null:
		# No defeat component at all: nothing in the project can process a defeat for
		# this actor, so it is NOT mortal however much damage it absorbs. Returning
		# true here claimed a death path that does not exist, which is exactly how a
		# damageable fixture used to read as an unkillable "mortal" enemy.
		return false
	if death.has_method("is_mortal"):
		return bool(death.call("is_mortal"))
	# A defeat component with no explicit mortality policy (the player's own
	# DeathComponent) is mortal by construction: it owns the respawn, not a switch.
	return true


## Whether this actor is currently out of the fight. Read from the defeat component,
## so a defeat is never inferred from health here as well.
func is_defeated() -> bool:
	var death := _get_death()
	if death != null and death.has_method("is_defeated"):
		return bool(death.call("is_defeated"))
	return false


## Whether this actor carries an attack component. A capability statement, not a
## state statement: it says the actor CAN attack, never that it is attacking.
func is_attack_capable() -> bool:
	return _get_attack() != null


## Whether this actor may be selected as a target right now: present, alive, not
## defeated, and targetable by policy. This is the answer the enemy's targeting uses.
func is_valid_target() -> bool:
	return refusal_reason() == Refusal.NONE


## Whether this actor is still a functioning combat participant: alive and not
## defeated. This is the question a combat system asks before letting an actor act.
func can_act() -> bool:
	return is_alive() and not is_defeated()


## Current health as 0..1, or 0.0 when there is no health.
func health_fraction() -> float:
	var health := _get_health()
	if health == null:
		return 0.0
	return health.health_fraction()


## Why THIS actor is not a usable target, or NONE when it is one.
func refusal_reason() -> int:
	if not is_wired():
		return Refusal.NOT_PARTICIPANT
	if is_dead():
		return Refusal.DEAD
	if is_defeated():
		return Refusal.DEFEATED
	if not can_be_targeted:
		return Refusal.NOT_TARGETABLE
	return Refusal.NONE


## The combat state in one readable line, for a debug readout or a probe report.
## Flags that do not apply to an actor simply do not appear.
func state_summary() -> String:
	var parts: Array = []
	# A NON-MORTAL actor at zero health is DEPLETED, not dead: its health ran out and
	# nothing can process a death for it, because no defeat path exists. Reporting that
	# as "dead" is exactly what made an unkillable actor look like a broken enemy.
	if is_dead() and not is_mortal():
		parts.append("depleted")
	else:
		parts.append("alive" if is_alive() else "dead")
	if not is_damageable():
		parts.append("non-damageable")
	if not is_mortal():
		parts.append("non-mortal")
	if is_defeated():
		parts.append("defeated")
	if is_attack_capable():
		parts.append("attack-capable")
	if can_be_targeted:
		parts.append("targetable")
	else:
		parts.append("not-targetable")
	return " ".join(PackedStringArray(parts))


# --- Static queries, usable without an actor reference ------------------------

## The participant component belonging to `actor`, or null when it has none.
static func find_for(actor) -> CombatParticipant:
	if actor == null or not is_instance_valid(actor):
		return null
	# Explicit types here on purpose: the parameter is deliberately untyped so a freed
	# or non-node reference can be handled instead of raising, and an untyped source
	# cannot be inferred.
	var tree: SceneTree = actor.get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(GROUP_PARTICIPANT):
		var participant := node as CombatParticipant
		if participant == null:
			continue
		if participant.get_actor() == actor:
			return participant
	return null


## Why `node` is not a usable combat target, or NONE when it is one.
##
## Safe on anything, including null and a freed node, which is the whole point: this
## is the check a consumer calls on a target it has not validated yet.
##
## When the actor has a CombatParticipant its explicit answer is used. When it does
## NOT, this falls back to the health-based answer the project used before this
## component existed, so an unwired actor is not silently refused as a target.
static func target_refusal(node) -> int:
	if node == null or not is_instance_valid(node):
		return Refusal.MISSING
	if not node.is_inside_tree():
		return Refusal.MISSING
	if not (node is Node3D):
		return Refusal.NOT_PARTICIPANT

	var participant := find_for(node)
	if participant != null:
		return participant.refusal_reason()

	# Unwired fallback: identical to the pre-8K behaviour.
	var health := _health_under(node)
	if health == null:
		return Refusal.NOT_PARTICIPANT
	if health.is_dead:
		return Refusal.DEAD
	var death: Node = node.get_node_or_null("Death")
	if death != null and death.has_method("is_defeated") and bool(death.call("is_defeated")):
		return Refusal.DEFEATED
	return Refusal.NONE


## Whether `node` may be used as a combat target right now.
static func is_usable_target(node) -> bool:
	return target_refusal(node) == Refusal.NONE


## Readable name for a refusal cause, so a log line or a probe report never prints
## a bare integer.
static func refusal_name(reason: int) -> String:
	match reason:
		Refusal.NONE:
			return "usable"
		Refusal.MISSING:
			return "missing"
		Refusal.NOT_PARTICIPANT:
			return "not-participant"
		Refusal.DEAD:
			return "dead"
		Refusal.DEFEATED:
			return "defeated"
		Refusal.NOT_TARGETABLE:
			return "not-targetable"
	return "unknown"


## First HealthComponent directly under `node`. Used only by the unwired fallback.
static func _health_under(node) -> HealthComponent:
	for child in node.get_children():
		var health := child as HealthComponent
		if health != null:
			return health
	return null


# --- Resolution ---------------------------------------------------------------

func _resolve() -> void:
	_actor = _resolve_actor()


func _resolve_actor() -> Node3D:
	if not String(actor_path).is_empty():
		if _actor == null or not is_instance_valid(_actor):
			_actor = get_node_or_null(actor_path) as Node3D
		return _actor
	if _actor == null or not is_instance_valid(_actor):
		_actor = get_parent() as Node3D
	return _actor


func _get_health() -> HealthComponent:
	if _health == null or not is_instance_valid(_health):
		if String(health_path).is_empty():
			return null
		_health = get_node_or_null(health_path) as HealthComponent
	return _health


func _get_hurtbox() -> HurtboxComponent:
	if _hurtbox == null or not is_instance_valid(_hurtbox):
		if String(hurtbox_path).is_empty():
			return null
		_hurtbox = get_node_or_null(hurtbox_path) as HurtboxComponent
	return _hurtbox


func _get_death() -> Node:
	if _death == null or not is_instance_valid(_death):
		if String(death_path).is_empty():
			return null
		_death = get_node_or_null(death_path)
	return _death


func _get_attack() -> Node:
	if _attack == null or not is_instance_valid(_attack):
		if String(attack_path).is_empty():
			return null
		_attack = get_node_or_null(attack_path)
	return _attack
