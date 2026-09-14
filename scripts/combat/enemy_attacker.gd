class_name EnemyAttacker
extends Node
## One enemy's single telegraphed attack (Milestone 8).
##
## The smallest real attacker that makes Cascadia's DEFENSIVE systems testable: a
## committed, readable windup -> active -> recovery swing that delivers damage
## through the existing HitboxComponent -> HurtboxComponent -> HealthComponent
## chain and nothing else.
##
## WHY THIS IS NOT PlayerCombat: the player's attack state machine reads player
## input through CascadiaInput. An enemy must never read player input, and it has
## no stamina, dodge or parry of its own. Reusing that class would have meant
## either an input-reading enemy or a branch inside the player's state machine,
## so this is a separate component that reuses the three-phase SHAPE and the
## AttackDefinition payload rather than the owner.
##
## This is deliberately NOT enemy AI. There is no navigation, no pathing, no
## chase, no target selection and no second attack. The enemy stands where it is
## placed, turns to face its target while idle, and swings on a fixed cadence when
## the target is inside engage_range. That is the whole behaviour.
##
## DEFEAT is owned by EnemyDeathComponent, not here. This component only ASKS whether
## the enemy is defeated; once it is, the enemy stops acting entirely and refuses
## every further start, including a code-driven one.
##
## Commitment is structural, exactly as it is for the player: an attack can only
## begin from IDLE, so once windup starts there is no path back to neutral except
## by finishing recovery. The FACING is locked at the moment the attack starts and
## is never re-read while it runs, so walking around a windup genuinely works.
##
## Attach one per attacking actor, as a direct child of the body, named
## "Attacker", with a sibling "AttackHitbox" on GameLayers.HITBOX.

## Emitted once when an attack is actually accepted.
signal attack_started(definition: AttackDefinition)

## Emitted once when an attack completes on its own.
signal attack_finished(definition: AttackDefinition)

## The phases. IDLE is the absence of an attack, not a phase of one. WINDUP is
## named for what it is - the telegraphed, vulnerable build-up - and maps onto
## AttackDefinition.startup.
enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

## Every attacker joins this group, so tooling can enumerate ambient hostiles
## without a hard-coded scene path. The verification probes use it to stand the
## arena's test attacker down: a probe measures ONE system, and must never be
## fighting the arena at the same time.
const GROUP_ATTACKER := &"enemy_attacker"

@export_group("Attack")
## Seconds of telegraphed commitment before the damage window opens. The
## telegraph is visible for exactly this long, and the actor is VULNERABLE.
@export var windup := 0.60
## Seconds the damage window stays open. One hit per target, no longer.
@export var active := 0.12
## Seconds of commitment after the window closes. VULNERABLE again, so a
## mistimed dodge or parry is punished rather than free.
@export var recovery := 0.70
## Damage this attack applies. Deliberately different from the player's 15/32 so
## a probe can never confuse who dealt what.
@export var damage := 20.0

@export_group("Engagement")
## Flat distance at which the attacker will commit to a swing. Outside this it
## simply stands and faces its target.
@export var engage_range := 2.8
## Seconds of IDLE after recovery completes before the next swing may begin.
@export var attack_cooldown := 1.6
## Swing on its own cadence when the target is in range. Turn OFF to drive the
## attacker by hand, which is what the diagnostic probe does.
@export var auto_attack := true
## Turn to face the target while idle. Locked once an attack commits.
@export var face_target := true

@export_group("Death")
## The enemy's death state, if it has one. Read ONLY to refuse a new attack and to
## stop acting once the enemy is defeated. Defaults to a sibling named "Death". An
## enemy without one simply never dies and keeps its previous behaviour exactly, so
## no existing scene breaks by omitting the node.
@export var death_path: NodePath = NodePath("../Death")

@export_group("Wiring")
## The HitboxComponent this attacker opens. Defaults to a sibling named
## "AttackHitbox" under the owning body.
@export var hitbox_path: NodePath = NodePath("../AttackHitbox")
## The telegraph node shown during WINDUP. Defaults to a sibling named
## "Telegraph"; actor without one simply has no visual tell.
@export var telegraph_path: NodePath = NodePath("../Telegraph")
## Explicit target override. Leave empty and the target is found through
## target_group instead.
@export var target_path: NodePath
## Group the target actor belongs to. Keeps this component from depending on any
## player class - it only needs a Node3D that answers to a group name.
@export var target_group: StringName = &"player_actor"

## Print each phase transition and each refusal. Diagnostic.
@export var debug_logging := false

## The attack this component performs. Built from the exported values in _ready(),
## the same way PlayerCombat builds its own, so the numbers live in one place.
var attack: AttackDefinition

