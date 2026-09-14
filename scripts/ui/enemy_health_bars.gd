class_name EnemyHealthBars
extends CanvasLayer
## Milestone 14 - a damage-revealed health bar over each engaged enemy.
##
## WHAT THIS IS: a bar that appears over an enemy when it is ATTACKED, stays while that enemy is
## engaged, and disappears when it is not. It exists so damage, enemy survivability and combat tuning
## are legible during testing. It is NOT a permanent HUD decision - see roadmap section 8R.
##
## WHAT IT OWNS: one reveal TIMESTAMP per tracked enemy, plus the Controls it draws. It owns NO health
## value, no aggro state and no lock state. Every value it shows is read from its owner:
##
##   health fraction   HealthComponent.health_fraction()   the enemy's own health
##   reveal            HealthComponent.damaged signal      the enemy's own damage report
##   lock state        TargetingComponent.is_locked() / get_current_target()
##
## "ENGAGED" IS A RECORDED STAND-IN - read this before changing the rule.
## This project has NO aggro, threat or deaggro system; enemy AI is a deferred milestone, so there is
## nothing to ask whether an enemy is aggroed. The honest substitute implemented here is:
##
##   DAMAGE REVEALS, and the bar is HELD while the enemy was damaged within `hold_seconds` OR the
##   player currently holds a lock on it.
##
## Lock-on counts as engagement because it is the only real, player-DECLARED "I am fighting this one"
## signal that exists today, and it deliberately does NOT reveal an undamaged enemy. When enemy AI
## arrives, its aggro authority should replace that second condition - `is_engaged()` is the single
## function that decides, and therefore the one place to change.
##
## WHY EVERY CONTROL IS MOUSE_FILTER_IGNORE: light and heavy attacks are bound to the MOUSE BUTTONS,
## and `focus_input_routing_probe_debug` enumerates every VISIBLE Control under every CanvasLayer and
## fails on one with a non-IGNORE filter overlapping the centre of the viewport. A bar sitting dead
## centre over a close enemy must therefore never be able to take a click.

## The group HealthComponent joins. Enemies are enumerated from it, so no actor list is hard-coded.
const GROUP_DAMAGEABLE := &"damageable"
## The group TargetingComponent joins.
const GROUP_TARGETING := &"targeting"
## The group this module joins, so a probe or a debug readout can resolve it without a scene path -
## the same resolution pattern the HUD, the indicator and the targeting module all use.
const GROUP_ENEMY_HEALTH_BARS := &"enemy_health_bars"

@export_group("Wiring")
## The targeting module to read. Leave EMPTY to resolve it through its own group.
@export var targeting_path: NodePath

@export_group("Engagement (STAND-IN - see the class comment and roadmap 8R)")
## How long a bar stays after the last damage, in seconds. A FEEL value, exported on purpose so it can
## be tuned without a code change.
@export var hold_seconds := 4.0
## Whether holding a lock also holds that enemy's bar. The only player-declared engagement signal that
## exists today; it does NOT reveal an undamaged enemy.
@export var hold_while_locked := true

@export_group("Bar")
@export var bar_width := 96.0
@export var bar_height := 9.0
## How far above the enemy's origin the bar floats, in metres.
@export var head_offset := 2.05
@export var fill_color := Color(0.78, 0.24, 0.24, 1)
@export var background_color := Color(0.06, 0.07, 0.09, 0.85)

## How many times a bar has APPEARED. Diagnostic: it separates "never revealed" from "revealed and
## then expired", which a single on-screen check cannot tell apart.
var reveals := 0
## How many times a bar has been HIDDEN again. Diagnostic, same reason.
var hides := 0

var _targeting: TargetingComponent
var _root: Control
var _camera: Camera3D
## Seconds of GAMEPLAY time since boot, advanced in `_process`. Used instead of a wall clock so the hold
## window FREEZES while the tree is paused, exactly like every other frame-driven value.
var _elapsed := 0.0
## One record per tracked enemy:
##     actor -> {"health": HealthComponent, "root": Control, "fill": ColorRect, "revealed_at": float}
## The ONLY state is the timestamp and the Controls. The health value is read fresh every frame.
var _entries: Dictionary = {}


