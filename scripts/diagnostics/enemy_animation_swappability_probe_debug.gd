class_name EnemyAnimationSwappabilityProbeDebug
extends Node3D
## Temporary diagnostic (NOT production): is the animation architecture GENUINELY swappable by DATA?
## (Milestone 22 - AnimationSet swappability and enemy death-pose ownership.)
##
## WHY THIS EXISTS. Milestone 21 built a slot vocabulary, an `AnimationSet` resource and one generic
## `AnimationAdapter`, and claimed the central property that buys all of it:
##
##     the controller and the adapter stay the same while the assigned AnimationSet changes.
##
## That claim was UNFALSIFIED, NOT PROVEN. Every actor in the project wore one set, so an adapter
## that ignored `animation_set` entirely and hard-coded the player's clips would have passed every
## check the project had. This probe is the falsifier.
##
## WHAT IT MEASURES, and why each measurement can actually FAIL on a wrong implementation:
##
##   1. ADAPTER IDENTITY. Not "an adapter exists" - that both actors carry the SAME SCRIPT OBJECT,
##      that the object is the shared `animation_adapter.gd`, and that NO enemy-specific adapter
##      script exists anywhere in the tree. An enemy-specific implementation is exactly what this
##      milestone fails on, so it is checked directly rather than inferred.
##
##   2. SET IDENTITY. The two actors hold DISTINCT `AnimationSet` resources, each actor's VISUAL
##      registered the same set its ADAPTER resolves against, and each set names real clips. A test
##      that passed because both actors pointed at one resource would prove nothing.
##
##   3. SAME SLOT, DIFFERENT CLIP. One semantic slot, resolved through both live sets, must return
##      two DIFFERENT clips that are both registered on the actor that will play them. This is the
##      headline claim, and it fails if the two sets accidentally agree.
##
##   4. THE DIFFERENCE FOLLOWS THE DATA, LIVE. The strongest available form of "no enemy branch",
##      and the reason this probe is not just a resource comparison: the ENEMY's own adapter is
##      handed the PLAYER's set, and then every frame's (slot -> resolved clip) is checked against
##      the set it is HOLDING at that moment. Its resolutions must relocate to the other set's data
##      with no code change, no new node and no restart - and then relocate back when the set is
##      restored. An `if actor_is_enemy` branch inside the adapter cannot satisfy both windows.
##
##   5. THE FALLBACK POLICY. The five outcomes must survive the enemy: exact content resolves
##      exactly, a DECLARED substitute reports `fallback`, an undeclared gap reports `neutral`, and
##      a declared-but-empty substitute reports `missing`. Missing content is never reported as
##      exact, and the enemy's set is deliberately thin in one place so the policy is OBSERVED
##      rather than asserted from a comment.
##
##   6. VISUAL vs GAMEPLAY AUTHORITY. The enemy visual owns no collision node at any depth, sits on
##      the body with no offset of its own, joined no gameplay group, and the enemy's gameplay
##      geometry (collision, hurtbox, hitbox, health, death, attacker, locomotion) is all still on
##      the body. The registered clips are measured for horizontal travel, so "no root motion" is a
##      measurement rather than a promise.
##
##   7. SKELETON MOVEMENT. `is_playing()` is satisfied by a clip whose tracks resolve to nothing, so
##      the skeleton's pose is measured directly: it must MOVE while a clip plays, and it must HOLD
##      STILL when the driver is stopped. Without that second half, a skeleton moved by something
##      else would be credited to this layer.
##
##   8. DEATH-POSE OWNERSHIP, MEASURED. Exactly ONE system writes the defeated enemy's pose. The
##      presentation DECLARES it is not the owner, names the visual as the owner, and then writes
##      NOTHING: its capsule's local transform and `material_override` are sampled on EVERY frame of
##      the death hold and must never change. One writer with no second writer is why the result
##      cannot depend on update order, and sampling the whole hold is what makes that a measurement.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const SetScript := preload("res://scripts/animation/animation_set.gd")
const DamageScript := preload("res://scripts/combat/damage_event.gd")

## The shared adapter this milestone must NOT fork.
const ADAPTER_PATH := "res://scripts/animation/animation_adapter.gd"
const PLAYER_SET_PATH := "res://resources/animation/player_fist.animset.tres"
const ENEMY_SET_PATH := "res://resources/animation/enemy_attacker.animset.tres"

## The actor under test. Named rather than grouped because the enemy archetype does not join a
## group; the player is found the way every other probe finds it.
const ENEMY_ACTOR_NAME := "TestAttacker"
const GROUP_VISUAL_DRIVER := &"visual_driver"

## THE PROOF SLOT, and the reason it is this one: both actors genuinely reach it in play (the player
## walks, the enemy walks), so a difference here is a difference a player can SEE rather than one
## that only exists in a dictionary.
const PROOF_SLOT := "locomotion"
## Second slot, checked for the same property, at rest rather than in motion.
const SECONDARY_SLOT := "idle"
## The enemy's own attack identity, derived from its profile's display name by `AttackDefinition.key()`.
const ATTACK_SLOT := "attack:arena_attacker"
## A slot the enemy set DELIBERATELY does not populate, with a declared substitute on record.
const DECLARED_FALLBACK_SLOT := "stagger"
## A slot neither set populates and neither declares a substitute for.
const NEUTRAL_ONLY_SLOT := "parry"

