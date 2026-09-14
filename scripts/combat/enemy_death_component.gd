class_name EnemyDeathComponent
extends Node
## One enemy's defeat (Milestone 8 family - enemy death and persistence pass).
##
## The counterpart of the player's DeathComponent, and deliberately a DIFFERENT
## class. DeathComponent owns a full ARENA reset - health, stamina, position and the
## test attacker. An enemy dying must restore none of that, so sharing the class
## would have meant either an arena reset on every enemy death or a branch inside it.
## This component owns the smallest thing that makes an enemy a defeated actor.
##
## What it owns:
##   - the DEFEATED state, processed exactly once from the existing `died` signal
##   - cancelling whatever attack was committed when the enemy died
##   - the persistent fact that this enemy is out of the fight
##
## What it deliberately does NOT own:
##   - health or damage. `HealthComponent` is already the single place damage lands,
##     and it already refuses damage to a dead actor, so nothing here duplicates it.
##   - the attack state machine. `EnemyAttacker` ASKS this component whether the
##     enemy is defeated before it starts anything, so there is one authority and no
##     second copy of the flag that could drift out of sync.
##   - presentation. An adapter reads this state and represents it.
##
## PERSISTENCE, defined precisely for this milestone: the defeated state lives in
## THIS component and OUTLIVES the player's single-arena reset. It is deliberately
## NOT cleared by `EnemyAttacker.reset()`, and that is the whole point - the player's
## death circuit calls exactly that method, so storing the flag on the attacker would
## make a defeated enemy stand back up every time the player died. That one fact is
## why this state lives here rather than beside the attack state machine.
##
## This is NOT a save or checkpoint system. Nothing here survives a scene load. It is
## an encounter-local defeated flag that a future encounter or checkpoint system can
## consume; it does not pretend to be either.
##
## Attach one per enemy, as a direct child of the body, named "Death".

## Emitted once, when the enemy becomes defeated.
signal defeated()

## Every enemy death state joins this group, so tooling can enumerate them.
## Deliberately NOT the player's "death" group: the player's death presentation
## resolves its subject through DeathComponent.GROUP_DEATH, so an enemy joining that
## group would let the player's "YOU DIED" panel attach to an enemy.
const GROUP_ENEMY_DEATH := &"enemy_death"

@export_group("Policy")
## Whether this actor can be DEFEATED at all.
##
## true  - mortal: a lethal hit processes exactly one defeat.
## false - damageable but IMMORTAL: a lethal hit still lands and still reaches zero
##         health, but no defeat is processed and is_defeated() never becomes true.
##
## This is the one flag that separates "damageable" from "mortal". An actor can be
## damaged by every attack in the arena and never be defeated, which is a real and
## legitimate configuration (a training dummy, an invulnerable plot actor, a future
## tutorial target). Default true, so every existing actor keeps its behaviour.
@export var mortal := true

@export_group("Wiring")
## The HealthComponent whose `died` signal is consumed. Defaults to a sibling named
## "Health".
@export var health_path: NodePath = NodePath("../Health")
## The attacker whose committed attack is cancelled on death. Defaults to a sibling
## named "Attacker"; an enemy without one simply has nothing to cancel.
@export var attacker_path: NodePath = NodePath("../Attacker")

## Print the defeat. Diagnostic.
@export var debug_logging := false

var _defeated := false
var _health: HealthComponent
var _attacker: Node

## How many times this enemy has been defeated. A second defeat would be a defect,
## so the count is exposed for the same reason the player's is.
var defeats := 0

## How many lethal hits arrived while `mortal` was false. Diagnostic: this is what
## makes "damageable but immortal" checkable rather than inferred from a defeat that
## merely never happened.
var lethal_refusals := 0

func _ready() -> void:
	add_to_group(GROUP_ENEMY_DEATH)
	_health = _get_health()
	if _health != null:
		_health.died.connect(_on_died)
	else:
		push_warning("EnemyDeathComponent %s: no HealthComponent found; this enemy can never be defeated." % name)