func _ready() -> void:
	# ABOVE the world, BELOW the debug overlays, so one F1 press still clears the debug layer while
	# this feedback stays visible in the plain shipped game.
	layer = 2
	add_to_group(GROUP_ENEMY_HEALTH_BARS)
	_build_root()
	_resolve()
	# DEFERRED, and the ordering matters: `HealthComponent._ready()` is what joins the damageable
	# group, and this node sits BEFORE the actors in tree order. A deferred scan is the first moment
	# that group is complete and every actor is where the scene authored it.
	_scan.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	var locked := _locked_target()
	for actor in _entries.keys():
		if actor == null or not is_instance_valid(actor):
			_forget(actor)
			continue
		_sync_bar(actor, _entries[actor], locked)


# --- The engagement rule -----------------------------------------------------

## THE ONE PLACE THAT DECIDES WHETHER AN ENEMY IS ENGAGED, and the seam where enemy AI will later be
## asked instead of this stand-in. See the class comment and roadmap section 8R.
func is_engaged(actor: Node3D, locked: Node3D, recently_damaged: bool) -> bool:
	if recently_damaged:
		return true
	if hold_while_locked and locked != null and locked == actor:
		return true
	return false


## The actor the player currently holds a lock on, or null. Read from the owner, never cached.
func _locked_target() -> Node3D:
	var targeting := _get_targeting()
	if targeting == null or not targeting.is_locked():
		return null
	var target: Node3D = targeting.get_current_target()
	if target == null or not is_instance_valid(target):
		return null
	return target


# --- Scanning and construction ----------------------------------------------

