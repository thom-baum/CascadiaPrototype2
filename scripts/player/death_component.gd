class_name DeathComponent
extends Node
## One actor's death and reset circuit.
##
## Death is a GAMEPLAY state transition, not a presentation. This component owns
## the state, the timing and the restoration; everything a person sees is an
## adapter that READS this state (see DeathPresentationDebug). Nothing here plays
## an animation, draws a label or moves a mesh - the same separation every other
## Cascadia system uses.
##
## What it owns:
##
##   death detection    it listens to its HealthComponent's `died` signal - the
##                      existing single place where health reaches zero - and
##                      processes that death exactly ONCE, however much further
##                      damage arrives afterwards.
##   the dead flag      is_dead() is the question every other gameplay system asks
##                      before it acts. While it is true, input is refused.
##   the reset contract reset_playable_state() restores this arena's gameplay state
##                      and nothing else: health, stamina, committed action state,
##                      the actor's position and the transient presentation. It
##                      deliberately does NOT touch scripted scene state such as
##                      the arena's static targets - this is a single-arena reset,
##                      not a checkpoint or save system.
##   the timing         death_delay seconds after death the reset fires on its own,
##                      so the circuit completes unattended and the death is
##                      readable. The RESTART input resets immediately instead of
##                      shortening that delay, which is what a player will use.
##
## What it does NOT own: it does not damage anything, does not read raw device
## input, does not decide what an attack is, and does not drive presentation.
##
## TWO SEPARATE AXES, kept apart here on purpose:
##
##   resettable  - `resets_actors` says whether this component owns a RESPAWN. It is
##                 only ever true for a PLAYER-CONTROLLED actor, because it is the
##                 actor the human is driving that has to be put back on its feet for
##                 play to continue. An actor that is NOT player-controlled must not
##                 have this: applying a player respawn to a defeated actor is exactly
##                 how a corpse would stand back up.
##   mortal      - whether the actor can be defeated at all. That axis is owned by the
##                 defeat component (see EnemyDeathComponent.mortal), not here.
##
## So the player's death component is resettable AND the player also has this one
## circuit; a non-player actor gets EnemyDeathComponent instead and reads
## resets_actors == false.
##
## Attach one per PLAYER-CONTROLLED actor, as a direct child of the body, named
## "Death", beside that actor's "Health". An actor with no DeathComponent can never
## die through it and is never gated by it: every consumer treats a missing
## DeathComponent as "not dead", so a scene without one keeps working unchanged.

## Emitted once when the death is processed.
signal death_started()

## Emitted once when the actor is playable again. `by_input` is true when the
## RESTART input asked for the reset and false when the automatic delay did, so
## "the player restarted it" and "it timed out" are never confused afterwards.
signal reset_completed(by_input: bool)

@export_group("Timing")
## Seconds the dead state lasts before it resets itself. One value, easy to tune.
## The RESTART input skips this entirely rather than shortening it.
@export var death_delay := 1.5

@export_group("Wiring")
## The actor whose death this watches. Defaults to the parent body.
@export var actor_path: NodePath
## The HealthComponent that reports the death. Defaults to a sibling "Health".
@export var health_path: NodePath = NodePath("../Health")
## The actor's stamina pool, restored on reset. Defaults to a sibling "Stamina".
@export var stamina_path: NodePath = NodePath("../Stamina")
## The actor's attack state machine, cancelled on death. Defaults to "Combat".
@export var combat_path: NodePath = NodePath("../Combat")
## The actor's dodge, cleared on death. Defaults to a sibling "Dodge".
@export var dodge_path: NodePath = NodePath("../Dodge")
## The actor's parry, cleared on death. Defaults to a sibling "Parry".
@export var parry_path: NodePath = NodePath("../Parry")
## The deterministic test attacker to restore. Leave empty in an arena whose
## attacker is found through the "enemy_attacker" group, which is the default
## behaviour; set it to restore one specific attacker instead.
@export var attacker_path: NodePath

@export_group("Policy")
## Whether this component owns a RESPAWN - restoring health, stamina, position and
## this arena's test attacker - when the actor dies.
##
## true  - the PLAYER-CONTROLLED actor's configuration, and the default, so the
##         existing single-arena reset circuit is unchanged.
## false - the actor still dies and is still gated as dead, but nothing is restored
##         and nothing is reset. This exists so "this actor died" and "this actor
##         respawns" are two separate, per-actor statements instead of one
##         inseparable behaviour.
##
## Setting this false does NOT make an actor mortal: mortality is the defeat
## component's axis (EnemyDeathComponent.mortal), not this one. A non-player actor
## should carry EnemyDeathComponent rather than this component at all.
@export var resets_actors := true

