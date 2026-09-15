extends Node3D
## Temporary diagnostic (NOT production). Measures the IMPORTED player model so the facing and
## drift corrections are based on the asset's real numbers rather than on inference.
##
## WHY THIS EXISTS. Two defects were reported by hand - the model faces backwards, and the model
## drifts or teleports away from the capsule while animating. Neither can be fixed safely by
## guessing, because there are three separate candidate mechanisms and they need DIFFERENT fixes:
##
##   1. the model's AUTHORED forward axis, which is a property of how the pack was exported;
##   2. NODE-level tracks that move the imported scene root, which the driver claims to strip;
##   3. BONE-level translation on the root bone, which a subname-based strip does NOT touch.
##
## Mechanism 3 is the one that is easy to miss and the one that matters here: a locomotion clip
## with baked root motion translates the whole body through its ROOT BONE, and a strip that only
## removes node tracks will leave it running. So this probe measures the ROOT BONE's world position
## over time rather than trusting the strip's counter.
##
## FACING IS MEASURED, NOT ASSUMED. The pack ships forward and backward walk clips. If either
## carries root translation, comparing the two displacement vectors identifies the model's own
## forward axis directly. If both are in place, this reports that it could not be determined from
## the data, rather than inventing an answer.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const REPORT_PATH := "res://animation_model_recon_report.txt"

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 20
## How many frames between bone-position samples, and how many samples to take per clip.
const SAMPLE_EVERY := 4
const SAMPLES := 10

var _frame := 0
var _stage := 0
var _wait := 0
var _sample_index := 0
var _done := false
var _lines: Array = []

var _player: Node3D
var _visual: Node
var _model: Node3D
var _skeleton: Skeleton3D
var _root_bone := -1
var _hips_bone := -1

var _sample_origin := Vector3.ZERO
var _sample_max := 0.0
var _sample_last := Vector3.ZERO

## Forward/back displacement of the root bone, used to derive the model's authored forward axis.
var _forward_delta := Vector3.ZERO
var _backward_delta := Vector3.ZERO


func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: model recon probe loaded and _ready() executed")
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
			_audit_static()
			_audit_tracks()
			_begin_sample("core_main_walk_F_01")
			_stage = 1
			_wait = 0
		1:
			_wait += 1
			_tick_sample()
			if _sample_index >= SAMPLES:
				_forward_delta = _sample_last - _sample_origin
				_lines.append("walk_F root-bone displacement: %s (%.4f m)" % [
					str(_forward_delta), _forward_delta.length()])
				_begin_sample("core_main_walk_B_01")
				_stage = 2
				_wait = 0
		2:
			_wait += 1
			_tick_sample()
			if _sample_index >= SAMPLES:
				_backward_delta = _sample_last - _sample_origin
				_lines.append("walk_B root-bone displacement: %s (%.4f m)" % [
					str(_backward_delta), _backward_delta.length()])
				_audit_facing()
				_audit_idle_drift()
				_done = true
				_report()


# --- Setup --------------------------------------------------------------------

func _resolve() -> void:
	_player = get_tree().get_first_node_in_group("player_actor")
	if _player == null:
		_lines.append("FAIL: no player_actor in the scene")
		return
	_visual = _player.get_node_or_null("Visual")
	if _visual == null:
		_lines.append("FAIL: the player carries no Visual child")
		return
	_model = _visual.get_node_or_null("Model")
	if _model == null:
		_lines.append("FAIL: the visual carries no Model child")
		return
	_skeleton = _find_first(_model, "Skeleton3D") as Skeleton3D
	if _skeleton == null:
		_lines.append("FAIL: the model carries no Skeleton3D")
		return
	_root_bone = 0
	_hips_bone = _find_bone("Hips")
	if _hips_bone < 0:
		_hips_bone = _find_bone("hip")
	if _hips_bone < 0:
		_hips_bone = 1 if _skeleton.get_bone_count() > 1 else 0


