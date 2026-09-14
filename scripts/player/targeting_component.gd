class_name TargetingComponent
extends Node
## One actor's target lock (Milestone 12 - target lock-on).
##
## WHAT IT OWNS: the lock STATE and nothing else - whether a lock is held, which actor
## is locked, the candidate set it cycles through, and the four conditions under which
## the lock ends by itself. It moves nothing, damages nothing, draws nothing, and never
## reads a physical key, mouse button or controller button.
##
## WHAT IT DELIBERATELY DOES NOT OWN, so nothing here becomes a second authority:
##
##   target VALIDITY  `CombatParticipant.is_usable_target()` / `CombatParticipant.target_refusal()`.
##                    This file never re-derives "is this a legal target"; it asks the
##                    participant and reports the CAUSE the participant gave.
##   defeat           the target's defeat component (EnemyDeathComponent), reached through
##                    the participant's own refusal. Never inferred from a health value here.
##   player death     the locking actor's own death circuit (DeathComponent.is_dead()), with a
##                    HealthComponent fallback for an actor that has no death circuit.
##   look INTENT      it DECLARES intent to CascadiaInput (see below). It never writes a camera
##                    transform and never decides what the camera does.
##
## THE DECLARED-INTENT PATTERN, copied exactly from `CascadiaInput.mouse_look_enabled`. On the
## controller the right stick's X axis (axis 2) already drives `camera_look_left` / `camera_look_right`.
## Binding target cycling to that same axis is the Soulslike convention, but one physical axis must
## not feed two consumers on the same frame. So while a lock is HELD this component declares
## `look_yaw_suppressed` on CascadiaInput, and the input layer drops the horizontal STICK component
## from the look delta while still delivering the cycle presses.
##
## The input layer HONOURS that intent; it never derives lock state, and a focus transition never
## clears it. The intent is written only on a lock STATE CHANGE, never per frame - a per-frame
## reconciliation that can invent its own state is the defect this project already fixed once.
##
## CYCLE ORDER is decided ONCE, when the lock is taken, from the camera's horizontal basis, and then
## held for the rest of that lock. That is what makes right-then-left a guaranteed round trip: if the
## order were recomputed every call, the camera framing the new target would re-sort the list under
## the player's own input.
##
## Attach one per locking actor, named "Targeting", as a scene-level system with `actor_path` set,
## or as a direct child of its actor. With no usable target in range a lock request simply refuses
## and returns false: no error, no lock, and no look intent declared.

## Emitted when a lock is taken.
signal target_acquired(target: Node3D)

## Emitted when the lock ends. `reason` is the name of a ReleaseReason value, so a consumer can
## tell "the target died" apart from "the player died" without re-checking anything.
signal target_released(target: Node3D, reason: StringName)

## Emitted when the locked target changes while the lock is held (a cycle).
signal target_changed(target: Node3D)

## Why a lock ended. A countable cause, so a report never has to guess or lump causes together.
enum ReleaseReason {
	NONE,           ## no release - the lock is still held
	DEFEATED,       ## the target's own defeat authority reports it out of the fight
	INVALID,        ## the target is gone, freed, or refused as a usable target for any other reason
	OUT_OF_RANGE,   ## the locked target is beyond release_range
	PLAYER_DEAD,    ## the locking actor died, so no lock outlives it
	RUN_RESET,      ## the RUN was reset (New Run): no lock outlives the run it was taken in
}

## The group this component joins. The camera rig reads targeting state through it, which is how the
## rig stays a READER of the lock rather than its owner.
const GROUP_TARGETING := &"targeting"

@export_group("Wiring")
## The actor this lock belongs to. Leave EMPTY for a component that is a direct child of its actor,
## or for a scene-level system, in which case the player actor group is used.
@export var actor_path: NodePath
## The input layer. Leave EMPTY to resolve CascadiaInput through its own group.
@export var input_path: NodePath

@export_group("Policy")
## How far a candidate may be from the actor and still be selected or cycled to.
@export var acquire_range := 18.0
## How far the LOCKED target may be before the lock releases itself. Deliberately separate from
## `acquire_range` so a target that drifts slightly further away is not dropped the moment it moves:
## the two numbers are the hysteresis, not a duplicate of one another.
@export var release_range := 22.0

