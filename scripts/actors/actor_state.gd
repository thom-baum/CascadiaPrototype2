class_name ActorState
extends Node
## One actor's answer to "what is this actor doing right now, in terms a PRESENTATION layer
## can consume?" (Milestone 15 - shared combatant foundation).
##
## WHY THIS EXISTS. The project already answers that question in four correct but SEPARATE
## dialects: PlayerCombat reports `is_busy()` / `state_name()`, EnemyAttacker reports
## `is_attacking()` / `phase_name()`, DodgeComponent reports `is_dodging()`, ParryComponent
## reports `is_parrying()`, HealthReactionComponent reports `is_reacting()`. An animation
## adapter written against one of them had to be rewritten for the next, and a third actor
## would have meant a third dialect. This node asks EVERY actor the same questions in ONE
## vocabulary - the player, the enemy and the NPC - and it still gets every answer from its
## owner.
##
## WHAT IT OWNS: the query, and the translation. Nothing else. It holds no health, no timer,
## no phase, no velocity and no flag of its own; it starts nothing, cancels nothing and moves
## nothing. Delete every ActorState node in the project and every actor behaves exactly as it
## does now - which is the test of whether a contract is a contract or a new authority.
##
## WHY THE OWNERS KEEP THEIR OWN METHOD NAMES. PlayerCombat and EnemyAttacker are proven
## systems with probes reading their exact method names, and renaming them to fit a new
## convention would have been a change to working gameplay for cosmetic gain. The translation
## lives HERE, in one place, written down:
##
##   attack state   is_attacking()   enemy   -> read directly
##                  is_busy()        player  -> read directly
##   attack phase   phase_name()     enemy   -> IDLE / WINDUP / ACTIVE / RECOVERY
##                  state_name()     player  -> IDLE / STARTUP / ACTIVE / RECOVERY
##
## WINDUP and STARTUP are the SAME phase of a committed attack under two names. The shared
## report normalizes both to `startup`, and `source_phase_name()` still exposes the owner's
## own word, so nothing is lost: the uniform answer is uniform, and the original remains
## readable in a diagnostic.
##
## NULLABILITY IS DELIBERATE. Every question below answers honestly for an actor that does not
## carry the component being asked: an actor with no dodge is not dodging, an actor with no
## attacker is not attacking. That is what lets the SAME reader describe the player, the
## enemy and a passive NPC without a special case per actor.
##
## WHAT IT IS NOT: an authority, and not a state machine. Nothing in gameplay reads this node.
## It is the seat a future animation adapter reads from, and it is what makes the player, the
## enemy and the NPC describable by ONE reader instead of three.
##
## Attach one per actor, as a direct child of the body, named "ActorState".

## Every actor state in the project joins this group, so tooling can enumerate actors that
## carry the shared contract without a hard-coded scene path.
const GROUP_ACTOR_STATE := &"actor_state"

## Physics priority. Positive, so this node reports AFTER the actor's own controller and after the
## components that publish the state it reads. See `_ready()`.
const PHYSICS_PRIORITY := 10

## The shared ACTION vocabulary. Every value `action_name()` can return.
const ACTION_IDLE := "idle"
const ACTION_ATTACKING := "attacking"
const ACTION_DODGING := "dodging"
const ACTION_PARRYING := "parrying"
const ACTION_STAGGERED := "staggered"
const ACTION_DEAD := "dead"

## The shared PHASE vocabulary. Every value `phase_name()` can return.
const PHASE_NONE := "none"
const PHASE_STARTUP := "startup"
const PHASE_ACTIVE := "active"
const PHASE_RECOVERY := "recovery"

@export_group("Wiring")
## The actor body this state speaks for. Defaults to the parent body.
@export var actor_path: NodePath
## The attack state machine, if any. Leave EMPTY to resolve it by the project's own component
## naming: a child named "Attacker", else a child named "Combat". There is no third guess, so
## an actor with neither simply reports that it is not attacking.
@export var attack_path: NodePath
## The actor's dodge, if any. Defaults to a child named "Dodge".
@export var evasion_path: NodePath = NodePath("Dodge")
## The actor's parry, if any. Defaults to a child named "Parry".
@export var guard_path: NodePath = NodePath("Parry")
## The actor's hit reaction, if any. Defaults to a child named "Reaction".
@export var reaction_path: NodePath = NodePath("Reaction")
## The actor's combat participant, if any. Defaults to a child named "Participant".
@export var participant_path: NodePath = NodePath("Participant")
## The actor's health, if any. Defaults to a child named "Health". Used only when there is no
## participant to ask, so alive/dead still has exactly one owner.
@export var health_path: NodePath = NodePath("Health")