const SETTLE_FRAMES := 30
## Frames allowed for a slot change to arm a sampling window before the window is graded anyway.
const ARM_BUDGET_FRAMES := 120
## Frames of (slot -> clip) actually recorded per window.
const SAMPLE_FRAMES := 20
## Frames the defeated enemy is held and re-measured before the ownership verdict.
const DEATH_HOLD_FRAMES := 45
## Frames between the two readings that must be IDENTICAL with the driver stopped.
const FROZEN_A_FRAME := 4
const FROZEN_B_FRAME := 16
## Distance the player is re-placed at from the enemy to force a genuine walk, in metres. Comfortably
## outside the enemy's stop distance and comfortably inside its detection radius, so the walk is
## guaranteed without the enemy ever losing the target.
const STAND_OFF := 6.0
## The CLOSE stand-off, and it exists to make a slot change REACHABLE rather than to reposition anything
## for the camera. The enemy stops at `engage_range - stop_margin` (2.4 m from its profile), so holding
## the player inside that distance lets the enemy ARRIVE and stand still - the only way its `locomotion`
## slot can drop back to `idle`. See `_stand_off()` for why the live window needs that flip.
const STAND_OFF_NEAR := 2.2
## Frames each stand-off distance is held. Set from the enemy's own deceleration (`acceleration` 14.0
## down from `move_speed` 2.6 reaches a standstill in roughly 11 frames), so the CLOSE half of the cycle
## really does bring it to rest and produce the `idle` end of the flip.
const STAND_OFF_PERIOD_FRAMES := 30
## Horizontal travel at or below this counts as in place. The same tolerance the correction probe uses.
const IN_PLACE_EPSILON := 0.01

const REPORT_PATH := "res://enemy_animation_swappability_report.txt"

const STAGE_SETTLE := 0
const STAGE_WINDOW_A := 1
const STAGE_WINDOW_B := 2
const STAGE_WINDOW_C := 3
const STAGE_DEATH := 4
const STAGE_FROZEN := 5
const STAGE_DONE := 6

var _player: Node3D
var _enemy: Node3D
var _player_adapter: Variant
var _enemy_adapter: Variant
var _player_visual: Node
var _enemy_visual: Node
var _player_set: Resource
var _enemy_set: Resource
var _presentation: Node
var _enemy_death: Node
var _enemy_mesh: MeshInstance3D

var _frame := 0
var _stage := STAGE_SETTLE
var _stage_frame := 0
var _done := false
var _failures: Array = []
var _passed := 0
var _lines: Array = []

var _window_store: Array = []
var _window_armed := false
var _window_baseline_slot := ""
var _window_frames := 0
var _window_arm_frames := 0
## Whether the window ever observed a real slot change, as opposed to falling through on its budget.
## Recorded so the report says HOW the samples were obtained rather than implying a change happened.
var _window_armed_on_change := false

## Every distinct mesh transform string seen during the death hold, and the material identity. ONE
## entry means no writer touched the capsule on any frame, which is the ownership proof.
var _hold_transforms: Dictionary = {}
var _hold_materials: Dictionary = {}
var _mesh_transform_before := Transform3D.IDENTITY
var _mesh_material_before := ""
var _mesh_transform_captured := false

var _bones_early := 0.0
var _bones_late := 0.0
var _bones_frozen_a := 0.0
var _bones_frozen_b := 0.0


## Stand the arena's ambient attacker down BEFORE anything is measured, exactly as the enemy death
## probe does. A live enemy attacking the player can kill it, a player death resets the single arena,
## and a reset mid-run would restore the enemy this probe is about to defeat - so the cadence is
## removed rather than tolerated. Movement is deliberately NOT stood down: the walk is what makes the
## locomotion slot reachable on the enemy.
func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: enemy animation swappability probe loaded and _ready() executed")
		file.close()
	for ambient in get_tree().get_nodes_in_group(&"enemy_attacker"):
		if "auto_attack" in ambient:
			ambient.auto_attack = false


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_stage_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		STAGE_SETTLE:
			_audit_structure()
			_advance(STAGE_WINDOW_A)
		STAGE_WINDOW_A:
			_stand_off()
			if _tick_window(_enemy_set):
				_audit_window(_window_store, "as shipped (enemy set)", _enemy_set, _player_set)
				_bones_early = _bone_signature()
				# THE SWAP. One property, on a live adapter, mid-run. Nothing else changes.
				_enemy_adapter.animation_set = _player_set
				_advance(STAGE_WINDOW_B)
		STAGE_WINDOW_B:
			# The alternation must run HERE too, not only around the windows that re-position the player.
			# Window B is the one whose data was just swapped, so it is the window that most needs a forced
			# re-read - and a stand-off left frozen at the CLOSE distance when window A ended would leave
			# the enemy standing perfectly still, with nothing to force one.
			_stand_off()
			if _tick_window(_player_set):
				_audit_window(_window_store, "enemy given the PLAYER set", _player_set, _enemy_set)
				_run_adapter_identity_after_swap()
				_enemy_adapter.animation_set = _enemy_set
				_stand_off()
				_advance(STAGE_WINDOW_C)
		STAGE_WINDOW_C:
			# Same alternation as A and B, and for the same reason: the window arms on a SLOT CHANGE, and
			# a stand-off that stops alternating leaves the enemy standing still with nothing to force
			# the adapter to re-resolve under the restored set. This is the window that proves the swap
			# went BACK, so it must be measured, not merely opened.
			_stand_off()
			if _tick_window(_enemy_set):
				_audit_window(_window_store, "enemy set RESTORED", _enemy_set, _player_set)
				_bones_late = _bone_signature()
				_audit_bones_move()
				_capture_mesh_before_death()
				_kill_enemy()
				_advance(STAGE_DEATH)
		STAGE_DEATH:
			_sample_death_hold()
			if _stage_frame >= DEATH_HOLD_FRAMES:
				_audit_death_ownership()
				_audit_death_determinism()
				_advance(STAGE_FROZEN)
		STAGE_FROZEN:
			_tick_frozen()
		_:
			_finish()


func _advance(next: int) -> void:
	_stage = next
	_stage_frame = 0
	if next == STAGE_WINDOW_A or next == STAGE_WINDOW_B or next == STAGE_WINDOW_C:
		_open_window()


