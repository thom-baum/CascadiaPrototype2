class_name HitFeedbackDebug
extends Node3D
## Temporary in-world hit confirmation (Milestone 4 observability pass).
##
## Milestone 4 could be BUILT and still not be SEEN: a swing produced no in-world
## sign that the object standing in front of the player was the object that lost
## health, so "I think the target took damage" could not become "I can see this
## target get hit". This closes that gap from the world side:
##
##   - a floating damage number parented to the STRUCK ACTOR, so the number
##     belongs to the thing that was actually hit rather than to a HUD row that
##     might be misread
##   - a brief bright flash on that actor's mesh
##
## It also prints one line per hit, so the feedback path is verifiable from
## output and not only by eye.
##
## It reads no input and decides nothing: it listens to the player's attack
## volume and reports what the damage system already resolved.
##
## Development feedback, not final presentation. Listed in
## CASCADIA_DELETION_MANIFEST.md.

## Seconds the floating number lives.
const FLOAT_TIME := 1.2
## How far the number rises over its life, in metres.
const RISE_SPEED := 1.2
## Seconds the struck mesh stays flashed.
const FLASH_TIME := 0.35
## Height above the actor's origin where the number starts.
const SPAWN_HEIGHT := 1.5

var _combat: PlayerCombat
var _hitbox: HitboxComponent
var _hits := 0


func _ready() -> void:
	_connect()


func _connect() -> void:
	_combat = get_tree().get_first_node_in_group(
		PlayerCombat.GROUP_PLAYER_COMBAT) as PlayerCombat
	if _combat == null:
		return
	var actor := _combat.get_parent()
	if actor == null:
		return
	_hitbox = actor.get_node_or_null("AttackHitbox") as HitboxComponent
	if _hitbox == null:
		push_warning("HitFeedbackDebug: no AttackHitbox under %s" % actor.name)
		return
	if not _hitbox.hit_landed.is_connected(_on_hit_landed):
		_hitbox.hit_landed.connect(_on_hit_landed)


func _on_hit_landed(event: DamageEvent) -> void:
	var victim := event.victim as Node3D
	if victim == null:
		return
	_hits += 1
	_spawn_number(victim, event.amount)
	_flash(victim)
	print("[HITFX] %s struck for %.0f  (feedback #%d)" % [
		victim.name, event.amount, _hits])


## A Label3D parented to the struck actor. Parenting it to the actor is the point:
## the number travels with, and belongs to, the object that was hit.
func _spawn_number(victim: Node3D, amount: float) -> void:
	var label := Label3D.new()
	label.name = "HitNumber"
	label.text = "-%d" % int(round(amount))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 64
	label.pixel_size = 0.005
	label.outline_size = 20
	label.modulate = Color(1.0, 0.86, 0.32, 1.0)
	label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	victim.add_child(label)
	label.position = Vector3(0.0, SPAWN_HEIGHT, 0.0)

	var tween := create_tween()
	tween.tween_property(label, "position",
		Vector3(0.0, SPAWN_HEIGHT + RISE_SPEED, 0.0), FLOAT_TIME)
	tween.parallel().tween_property(label, "modulate:a", 0.0, FLOAT_TIME)
	tween.tween_callback(label.queue_free)


## A short overlay flash, so the struck actor is obvious even if the number is
## missed. Uses material_overlay because MeshInstance3D has no modulate.
func _flash(victim: Node3D) -> void:
	var mesh := _find_mesh(victim)
	if mesh == null:
		return
	var flash := StandardMaterial3D.new()
	flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.albedo_color = Color(1.0, 0.5, 0.4, 0.9)
	mesh.material_overlay = flash
	var tween := create_tween()
	tween.tween_property(flash, "albedo_color:a", 0.0, FLASH_TIME)
	tween.tween_callback(func() -> void:
		if is_instance_valid(mesh):
			mesh.material_overlay = null)


func _find_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
