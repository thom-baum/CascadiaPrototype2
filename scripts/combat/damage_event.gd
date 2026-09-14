class_name DamageEvent
extends RefCounted
## One resolved attempt to damage an actor (Milestone 2).
##
## A plain data object. It carries no behaviour and no timing: whoever owns the
## attack decides when a hitbox is active, the hitbox decides which hurtbox it
## reached, and the HealthComponent decides whether the damage actually applies.
##
## Using one object keeps call sites readable and lets later milestones add
## fields (poise damage, damage type, knockback) without changing every
## signature that passes a hit around.

## How much health this event removes.
var amount := 0.0

## The actor that caused the damage, if any. Null for environmental or
## diagnostic damage, which is why the hitbox cannot rely on it being set.
var source: Node = null

## The HitboxComponent that produced this event, if any.
var hitbox: Node = null

## The actor that took the damage. Set by the hitbox from the hurtbox it reached,
## so hit confirmation can name what was struck instead of guessing.
var victim: Node = null

## World position of the hit. Placeholder for effects, audio and hit reaction.
var position := Vector3.ZERO

## Set by HealthComponent when this event reduced the target to zero health.
var was_lethal := false


func _to_string() -> String:
	var source_name := "none"
	if source != null:
		source_name = String(source.name)
	return "DamageEvent(amount=%.1f, source=%s)" % [amount, source_name]
