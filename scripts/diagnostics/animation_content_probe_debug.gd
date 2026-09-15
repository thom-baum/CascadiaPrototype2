class_name AnimationContentProbeDebug
extends Node3D
## Temporary diagnostic (not production): does the PLAYER wear a real imported character, does the
## driver actually PLAY imported clips, and is gameplay still the authority while it does?
##
## Why this exists. Slice A proved that a slot carries attack identity. Slice B hands that slot to a
## real `AnimationPlayer` behind a real skinned mesh, and a content pipeline can fail in ways no
## static read catches:
##
##   1. the model could be present but the DRIVER never receives an intent, so nothing ever plays;
##   2. the driver could receive an intent but resolve NO clip, so the character stands frozen and
##      every screenshot looks "fine";
##   3. the visual could quietly become a second physics body, or start writing the body it sits on.
##
## So this probe measures the resolved clip for every slot that gameplay can actually ask for, reads
## what the AnimationPlayer is playing, and drives REAL gameplay - a committed attack and a death -
## while asserting that gameplay timing, the damage window and the stamina cost are untouched.
##
## MISSING CONTENT IS NOT A FAILURE. The pack ships no parry clip. That must be REPORTED as the
## neutral stand-in it is, not faked and not counted as a defect.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const AdapterScript := preload("res://scripts/animation/animation_adapter.gd")
const SetScript := preload("res://scripts/animation/animation_set.gd")
const CombatScript := preload("res://scripts/player/player_combat.gd")

## Frames allowed for the arena and the visual's clip registration to settle.
const SETTLE_FRAMES := 30
## Frame budget for one driven attack to run to completion.
const ATTACK_BUDGET_FRAMES := 300
## Frames allowed after death for the reset to land.
##
## MEASURED, not guessed, and this value was wrong once. `DeathComponent.death_delay` is authored at
## 1.5 s and no scene overrides it, so the automatic reset fires roughly 90 physics frames after
## death. The first value here was 30 frames, which sampled the actor 0.5 s into a 1.5 s delay and
## reported the pre-existing reset circuit as broken. 150 frames is that delay with a wide margin.
const RESET_FRAMES := 150

const REPORT_PATH := "res://animation_content_probe_report.txt"

## Reached by PATH for the same reason every other preload in this project is: a probe must not fail
## to parse because a class registry has not caught up with a freshly written file.
const DamageScript := preload("res://scripts/combat/damage_event.gd")

## The slots gameplay can actually request today, and whether a real clip is expected.
##
## `backstep` is declared by the set but is NOT reachable from gameplay - `AnimationIntent` maps a
## dodging actor to the single `dodge` slot, because the contract does not yet expose whether an
## evasion was a roll or a backstep. It is probed as a DECLARED slot rather than as a wired one.
const WIRED_SLOTS := ["idle", "locomotion", "sprint", "dodge", "hurt", "stagger", "dead", "attack:light", "attack:heavy"]
const DECLARED_ONLY_SLOTS := ["backstep"]

var _frame := 0
var _stage := 0
var _wait := 0
var _done := false
var _failures: Array = []
var _passed := 0
var _lines: Array = []

var _player: Node3D
var _visual: Node
var _adapter: Variant
var _combat: Node
var _state: ActorState

var _collision_shape_id := 0
var _player_origin := Vector3.ZERO
var _stamina_before := 0.0
var _stamina_after := 0.0
var _attack_phases: Array = []
var _attack_window_outside_active := 0
var _attack_window_closed_inside := 0
var _health_before_death := 0.0
var _health_after_reset := 0.0
## Bone-pose signatures: two at rest while a clip plays, and two after a deliberate STOP.
## `is_playing()` cannot tell a POSED skeleton from a clock ticking over dead tracks, so these
## measure the thing itself.
var _bones_early := 0.0
var _bones_late := 0.0
var _bones_stopped_a := 0.0
var _bones_stopped_b := 0.0


