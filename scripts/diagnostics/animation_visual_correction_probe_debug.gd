extends Node3D
## Temporary diagnostic (NOT production). Proves the two visual corrections on the RUNNING game.
##
## WHY THIS EXISTS. Facing and drift were the reported defects, and both have a measurement that can
## confirm or refute them. A render cannot settle facing reliably (a single frame cannot establish an
## authored axis, and the visual observer is not guaranteed to be available), so this probe measures
## geometry and transform arithmetic instead.
##
## WHAT IT PROVES, and why each one is the right measurement:
##
##   1. FACING. The model's own forward axis is computed from the REST pose as foot -> toe, in the
##      MODEL's local space, then transformed by the model's world basis and compared against the
##      PLAYER's world forward. If the correction is right, that dot product is close to +1. This is
##      independent of any clip, so it cannot be satisfied by animation.
##   2. IN PLACE. It reads the animations the DRIVER actually registered - not the source files - and
##      reports each one's horizontal hips travel. Measuring the registered copy is the point: it is
##      what really plays, so it proves the conversion reached the clips in use.
##   3. VERTICAL MOTION PRESERVED, which is the control that stops "in place" from being achieved by
##      flattening the whole clip. A walk clip must still have Y movement.
##   4. BONES STILL MOVE, the control that stops "no drift" from being achieved by freezing the
##      skeleton - the failure mode that would pass every other check while looking dead.
##   5. THE MODEL STAYS OVER THE BODY. The offset between the model and the player body is sampled
##      while a locomotion clip plays and must stay constant.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const REPORT_PATH := "res://animation_visual_correction_report.txt"

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 20
## Frames spent sampling the model's offset from the body while a locomotion clip plays.
const DRIFT_FRAMES := 60
## A horizontal hips travel at or below this, in metres, counts as IN PLACE.
const IN_PLACE_EPSILON := 0.01
## How far the model may move relative to the body before it counts as drift.
const DRIFT_EPSILON := 0.01

var _frame := 0
var _stage := 0
var _wait := 0
var _done := false
var _lines: Array = []
var _failures: Array = []
var _passed := 0

var _player: Node3D
var _visual: Node
var _model: Node3D
var _skeleton: Skeleton3D
var _adapter: Node

## Offset of the model from the body, measured while a locomotion clip plays.
var _offset_first := Vector3.ZERO
var _offset_max := 0.0

## Bone signature sampling, so "animation still runs" is measured rather than assumed.
var _bone_signature_before := 0.0


func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: visual correction probe loaded and _ready() executed")
		file.close()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		0:
			_resolve()
			_audit_facing()
			_audit_registered_clips()
			_audit_gameplay_untouched()
			_bone_signature_before = _bone_signature()
			_begin_drift()
			_stage = 1
			_wait = 0
		1:
			_wait += 1
			_tick_drift()
			if _wait >= DRIFT_FRAMES:
				_audit_drift()
				_audit_bones_alive()
				_done = true
				_report()


# --- Setup ---------------------------------------------------------------------

func _resolve() -> void:
	_player = get_tree().get_first_node_in_group("player_actor")
	if _player == null:
		_fail("no player_actor in the scene")
		return
	_visual = _player.get_node_or_null("Visual")
	if _visual == null:
		_fail("the player carries no Visual child")
		return
	_model = _visual.get_node_or_null("Model") as Node3D
	if _model == null:
		_fail("the visual carries no Model child")
		return
	_skeleton = _find_first_of_class(_model, "Skeleton3D") as Skeleton3D
	_adapter = _player.get_node_or_null("Animation")
	_lines.append("player=%s  visual=%s  model=%s" % [
		String(_player.name), String(_visual.name), String(_model.name)])
	_lines.append("model world basis -Z = %s" % str(-_model.global_transform.basis.z.snappedf(0.0001)))
	_lines.append("player world basis -Z = %s" % str(-_player.global_transform.basis.z.snappedf(0.0001)))


# --- 1. Facing -----------------------------------------------------------------