@export_group("Diagnostics")
## Print each acquire, cycle, release and refusal. Diagnostic.
@export var debug_logging := false

## How many locks have been taken. Diagnostic.
var acquires := 0
## How many cycles were accepted, per direction. Diagnostic.
var cycle_right_count := 0
var cycle_left_count := 0
## How many times a lock request was refused because nothing usable was in range. Diagnostic: this
## is what makes "a request with no target does nothing" checkable rather than assumed.
var acquire_refusals := 0
## How many times a cycle was refused because no lock was held or nothing was in range. Diagnostic.
var cycle_refusals := 0
## How many locks have ended, by cause. Read through release_counts().
var _releases_by_reason: Dictionary = {}

var _locked := false
var _target: Node3D
## The horizontal camera basis captured when the lock was taken, in degrees. Fixed for the whole
## lock so the cycle order cannot re-sort itself under the player's input. See the class comment.
var _order_yaw_degrees := 0.0
var _actor: Node3D
var _intent_declared := false
var _input: CascadiaInput


func _enter_tree() -> void:
	add_to_group(GROUP_TARGETING)


func _ready() -> void:
	_actor = _resolve_actor()
	# A component that starts before its actor resolves must never be left holding a stale intent.
	_declare_look_intent(false)


func _exit_tree() -> void:
	# The intent is a statement about a LIVE lock. If this component leaves the tree, the statement
	# is no longer true, so it is withdrawn rather than left behind for the input layer to honour.
	_declare_look_intent(false)


## Read the semantic actions this module consumes. It polls, exactly as DeathComponent polls
## `consume_restart()`: gameplay owns the decision and the input layer only reports the press.
func _physics_process(_delta: float) -> void:
	var input := _get_input()
	if input != null:
		if input.consume_lock_on():
			toggle_lock()
		if input.consume_target_cycle_right():
			cycle(1)
		if input.consume_target_cycle_left():
			cycle(-1)
	if _locked:
		_check_invalidation()


# --- Queries -----------------------------------------------------------------

## Whether a lock is held. This is the component's own STATE and nothing else, so a consumer
## asking "is the player locked on" is not silently answered by a target that has just been freed.
## Use get_current_target() when the target itself is what is wanted.
func is_locked() -> bool:
	return _locked


## The currently locked actor, or null when nothing is locked or the actor is gone.
func get_current_target() -> Node3D:
	if _target != null and is_instance_valid(_target):
		return _target
	return null


## Locks ended so far, keyed by release-reason name. Diagnostic, and the reason the four auto-release
## paths stay distinguishable in a report.
func release_counts() -> Dictionary:
	return _releases_by_reason.duplicate()


## Why `target` could not keep a lock right now. The four causes are kept APART rather than collapsed
## into one boolean, so a report can say what actually happened.
##
## Deliberately untyped on `target`: a freed or null reference is one of the cases this must answer,
## and a typed parameter would raise instead of answering.
func invalidation_reason(target) -> int:
	if _actor_is_dead():
		return ReleaseReason.PLAYER_DEAD
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return ReleaseReason.INVALID
	# WHETHER the target may be kept is decided by `CombatParticipant` and by nothing here. The
	# defeat authority is consulted only to NAME that refusal as a defeat: an actor taken out of the
	# fight reports BOTH off-the-fight and zero health, and reporting that as a generic "invalid"
	# would lose the distinction the player actually experiences.
	if _target_is_defeated(target):
		return ReleaseReason.DEFEATED
	if CombatParticipant.target_refusal(target) != CombatParticipant.Refusal.NONE:
		return ReleaseReason.INVALID
	if _distance_to(target) > release_range:
		return ReleaseReason.OUT_OF_RANGE
	return ReleaseReason.NONE


## Whether `target` is out of the fight, read from the SAME authority the rest of the project reads:
## the target's own defeat component, reached through its participant and falling back to the
## component itself. Never inferred from a health value here, and never called on a freed reference.
func _target_is_defeated(target) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var participant := CombatParticipant.find_for(target)
	if participant != null and participant.is_defeated():
		return true
	var death: Node = target.get_node_or_null("Death")
	if death != null and death.has_method("is_defeated"):
		return bool(death.call("is_defeated"))
	return false


