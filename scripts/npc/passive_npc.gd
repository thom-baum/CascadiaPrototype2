class_name PassiveNpc
extends CharacterBody3D
## The FIRST NPC ARCHETYPE (Milestone 15 - shared combatant foundation).
##
## WHY THIS EXISTS. Cascadia could prove that a PLAYER and an ENEMY are combat actors. It had
## never proved that an actor which is NOT hostile and NOT player-controlled can be one too.
## A civilian standing in the arena is the cheapest honest proof of that: it must be damageable
## through the same hitbox -> hurtbox -> health chain, must carry the same defeat path, must
## publish the same actor state, and must be configurable from the same data layer - without
## being an enemy and without being a second implementation of "an actor".
##
## WHAT THIS OWNS: IDLE BEHAVIOUR and the RESPAWN WAIT. It notices the player nearby and turns
## the body to face them; with nobody near it turns back to the yaw the scene authored. Gravity
## and floor settling are the body's own, so it stands ON the ground like every other actor.
## When it is defeated it either stays down - the default - or, if its archetype says so, waits
## out a delay and is put back on its mark through each component's OWN reset API, so a respawn
## is not a third way of restoring an actor.
##
## WHAT THIS DELIBERATELY DOES NOT OWN, and why each one is a refusal rather than an oversight:
##
##   health, damage, invulnerability   HealthComponent / HurtboxComponent already own these and
##                                     this actor is wired with them exactly as the enemy is.
##   defeat                            the SAME defeat component the arena's practice targets
##                                     and the enemy use. A civilian is a defeatable actor.
##   reaction                          HealthReactionComponent, the same one the enemy uses.
##   attack, perception, AI state      IT IS NOT AN ENEMY. There is no detection, no aggro, no
##                                     chase, no navigation and no swing here, and `EnemyAttacker`
##                                     is deliberately NOT on this actor.
##   movement / pathing                IT DOES NOT WALK. Turning is the whole of its idle
##                                     behaviour; walking an NPC to a destination is navigation,
##                                     which is a deferred milestone and is not needed to prove
##                                     the shared foundation.
##   dialogue, quests, schedules, shops, relationships, interaction prompts  all deferred by
##                                     explicit instruction. Nothing here anticipates them.
##
## WHAT IT PUBLISHES: nothing of its own. The sibling `ActorState` node reports this actor's
## shared animation-facing state by READING its components, so the NPC, the enemy and the
## player are described by one implementation rather than three.
##
## Input: NONE. This actor never reads CascadiaInput, which is what makes it an NPC rather than
## a second player. Its only sense is DISTANCE TO THE PLAYER, resolved through the same
## `player_actor` group the enemy's targeting already uses.

@export_group("Data")
## Archetype data for this NPC. The SAME resource type the enemy archetype uses, so a second
## civilian variant is a new .tres rather than a second script.
##
## DECLARED WITH THE GLOBAL `class_name`, NOT A `preload()` CONST, and that is MEASURED rather than
## assumed. An exported property whose type comes from a preload const does NOT register as a
## bindable property, so the scene's `profile = ExtResource(...)` line was silently DROPPED at load
## and this actor ran with no archetype at all - while still looking fully wired everywhere.
##
## This is the SAME declaration `EnemyAttacker` already uses for `EnemyAttackProfile`, so both
## archetype resources bind through one mechanism. An earlier `preload` workaround here was aimed at
## a class-registration parse failure that turned out NOT to be the cause of the boot defect (that
## was a script mounted on the wrong node type in the NPC scene), and it introduced this one.
@export var profile: ActorProfile

@export_group("Wiring")
## The actor this NPC notices. Leave EMPTY to resolve the player through the `player_actor`
## group, exactly as the enemy's targeting does - so no scene path is hard-coded and this
## actor depends on no player class.
@export var player_path: NodePath
## This actor's defeat state. Read ONLY to stop a defeated civilian from turning.
@export var death_path: NodePath = NodePath("Death")
## This actor's health. Read ONLY so a corpse stops turning.
@export var health_path: NodePath = NodePath("Health")

