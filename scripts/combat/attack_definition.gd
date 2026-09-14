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


## Build one in code. Keeps a starting attack beside the class that uses it
## rather than in a separate resource file that has to be kept in sync.
static func make(p_name: String, p_startup: float, p_active: float, p_recovery: float, p_damage: float) -> AttackDefinition:
	var definition := AttackDefinition.new()
	definition.display_name = p_name
	definition.startup = p_startup
	definition.active = p_active
	definition.recovery = p_recovery
	definition.damage = p_damage
	return definition
