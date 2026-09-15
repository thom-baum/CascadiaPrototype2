class_name AnimationAdapter
extends Node3D
## ONE presentation layer for EVERY actor (Milestone 16 - animation adapter).
##
## WHY THIS EXISTS. Cascadia has never had an animation system: every actor's presentation has been
## primitives, and the animation pass was deliberately deferred until gameplay stopped moving.
## ActorState is the point at which it stopped moving - it already describes the player, both enemy
## variants and the NPC in one vocabulary. This node is the first CONSUMER of that vocabulary, and
## it answers exactly one question:
##
##     "Given what this actor is ALREADY doing, what should be playing?"
##
## It deliberately does NOT answer "what is this actor doing?" - that question belongs to gameplay,
## and the answer is whatever ActorState reports.
##
## THE DEPENDENCY DIRECTION IS THE WHOLE DESIGN, and it only ever runs one way:
##
##     gameplay owners   ->   ActorState    ->   AnimationAdapter   ->   driver
##     (PlayerCombat,          (the shared        (this node:            (a Label3D today; a
##      EnemyAttacker,          contract)          reads, translates)     real AnimationTree
##      DodgeComponent...)                                                later)
##
## Nothing here writes gameplay state, starts or cancels anything, or decides how long a phase
## lasts. Delete every AnimationAdapter in the project and every actor behaves EXACTLY as it does
## now - which is the test of whether a presentation layer is a presentation layer.
##
## GAMEPLAY TIMING STAYS AUTHORITATIVE. An attack's phases come from the attack's own definition, so
## this adapter reports them for exactly as long as the owner commits to them. A Heavy Brute's
## windup is longer than the arena attacker's because its PROFILE says so: the presentation follows
## the data instead of defining it.
##
## WHAT IT DELIBERATELY DOES NOT DO:
##
##   - No new combat or movement states. The action comes from ActorState VERBATIM.
##   - No animation-driven hitboxes, damage or timing.
##   - No root motion: gameplay owns every metre an actor moves.
##   - It writes NO mesh transforms and NO materials. `EnemyDeathPresentationDebug` owns the defeat
##     pose (mesh transform + material_override) and `hit_feedback_debug` owns material_overlay, so
##     writing either would clobber an existing presentation owner mid-effect.
##   - It does NOT pose a dead actor. A defeat already has a presentation, so this adapter reports
##     the DEAD intent and lets that presentation keep owning the body.
##
## Attach one per actor, as a direct child of the body, named "Animation".

## Every adapter joins this group, so a probe or a debug readout can enumerate them without a
## hard-coded actor list.
const GROUP_ANIMATION_ADAPTER := &"animation_adapter"

## The shared INTENT vocabulary. Every value `intent_name()` can return.
##
## This covers the WHOLE declared ActorState vocabulary rather than only the obvious states. An
## adapter that cannot express "parrying" would have to report something else while the player
## parries, which is exactly the silent misrepresentation this layer exists to avoid.
const INTENT_IDLE := "idle"
const INTENT_LOCOMOTION := "locomotion"
const INTENT_SPRINT := "sprint"
const INTENT_ATTACK_WINDUP := "attack_windup"
const INTENT_ATTACK_ACTIVE := "attack_active"
const INTENT_ATTACK_RECOVERY := "attack_recovery"
const INTENT_DODGE := "dodge"
const INTENT_PARRY := "parry"
const INTENT_HURT := "hurt"
const INTENT_STAGGER := "stagger"
const INTENT_DEAD := "dead"

## Reached by PATH rather than by global class name, and the reason is recorded because it has bitten
## this project already. The editor registers a `class_name` only once its registry has scanned the
## file, and a brand-new script in a brand-new directory is not registered the moment it is written -
## so annotating against the type makes this whole file fail to PARSE until the editor catches up. A
## dependency that can silently disable the presentation layer is worse than a duck-typed one.
const IntentScript := preload("res://scripts/animation/animation_intent.gd")