## Early marker, so "the scene never ran" and "the world never settled" can be told apart.
func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: animation content probe loaded and _ready() executed")
		file.close()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		0:
			_audit_structure()
			_audit_ownership()
			_audit_resolution()
			_audit_playback()
			_capture_bones_early()
			_start_attack()
			_stage = 1
			_wait = 0
		1:
			_wait += 1
			_observe_attack()
			if _attack_over() or _wait > ATTACK_BUDGET_FRAMES:
				_audit_attack_untouched()
				_kill_player()
				_stage = 2
				_wait = 0
		2:
			_wait += 1
			if _wait >= RESET_FRAMES:
				_audit_reset()
				_audit_still_playing()
				_audit_bones_move()
				_stop_visual()
				_stage = 3
				_wait = 0
		3:
			_wait += 1
			# TWO reads with frames between them, after a deliberate stop. If the skeleton were
			# still moving here, something OTHER than this driver would be posing it, and the
			# movement measured above would not be this layer's doing.
			if _wait == 4:
				_bones_stopped_a = _bone_signature_at_rest()
			elif _wait >= 12:
				_bones_stopped_b = _bone_signature_at_rest()
				_audit_bones_frozen()
				_done = true
				_report()


# --- 1. The visual exists and is NOT the gameplay body ------------------------

func _audit_structure() -> void:
	_player = get_tree().get_first_node_in_group("player_actor")
	_expect(_player != null, "the player actor is discoverable by group")
	if _player == null:
		_fail("no player_actor in the scene, so nothing below could be measured")
		return
	_lines.append("player: %s (%s)" % [String(_player.name), _player.get_class()])

	# The gameplay body is UNCHANGED. These are the nodes that carry collision, combat and state,
	# and every one of them must still be here for the visual to be an addition rather than a swap.
	_expect(_player is CharacterBody3D, "the player is still a CharacterBody3D")
	_expect(_player.get_script() != null, "the player body still carries its controller script")
	for required in ["Collision", "Hurtbox", "AttackHitbox", "Combat", "Stamina", "Dodge", "Parry", "Death", "ActorState", "Animation"]:
		_expect(_player.get_node_or_null(required) != null,
			"the player still carries its authored '%s' node" % required)

	_visual = _player.get_node_or_null("Visual")
	_expect(_visual != null, "the player carries an imported VISUAL child")
	if _visual == null:
		return
	_lines.append("visual: %s (%s)" % [String(_visual.name), _visual.get_class()])

	# The mesh must actually be there, not just the wrapper node.
	var model: Node3D = null
	if _visual.has_method("get_model"):
		model = _visual.get_model()
	_expect(model != null, "the visual resolved its imported model")
	if model != null:
		var skeleton := _find_first(model, "Skeleton3D")
		var mesh := _find_first(model, "MeshInstance3D")
		_expect(skeleton != null, "the imported model carries a Skeleton3D (it is a rigged character)")
		_expect(mesh != null, "the imported model carries a skinned MeshInstance3D")

	# The OLD placeholder capsule must no longer be drawn, or the character renders inside it.
	var capsule := _player.get_node_or_null("Mesh") as MeshInstance3D
	if capsule != null:
		_expect(not capsule.visible,
			"the primitive placeholder capsule is hidden now that a real model is worn")


## The visual must not own physics, collision or gameplay state. This is the check that keeps the
## added layer a presentation layer.
func _audit_ownership() -> void:
	if _visual == null:
		return
	var bodies := _count_collision_nodes(_visual)
	_expect(bodies == 0,
		"the visual subtree owns NO CollisionObject3D / CollisionShape3D (found %d)" % bodies)

	# The player's own collision authority is intact and is NOT parented under the visual.
	var collision := _player.get_node_or_null("Collision") as CollisionShape3D
	if collision != null and collision.shape != null:
		_collision_shape_id = collision.shape.get_instance_id()
		_expect(_player.get_node_or_null("Hurtbox") != null, "the player hurtbox is still on the player body")
		_expect(_player.get_node_or_null("AttackHitbox") != null, "the player hitbox is still on the player body")
	_expect(_player.get_node_or_null("Visual") == _visual, "the visual is a child of the player BODY, not of a collider")

	# A visual that moved itself would be a second author of position. It must sit exactly on the
	# body's origin and own no offset of its own.
	var offset := (_visual as Node3D).transform.origin if _visual is Node3D else Vector3.ZERO
	_expect(offset.is_zero_approx(),
		"the visual declares NO positional offset of its own (origin=%s)" % str(offset))

	# The visual must not have joined a gameplay group. If it had, save/load and every
	# group-driven system would start seeing a second actor that is not one.
	var groups := _visual.get_groups()
	var gameplay_groups: Array = []
	for group in groups:
		var name := String(group)
		# The visual's OWN group is `visual_driver`, and the adapter's is `animation_adapter`. Both
		# are presentation-only, so neither counts as a gameplay group. Everything else does.
		if name != "visual_driver" and name != "animation_adapter":
			gameplay_groups.append(name)
	_expect(gameplay_groups.is_empty(),
		"the visual joined no gameplay group beyond its own (found %s)" % str(gameplay_groups))


