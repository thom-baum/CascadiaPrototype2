class_name HitboxComponent
extends Area3D
## A volume that deals damage during an explicit window (Milestone 2).
##
## Deliberately separate from physical collision: this Area3D sits on
## GameLayers.HITBOX and masks GameLayers.HURTBOX only, so it can never move a
## body, and a body can never absorb a hit.
##
## Windows, not swings. Gameplay calls activate() when an attack becomes active
## and deactivate() when it ends. The hitbox guarantees any one hurtbox is hit
## at most ONCE per activation, so a window held open across many physics frames
## cannot apply damage repeatedly, and an overlap that flickers on and off
## cannot double-hit.
##
## Timing belongs to whoever calls activate(). Nothing here reads input and
## nothing here decides when an attack should happen - that is Milestone 5.

## Emitted once per hurtbox that actually took damage in the current window.
signal hit_landed(event: DamageEvent)

## Every hitbox joins this group, so a consumer of confirmed hits - the HitStop service -
## can enumerate them without a hard-coded scene path. The same resolution pattern the
## attacker, locomotion and health modules already use.
const GROUP_HITBOX := &"hitbox"

@export var damage := 10.0
## The actor that owns this hitbox. Its own hurtboxes are never hit. Leave empty
## for a neutral hitbox that may hit anything, which is what the diagnostic uses.
@export var source_actor_path: NodePath
## Print each window and each skip. Diagnostic.
@export var debug_logging := false

var active := false

## Instance IDs of hurtboxes already hit during the current window.
var _already_hit: Dictionary = {}
## How many windows have been opened. Diagnostic.
var window_count := 0
var _source_actor: Node


func _ready() -> void:
	# The group is how a confirmed-hit consumer enumerates hitboxes without a scene path.
	add_to_group(GROUP_HITBOX)
	collision_layer = GameLayers.HITBOX
	collision_mask = GameLayers.HURTBOX
	# Monitoring stays ON for the whole lifetime. It is deliberately NOT the
	# window gate. Measured on this project: closing and reopening a window with
	# monitoring toggling inside the same frame loses the hit - the engine does
	# not re-detect an already-overlapping area in time, so window 2 applied
	# nothing while frames-separated windows applied correctly. The window is the
	# `active` flag, and overlaps are tracked continuously.
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	if not String(source_actor_path).is_empty():
		_source_actor = get_node_or_null(source_actor_path)


func _physics_process(_delta: float) -> void:
	if not active:
		return
	_sweep()


## Check everything currently overlapping. area_entered covers a hurtbox that
## walks into an already-open window; this covers a window opened around a
## hurtbox that is already overlapping. Both funnel through _try_hit, which
## de-duplicates, so calling this often is safe.
func _sweep() -> void:
	for area in get_overlapping_areas():
		_try_hit(area)


## Open a new damage window. Every hurtbox may be hit once from here until the
## next activate() or deactivate().
func activate() -> void:
	window_count += 1
	_already_hit.clear()
	active = true
	# Sweep on the same frame the window opens, so a hurtbox that is already
	# overlapping is hit now rather than one frame later.
	_sweep()
	if debug_logging:
		print("[HITBOX] %s: window %d open (damage %.1f)" % [name, window_count, damage])


func deactivate() -> void:
	active = false
	if debug_logging:
		print("[HITBOX] %s: window %d closed" % [name, window_count])


func _on_area_entered(area: Area3D) -> void:
	if not active:
		return
	_try_hit(area)


func _try_hit(area: Node) -> void:
	var hurt := area as HurtboxComponent
	if hurt == null:
		return

	# Never hit the actor that owns this hitbox. A neutral hitbox has no source
	# and is therefore allowed to hit anything.
	if _source_actor != null and hurt.actor == _source_actor:
		return

	var id := hurt.get_instance_id()
	if _already_hit.has(id):
		return
	# Marked before the attempt on purpose: a hurtbox that refuses the damage
	# (already dead) must still not be re-attempted inside the same window.
	_already_hit[id] = true

	var event := DamageEvent.new()
	event.amount = damage
	event.source = _source_actor
	event.hitbox = self
	event.victim = hurt.actor
	event.position = global_position

	if hurt.receive_hit(event):
		hit_landed.emit(event)