## The set vocabulary and its resolution statuses, reached by path for the same registration reason
## as the preload above. This driver must be able to report `missing` versus `none` WITHOUT the
## editor having registered a class, because the alternative is a driver that silently reports the
## wrong outcome in exactly the window where new content is being added.
const SetScript := preload("res://scripts/animation/animation_set.gd")

## Animation-set SLOT keys, one per presentable state (Milestone 21 - animation lookup architecture).
##
## A SLOT IS A NAMED REQUEST, NOT A CLIP. It says what the actor wants presented; the animation set
## decides which clip, if any, satisfies it. That split is the whole point of this layer: the shared
## adapter contains no clip name and no weapon knowledge, so a machete set is a new `.tres` rather
## than a change to the code every actor shares.
##
## LOCOMOTION AND SPRINT HAVE THEIR OWN SLOTS AND SHARE ONE FALLBACK. A set that distinguishes them
## can; a set that only has a run cycle declares `move` once instead of the same clip twice, which is
## the difference between a mapping a person can maintain and one they will get wrong.
const SLOT_IDLE := "idle"
const SLOT_LOCOMOTION := "locomotion"
const SLOT_SPRINT := "sprint"
const SLOT_MOVE := "move"
const SLOT_DODGE := "dodge"
const SLOT_PARRY := "parry"
const SLOT_HURT := "hurt"
const SLOT_STAGGER := "stagger"
const SLOT_DEAD := "dead"

## ATTACK SLOTS ARE KEYED BY ATTACK IDENTITY, NOT BY PHASE: `attack:<id>`. All three gameplay phases
## resolve to the SAME slot, so a set supplies one complete motion for the whole attack and the phase
## rides alongside as metadata. A set that later wants phase-split clips still fits - it declares the
## phase clips as the ordered clip list for that one slot - so Option A and Option B are both
## expressible without this driver changing shape.
##
## The identity comes from `ActorState.attack_id()`, which the gameplay owner reports. This driver
## never derives it, and an attack with no identity resolves to the set's `attack:unknown` slot
## rather than being guessed into a specific attack.
const SLOT_ATTACK_GENERIC := "attack"

## Runs AFTER ActorState (priority 10), which runs after the gameplay owners (negative priorities).
## The ordering is deliberate: this adapter then reports the state the actor ENDED the frame in,
## rather than one an action changed after it looked.
const PHYSICS_PRIORITY := 20

## How many intent transitions are remembered. Bounded so a long session cannot grow it forever,
## and exposed so a probe can prove an attack's phases were actually OBSERVED rather than inferred
## from the final resting state.
const HISTORY_LIMIT := 32

@export_group("Wiring")
## The shared state this adapter reads. Leave EMPTY to resolve it through the actor's own
## ActorState, so no scene has to hand-wire the pair.
@export var state_path: NodePath
## The actor body this adapter speaks for. Defaults to the parent body.
@export var actor_path: NodePath

@export_group("Animation set")
## The animation set this actor presents through (Milestone 21). TYPED AS `Resource` ON PURPOSE. The
## concrete class is reached by duck typing for the same registration reason the preload above exists,
## and because this layer must keep working for an actor that simply has no set assigned.
##
## LEAVE EMPTY AND NOTHING CHANGES. With no set there are no clips to look up, the resolved clip stays
## empty, and the placeholder label shows the SLOT it would have asked for. Absence of content is
## therefore a state this driver REPORTS rather than a failure it invents - which is what makes the
## set swappable without touching a single actor.
@export var animation_set: Resource
## Report each slot that resolves to no clip, once per slot. ON by default: a missing clip is an
## ASSET/CONFIGURATION problem, and the whole point of the fallback policy is that it is visible
## rather than silently presented as the wrong motion.
@export var report_missing_slots := true

@export_group("Placeholder driver")
## Whether to build the placeholder intent label. A real animation driver replaces
## `_apply_intent()` and this label with authored clips.
@export var show_label := true
## Height above the actor's origin the label floats, in metres.
@export var label_height := 2.6
@export var label_font_size := 40
@export var label_pixel_size := 0.005