## The model's forward axis from the REST pose, in model-local space, then rotated into world space.
## Foot-to-toe is used because toes point where the character faces and the rest pose is immune to
## any clip, any driver and any frame timing.
func _audit_facing() -> void:
	_lines.append("")
	_lines.append("--- FACING ---")
	if _skeleton == null:
		_fail("no Skeleton3D, so facing could not be measured")
		return
	var toes := _bones_matching(["toe", "ball"])
	var feet := _bones_matching(["foot", "ankle"])
	if toes.is_empty() or feet.is_empty():
		_fail("no foot/toe bones found by name, so facing could not be measured")
		return
	var votes: Array = []
	for toe in toes:
		var foot := _nearest_of(toe, feet)
		if foot < 0:
			continue
		var flat := _rest_bone_pos(toe) - _rest_bone_pos(foot)
		flat = Vector3(flat.x, 0.0, flat.z)
		if flat.length() > 0.001:
			votes.append(flat.normalized())
	if votes.is_empty():
		_fail("every foot/toe pair collapsed to zero length, so facing is undetermined")
		return
	var local_forward := Vector3.ZERO
	for v in votes:
		local_forward += v
	local_forward = Vector3(local_forward.x, 0.0, local_forward.z).normalized()

	# Rotate the model's own forward into world space. ORIGIN is irrelevant: only the basis matters.
	var world_forward := (_model.global_transform.basis * local_forward)
	world_forward = Vector3(world_forward.x, 0.0, world_forward.z).normalized()

	# Gameplay's forward is the BODY's own -Z, which is also where the facing marker sits.
	var gameplay_forward := -_player.global_transform.basis.z
	gameplay_forward = Vector3(gameplay_forward.x, 0.0, gameplay_forward.z).normalized()

	var agreement := world_forward.dot(gameplay_forward)
	_lines.append("model forward (local, rest) = %s" % str(local_forward.snappedf(0.0001)))
	_lines.append("model forward (world)       = %s" % str(world_forward.snappedf(0.0001)))
	_lines.append("gameplay forward (world)    = %s" % str(gameplay_forward.snappedf(0.0001)))
	_lines.append("agreement (dot) = %.4f" % agreement)
	_expect(agreement > 0.9,
		"the model's forward axis AGREES with the gameplay body's forward (dot %.4f)" % agreement)


# --- 2 and 3. Registered clips are in place, and still have vertical motion -----

## Reads the animations on the AnimationPlayer the DRIVER registered. Measuring the registered copy
## rather than the source file is deliberate: it is what actually plays.
func _audit_registered_clips() -> void:
	_lines.append("")
	_lines.append("--- REGISTERED CLIPS (what the driver actually plays) ---")
	var player: AnimationPlayer = _visual.get_player()
	if player == null:
		_fail("the visual owns no AnimationPlayer")
		return
	if not player.has_animation_library(&""):
		_fail("the AnimationPlayer declares no default library")
		return
	var library := player.get_animation_library(&"")
	var clip_names := library.get_animation_list()
	_lines.append("registered: %d clip(s)" % clip_names.size())
	_expect(clip_names.size() > 0, "at least one real clip is registered (%d)" % clip_names.size())

	for clip_name in clip_names:
		var animation := library.get_animation(clip_name)
		if animation == null:
			continue
		var travel := _horizontal_travel_of(animation)
		var vertical := _vertical_span_of(animation)
		_lines.append("  %-42s flat=%.4f m  vertical=%.4f m" % [String(clip_name), travel, vertical])
		_expect(travel <= IN_PLACE_EPSILON,
			"clip '%s' is IN PLACE (horizontal travel %.4f m)" % [String(clip_name), travel])

	# The control: "in place" must not have been achieved by flattening the clip entirely.
	var walk := library.get_animation(_clip_named(library, "walk_F"))
	if walk != null:
		var vertical := _vertical_span_of(walk)
		_expect(vertical > 0.005,
			"the walk clip still has VERTICAL motion, so it was not flattened (%0.4f m)" % vertical)
	else:
		_lines.append("  NOTE: no walk clip registered under a name containing 'walk_F'; vertical control skipped")