## Every actor that could be locked right now: a usable combat target, not the locking actor, and
## within acquire_range. Ordered by where the player is looking RIGHT NOW.
##
## `cycle()` deliberately does not use that order - see there. Validity here is
## `CombatParticipant.is_usable_target()` and nothing else, so there is exactly one authority on
## what may be targeted.
func valid_candidates() -> Array:
	var out: Array = []
	var actor := _get_actor()
	if actor == null:
		return out
	for node in _damageable_actors():
		if node == actor:
			continue
		if CombatParticipant.is_usable_target(node) == false:
			continue
		if _distance_to(node) > acquire_range:
			continue
		out.append(node)
	return _ordered_by(out, _camera_yaw_degrees())


## The candidate count, without building the ordered list. Diagnostic.
func candidate_count() -> int:
	return valid_candidates().size()


## Readable name for a release cause, so a log line or a report never prints a bare integer.
func release_reason_name(reason: int) -> String:
	match reason:
		ReleaseReason.DEFEATED:
			return "defeated"
		ReleaseReason.INVALID:
			return "invalid"
		ReleaseReason.OUT_OF_RANGE:
			return "out-of-range"
		ReleaseReason.PLAYER_DEAD:
			return "player-dead"
		ReleaseReason.RUN_RESET:
			return "run-reset"
	return "none"


## The lock state in one readable line, for a debug readout or a probe report.
func state_summary() -> String:
	var target_name := "none"
	var current := get_current_target()
	if current != null:
		target_name = String(current.name)
	return "locked=%s target=%s candidates=%d acquires=%d refuse=%d cycles=%d/%d releases=%s" % [
		str(_locked), target_name, candidate_count(), acquires, acquire_refusals,
		cycle_left_count, cycle_right_count, str(_releases_by_reason)]


# --- Acquire, cycle, release -------------------------------------------------

## The `lock_on` toggle. Acquires when nothing is locked and releases when a lock is held, which is
## the binding the user chose. Returns the lock state afterwards.
func toggle_lock() -> bool:
	if _locked:
		release(ReleaseReason.NONE)
		return false
	return acquire()


## Take a lock on the best candidate: the one nearest the centre of what the player is looking at.
## Refuses, and changes nothing, when no usable target is in range.
func acquire() -> bool:
	if _locked:
		return true
	# A dead actor holds no lock. Without this the lock would be taken and then dropped by the next
	# invalidation check, which is a one-frame state the player would never see but a report could.
	if _actor_is_dead():
		acquire_refusals += 1
		_log("acquire refused: the actor is dead")
		return false
	var candidates := valid_candidates()
	if candidates.is_empty():
		acquire_refusals += 1
		_log("acquire refused: no usable target within %.1f m" % acquire_range)
		return false
	var chosen: Node3D = _nearest_to_centre(candidates)
	_order_yaw_degrees = _camera_yaw_degrees()
	_apply_target(chosen)
	acquires += 1
	_log("acquired %s (%d candidate(s), order basis %.1f deg)"
		% [String(chosen.name), candidates.size(), _order_yaw_degrees])
	return true


## Move the lock to another valid target while a lock is held. `direction` is +1 for right and -1
## for left. Refuses, and changes nothing, with no lock held or nothing in range.
##
## The order is the one captured when the lock was taken, so right followed by left always returns
## to the target the player came from.
func cycle(direction: int) -> bool:
	if direction == 0:
		return false
	if not _locked:
		cycle_refusals += 1
		_log("cycle refused: no lock is held")
		return false
	var live := valid_candidates()
	if live.is_empty():
		cycle_refusals += 1
		_log("cycle refused: no usable target within %.1f m" % acquire_range)
		return false
	# Re-ordered around the basis FROZEN when this lock was taken, not around where the camera points
	# this frame. The camera is busy framing the current target, so a live order would re-sort the
	# list under the player's own input and right-then-left would not return where it came from.
	var candidates := _ordered_by(live, _order_yaw_degrees)
	var count := candidates.size()
	var index := candidates.find(_target)
	var step := 1 if direction > 0 else -1
	# A locked target that has left the candidate list (it moved out of range, or stopped being
	# usable) is treated as a fresh start rather than a failure: the next frame check would release
	# the lock, and refusing here would just lose the player's input.
	var next_index := 0 if index < 0 else posmod(index + step, count)
	var chosen: Node3D = candidates[next_index]
	_apply_target(chosen)
	if direction > 0:
		cycle_right_count += 1
	else:
		cycle_left_count += 1
	_log("cycle %s -> %s (index %d of %d)"
		% ["right" if direction > 0 else "left", String(chosen.name), next_index + 1, count])
	return true