## Print every intent transition. Diagnostic.
@export var debug_logging := false

## Emitted when the resolved intent changes. A real driver could consume this instead of polling.
signal intent_changed(from_intent: String, to_intent: String)

## How many times the intent has changed. Diagnostic: it separates "never changed" from "changed
## and came back", which one on-screen look cannot tell apart.
var changes := 0

var _actor: Node3D
var _state: ActorState
var _label: Label3D
## The intent currently being presented. Empty until the first read, which is NOT a state an actor
## can report - it means "this adapter has not looked yet".
var _intent := ""
## Every intent this adapter has presented, newest last. Read by a probe to prove it SAW an attack's
## phases rather than merely ending up idle.
var _history: Array = []
## The SLOT currently being requested: the named ask, independent of whether any set satisfies it.
## Kept ALONGSIDE the intent rather than derived from it, because two intents can share one slot
## (locomotion and sprint both fall back to `move`) and an attack's slot changes with its PHASE while
## the attack identity does not.
var _slot := ""
## What the assigned set resolved that slot to. "" means NOTHING resolved it - either no set is
## assigned at all, or the set is honestly missing that clip. Those are different problems and the
## message distinguishes them, but they present identically: as the absence of a clip.
var _resolved_clip := ""
## Slots already reported as missing, so the log records each missing clip ONCE rather than once per
## frame. Keyed by the slot, which is exactly what a set author has to go and add.
var _missing_slots := {}
## How the current slot resolved, straight from the set's own `resolve()`. Never recomputed here, so
## the driver cannot claim an outcome the set did not produce.
var _resolved_status := "none"
## The set's own explanation for an unsatisfied slot, carried for the warning line.
var _missing_note := ""


func _ready() -> void:
	add_to_group(GROUP_ANIMATION_ADAPTER)
	process_physics_priority = PHYSICS_PRIORITY
	_resolve()
	if show_label:
		_build_label()


func _physics_process(_delta: float) -> void:
	var next := _read_intent()
	# The SLOT is read every frame, not only on an intent change, because the two move INDEPENDENTLY.
	# An attack's slot follows its IDENTITY, and the identity can change while the intent stays
	# `attack_windup` - a light follow-up after a heavy lands in the same intent with a different
	# slot. A driver keyed on the intent alone would present the previous attack for that whole
	# windup, which is precisely the silent misrepresentation this layer exists to prevent.
	var next_slot := _read_slot()
	var intent_moved := next != _intent
	var slot_moved := next_slot != _slot
	if not intent_moved and not slot_moved:
		return
	var previous := _intent
	var previous_slot := _slot
	_intent = next
	_slot = next_slot
	if intent_moved:
		changes += 1
		_record(next)
	_resolve_slot(next_slot)
	# Only ever applied on a CHANGE. A driver that re-triggered a clip every frame would restart an
	# animation constantly, so the transition is the unit of work.
	_apply_intent(previous, previous_slot)
	if intent_moved:
		intent_changed.emit(previous, next)


# --- The contract this adapter consumes ---------------------------------------