func _audit_static() -> void:
	_lines.append("--- STATIC STRUCTURE ---")
	_lines.append("player=%s  visual=%s  model=%s" % [
		String(_player.name), String(_visual.name), String(_model.name)])
	_lines.append("visual local transform: pos=%s rot_deg=%s scale=%s" % [
		str(_visual.transform.origin),
		str(_visual.transform.basis.get_euler() * 180.0 / PI),
		str(_visual.transform.basis.get_scale())])
	_lines.append("MODEL local transform: pos=%s rot_deg=%s scale=%s" % [
		str(_model.transform.origin),
		str(_model.transform.basis.get_euler() * 180.0 / PI),
		str(_model.transform.basis.get_scale())])
	_lines.append("SKELETON local transform: pos=%s rot_deg=%s scale=%s" % [
		str(_skeleton.transform.origin),
		str(_skeleton.transform.basis.get_euler() * 180.0 / PI),
		str(_skeleton.transform.basis.get_scale())])
	_lines.append("skeleton bone count: %d" % _skeleton.get_bone_count())
	_lines.append("bone[0]='%s'   hips_index=%d ('%s')" % [
		_skeleton.get_bone_name(_root_bone), _hips_bone, _skeleton.get_bone_name(_hips_bone)])

	# A physical-bone simulator is a second thing that can move this body, and it is not the
	# animation driver. If one is present and ACTIVE the drift has a different owner entirely.
	var sim := _find_first(_skeleton, "PhysicalBoneSimulator3D") as Node3D
	if sim == null:
		_lines.append("physical bone simulator: none")
	else:
		var active := false
		if sim.has_method("get") and sim.get("active") != null:
			active = bool(sim.get("active"))
		_lines.append("physical bone simulator: present, active=%s, process_mode=%d" % [
			str(active), sim.process_mode])

	if _visual.has_method("stripped_tracks"):
		_lines.append("node-level tracks stripped across all clips: %d" % int(_visual.stripped_tracks))


func _audit_tracks() -> void:
	_lines.append("")
	_lines.append("--- TRACK CENSUS (per clip) ---")
	var player: AnimationPlayer = _visual.get_player()
	if player == null:
		_lines.append("FAIL: no AnimationPlayer")
		return
	_lines.append("AnimationPlayer root_node=%s" % str(player.root_node))
	var resolved_root := player.get_node_or_null(player.root_node)
	_lines.append("root_node resolves to: %s" % (String(resolved_root.name) if resolved_root != null else "<UNRESOLVED>"))
	for clip in ["core_main_idle_01", "core_main_walk_F_01"]:
		if not player.has_animation(clip):
			_lines.append("%s: NOT REGISTERED" % clip)
			continue
		var animation := player.get_animation(clip)
		var node_tracks := 0
		var bone_tracks := 0
		var samples: Array = []
		for i in animation.get_track_count():
			var path := animation.track_get_path(i)
			if path.get_subname_count() == 0:
				node_tracks += 1
			else:
				bone_tracks += 1
			if samples.size() < 4:
				samples.append("%s [%s]" % [str(path), _track_type_name(animation.track_get_type(i))])
		_lines.append("%s: %d track(s) - %d node-level, %d bone-level | len=%.2fs" % [
			clip, animation.get_track_count(), node_tracks, bone_tracks, animation.length])
		for s in samples:
			_lines.append("    e.g. %s" % str(s))


static func _track_type_name(t: int) -> String:
	match t:
		Animation.TYPE_POSITION_3D:
			return "pos3d"
		Animation.TYPE_ROTATION_3D:
			return "rot3d"
		Animation.TYPE_SCALE_3D:
			return "scale3d"
		Animation.TYPE_BLEND_SHAPE:
			return "blend"
		Animation.TYPE_VALUE:
			return "value"
	return "type%d" % t


# --- Sampling -----------------------------------------------------------------

