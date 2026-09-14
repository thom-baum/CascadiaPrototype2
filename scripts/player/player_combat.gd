class_name PlayerCombat
extends Node
## The player's attack state machine (Milestone 4).
##
## Owns the light attack and the heavy attack, and nothing else. Locomotion is
## not here, stamina is not here, health and the hurtbox are not here. Locomotion
## asks is_busy() and stands down; the attack hitbox supplies the damage.
##
## Gameplay is authoritative. The hitbox is open for exactly the ACTIVE phase
## defined by the AttackDefinition and for no longer. No animation clip, effect
## or sound influences any of it - those adapt to it later (Milestone 15).
##
## Commitment is structural, not a rule bolted on afterwards: an attack can only
## begin from IDLE, so once startup starts there is no path back to neutral
## except by finishing recovery. A press during an attack is refused outright
## rather than queued, so nothing here turns into a combo by accident.
##
## Stamina cost is deliberately NOT implemented. The stamina system does not
## exist yet and is its own milestone. When it arrives the cost belongs to this
## state machine, not to the hitbox.

enum State { IDLE, STARTUP, ACTIVE, RECOVERY }

## Emitted only when an attack is actually accepted, and when it completes.
signal attack_started(definition: AttackDefinition)
signal attack_finished(definition: AttackDefinition)

## Emitted when an attack is refused ONLY because stamina was insufficient. The
## attack does not start, is not queued, and costs nothing.
signal attack_refused_by_stamina(definition: AttackDefinition, cost: float)

## Light attack timeline, in seconds. A fast, cheap poke.
const LIGHT_STARTUP := 0.16
const LIGHT_ACTIVE := 0.10
const LIGHT_RECOVERY := 0.28
const LIGHT_DAMAGE := 15.0

## Heavy attack timeline. Deliberately long on both ends - the distance between
## these numbers and the light attack's is what commitment feels like.
const HEAVY_STARTUP := 0.44
const HEAVY_ACTIVE := 0.14
const HEAVY_RECOVERY := 0.62
const HEAVY_DAMAGE := 32.0

## The HitboxComponent this state machine opens, relative to this node.
## The damage volume this actor attacks with. Defaults to the sibling
## "AttackHitbox" under the owning actor.
@export var hitbox_path: NodePath = NodePath("../AttackHitbox")

@export_group("Stamina")
## Stamina charged when an attack is accepted. Charged by THIS state machine, not
## by the hitbox: the cost belongs to the decision to swing. An actor with no
## StaminaComponent is never charged and never refused.
@export var light_stamina_cost := 18.0
@export var heavy_stamina_cost := 32.0
## The actor's stamina pool. Defaults to a sibling named "Stamina" on the owner.
@export var stamina_path: NodePath = NodePath("../Stamina")

@export_group("Commitment")
## The actor's dodge. An attack is refused while a dodge is committed, so a dodge
## cannot be cancelled into a swing. Defaults to a sibling named "Dodge"; an actor
## without one simply never blocks an attack.
@export var dodge_path: NodePath = NodePath("../Dodge")
## The actor's parry. An attack is refused while a parry is committed, so a parry
## cannot be cancelled into a swing either. Defaults to a sibling named "Parry"; an
## actor without one simply never blocks an attack.
@export var parry_path: NodePath = NodePath("../Parry")
## The actor's death circuit. Read ONLY to refuse new attacks while the actor is
## dead. Defaults to a sibling named "Death"; an actor without one is never dead.
@export var death_path: NodePath = NodePath("../Death")

## Joins this group so diagnostics can find the player's combat state without a
## hard-coded scene path.
const GROUP_PLAYER_COMBAT := &"player_combat"
## Print each phase transition. Diagnostic.
@export var debug_logging := false

var light_attack: AttackDefinition
var heavy_attack: AttackDefinition

var state: int = State.IDLE
var current_attack: AttackDefinition = null
## Seconds spent in the current phase.
var phase_elapsed := 0.0
## Attacks accepted since load. How a refused input is proven to have started
## nothing, rather than quietly queued.
var attacks_started := 0
## Attacks refused because stamina was insufficient. Diagnostic: this is what
## makes "an unaffordable attack was refused" checkable, rather than looking
## identical to an attack that was silently dropped.
var attacks_refused_by_stamina := 0
## Attacks refused because a dodge was committed. Counted separately from the
## stamina refusal so the two causes are never confused.
var attacks_refused_while_dodging := 0
## Attacks refused because a parry was committed. Counted separately again, so the
## three refusal causes never collapse into one another.
var attacks_refused_while_parrying := 0

