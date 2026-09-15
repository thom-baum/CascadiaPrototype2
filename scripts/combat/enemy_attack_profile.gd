class_name EnemyAttackProfile
extends Resource
## The DATA half of one enemy archetype (Milestone 15 - shared combatant foundation).
##
## WHY THIS EXISTS. EnemyAttacker was the project's only attacker and its numbers were
## scene-authored exports on the component itself. That is correct for ONE enemy and wrong
## for two: a second variant would have meant a second scene holding the same script with
## different numbers pasted into it, and nothing in the project recording that those
## numbers are a VARIANT rather than a retune of the original.
##
## This resource is that record. It holds the tuning an archetype is allowed to change,
## and EnemyAttacker copies it into its own exported fields at _ready().
##
## THE EXPORTED FIELDS ARE NOT REMOVED, and that is deliberate. Every diagnostic probe in
## the project reads them (`_attacker.windup`, `_attacker.damage`, `_attacker.engage_range`
## and friends), the running state machine only ever reads them, and a scene that assigns
## no profile must keep behaving exactly as it does today. So this resource SEEDS those
## fields rather than replacing them.
##
## AUTHORITY, stated plainly: the copy is one-way and one-time, at _ready(). A profile can
## therefore never retune an attack mid-commitment - which is the correct limit, because
## gameplay timing is authoritative in Cascadia and an attack whose numbers could change
## while it runs would not be. Assigning a profile to an already-running attacker changes
## nothing until it is ready again.
##
## DETECTION LIVES HERE (Milestone 17), exactly where this note always said it belonged. The
## original text below read "detection radius, aggro distance, deaggro distance, move speed,
## acceleration and turning behaviour ... belong here the day enemy AI does" - and that day is the
## minimal engagement pass, which gives an enemy the ability to notice and approach. So exactly ONE
## of those fields was added: `detection_radius`.
##
## WHAT IS STILL NOT HERE, on purpose: aggro distance, deaggro distance, threat, leash distance,
## target selection and pursuit pathing. Milestone 17 ships direct steering toward a single target
## that simply walks home when the target leaves detection, which needs none of them.
##
## `move_speed`, `acceleration` and `turn_speed_degrees` did NOT move here, and that is deliberate:
## they are properties of the ACTOR, and `ActorProfile.Locomotion` already holds them. An engaging
## enemy is given an `ActorProfile` on its `EnemyLocomotion` component, so a movement variant is a
## new `ActorProfile` rather than a second copy of the same numbers on the attack record.

@export_group("Attack")
## Shown in diagnostics. Names the variant in a log or a probe report.
@export var display_name := "Enemy Attack"
## Seconds of telegraphed commitment before the damage window opens. The actor is
## vulnerable for exactly this long.
@export var windup := 0.60
## Seconds the damage window stays open. One hit per target, no longer.
@export var active := 0.12
## Seconds of commitment after the window closes. Vulnerable again, so a mistimed dodge
## or parry is punished rather than free.
@export var recovery := 0.70
## Damage one hit from this attack applies.
@export var damage := 20.0

@export_group("Engagement")
## Radius, in metres, at which this enemy NOTICES its target and begins to engage it. Outside this
## radius the enemy stands at the mark its scene placed it on. Read by `EnemyLocomotion`, which asks
## its sibling attacker for it rather than keeping a second copy that could drift.
##
## It lives on the ATTACK record rather than the actor record on purpose: how close an enemy must be
## before it fights is a property of the engagement, and the range it fights at already lives here.
## 0.0 means this enemy notices nothing, which is the inert default every existing scene keeps.
@export var detection_radius := 0.0

## Flat distance at which the attacker commits to a swing. Outside this it stands and
## faces its target - though an enemy with an `EnemyLocomotion` component now WALKS in to this range
## instead, and stops `stop_margin` inside it so it cannot oscillate across the threshold.
@export var engage_range := 2.8
## Seconds of IDLE after recovery completes before the next swing may begin.
@export var attack_cooldown := 1.6
## Swing on its own cadence when the target is in range. OFF lets a probe drive the
## attacker by hand.
@export var auto_attack := true
## Turn to face the target while idle. Locked once an attack commits.
@export var face_target := true


## Total committed time, windup through recovery. The same sum EnemyAttacker exposes, so a
## profile can be compared with a live attacker without building one.
func total_duration() -> float:
	return windup + active + recovery


## The whole profile on one line, for a log line or a probe report. Every field is printed,
## so a profile can never be reported as something it is not.
func summary() -> String:
	return "%s: windup=%.2f active=%.2f recovery=%.2f damage=%.1f detect=%.1f range=%.2f cooldown=%.2f auto=%s face=%s" % [
		display_name, windup, active, recovery, damage, detection_radius, engage_range,
		attack_cooldown, str(auto_attack), str(face_target)]