# --- Queries ----------------------------------------------------------------

## True once this enemy is defeated, for the rest of the arena's life. The attack
## state machine asks this before every start.
func is_defeated() -> bool:
	return _defeated


## Whether this actor is configured to be defeatable at all.
##
## Deliberately separate from is_defeated(): this is the POLICY, that one is the
## STATE. An actor authored with mortal=false reports false here and false from
## is_defeated() for its entire life, however much damage it absorbs.
func is_mortal() -> bool:
	return mortal


## Put the defeated STATE back to what a snapshot recorded (Milestone 10 world-state restore).
##
## The ONLY place `_defeated` is ever set back to false, and the only writer other than
## `_on_died()`. It is not a general-purpose revive that any system may call: it exists so a
## load can restore the world it recorded.
##
## IT DOES NOT EMIT `defeated`. That is deliberate and load-bearing. `CreditLedger` pays
## Credits from that signal, so emitting it here would pay a reward for a RESTORE - a save
## would mint currency every time it was loaded. The presentation does not need the signal
## either: it polls `is_defeated()` and re-poses on its own.
##
## `defeats` counts defeats PROCESSED, so a restore deliberately does not touch it. A restored
## actor reports defeats=0 with is_defeated()=true, which is honest: no defeat happened here.
##
## Returns whether the state actually changed, so a load can report what it really did rather
## than claiming it restored something that was already that way.
func restore_defeated(defeated: bool) -> bool:
	if _defeated == defeated:
		return false
	_defeated = defeated
	if defeated:
		# Whatever the actor had committed belongs to a defeated actor either way.
		_cancel_committed_attack()
	_log("RESTORED to %s (defeats=%d)" % ["defeated" if defeated else "alive", defeats])
	return true


# --- Defeat -----------------------------------------------------------------

## The defeat itself. Guarded so one death is processed once even if further lethal
## damage arrives or the signal fires again for any reason.
func _on_died(_event: DamageEvent) -> void:
	if _defeated:
		return
	# Mortality is checked AFTER the duplicate guard and BEFORE any state changes. A
	# non-mortal actor records the refusal and stays fully alive as a combat
	# participant - no defeat, no attack cancellation, no signal - which is exactly
	# the difference between being DAMAGEABLE and being MORTAL.
	if not mortal:
		lethal_refusals += 1
		_log("lethal damage but mortal=false - no defeat (refusal #%d)" % lethal_refusals)
		return
	_defeated = true
	defeats += 1

	# Whatever this enemy had committed died with it. The cancel lives on the
	# attacker, because the attacker owns that state machine; what this component
	# adds is the refusal to start another one.
	_cancel_committed_attack()

	_log("defeated (defeat #%d)" % defeats)
	defeated.emit()


## Ask the attacker to end any committed attack and close its damage window.
##
## Duck-typed on purpose, exactly as HurtboxComponent asks its invulnerability and
## parry sources by method name: any attacker that answers `cancel_attack()` works,
## so this component depends on no particular attacker class.
func _cancel_committed_attack() -> void:
	var attacker := _get_attacker()
	if attacker == null:
		return
	if not attacker.has_method("cancel_attack"):
		return
	attacker.call("cancel_attack")
	_log("committed attack cancelled")


# --- Resolution -------------------------------------------------------------

func _get_health() -> HealthComponent:
	if _health == null or not is_instance_valid(_health):
		if String(health_path).is_empty():
			return null
		_health = get_node_or_null(health_path) as HealthComponent
	return _health


func _get_attacker() -> Node:
	if _attacker == null or not is_instance_valid(_attacker):
		if String(attacker_path).is_empty():
			return null
		_attacker = get_node_or_null(attacker_path)
	return _attacker


func _log(message: String) -> void:
	if debug_logging:
		print("[ENEMYDEATH] %s: %s" % [name, message])