## Horizontal travel of the whole-body bones across a clip: the number that reads as drift on screen.
static func _horizontal_travel_of(animation: Animation) -> float:
	var worst := 0.0
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var count := animation.track_get_path(track).get_subname_count()
		if count == 0:
			continue
		var bone := String(animation.track_get_path(track).get_subname(count - 1)).to_lower()
		if bone != "root" and bone != "hips":
			continue
		var keys := animation.track_get_key_count(track)
		if keys < 2:
			continue
		var lo: Vector3 = animation.track_get_key_value(track, 0)
		var hi: Vector3 = lo
		for key in range(1, keys):
			var v: Vector3 = animation.track_get_key_value(track, key)
			lo = Vector3(minf(lo.x, v.x), lo.y, minf(lo.z, v.z))
			hi = Vector3(maxf(hi.x, v.x), hi.y, maxf(hi.z, v.z))
		worst = maxf(worst, Vector2(hi.x - lo.x, hi.z - lo.z).length())
	return worst


## Vertical range of the same bones. Used as the CONTROL that in-place did not flatten the motion.
static func _vertical_span_of(animation: Animation) -> float:
	var worst := 0.0
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var count := animation.track_get_path(track).get_subname_count()
		if count == 0:
			continue
		var bone := String(animation.track_get_path(track).get_subname(count - 1)).to_lower()
		if bone != "root" and bone != "hips":
			continue
		var keys := animation.track_get_key_count(track)
		if keys < 2:
			continue
		var lo: float = animation.track_get_key_value(track, 0).y
		var hi := lo
		for key in range(1, keys):
			var y: float = animation.track_get_key_value(track, key).y
			lo = minf(lo, y)
			hi = maxf(hi, y)
		worst = maxf(worst, hi - lo)
	return worst


static func _clip_named(library: AnimationLibrary, fragment: String) -> StringName:
	for clip_name in library.get_animation_list():
		if String(clip_name).contains(fragment):
			return clip_name
	return &""


# --- 4. The model stays over the body ------------------------------------------

func _begin_drift() -> void:
	_offset_first = _model.global_transform.origin - _player.global_transform.origin
	_offset_max = 0.0
	# Drive a real locomotion clip through the driver's own entry point, so what is measured is the
	# presentation the game actually produces rather than a clip played out of band.
	var locomotion := _source_for_slot("locomotion")
	if locomotion.is_empty():
		_lines.append("NOTE: the set declares no locomotion source, so drift was sampled on the current clip")
	else:
		_visual.play_clip(locomotion, true)


func _tick_drift() -> void:
	var offset := _model.global_transform.origin - _player.global_transform.origin
	_offset_max = maxf(_offset_max, (offset - _offset_first).length())


func _audit_drift() -> void:
	_lines.append("")
	_lines.append("--- ATTACHMENT (model offset from the body, while locomotion plays) ---")
	_lines.append("worst offset change over %d frames: %.4f m" % [DRIFT_FRAMES, _offset_max])
	_expect(_offset_max <= DRIFT_EPSILON,
		"the model did NOT drift away from the body (worst %.4f m)" % _offset_max)

	# The body itself must not have been moved by animation either. Gameplay owns position.
	var adapter_slot := ""
	if _adapter != null and _adapter.has_method("slot_name"):
		adapter_slot = String(_adapter.slot_name())
	_lines.append("adapter slot during sampling: '%s'" % adapter_slot)


func _audit_bones_alive() -> void:
	_lines.append("")
	_lines.append("--- SKELETON STILL ANIMATES (control against freezing it) ---")
	if _skeleton == null:
		return
	var now := _bone_signature()
	_lines.append("bone signature before=%.3f after=%.3f" % [_bone_signature_before, now])
	_expect(absf(now - _bone_signature_before) > 0.001,
		"the skeleton is STILL MOVING, so in-place was not achieved by freezing it")