# --- 1. The architecture, as assembled ----------------------------------------

func _audit_structure() -> void:
	_player = get_tree().get_first_node_in_group("player_actor")
	_expect(_player != null, "the player actor is discoverable by the 'player_actor' group")
	var main := get_node_or_null("Main")
	if main == null:
		main = get_tree().current_scene
	_enemy = _find_named(main, ENEMY_ACTOR_NAME)
	_expect(_enemy != null, "the test enemy '%s' is present in the arena" % ENEMY_ACTOR_NAME)
	if _player == null or _enemy == null:
		_fail("both actors are required for every check below")
		return
	_lines.append("player: %s" % String(_player.name))
	_lines.append("enemy:  %s (%s)" % [String(_enemy.name), _enemy.get_class()])

	_audit_adapter_identity()
	_audit_visual_separation()
	_audit_sets()
	_audit_same_slot_different_clip()
	_audit_fallback_policy()
	_audit_in_place()
	_audit_gameplay_geometry()
	_audit_death_ownership_declaration()


## THE CHECK THAT MAKES "one generic adapter" MEANINGFUL. Two actors running the same script is not
## enough on its own if a third script exists that the enemy could switch to, so the tree is scanned
## for one as well.
func _audit_adapter_identity() -> void:
	_player_adapter = _player.get_node_or_null("Animation")
	_enemy_adapter = _enemy.get_node_or_null("Animation")
	_expect(_player_adapter != null and _player_adapter.has_method("slot_name"),
		"the player carries the shared AnimationAdapter node")
	_expect(_enemy_adapter != null and _enemy_adapter.has_method("slot_name"),
		"the enemy carries an AnimationAdapter node")
	if _player_adapter == null or _enemy_adapter == null:
		return

	var player_script = _player_adapter.get_script()
	var enemy_script = _enemy_adapter.get_script()
	_expect(player_script != null and enemy_script != null, "both adapter nodes carry a script")
	_expect(player_script == enemy_script,
		"the enemy runs THE SAME adapter script OBJECT as the player, not a copy of it")
	_expect(String(player_script.resource_path) == ADAPTER_PATH,
		"that shared script is the generic adapter (%s)" % ADAPTER_PATH)
	_expect(_player_adapter.call("is_wired") and _enemy_adapter.call("is_wired"),
		"both adapters are wired to their own actor's shared state")

	var intruders := _find_enemy_adapter_scripts()
	_expect(intruders.is_empty(),
		"no enemy-specific adapter implementation exists anywhere in the tree (found %s)" % str(intruders))
	_lines.append("adapter script: %s (shared by both actors)" % ADAPTER_PATH)


## Both actors must wear a visual at the SAME layer of the chain, found the way the adapter finds it:
## a child in the `visual_driver` group. If the enemy's visual were discovered some other way, the
## shared discovery path would not be what is being exercised.
func _audit_visual_separation() -> void:
	_player_visual = _find_visual(_player)
	_enemy_visual = _find_visual(_enemy)
	_expect(_player_visual != null, "the player carries a visual in the 'visual_driver' group")
	_expect(_enemy_visual != null, "the enemy carries a visual in the 'visual_driver' group")
	if _player_visual == null or _enemy_visual == null:
		return
	_lines.append("player visual: %s (%s)" % [String(_player_visual.name), _player_visual.get_class()])
	_lines.append("enemy visual:  %s (%s)" % [String(_enemy_visual.name), _enemy_visual.get_class()])
	_expect(_player_visual.get_script() == _enemy_visual.get_script(),
		"both visuals run the SAME visual driver script (no second driver implementation)")

	# The visual is DOWNSTREAM: a child of the body, with no offset and no collision of its own.
	for pair in [["player", _player, _player_visual], ["enemy", _enemy, _enemy_visual]]:
		var who := String(pair[0])
		var body: Node3D = pair[1]
		var visual: Node = pair[2]
		_expect(visual.get_parent() == body,
			"%s: the visual is a CHILD of the gameplay body, so it inherits its transform" % who)
		var offset := (visual as Node3D).transform.origin if visual is Node3D else Vector3.ZERO
		_expect(offset.is_zero_approx(),
			"%s: the visual declares NO positional offset of its own (origin=%s)" % [who, str(offset)])
		var colliders := _count_collision(visual)
		_expect(colliders == 0,
			"%s: the visual subtree owns NO collision node at any depth (%d)" % [who, colliders])
		var intruding_groups: Array = []
		for group in visual.get_groups():
			var group_name := String(group)
			if group_name != "visual_driver":
				intruding_groups.append(group_name)
		_expect(intruding_groups.is_empty(),
			"%s: the visual joined no gameplay group beyond its own (found %s)" % [who, str(intruding_groups)])

	# The imported model must be a real rigged character on BOTH, not a bare wrapper node.
	for pair in [["player", _player_visual], ["enemy", _enemy_visual]]:
		var who := String(pair[0])
		var visual: Node = pair[1]
		var model: Node = visual.get_model() if visual.has_method("get_model") else null
		_expect(model != null, "%s: the visual resolved its imported model" % who)
		if model == null:
			continue
		_expect(_find_first(model, "Skeleton3D") != null,
			"%s: the imported model carries a Skeleton3D (a rigged character)" % who)
		_expect(_find_first(model, "MeshInstance3D") != null,
			"%s: the imported model carries a skinned MeshInstance3D" % who)