# --- 2. Every wired slot resolves to a REAL imported clip ---------------------

func _audit_resolution() -> void:
	var adapter: Variant = _find_adapter()
	_expect(adapter != null, "the player's AnimationAdapter is present")
	if adapter == null:
		return
	_adapter = adapter
	_expect(adapter.is_wired(), "the adapter is wired to the player's ActorState")

	var set = adapter.animation_set
	_expect(set != null, "the adapter has an AnimationSet assigned")
	if set == null:
		return
	_lines.append("set: %s" % String(set.get("display_name")))

	var sources: PackedStringArray = _visual.available_sources() if _visual != null and _visual.has_method("available_sources") else PackedStringArray()
	_lines.append("clips registered on the visual: %d" % sources.size())
	_expect(sources.size() > 0, "the visual registered at least one real clip from the set")

	# EVERY slot gameplay can ask for must resolve to a clip, and that clip's path must exist in the
	# list the visual actually registered - otherwise the lookup names a clip nothing can play.
	for slot in WIRED_SLOTS:
		var result: Dictionary = set.call("resolve", slot)
		var status := String(result.get("status", "none"))
		var clips: PackedStringArray = result.get("clips", PackedStringArray())
		_expect(status == SetScript.STATUS_EXACT,
			"slot '%s' resolves EXACT to real content (got '%s')" % [slot, status])
		if clips.size() > 0:
			_expect(sources.has(clips[0]),
				"slot '%s' resolves to a clip the visual actually registered" % slot)
			_lines.append("  %-14s -> %s" % [slot, String(clips[0]).get_file().get_basename()])
		else:
			_fail("slot '%s' resolved with no clip at all" % slot)

	# DECLARED-ONLY slots: the set names content for them, but gameplay cannot request them yet.
	for slot in DECLARED_ONLY_SLOTS:
		var declared: Dictionary = set.call("resolve", slot)
		_expect(String(declared.get("status", "")) == SetScript.STATUS_EXACT,
			"declared slot '%s' names real content" % slot)
	_lines.append("NOTE: 'backstep' is declared with real content but is NOT reachable from gameplay - "
		+ "AnimationIntent maps every evasion to 'dodge'. Recorded, not built.")


## The two facts that make the pipeline real rather than decorative.
func _audit_playback() -> void:
	if _visual == null or _adapter == null:
		return
	var slot := String(_adapter.slot_name())
	_expect(not slot.is_empty(), "the adapter is asking for a slot at rest ('%s')" % slot)

	var resolved := String(_adapter.resolved_clip())
	_expect(not resolved.is_empty(),
		"the set resolved that slot to a clip through the REAL lookup ('%s')" % resolved.get_file())

	var animation: AnimationPlayer = _visual.get_player()
	_expect(animation != null, "the visual owns an AnimationPlayer")
	if animation == null:
		return
	_expect(animation.has_animation(String(_visual.current_clip())),
		"the resolved clip is registered ON the AnimationPlayer")
	_expect(animation.is_playing(),
		"the AnimationPlayer is actually PLAYING (current='%s')" % animation.current_animation)
	_expect(_visual.current_source() == resolved,
		"the clip playing is the one the lookup resolved (playing='%s')" % _visual.current_source().get_file())

	# THE MISSING-CONTENT CASE. The pack ships no parry clip, and that must be reported through the
	# fallback policy rather than faked.
	var set = _adapter.animation_set
	var parry: Dictionary = set.call("resolve", "parry")
	var parry_status := String(parry.get("status", ""))
	_expect(parry_status != SetScript.STATUS_EXACT,
		"a MISSING slot ('parry') is not reported as exact content")
	_expect(parry_status == SetScript.STATUS_NEUTRAL,
		"missing parry falls to the declared NEUTRAL stand-in (got '%s')" % parry_status)
	var note := String(parry.get("note", ""))
	_expect(note.contains("parry"), "the fallback note NAMES the missing slot ('%s')" % note)
	_lines.append("MISSING CONTENT: slot 'parry' -> %s (%s)" % [parry_status, note])


# --- 3. Gameplay is still authoritative --------------------------------------

func _start_attack() -> void:
	_combat = get_tree().get_first_node_in_group("player_combat")
	if _combat == null:
		_fail("no PlayerCombat found, so gameplay authority could not be measured")
		return
	var stamina := _player.get_node_or_null("Stamina")
	if stamina != null:
		_stamina_before = float(stamina.current_stamina)
	if _player is Node3D:
		_player_origin = _player.global_position
	_expect(_combat.try_start(_combat.light_attack),
		"a real light attack was accepted while the animation layer was live")