## A cheap scalar over every bone's pose position, so "the skeleton changed" is one comparable
## number. Not a hash: it only has to differ when the pose differs.
func _bone_signature() -> float:
	if _skeleton == null:
		return 0.0
	var total := 0.0
	for i in _skeleton.get_bone_count():
		var p := _skeleton.get_bone_pose_position(i)
		total += p.x * 1.7 + p.y * 2.3 + p.z * 3.1
	return total


# --- 5. Gameplay untouched -----------------------------------------------------

func _audit_gameplay_untouched() -> void:
	_lines.append("")
	_lines.append("--- GAMEPLAY AUTHORITY ---")
	_expect(_player is CharacterBody3D, "the player is still a CharacterBody3D")
	_expect(_player.get_node_or_null("Collision") != null,
		"the player still carries its authored Collision shape")
	_expect(_player.get_node_or_null("Hurtbox") != null, "the player still carries its Hurtbox")
	_expect(_player.get_node_or_null("AttackHitbox") != null, "the player still carries its AttackHitbox")
	# The visual must own no collision of its own, at any depth.
	var colliders := _count_collision(_visual)
	_expect(colliders == 0,
		"the visual subtree owns NO collision nodes, so it cannot become a physics authority (%d)" % colliders)
	_lines.append("visual collision nodes: %d" % colliders)


func _count_collision(node: Node) -> int:
	var count := 0
	if node is CollisionObject3D or node is CollisionShape3D:
		count += 1
	for child in node.get_children():
		count += _count_collision(child)
	return count


# --- Helpers -------------------------------------------------------------------

func _source_for_slot(slot: String) -> String:
	if _visual == null:
		return ""
	var set = _visual.get("animation_set")
	if set == null:
		return ""
	var slots = set.get("slots")
	if not (slots is Dictionary) or not (slots as Dictionary).has(slot):
		return ""
	var raw = (slots as Dictionary)[slot]
	if raw is PackedStringArray and (raw as PackedStringArray).size() > 0:
		return String((raw as PackedStringArray)[0])
	if raw is Array and (raw as Array).size() > 0:
		return String((raw as Array)[0])
	return ""


func _bones_matching(hints: Array) -> Array:
	var out: Array = []
	if _skeleton == null:
		return out
	for i in _skeleton.get_bone_count():
		var lower := String(_skeleton.get_bone_name(i)).to_lower()
		for hint in hints:
			if lower.contains(String(hint)):
				out.append(i)
				break
	return out


func _nearest_of(from: int, candidates: Array) -> int:
	var best := -1
	var best_distance := INF
	var origin := _rest_bone_pos(from)
	for c in candidates:
		if c == from:
			continue
		var d := origin.distance_to(_rest_bone_pos(c))
		if d < best_distance:
			best_distance = d
			best = c
	return best


## A bone's position in MODEL space from the REST pose alone: rests are parent-relative, so they are
## accumulated root-down. No clip and no driver can affect this.
func _rest_bone_pos(index: int) -> Vector3:
	if _skeleton == null or index < 0:
		return Vector3.ZERO
	var xform := _skeleton.get_bone_rest(index)
	var parent := _skeleton.get_bone_parent(index)
	while parent >= 0:
		xform = _skeleton.get_bone_rest(parent) * xform
		parent = _skeleton.get_bone_parent(parent)
	return xform.origin


func _find_first_of_class(root: Node, type_name: String) -> Node:
	if root == null:
		return null
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_first_of_class(child, type_name)
		if found != null:
			return found
	return null


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		_lines.append("PASS  %s" % label)
	else:
		_failures.append(label)
		_lines.append("FAIL  %s" % label)


func _fail(label: String) -> void:
	_failures.append(label)
	_lines.append("FAIL  %s" % label)


func _report() -> void:
	_lines.append("")
	if _failures.is_empty():
		_lines.append("RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		_lines.append("RESULT: %d of %d CHECK(S) FAILED" % [_failures.size(), _passed + _failures.size()])
		for failure in _failures:
			_lines.append("  - %s" % failure)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line in _lines:
		file.store_line(line)
	file.close()
