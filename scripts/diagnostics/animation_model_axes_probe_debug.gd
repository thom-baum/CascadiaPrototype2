extends Node3D
## Temporary diagnostic (NOT production). Reads the IMPORTED player model and its clips and reports
## the numbers the correction pass needs, so nothing is fixed by guessing.
##
## WHY THIS EXISTS. A first recon measured the ROOT bone and found no displacement at all, which
## CONTRADICTED the reported drift. The reason is that the pack puts translation on the HIPS, not on
## the root - the census showed `Skeleton3D:Hips [pos3d]` in every locomotion clip. So this probe
## measures the HIPS position tracks across EVERY clip in the assigned set, and reports the key
## RANGE on each axis, which is the number that says whether a clip travels.
##
## IT READS THE ANIMATION RESOURCE DIRECTLY, and that is deliberate rather than convenient. Sampling
## a PLAYING clip would be perturbed by the live driver, by frame timing and by which slot happened
## to be active. Reading an Animation's own keys is deterministic and cannot be affected by anything
## else running in the scene.
##
## FACING IS DERIVED FROM GEOMETRY, NOT FROM A RENDER. Walk clips in this pack are authored IN PLACE
## (measured: zero root displacement), so they cannot reveal the model's forward axis. The foot-to-toe
## vector from the skeleton's REST pose can, because toes point the way the character faces. That is
## printed as a vector so it can be compared against gameplay's own forward axis.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const REPORT_PATH := "res://animation_model_axes_report.txt"

## Frames allowed for the arena to settle before anything is read.
const SETTLE_FRAMES := 20

## The set whose clips are analysed. Read as a Resource so this probe never depends on the set
## class being in the global registry.
const SET_PATH := "res://resources/animation/player_fist.animset.tres"

## A position range at or below this, in metres, is treated as no translation. Bone-space units are
## metres here, so 1 cm is well below anything that would read as drift on screen.
const MOTION_EPSILON := 0.01

## How many node-level track paths to name per clip, when a clip has any.
const MAX_NODE_TRACKS_SHOWN := 6

## Bone names whose forward meaning is worth measuring, matched case-insensitively by substring.
const TOE_HINTS := ["toe", "ball"]
const FOOT_HINTS := ["foot", "ankle"]
const HEAD_HINTS := ["head", "nose", "face"]

var _frame := 0
var _done := false
var _lines: Array = []
var _skeleton: Skeleton3D
var _model: Node3D
var _visual: Node


func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: model axes probe loaded and _ready() executed")
		file.close()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_done = true
	_run()
	_report()


func _run() -> void:
	var player := get_tree().get_first_node_in_group("player_actor")
	if player == null:
		_lines.append("FAIL: no player_actor in the scene")
		return
	_visual = player.get_node_or_null("Visual")
	if _visual == null:
		_lines.append("FAIL: the player carries no Visual child")
		return
	_model = _visual.get_node_or_null("Model") as Node3D
	_skeleton = _find_skeleton(_model)
	if _skeleton == null:
		_lines.append("FAIL: the imported model carries no Skeleton3D")
		return

	_audit_hierarchy(player)
	_audit_bones()
	_audit_facing()
	_audit_clips()


# --- Hierarchy -----------------------------------------------------------------

func _audit_hierarchy(player: Node3D) -> void:
	_lines.append("--- HIERARCHY ---")
	_lines.append("player global: %s" % str(player.global_transform.origin))
	_lines.append("body forward (gameplay) is the body's own -Z, because FacingMarker/Nose sits at local z=-0.4")
	var visual_path := String(player.get_path_to(_visual))
	var model_path := String(_visual.get_path_to(_model))
	_lines.append("player -> visual path: %s" % visual_path)
	_lines.append("visual -> model path:  %s" % model_path)
	_lines.append("visual local: pos=%s rot=%s" % [
		str(_visual.transform.origin), str(_visual.transform.basis.get_euler() * 180.0 / PI)])
	_lines.append("model  local: pos=%s rot=%s" % [
		str(_model.transform.origin), str(_model.transform.basis.get_euler() * 180.0 / PI)])
	_lines.append("skeleton local: pos=%s rot=%s" % [
		str(_skeleton.transform.origin), str(_skeleton.transform.basis.get_euler() * 180.0 / PI)])


# --- Bones ---------------------------------------------------------------------

func _audit_bones() -> void:
	_lines.append("")
	_lines.append("--- BONES (%d) ---" % _skeleton.get_bone_count())
	var names: Array = []
	for i in _skeleton.get_bone_count():
		names.append("%d:%s" % [i, _skeleton.get_bone_name(i)])
	_lines.append("  " + ", ".join(PackedStringArray(names)))


