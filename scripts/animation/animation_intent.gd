class_name AnimationIntent
extends RefCounted
## What an actor is ALREADY doing, at the level of detail an animation set needs to pick a clip
## (Milestone 21 - animation lookup architecture, Slice A).
##
## WHY THIS EXISTS. `AnimationAdapter`'s intent vocabulary - `attack_windup`, `attack_active`,
## `attack_recovery` - is the correct SHARED STATE vocabulary and an insufficient ANIMATION LOOKUP
## KEY. It can say "this actor is attacking". It cannot say WHICH attack, so it cannot choose a light
## attack over a backstep attack. Every attack in the game collapses onto one of three keys.
##
##     "the actor is attacking"                     <- what the old key knew
##     "the actor is performing light, phase X"     <- what a clip lookup needs
##
## This type is the missing middle. It carries the attack's IDENTITY alongside the state that was
## already being reported, so the presentation layer can ask a question with an answer in it.
##
## THE RULE THAT KEEPS THIS SAFE. This is a READ model, built exclusively from `ActorState` - the
## existing read-only contract. It holds no timer, starts nothing, cancels nothing and decides
## nothing. It is a snapshot of one instant, rebuilt on demand. Identity flows IN from gameplay and
## is never inferred or guessed here:
##
##     gameplay owner  ->  ActorState  ->  AnimationIntent  ->  AnimationSet  ->  clip
##     (owns the attack)   (reports it)    (this: describes)    (maps it)        (plays it)
##
## Nothing about an attack's timing, damage or commitment is decided by any part of that chain, and
## deleting this file and `animation_set.gd` would leave every actor behaving exactly as it does now.
##
## REACHED BY PRELOAD RATHER THAN BY GLOBAL CLASS NAME, and this is load-bearing rather than style.
## The editor registers a `class_name` only once its registry has scanned the file, and a brand-new
## script in a brand-new directory is not registered the moment it is written. A class that refers to
## its OWN class name - or to a sibling new class by name - fails to PARSE in that window, which has
## already silently disabled part of this pipeline once. So: an INSTANCE `populate()` instead of a
## static self-constructing factory, and a preloaded const for the set vocabulary.

## The set vocabulary, reached by path so this file has no dependency on `class_name` registration.
const SetScript := preload("res://scripts/animation/animation_set.gd")

## The shared action word, from `ActorState.action_name()`.
var action := ""
## The shared phase word, from `ActorState.phase_name()`: none / startup / active / recovery.
var phase := ""
## The owning component's OWN phase word, untranslated (WINDUP for the enemy, STARTUP for the
## player). Kept so a diagnostic can still show the original once both are normalized above.
var source_phase := ""
## The IDENTITY of the attack being performed, or "" when this actor is not attacking or reports no
## identity. THIS IS THE VALUE THE OLD INTENT VOCABULARY COULD NOT CARRY.
var attack_id := ""
## Whether an attack is committed at all, so "not attacking" and "attacking with no identity" stay
## distinguishable.
var attacking := false
## Seconds left in the current attack phase, or 0.0 outside an attack. Carried for a driver that
## wants to know how much of the gameplay window remains - NOT to extend it; gameplay owns the phase.
var remaining_time := 0.0

## The movement and lifecycle context that decorates an otherwise neutral actor.
var moving := false
var sprinting := false
var grounded := false
var turning := false
var speed := 0.0
var alive := true
## The hit reaction in one word: "none", "hurt" or "stagger".
var reaction := "none"
## Body yaw in radians and the unit forward vector, so a future directional set can pick a
## directional clip without re-deriving either from the body.
var yaw := 0.0
var forward := Vector3.ZERO

## RESERVED, AND DELIBERATELY UNPOPULATED TODAY. `variant` is where a pack's numbered variations
## (`..._light_attack_01` vs `_02`) will be selected, and `direction` is where a directional
## locomotion or directional attack clip will be chosen. Neither is set by anything in this pass,
## because the game cannot yet produce either distinction: there is no combo chain that advances
## from one variation to the next, and a committed attack owns the body so it cannot be performed
## while moving. They are declared so the shape is honest about where that content will land.
var variant := ""
var direction := ""


## Fill this intent with whatever `state` reports RIGHT NOW. Returns FALSE when there is no usable
## contract, which is a different statement from "idle" and must not be flattened into one.
func populate(state: ActorState) -> bool:
	if state == null or not is_instance_valid(state) or state.get_actor() == null:
		return false
	action = state.action_name()
	phase = state.phase_name()
	source_phase = state.source_phase_name()
	attacking = state.is_attacking()
	attack_id = state.attack_id() if attacking else ""
	remaining_time = state.phase_remaining()
	moving = state.is_moving()
	sprinting = state.is_sprinting()
	grounded = state.is_grounded()
	turning = state.is_turning()
	speed = state.flat_speed()
	alive = state.is_alive()
	reaction = state.reaction_name()
	yaw = state.facing_yaw()
	forward = state.facing_direction()
	return true


## The slot this intent should be looked up under in an `AnimationSet`. This is the single place the
## action vocabulary is translated into the animation slot vocabulary.
##
## The attack case is why this type exists: it resolves to `attack:<id>`, so WHICH attack is being
## performed survives into the lookup instead of being flattened into "attacking". The phase is
## deliberately NOT part of the key - a set supplies one complete motion per attack, and the phase is
## carried alongside as metadata for a driver that wants to sync against it.
func slot_key() -> String:
	match action:
		ActorState.ACTION_DEAD:
			return SetScript.SLOT_DEAD
		ActorState.ACTION_STAGGERED:
			return SetScript.SLOT_STAGGER
		ActorState.ACTION_DODGING:
			return SetScript.SLOT_DODGE
		ActorState.ACTION_PARRYING:
			return SetScript.SLOT_PARRY
		ActorState.ACTION_ATTACKING:
			return SetScript.attack_slot(attack_id)

	# Reaching here means the actor is NEUTRAL. The same contract's reaction and movement describe
	# it - these are not a second opinion about the action, they only decorate an actor at rest.
	if reaction == "hurt":
		return SetScript.SLOT_HURT
	if sprinting:
		return SetScript.SLOT_SPRINT
	if moving:
		return SetScript.SLOT_LOCOMOTION
	return SetScript.SLOT_IDLE


## The movement context of this instant, named rather than numeric: "stationary", "moving" or
## "sprinting". Recorded for the future "running" attack variants, which are NOT reachable today -
## a committed attack owns the body and stops locomotion, so an attack is always performed
## stationary. Reported honestly rather than pretending the variant exists.
func locomotion_context() -> String:
	if sprinting:
		return "sprinting"
	if moving:
		return "moving"
	return "stationary"


## One readable line, for a log or a probe report. Every value that was carried is printed, so an
## intent can never be summarised as something it is not.
func summary() -> String:
	var parts: Array = [action]
	if phase != ActorState.PHASE_NONE:
		parts.append(phase)
	if not attack_id.is_empty():
		parts.append("id=%s" % attack_id)
	parts.append(locomotion_context())
	if not alive:
		parts.append("dead")
	return "%s | slot=%s" % [" ".join(PackedStringArray(parts)), slot_key()]