## End the lock. `reason` only labels the cause; it changes nothing that is restored, because
## nothing is restored: this component owns no state but the lock.
func release(reason: int = ReleaseReason.NONE) -> void:
	if not _locked and _target == null:
		return
	var was := _target
	var label := "none"
	if was != null and is_instance_valid(was):
		label = String(was.name)
	_target = null
	_locked = false
	_declare_look_intent(false)
	var key := release_reason_name(reason)
	_releases_by_reason[key] = int(_releases_by_reason.get(key, 0)) + 1
	_log("released %s (%s)" % [label, key])
	var emit_target: Node3D = null
	if was != null and is_instance_valid(was):
		emit_target = was
	target_released.emit(emit_target, key)


# --- Internals ---------------------------------------------------------------

## The per-frame invalidation check. One place decides, by CAUSE, whether the lock survives - and
## every path below ends in the same release(), so no exit leaks a held lock.
func _check_invalidation() -> void:
	var reason := invalidation_reason(_target)
	if reason != ReleaseReason.NONE:
		release(reason)


func _apply_target(node: Node3D) -> void:
	var changed := _locked
	_target = node
	_locked = true
	_declare_look_intent(true)
	if changed:
		target_changed.emit(node)
	else:
		target_acquired.emit(node)


## Declare, or withdraw, gameplay's LOOK-YAW INTENT on the input layer.
##
## Written only on a lock state change, and only when the value actually changes. It is never
## re-derived per frame, and it is never cleared by a focus transition on the input side - exactly
## the contract `mouse_look_enabled` already has.
func _declare_look_intent(active: bool) -> void:
	var input := _get_input()
	if input == null:
		return
	if input.look_yaw_suppressed == active:
		_intent_declared = active
		return
	input.set_look_yaw_suppressed(active)
	_intent_declared = active
	_log("look-yaw intent declared: %s" % str(active))


## The candidate nearest the centre of the camera's horizontal view. Ties are broken by distance and
## then by name, so the choice is always the same for the same scene state.
func _nearest_to_centre(candidates: Array) -> Node3D:
	var basis_yaw := _camera_yaw_degrees()
	var ordered := candidates.duplicate()
	# Sorted by how far the actor is from the CENTRE of the view, not by left-to-right order: the
	# player acquires what they are looking at. The cycling order is a different question and is
	# built separately - see `_ordered_by()`.
	ordered.sort_custom(self._compare_centre.bind(basis_yaw))
	return ordered[0]


## Ordering used by ACQUIRE: the actor closest to the middle of the view wins.
func _compare_centre(a: Variant, b: Variant, basis_yaw: float) -> bool:
	var off_a := snappedf(absf(_bearing_degrees(a, basis_yaw)), 0.001)
	var off_b := snappedf(absf(_bearing_degrees(b, basis_yaw)), 0.001)
	if off_a != off_b:
		return off_a < off_b
	var distance_a := snappedf(_distance_to(a), 0.001)
	var distance_b := snappedf(_distance_to(b), 0.001)
	if distance_a != distance_b:
		return distance_a < distance_b
	return String(a.name) < String(b.name)


## Order candidates by signed bearing around the locking actor, measured from `basis_yaw_degrees`.
## Left (-) first, right (+) last, so +1 walks to the right and -1 to the left.
func _ordered_by(candidates: Array, basis_yaw_degrees: float) -> Array:
	var ordered := candidates.duplicate()
	ordered.sort_custom(self._compare_bearing.bind(basis_yaw_degrees))
	return ordered