var _phase: int = Phase.IDLE
## Seconds spent in the current phase.
var _elapsed := 0.0
## Seconds left before an auto-attack may begin.
var _cooldown_left := 0.0

var _body: Node3D
var _hitbox: HitboxComponent
var _telegraph: Node3D
var _target: Node3D
## The enemy's death state. Untyped and duck-typed on purpose: this component only
## ever asks whether the enemy is defeated, so any component that answers
## `is_defeated()` works and no particular death class is depended on.
var _death: Node

## Attacks accepted since load.
var attacks_started := 0
## Attacks refused because one was already committed. Counted by cause so a
## refusal is never mistaken for a dropped intent.
var attacks_refused_while_attacking := 0
## Attacks refused because the target was outside engage_range.
var attacks_refused_out_of_range := 0
## Attacks refused because the enemy was already defeated. Counted by cause like
## every other refusal, so "the defeated enemy did nothing" is a recorded fact and
## never looks like a dropped input or a distance refusal.
var attacks_refused_while_defeated := 0
## Attacks refused because the resolved target is not usable right now: gone, a
## corpse, a defeated actor, or not a combat participant at all. Before 8K this check
## did not exist - the target was whatever the group returned, so a corpse was a
## legal target and the enemy would turn its body to face it.
var attacks_refused_no_target := 0
## Refusals split by the exact reason CombatParticipant reported. Diagnostic: this is
## what makes each cause checkable rather than inferred from one lumped counter.
var target_refusals_dead := 0
var target_refusals_defeated := 0
var target_refusals_missing := 0
var target_refusals_non_participant := 0
var target_refusals_not_targetable := 0

## The refusal reason last recorded by the auto-attack cadence, or -1 for none. A
## REASON and not a boolean on purpose: while an enemy stands next to an unusable
## target the cause can change (out of range, then dead, then defeated), and a
## boolean would suppress every cause after the first, making a changed refusal
## invisible. Tracking the reason records each NEW cause once, so the counters
## answer "how many times did it want to act and could not, and why" instead of
## becoming a frame count.
var _last_auto_refusal := -1


func _ready() -> void:
	add_to_group(GROUP_ATTACKER)
	# Runs AFTER ParryComponent (-3), DodgeComponent (-2) and PlayerCombat (-1), so
	# on the frame this attacker opens its damage window the player's defensive
	# windows have already advanced for that frame. The defences evaluate first;
	# the attack lands second. That ordering is deliberate, not incidental.
	_body = get_parent() as Node3D
	attack = AttackDefinition.make("Enemy Attack", windup, active, recovery, damage)
	_hitbox = _resolve_hitbox()
	_telegraph = _resolve_telegraph()
	if _telegraph != null:
		_telegraph.visible = false


func _physics_process(delta: float) -> void:
	# A defeated enemy does not act at all: no facing, no cadence, no swing. Asked
	# rather than cached, so a defeat takes effect on the frame it happens.
	if _is_defeated():
		return
	match _phase:
		Phase.IDLE:
			_cooldown_left = maxf(0.0, _cooldown_left - delta)
			if face_target:
				_face_target()
			if auto_attack and _cooldown_left <= 0.0:
				if is_target_in_range():
					_last_auto_refusal = -1
					try_start()
				else:
					# The cadence is ready but nothing it could legally swing at is
					# there. try_start() is the refusal authority, so the only thing
					# this path adds is being counted at all - otherwise a dead target
					# produces "the enemy did not swing" with no recorded cause.
					_auto_start_refusal()
			else:
				_last_auto_refusal = -1
		Phase.WINDUP:
			_elapsed += delta
			if _elapsed >= windup:
				_open_window()
		Phase.ACTIVE:
			_elapsed += delta
			if _elapsed >= active:
				_close_window()
		Phase.RECOVERY:
			_elapsed += delta
			if _elapsed >= recovery:
				_complete()


# --- Queries ----------------------------------------------------------------

## True while an attack is committed, in any phase.
func is_attacking() -> bool:
	return _phase != Phase.IDLE


## True only while the damage window is open.
func hitbox_is_open() -> bool:
	return _hitbox != null and _hitbox.active


func phase_name() -> String:
	match _phase:
		Phase.WINDUP:
			return "WINDUP"
		Phase.ACTIVE:
			return "ACTIVE"
		Phase.RECOVERY:
			return "RECOVERY"
		_:
			return "IDLE"