func _observe_attack() -> void:
	if _combat == null:
		return
	var phase := String(_combat.state_name())
	var hitbox_active := false
	if _combat.has_method("hitbox_is_open"):
		hitbox_active = bool(_combat.hitbox_is_open())
	if phase == "IDLE":
		return
	if _attack_phases.is_empty() or _attack_phases[-1] != phase:
		_attack_phases.append(phase)
	if hitbox_active and phase != "ACTIVE":
		_attack_window_outside_active += 1
	if phase == "ACTIVE" and not hitbox_active:
		_attack_window_closed_inside += 1


func _audit_attack_untouched() -> void:
	var stamina := _player.get_node_or_null("Stamina")
	if stamina != null:
		_stamina_after = float(stamina.current_stamina)

	# PHASE ORDER. The animation layer must not have reordered or skipped a gameplay phase.
	_expect(_attack_phases == ["STARTUP", "ACTIVE", "RECOVERY"],
		"the attack still ran STARTUP -> ACTIVE -> RECOVERY with animation playing (%s)" % str(_attack_phases))

	# HITBOX TIMING. The damage window is opened by gameplay, and only for the ACTIVE phase.
	_expect(_attack_window_outside_active == 0,
		"the damage window never opened outside ACTIVE (%d frames)" % _attack_window_outside_active)
	_expect(_attack_window_closed_inside == 0,
		"the damage window was open on every ACTIVE frame (%d closed)" % _attack_window_closed_inside)

	# STAMINA. The authored cost, charged exactly once - not a value the animation changed.
	var spent := _stamina_before - _stamina_after
	_expect(is_equal_approx(spent, float(_combat.light_stamina_cost)),
		"the authored light-attack stamina cost was charged (spent %.1f, authored %.1f)" % [
			spent, float(_combat.light_stamina_cost)])

	# MOVEMENT AUTHORITY. A committed attack does not translate the body, and the visual does not
	# push it: the body must be exactly where gameplay left it.
	var moved := (_player.global_position - _player_origin).length()
	_expect(moved < 0.05, "the attack did not translate the body by an animation (%0.3f m)" % moved)

	# The player's collision SHAPE is the same object it was before the animation ran.
	var collision := _player.get_node_or_null("Collision") as CollisionShape3D
	if collision != null and collision.shape != null:
		_expect(collision.shape.get_instance_id() == _collision_shape_id,
			"the player's collision shape was not replaced while animation played")


func _kill_player() -> void:
	var health := _player.get_node_or_null("Health")
	if health == null:
		return
	_health_before_death = float(health.current_health)
	# DAMAGE GOES THROUGH THE COMPONENT'S OWN ENTRY POINT. `apply_damage()` takes a DamageEvent, so
	# the probe builds one rather than reaching past it - a lethal blow that bypassed the real path
	# would prove nothing about the death circuit the reset is being measured against.
	var event := DamageScript.new()
	event.amount = 9999.0
	event.source = null
	health.apply_damage(event)


func _audit_reset() -> void:
	var health := _player.get_node_or_null("Health")
	if health != null:
		_health_after_reset = float(health.current_health)
		_expect(_health_after_reset > 0.0,
			"the existing death reset still restores the player (%.1f -> %.1f)" % [
				_health_before_death, _health_after_reset])
	# The visual must SURVIVE the reset rather than being freed or duplicated by it.
	_expect(is_instance_valid(_visual) and _visual.is_inside_tree(),
		"the visual survives the death reset and is still in the tree")


## The strongest single statement this probe can make: after a full attack and a death reset, the
## driver is STILL playing a clip resolved through the real lookup.
func _audit_still_playing() -> void:
	if _visual == null or _adapter == null:
		return
	var animation: AnimationPlayer = _visual.get_player()
	if animation == null:
		_fail("the AnimationPlayer vanished after the reset")
		return
	_expect(animation.is_playing(),
		"the driver is still playing after attack + death reset (current='%s')" % animation.current_animation)
	var slot := String(_adapter.slot_name())
	var resolved := String(_adapter.resolved_clip())
	_expect(not resolved.is_empty(),
		"the driver still resolves a clip through the lookup after the reset (slot='%s')" % slot)
	_lines.append("post-reset: slot=%s clip=%s playing=%s" % [
		slot, String(resolved).get_file().get_basename(), animation.current_animation])