## A strict weak ordering, which is what a sort is allowed to assume. The bearings are QUANTISED
## before they are compared so two actors that are practically in the same direction cannot make the
## comparison inconsistent between calls; the name is the final tie-break, and names are unique.
func _compare_bearing(a: Variant, b: Variant, basis_yaw: float) -> bool:
	var bearing_a := snappedf(_bearing_degrees(a, basis_yaw), 0.001)
	var bearing_b := snappedf(_bearing_degrees(b, basis_yaw), 0.001)
	if bearing_a != bearing_b:
		return bearing_a < bearing_b
	var distance_a := snappedf(_distance_to(a), 0.001)
	var distance_b := snappedf(_distance_to(b), 0.001)
	if distance_a != distance_b:
		return distance_a < distance_b
	return String(a.name) < String(b.name)


## Signed bearing of `node` around the locking actor, in degrees. 0 is dead ahead of the basis, +90
## is directly to its right.
##
## The basis is the camera rig's own yaw, so "nearest to the centre of the screen" and "right of the
## current target" mean what the player sees. When no rig can be found the actor's own facing is
## used, which keeps the module usable on an actor with no camera at all.
func _bearing_degrees(node: Node3D, basis_yaw_degrees: float) -> float:
	var actor := _get_actor()
	if actor == null or node == null or not is_instance_valid(node):
		return 0.0
	var to_target := node.global_position - actor.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.000001:
		return 0.0
	var yaw := deg_to_rad(basis_yaw_degrees)
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return rad_to_deg(atan2(to_target.dot(right), to_target.dot(forward)))


## Straight-line distance from the locking actor to `node`.
func _distance_to(node: Node3D) -> float:
	var actor := _get_actor()
	if actor == null or node == null or not is_instance_valid(node):
		return INF
	return actor.global_position.distance_to(node.global_position)


## The horizontal orbit of what the player is looking through: the camera rig's own yaw when one can
## be found, otherwise the actor's facing.
func _camera_yaw_degrees() -> float:
	var rig := _find_camera_rig()
	if rig != null:
		return float(rig.call("current_yaw_degrees"))
	var actor := _get_actor()
	if actor == null:
		return 0.0
	return rad_to_deg(actor.global_rotation.y)


## Walk up from the live camera to the node that owns the horizontal orbit, the same way the
## existing diagnostics resolve the rig. No camera path is exported on purpose: the rig is a READER
## of this module, so this module does not need to be told where it is.
func _find_camera_rig() -> Node:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var camera := viewport.get_camera_3d()
	if camera == null:
		return null
	var node: Node = camera
	while node != null:
		if node.has_method("current_yaw_degrees") and node.has_method("is_framing_lock"):
			return node
		node = node.get_parent()
	return null


## Every damageable actor in the scene, resolved from the health components that own that group.
## A HealthComponent joins the group itself, so the ACTOR is its parent body.
func _damageable_actors() -> Array:
	var out: Array = []
	var tree := get_tree()
	if tree == null:
		return out
	for node in tree.get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var actor := health.get_parent() as Node3D
		if actor != null:
			out.append(actor)
	return out


## Whether the locking actor is dead. The actor's death circuit owns this; a HealthComponent is only
## consulted when there is no death circuit to ask, so an actor without one still releases its lock.
func _actor_is_dead() -> bool:
	var actor := _get_actor()
	if actor == null:
		return false
	var death := actor.get_node_or_null("Death")
	if death != null and death.has_method("is_dead"):
		return bool(death.call("is_dead"))
	var health := actor.get_node_or_null("Health") as HealthComponent
	return health != null and health.is_dead


# --- Resolution --------------------------------------------------------------

func _resolve_actor() -> Node3D:
	if not String(actor_path).is_empty():
		return get_node_or_null(actor_path) as Node3D
	var tree := get_tree()
	if tree != null:
		var found := tree.get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
		if found != null:
			return found
	return get_parent() as Node3D


func _get_actor() -> Node3D:
	if _actor == null or not is_instance_valid(_actor):
		_actor = _resolve_actor()
	return _actor


func _get_input() -> CascadiaInput:
	if _input == null or not is_instance_valid(_input):
		if not String(input_path).is_empty():
			_input = get_node_or_null(input_path) as CascadiaInput
		else:
			_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	return _input


func _log(message: String) -> void:
	if debug_logging:
		print("[TARGETING] %s: %s" % [name, message])