## Seconds left in the current phase, or 0 while idle.
func phase_remaining() -> float:
	if _phase == Phase.IDLE:
		return 0.0
	var total := 0.0
	match _phase:
		Phase.WINDUP:
			total = windup
		Phase.ACTIVE:
			total = active
		Phase.RECOVERY:
			total = recovery
	return maxf(0.0, total - _elapsed)


## Total committed time, windup through recovery.
func total_duration() -> float:
	return windup + active + recovery


## Flat (XZ) distance from this attacker to its target, or INF when there is none.
func distance_to_target() -> float:
	var target := _get_target()
	if target == null or _body == null:
		return INF
	var to := target.global_position - _body.global_position
	return Vector2(to.x, to.z).length()


## True only when the target is USABLE right now AND inside engage_range.
##
## The usability gate is what makes a corpse fail safely: before 8K this was a pure
## distance test, so a dead or defeated actor standing in reach was still a legal
## target and the enemy would turn its body to face it.
func is_target_in_range() -> bool:
	if not has_valid_target():
		return false
	return distance_to_target() <= engage_range


## Whether the resolved target is a usable combat participant right now. Delegates to
## CombatParticipant so there is exactly one authority for the answer; an actor with
## no participant component keeps the pre-8K health-based answer.
func has_valid_target() -> bool:
	return CombatParticipant.is_usable_target(_get_target())


## Why the current target is unusable, as a CombatParticipant.Refusal. NONE when it
## is usable. Exposed so a probe can NAME the cause rather than only count it.
func target_refusal_reason() -> int:
	return CombatParticipant.target_refusal(_get_target())


# --- Starting an attack -----------------------------------------------------

## The only way an attack begins. Refused unless the actor is idle, its target is a
## usable combat participant, that target is genuinely in range, and the enemy is not
## defeated. Every refusal is counted by cause.
func try_start() -> bool:
	# Defeat is checked FIRST, before the phase and before the range test, so a
	# defeated enemy refuses every start and the refusal is recorded as a DEFEAT
	# refusal rather than being mistaken for an out-of-range one.
	if _is_defeated():
		attacks_refused_while_defeated += 1
		_log("refused: defeated")
		return false

	if _phase != Phase.IDLE:
		attacks_refused_while_attacking += 1
		_log("refused: already attacking")
		return false

	# Target usability is checked BEFORE the range test, so an unusable target is
	# refused for the right reason instead of looking like a distance failure.
	if not has_valid_target():
		attacks_refused_no_target += 1
		var reason := target_refusal_reason()
		_record_target_refusal(reason)
		_log("refused: no usable target (%s)" % CombatParticipant.refusal_name(reason))
		return false

	if not is_target_in_range():
		attacks_refused_out_of_range += 1
		_log("refused: target out of range")
		return false

	attacks_started += 1
	_enter(Phase.WINDUP)
	_log("started")
	attack_started.emit(attack)
	return true


# --- Internals --------------------------------------------------------------

## The damage window opens here and nowhere else, so damage cannot land outside
## ACTIVE. Opening the window also switches the telegraph off: the tell exists
## for the windup, not for the hit.
func _open_window() -> void:
	if _hitbox != null:
		_hitbox.damage = attack.damage
		_hitbox.activate()
	_enter(Phase.ACTIVE)


func _close_window() -> void:
	if _hitbox != null:
		_hitbox.deactivate()
	_enter(Phase.RECOVERY)


func _complete() -> void:
	var finished := attack
	if _hitbox != null:
		_hitbox.deactivate()
	_cooldown_left = attack_cooldown
	_enter(Phase.IDLE)
	_log("finished")
	attack_finished.emit(finished)


func _enter(next: int) -> void:
	_phase = next
	_elapsed = 0.0
	# Telegraph visibility has exactly one source of truth: the phase.
	if _telegraph != null:
		_telegraph.visible = next == Phase.WINDUP
	_log("-> %s" % phase_name())


## Turn the body to face the target, yaw only. A body with rotation.y = 0 faces
## -Z, so facing a flat direction d is atan2(-d.x, -d.z). Roll and pitch are
## never touched - the horizon stays upright, as everywhere else in Cascadia.
func _face_target() -> void:
	var target := _get_valid_target()
	if target == null or _body == null:
		return
	var to := target.global_position - _body.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	_body.rotation.y = atan2(-to.x, -to.z)


## Clear any attack in progress without emitting attack_finished, and WITHOUT
## touching the defeated state. Gameplay calls this through the player's arena reset
## and through the enemy's own defeat; tests and scene setup call it too. Counters are
## left alone so a probe can still read deltas across a run.
##
## It deliberately does NOT clear EnemyDeathComponent's defeated flag: this is the
## method the player's death circuit calls, so clearing defeat here would make a
## defeated enemy stand back up every time the player died.
func reset() -> void:
	_cooldown_left = 0.0
	cancel_attack()


