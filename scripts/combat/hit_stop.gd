class_name HitStop
extends Node
## The GAMEPLAY hitstop for a CONFIRMED hit (Milestone 18 - combat feedback).
##
## THE PROBLEM THIS EXISTS FOR. Cascadia could damage an actor and could play a damage
## number, but a landed hit had NO time component at all: the two participants carried on
## moving and advancing their committed phases on the very frame the hit landed. A hit
## that does not stop the world for a moment does not read as a hit.
##
## WHAT IT DOES, in one sentence: when a hitbox reports that a hit ACTUALLY LANDED, this
## service FREEZES the two participants - the actor that dealt the hit and the actor that
## took it - for a short, configurable duration.
##
## THE ONLY INPUT is `HitboxComponent.hit_landed`, the project's existing CONFIRMED-hit
## signal. It is emitted only after damage really applied, so a dodged, parried, refused or
## already-dead-facing hit never produces a hitstop. Nothing here reads health, re-derives
## a hit from a health difference, or hears about an attacker.
##
## WHY NOT Engine.time_scale. `CascadiaInput._keep_clock_running()` forces
## `Engine.time_scale` back to 1.0 whenever it is <= 0.0 while the tree is not paused, so a
## zero-scale hitstop would be erased on the very next frame. A non-zero micro-scale is
## refused too: the recorded project rule is that NOTHING in Cascadia writes
## `Engine.time_scale`, and the focus and recovery probes assert it stays exactly 1.0.
##
## WHY NOT get_tree().paused. Pause is owned by PauseMenu and is a different concern; the
## probes assert pause state, and pausing the whole tree to sell one exchange would stop
## every unrelated system.
##
## THE MECHANISM, deliberately the narrowest one available. The two participant SUBTREES
## have their per-frame callbacks switched off with `propagate_call` over `set_process` and
## `set_physics_process` - the idiom Godot's own documentation recommends for freezing a
## subtree. `process_mode` is NEVER touched, so a participant can never be stranded in
## PROCESS_MODE_DISABLED; two existing probes assert the player stays
## PROCESS_MODE_INHERIT and they are this mechanism's regression guard. `set_process_input`
## is deliberately NOT called: the input layer is a separate root node that must keep
## buffering presses while a participant is frozen, so a press that arrives during a
## hitstop is not lost.
##
## THE CLOCK. The countdown is read from `Time.get_ticks_msec()`, NEVER accumulated from
## delta. This service is a direct child of the game root and is therefore never inside a
## frozen subtree, and an unscaled clock is what makes the release point independent of the
## frames it is measuring.
##
## ALWAYS RELEASED. A second hit during a freeze EXTENDS the release point and adds any new
## participant - it never freezes the same node twice and never shortens the freeze. An
## expired freeze is released on the frame it expires, and `_exit_tree` releases as a
## safety net, so no actor can be left with processing disabled.
##
## Attach ONE of these to the game root, as a DIRECT CHILD of the game root and a sibling
## of the world - never inside an actor, because a participant's own freeze must never be
## able to disable the clock that releases it.

## Every hitstop service joins this group, so a probe or a future setting can resolve it
## without a hard-coded scene path.
const GROUP_HIT_STOP := &"hit_stop"

@export_group("Timing")
## Seconds the two participants stay frozen. A short, unscaled wall-clock duration: long
## enough to read as impact, short enough that it never becomes a stall.
@export var duration := 0.075

@export_group("Policy")
## Master switch. false makes this service inert - it still watches hitboxes and still
## counts, and freezes nothing - so hitstop can be turned off for tuning or for a probe
## that must measure something else.
@export var enabled := true

## Print each freeze, extension and release. Diagnostic.
@export var debug_logging := false

## Freezes started since load.
var freezes := 0
## Freezes that were EXTENDED by a second hit rather than started again.
var extensions := 0
## Freezes released since load. Counted separately from `freezes` so a freeze that never
## released is visible as freezes > releases rather than inferred.
var releases := 0

## The participant bodies currently frozen.
var _targets: Array[Node] = []
var _frozen := false
## When the current freeze ends, in `Time.get_ticks_msec()` milliseconds.
var _release_at_ms := 0
## Instance ids of hitboxes already subscribed to, so re-scanning never double-connects.
var _watched: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP_HIT_STOP)
	# Processing is enabled explicitly rather than relied on: this node's whole job is the
	# per-frame release check, and a service that silently stopped processing would leave
	# every participant it froze stuck.
	set_process(true)
	_watch_hitboxes()


func _process(_delta: float) -> void:
	# Enemies and hitboxes can be added at runtime, so the population is re-scanned. Cheap at
	# this scale, and it is what keeps the wiring enumeration-driven rather than bound to a
	# fixed actor list.
	_watch_hitboxes()
	if not _frozen:
		return
	if Time.get_ticks_msec() >= _release_at_ms:
		release_now()


## Safety net: a freeze must never outlive the service that created it. Reached only when
## the tree is being torn down with a freeze still running.
func _exit_tree() -> void:
	release_now()


# --- Queries -----------------------------------------------------------------

## Whether a hitstop is running right now.
func is_frozen() -> bool:
	return _frozen


## How many participants are frozen right now.
func frozen_count() -> int:
	return _targets.size()


