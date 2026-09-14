class_name FacingMarkerFeedbackDebug
extends Node3D
## Temporary presentation aid for playtesting (not shipping code).
##
## Reads the player's ATTACK PHASE and tints the facing marker so a swing is
## visible on the capsule. It exists because there is no animation system yet
## (the presentation boundary recorded in roadmap 8G.2 item 3), so a committed
## attack is otherwise completely invisible on the body.
##
## STRICTLY READ-ONLY on gameplay. It reads `PlayerCombat.state` and writes to
## exactly one thing: a material's `albedo_color`. It never starts, cancels,
## delays, extends or redirects an attack, imposes no timing of its own, and owns
## no gameplay state. The colour FOLLOWS the phase; the phase never follows the
## colour. Gameplay stays authoritative and this adapts to it - which is exactly
## how an animation clip will behave later (Milestone 15), at which point this
## file is deleted along with the primitive markers it decorates.
##
## It deliberately reads the phase rather than connecting to the attack signals:
## the phase is continuous state, so a mid-swing scene load or a missed signal
## cannot leave the marker stuck on the wrong colour.
##
## Attached to the `FacingMarker` node under `Player` in
## `scenes/test_environment.tscn`. Recorded in CASCADIA_DELETION_MANIFEST.md.
## Delete with the facing markers.

## The mesh whose colour reports the attack phase. Defaults to the "Nose" disc,
## which is this node's own child.
@export var marker_path: NodePath = NodePath("Nose")

## The player's attack state machine. This node is a child of `Player`, and so is
## `Combat`, hence the sibling path. A scene without one simply keeps the marker
## neutral - a missing combat system must never be an error here.
@export var combat_path: NodePath = NodePath("../Combat")

@export_group("Colours")
## No attack committed. The marker's authored amber.
@export var idle_color := Color(1, 0.62, 0.12, 1)
## Wind-up. Bright and hot, so the commitment is visible BEFORE the hit lands.
@export var startup_color := Color(1, 0.95, 0.45, 1)
## The damage window. Unmistakable, reading as the strike itself.
@export var active_color := Color(0.95, 0.16, 0.12, 1)
## Spent. Cool and dim, so a committed recovery cannot be mistaken for readiness.
@export var recovery_color := Color(0.34, 0.46, 0.62, 1)

## Print each phase change this adapter observes. Diagnostic.
@export var debug_logging := false

var _marker: MeshInstance3D
var _combat: PlayerCombat
var _material: StandardMaterial3D
## Last phase painted, so the material is written only when the phase changes
## rather than every frame.
var _last_state := -1


func _ready() -> void:
	_marker = get_node_or_null(marker_path) as MeshInstance3D
	_combat = get_node_or_null(combat_path) as PlayerCombat
	_material = _resolve_material()
	if _marker == null or _combat == null:
		# Say so rather than failing silently: a missing marker or Combat means
		# this aid is doing nothing, and that should be visible in the console.
		push_warning("[FACING] feedback disabled: marker=%s combat=%s" % [
			str(_marker != null), str(_combat != null)])
	# Paint the current phase immediately, so any entry state - including loading
	# mid-swing - shows the correct colour rather than whatever the material
	# happened to hold.
	_apply(_combat.state if _combat != null else PlayerCombat.State.IDLE)


## Presentation runs on the VISUAL frame, not the physics frame: nothing here
## feeds back into gameplay, so this must not compete with PlayerCombat for
## physics ordering.
func _process(_delta: float) -> void:
	if _combat == null or _material == null:
		return
	if _combat.state == _last_state:
		return
	_apply(_combat.state)


## The material to tint. Duplicated on first use, so this adapter can never
## mutate a resource that another node also draws with - the scene declares the
## amber disc and the blue badge separately today, and that must not be relied on.
func _resolve_material() -> StandardMaterial3D:
	if _marker == null:
		return null
	var source := _marker.material_override as StandardMaterial3D
	if source == null:
		source = _marker.get_active_material(0) as StandardMaterial3D
	if source == null:
		source = StandardMaterial3D.new()
	else:
		source = source.duplicate() as StandardMaterial3D
	_marker.material_override = source
	return source


## Map one attack phase onto one colour. The whole of this adapter's logic.
func _apply(state: int) -> void:
	_last_state = state
	if _material == null:
		return
	var chosen := idle_color
	var label := "IDLE"
	match state:
		PlayerCombat.State.STARTUP:
			chosen = startup_color
			label = "STARTUP"
		PlayerCombat.State.ACTIVE:
			chosen = active_color
			label = "ACTIVE"
		PlayerCombat.State.RECOVERY:
			chosen = recovery_color
			label = "RECOVERY"
	_material.albedo_color = chosen
	if debug_logging:
		print("[FACING] attack phase %s -> marker %s" % [label, str(chosen)])
