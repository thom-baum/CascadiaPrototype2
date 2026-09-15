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
## target selection and no second attack. This component owns exactly one thing: the
## swing, on a fixed cadence, when the target is inside engage_range. An enemy that
## also has to WALK to that range is given a separate `EnemyLocomotion` component -
## moving a body is a different concern from committing an attack, and folding it in
## here would put a body's physics inside the one component whose whole correctness
## argument is that it is a phase machine.
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
## THE YAW CONTRACT (Milestone 17). The body's rotation.y has exactly ONE writer at any
## moment, and which one depends on whether an attack is committed:
##
##   no attack committed  ->  `EnemyLocomotion`, turning at its own turn_speed_degrees
##   attack committed     ->  NEITHER writes; the facing committed at the start is frozen
##
## `_face_target()` therefore DEFERS to a Locomotion component when one is present, and this
## component stops being a yaw writer entirely. With no Locomotion component present it keeps
## writing yaw exactly as it always has, so every archived scene, probe and recorded result
## stays valid. Two systems must never write the same property, and this is the single place
## where that is decided.
##
## Attach one per attacking actor, as a direct child of the body, named
## "Attacker", with a sibling "AttackHitbox" on GameLayers.HITBOX.
##
## HIT INTERRUPTION (Milestone 18). A committed attack can now be ENDED BY A HIT, and the
## decision lives HERE - not in the reaction timer - for the reason HealthReactionComponent
## records: whether a committed attack survives a hit is an interrupt-armor decision that
## belongs to the actor's own action state machine. This component SUBSCRIBES to its
## sibling "Reaction" component's `staggered` signal and ends the attack through its own
## `cancel_attack()`, so the reaction component still cancels nothing and the attack state
## machine is still the only thing that changes the phase. The threshold is the reaction
## component's per-archetype `stagger_threshold`, so interruption is DATA, and an enemy
## whose threshold is left at its inert default keeps its previous behaviour exactly.

## Emitted once when a hit ended a committed attack. `amount` is the damage that did it.
signal attack_interrupted(amount: float)

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

@export_group("Data")
## The archetype data for this attacker: what this VARIANT is allowed to change.
##
## Copied into the exported fields below at _ready(), before the attack definition is built from
## them, which is what makes a second enemy variant a new .tres instead of a copied scene. Leave it
## EMPTY and this attacker behaves exactly as its own exported values already say - so wiring a
## profile can change numbers but can never introduce behaviour that was not already here.
@export var profile: EnemyAttackProfile

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
## Radius at which this enemy NOTICES its target, seeded one-way and one-time from the archetype
## profile exactly like every other number here. Read by `EnemyLocomotion`, which asks its sibling
## attacker for it rather than storing a second copy that could drift out of step.
##
## It lives on THIS component because the engagement tuning is one record and this is where the rest
## of it already is. This component itself never reads it: an attacker that has not been approached
## does not need to know how it was found.
@export var detection_radius := 0.0
## Flat distance at which the attacker will commit to a swing. Outside this it
## simply stands and faces its target - unless an `EnemyLocomotion` component is walking it in.
@export var engage_range := 2.8
## Seconds of IDLE after recovery completes before the next swing may begin.
@export var attack_cooldown := 1.6
## Swing on its own cadence when the target is in range. Turn OFF to drive the
## attacker by hand, which is what the diagnostic probe does.
@export var auto_attack := true
## Turn to face the target while idle. Locked once an attack commits.
@export var face_target := true

