class_name ParryComponent
extends Node
## One actor's parry (Milestone 7).
##
## A committed, STATIONARY defensive action with a narrow window that refuses
## incoming damage. It is the third member of the committed-action family, beside
## the attack state machine (Milestone 4) and the dodge (Milestone 6), and it uses
## the same three-phase shape an attack uses:
##
##   STARTUP   committed; the parry has not come out yet - and it is VULNERABLE.
##   WINDOW    the parry frames. Incoming damage is refused here and counted.
##   RECOVERY  committed; the window is shut - and it is VULNERABLE again.
##
## That shape is the whole point: a narrow correct window surrounded by commitment,
## so a mistimed parry is punished rather than free. Startup and recovery are not
## decoration - they are where an early or late press gets you hit.
##
## STATIONARY is what separates a parry from a dodge. A dodge moves the body 3.375 m;
## a parry does not move it at all. It commits the actor in place.
##
## What it does NOT own: it does not read input, does not move the body, does not
## damage anything, and has no riposte, counter-attack or visceral follow-up.
## Refusing the hit, and recording that it refused it, is the entire effect in this
## milestone. Any payoff belongs to a later milestone, with an enemy to pay it out on.
##
## Who does what:
##
##   ParryComponent   owns the parry's state, its timing, its window, its cost, and
##                    every refusal cause.
##   PlayerController reads the parry input and commits the body in place.
##   PlayerCombat     refuses to start an attack while a parry is committed.
##   DodgeComponent   refuses to start a dodge while a parry is committed.
##   HurtboxComponent refuses damage while the window is open, and counts it as a
##                    PARRY, kept separate from a dodge's i-frame refusal.
##
## MUTUAL EXCLUSION is a small read-only ring rather than an arbiter: this component
## asks combat and dodge whether they are committed, and each of those asks this one
## whether a parry is committed. Every question is a single boolean, every path is
## null-safe, and an actor missing any of the three simply never blocks anything.
## See roadmap section 8C for why it is three pairwise checks for now, and for the
## point at which it must become an arbiter instead.
##
## Attach one per actor, as a direct child of the body, named "Parry" so a consumer
## can find it without an explicit path. An actor with no ParryComponent cannot
## parry, and its hurtbox never refuses damage on a parry's behalf.

## Emitted once when a parry is actually accepted.
signal parry_started()

## Emitted once when a parry completes on its own. `landed` is true when the window
## actually refused at least one hit, which is what makes "the parry worked" a
## recorded fact rather than something a later system has to infer.
signal parry_finished(landed: bool)

## Emitted when a parry is refused ONLY because stamina was insufficient. The parry
## does not start, is not queued, and costs nothing.
signal parry_refused_by_stamina(cost: float)

## The parry's phases. IDLE is the absence of a parry, not a phase of one.
enum Phase { IDLE, STARTUP, WINDOW, RECOVERY }

@export_group("Timing")
## Seconds before the parry window opens. Committed and VULNERABLE.
@export var parry_startup := 0.08
## Seconds the parry window stays open. Damage arriving here is refused.
@export var parry_window := 0.18
## Seconds of commitment after the window closes. VULNERABLE again, so a mistimed
## parry is punishable rather than free.
@export var parry_recovery := 0.34

@export_group("Stamina")
## Stamina charged when a parry is accepted. Charged by THIS component: the cost
## belongs to the decision to parry, not to the hurtbox that refuses the hit.
@export var stamina_cost := 20.0
## The actor's stamina pool. Defaults to a sibling named "Stamina" on the owner.
@export var stamina_path: NodePath = NodePath("../Stamina")

@export_group("Commitment")
## The actor's attack state machine. A parry is refused while an attack is
## committed, so an attack cannot be cancelled into a parry.
@export var combat_path: NodePath = NodePath("../Combat")
## The actor's dodge. A parry is refused while a dodge is committed.
@export var dodge_path: NodePath = NodePath("../Dodge")

@export_group("Refusal Reporting")
## The actor's hurtbox. Used ONLY to listen for the hit refusals this parry's window
## causes, so a completed parry can report whether it actually landed. The hurtbox
## still reads the window itself through is_parry_window_open(); nothing is pushed
## into it from here.
@export var hurtbox_path: NodePath = NodePath("../Hurtbox")

## Print each phase transition and each refusal. Diagnostic.
@export var debug_logging := false

var _phase: int = Phase.IDLE
## Seconds spent in the current phase.
var _elapsed := 0.0
## True once the current parry's window has refused at least one hit.
var _landed := false

## Parries accepted since load.
var parries_started := 0
## Hits the current parry's window refused.
var hits_refused := 0
## Total hits refused across every parry since load. Diagnostic: this is what makes
## "the parry window actually refused damage" checkable rather than assumed.
var total_hits_refused := 0
## Parries refused because one was already running.
var parries_refused_while_parrying := 0
## Parries refused because an attack was committed.
var parries_refused_while_attacking := 0
## Parries refused because a dodge was committed.
var parries_refused_while_dodging := 0
## Parries refused because stamina was insufficient.
var parries_refused_by_stamina := 0

## Every parry joins this group, so tooling can enumerate them.
const GROUP_PARRY := &"parry"

var _stamina: StaminaComponent
var _combat: PlayerCombat
var _dodge: DodgeComponent
var _hurtbox: HurtboxComponent


func _ready() -> void:
	add_to_group(GROUP_PARRY)
	# Advance before DodgeComponent (-2), PlayerCombat (-1) and PlayerController (0),
	# so every consumer reads this frame's parry state rather than last frame's - the
	# same reason the dodge and the attack state machine run early.
	process_physics_priority = -3
	_hurtbox = _get_hurtbox()
	if _hurtbox != null:
		_hurtbox.damage_refused_by_parry.connect(_on_hit_refused)