## Print each death and each reset. Diagnostic.
@export var debug_logging := false

## Every death component joins this group, so tooling can enumerate them.
const GROUP_DEATH := &"death"

## The group an attacker joins. Deliberately a group name rather than the
## EnemyAttacker class: this component only needs "a node that answers to
## reset()", which keeps death independent of the enemy system.
const GROUP_ATTACKER := &"enemy_attacker"

var _dead := false
## Seconds left of the automatic delay. Only meaningful while dead.
var _delay_left := 0.0

## Deaths processed since load. Diagnostic: this is what makes "the death happened
## exactly once" checkable rather than assumed.
var deaths := 0
## Resets completed since load, and how many of them the RESTART input asked for.
var resets := 0
var resets_by_input := 0

var _actor: Node3D
var _health: HealthComponent
var _stamina: StaminaComponent
var _combat: PlayerCombat
var _dodge: DodgeComponent
var _parry: ParryComponent
var _input: CascadiaInput
var _start_position := Vector3.ZERO
var _start_yaw := 0.0


func _ready() -> void:
	add_to_group(GROUP_DEATH)
	_actor = _resolve_actor()
	if _actor != null:
		_start_position = _actor.global_position
		_start_yaw = _actor.rotation.y
	_health = _get_health()
	if _health != null:
		_health.died.connect(_on_died)
	else:
		push_warning("DeathComponent %s: no HealthComponent found; this actor can never die." % name)


func _physics_process(delta: float) -> void:
	if not _dead:
		return
	if _restart_requested():
		_log("restart input received %.2f s into the death" % (death_delay - _delay_left))
		reset_playable_state(true)
		return
	_delay_left -= delta
	if _delay_left <= 0.0:
		reset_playable_state(false)


# --- Queries ----------------------------------------------------------------

## True while the actor is dead, to the end of the reset. Gameplay asks this
## before it accepts input or spends anything.
func is_dead() -> bool:
	return _dead


## Seconds left before the automatic reset, or 0 while alive. For presentation.
func time_until_reset() -> float:
	return maxf(0.0, _delay_left) if _dead else 0.0


## Whether this component owns a respawn at all. The POLICY, deliberately separate
## from is_dead(), which is the STATE: an actor authored with resets_actors = false
## still reports is_dead() == true after a lethal hit, and never restores itself.
func is_resettable() -> bool:
	return resets_actors


# --- Death ------------------------------------------------------------------

## The death itself. Guarded so one death is processed once even if further
## lethal damage arrives, or the signal fires again for any reason.
func _on_died(_event: DamageEvent) -> void:
	if _dead:
		return
	_dead = true
	deaths += 1
	_delay_left = maxf(0.0, death_delay)

	# Everything committed when the actor died belonged to a living actor: an
	# attack still holding its damage window open, an evasion or a parry still
	# holding the body. All of it ends HERE. This is the one place a committed
	# action is allowed to be cancelled, and it is why a dead actor is never seen
	# mid-swing or mid-dodge.
	_clear_committed_actions()

	# Regeneration is frozen rather than merely gated, so the pool cannot quietly
	# refill during the death; the reset is what restores it.
	var stamina := _get_stamina()
	if stamina != null:
		stamina.regen_enabled = false

	_log("died (death #%d) - reset in %.2f s, or immediately on restart" % [deaths, _delay_left])
	death_started.emit()


# --- Reset ------------------------------------------------------------------

## Restore this arena's gameplay state and hand control back.
##
## Public on purpose: this is what the RESTART input calls, and the entry point a
## test, a future menu or a future checkpoint system would call. `by_input` only
## labels the cause; it does not change what is restored.
func reset_playable_state(by_input: bool = false) -> void:
	# State first, position last: nothing that runs during restoration can then
	# move a body that is being put back on its start mark.
	_dead = false
	_delay_left = 0.0
	_clear_committed_actions()

	var health := _get_health()
	if health != null:
		health.reset()

	var stamina := _get_stamina()
	if stamina != null:
		stamina.regen_enabled = true
		stamina.reset()

	_restore_position()
	_reset_attackers()
	# Dying resets the ENCOUNTER, not just the player: every other combat actor comes back alive at
	# full health. See _restore_arena_actors() for why this is the spawn path only.
	_restore_arena_actors()

	resets += 1
	if by_input:
		resets_by_input += 1
	_log("playable again (reset #%d, by_input=%s)" % [resets, str(by_input)])
	reset_completed.emit(by_input)