@export_group("Interruption")
## The hit reaction component whose `staggered` signal ends a committed attack. Defaults to a
## sibling named "Reaction".
##
## Duck-typed and OPTIONAL on purpose, exactly like death_path: an enemy with no reaction
## component simply never has an attack interrupted, so every scene and every archived result
## stays valid. The THRESHOLD is not read or duplicated here - it is the reaction component's
## own per-archetype value, asked through `would_stagger`, so interruption is calibrated in
## one place and by data.
@export var reaction_path: NodePath = NodePath("../Reaction")

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
## The locomotion component that owns this body's yaw and velocity, if the enemy has one. Defaults
## to a sibling named "Locomotion".
##
## Present: this attacker DEFERS all yaw writing to it and never touches rotation.y. Absent: this
## attacker writes yaw exactly as it did before that component existed. Duck-typed on `has_method`,
## so no particular locomotion class is depended on and a scene without one is untouched.
@export var locomotion_path: NodePath = NodePath("../Locomotion")
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
## Name carried into the built AttackDefinition. Seeded from the archetype profile when one is
## assigned, so a diagnostic reports the VARIANT's own name rather than a generic one.
var _display_name := "Enemy Attack"

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
## The locomotion component that owns this body's yaw and velocity, when the enemy has one.
## Untyped and duck-typed on purpose, exactly like `_death`: this component only needs to ask whether
## some other component has taken ownership of the facing, so any component answering
## `owns_uncommitted_facing()` works and no particular locomotion class is depended on.
var _locomotion: Node
## The sibling hit reaction. Untyped and duck-typed on purpose: the attacker only asks
## whether the incoming amount reaches the reaction's authored threshold.
var _reaction: Node

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

## Committed attacks a HIT ended, and how many interrupt-classified hits arrived while there
## was nothing committed to end. Counted separately like every other cause in Cascadia, so
## "it was interrupted" can never be confused with "the hit arrived and nothing happened".
var attacks_interrupted := 0
var hits_with_nothing_to_interrupt := 0

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
	_apply_profile()
	_body = get_parent() as Node3D
	attack = AttackDefinition.make(_display_name, windup, active, recovery, damage)
	_hitbox = _resolve_hitbox()
	_telegraph = _resolve_telegraph()
	if _telegraph != null:
		_telegraph.visible = false
	# The ONLY interrupt-armor wiring. The sibling reaction component CLASSIFIES the hit and
	# says so; this state machine decides what that costs a committed attack. Neither reaches
	# into the other's state.
	_connect_reaction()


## Copy the assigned archetype data into this component's OWN exported fields, once, before the
## attack definition is built from them.
##
## ONE-WAY AND ONE-TIME, and both halves of that are load-bearing. One-way, because nothing is ever
## written back to the profile, so two enemies sharing one archetype cannot corrupt each other's
## tuning. One-time, because an attack whose numbers could change while it is committed would not
## be authoritative gameplay timing - and gameplay timing is authoritative in Cascadia.
##
## Every field written here already has an exported default on this component, so a profile can
## only ever SET values this attacker already had. It cannot create behaviour.
func _apply_profile() -> void:
	if profile == null:
		return
	windup = profile.windup
	active = profile.active
	recovery = profile.recovery
	damage = profile.damage
	detection_radius = profile.detection_radius
	engage_range = profile.engage_range
	attack_cooldown = profile.attack_cooldown
	auto_attack = profile.auto_attack
	face_target = profile.face_target
	if not String(profile.display_name).is_empty():
		_display_name = profile.display_name


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
##
## THE YAW CONTRACT. When the enemy has a locomotion component, that component owns the body's yaw
## while no attack is committed and this function writes nothing at all. The two never both write:
## the delegated case turns at a real turn rate, and the committed case is frozen by the phase
## machine above. With no locomotion component this is the pre-existing instant snap, unchanged.
func _face_target() -> void:
	if _gives_facing_to_locomotion():
		return
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


# --- Hit interruption ---------------------------------------------------------