@export_group("Thresholds")
## Flat speed above which the actor counts as moving, in metres per second.
@export var move_threshold := 0.05
## Turn rate above which the actor counts as turning, in degrees per second. A RATE rather
## than a per-frame delta, so the answer does not change with the frame rate.
@export var turn_threshold_degrees_per_second := 15.0

var _actor: Node3D
var _attack: Node
var _evasion: Node
var _guard: Node
var _reaction: Node
var _participant: CombatParticipant
var _health: HealthComponent
## Body yaw on the previous physics frame, for the turn rate. Sampled here rather than asked
## for, because no component in the project stores an actor's previous orientation.
var _last_yaw := 0.0
var _turn_rate := 0.0


func _ready() -> void:
	add_to_group(GROUP_ACTOR_STATE)
	# Runs AFTER the body and after every component that publishes state. The project's gameplay
	# components all use a NEGATIVE physics priority (-3 parry, -2 dodge, -1 player combat) so they
	# advance BEFORE the body that owns them; this is the deliberate mirror of that convention, so
	# the change this node announces is the one the actor actually ENDED the frame in rather than
	# one an action changed afterwards.
	process_physics_priority = PHYSICS_PRIORITY
	_resolve()
	if _get_participant() == null and _get_health() == null:
		push_warning("ActorState %s: no CombatParticipant and no HealthComponent found; this actor cannot report its lifecycle." % name)
	_last_yaw = _actor.rotation.y if _actor != null else 0.0


func _physics_process(delta: float) -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	var yaw := _actor.rotation.y
	if delta > 0.0:
		_turn_rate = absf(rad_to_deg(angle_difference(_last_yaw, yaw))) / delta
	_last_yaw = yaw


# --- Identity and lifecycle --------------------------------------------------

## The actor this state speaks for, or null when unwired.
func get_actor() -> Node3D:
	return _resolve_actor()


## True once this actor is dead. Read from the combat participant when it has one, so
## alive/dead is never inferred here as well as there. False when there is nothing to ask.
func is_dead() -> bool:
	var participant := _get_participant()
	if participant != null:
		return participant.is_dead()
	var health := _get_health()
	return health != null and health.is_dead


func is_alive() -> bool:
	var participant := _get_participant()
	if participant != null:
		return participant.is_alive()
	var health := _get_health()
	return health != null and not health.is_dead


## Whether this actor is out of the fight, as opposed to merely out of health.
func is_defeated() -> bool:
	var participant := _get_participant()
	return participant != null and participant.is_defeated()


## Whether this actor may act at all right now: alive and not out of the fight. DELEGATED to
## the combat participant, which already owns that decision, so this contract never becomes a
## second opinion about whether an actor can act - the same rule is_dead() and is_alive() follow.
func can_act() -> bool:
	var participant := _get_participant()
	if participant != null:
		return participant.can_act()
	var health := _get_health()
	return health != null and not health.is_dead


## Whether this state resolved the actor's CombatParticipant. A WIRING question, so a consumer
## can tell "this actor carries no participant" apart from "the participant is refusing".
func has_participant() -> bool:
	return _get_participant() != null


## Whether this state resolved the actor's HealthComponent. The same wiring question for health.
func has_health() -> bool:
	return _get_health() != null


# --- Combat state ------------------------------------------------------------

## The actor's attack state machine, or null when it has none.
func get_attack() -> Node:
	return _get_attack()


## Whether an attack is committed right now. Deliberately NOT the same question as "is a
## damage window open": a committed attack is committed through startup AND recovery too.
func is_attacking() -> bool:
	var attack := _get_attack()
	if attack == null:
		return false
	if attack.has_method("is_attacking"):
		return bool(attack.call("is_attacking"))
	if attack.has_method("is_busy"):
		return bool(attack.call("is_busy"))
	return false