@export_group("Idle")
## Horizontal distance, in metres, at which this NPC starts facing the player.
@export var greet_radius := 6.0
## Degrees per second the body turns. Read from the profile when one is assigned.
@export var turn_speed_degrees := 220.0

@export_group("Lifecycle (read from the profile when one is assigned)")
## Whether this actor may ever be selected as a combat target. FALSE is the NPC default, and the
## reason is the point: a bystander is not something the player is fighting, so it must not be
## pulled into the lock-on rotation merely by existing. An archetype that WANTS a targetable NPC
## raises this in its profile, and the profile wins.
@export var can_be_targeted := false
## Whether a DEFEATED actor is allowed to be restored by the world/reset path. The other half of
## the lifecycle, deliberately separate from the death policy: one decides whether death is
## allowed at all, the other decides whether it is permanent.
##
## OFF by default, deliberately: respawning is an AUTHORED decision about a particular actor,
## never an implicit behaviour that silently revives a civilian somebody meant to stay down.
@export var respawnable := false
## Seconds a defeated actor waits before it is restored to its spawn mark.
@export var respawn_delay := 4.0

## Print each change of state. Diagnostic.
@export var debug_logging := false

## How many times this actor has turned TO the player. Diagnostic: separates "never noticed"
## from "noticed and then turned away", which one on-screen look cannot tell apart.
var greetings := 0

var _player: Node3D
var _health: HealthComponent
var _death: Node
var _home_yaw := 0.0
## The transform the scene authored, captured at boot. This is the mark a respawn restores -
## RECORDED rather than read back from the scene, because by the time an actor is defeated the
## fight has already moved and turned it.
var _spawn_transform := Transform3D.IDENTITY
## Seconds left before this actor is restored, or -1.0 when no respawn is pending.
var _respawn_left := -1.0
## How many times this actor has come back. Diagnostic: it separates "never defeated" from
## "defeated and restored", which one on-screen look cannot tell apart.
var respawns_made := 0
## Whether the body is currently facing the player. Tracked so the greeting is counted once per
## approach instead of once per frame.
var _facing_player := false


func _ready() -> void:
	_spawn_transform = global_transform
	_home_yaw = rotation.y
	_resolve()
	_apply_profile()


## Copy the archetype data into the components that own each value.
##
## ONE-WAY AND ONE-TIME, at _ready(), exactly as `EnemyAttacker` seeds itself from an
## `EnemyAttackProfile`. Nothing here is read per frame, and no value here can retune this actor
## mid-action - gameplay timing is authoritative in Cascadia, and an actor whose maximum health
## could change while it is being hit would not be.
##
## A component that is not wired is skipped rather than guessed at, so a civilian built without a
## reaction component still stands and turns. With NO profile assigned every value below is
## simply not written, so this actor keeps its own scene-authored values and behaves exactly as
## it would without this function.
##
## ORDERING IS LOAD-BEARING: `HealthComponent._ready()` runs before this one, because Health is
## an earlier child of the same body and Godot readies children in tree order. So `reset()` here
## refills to the profile's maximum rather than being overwritten by the component's own start.
func _apply_profile() -> void:
	# The NPC's OWN default is applied FIRST, so an actor with no archetype assigned still behaves
	# as a bystander instead of inheriting CombatParticipant's general-purpose default of
	# "targetable". A profile then OVERRIDES it, so authored data always beats the fallback.
	_apply_targetability(can_be_targeted)
	if profile == null:
		return
	turn_speed_degrees = profile.turn_speed_degrees
	respawnable = profile.respawnable
	respawn_delay = profile.respawn_delay
	_apply_targetability(profile.can_be_targeted)

	var health := get_node_or_null(health_path) as HealthComponent
	if health != null and profile.max_health > 0.0:
		health.max_health = profile.max_health
		health.reset()

	_apply_mortality(profile.mortal)

	var reaction := get_node_or_null("Reaction")
	if reaction != null:
		reaction.set("reaction_seconds", profile.reaction_seconds)
		reaction.set("stagger_seconds", profile.stagger_seconds)
		reaction.set("stagger_threshold", profile.stagger_threshold)

	_log("profile applied: %s" % profile.summary())


