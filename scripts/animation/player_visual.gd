class_name PlayerVisual
extends Node3D
## The player's VISUAL child, and the real animation driver (Milestone 21 - Slice B).
##
## WHERE THIS SITS. It is the last node in a one-way chain, and it is the ONLY part of that chain
## that knows an AnimationPlayer exists:
##
##     gameplay owners -> ActorState -> AnimationAdapter -> AnimationSet -> THIS -> clips
##
## The adapter still decides nothing about gameplay and this node decides nothing either. It is
## handed a slot that someone else already resolved to a clip, and it plays that clip. Delete this
## node and every actor behaves EXACTLY as it does now - which is the test of a presentation layer.
##
## WHAT IT OWNS: the AnimationPlayer, the extracted Animation resources, and which clip is playing.
## WHAT IT MUST NEVER OWN, and does not: movement, collision, hitboxes, hurtboxes, attack timing,
## damage, stamina, commitment, death state, or any component of gameplay. It never calls into
## gameplay and never writes a transform on anything but the visual model's own skeleton.
##
## THE PLAYER BODY IS STILL THE AUTHORITY. This node is a CHILD of it. It inherits the body's
## transform the way any decorative child does, and it contributes nothing back. The gameplay
## collision shape, hurtbox and hitbox are untouched by this file.
##
## WHY CLIPS ARE EXTRACTED AT RUNTIME RATHER THAN REFERENCED. Every animation in the Nephilite
## pack ships as its OWN FBX, and each one imports as a scene containing a bare `Skeleton3D` plus
## an `AnimationPlayer` - NOT as a reusable `.res` animation. This project cannot run editor
## scripts, so there is no import step that could bake them into standalone resources. So this node
## reads each clip scene ONCE, takes its `Animation`, and registers it on the model's own
## AnimationPlayer under a stable name. The result is cached and SHARED, so a second actor wearing
## the same set costs nothing.
##
## ROOT MOTION IS STRIPPED, deliberately. The pack's clips animate the armature node as well as its
## bones, which would slide the model out of the body that owns it. Any track that targets a NODE
## rather than a BONE is removed on extraction, so gameplay keeps every metre it owns.

## Sources already extracted this session, keyed by res:// path. Shared across every instance:
## an Animation is immutable data, so one copy serves the whole arena.
static var _source_cache: Dictionary = {}

## The model child, resolved from `model_path`.
@export var model_path: NodePath = NodePath("Model")
## The animation set this visual presents through. Its SLOTS are the contract; each slot's value is
## the clip SOURCE it resolves to. Leave empty and the visual simply plays nothing.
@export var animation_set: Resource
## Report a source that cannot be extracted, once per source. A clip that will not load is a CONTENT
## problem and must be visible rather than silently presented as a frozen pose.
@export var report_missing_sources := true
## Blend time between clips, in seconds. Purely presentational.
@export var blend_time := 0.12

## Emitted when the playing clip changes. Diagnostic seam.
signal clip_changed(from_clip: String, to_clip: String)

var _model: Node3D
var _player: AnimationPlayer
## Registered name -> the source path it came from. The reverse of `_source_to_name`.
var _registered: Dictionary = {}
var _source_to_name: Dictionary = {}
## Sources already reported as unplayable, so the log records each ONCE.
var _reported: Dictionary = {}
var _current := ""
var _current_loop := false
## Node-level tracks stripped across every extracted clip. Diagnostic, not decoration.
var stripped_tracks := 0

## The group every visual driver joins, so an actor's adapter can find its driver without a
## hand-authored path. The adapter spells the same name as its own literal on purpose: referring to
## this class from there would make the whole presentation layer depend on a `class_name` being in
## the global registry, which is the failure mode documented at the top of this file.
const GROUP_VISUAL_DRIVER := &"visual_driver"