## Seconds left of the current freeze, or 0 when none is running.
func remaining_seconds() -> float:
	if not _frozen:
		return 0.0
	return maxf(0.0, float(_release_at_ms - Time.get_ticks_msec()) / 1000.0)


## The hitstop service in this tree, or null when there is none. Lets a probe or a future
## consumer resolve it without a scene path.
static func find_hit_stop(tree: SceneTree) -> HitStop:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP_HIT_STOP) as HitStop


# --- Freezing -----------------------------------------------------------------

## The CONFIRMED-hit entry point, and the production path: `hit_landed` carries a
## DamageEvent whose `source` is the actor that dealt the hit and whose `victim` is the
## actor that took it. Safe on a null event and safe when either side is absent, so a
## neutral hitbox with no source simply freezes whatever participant does exist.
func register_hit(event: DamageEvent) -> void:
	if not enabled or event == null:
		return
	var bodies: Array = [event.source, event.victim]
	freeze_bodies(bodies, duration)


## Freeze these PARTICIPANT BODIES for `seconds`. Public because a future source of impact
## (a parry, a heavy landing, a boss phase change) should reuse this rather than write a
## second freeze.
##
## A freeze already running is EXTENDED, never restarted: the release point only ever moves
## later, and a participant that was already frozen is never frozen a second time. Returns
## the number of participant bodies frozen by this call.
func freeze_bodies(bodies: Array, seconds: float) -> int:
	if not enabled:
		return 0
	var parts: Array[Node] = []
	for body in bodies:
		_collect(parts, body)
	if parts.is_empty():
		return 0
	var span := maxi(1, int(round(seconds * 1000.0)))
	var now := Time.get_ticks_msec()
	if _frozen:
		_release_at_ms = maxi(_release_at_ms, now + span)
		extensions += 1
		var added := 0
		for part in parts:
			if _add_target(part):
				_set_frozen(part, true)
				added += 1
		_log("extended by %d ms, %d new participant(s), %d frozen" % [span, added, _targets.size()])
		return added
	for part in parts:
		_add_target(part)
	if _targets.is_empty():
		return 0
	_release_at_ms = now + span
	_frozen = true
	freezes += 1
	for target in _targets:
		_set_frozen(target, true)
	_log("froze %d participant(s) for %d ms" % [_targets.size(), span])
	return _targets.size()


## Release the current freeze immediately and restore every participant's processing.
## Idempotent and safe to call at any time, including when nothing is frozen.
func release_now() -> void:
	if not _frozen and _targets.is_empty():
		return
	var released := 0
	for target in _targets:
		if is_instance_valid(target):
			_set_frozen(target, false)
			released += 1
	_targets.clear()
	if _frozen:
		_frozen = false
		_release_at_ms = 0
		releases += 1
		_log("released %d participant(s)" % released)


# --- Internals ----------------------------------------------------------------

## Freeze or release one participant SUBTREE.
##
## `propagate_call` reaches this node and every descendant, which is exactly the scope
## wanted: an actor's gameplay lives in its children (health, locomotion, the attack state
## machine, the hitbox), and freezing the body alone would leave all of it running.
##
## ONLY `set_process` and `set_physics_process` are called. `set_process_input` is left
## alone so the input layer keeps buffering, and `process_mode` is left alone so no actor
## can be stranded in an unintended mode.
func _set_frozen(target: Node, frozen: bool) -> void:
	if not is_instance_valid(target):
		return
	target.propagate_call(&"set_process", [not frozen])
	target.propagate_call(&"set_physics_process", [not frozen])


## Add a candidate participant, refusing anything that is not a real actor body and
## anything that is this service or an ancestor of it.
##
## The ancestor guard is the one that matters: freezing a subtree that CONTAINS this
## service would disable the only clock that can release it, which is the single way this
## mechanism could strand an actor.
func _collect(list: Array[Node], node) -> void:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return
	var part := node as Node
	if part == self or part.is_ancestor_of(self):
		return
	for existing in list:
		if existing == part:
			return
	list.append(part)


## Add one body to the frozen set. Returns whether it was newly added, so an extension
## only ever applies the setter to participants that are not already frozen.
func _add_target(part: Node) -> bool:
	for existing in _targets:
		if existing == part:
			return false
	_targets.append(part)
	return true


## Subscribe to every hitbox in the tree that is not already subscribed. The GROUP is the
## enumeration source, so a hitbox added later is picked up without editing this file.
func _watch_hitboxes() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(HitboxComponent.GROUP_HITBOX):
		if node == null or not is_instance_valid(node):
			continue
		var id := node.get_instance_id()
		if _watched.has(id):
			continue
		var hitbox := node as HitboxComponent
		if hitbox == null:
			continue
		_watched[id] = true
		if not hitbox.hit_landed.is_connected(_on_hit_landed):
			hitbox.hit_landed.connect(_on_hit_landed)
		_log("watching hitbox %s" % hitbox.name)


## The production signal handler. It decides nothing - it hands the confirmed event to
## register_hit() so there is exactly ONE place that decides what a hitstop is.
func _on_hit_landed(event: DamageEvent) -> void:
	register_hit(event)


func _log(message: String) -> void:
	if debug_logging:
		print("[HITSTOP] %s" % message)