## THE CHECK THAT SEPARATES "a clip is playing" FROM "the character is animating".
##
## `is_playing()` and `has_animation()` are BOTH satisfied by a player whose tracks resolve to
## nothing: the clip ticks on a clock, every frame advances, and no bone ever moves. A clip's track
## paths are authored against ITS OWN scene root, where the skeleton is a direct child called
## `Skeleton3D`, so a driver that points its root somewhere else produces a perfectly animated
## nothing - and that is invisible to every other assertion in this file.
##
## So the SKELETON is measured, not the player. Two reads separated by a whole attack, a death and
## a reset must DIFFER, or the model is standing still while the mixer reports success.
func _audit_bones_move() -> void:
	var skeleton := _find_skeleton()
	if skeleton == null:
		_fail("no Skeleton3D under the visual model, so no clip could pose anything")
		return
	_expect(skeleton.get_bone_count() > 0,
		"the model's skeleton carries real bones (%d)" % skeleton.get_bone_count())
	_bones_late = _bone_signature(skeleton)
	var moved := not is_equal_approx(_bones_early, _bones_late)
	_expect(moved,
		"BONES ACTUALLY MOVED while a clip played, so the clips bound to THIS skeleton (%d bones)" % skeleton.get_bone_count())
	_lines.append("bone signature: early=%.3f late=%.3f moved=%s" % [_bones_early, _bones_late, str(moved)])


## The CONTROL for the check above. Without it, a skeleton that moved because something ELSE was
## posing it would pass as though this driver were responsible. Stopping the driver must freeze it.
func _audit_bones_frozen() -> void:
	var skeleton := _find_skeleton()
	var bones := 0
	if skeleton != null:
		bones = skeleton.get_bone_count()
	var held := is_equal_approx(_bones_stopped_a, _bones_stopped_b)
	_expect(held,
		"with the driver STOPPED the skeleton holds still, so THIS driver is what poses it (%d bones)" % bones)
	_lines.append("stopped control: a=%.3f b=%.3f held=%s" % [_bones_stopped_a, _bones_stopped_b, str(held)])


## Stop the driver without touching gameplay, for the control above.
func _stop_visual() -> void:
	if _visual != null and _visual.has_method("stop"):
		_visual.stop()


# --- Helpers ------------------------------------------------------------------

## Take the early bone-pose reading. Called once at rest, before anything is driven.
func _capture_bones_early() -> void:
	_bones_early = _bone_signature_at_rest()


func _bone_signature_at_rest() -> float:
	return _bone_signature(_find_skeleton())


## The skeleton the clips drive: the first one under the visual's own model. Null when the model
## carries none, which is a configuration problem rather than a passing state.
func _find_skeleton() -> Skeleton3D:
	if _visual == null or not _visual.has_method("get_model"):
		return null
	var model: Node = _visual.get_model()
	if model == null:
		return null
	return _find_first(model, "Skeleton3D") as Skeleton3D


## ONE number summarising the whole pose. Deliberately not a single bone: the packs pose the entire
## rig, and one unchanged finger would not mean the character is animating. INF means "no skeleton",
## which is reported as a failure by `_audit_bones_move()` rather than compared.
static func _bone_signature(skeleton: Skeleton3D) -> float:
	if skeleton == null:
		return INF
	var total := 0.0
	for i in skeleton.get_bone_count():
		var p := skeleton.get_bone_pose_position(i)
		var q := skeleton.get_bone_pose_rotation(i)
		total += p.x + p.y * 2.0 + p.z * 3.0
		total += (q.x + q.y + q.z + q.w) * 10.0
	return total

func _attack_over() -> bool:
	if _combat == null:
		return true
	return not _combat.is_busy()


func _find_adapter() -> Variant:
	if _player == null:
		return null
	var node := _player.get_node_or_null("Animation")
	if node != null and node.has_method("slot_name"):
		return node
	return null


func _find_first(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null


## Every collision-bearing node in a subtree. A presentation layer that owns one of these has
## stopped being presentation.
func _count_collision_nodes(root: Node) -> int:
	var count := 0
	if root is CollisionObject3D or root is CollisionShape3D or root is CollisionPolygon3D:
		count += 1
	for child in root.get_children():
		count += _count_collision_nodes(child)
	return count


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		_lines.append("PASS  %s" % label)
	else:
		_fail(label)


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
	if file != null:
		file.store_line("\n".join(PackedStringArray(_lines)))
		file.close()
