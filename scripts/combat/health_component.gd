class_name HealthComponent
extends Node
## Health for one damageable actor (Milestone 2).
##
## Owns health and nothing else: a maximum, a current value, a dead flag, and the
## single place where damage is applied. It does not know what an attack is, who
## swung it, or when a hitbox should be active. Those are gameplay decisions that
## arrive later, already resolved, as a DamageEvent.
##
## Every point of damage in Cascadia passes through apply_damage(). It returns
## whether the damage actually landed, which is what lets a hitbox report an
## honest hit_landed signal instead of assuming contact meant damage.
##
## Attach one per damageable actor, as a direct child of the body, named "Health"
## so a HurtboxComponent can find it without an explicit path.

## Emitted whenever the current value changes, including on reset.
signal health_changed(current: float, maximum: float)

## Emitted only when damage is actually applied.
signal damaged(event: DamageEvent, current: float, maximum: float)

## Emitted once, when current health first reaches zero.
signal died(event: DamageEvent)

@export var max_health := 100.0

## Print one line per accepted or refused damage application. Diagnostic.
@export var debug_logging := true

## Every health component joins this group, so tooling - and later lock-on and
## enemy AI - can enumerate damageable actors without hard-coded scene paths.
const GROUP_DAMAGEABLE := &"damageable"

var current_health := 0.0
var is_dead := false

## How many applications actually changed health. Diagnostic. This is what makes
## "damage applies exactly once per valid hit" checkable from a log rather than
## taken on trust.
var applied_count := 0


func _ready() -> void:
	add_to_group(GROUP_DAMAGEABLE)
	reset()


## Restore to full and clear the dead flag. Used at spawn, on respawn, and by the
## Milestone 2 diagnostic probe.
func reset() -> void:
	current_health = max_health
	is_dead = false
	applied_count = 0
	health_changed.emit(current_health, max_health)
	_log("reset to %.1f" % current_health)


## Restore to an EXACT saved value (Milestone 10 world-state restore).
##
## Deliberately separate from reset(). reset() means "this actor starts fresh" and is what
## spawn, respawn and the arena reset use. This means "put this actor back to what a snapshot
## recorded", which is a different intent with a different value.
##
## CLAMPED on purpose: a corrupt or hand-edited save must not be able to set health above
## maximum or below zero. The value is validated at the boundary rather than trusted.
func restore_to(value: float, dead: bool) -> void:
	current_health = clampf(value, 0.0, max_health)
	is_dead = dead or current_health <= 0.0
	health_changed.emit(current_health, max_health)
	_log("restored to %.1f (dead=%s)" % [current_health, str(is_dead)])


## Apply one damage event.
## Returns true only when health actually changed, so a caller can tell a real
## hit from one refused because the actor was already dead.
func apply_damage(event: DamageEvent) -> bool:
	if event == null:
		return false

	if is_dead:
		_log("refused: already dead")
		return false

	if event.amount <= 0.0:
		_log("refused: non-positive amount (%.2f)" % event.amount)
		return false

	var before := current_health
	current_health = maxf(0.0, current_health - event.amount)
	applied_count += 1
	event.was_lethal = current_health <= 0.0

	_log("applied %.1f  (%.1f -> %.1f) from %s" % [
		event.amount, before, current_health, _source_name(event)])

	health_changed.emit(current_health, max_health)
	damaged.emit(event, current_health, max_health)

	# Guarded so a lethal hit emits died exactly once even if more damage arrives.
	if current_health <= 0.0 and not is_dead:
		is_dead = true
		_log("died")
		died.emit(event)

	return true


## Current health as 0..1 of maximum. For HUD bars in a later milestone.
func health_fraction() -> float:
	if max_health <= 0.0:
		return 0.0
	return current_health / max_health


func _source_name(event: DamageEvent) -> String:
	if event.source == null:
		return "none"
	return String(event.source.name)


func _log(message: String) -> void:
	if debug_logging:
		print("[DAMAGE] %s: %s" % [name, message])