## End the committed attack and close its damage window. Split out of reset() so the
## death circuit can cancel an attack on its own terms - the cooldown and the
## defeated state are none of its business.
func cancel_attack() -> void:
	_phase = Phase.IDLE
	_elapsed = 0.0
	if _hitbox != null:
		_hitbox.deactivate()
	if _telegraph != null:
		_telegraph.visible = false


## Stop every attacker in the tree from starting an attack on its own. Returns how
## many were stood down. Static so a verification probe can call it in one line
## without resolving any scene path: a probe must be able to isolate the system it
## measures from the live test arena around it.
static func stand_down_all(tree: SceneTree) -> int:
	var count := 0
	if tree == null:
		return 0
	for node in tree.get_nodes_in_group(GROUP_ATTACKER):
		var attacker := node as EnemyAttacker
		if attacker != null:
			attacker.auto_attack = false
			count += 1
	return count


## The target actor, or null when there is none. Found by group so this component
## depends on no player class: it only needs a Node3D answering to target_group.
func _get_target() -> Node3D:
	if _target == null or not is_instance_valid(_target):
		if not String(target_path).is_empty():
			_target = get_node_or_null(target_path) as Node3D
		else:
			_target = get_tree().get_first_node_in_group(target_group) as Node3D
	return _target


## The target ONLY while it is a usable combat participant, or null. This is what the
## facing code asks for, so the body never turns to face a corpse.
func _get_valid_target() -> Node3D:
	var target := _get_target()
	if CombatParticipant.is_usable_target(target):
		return target
	return null


## Record a target refusal under its own cause, so "the target was unusable" and "the
## target was too far away" can never blur into one number.
func _record_target_refusal(reason: int) -> void:
	match reason:
		CombatParticipant.Refusal.DEAD:
			target_refusals_dead += 1
		CombatParticipant.Refusal.DEFEATED:
			target_refusals_defeated += 1
		CombatParticipant.Refusal.MISSING:
			target_refusals_missing += 1
		CombatParticipant.Refusal.NOT_PARTICIPANT:
			target_refusals_non_participant += 1
		CombatParticipant.Refusal.NOT_TARGETABLE:
			target_refusals_not_targetable += 1
		_:
			pass


## The auto-attack path wanted to swing and could not, so the reason is recorded.
## try_start() is still the refusal authority - it owns every counter and the log line
## - but it decides on WINDUP vs out-of-range vs unusable target, and the cadence gate
## here already answered the range question, so the unusable-target case never reaches
## it from this path.
##
## Recorded ONCE per refusal SPELL rather than once per frame, and once per CAUSE.
## `_last_auto_refusal` remembers which reason was last recorded and is reset to -1
## the moment the target becomes usable or auto_attack is off. Comparing the reason
## rather than a bare boolean matters: a spell that starts as OUT_OF_RANGE and then
## becomes DEAD - which is exactly what happens when a target dies while the attacker
## watches it - is a NEW refusal and must be recorded, or the dead-target counter
## never moves. A bare boolean silently swallowed that case.
func _auto_start_refusal() -> void:
	var reason := target_refusal_reason()
	if reason == _last_auto_refusal:
		return
	_last_auto_refusal = reason
	attacks_refused_no_target += 1
	_record_target_refusal(reason)
	_log("refused from the auto-attack cadence: no usable target (%s)" % CombatParticipant.refusal_name(reason))


func _resolve_hitbox() -> HitboxComponent:
	if String(hitbox_path).is_empty():
		return null
	return get_node_or_null(hitbox_path) as HitboxComponent


func _resolve_telegraph() -> Node3D:
	if String(telegraph_path).is_empty():
		return null
	return get_node_or_null(telegraph_path) as Node3D


## True when the enemy is defeated and must not act. An enemy with no death state is
## never defeated, so a scene without one keeps its previous behaviour exactly.
func _is_defeated() -> bool:
	var death := _get_death()
	if death == null:
		return false
	if not death.has_method("is_defeated"):
		return false
	return bool(death.call("is_defeated"))


## The enemy's death state, or null when there is none. Duck-typed on purpose: any
## component answering `is_defeated()` works, so this state machine depends on no
## particular enemy-death class.
func _get_death() -> Node:
	if _death == null or not is_instance_valid(_death):
		if String(death_path).is_empty():
			return null
		_death = get_node_or_null(death_path)
	return _death


func _log(message: String) -> void:
	if debug_logging:
		print("[ENEMY] %s: %s" % [name, message])