var _hitbox: HitboxComponent
var _input: CascadiaInput
var _stamina: StaminaComponent
var _dodge: DodgeComponent
var _parry: ParryComponent
var _death: DeathComponent


func _ready() -> void:
	# Join the group the combat readout and future lock-on enumerate through.
	# Without this the diagnostic can never find the state machine.
	add_to_group(GROUP_PLAYER_COMBAT)
	# Run before the player controller so a commit takes effect on the same frame
	# the attack starts instead of one frame later.
	process_physics_priority = -1
	light_attack = AttackDefinition.make(
		"Light Attack", LIGHT_STARTUP, LIGHT_ACTIVE, LIGHT_RECOVERY, LIGHT_DAMAGE)
	heavy_attack = AttackDefinition.make(
		"Heavy Attack", HEAVY_STARTUP, HEAVY_ACTIVE, HEAVY_RECOVERY, HEAVY_DAMAGE)
	_hitbox = _resolve_hitbox()


func _physics_process(delta: float) -> void:
	_read_input()
	_advance(delta)


# --- Queries ----------------------------------------------------------------

## True while any attack is in progress. Locomotion stands down while this holds.
func is_busy() -> bool:
	return state != State.IDLE


func state_name() -> String:
	match state:
		State.STARTUP:
			return "STARTUP"
		State.ACTIVE:
			return "ACTIVE"
		State.RECOVERY:
			return "RECOVERY"
		_:
			return "IDLE"


## True only while the damage window is open.
func hitbox_is_open() -> bool:
	return _hitbox != null and _hitbox.active


## Seconds left in the current phase, or 0 while idle.
func phase_remaining() -> float:
	if state == State.IDLE or current_attack == null:
		return 0.0
	var total := 0.0
	match state:
		State.STARTUP:
			total = current_attack.startup
		State.ACTIVE:
			total = current_attack.active
		State.RECOVERY:
			total = current_attack.recovery
	return maxf(0.0, total - phase_elapsed)


# --- Starting an attack -----------------------------------------------------

## The only way an attack begins. Refused unless fully idle, and that refusal is
## what makes an attack uncancellable.
func try_start(definition: AttackDefinition) -> bool:
	if state != State.IDLE or definition == null:
		return false

	# A dead actor starts nothing. Checked first, ahead of stamina and ahead of
	# every commitment gate, so a press that arrived a frame before the death
	# cannot become a swing after it.
	if is_dead():
		return false

	# A committed dodge owns the actor for its whole duration. The exclusion lives
	# HERE rather than only on the input path, for the same reason attack
	# commitment is structural: there must be no route into an attack out of a
	# dodge, whether the request came from input or from code. Checked before
	# stamina, so a refusal during a dodge never spends.
	if _is_dodging():
		attacks_refused_while_dodging += 1
		if debug_logging:
			print("[ATTACK] refused: dodge in progress")
		return false

	# Same rule for a committed parry. Dodge and parry are mutually exclusive, so at
	# most one of these two gates can ever be the one that fires.
	if _is_parrying():
		attacks_refused_while_parrying += 1
		if debug_logging:
			print("[ATTACK] refused: parry in progress")
		return false

	# Stamina is checked BEFORE anything is accepted, so an unaffordable attack
	# leaves the state machine completely untouched: not started, not queued, and
	# nothing spent. An actor with no StaminaComponent is simply never charged.
	var cost := _cost_of(definition)
	var stamina := _get_stamina()
	if stamina != null and not stamina.has(cost):
		attacks_refused_by_stamina += 1
		if debug_logging:
			print("[ATTACK] %s refused: stamina %.1f < %.1f" % [
				definition.display_name, stamina.current_stamina, cost])
		attack_refused_by_stamina.emit(definition, cost)
		return false
	if stamina != null:
		stamina.try_spend(cost)

	current_attack = definition
	attacks_started += 1
	_enter_phase(State.STARTUP)
	attack_started.emit(definition)
	return true


# --- Internals --------------------------------------------------------------

## Attacks are read only while idle. A press during an attack is left in the
## input layer's buffer to expire rather than being queued for later.
func _read_input() -> void:
	if state != State.IDLE:
		return
	var input := _get_input()
	if input == null:
		return
	# Deliberately no dodge special case here. A press during a dodge is consumed
	# and then refused by try_start() itself, which is the single enforcement point
	# for the mutual exclusion, so the press is counted rather than left buffered
	# and no second refusal path can drift out of sync with it.
	if input.consume_light_attack():
		try_start(light_attack)
	elif input.consume_heavy_attack():
		try_start(heavy_attack)


