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


func _ready() -> void:
	add_to_group(GROUP_ANIMATION_ADAPTER)
	process_physics_priority = PHYSICS_PRIORITY
	_resolve()
	if show_label:
		_build_label()


func _physics_process(_delta: float) -> void:
	var next := _read_intent()
	if next == _intent:
		return
	var previous := _intent
	_intent = next
	changes += 1
	_record(next)
	# Only ever applied on a CHANGE. A driver that re-triggered a clip every frame would restart an
	# animation constantly, so the transition is the unit of work.
	_apply_intent(previous)
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


# --- The placeholder driver ---------------------------------------------------

## THE DRIVER SEAM, and the only place a real animation system has to touch.
##
## A real driver replaces exactly this function: take the resolved intent and play the matching
## clip. Everything above stays byte-for-byte identical, which is what makes this worth having as a
## shared layer rather than a second state machine per actor.
##
## The placeholder is a billboarded label, which is the honest prototype answer while the project
## has no clips: it makes the adapter's decision VISIBLE on every actor, so the contract can be
## read at a glance instead of inferred from a log.
func _apply_intent(previous: String) -> void:
	if _label != null:
		_label.text = _intent.to_upper()
		_label.modulate = _color_for(_intent)
	_log("intent %s -> %s" % ["(unread)" if previous.is_empty() else previous, _intent])


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