func _physics_process(delta: float) -> void:
	if _phase == Phase.IDLE:
		return
	_elapsed += delta
	# Each phase times itself against its OWN authored duration. The elapsed counter
	# is reset on every transition, so comparing against a cumulative time here would
	# silently multiply the recovery.
	match _phase:
		Phase.STARTUP:
			if _elapsed >= parry_startup:
				_enter_phase(Phase.WINDOW)
		Phase.WINDOW:
			if _elapsed >= parry_window:
				_enter_phase(Phase.RECOVERY)
		Phase.RECOVERY:
			if _elapsed >= parry_recovery:
				_finish()


# --- Queries ----------------------------------------------------------------

## True while a parry is committed, in any phase. The mutual exclusion reads this.
func is_parrying() -> bool:
	return _phase != Phase.IDLE


## True ONLY while the parry window is open. The hurtbox reads this to refuse
## damage, and it is deliberately distinct from is_parrying(): startup and recovery
## are committed but VULNERABLE.
func is_parry_window_open() -> bool:
	return _phase == Phase.WINDOW


## True when the current or most recent parry's window refused at least one hit.
func has_landed() -> bool:
	return _landed


## Total committed time, startup through recovery.
func total_duration() -> float:
	return parry_startup + parry_window + parry_recovery


## Seconds left in the current phase, or 0 while idle.
func phase_remaining() -> float:
	if _phase == Phase.IDLE:
		return 0.0
	var total := 0.0
	match _phase:
		Phase.STARTUP:
			total = parry_startup
		Phase.WINDOW:
			total = parry_window
		Phase.RECOVERY:
			total = parry_recovery
	return maxf(0.0, total - _elapsed)


func state_name() -> String:
	match _phase:
		Phase.STARTUP:
			return "STARTUP"
		Phase.WINDOW:
			return "WINDOW"
		Phase.RECOVERY:
			return "RECOVERY"
		_:
			return "IDLE"


# --- Starting a parry -------------------------------------------------------

## The only way a parry begins. Refused unless the actor can genuinely parry, and
## every refusal is counted by cause so a refusal is never mistaken for a dropped
## input.
func try_start() -> bool:
	if _phase != Phase.IDLE:
		parries_refused_while_parrying += 1
		_log("refused: already parrying")
		return false

	# An attack commits the body for its whole timeline and cannot be cancelled, so
	# an attack cannot be escaped by parrying out of it.
	var combat := _get_combat()
	if combat != null and combat.is_busy():
		parries_refused_while_attacking += 1
		_log("refused: attack in progress")
		return false

	# A committed dodge owns the actor for its whole duration, so a dodge cannot be
	# cancelled into a parry either.
	var dodge := _get_dodge()
	if dodge != null and dodge.is_dodging():
		parries_refused_while_dodging += 1
		_log("refused: dodge in progress")
		return false

	# Stamina is checked BEFORE anything is accepted, so an unaffordable parry
	# leaves this component untouched: not started, not queued, nothing spent.
	var stamina := _get_stamina()
	if stamina != null and not stamina.has(stamina_cost):
		parries_refused_by_stamina += 1
		_log("refused: stamina %.1f < %.1f" % [stamina.current_stamina, stamina_cost])
		parry_refused_by_stamina.emit(stamina_cost)
		return false
	if stamina != null:
		stamina.try_spend(stamina_cost)

	_landed = false
	hits_refused = 0
	parries_started += 1
	_enter_phase(Phase.STARTUP)
	parry_started.emit()
	return true


# --- Internals --------------------------------------------------------------

func _enter_phase(next: int) -> void:
	_phase = next
	_elapsed = 0.0
	_log("-> %s" % state_name())


func _finish() -> void:
	var landed := _landed
	_phase = Phase.IDLE
	_elapsed = 0.0
	_log("finished (landed=%s)" % str(landed))
	parry_finished.emit(landed)


## A hit was refused by this parry's window. Called by the hurtbox, which is the
## authority on the refusal actually happening.
func _on_hit_refused(_event: DamageEvent) -> void:
	_landed = true
	hits_refused += 1
	total_hits_refused += 1
	_log("window refused a hit (#%d)" % hits_refused)


## Clear any parry in progress without emitting parry_finished. For tests and scene
## setup only - gameplay never calls this. Counters are left alone so a probe can
## still read deltas across a run.
func reset() -> void:
	_phase = Phase.IDLE
	_elapsed = 0.0
	_landed = false
	hits_refused = 0


func _get_stamina() -> StaminaComponent:
	if _stamina == null or not is_instance_valid(_stamina):
		if String(stamina_path).is_empty():
			return null
		_stamina = get_node_or_null(stamina_path) as StaminaComponent
	return _stamina


func _get_combat() -> PlayerCombat:
	if _combat == null or not is_instance_valid(_combat):
		if String(combat_path).is_empty():
			return null
		_combat = get_node_or_null(combat_path) as PlayerCombat
	return _combat


func _get_dodge() -> DodgeComponent:
	if _dodge == null or not is_instance_valid(_dodge):
		if String(dodge_path).is_empty():
			return null
		_dodge = get_node_or_null(dodge_path) as DodgeComponent
	return _dodge


func _get_hurtbox() -> HurtboxComponent:
	if _hurtbox == null or not is_instance_valid(_hurtbox):
		if String(hurtbox_path).is_empty():
			return null
		_hurtbox = get_node_or_null(hurtbox_path) as HurtboxComponent
	return _hurtbox


func _log(message: String) -> void:
	if debug_logging:
		print("[PARRY] %s: %s" % [name, message])
