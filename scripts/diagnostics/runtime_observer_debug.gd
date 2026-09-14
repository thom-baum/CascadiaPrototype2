class_name RuntimeObserverDebug
extends Node
## Temporary diagnostic (not production): an INDEPENDENT runtime observer.
##
## WHY THIS EXISTS. The F9 runtime probe went SILENT after a load even though it runs in
## PROCESS_MODE_ALWAYS and the game was still RENDERING (a live frame showed the SAVE/LOAD panel
## reading "load: OK"). A diagnostic that stops reporting exactly when the runtime breaks cannot
## name the break - and a probe reporting its OWN silence is not evidence about anything else.
##
## So this node is deliberately SEPARATE and dumb: it shares no state with the probe, holds no
## references the probe owns, and does nothing but print what it can see from a fixed position in
## the tree. It runs in PROCESS_MODE_ALWAYS so a pause cannot silence it, and it reports the
## candidates for "why did everything stop":
##
##   - is the TREE paused, and what is the ENGINE time scale
##   - is the frame loop still producing frames (fps, idle frame count)
##   - does the PROBE node still exist, still sit in the tree, and is it still processing
##   - is the PLAYER still in the tree, still processing, and is its POSITION actually changing
##   - what is the mouse mode
##   - how many children the scene root has (a silent scene replacement would show here)
##
## It does NOT decide anything and it never fixes anything. It only keeps the light on.

@export var probe_node_path: NodePath = NodePath("Probe")
@export var label_prefix := "OBSERVER"
## How often to print, in idle frames.
@export var beat_every := 30

var _beat := 0
var _player: Node3D
var _last_player_pos := Vector3.ZERO
var _moved_total := 0.0
## The last printed playability signature, so a CHANGE is printed immediately and an unchanged
## runtime only beats occasionally.
var _last_signature := ""


func _ready() -> void:
	# ALWAYS, so this observer keeps reporting THROUGH a pause instead of falling silent with it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[%s] observer online (process_mode=ALWAYS)" % label_prefix)


func _process(_delta: float) -> void:
	_beat += 1
	_resolve_player()
	var moved := 0.0
	var frozen := false
	if _player != null and is_instance_valid(_player):
		moved = _last_player_pos.distance_to(_player.global_position)
		_last_player_pos = _player.global_position
		_moved_total += moved
		frozen = moved < 0.0001
	# Print when a value that decides PLAYABILITY changes, plus a slow heartbeat. A fixed-rate beat
	# crowds the probe's real results out of the console's capped view; the transition moments are
	# what matter, and they are reported exactly once, when they happen.
	var signature := "%s|%d|%s|%s|%s" % [
		str(get_tree().paused), int(round(Engine.time_scale * 100.0)), str(Input.mouse_mode),
		_describe_probe(), _describe_player()]
	if signature == _last_signature and _beat % beat_every != 0:
		return
	_last_signature = signature
	print("[%s] beat=%d paused=%s time_scale=%.3f fps=%d idle_frames=%d mouse=%s root_children=%d probe=%s player=%s player_physics=%s player_moved=%.4f total=%.3f" % [
		label_prefix, _beat, str(get_tree().paused), Engine.time_scale,
		int(Engine.get_frames_per_second()), Engine.get_process_frames(),
		_mouse_name(Input.mouse_mode), get_tree().root.get_child_count(),
		_describe_probe(), _describe_player(),
		_player.is_physics_processing() if _player != null and is_instance_valid(_player) else false,
		moved, _moved_total])


func _describe_probe() -> String:
	var pivot := get_node_or_null(probe_node_path)
	if pivot == null:
		if not probe_node_path.is_empty():
			var direct := get_node_or_null("..") 
			if direct != null:
				pivot = direct.get_node_or_null(probe_node_path)
	if pivot == null:
		return "MISSING"
	return "%s in_tree=%s physics=%s mode=%d valid=%s" % [
		String(pivot.name), str(pivot.is_inside_tree()), str(pivot.is_physics_processing()),
		pivot.process_mode, str(is_instance_valid(pivot))]


func _describe_player() -> String:
	if _player == null or not is_instance_valid(_player):
		return "MISSING"
	return "%s in_tree=%s pos=%.2f,%.2f,%.2f" % [
		String(_player.name), str(_player.is_inside_tree()),
		_player.global_position.x, _player.global_position.y, _player.global_position.z]


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D


func _mouse_name(mode: int) -> String:
	match mode:
		0:
			return "VISIBLE"
		1:
			return "HIDDEN"
		2:
			return "CAPTURED"
		3:
			return "CONFINED"
	return "mode%d" % mode