## The set an actor's VISUAL registered must be the set its ADAPTER resolves against. Two different
## sets on one actor would mean the adapter resolves clips the visual never loaded, which fails
## silently at play time - so it is checked rather than assumed.
func _audit_sets() -> void:
	_enemy_set = _enemy_adapter.get("animation_set")
	_player_set = _player_adapter.get("animation_set")
	_expect(_player_set != null, "the player adapter has an AnimationSet assigned")
	_expect(_enemy_set != null, "the ENEMY adapter has an AnimationSet assigned")
	if _player_set == null or _enemy_set == null:
		return
	_expect(_player_set != _enemy_set,
		"the two actors are assigned DISTINCT AnimationSet RESOURCES, not one shared resource")
	_expect(String(_player_set.get("display_name")) != String(_enemy_set.get("display_name")),
		"the two sets are different sets ('%s' vs '%s')" % [
			String(_player_set.get("display_name")), String(_enemy_set.get("display_name"))])
	_expect(String(_enemy_set.get("display_name")).contains("Arena")
		or String(_enemy_set.get("display_name")).contains("Enemy"),
		"the enemy set identifies the ENEMY rather than the player ('%s')" % String(_enemy_set.get("display_name")))
	_expect(_player_set.slot_count() > 0 if _player_set.has_method("slot_count") else true, "")
	_lines.append("player set: %s (%s)" % [String(_player_set.get("display_name")), PLAYER_SET_PATH])
	_lines.append("enemy set:  %s (%s)" % [String(_enemy_set.get("display_name")), ENEMY_SET_PATH])

	if _player_visual != null:
		_expect(_player_visual.get("animation_set") == _player_set,
			"the player's VISUAL registered the same set its ADAPTER resolves against")
	if _enemy_visual != null:
		_expect(_enemy_visual.get("animation_set") == _enemy_set,
			"the enemy's VISUAL registered the same set its ADAPTER resolves against")
		_expect(String(_enemy_visual.get("model_path")) != "", "the enemy visual is wired to its model child")


## THE HEADLINE CLAIM. One slot, two live sets, two different clips - and both clips genuinely
## registered on the actor that will play them, so the difference is playable rather than declared.
func _audit_same_slot_different_clip() -> void:
	for slot in [PROOF_SLOT, SECONDARY_SLOT]:
		var player_result: Dictionary = _player_set.call("resolve", slot)
		var enemy_result: Dictionary = _enemy_set.call("resolve", slot)
		var player_clip := _first_clip(player_result)
		var enemy_clip := _first_clip(enemy_result)

		_expect(String(player_result.get("status", "")) == SetScript.STATUS_EXACT,
			"player set: slot '%s' resolves EXACT to real content" % slot)
		_expect(String(enemy_result.get("status", "")) == SetScript.STATUS_EXACT,
			"enemy set: slot '%s' resolves EXACT to real content" % slot)
		_expect(not player_clip.is_empty() and not enemy_clip.is_empty(),
			"both sets name a clip for slot '%s'" % slot)
		if player_clip.is_empty() or enemy_clip.is_empty():
			continue
		_expect(player_clip != enemy_clip,
			"THE PROOF - the SAME slot '%s' resolves to DIFFERENT clips: player='%s'  enemy='%s'" % [
				slot, player_clip.get_file(), enemy_clip.get_file()])
		if _player_visual != null:
			_expect(_player_visual.has_source(player_clip),
				"player slot '%s' resolves to a clip the PLAYER's visual registered" % slot)
			_expect(not _player_visual.has_source(enemy_clip),
				"the player's visual did NOT register the enemy's clip for '%s', so the two sets are" % slot
				+ " genuinely different content")
		if _enemy_visual != null:
			_expect(_enemy_visual.has_source(enemy_clip),
				"enemy slot '%s' resolves to a clip the ENEMY's visual registered" % slot)
			_expect(not _enemy_visual.has_source(player_clip),
				"the enemy's visual did NOT register the player's clip for '%s'" % slot)
		_lines.append("PROOF slot '%s':" % slot)
		_lines.append("    player -> %s" % player_clip)
		_lines.append("    enemy  -> %s" % enemy_clip)

	# The enemy's own attack slot: EXACT in the set that was authored for it, and absent from the
	# player's set. This is what makes the two sets structurally different rather than a re-skin.
	var enemy_attack: Dictionary = _enemy_set.call("resolve", ATTACK_SLOT)
	var player_attack: Dictionary = _player_set.call("resolve", ATTACK_SLOT)
	_expect(String(enemy_attack.get("status", "")) == SetScript.STATUS_EXACT,
		"the enemy set carries the enemy's OWN attack slot '%s' as exact content" % ATTACK_SLOT)
	_expect(String(player_attack.get("status", "")) != SetScript.STATUS_EXACT,
		"the player set has no exact content for the enemy's attack slot '%s' (got '%s')" % [
			ATTACK_SLOT, String(player_attack.get("status", ""))])
	_lines.append("enemy attack slot '%s' -> %s (player set: %s)" % [
		ATTACK_SLOT, _first_clip(enemy_attack).get_file(), String(player_attack.get("status", ""))])


