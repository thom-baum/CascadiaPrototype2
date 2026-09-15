class_name ActorProfile
extends Resource
## The IDENTITY AND LIFECYCLE half of one actor archetype (Milestone 15 - shared combatant
## foundation).
##
## WHY THIS EXISTS. Cascadia already has `EnemyAttackProfile`, which holds the attack tuning of
## an enemy archetype. It deliberately does NOT hold what an actor IS: how much health it has,
## whether it can be defeated at all, whether it may ever be targeted, how long it flinches.
## Those values were scene-authored exports spread across three different components, so an
## actor's archetype existed only as "the numbers pasted into that particular .tscn".
##
## This resource is that record, for ANY actor - player-scale, enemy-scale or civilian-scale -
## so a new variant is a new .tres rather than a copied scene.
##
## THE SPLIT, stated plainly, and why it is two resources rather than one:
##
##   ActorProfile        what an ACTOR is      health, mortality, targetability, reaction
##   EnemyAttackProfile  what an ATTACK is      windup, active, recovery, damage, range
##
## A civilian needs the first and must never be given the second, because giving a passive NPC
## an attack profile would be the beginning of a second enemy rather than an NPC. An actor with
## no attack simply has no attack resource to assign.
##
## AUTHORITY, stated plainly: this is a SEED, not a live authority. Every value here is copied
## into the owning component's exported field once, at that component's `_ready()`. A component
## with no profile assigned keeps its own exported default, so wiring a profile can change
## numbers but can never create behaviour that was not already there. Nothing here is read
## per frame, and no value here can retune an actor mid-action - gameplay timing is
## authoritative in Cascadia, and an actor whose maximum health could change while it is being
## hit would not be.
##
## DEFAULTS ARE THE PROJECT'S EXISTING DEFAULTS. An empty profile and no profile at all describe
## the same actor, so assigning this resource to an existing actor is a no-op until a field is
## deliberately changed.

@export_group("Identity")
## Shown in diagnostics. Names the archetype in a log line or a probe report.
@export var display_name := "Actor"
## Free-text archetype label for tooling and future content work. NOT read by gameplay: nothing
## branches on this, and it is here so a probe report can say what an actor was MEANT to be.
@export var archetype := "actor"

@export_group("Lifecycle")
## Starting and maximum health for this actor's HealthComponent.
@export var max_health := 100.0
## Whether a lethal hit processes a DEFEAT for this actor. false makes a damageable but
## immortal actor - a training fixture or a plot actor that can be hit and can never die.
@export var mortal := true
## Whether this actor may ever be selected as a combat target. Deliberately separate from being
## alive or damageable: a neutral bystander can be perfectly damageable and still never be a
## legal target.
@export var can_be_targeted := true

@export_group("Lifecycle - coming back, if it does")
## Whether a DEFEATED actor is allowed to be restored.
##
## DELIBERATELY SEPARATE FROM `mortal` ABOVE, because the two answer different questions and one
## flag could never mean both:
##
##   mortal      - MAY this actor die at all?         death is allowed / refused
##   respawnable - AFTER it dies, may it come back?   death is permanent / recoverable
##
## Keeping them apart is what makes the four real combinations expressible:
##
##   mortal=true  respawnable=false   a normal enemy: it dies and stays dead
##   mortal=true  respawnable=true    an actor that returns after being killed
##   mortal=false respawnable=false   UNKILLABLE: damage lands, death never processes
##   mortal=false respawnable=true    redundant and harmless; it can never reach a death
##
## DEFAULT false. Respawn is an AUTHORED decision about a particular actor, never an implicit
## behaviour that quietly revives something somebody meant to stay down.
@export var respawnable := false
## Seconds a defeated actor waits before it is restored. Read only when `respawnable` is true.
@export var respawn_delay := 4.0

@export_group("Reaction")
## Seconds of flinch after any hit at all.
@export var reaction_seconds := 0.30
## Seconds of stagger after a hit at or above `stagger_threshold`.
@export var stagger_seconds := 0.60
## Damage at or above which a hit staggers. 0.0 means NO hit staggers, which is the project's
## existing behaviour and the correct default for an actor nobody has tuned yet.
@export var stagger_threshold := 0.0

@export_group("Locomotion (used by actors that move themselves)")
## Ordinary ground speed. Unused by the current enemy, which does not move.
@export var move_speed := 0.0
## Sprint speed for an actor that has one. Unused today.
@export var sprint_speed := 0.0
## Acceleration toward the target speed. Unused today.
@export var acceleration := 0.0
## Degrees per second this actor turns. 0.0 means "leave the component's own value alone".
@export var turn_speed_degrees := 0.0
## Radius, in metres, at which a passive actor notices another actor. Used by the NPC archetype.
@export var greet_radius := 0.0


## The whole profile on one line, for a log line or a probe report. Every field that describes
## the actor's IDENTITY is printed, so a profile can never be reported as something it is not.
func summary() -> String:
	return "%s [%s]: health=%.1f mortal=%s respawnable=%s targetable=%s stagger>=%.1f flinch=%.2f stagger=%.2fs" % [
		display_name, archetype, max_health, str(mortal), str(respawnable), str(can_be_targeted),
		stagger_threshold, reaction_seconds, stagger_seconds]


## Whether this profile describes an actor at least one hit can stagger. False for the default
## profile and for any untuned actor.
func can_stagger() -> bool:
	return stagger_threshold > 0.0