## Whether a committed evasion owns this actor's body right now.
func is_evading() -> bool:
	return _query_flag(_get_evasion(), &"is_dodging")


## Whether this actor is inside a parry, of any phase. Deliberately NOT the same question as
## "is the parry WINDOW open" - a parry is committed through its startup and recovery as well.
func is_guarding() -> bool:
	return _query_flag(_get_guard(), &"is_parrying")


## Whether this actor is being INTERRUPTED by a hit.
func is_staggered() -> bool:
	return _query_flag(_get_reaction(), &"is_staggered")


## Whether this actor is feeling any hit at all, flinch or stagger.
func is_reacting() -> bool:
	return _query_flag(_get_reaction(), &"is_reacting")


## Whether ANY committed action currently owns this actor.
func is_acting() -> bool:
	return is_attacking() or is_evading() or is_guarding()


## The one shared ACTION the actor is in, in the shared vocabulary. Priority is the
## project's own: a death outranks everything, because a dead actor is not doing anything
## else; then a committed evasion, then a committed parry, then a committed attack, then a
## hit reaction. `is_acting()` and `is_reacting()` are independent facts and stay independent
## - this is a LABEL for presentation, not the authority those two answer from.
func action_name() -> String:
	if is_dead():
		return ACTION_DEAD
	if is_evading():
		return ACTION_DODGING
	if is_guarding():
		return ACTION_PARRYING
	if is_attacking():
		return ACTION_ATTACKING
	if is_staggered():
		return ACTION_STAGGERED
	return ACTION_IDLE


## The phase of the current attack, in the SHARED vocabulary: a value from
## PHASE_NONE / PHASE_STARTUP / PHASE_ACTIVE / PHASE_RECOVERY.
func phase_name() -> String:
	if not is_attacking():
		return PHASE_NONE
	return _normalize_phase(source_phase_name())


## The owning component's OWN phase word, untranslated: EnemyAttacker says WINDUP where
## PlayerCombat says STARTUP. Exposed so the normalization above never hides the original.
func source_phase_name() -> String:
	var attack := _get_attack()
	if attack == null:
		return ""
	if attack.has_method("phase_name"):
		return String(attack.call("phase_name"))
	if attack.has_method("state_name"):
		return String(attack.call("state_name"))
	return ""


## Seconds left in the current attack phase, or 0.0 when there is no attack.
func phase_remaining() -> float:
	if not is_attacking():
		return 0.0
	var attack := _get_attack()
	if attack.has_method("phase_remaining"):
		return float(attack.call("phase_remaining"))
	return 0.0


## The IDENTITY of the attack currently being performed, or "" when there is no attack or the owner
## reports none (Milestone 21 - animation lookup architecture).
##
## WHY THIS IS ON THE CONTRACT RATHER THAN REACHED FOR THROUGH get_attack(). The phase vocabulary
## says an actor is attacking; it cannot say WHICH attack, so `startup` is the same key for every
## attack in the game and a presentation layer cannot choose between them. Reading the owner's
## definition directly would work, but it would make the presentation layer depend on a gameplay
## COMPONENT - the same coupling this contract exists to remove. So identity is translated here,
## from the owner's own report, and the one-way rule still holds: gameplay owns the attack, this
## reports which one it is.
##
## Deliberately reports identity and NOTHING ELSE about the attack: no timing, no damage, no phase.
## Those stay with the owner, exactly as before.
func attack_id() -> String:
	var attack := _get_attack()
	if attack == null or not is_attacking():
		return ""
	if attack.has_method("attack_id"):
		return String(attack.call("attack_id"))
	return ""


## The current hit reaction in one word: "none", "stagger" or "hurt".
func reaction_name() -> String:
	var reaction := _get_reaction()
	if reaction == null or not reaction.has_method("reaction_name"):
		return "none"
	return String(reaction.call("reaction_name"))


# --- Spatial state -----------------------------------------------------------

## The actor's full velocity, or ZERO when there is no physics body to ask.
func velocity() -> Vector3:
	if _actor is CharacterBody3D:
		return (_actor as CharacterBody3D).velocity
	return Vector3.ZERO