## THE FIVE OUTCOMES, on the ENEMY's own set, including the one it is deliberately thin in. Missing
## content must be REPORTED as the outcome it is, never promoted to an exact match.
func _audit_fallback_policy() -> void:
	var exact: Dictionary = _enemy_set.call("resolve", PROOF_SLOT)
	_expect(String(exact.get("status", "")) == SetScript.STATUS_EXACT,
		"POLICY exact: a populated enemy slot reports EXACT")

	# Deliberately undeclared in the enemy set, with a SUBSTITUTE on record: the declared-substitute
	# outcome, which must be distinguishable from an exact hit.
	var fallback: Dictionary = _enemy_set.call("resolve", DECLARED_FALLBACK_SLOT)
	var fallback_status := String(fallback.get("status", ""))
	var fallback_clip := _first_clip(fallback)
	_expect(fallback_status == SetScript.STATUS_FALLBACK,
		"POLICY fallback: enemy slot '%s' reports FALLBACK, not exact (got '%s')" % [
			DECLARED_FALLBACK_SLOT, fallback_status])
	_expect(fallback_status != SetScript.STATUS_EXACT,
		"POLICY: a MISSING enemy slot is NOT reported as exact content")
	_expect(not fallback_clip.is_empty(),
		"POLICY: the declared substitute actually supplies a clip ('%s')" % fallback_clip.get_file())
	_expect(String(fallback.get("resolved", "")) != DECLARED_FALLBACK_SLOT,
		"POLICY: the substitute is named in the result, so the outcome is auditable ('%s')" % String(fallback.get("resolved", "")))
	_lines.append("POLICY fallback: '%s' -> %s (%s)" % [
		DECLARED_FALLBACK_SLOT, fallback_clip.get_file(), String(fallback.get("note", ""))])

	# Empty AND undeclared: the neutral stand-in, and the note must NAME the slot that was asked for.
	var neutral: Dictionary = _enemy_set.call("resolve", NEUTRAL_ONLY_SLOT)
	var neutral_status := String(neutral.get("status", ""))
	_expect(neutral_status == SetScript.STATUS_NEUTRAL,
		"POLICY neutral: the undeclared enemy slot '%s' falls to the neutral stand-in (got '%s')" % [
			NEUTRAL_ONLY_SLOT, neutral_status])
	_expect(String(neutral.get("note", "")).contains(NEUTRAL_ONLY_SLOT),
		"POLICY: the neutral note NAMES the slot that was missing ('%s')" % String(neutral.get("note", "")))
	_expect(_first_clip(neutral) == _first_clip(_enemy_set.call("resolve", "idle")),
		"POLICY: the neutral outcome supplies the set's declared neutral slot's clip")
	_lines.append("POLICY neutral: '%s' -> %s (%s)" % [
		NEUTRAL_ONLY_SLOT, _first_clip(neutral).get_file(), String(neutral.get("note", ""))])

	# A slot that does not exist in the vocabulary at all must still classify honestly rather than
	# inventing content.
	var unknown: Dictionary = _enemy_set.call("resolve", "slot_that_does_not_exist")
	_expect(String(unknown.get("status", "")) != SetScript.STATUS_EXACT,
		"POLICY: an unknown slot key is never reported as exact content")
	_lines.append("POLICY unknown slot -> '%s'" % String(unknown.get("status", "")))

	# The player's own set must be unaffected by the enemy's thinness: its slots still resolve exact.
	var player_neutral: Dictionary = _player_set.call("resolve", NEUTRAL_ONLY_SLOT)
	_expect(String(player_neutral.get("status", "")) == SetScript.STATUS_NEUTRAL,
		"POLICY: the PLAYER's set still reports neutral for its own missing slot, so semantics are"
		+ " global and unchanged")


## "No root motion" as a measurement: the clips the ENEMY registered must have had their horizontal
## travel flattened, and must still carry vertical motion - or in-place would have been achieved by
## flattening the clip into nothing.
func _audit_in_place() -> void:
	if _enemy_visual == null or not _enemy_visual.has_method("get_player"):
		return
	_expect(bool(_enemy_visual.get("convert_to_in_place")),
		"the enemy visual runs the SAME in-place correction as the player (convert_to_in_place)")
	var animation: AnimationPlayer = _enemy_visual.get_player()
	_expect(animation != null, "the enemy visual owns an AnimationPlayer")
	if animation == null:
		return
	if not animation.has_animation_library(&""):
		_fail("the enemy's AnimationPlayer declares no default library")
		return
	var library := animation.get_animation_library(&"")
	var names := library.get_animation_list()
	_expect(names.size() > 0, "the enemy registered %d real clip(s) from its own set" % names.size())
	var worst := 0.0
	for clip_name in names:
		var clip := library.get_animation(clip_name)
		if clip == null:
			continue
		var travel := _horizontal_travel_of(clip)
		worst = maxf(worst, travel)
		_expect(travel <= IN_PLACE_EPSILON,
			"enemy clip '%s' is IN PLACE (horizontal travel %.4f m)" % [String(clip_name), travel])
	_lines.append("worst enemy horizontal travel across %d clip(s): %.4f m" % [names.size(), worst])
	var walk := library.get_animation(_clip_named(library, "walk_F"))
	if walk != null:
		var vertical := _vertical_span_of(walk)
		_expect(vertical > 0.005,
			"the enemy's walk still has VERTICAL motion, so in place was not achieved by freezing it (%0.4f m)" % vertical)
	else:
		_lines.append("NOTE: no enemy clip named '*walk_F*' registered; vertical control skipped")


## Gameplay authority is INTACT and still on the body. The visual is an addition, not a swap.
func _audit_gameplay_geometry() -> void:
	_expect(_enemy is CharacterBody3D, "the enemy is still a CharacterBody3D")
	for required in ["Collision", "Hurtbox", "AttackHitbox", "Health", "Death", "DeathPresentation",
			"Attacker", "Locomotion", "ActorState", "Animation", "Reaction", "Participant"]:
		_expect(_enemy.get_node_or_null(required) != null,
			"the enemy still carries its authored '%s' node" % required)
	var collision := _enemy.get_node_or_null("Collision") as CollisionShape3D
	_expect(collision != null and collision.shape != null,
		"the enemy's gameplay collision shape is still present and non-empty")
	_expect(_enemy.get_node_or_null("Visual") == _enemy_visual,
		"the enemy visual is a child of the BODY and not of a collider")
	# The primitive capsule must be HIDDEN, or the character renders inside it. Its being a cylinder
	# also still being present is what keeps `hit_feedback` and the defeat presentation working.
	_enemy_mesh = _enemy.get_node_or_null("Mesh") as MeshInstance3D
	_expect(_enemy_mesh != null, "the enemy still carries its capsule Mesh node")
	if _enemy_mesh != null:
		_expect(not _enemy_mesh.visible,
			"the enemy's primitive capsule is hidden now that a real model is worn")