## Write the targetability policy into the component that OWNS it. This actor decides nothing
## itself and keeps no copy: `CombatParticipant` remains the single target-validity authority,
## and this only seeds that policy from authored data.
func _apply_targetability(value: bool) -> void:
	var participant := get_node_or_null("Participant") as CombatParticipant
	if participant != null:
		participant.can_be_targeted = value


## Write the mortality policy into the component that owns DEFEAT. `EnemyDeathComponent` remains
## the single authority on whether a defeat is processed; this only seeds its policy, so an actor
## authored mortal = false takes damage and never enters the dead state.
func _apply_mortality(value: bool) -> void:
	var death := get_node_or_null(death_path)
	if death == null:
		return
	_death = death
	if "mortal" in death:
		death.set("mortal", value)


func _physics_process(delta: float) -> void:
	_update_respawn(delta)
	_update_facing(delta)
	_apply_gravity(delta)
	move_and_slide()


# --- Idle behaviour -----------------------------------------------------------

## The whole of this NPC's behaviour: face the player when they are close and alive, face the
## authored yaw otherwise. Never advances the body toward anything.
##
## A dead or defeated actor does NOT turn. That gate is deliberate rather than cosmetic: a
## corpse that keeps tracking the player reads as a live threat, and the state a future
## animation adapter would select for it is a death pose, not an idle.
func _update_facing(delta: float) -> void:
	var yaw := _home_yaw
	var wanted := _player_in_reach()
	if wanted:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		# The guard is not cosmetic: atan2 of a zero-length vector still returns a number, and
		# adopting it would snap the body to an arbitrary yaw when the player stands exactly on
		# top of this actor.
		if to_player.length_squared() > 0.0001:
			yaw = atan2(-to_player.x, -to_player.z)
			if not _facing_player:
				_facing_player = true
				greetings += 1
				_log("noticed the player at %.1fm" % to_player.length())
		else:
			wanted = false
	if not wanted:
		if _facing_player:
			_facing_player = false
			_log("player out of reach - returning to the authored yaw")
		rotation.y = rotate_toward(rotation.y, _home_yaw, deg_to_rad(turn_speed_degrees) * delta)
		return
	rotation.y = rotate_toward(rotation.y, yaw, deg_to_rad(turn_speed_degrees) * delta)


## Whether the player is close enough to notice AND still a living participant. Validity is
## asked through CombatParticipant, the project's single target-validity authority, so a dead
## player is never greeted - the same rule every other consumer obeys.
func _player_in_reach() -> bool:
	var player := _get_player()
	if player == null or not is_instance_valid(player):
		return false
	if not CombatParticipant.is_usable_target(player):
		return false
	var offset := player.global_position - global_position
	offset.y = 0.0
	return offset.length() <= greet_radius


# --- State reports ------------------------------------------------------------

## Whether this NPC is currently facing the player. For a probe or a debug readout.
func is_facing_player() -> bool:
	return _facing_player


## The yaw the scene authored for this NPC - the facing it returns to.
func home_yaw() -> float:
	return _home_yaw


## Whether this actor may still act at all: alive, and not defeated. Read through the same two
## owners every other actor uses, so this is not a third opinion about being alive.
func can_act() -> bool:
	if _health == null or _health.is_dead:
		return false
	if _death != null and _death.has_method("is_defeated") and bool(_death.call("is_defeated")):
		return false
	return true