## Restore this actor to a RECORDED state and hand control back (a LOAD).
##
## DELIBERATELY SEPARATE from reset_playable_state(), exactly as HealthComponent.restore_to() is
## separate from reset(). reset_playable_state() means "this actor died and is going back on its
## SPAWN mark", which is what a death and a respawn mean. This means "put this actor back to what a
## snapshot recorded" - a different intent with different values.
##
## THE DEFECT THIS FIXES. A load used to reset the player ONLY when it was dead, and that reset put
## the body on the spawn mark. So a load after walking somewhere else left the player exactly where
## it stood - the run's recorded position was never restored at all - and a load while dead put the
## player back at spawn rather than at the position the save recorded. Both are the same missing
## piece: nobody owned "restore the player's transform from a snapshot".
##
## Every value goes back through its own owner (HealthComponent, StaminaComponent, the body's
## transform), so a load does not become a second, competing owner of any of them.
func restore_snapshot(position: Vector3, yaw: float, health_value: float, stamina_value: float) -> void:
	# State first, transform last: nothing that runs during restoration can then move a body that is
	# being put back on its recorded mark.
	_dead = false
	_delay_left = 0.0
	_clear_committed_actions()

	var health := _get_health()
	if health != null:
		health.restore_to(health_value, health_value <= 0.0)

	var stamina := _get_stamina()
	if stamina != null:
		stamina.regen_enabled = true
		stamina.restore_to(stamina_value)

	_place(position, yaw)
	_reset_attackers()

	resets += 1
	_log("restored from a snapshot (reset #%d, pos=%s yaw=%.3f)" % [resets, str(position), yaw])
	reset_completed.emit(false)


## End any committed attack, dodge or parry. Idempotent: called on death and again
## on reset, so the actor is provably in no committed action either way.
func _clear_committed_actions() -> void:
	var combat := _get_combat()
	if combat != null:
		combat.cancel_current_action()
	var dodge := _get_dodge()
	if dodge != null:
		dodge.reset()
	var parry := _get_parry()
	if parry != null:
		parry.reset()


func _restore_position() -> void:
	_place(_start_position, _start_yaw)


## Put the body at an exact position and yaw, with no residual velocity, so a restored body does not
## carry the momentum of wherever it was standing before. One definition, used by BOTH the spawn
## reset and a snapshot restore, so the two can never drift apart.
func _place(position: Vector3, yaw: float) -> void:
	if _actor == null or not is_instance_valid(_actor):
		return
	_actor.global_position = position
	_actor.rotation.y = yaw
	if _actor is CharacterBody3D:
		(_actor as CharacterBody3D).velocity = Vector3.ZERO


## Put EVERY attacker in the arena back into its initial usable state: no attack in
## progress, no cooldown left, an idle telegraph and its hitbox shut.
##
## EVERY attacker, not the first one, and that is a defect fix rather than a tidy-up. This used to
## resolve a SINGLE attacker, falling back to `get_first_node_in_group()` when no path was authored
## - so with two enemy variants in the arena only ONE of them was reset, and WHICH one depended on
## an unspecified group order that could differ between runs. Enumerating the group makes the result
## deterministic and covers a newly added variant the moment it exists.
##
## ACTION state only. Health and the defeated state are NOT touched here, because this same method
## runs on a LOAD (`restore_snapshot`), where the world's recorded values must survive untouched.
## The enemy health/defeat reset a death needs lives in `_restore_arena_actors()`, which only the
## spawn-reset path calls.
func _reset_attackers() -> void:
	# An actor configured NOT to restore the arena (resets_actors = false) must not
	# reach into the scene and reset somebody else's attacker either. The guard is
	# here rather than at the call site so there is exactly one place that decides.
	if not resets_actors:
		return
	# An AUTHORED path means "reset exactly this one", which is what a scene naming its own
	# attacker is asking for.
	var named := _resolve_attacker_by_path()
	if named != null:
		if named.has_method("reset"):
			named.call("reset")
			_log("attacker %s reset (authored path)" % named.name)
		return
	var count := 0
	for node in get_tree().get_nodes_in_group(GROUP_ATTACKER):
		if node == null or not is_instance_valid(node):
			continue
		if not node.has_method("reset"):
			continue
		node.call("reset")
		count += 1
	if count > 0:
		_log("%d attacker(s) reset" % count)


