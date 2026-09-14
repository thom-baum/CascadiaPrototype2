class_name StaminaComponent
extends Node
## One actor's stamina pool (Milestone 5).
##
## Stamina is its own system. It does not know what sprinting, attacking or
## dodging are, and it does not move anything or damage anything. It owns a
## maximum, a current value, a regeneration rate and a short delay before
## regeneration resumes, and it answers two questions:
##
##   has(cost) -> bool        can this be afforded right now
##   try_spend(cost) -> bool  spend atomically, or refuse and change nothing
##
## Costs belong to the systems that pay them: locomotion pays for sprint, the
## attack state machine pays for an attack. Nothing in this file decides what
## anything costs, which is what keeps stamina from becoming a second, competing
## authority on movement or combat timing.
##
## Regeneration is paused for regen_delay seconds after a spend. That one rule is
## what gives sprinting, attacking and (later) dodging a shared pacing cost
## instead of three unrelated timers.
##
## Attach one per actor, as a direct child of the body, named "Stamina" so a
## consumer can find it without an explicit path. An actor with no
## StaminaComponent is simply never charged and never gated - every consumer
## treats "no pool" as "unlimited", so scenes without one keep working.

## Emitted whenever the current value changes, including on reset.
signal stamina_changed(current: float, maximum: float)

## Emitted on the transition to empty, once per depletion.
signal depleted()

## Emitted on the transition back to full, once per recovery.
signal recovered()

@export var max_stamina := 100.0
## Points restored per second once regeneration is running.
@export var regen_per_second := 22.0
## Seconds regeneration stays paused after the most recent spend or drain.
@export var regen_delay := 0.8
## Set false to freeze regeneration entirely (tests, cutscenes, death).
@export var regen_enabled := true
## Print each accepted or refused spend. Diagnostic.
@export var debug_logging := false

## Every stamina pool joins this group, so tooling can enumerate them.
const GROUP_STAMINA := &"stamina"

var current_stamina := 0.0

## How many spends were accepted. Diagnostic: proves a refusal started nothing.
var spent_count := 0
## How many spends were refused for insufficient stamina. Diagnostic.
var refused_count := 0

var _regen_block := 0.0


func _ready() -> void:
	add_to_group(GROUP_STAMINA)
	reset()


## Restore to full and clear the regeneration pause.
func reset() -> void:
	_regen_block = 0.0
	var before := current_stamina
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina > before:
		_log("reset to %.1f" % current_stamina)


## Restore to an EXACT recorded value (snapshot restore).
##
## Deliberately separate from reset(), exactly as HealthComponent separates reset() from
## restore_to(): reset() means "this pool starts fresh" and is what spawn, respawn and the arena
## reset use. This means "put this pool back to what a snapshot recorded" - a different intent with
## a different value. CLAMPED by _set_stamina so a corrupt or hand-edited save cannot push the pool
## out of range.
##
## The regeneration pause is cleared, so a restored pool behaves like a pool that was not mid
## cooldown: a load puts the run back to a playable state, not to a paused timer.
func restore_to(value: float) -> void:
	_regen_block = 0.0
	_set_stamina(value)
	_log("restored to %.1f" % current_stamina)


func _process(delta: float) -> void:
	if _regen_block > 0.0:
		_regen_block = maxf(0.0, _regen_block - delta)
		return
	if not regen_enabled or current_stamina >= max_stamina:
		return
	_set_stamina(current_stamina + regen_per_second * delta)


# --- Spending ---------------------------------------------------------------

## True when the pool can afford the cost right now. A cost of zero is always
## affordable, so a system with no cost never has to special-case itself.
func has(cost: float) -> bool:
	if cost <= 0.0:
		return true
	return current_stamina >= cost


## Spend atomically: either the whole cost is paid and true is returned, or
## nothing changes and false is returned. There is no partial spend, so a caller
## that is refused has paid nothing and started nothing.
func try_spend(cost: float) -> bool:
	if cost <= 0.0:
		return true
	if current_stamina < cost:
		refused_count += 1
		_log("refused: needs %.1f, has %.1f" % [cost, current_stamina])
		return false
	spent_count += 1
	_regen_block = regen_delay
	_set_stamina(current_stamina - cost)
	_log("spent %.1f -> %.1f" % [cost, current_stamina])
	return true


## Continuous drain for a held action such as sprint. Returns false once the
## pool is exhausted, so the caller can stop the action on the same frame.
##
## This deliberately does NOT re-arm the regeneration delay the way try_spend
## does. Sprinting calls this every frame; if each call restarted the delay,
## regeneration could never resume even long after the sprint ended.
func drain(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_stamina <= 0.0:
		return false
	_regen_block = regen_delay
	_set_stamina(current_stamina - amount)
	return current_stamina > 0.0


## Current stamina as 0..1 of maximum. For HUD bars.
func fraction() -> float:
	if max_stamina <= 0.0:
		return 0.0
	return current_stamina / max_stamina


func is_full() -> bool:
	return current_stamina >= max_stamina


# --- Internals --------------------------------------------------------------

func _set_stamina(value: float) -> void:
	var before := current_stamina
	current_stamina = clampf(value, 0.0, max_stamina)

	# The edge cases are computed BEFORE the no-change guard, and the guard is
	# forced open for them. This is not cosmetic: a continuous drain approaches
	# the floor and its final step lands a hair above zero (about 1e-7) which the
	# clamp then turns into exactly 0.0. `is_equal_approx(0.0, 1e-7)` is TRUE, so
	# a plain guard returns early and the depleted event is silently swallowed.
	# Measured before this fix: a 121-frame continuous drain emptied the pool
	# (100.0 -> 0.0) but emitted depleted 0 times, while a single spend to zero
	# emitted it correctly. Sprinting drains continuously, so the drained path is
	# the common one and the edge was effectively unreachable.
	var hit_empty := before > 0.0 and current_stamina <= 0.0
	var hit_full := before < max_stamina and current_stamina >= max_stamina
	if not hit_empty and not hit_full and is_equal_approx(current_stamina, before):
		return

	stamina_changed.emit(current_stamina, max_stamina)
	# Edge-triggered so a pool that stays empty, or stays full, announces the
	# transition once rather than every frame.
	if hit_empty:
		_log("depleted")
		depleted.emit()
	elif hit_full:
		_log("recovered")
		recovered.emit()


func _log(message: String) -> void:
	if debug_logging:
		print("[STAMINA] %s: %s" % [name, message])