## End the committed attack because a hit was heavy enough to break it.
##
## THE ONLY HIT-DRIVEN CALLER of cancel_attack(), and the mechanics are deliberate:
##
##   1. The attack ends through `cancel_attack()`, so the damage window really closes and a
##      stale swing can no longer land. There is no second path that changes the phase.
##   2. The actor takes its NORMAL `attack_cooldown`, because without it the enemy is idle
##      on the very next frame and instantly re-windups - which reads as the interruption
##      having done nothing at all.
##   3. It returns whether an attack was actually ended. A hit that arrives while the enemy
##      is idle counts as having KEPT nothing, so a stale counter can never be read as an
##      interruption.
##
## `amount` is only used for the report; the threshold decision belongs to the reaction
## component, which is why this is never called for a hit below it.
func interrupt_attack(amount: float) -> bool:
	if _phase == Phase.IDLE:
		return false
	cancel_attack()
	_cooldown_left = attack_cooldown
	attacks_interrupted += 1
	_log("attack INTERRUPTED by %.1f damage - cooldown %.2f s" % [amount, attack_cooldown])
	attack_interrupted.emit(amount)
	return true


## A hit landed on this enemy. THE interrupt-armor decision, and it lives in the attack state
## machine rather than in the reaction timer on purpose.
##
## Public so a probe can drive it directly. The production route is the reaction component's
## `staggered` signal, which is connected to exactly this method.
##
## The amount is re-checked against the reaction component's OWN threshold rather than
## trusted. `staggered` is a signal any node in the tree can be handed to, so this keeps the
## decision honest even if it is called by hand, and it stops a partially wired reaction
## component from being able to interrupt. An enemy with no reaction component never has an
## attack interrupted, which is the pre-existing behaviour exactly.
func on_hit_received(amount: float) -> bool:
	var reaction := _get_reaction()
	if reaction == null:
		return false
	if not reaction.has_method(&"would_stagger"):
		return false
	if not bool(reaction.call(&"would_stagger", amount)):
		return false
	if not interrupt_attack(amount):
		hits_with_nothing_to_interrupt += 1
		return false
	return true


## Subscribe to the sibling reaction's stagger classification, once. A missing component, one
## with no such signal, or one already connected is a plain no-op.
func _connect_reaction() -> void:
	var reaction := _get_reaction()
	if reaction == null:
		return
	if not reaction.has_signal(&"staggered"):
		return
	var handler := Callable(self, &"_on_reaction_staggered")
	if not reaction.is_connected(&"staggered", handler):
		reaction.connect(&"staggered", handler)


func _on_reaction_staggered(amount: float) -> void:
	on_hit_received(amount)


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


## Whether some other component has taken ownership of this body's yaw.
##
## Asked as a QUESTION rather than read as a name, so a scene that happens to have an unrelated node
## called "Locomotion" does not silently stop this attacker from facing. A component that answers
## `owns_uncommitted_facing()` with true is making a statement about authority, and this is where it
## is honoured.
func _gives_facing_to_locomotion() -> bool:
	var locomotion := _get_locomotion()
	if locomotion == null:
		return false
	if not locomotion.has_method(&"owns_uncommitted_facing"):
		return false
	return bool(locomotion.call(&"owns_uncommitted_facing"))


## The locomotion component, or null when the enemy has none. Resolved once and re-resolved if it
## goes away, so a scene that never adds one never pays for the lookup.
func _get_locomotion() -> Node:
	if _locomotion == null or not is_instance_valid(_locomotion):
		_locomotion = null
		if not String(locomotion_path).is_empty():
			_locomotion = get_node_or_null(locomotion_path)
	return _locomotion


## The enemy's death state, or null when there is none. Duck-typed on purpose: any
## component answering `is_defeated()` works, so this state machine depends on no
## particular enemy-death class.
func _get_death() -> Node:
	if _death == null or not is_instance_valid(_death):
		if String(death_path).is_empty():
			return null
		_death = get_node_or_null(death_path)
	return _death


## The sibling hit reaction, or null when the enemy has none. Re-resolved if it goes away, so a
## scene that never adds one never pays for anything beyond the lookup.
func _get_reaction() -> Node:
	if _reaction == null or not is_instance_valid(_reaction):
		_reaction = null
		if not String(reaction_path).is_empty():
			_reaction = get_node_or_null(reaction_path)
	return _reaction


func _log(message: String) -> void:
	if debug_logging:
		print("[ENEMY] %s: %s" % [name, message])