func _ready() -> void:
	add_to_group(GROUP_VISUAL_DRIVER)
	_model = get_node_or_null(model_path) as Node3D
	if _model == null:
		push_error("[VISUAL] %s: no model at '%s', so nothing can be posed" % [name, model_path])
		return
	_player = get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if _player == null:
		_player = AnimationPlayer.new()
		_player.name = "AnimationPlayer"
		add_child(_player)
	# THE CRITICAL BINDING. Track paths inside an imported clip are written relative to THAT clip's
	# own root, where the skeleton is a direct child called `Skeleton3D`. Pointing this player's
	# root at the model makes those same paths resolve here, which is what lets one clip from one
	# FBX drive a skeleton that came from a different FBX.
	_player.root_node = _player.get_path_to(_model)
	_player.playback_default_blend_time = blend_time
	if animation_set != null:
		register_from_set(animation_set)


# --- Registration -------------------------------------------------------------

## Register every clip source the set names. Returns how many SOURCES were registered.
func register_from_set(set: Resource) -> int:
	var registered := 0
	for source in sources_in_set(set):
		if register_source(source) != "":
			registered += 1
	return registered


## Every distinct clip source a set names, across every slot. Reads the set's own `slots`
## dictionary through `get()` rather than a typed class, so this node never depends on the set
## class being registered.
static func sources_in_set(set: Resource) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if set == null:
		return out
	var slots = set.get("slots")
	if not (slots is Dictionary):
		return out
	for key in (slots as Dictionary).keys():
		for source in _clip_list((slots as Dictionary)[key]):
			if not out.has(source):
				out.append(source)
	return out


## Normalize a slot value into a list of source paths. Accepts the same three shapes
## `AnimationSet.clips_for()` accepts, so the two layers cannot disagree about what a slot holds.
static func _clip_list(raw) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if raw == null:
		return out
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for entry in raw:
			out.append(String(entry))
		return out
	out.append(String(raw))
	return out


## Extract one clip scene's animation and register it. Returns the registered NAME, or "" when the
## source could not be used. Idempotent: registering the same source twice is a no-op.
func register_source(source: String) -> String:
	if source.is_empty():
		return ""
	if _player == null:
		return ""
	if _source_to_name.has(source):
		return String(_source_to_name[source])

	var animation: Animation = _extract(source)
	if animation == null:
		_report(source, "no Animation could be extracted from this clip scene")
		return ""

	var clip_name := _clip_name_for(source)
	if _player.has_animation(clip_name):
		clip_name = clip_name + "_" + str(_registered.size())

	# ASK BEFORE READING. `get_animation_library()` on a name the player does not have logs an
	# engine error and returns null rather than answering quietly - which would make the FIRST
	# registration of any session an error for no reason. The name is the empty one, the standard
	# place for a player with no explicit libraries.
	var library: AnimationLibrary = null
	if _player.has_animation_library(&""):
		library = _player.get_animation_library(&"")
	if library == null:
		library = AnimationLibrary.new()
		_player.add_animation_library(&"", library)
	library.add_animation(clip_name, animation)

	_registered[clip_name] = source
	_source_to_name[source] = clip_name
	return clip_name


## Read a clip scene ONCE and take its animation. The scene is instantiated, mined and freed: the
## pack ships a full skeleton with every clip, and none of it is needed except the Animation.
func _extract(source: String) -> Animation:
	if _source_cache.has(source):
		return _source_cache[source] as Animation

	var packed := load(source) as PackedScene
	if packed == null:
		_source_cache[source] = null
		return null

	var instance := packed.instantiate()
	var found: Animation = null
	for node in instance.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		found = _first_animation(player)
		if found != null:
			break
	instance.free()

	if found != null:
		# Duplicated so each registration owns its own loop mode, and so stripping here cannot
		# mutate a copy another actor is already playing.
		found = found.duplicate() as Animation
		var stripped := _strip_node_tracks(found)
		if stripped > 0:
			stripped_tracks += stripped
	_source_cache[source] = found
	return found


