class_name AttackDefinition
extends Resource
## One attack's gameplay timing and damage (Milestone 4).
##
## Gameplay is authoritative: these numbers ARE the attack. Animation, effects
## and sound are adapters that must conform to this timeline, never define it.
##
## The three phases are the whole contract:
##
##   STARTUP   committed, no damage yet. Cannot be cancelled from here.
##   ACTIVE    the damage window. Open for exactly this long, no longer.
##   RECOVERY  committed, damage window already closed.
##
## Nothing here reads input, owns state or touches the scene. It is data.

## Shown in diagnostics and, later, drive the animation adapter.
@export var display_name := "Attack"
## The STABLE MACHINE KEY for this attack, and the identity presentation is keyed by.
##
## `display_name` is for a human reading a log; THIS is the value an `AnimationSet` is addressed by
## (Milestone 21). It is separate and explicit so renaming an attack for readability cannot silently
## repoint its clips, and so an animation set can be swapped without touching this file.
##
## Leave it EMPTY and the key is derived from `display_name` instead (see `key()`), so an attack that
## never names one still has a usable identity.
@export var id := ""
## Seconds of commitment before the damage window opens.
@export var startup := 0.20
## Seconds the damage window stays open.
@export var active := 0.10
## Seconds of commitment after the damage window closes.
@export var recovery := 0.35
## Damage applied by one hit from this attack.
@export var damage := 15.0


## Total committed time, startup through recovery.
func total_duration() -> float:
	return startup + active + recovery


## The stable key for this attack: the explicit `id` when one is authored, otherwise a slug of
## `display_name`. Always non-empty for an attack that has a name, because a lookup key that can
## vanish silently is a lookup that can silently fail.
func key() -> String:
	if not String(id).is_empty():
		return slug(id)
	return slug(display_name)


## Lowercase, underscore-separated, punctuation dropped. Applied to BOTH the explicit id and the
## derived display name, so "Light 1", "light_1" and "LIGHT-1" all resolve to one key and an
## animation-set author cannot be defeated by capitalization or a stray hyphen.
static func slug(text: String) -> String:
	var source := String(text)
	var out := ""
	var pending_separator := false
	for i in source.length():
		var c := source[i].to_lower()
		var is_word := (c >= "a" and c <= "z") or (c >= "0" and c <= "9")
		if is_word:
			if pending_separator and not out.is_empty():
				out += "_"
			out += c
			pending_separator = false
		else:
			pending_separator = true
	return out


## Build one in code. Keeps a starting attack beside the class that uses it
## rather than in a separate resource file that has to be kept in sync.
##
## `p_id` is the last parameter and OPTIONAL, so every existing call site keeps working unchanged
## while a caller that cares about animation identity can name its attack explicitly.
static func make(p_name: String, p_startup: float, p_active: float, p_recovery: float, p_damage: float, p_id: String = "") -> AttackDefinition:
	var definition := AttackDefinition.new()
	definition.display_name = p_name
	definition.id = p_id
	definition.startup = p_startup
	definition.active = p_active
	definition.recovery = p_recovery
	definition.damage = p_damage
	return definition