## Put EVERY OTHER COMBAT ACTOR in the arena back to alive and at full health, and clear its defeat.
##
## SOULSLIKE DEATH LOGIC, and a DELIBERATE CHANGE TO AN EARLIER DECISION. This circuit used to reset
## only the attackers' ACTION state and left enemy health and enemy defeat exactly as the fight left
## them - `EnemyDeathComponent` was specifically authored NOT to be cleared from here, so a defeated
## enemy stayed down when the player died. That is no longer the intent: dying resets the encounter,
## and every enemy comes back alive at full health, which is what a Soulslike does.
##
## Enumerated from the damageable group, so a newly added enemy is covered the moment it exists, and
## every value goes back through its OWN owner - `HealthComponent.reset()` and the defeat component's
## `restore_defeated(false)` - so this is never a second authority over either one. The restore
## deliberately does NOT emit `defeated`, which is exactly why reviving an enemy here cannot pay a
## Credit reward for it.
##
## THIS ACTOR is skipped: its own health, stamina, position and actions were already restored by the
## caller, and repeating that here would misstate who owns them.
##
## Only the SPAWN-RESET path calls this. A load must NOT: it restores a recorded world, and refilling
## every enemy would overwrite exactly the state the snapshot exists to put back.
func _restore_arena_actors() -> void:
	if not resets_actors:
		return
	var self_actor := _resolve_actor()
	var restored := 0
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var actor := node.get_parent() as Node3D
		if actor == null or actor == self_actor:
			continue
		var other_health := actor.get_node_or_null("Health") as HealthComponent
		if other_health != null:
			other_health.reset()
		var other_death := actor.get_node_or_null("Death")
		if other_death != null and other_death.has_method("restore_defeated"):
			other_death.call("restore_defeated", false)
		# POSITION TOO, and only through the mover's OWN API. Once an enemy can walk, a fight
		# rearranges the arena: without this a player who died would come back to enemies standing
		# wherever the fight left them. `reset_to_mark()` restores the transform the SCENE authored
		# and stops the body; it deliberately touches neither health nor defeat, because those have
		# their own owners just above. Duck-typed like every other cross-component call here, so an
		# enemy that cannot move simply has nothing to reset.
		var other_locomotion := actor.get_node_or_null("Locomotion")
		if other_locomotion != null and other_locomotion.has_method("reset_to_mark"):
			other_locomotion.call("reset_to_mark")
		restored += 1
	if restored > 0:
		_log("%d arena actor(s) restored to alive at full health" % restored)


# --- Input ------------------------------------------------------------------

## True when the RESTART action was pressed. Read through the input layer, like
## every other semantic action in Cascadia: the input layer buffers the press, so
## a press cannot be lost between the frame it arrived and this frame.
func _restart_requested() -> bool:
	var input := _get_input()
	if input == null:
		return false
	return input.consume_restart()


# --- Resolution -------------------------------------------------------------

func _resolve_actor() -> Node3D:
	if not String(actor_path).is_empty():
		return get_node_or_null(actor_path) as Node3D
	return get_parent() as Node3D


## The attacker an AUTHORED path names, or null when this component does not name one.
##
## Deliberately NO group fallback. That fallback is what this pass removed: with two enemy variants
## in the arena it returned ONE of them in an unspecified order, so the reset restored a single,
## non-deterministic attacker and silently ignored the other.
func _resolve_attacker_by_path() -> Node:
	if String(attacker_path).is_empty():
		return null
	return get_node_or_null(attacker_path)


func _get_health() -> HealthComponent:
	if _health == null or not is_instance_valid(_health):
		if String(health_path).is_empty():
			return null
		_health = get_node_or_null(health_path) as HealthComponent
	return _health


## The actor's stamina pool, or null when there is none. A missing pool simply
## means nothing to restore, so a scene without one keeps working.
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


func _get_dodge() -> DodgeComponent:
	if _dodge == null or not is_instance_valid(_dodge):
		if String(dodge_path).is_empty():
			return null
		_dodge = get_node_or_null(dodge_path) as DodgeComponent
	return _dodge


func _get_parry() -> ParryComponent:
	if _parry == null or not is_instance_valid(_parry):
		if String(parry_path).is_empty():
			return null
		_parry = get_node_or_null(parry_path) as ParryComponent
	return _parry


func _get_input() -> CascadiaInput:
	if _input == null or not is_instance_valid(_input):
		_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	return _input


func _log(message: String) -> void:
	if debug_logging:
		print("[DEATH] %s: %s" % [name, message])