## Foot-to-toe in the REST pose, in MODEL space. This is the model's own forward axis: a foot points
## the way the character faces, and the rest pose cannot be influenced by any clip or driver.
func _audit_facing() -> void:
	_lines.append("")
	_lines.append("--- MODEL FORWARD AXIS (from rest pose geometry) ---")
	var toes := _bones_matching(TOE_HINTS)
	var feet := _bones_matching(FOOT_HINTS)
	var heads := _bones_matching(HEAD_HINTS)
	_lines.append("toe bones:  %s" % str(toes))
	_lines.append("foot bones: %s" % str(feet))
	_lines.append("head bones: %s" % str(heads))

	var votes: Array = []
	for toe in toes:
		var foot := _nearest_of(toe, feet)
		if foot < 0:
			continue
		var fwd := _rest_pos(toe) - _rest_pos(foot)
		var flat := Vector3(fwd.x, 0.0, fwd.z)
		if flat.length() < 0.001:
			continue
		flat = flat.normalized()
		votes.append(flat)
		_lines.append("  %s -> %s : forward=%s  (azimuth %.1f deg)" % [
			_skeleton.get_bone_name(foot), _skeleton.get_bone_name(toe),
			str(flat.snappedf(0.0001)), rad_to_deg(atan2(flat.x, flat.z))])

	if votes.is_empty():
		_lines.append("  NOT DETERMINED: no foot/toe pair was found by name.")
		return
	var sum := Vector3.ZERO
	for v in votes:
		sum += v
	sum = Vector3(sum.x, 0.0, sum.z).normalized()
	_lines.append("  VERDICT: model forward (rest) is %s, azimuth %.1f deg from +Z" % [
		str(sum.snappedf(0.0001)), rad_to_deg(atan2(sum.x, sum.z))])
	# Gameplay forward is the body's -Z. A model whose toes point at +Z is facing 180 deg away.
	var dot_with_gameplay_forward := sum.dot(Vector3(0.0, 0.0, -1.0))
	_lines.append("  dot(model_forward, gameplay_forward=-Z) = %.3f" % dot_with_gameplay_forward)
	if dot_with_gameplay_forward < -0.5:
		_lines.append("  => OPPOSED: the model is authored facing BACKWARDS, so a 180 deg yaw correction is required.")
	elif dot_with_gameplay_forward > 0.5:
		_lines.append("  => ALIGNED: the model is already authored facing gameplay's forward.")
	else:
		_lines.append("  => SIDEWAYS: the model's forward is neither aligned nor opposed; inspect by eye.")


# --- Clips ---------------------------------------------------------------------

## Every clip the assigned set names, analysed for the two things that can displace a visual child:
## NODE-level tracks (which the driver strips) and HIPS position tracks (which it does not).
func _audit_clips() -> void:
	var set := load(SET_PATH)
	var sources := _sources_of(set)
	_lines.append("")
	_lines.append("--- CLIPS (%d in the assigned set) ---" % sources.size())
	for source in sources:
		_audit_one_clip(source)


func _audit_one_clip(source: String) -> void:
	var packed := load(source) as PackedScene
	if packed == null:
		_lines.append("")
		_lines.append("%s: NOT LOADABLE" % source.get_file())
		return
	var instance := packed.instantiate()
	var player := _find_animation_player(instance)
	if player == null:
		_lines.append("")
		_lines.append("%s: no AnimationPlayer" % source.get_file())
		instance.free()
		return
	var clip := _first_animation(player)
	if clip == null:
		_lines.append("")
		_lines.append("%s: no Animation" % source.get_file())
		instance.free()
		return

	var node_tracks: Array = []
	var bone_tracks := 0
	for t in clip.get_track_count():
		if clip.track_get_path(t).get_subname_count() == 0:
			node_tracks.append(String(clip.track_get_path(t)))
		else:
			bone_tracks += 1

	_lines.append("")
	_lines.append("%s  len=%.2fs  tracks=%d (node=%d bone=%d)" % [
		source.get_file().get_basename(), clip.length, clip.get_track_count(),
		node_tracks.size(), bone_tracks])
	if not node_tracks.is_empty():
		var shown: Array = node_tracks.slice(0, mini(node_tracks.size(), MAX_NODE_TRACKS_SHOWN))
		_lines.append("  NODE-LEVEL TRACKS (these can move the model inside the body): %s" % str(shown))

	# The hips is where this pack puts translation. Report its range, and the same for the root so a
	# clip that moves BOTH is distinguishable from one that moves only the hips.
	for t in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var sub := _subname_of(clip.track_get_path(t))
		if sub != "Root" and sub != "Hips":
			continue
		_report_position_track(clip, t, sub)
	instance.free()