## Horizontal speed, ignoring fall and rise. The value "is this actor moving" is asked of.
func flat_speed() -> float:
	var v := velocity()
	return Vector2(v.x, v.z).length()


func is_moving() -> bool:
	return flat_speed() > move_threshold


## Whether the actor's body reports a floor under it. Read from the body itself, never
## re-derived: an actor whose body cannot report it answers false and says so through
## has_ground_report().
func is_grounded() -> bool:
	if _actor is CharacterBody3D:
		return (_actor as CharacterBody3D).is_on_floor()
	return false


## Whether a grounded answer is available at all. Separates "not on the floor" from "nobody
## can tell", which a single false would blur.
func has_ground_report() -> bool:
	return _actor is CharacterBody3D


## Whether this actor is sprinting right now. Asked of the actor body's OWN controller, which is
## the single authority on it, so nothing here re-derives sprint from speed.
##
## THE RESOLUTION TARGET IS THE BODY, NOT A CHILD COMPONENT, and that is load-bearing. Sprint is a
## property of whatever DRIVES an actor, and on the player that driver IS the body itself
## (PlayerController), not one of the Nod children beside this state node. Asking a child would
## have returned false for every actor in the project while the player sprinted past.
func is_sprinting() -> bool:
	return _query_flag(_resolve_actor(), &"is_sprinting")


## Whether a sprint answer is available at all. Separates "not sprinting" from "this actor
## publishes no sprint state", exactly as has_ground_report() does for grounding: an actor that
## answers nothing must not be reported as having answered no.
func has_sprint_report() -> bool:
	var actor := _resolve_actor()
	if actor == null or not is_instance_valid(actor):
		return false
	return actor.has_method(&"is_sprinting")


## How fast the body is currently turning, in degrees per second.
func turn_rate_degrees_per_second() -> float:
	return _turn_rate


func is_turning() -> bool:
	return _turn_rate > turn_threshold_degrees_per_second


## The body yaw in radians.
func facing_yaw() -> float:
	if _actor == null or not is_instance_valid(_actor):
		return 0.0
	return _actor.rotation.y


## The direction the body faces, as a world-space unit vector. Cascadia bodies face -Z, so
## this is the body's own forward by construction rather than a guess from velocity.
func facing_direction() -> Vector3:
	if _actor == null or not is_instance_valid(_actor):
		return Vector3.ZERO
	return (-_actor.global_transform.basis.z).normalized()


# --- Reporting ---------------------------------------------------------------

## The whole shared state in one readable line, for a debug readout or a probe report. Flags
## that do not apply to an actor simply do not appear.
func state_summary() -> String:
	var parts: Array = []
	var action := action_name()
	parts.append(action)
	var phase := phase_name()
	if phase != PHASE_NONE:
		parts.append(phase)
	if is_moving():
		# Sprint is claimed ONLY when the actor can actually answer the question, so an actor that
		# publishes no sprint state reads as "moving" rather than as a confident "not sprinting".
		parts.append("sprinting" if (has_sprint_report() and is_sprinting()) else "moving")
	if is_grounded():
		parts.append("grounded")
	if is_turning():
		parts.append("turning")
	if is_reacting() and action != ACTION_STAGGERED:
		parts.append(reaction_name())
	return " ".join(PackedStringArray(parts))


## Every ACTION name this contract can report.
static func action_vocabulary() -> PackedStringArray:
	return PackedStringArray([
		ACTION_IDLE, ACTION_ATTACKING, ACTION_DODGING, ACTION_PARRYING,
		ACTION_STAGGERED, ACTION_DEAD,
	])


## Every PHASE name this contract can report.
static func phase_vocabulary() -> PackedStringArray:
	return PackedStringArray([PHASE_NONE, PHASE_STARTUP, PHASE_ACTIVE, PHASE_RECOVERY])


# --- Static queries, usable without an actor reference -----------------------

## The shared actor state belonging to `actor`, or null when it has none. Resolved through the
## group so a caller needs no scene path - the same pattern CombatParticipant already uses.
static func find_for(actor) -> ActorState:
	if actor == null or not is_instance_valid(actor):
		return null
	var tree: SceneTree = actor.get_tree()
	if tree == null:
		return null
	for node in tree.get_nodes_in_group(GROUP_ACTOR_STATE):
		var state := node as ActorState
		if state == null:
			continue
		if state.get_actor() == actor:
			return state
	return null