# --- Lifecycle: coming back ----------------------------------------------------

## Count down a pending respawn and restore this actor when it elapses.
##
## Only ever arms a timer for an actor whose data says it is `respawnable`, so a civilian authored
## to stay down never comes back, and an actor that was never defeated never has a timer at all.
func _update_respawn(delta: float) -> void:
	if not respawnable:
		_respawn_left = -1.0
		return
	if _respawn_left > 0.0:
		# A pending respawn is CANCELLED when the actor is already alive again, because something
		# else restored it first - the player's death circuit resets the arena, and a load restores
		# a recorded world. Without this the timer kept counting and fired a SECOND restoration on
		# top of one that had already happened, bumping `respawns_made` for a respawn this actor
		# never actually performed and re-stamping a transform that was already correct.
		if not _is_defeated():
			_respawn_left = -1.0
			_log("already restored elsewhere - pending respawn cancelled")
			return
		_respawn_left = maxf(0.0, _respawn_left - delta)
		if _respawn_left <= 0.0:
			_restore_after_defeat()
		return
	# Armed once, on the frame the defeat is first observed. The defeat state is POLLED rather
	# than driven by its `defeated` signal, because that signal is what the economy pays Credits
	# from - listening here would risk paying a reward for a state this actor is about to leave.
	if _is_defeated():
		_respawn_left = maxf(0.1, respawn_delay)
		_log("defeated - restoring in %.1fs" % _respawn_left)


## Whether this actor is currently waiting to come back. For a probe or a debug readout.
func is_awaiting_respawn() -> bool:
	return _respawn_left > 0.0


## Whether this actor is in the defeat state, asked of the component that owns it. An actor with
## no defeat component is never defeated.
func _is_defeated() -> bool:
	if _death == null or not is_instance_valid(_death):
		return false
	if not _death.has_method("is_defeated"):
		return false
	return bool(_death.call("is_defeated"))


## Restore a defeated actor to its spawn mark, one value per OWNER, so a respawn is never a third
## way of restoring an actor:
##
##   health     HealthComponent.reset()
##   defeat     the defeat component's own restore_defeated(false)
##   transform  the mark this actor recorded at boot
##
## `restore_defeated()` deliberately does NOT emit `defeated`, which is exactly why reviving an
## actor here cannot pay a Credit reward for its own respawn - the economy pays from that signal.
func _restore_after_defeat() -> void:
	if _is_defeated():
		var death := get_node_or_null(death_path)
		if death != null and death.has_method("restore_defeated"):
			death.call("restore_defeated", false)
	if _health != null:
		_health.reset()
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_respawn_left = -1.0
	_facing_player = false
	respawns_made += 1
	_log("restored at the authored mark (respawn #%d)" % respawns_made)


# --- Physics ------------------------------------------------------------------

## Ordinary gravity, the same shape the player uses. An NPC standing on the arena floor has to
## be a real grounded body, because every grounding, targeting and defeat check in the project
## measures the body, not a decorative mesh.
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		return
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	velocity.y = maxf(velocity.y - gravity * delta, -40.0)


# --- Resolution ---------------------------------------------------------------

func _resolve() -> void:
	if String(health_path).is_empty():
		_health = null
	else:
		_health = get_node_or_null(health_path) as HealthComponent
	if String(death_path).is_empty():
		_death = null
	else:
		_death = get_node_or_null(death_path)


func _get_player() -> Node3D:
	if _player != null and is_instance_valid(_player):
		return _player
	if not String(player_path).is_empty():
		_player = get_node_or_null(player_path) as Node3D
	if _player == null and get_tree() != null:
		# The same group the enemy's targeting resolves through, so no player class is
		# referenced and no scene path is assumed.
		_player = get_tree().get_first_node_in_group(&"player_actor") as Node3D
	return _player


func _log(message: String) -> void:
	if debug_logging:
		print("[NPC] %s: %s" % [name, message])