## The presentation INTENT for what the actor is already doing, or "" when the adapter is not
## wired to a state at all. An empty answer is deliberately NOT reported as "idle": those are
## different statements, and only one of them is true of a misconfigured actor.
func _read_intent() -> String:
	var state := _get_state()
	if state == null or state.get_actor() == null:
		return ""

	# THE CONTRACT IS ASKED, NEVER GUESSED. The action is read VERBATIM, so this adapter can only
	# ever present a state the shared vocabulary already declares.
	match state.action_name():
		ActorState.ACTION_DEAD:
			return INTENT_DEAD
		ActorState.ACTION_STAGGERED:
			return INTENT_STAGGER
		ActorState.ACTION_DODGING:
			return INTENT_DODGE
		ActorState.ACTION_PARRYING:
			return INTENT_PARRY
		ActorState.ACTION_ATTACKING:
			# The attack's OWN phase picks the clip. WINDUP and STARTUP are the same phase of a
			# committed attack under two names, and ActorState already normalizes them for us.
			match state.phase_name():
				ActorState.PHASE_ACTIVE:
					return INTENT_ATTACK_ACTIVE
				ActorState.PHASE_RECOVERY:
					return INTENT_ATTACK_RECOVERY
				_:
					return INTENT_ATTACK_WINDUP

	# Reaching here means the action is NEUTRAL - not attacking, dodging, parrying, staggered or
	# dead - so the movement and reaction the SAME contract reports refine it. These are not a
	# second opinion about the action; they only decorate an actor that is otherwise at rest.
	#
	# `is_reacting()` covers a stagger as well, but a stagger can never reach this line because the
	# action branch above already returned. So what is left here is a plain flinch.
	if state.is_reacting():
		return INTENT_HURT
	if state.is_sprinting():
		return INTENT_SPRINT
	if state.is_moving():
		return INTENT_LOCOMOTION
	return INTENT_IDLE


## The animation SLOT for what the actor is already doing, or "" when the adapter is not wired to a
## state at all.
##
## Built from the SAME contract the intent is, through the read model, so the slot can never become a
## second opinion about what the actor is doing. The one thing it adds is the attack IDENTITY, which
## the intent vocabulary cannot express - see `animation_intent.gd`.
func _read_slot() -> String:
	var model := _read_model()
	if model == null:
		return ""
	return String(model.call("slot_key"))


## A snapshot of this instant's full read model, or null when there is no usable contract. Built
## FRESH every time rather than cached: it describes one instant, and a cached snapshot is how a
## presentation layer starts reporting the past as though it were the present.
func _read_model() -> RefCounted:
	var model = IntentScript.new()
	if not model.populate(_get_state()):
		return null
	return model


## Ask the assigned set what this slot resolves to.
##
## NOTHING IS CACHED ACROSS FRAMES, deliberately: a set can be reassigned at runtime and the next
## frame should honour it.
##
## WITH NO SET ASSIGNED the clip stays empty and the driver reports the slot it WOULD have asked for.
## That is a state this layer honestly reports rather than a failure it invents, and it is what makes
## the whole lookup readable before any content exists.
func _resolve_slot(slot: String) -> void:
	_resolved_clip = ""
	_resolved_status = SetScript.STATUS_NONE
	_missing_note = ""
	if animation_set == null or String(slot).is_empty():
		return
	if not animation_set.has_method("resolve"):
		return
	var result: Dictionary = animation_set.call("resolve", slot)
	_resolved_status = String(result.get("status", SetScript.STATUS_NONE))
	var clips: PackedStringArray = result.get("clips", PackedStringArray())
	if clips.size() > 0:
		# The FIRST clip is what a placeholder can name. A multi-clip slot is an ordered motion and
		# playing it in order is the real driver's job, not this one's.
		_resolved_clip = clips[0]
		return
	if _resolved_status == SetScript.STATUS_MISSING:
		_missing_note = String(result.get("note", ""))
		_report_missing(slot)


## Report a slot the set cannot satisfy, ONCE per slot.
##
## ON BY DEFAULT, because a missing clip is a CONTENT problem and the entire point of the fallback
## policy is that it becomes visible rather than quietly presented as the wrong motion. A slot that is
## empty and UNDECLARED is a configuration gap, never a gameplay event.
func _report_missing(slot: String) -> void:
	if not report_missing_slots or _missing_slots.has(slot):
		return
	_missing_slots[slot] = true
	var actor := _resolve_actor()
	var who: String = String(actor.name) if actor != null else String(name)
	var detail := _missing_note
	if detail.is_empty():
		detail = "no clip declared for this slot"
	push_warning("[ANIM] %s: slot '%s' has no clip - %s" % [who, slot, detail])