## Register every damageable actor EXCEPT the player. Deferred from `_ready()` so the group is full.
##
## Scanned ONCE by design: the shipped arena spawns no damageable actor after boot, and a re-scan would
## silently add a bar for anything a diagnostic spawned mid-run. `rescan()` exists for tooling.
func _scan() -> void:
	if get_tree() == null:
		return
	var player := get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	for node in get_tree().get_nodes_in_group(GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var actor := health.get_parent() as Node3D
		# THE PLAYER IS NOT AN ENEMY. The player already has the HUD's own health bar, and this module
		# is enemy feedback - giving the player a floating bar too would be a second health display.
		if actor == null or actor == player:
			continue
		_track(actor, health)


## Re-run the scan. For tooling and probes, NOT called automatically.
func rescan() -> void:
	_scan()


func _track(actor: Node3D, health: HealthComponent) -> void:
	if _entries.has(actor):
		return

	var root := Control.new()
	root.name = "Bar_%s" % String(actor.name)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	_root.add_child(root)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = background_color
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.size = Vector2(bar_width, bar_height)
	root.add_child(background)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = fill_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inset by one pixel so the background reads as a border on every side.
	fill.position = Vector2(1.0, 1.0)
	fill.size = Vector2(bar_width - 2.0, bar_height - 2.0)
	root.add_child(fill)

	_entries[actor] = {
		"health": health,
		"root": root,
		"fill": fill,
		"revealed_at": -1000000.0,
	}

	# THE REVEAL. The enemy's OWN damage report is what makes the bar appear. Nothing here watches the
	# player's attack, and nothing here re-derives damage from a health difference.
	var callable := Callable(self, "_on_actor_damaged").bind(actor)
	if not health.is_connected(&"damaged", callable):
		health.connect(&"damaged", callable)


## An enemy took damage: start (or restart) its hold window. `bind(actor)` puts the actor AFTER the
## signal's own three arguments, which is why it is the fourth parameter here.
func _on_actor_damaged(_event: DamageEvent, _current: float, _maximum: float, actor: Node3D) -> void:
	if not _entries.has(actor):
		return
	var entry: Dictionary = _entries[actor]
	entry["revealed_at"] = _elapsed
	_entries[actor] = entry


# --- Drawing -----------------------------------------------------------------

func _sync_bar(actor: Node3D, entry: Dictionary, locked: Node3D) -> void:
	var root := entry["root"] as Control
	if root == null or not is_instance_valid(root):
		return
	var health := entry["health"] as HealthComponent
	if health == null or not is_instance_valid(health):
		root.visible = false
		return

	var recently_damaged: bool = (_elapsed - float(entry["revealed_at"])) < hold_seconds
	if not is_engaged(actor, locked, recently_damaged):
		_hide(root)
		return

	# The bar is anchored in the WORLD, so it needs that enemy's screen position. Behind the camera and
	# off-screen both mean "not visible", which is not the same as "not engaged" - the hold continues.
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		_hide(root)
		return
	var head := actor.global_position + Vector3(0.0, head_offset, 0.0)
	if _camera.is_position_behind(head):
		_hide(root)
		return
	var screen := _camera.unproject_position(head)
	var viewport_size := get_viewport().get_visible_rect().size
	if screen.x < -bar_width or screen.x > viewport_size.x + bar_width \
			or screen.y < -bar_height or screen.y > viewport_size.y + bar_height:
		_hide(root)
		return

	# The fill is the owner's OWN fraction, read this frame - never a value this module stored.
	var fraction := clampf(health.health_fraction(), 0.0, 1.0)
	var fill := entry["fill"] as ColorRect
	if fill != null and is_instance_valid(fill):
		fill.size.x = maxf(0.0, (bar_width - 2.0) * fraction)

	root.position = screen - Vector2(bar_width * 0.5, bar_height * 0.5)
	if not root.visible:
		root.visible = true
		reveals += 1


func _hide(root: Control) -> void:
	if root.visible:
		root.visible = false
		hides += 1


func _forget(actor: Variant) -> void:
	if not _entries.has(actor):
		return
	var entry: Dictionary = _entries[actor]
	var root: Control = entry.get("root")
	if root != null and is_instance_valid(root):
		root.queue_free()
	_entries.erase(actor)


# --- Read-only reports -------------------------------------------------------

## How many bars are currently showing. For a probe or a debug readout.
func visible_count() -> int:
	var shown := 0
	for actor in _entries.keys():
		if actor == null or not is_instance_valid(actor):
			continue
		var root: Control = _entries[actor]["root"]
		if root != null and is_instance_valid(root) and root.visible:
			shown += 1
	return shown


## Whether one specific actor's bar is showing right now.
func is_showing(actor: Node3D) -> bool:
	if not _entries.has(actor):
		return false
	var root: Control = _entries[actor]["root"]
	return root != null and is_instance_valid(root) and root.visible


## How many enemies are tracked at all. Diagnostic: separates "not tracked" from "tracked and hidden".
func tracked_count() -> int:
	return _entries.size()


## Whether this actor is tracked at all. Separates "not an enemy" from "an enemy with no bar up".
func is_tracked(actor: Node3D) -> bool:
	return _entries.has(actor)


## The CURRENT WIDTH IN PIXELS of one actor's fill, or -1.0 when it is not tracked. This is the drawn
## value, read back from the fill itself rather than recomputed, so a probe measuring it is measuring
## what is actually on screen and not a second copy of the same arithmetic.
func fill_width_of(actor: Node3D) -> float:
	if not _entries.has(actor):
		return -1.0
	var fill: ColorRect = _entries[actor]["fill"]
	if fill == null or not is_instance_valid(fill):
		return -1.0
	return fill.size.x


## The hold window remaining for one actor, in seconds. Negative once it has expired.
func hold_remaining(actor: Node3D) -> float:
	if not _entries.has(actor):
		return -1000000.0
	return hold_seconds - (_elapsed - float(_entries[actor]["revealed_at"]))


# --- Resolution --------------------------------------------------------------

func _build_root() -> void:
	_root = Control.new()
	_root.name = "Bars"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)


func _resolve() -> void:
	if not String(targeting_path).is_empty():
		_targeting = get_node_or_null(targeting_path) as TargetingComponent
	if _targeting == null and get_tree() != null:
		_targeting = get_tree().get_first_node_in_group(GROUP_TARGETING) as TargetingComponent


func _get_targeting() -> TargetingComponent:
	if _targeting == null or not is_instance_valid(_targeting):
		_resolve()
	return _targeting