func _report_position_track(clip: Animation, track: int, sub: String) -> void:
	var keys := clip.track_get_key_count(track)
	if keys == 0:
		return
	var first: Vector3 = clip.track_get_key_value(track, 0)
	var last: Vector3 = clip.track_get_key_value(track, keys - 1)
	var lo := first
	var hi := first
	for k in range(1, keys):
		var v: Vector3 = clip.track_get_key_value(track, k)
		lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
		hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
	var span := hi - lo
	var flat_span := Vector2(span.x, span.z).length()
	_lines.append("  %-4s pos3d: keys=%d first=%s last=%s span=%s | flat=%.4f m" % [
		sub, keys, str(first.snappedf(0.0001)), str(last.snappedf(0.0001)),
		str(span.snappedf(0.0001)), flat_span])
	# The flat span is the one that matters: vertical bob is normal and harmless, horizontal travel
	# inside a clip is what reads on screen as drift, and a clip that ENDS away from where it STARTED
	# is what reads as a teleport when it loops.
	if flat_span > MOTION_EPSILON:
		var back := (last - first)
		back = Vector3(back.x, 0.0, back.z)
		_lines.append("       ^ TRAVELS %.4f m horizontally; start-to-end offset %.4f m" % [
			flat_span, back.length()])
		if back.length() < MOTION_EPSILON:
			_lines.append("       ^ but it RETURNS to its start, so it loops without a jump")
		else:
			_lines.append("       ^ and it does NOT return to its start: looping this clip WILL jump")


# --- Helpers -------------------------------------------------------------------

func _bones_matching(hints: Array) -> Array:
	var out: Array = []
	for i in _skeleton.get_bone_count():
		var lower := String(_skeleton.get_bone_name(i)).to_lower()
		for hint in hints:
			if lower.contains(String(hint)):
				out.append(i)
				break
	return out


## The closest candidate bone to `from`, in rest space. Used to pair a toe with its own foot rather
## than with whichever foot happens to be listed first.
func _nearest_of(from: int, candidates: Array) -> int:
	var best := -1
	var best_distance := INF
	var origin := _rest_pos(from)
	for c in candidates:
		if c == from:
			continue
		var d := origin.distance_to(_rest_pos(c))
		if d < best_distance:
			best_distance = d
			best = c
	return best


## A bone's position in MODEL space from the REST pose alone: each bone's rest is relative to its
## PARENT, so they are accumulated root-down. No clip and no driver can affect this.
func _rest_pos(index: int) -> Vector3:
	if _skeleton == null or index < 0:
		return Vector3.ZERO
	var xform := _skeleton.get_bone_rest(index)
	var parent := _skeleton.get_bone_parent(index)
	while parent >= 0:
		xform = _skeleton.get_bone_rest(parent) * xform
		parent = _skeleton.get_bone_parent(parent)
	return xform.origin


func _subname_of(path: NodePath) -> String:
	var count := path.get_subname_count()
	if count == 0:
		return ""
	return String(path.get_subname(count - 1))


## Every distinct clip source the set names, read through `get()` so this probe never depends on the
## set class being registered in the global class list.
func _sources_of(set: Resource) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if set == null:
		return out
	var slots = set.get("slots")
	if not (slots is Dictionary):
		return out
	for key in (slots as Dictionary).keys():
		var raw = (slots as Dictionary)[key]
		var list: Array = []
		if raw is PackedStringArray or raw is Array:
			for entry in raw:
				list.append(String(entry))
		elif raw != null:
			list.append(String(raw))
		for source in list:
			if not out.has(source):
				out.append(source)
	return out


func _find_skeleton(root: Node) -> Skeleton3D:
	return _find_first_of_class(root, "Skeleton3D") as Skeleton3D


func _find_animation_player(root: Node) -> AnimationPlayer:
	return _find_first_of_class(root, "AnimationPlayer") as AnimationPlayer


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


func _first_animation(player: AnimationPlayer) -> Animation:
	if player == null:
		return null
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		if library == null:
			continue
		var names := library.get_animation_list()
		if names.size() > 0:
			return library.get_animation(names[0])
	return null


func _report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line in _lines:
		file.store_line(line)
	file.close()