## Everything this adapter consumed, exactly as the contract reported it, for a probe to compare
## against ActorState directly. A read-through layer can be checked this way; a guessing one cannot.
func snapshot() -> Dictionary:
	var state := _get_state()
	if state == null:
		return {
			"action": "", "phase": "", "moving": false, "sprinting": false,
			"grounded": false, "turning": false, "yaw": 0.0, "speed": 0.0,
			"reaction": "none", "alive": false, "phase_remaining": 0.0,
		}
	return {
		"action": state.action_name(),
		"phase": state.phase_name(),
		"moving": state.is_moving(),
		"sprinting": state.is_sprinting(),
		"grounded": state.is_grounded(),
		"turning": state.is_turning(),
		"yaw": state.facing_yaw(),
		"speed": state.flat_speed(),
		"reaction": state.reaction_name(),
		"alive": state.is_alive(),
		"phase_remaining": state.phase_remaining(),
	}


# --- Queries ------------------------------------------------------------------

## The intent currently being presented. "" when unwired.
func intent_name() -> String:
	return _intent


## The actor this adapter speaks for, or null when unwired.
func get_actor() -> Node3D:
	return _resolve_actor()


## The shared state this adapter reads, or null when there is none.
func get_state() -> ActorState:
	return _get_state()


## True when this adapter found a live contract to read.
func is_wired() -> bool:
	var state := _get_state()
	return state != null and state.get_actor() != null


## A COPY of the intent history, newest last.
func history_values() -> Array:
	return _history.duplicate()


## Every intent name this adapter can report.
static func intent_vocabulary() -> PackedStringArray:
	return PackedStringArray([
		INTENT_IDLE, INTENT_LOCOMOTION, INTENT_SPRINT,
		INTENT_ATTACK_WINDUP, INTENT_ATTACK_ACTIVE, INTENT_ATTACK_RECOVERY,
		INTENT_DODGE, INTENT_PARRY, INTENT_HURT, INTENT_STAGGER, INTENT_DEAD,
	])


## The SLOT currently being requested - the named ask, independent of whether any set satisfies it.
## Always populated for a wired actor. This is the value an animation set is looked up with.
func slot_name() -> String:
	return _slot


## The CLIP the assigned set resolved the current slot to, or "" when nothing resolved it. Read this
## together with `resolution_status()`: an empty clip means either "no set is assigned" or "the set
## has no content for this slot", and those are different problems with different fixes.
func resolved_clip() -> String:
	return _resolved_clip


## Which of the set's resolution outcomes produced `resolved_clip()`: exact / fallback / neutral /
## missing / none. Reported separately from the clip because "we played the declared substitute" and
## "there was no content at all" must never be mistaken for each other.
func resolution_status() -> String:
	return _resolved_status


## The explanation behind a NEUTRAL or MISSING outcome, or "" when the slot resolved exactly or by
## declaration. A missing clip is an asset/configuration fact, so the reason travels with it.
func resolution_note() -> String:
	return _missing_note


## Whether the current slot resolved to something playable.
func has_clip() -> bool:
	return not _resolved_clip.is_empty()


## The animation set assigned to this adapter, or null. Typed as Resource on purpose - see the
## export's own note on why the concrete class is not depended on here.
func get_animation_set() -> Resource:
	return animation_set


## Every slot this adapter has found EMPTY, and how many times each intent was reported for it.
## Diagnostic: it is what turns "the mace set is thin" into a list of the exact keys to author.
func missing_slots() -> Dictionary:
	return _missing_slots.duplicate()


# --- The placeholder driver ---------------------------------------------------