func _advance(delta: float) -> void:
	if state == State.IDLE or current_attack == null:
		return
	phase_elapsed += delta
	match state:
		State.STARTUP:
			if phase_elapsed >= current_attack.startup:
				_open_window()
		State.ACTIVE:
			if phase_elapsed >= current_attack.active:
				_close_window()
		State.RECOVERY:
			if phase_elapsed >= current_attack.recovery:
				_complete_attack()


## The damage window opens here and nowhere else, so damage cannot land outside
## ACTIVE.
func _open_window() -> void:
	if _hitbox != null:
		_hitbox.damage = current_attack.damage
		_hitbox.activate()
	_enter_phase(State.ACTIVE)


func _close_window() -> void:
	if _hitbox != null:
		_hitbox.deactivate()
	_enter_phase(State.RECOVERY)


func _complete_attack() -> void:
	var finished := current_attack
	if _hitbox != null:
		_hitbox.deactivate()
	current_attack = null
	state = State.IDLE
	phase_elapsed = 0.0
	if debug_logging:
		print("[ATTACK] %s -> IDLE (complete)" % finished.display_name)
	attack_finished.emit(finished)


func _enter_phase(next: int) -> void:
	state = next
	phase_elapsed = 0.0
	if debug_logging:
		var label := "-"
		if current_attack != null:
			label = current_attack.display_name
		print("[ATTACK] %s -> %s" % [label, state_name()])


func _resolve_hitbox() -> HitboxComponent:
	if String(hitbox_path).is_empty():
		return null
	return get_node_or_null(hitbox_path) as HitboxComponent


func _get_input() -> CascadiaInput:
	if _input == null or not is_instance_valid(_input):
		_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	return _input


# --- Stamina ----------------------------------------------------------------

## What one attack costs. Heavy is the committed, expensive option; anything else
## is priced as a light attack, which is the default case.
func _cost_of(definition: AttackDefinition) -> float:
	if definition == heavy_attack:
		return heavy_stamina_cost
	return light_stamina_cost


## The actor's stamina pool, or null when there is none. A missing pool means
## "never charged" rather than "cannot act", so an actor without stamina keeps
## its old behaviour exactly, and no scene breaks by omitting the node.
func _get_stamina() -> StaminaComponent:
	if _stamina == null or not is_instance_valid(_stamina):
		if String(stamina_path).is_empty():
			return null
		_stamina = get_node_or_null(stamina_path) as StaminaComponent
	return _stamina


# --- Dodge commitment -------------------------------------------------------

## True while a dodge is committed. An actor with no DodgeComponent is never
## dodging, so a scene without one keeps its previous attack behaviour exactly.
func _is_dodging() -> bool:
	var dodge := _get_dodge()
	return dodge != null and dodge.is_dodging()


## The actor's dodge, or null when there is none. Read-only: this state machine
## only ever asks whether a dodge is committed.
func _get_dodge() -> DodgeComponent:
	if _dodge == null or not is_instance_valid(_dodge):
		if String(dodge_path).is_empty():
			return null
		_dodge = get_node_or_null(dodge_path) as DodgeComponent
	return _dodge


## True while a parry is committed. An actor with no ParryComponent never parries.
func _is_parrying() -> bool:
	var parry := _get_parry()
	return parry != null and parry.is_parrying()


## The actor's parry, or null when there is none. Read-only: this state machine only
## asks whether a parry is committed.
func _get_parry() -> ParryComponent:
	if _parry == null or not is_instance_valid(_parry):
		if String(parry_path).is_empty():
			return null
		_parry = get_node_or_null(parry_path) as ParryComponent
	return _parry


# --- Death ------------------------------------------------------------------

## True while the actor is dead. An actor with no DeathComponent is never dead,
## so a scene without one keeps its previous attack behaviour exactly.
func is_dead() -> bool:
	var death := _get_death()
	return death != null and death.is_dead()


## End the current attack immediately: shut the damage window first, then clear
## the state, so an interrupted attack can never leave a live hitbox behind.
##
## For the death/reset circuit only. Gameplay itself never cancels an attack -
## attack commitment is structural and a swing can only otherwise end by finishing
## its recovery. This exists because a dead actor holding an open damage window
## would be a live attack with no owner.
func cancel_current_action() -> void:
	if _hitbox != null:
		_hitbox.deactivate()
	current_attack = null
	state = State.IDLE
	phase_elapsed = 0.0


## The actor's death circuit, or null when there is none. Read-only: this state
## machine only asks whether the actor is dead.
func _get_death() -> DeathComponent:
	if _death == null or not is_instance_valid(_death):
		if String(death_path).is_empty():
			return null
		_death = get_node_or_null(death_path) as DeathComponent
	return _death