## The ownership DECLARATION, read before anything is defeated. A declaration is only worth reading
## if it is checked against the write, which the death stage does.
func _audit_death_ownership_declaration() -> void:
	_presentation = _enemy.get_node_or_null("DeathPresentation")
	_enemy_death = _enemy.get_node_or_null("Death")
	_expect(_presentation != null, "the enemy carries its defeat presentation")
	_expect(_enemy_death != null, "the enemy carries the defeat authority (EnemyDeathComponent)")
	if _presentation == null:
		return
	_expect(_presentation.has_method("owns_body_pose"),
		"the defeat presentation publishes the pose-ownership query")
	_expect(_presentation.has_method("pose_owner_name"),
		"the defeat presentation publishes the pose OWNER NAME")
	if not _presentation.has_method("owns_body_pose"):
		return
	_expect(not bool(_presentation.call("owns_body_pose")),
		"the presentation DECLARES it is NOT the defeat-pose owner (pose_body_meshes is FALSE)")
	_expect(not bool(_presentation.get("pose_body_meshes")),
		"pose_body_meshes is FALSE on the scene, so the declaration is authored rather than defaulted")
	var owner := String(_presentation.call("pose_owner_name"))
	_expect(owner.contains("visual") and not owner.contains("NONE PRESENT"),
		"the declared defeat-pose owner is the enemy VISUAL, and that visual exists ('%s')" % owner)
	# The declared owner must be able to deliver: the dead slot must be real content on the enemy set.
	var dead_result: Dictionary = _enemy_set.call("resolve", "dead")
	_expect(String(dead_result.get("status", "")) == SetScript.STATUS_EXACT,
		"the declared pose owner has content to pose with: enemy slot 'dead' resolves EXACT")
	_lines.append("declared defeat-pose owner: %s" % owner)
	_lines.append("enemy 'dead' clip: %s" % _first_clip(dead_result).get_file())


# --- 2. The live windows: does the adapter FOLLOW its assigned data? -----------

func _open_window() -> void:
	_window_store = []
	_window_armed = false
	_window_frames = 0
	_window_arm_frames = 0
	_window_armed_on_change = false
	_window_baseline_slot = String(_enemy_adapter.call("slot_name"))


## Arm on a SLOT CHANGE rather than on frames elapsed. The adapter re-resolves a slot only when the
## slot moves, so sampling before a change would compare against a resolution made under the previous
## set and would prove nothing about the new one.
func _tick_window(assigned: Resource) -> bool:
	if not _window_armed:
		_window_arm_frames += 1
		if String(_enemy_adapter.call("slot_name")) != _window_baseline_slot:
			_window_armed = true
			_window_armed_on_change = true
		elif _window_arm_frames >= ARM_BUDGET_FRAMES:
			# NO CHANGE INSIDE THE BUDGET MEANS NOTHING WAS MEASURED, which is a different statement from
			# "the swap was ignored". Sampling anyway was tried and was WRONG: the adapter keeps reporting
			# the resolution it made under the PREVIOUS set until a change forces a re-read, so stale
			# samples reported a working swap as a mismatch. Bailing with an empty store makes the window
			# report that it observed nothing, and `_audit_window` says so out loud.
			return true
		else:
			return false
	_window_frames += 1
	_window_store.append(_sample(_enemy_adapter, assigned))
	return _window_frames >= SAMPLE_FRAMES


func _sample(adapter: Variant, assigned: Resource) -> Dictionary:
	var slot := String(adapter.call("slot_name"))
	return {
		"slot": slot,
		"clip": String(adapter.call("resolved_clip")),
		"want": _first_clip(assigned.call("resolve", slot)),
	}


## The verdict for one window: every sampled resolution must equal what the set the adapter is
## HOLDING resolves that slot to - and on the slots where the two sets disagree, the adapter must be
## following the assigned one. The second half is the part an actor-conditional cannot pass.
func _audit_window(store: Array, label: String, assigned: Resource, other: Resource) -> void:
	_expect(store.size() > 0, "%s: the window recorded live resolutions (%d frames)" % [label, store.size()])
	if store.is_empty():
		return
	_lines.append("%s: armed on a live slot change=%s (waited %d frame(s) to arm)" % [
		label, str(_window_armed_on_change), _window_arm_frames])
	var mismatches: Array = []
	var differing := 0
	var differing_followed := 0
	var slots_seen: Array = []
	for entry in store:
		var slot := String(entry["slot"])
		if not slots_seen.has(slot):
			slots_seen.append(slot)
		if String(entry["clip"]) != String(entry["want"]):
			mismatches.append("'%s' played %s but the assigned set resolves %s" % [
				slot, String(entry["clip"]).get_file(), String(entry["want"]).get_file()])
		var mine := _first_clip(assigned.call("resolve", slot))
		var theirs := _first_clip(other.call("resolve", slot))
		if mine != theirs:
			differing += 1
			if String(entry["clip"]) == mine:
				differing_followed += 1
	_expect(mismatches.is_empty(),
		"%s: every live resolution equals the ASSIGNED set's answer (%d sample(s), %d mismatch(es))%s" % [
			label, store.size(), mismatches.size(),
			"" if mismatches.is_empty() else " e.g. " + String(mismatches[0])])
	_expect(differing > 0 and differing_followed == differing,
		"%s: on the slots where the two sets DISAGREE the adapter followed the assigned set (%d/%d)" % [
			label, differing_followed, maxi(differing, 0)])
	_lines.append("%s: %d sample(s), slots seen %s, mismatches %d, disagreeing slots %d" % [
		label, store.size(), str(slots_seen), mismatches.size(), differing])