func _begin_sample(clip: String) -> void:
	var player: AnimationPlayer = _visual.get_player()
	if player == null or not player.has_animation(clip):
		_lines.append("cannot sample '%s' (not registered)" % clip)
		_sample_index = SAMPLES
		return
	# One-shot so the clip does not loop back to its start mid-sample and hide real displacement.
	var animation := player.get_animation(clip)
	animation.loop_mode = Animation.LOOP_NONE
	player.play(clip)
	player.seek(0.0, true)
	_sample_origin = _bone_world(_root_bone)
	_sample_last = _sample_origin
	_sample_max = 0.0
	_sample_index = 0
	_lines.append("")
	_lines.append("--- SAMPLING '%s' started, root bone world=%s ---" % [clip, str(_sample_origin)])


func _tick_sample() -> void:
	if _sample_index >= SAMPLES:
		return
	if _wait % SAMPLE_EVERY != 0:
		return
	var now := _bone_world(_root_bone)
	_sample_last = now
	var drift := now - _sample_origin
	_sample_max = maxf(_sample_max, drift.length())
	_lines.append("  sample %d: root=%s  drift=%.4f m" % [_sample_index, str(now), drift.length()])
	_sample_index += 1


## A bone's position in WORLD space: the skeleton's own transform applied to the bone's global pose.
func _bone_world(index: int) -> Vector3:
	if _skeleton == null or index < 0:
		return Vector3.ZERO
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(index)).origin


func _audit_facing() -> void:
	_lines.append("")
	_lines.append("--- FACING ---")
	var f := Vector3(_forward_delta.x, 0.0, _forward_delta.z)
	var b := Vector3(_backward_delta.x, 0.0, _backward_delta.z)
	if f.length() < 0.01 and b.length() < 0.01:
		_lines.append("NOT DETERMINED from clip data: both walk clips are IN PLACE (no root translation).")
		_lines.append("Facing must be judged from a render, not from this probe.")
		return
	var sum := f - b
	if sum.length() < 0.01:
		_lines.append("NOT DETERMINED: forward and backward displacements do not separate cleanly.")
		return
	sum = sum.normalized()
	_lines.append("derived authored FORWARD axis (world, model at identity): %s" % str(sum))
	_lines.append("dot with Godot -Z (the actor's forward): %.3f" % sum.dot(Vector3.FORWARD))
	_lines.append("dot with Godot +Z: %.3f" % sum.dot(Vector3.BACK))
	if sum.dot(Vector3.FORWARD) < -0.5:
		_lines.append("VERDICT: the model's forward is +Z, which is OPPOSITE the actor's -Z.")
		_lines.append("A 180 degree yaw correction is required on the visual.")
	elif sum.dot(Vector3.FORWARD) > 0.5:
		_lines.append("VERDICT: the model's forward already AGREES with the actor's -Z.")


func _audit_idle_drift() -> void:
	_lines.append("")
	_lines.append("--- IDLE: does the model stay put over time? ---")
	var player: AnimationPlayer = _visual.get_player()
	if player == null or not player.has_animation("core_main_idle_01"):
		_lines.append("cannot sample idle")
		return
	var animation := player.get_animation("core_main_idle_01")
	animation.loop_mode = Animation.LOOP_LINEAR
	player.play("core_main_idle_01")
	player.seek(0.0, true)
	var first := _bone_world(_hips_bone)
	var worst := 0.0
	for i in 40:
		# Advance by seeking rather than waiting, so the measurement covers the WHOLE clip instead
		# of one 40-frame window that a slow loop could hide inside.
		var t := (float(i) / 40.0) * animation.length
		player.seek(t, true)
		var d := (_bone_world(_hips_bone) - first).length()
		worst = maxf(worst, d)
	_lines.append("idle hips worst displacement across the clip: %.4f m" % worst)


# --- Output -------------------------------------------------------------------

func _report() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		return
	for line in _lines:
		file.store_line(line)
	file.close()


func _find_first(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null


func _find_bone(wanted: String) -> int:
	if _skeleton == null:
		return -1
	for i in _skeleton.get_bone_count():
		if String(_skeleton.get_bone_name(i)).to_lower() == wanted.to_lower():
			return i
	return -1