# --- Resolution --------------------------------------------------------------

func _resolve() -> void:
	_actor = _resolve_actor()
	_attack = null
	_evasion = null
	_guard = null
	_reaction = null
	_participant = null
	_health = null


func _resolve_actor() -> Node3D:
	if not String(actor_path).is_empty():
		if _actor == null or not is_instance_valid(_actor):
			_actor = get_node_or_null(actor_path) as Node3D
		return _actor
	if _actor == null or not is_instance_valid(_actor):
		_actor = get_parent() as Node3D
	return _actor


## Resolve one of the actor's components by path, tolerating an empty path meaning "this actor
## has none".
##
## THE PATH IS RESOLVED AGAINST THE ACTOR BODY, NOT AGAINST THIS NODE, and that distinction is
## load-bearing rather than a detail. The defaults read "Health", "Participant", "Dodge" - which
## name the ACTOR's own components, and those are SIBLINGS of this state node, not its children.
## Resolving them from here would ask for `ActorState/Health` and silently find nothing on every
## actor in the project, leaving the state reporting an unwired actor while every component it
## wanted sat one level up.
##
## The node's own children are tried second, so an actor that genuinely nests a component under
## its state node still resolves.
func _resolve_child(path: NodePath, type_check: String) -> Node:
	if String(path).is_empty():
		return null
	var node: Node = null
	var actor := _resolve_actor()
	if actor != null:
		node = actor.get_node_or_null(path)
	if node == null:
		node = get_node_or_null(path)
	if node == null:
		return null
	if type_check == "participant" and not (node is CombatParticipant):
		return null
	if type_check == "health" and not (node is HealthComponent):
		return null
	return node


func _get_evasion() -> Node:
	if _evasion == null or not is_instance_valid(_evasion):
		_evasion = _resolve_child(evasion_path, "any")
	return _evasion


func _get_guard() -> Node:
	if _guard == null or not is_instance_valid(_guard):
		_guard = _resolve_child(guard_path, "any")
	return _guard


func _get_reaction() -> Node:
	if _reaction == null or not is_instance_valid(_reaction):
		_reaction = _resolve_child(reaction_path, "any")
	return _reaction


func _get_participant() -> CombatParticipant:
	if _participant == null or not is_instance_valid(_participant):
		_participant = _resolve_child(participant_path, "participant") as CombatParticipant
	return _participant


func _get_health() -> HealthComponent:
	if _health == null or not is_instance_valid(_health):
		_health = _resolve_child(health_path, "health") as HealthComponent
	return _health


## The actor's attack state machine. Resolved by the project's own component naming - the
## enemy's is "Attacker", the player's is "Combat" - with an explicit path overriding both.
func _get_attack() -> Node:
	if _attack != null and is_instance_valid(_attack):
		return _attack
	if not String(attack_path).is_empty():
		_attack = _resolve_child(attack_path, "any")
		return _attack
	# Same body-relative rule as every other path here: the enemy's attack machine is a SIBLING
	# of this node, named "Attacker", and the player's is named "Combat".
	if _actor != null:
		_attack = _actor.get_node_or_null("Attacker")
		if _attack == null:
			_attack = _actor.get_node_or_null("Combat")
	return _attack


## Turn one owner's attack phase word into the shared vocabulary. Both dialects are accepted
## and anything unrecognised is reported as "none" rather than passed through, so a consumer
## can never receive a phase this contract does not define.
func _normalize_phase(source: String) -> String:
	match source.to_upper():
		"IDLE", "":
			return PHASE_NONE
		"STARTUP", "WINDUP":
			return PHASE_STARTUP
		"ACTIVE":
			return PHASE_ACTIVE
		"RECOVERY":
			return PHASE_RECOVERY
	return PHASE_NONE


## Ask a duck-typed source for a boolean. Duck-typed, so this node depends on no particular
## component class: any source answering the named method works, and a missing source is false.
func _query_flag(source: Node, method: StringName) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	if not source.has_method(method):
		return false
	return bool(source.call(method))