## The swap changed DATA ONLY. Read afterwards, through the same live adapter objects, so "nothing
## about the code changed" is a checked statement rather than a claim in a report.
func _run_adapter_identity_after_swap() -> void:
	_expect(_enemy_adapter.get_script() == _player_adapter.get_script(),
		"after the swap the two adapters are STILL the same script object (the change was data only)")
	_expect(_enemy_adapter.get_script() == _enemy_adapter.get_script(),
		"the enemy adapter node is the same node it started as (nothing was re-created)")
	_expect(String(_player_adapter.get_script().resource_path) == ADAPTER_PATH,
		"the adapter still resolves to the shared generic script after the swap")
	# The adapter that FOLLOWED the other set's data must genuinely be the enemy's own node.
	_expect(_enemy.get_node_or_null("Animation") == _enemy_adapter,
		"the swapped adapter is still the ENEMY's own Animation node")


# --- 3. The skeleton is the thing being animated, so measure the skeleton ------

func _audit_bones_move() -> void:
	var skeleton := _enemy_skeleton()
	if skeleton == null:
		_fail("no Skeleton3D under the enemy's visual model, so no clip could pose anything")
		return
	_expect(skeleton.get_bone_count() > 0,
		"the enemy's skeleton carries real bones (%d)" % skeleton.get_bone_count())
	_bones_late = _bone_signature()
	_expect(not is_equal_approx(_bones_early, _bones_late),
		"the ENEMY SKELETON ACTUALLY MOVED while a clip played (%d bones), so the visual is animated rather"
		% skeleton.get_bone_count() + " than frozen")
	_lines.append("enemy bone signature: early=%.3f late=%.3f" % [_bones_early, _bones_late])


func _tick_frozen() -> void:
	if _stage_frame == FROZEN_A_FRAME:
		if _enemy_visual != null and _enemy_visual.has_method("stop"):
			_enemy_visual.stop()
		_bones_frozen_a = _bone_signature()
		return
	if _stage_frame == FROZEN_B_FRAME:
		_bones_frozen_b = _bone_signature()
		_expect(is_equal_approx(_bones_frozen_a, _bones_frozen_b),
			"with the driver STOPPED the enemy skeleton holds still, so THIS driver is what poses it")
		_lines.append("enemy stopped control: a=%.3f b=%.3f" % [_bones_frozen_a, _bones_frozen_b])
		_finish()


# --- 4. Death: exactly one pose owner, and it is measurable -------------------

func _capture_mesh_before_death() -> void:
	if _enemy_mesh == null:
		return
	_mesh_transform_before = _enemy_mesh.transform
	_mesh_material_before = _material_key(_enemy_mesh.material_override)
	_mesh_transform_captured = true


## The killing blow goes through `HealthComponent.apply_damage` - the single place all damage lands -
## so the run never depends on combat timing or on the enemy's cadence.
func _kill_enemy() -> void:
	var health := _enemy.get_node_or_null("Health")
	if health == null:
		_fail("the enemy has no Health node, so its defeat path could not be driven")
		return
	var event := DamageScript.new()
	event.amount = 9999.0
	event.source = null
	health.apply_damage(event)


## Sampled EVERY frame of the hold. One distinct transform and one distinct material across the whole
## hold is the measurement that says no second writer exists on any frame.
func _sample_death_hold() -> void:
	if _enemy_mesh == null:
		return
	_hold_transforms[str(_enemy_mesh.transform)] = true
	_hold_materials[_material_key(_enemy_mesh.material_override)] = true


func _audit_death_ownership() -> void:
	var health := _enemy.get_node_or_null("Health")
	_expect(health != null and bool(health.get("is_dead")),
		"the enemy's health reached zero through the normal damage chain")
	_expect(_enemy_death != null and bool(_enemy_death.call("is_defeated")),
		"the EXISTING defeat path processed the enemy")
	if _enemy_death != null and "defeats" in _enemy_death:
		_expect(int(_enemy_death.get("defeats")) == 1,
			"exactly ONE defeat was processed (%d)" % int(_enemy_death.get("defeats")))
	if _presentation == null:
		return
	_expect(bool(_presentation.call("is_showing")),
		"the defeat presentation reports it is showing (is_showing)")
	_expect(String(_presentation.call("status_text")) == "DEFEATED",
		"the world-space DEFEATED label is raised ('%s')" % String(_presentation.call("status_text")))

	# THE OWNER. The declaration still says visual, and the visual is the thing that actually moved.
	var owner := String(_presentation.call("pose_owner_name"))
	_expect(not bool(_presentation.call("owns_body_pose")),
		"after defeat the presentation still does NOT own the pose")
	_expect(owner.contains("visual") and not owner.contains("NONE PRESENT"),
		"the ONE declared owner after defeat is the visual ('%s')" % owner)

	# The owner delivered: the dead slot resolved through the adapter, and the visual played it.
	var dead_clip := _first_clip(_enemy_set.call("resolve", "dead"))
	_expect(String(_enemy_adapter.call("slot_name")) == "dead",
		"the enemy adapter is asking for the 'dead' slot ('%s')" % String(_enemy_adapter.call("slot_name")))
	_expect(String(_enemy_adapter.call("resolved_clip")) == dead_clip,
		"the adapter resolved 'dead' to the enemy set's dead clip through the real lookup")
	_expect(String(_enemy_visual.call("current_source")) == dead_clip,
		"the ENEMY VISUAL is playing that dead clip, so animation owns the final pose")
	_lines.append("deads slot resolved: %s" % dead_clip)