## The first animation an AnimationPlayer carries, across every library it declares.
static func _first_animation(player: AnimationPlayer) -> Animation:
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


## Remove every track that targets a NODE rather than a BONE.
##
## A Skeleton3D bone track carries the bone name as a SUBNAME (`Skeleton3D:Hips`); a track that
## animates a node's own transform has no subname. Those are the only tracks that can move the
## model inside the body that owns it - the pack animates its armature node as well as its bones -
## and gameplay owns every metre an actor moves, so they are dropped rather than obeyed.
static func _strip_node_tracks(animation: Animation) -> int:
	var removed := 0
	for i in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_path(i).get_subname_count() == 0:
			animation.remove_track(i)
			removed += 1
	return removed


## A stable, readable name for a clip: its file name without the extension. The pack's own
## internal animation names are not used, because the set is addressed by source and a file name
## is the one identity a set author can see on disk.
static func _clip_name_for(source: String) -> String:
	return String(source).get_file().get_basename()


# --- Playback -----------------------------------------------------------------

## Play the clip a slot resolved to. Returns false when this visual has no such clip.
##
## `loop` is decided by the CALLER, from the intent it already read - an attack is a one-shot
## whatever its clip's author set, and an idle is a loop. This node does not re-derive intent.
func play_clip(source: String, loop: bool) -> bool:
	if source.is_empty() or _player == null:
		return false
	var clip_name := String(_source_to_name.get(source, ""))
	if clip_name.is_empty():
		# Not registered yet: try now, so a set assigned after _ready() still works.
		clip_name = register_source(source)
	if clip_name.is_empty():
		_report(source, "this clip is not registered on the visual")
		return false

	# Re-playing the SAME looping clip would restart it every frame it is asked for, which reads
	# as a stutter. A one-shot asked for twice is left alone for the same reason.
	if _current == clip_name and (loop or _player.is_playing()):
		return true

	var previous := _current
	_current = clip_name
	_current_loop = loop
	var animation := _player.get_animation(clip_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_player.play(clip_name)
	clip_changed.emit(previous, clip_name)
	return true


## Stop presenting motion without changing anything gameplay owns.
func stop() -> void:
	if _player != null:
		_player.stop()
	_current = ""


func _report(source: String, reason: String) -> void:
	if not report_missing_sources or _reported.has(source):
		return
	_reported[source] = true
	push_warning("[VISUAL] %s: clip '%s' unusable - %s" % [name, source.get_file(), reason])


# --- Queries ------------------------------------------------------------------

## The source of the clip currently playing, or "".
func current_source() -> String:
	return String(_registered.get(_current, ""))


## The registered NAME currently playing, or "".
func current_clip() -> String:
	return _current


## Whether the current clip is being looped.
func current_loops() -> bool:
	return _current_loop


## Every source this visual can play, sorted. This is the ANSWER half of the lookup, and a probe
## compares it against the set's QUESTIONS to prove the two layers agree.
func available_sources() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for source in _source_to_name.keys():
		out.append(String(source))
	out.sort()
	return out


## Every registered clip NAME, sorted.
func available_clips() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for clip in _registered.keys():
		out.append(String(clip))
	out.sort()
	return out


## How many clips are actually playable.
func clip_count() -> int:
	return _registered.size()


## Whether a source resolved to a playable clip.
func has_source(source: String) -> bool:
	return _source_to_name.has(source)


## The model node this visual poses. A probe uses it to prove the visual is a CHILD of the body and
## not the body itself.
func get_model() -> Node3D:
	return _model if _model != null else get_node_or_null(model_path) as Node3D


## The AnimationPlayer this visual drives, created on demand.
func get_player() -> AnimationPlayer:
	return _player if _player != null else get_node_or_null(^"AnimationPlayer") as AnimationPlayer


## One readable line, for a log or a probe report.
func summary() -> String:
	return "%s: %d clip(s), playing '%s'%s" % [
		name, _registered.size(), _current, " (loop)" if _current_loop else ""]