## THE DRIVER SEAM, and the only place a real animation system has to touch.
##
## A real driver replaces exactly this function: take the resolved SLOT and its CLIP and play it.
## Everything above stays byte-for-byte identical, which is what makes this worth having as a shared
## layer rather than a second state machine per actor.
##
## The driver is handed BOTH the slot and the clip, and that pair is the whole contract. `_slot` is
## the request - always populated, because it is derived from gameplay state. `_resolved_clip` is the
## answer - empty when no set is assigned or when the set honestly has no content for that slot, and
## `resolution_status()` names which of those applies. So a real driver never has to guess whether a
## missing clip means "no content yet" or "this actor is unconfigured".
##
## STILL A PLACEHOLDER, and its text is now the honest full decision rather than the coarse intent:
## it shows the SLOT and, beneath it, the resolved clip when there is one. Before any content exists
## that means every actor visibly reports the slot it is asking for - which is exactly the read this
## pass is for, and it is why this remains a label rather than a stub `AnimationPlayer`.
func _apply_intent(previous: String, previous_slot: String) -> void:
	if _label != null:
		_label.text = _slot.to_upper()
		if not _resolved_clip.is_empty():
			_label.text += "\n" + _resolved_clip
		_label.modulate = _color_for(_intent)
	_log("intent %s -> %s | slot %s -> %s | clip '%s' (%s)" % [
		"(unread)" if previous.is_empty() else previous, _intent,
		"(unread)" if previous_slot.is_empty() else previous_slot, _slot,
		_resolved_clip, _resolved_status,
	])


## One distinct colour per intent, so a glance distinguishes a windup from an active window.
func _color_for(intent: String) -> Color:
	match intent:
		INTENT_SPRINT:
			return Color(0.45, 0.85, 0.95, 1)
		INTENT_ATTACK_WINDUP:
			return Color(1.0, 0.85, 0.25, 1)
		INTENT_ATTACK_ACTIVE:
			return Color(1.0, 0.45, 0.10, 1)
		INTENT_ATTACK_RECOVERY:
			return Color(0.85, 0.60, 0.25, 1)
		INTENT_DODGE:
			return Color(0.40, 0.65, 1.0, 1)
		INTENT_PARRY:
			return Color(0.45, 0.95, 0.55, 1)
		INTENT_HURT:
			return Color(1.0, 0.65, 0.55, 1)
		INTENT_STAGGER:
			return Color(1.0, 0.30, 0.30, 1)
		INTENT_DEAD:
			return Color(0.45, 0.20, 0.20, 1)
		INTENT_LOCOMOTION:
			return Color(0.88, 0.91, 0.95, 1)
	return Color(0.62, 0.66, 0.72, 1)


func _build_label() -> void:
	_label = Label3D.new()
	_label.name = "IntentLabel"
	_label.text = ""
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = label_font_size
	_label.pixel_size = label_pixel_size
	_label.outline_size = 14
	_label.modulate = _color_for(INTENT_IDLE)
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	_label.position = Vector3(0.0, label_height, 0.0)
	add_child(_label)


func _record(intent: String) -> void:
	_history.append(intent)
	if _history.size() > HISTORY_LIMIT:
		_history = _history.slice(_history.size() - HISTORY_LIMIT)


# --- Resolution ---------------------------------------------------------------

func _resolve() -> void:
	_actor = _resolve_actor()


func _resolve_actor() -> Node3D:
	if not String(actor_path).is_empty():
		if _actor == null or not is_instance_valid(_actor):
			_actor = get_node_or_null(actor_path) as Node3D
		return _actor
	if _actor == null or not is_instance_valid(_actor):
		_actor = get_parent() as Node3D
	return _actor


## The contract to read, resolved lazily and re-tried every frame until it is found, so an adapter
## whose actor readies its state node afterwards still wires up. Retrieved through the contract's
## OWN group, so a renamed state node does not silently unwire the presentation layer.
func _get_state() -> ActorState:
	if _state != null and is_instance_valid(_state):
		return _state
	if not String(state_path).is_empty():
		_state = get_node_or_null(state_path) as ActorState
	if _state == null:
		var actor := _resolve_actor()
		if actor != null:
			_state = ActorState.find_for(actor)
	return _state


func _log(message: String) -> void:
	if debug_logging:
		print("[ANIM] %s: %s" % [name, message])