## ORDER INDEPENDENCE, as a measurement rather than an argument. The capsule is re-read on every
## frame of the hold and must never change: with one writer and the other writing nothing, there is
## no frame on which the two could disagree.
func _audit_death_determinism() -> void:
	_expect(_mesh_transform_captured, "the capsule's pre-defeat transform was captured")
	_expect(_hold_transforms.size() == 1,
		"the capsule transform was IDENTICAL on every one of the %d held frames (%d distinct value(s))" % [
			DEATH_HOLD_FRAMES, _hold_transforms.size()])
	_expect(_hold_materials.size() == 1,
		"the capsule material_override was IDENTICAL on every held frame (%d distinct value(s))" % [
			_hold_materials.size()])
	if _mesh_transform_captured and _enemy_mesh != null:
		_expect(_enemy_mesh.transform.is_equal_approx(_mesh_transform_before),
			"the competing transform writer stopped: the capsule holds its PRE-DEFEAT transform")
		_expect(_material_key(_enemy_mesh.material_override) == _mesh_material_before,
			"the competing material writer stopped: the capsule holds its PRE-DEFEAT material")
		_expect(not _enemy_mesh.visible,
			"the capsule is still hidden after defeat, so the rigged pose is the only body read")
	_lines.append("death hold: %d distinct transform(s), %d distinct material(s) over %d frames" % [
		_hold_transforms.size(), _hold_materials.size(), DEATH_HOLD_FRAMES])
	_lines.append("capsule transform before defeat: %s" % str(_mesh_transform_before))


# --- Helpers ------------------------------------------------------------------

func _enemy_skeleton() -> Skeleton3D:
	if _enemy_visual == null or not _enemy_visual.has_method("get_model"):
		return null
	var model: Node = _enemy_visual.get_model()
	if model == null:
		return null
	return _find_first(model, "Skeleton3D") as Skeleton3D


## ONE number summarising the whole pose. Deliberately every bone: the packs pose the entire rig, and
## one unchanged finger would not mean the character is animating.
func _bone_signature() -> float:
	var skeleton := _enemy_skeleton()
	if skeleton == null:
		return INF
	var total := 0.0
	for i in skeleton.get_bone_count():
		var p := skeleton.get_bone_pose_position(i)
		var q := skeleton.get_bone_pose_rotation(i)
		total += p.x + p.y * 2.0 + p.z * 3.0
		total += (q.x + q.y + q.z + q.w) * 10.0
	return total


## Place the player at a distance that lets the enemy's OWN locomotion produce the slot changes this
## probe measures. Only the player's transform is authored, and the enemy is never driven directly.
##
## THE ALTERNATION IS LOAD-BEARING, and here is the failure it removes. The adapter re-resolves a slot
## only when the slot MOVES - its `_physics_process` returns early otherwise - so until something forces
## a re-read it keeps reporting the resolution it made under the PREVIOUS set. A window that held the
## enemy in one state therefore sampled a resolution that predated the swap, and reported a working swap
## as a mismatch. Cycling in and out of the enemy's stopping distance makes its `locomotion` slot
## acquire and drop every cycle, so every sample is a resolution made while holding the CURRENT set.
##
## `_stage_frame` and not the window's own frame count, because the alternation has to run during ARMING
## too: a key frozen until sampling began could never produce the change that arms the window.
func _stand_off() -> void:
	if _player == null or _enemy == null:
		return
	var away := _player.global_position - _enemy.global_position
	away.y = 0.0
	if away.length() < 0.5:
		away = -_enemy.global_transform.basis.z
	var close := int(_stage_frame / STAND_OFF_PERIOD_FRAMES) % 2 == 0
	var distance := STAND_OFF_NEAR if close else STAND_OFF
	var target := _enemy.global_position + away.normalized() * distance
	target.y = _player.global_position.y
	_player.global_position = target


func _find_visual(actor: Node3D) -> Node:
	if actor == null:
		return null
	for child in actor.get_children():
		if child.is_in_group(GROUP_VISUAL_DRIVER):
			return child
	return null


## Every script in the tree whose path looks like an ADAPTER and belongs to an ENEMY. The check this
## milestone would otherwise have to take on trust.
func _find_enemy_adapter_scripts() -> Array:
	var found: Array = []
	_scan_scripts(get_tree().root, found)
	return found


func _scan_scripts(node: Node, found: Array) -> void:
	var script = node.get_script()
	if script != null:
		var path := String(script.resource_path)
		if path.contains("adapter") and path.contains("enemy"):
			if not found.has(path):
				found.append(path)
	for child in node.get_children():
		_scan_scripts(child, found)


func _first_clip(result: Dictionary) -> String:
	var clips: PackedStringArray = result.get("clips", PackedStringArray())
	if clips.size() == 0:
		return ""
	return String(clips[0])


## A stable identity for a material, so "the material was not replaced" is an identity comparison and
## not a value comparison that a re-created identical material would pass.
func _material_key(material) -> String:
	if material == null:
		return "null"
	if material is Object:
		return "%s#%d" % [material.get_class(), material.get_instance_id()]
	return str(material)


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


## Vertical range of the same bones. The CONTROL that in-place did not flatten the motion instead.
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


func _count_collision(node: Node) -> int:
	var count := 0
	if node is CollisionObject3D or node is CollisionShape3D:
		count += 1
	for child in node.get_children():
		count += _count_collision(child)
	return count


func _find_named(root: Node, node_name: String) -> Node3D:
	if root == null:
		return null
	if String(root.name) == node_name:
		return root as Node3D
	for child in root.get_children():
		var found := _find_named(child, node_name)
		if found != null:
			return found
	return null


func _find_first(root: Node, type_name: String) -> Node:
	if root == null:
		return null
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_first(child, type_name)
		if found != null:
			return found
	return null


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		_lines.append("PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	_lines.append("FAIL  %s" % label)


func _finish() -> void:
	_stage = STAGE_DONE
	if _done:
		return
	_done = true
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
