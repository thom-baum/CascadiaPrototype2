class_name CreditLedger
extends Node
## The player's CARRIED Credits, and the ONE place an enemy defeat is converted into a reward
## (Milestone 9 - Soulslike credit economy and meaningful progression foundation).
##
## WHAT THIS IS. A Soulslike earns its currency from defeated enemies, carries it on the character,
## and only LATER banks or spends it. This node owns exactly the carried half of that loop:
##
##     an eligible enemy is defeated  ->  Credits are added to the carried balance
##
## WHAT IT DELIBERATELY IS NOT. It is NOT a bank, NOT a shop, NOT a stat system and NOT a save file.
## The four concepts below are kept APART on purpose, and only the first exists here:
##
##   CARRIED    the balance the active run holds        <- THIS NODE
##   STORED     safely banked at a future location      <- does not exist
##   SPENT      converted into stats/items/gear         <- does not exist
##   PERSISTENT restored by game-state saving (M10)     <- does not exist
##
## Reading `credits` and expecting it to survive a scene load would be a mistake, so it is spelled
## out here rather than left to be rediscovered.
##
## WHERE IT GETS ITS NUMBERS. It subscribes to the EXISTING `EnemyDeathComponent.defeated` signal and
## to nothing else. It does not read `died`, does not poll `is_dead`, and does not look at a health
## value, so "what counts as a defeat" keeps exactly one owner and the economy cannot drift from it.
## The economy OBSERVES the authority; it never redefines it.
##
## REWARD ELIGIBILITY is an explicit rule, not "this actor reached zero health". All four must hold:
##   1. the actor carries an EnemyDeathComponent (the authoritative defeat authority), and
##   2. that component reports is_defeated() true, and
##   3. that component reports mortal (an actor that declares mortal = false pays nothing - its
##      defeat path never even emits, so the exclusion is structural), and
##   4. the actor is not the player-controlled actor.
##
## Attach ONE of these to the game root, as a sibling of the player and the arena.

## Emitted whenever the carried balance changes. `delta` is what changed it, for presentation.
signal credits_changed(current: int, delta: int)

## Emitted when Credits were actually awarded, so a gain can be shown without comparing balances.
signal credits_awarded(actor_name: String, amount: int, total: int)

## Emitted when the run's carried balance was DROPPED as a retrievable stake at a world position
## (Milestone 19). `amount` is what was dropped, which is the balance the death COST - not the
## balance the run was carrying, when `starting_credits` is above zero.
signal stake_placed(amount: int, position: Vector3)

## Emitted when the player walked back to a standing stake and took its contents back.
signal stake_reclaimed(amount: int)

## Emitted when a standing stake was DESTROYED without being claimed - a second death, a new run,
## or a load. Counted separately from `stake_reclaimed` so "the run got its Credits back" can never
## be confused with "the run lost them for good".
signal stake_lost(amount: int)

## Every ledger joins this group, so presentation and probes can find it without a scene path.
const GROUP_LEDGER := &"credit_ledger"

## The group the player-controlled actor joins. Used to state the player exclusion explicitly rather
## than relying only on the player not carrying an EnemyDeathComponent.
const GROUP_PLAYER_ACTOR := &"player_actor"

@export_group("Economy")
## The carried balance an item of fresh run state starts with. Zero, because the player has earned
## nothing until an enemy is defeated.
@export var starting_credits := 0

## Credits awarded for ONE eligible enemy defeat. THE single provisional economy value in the project,
## deliberately explicit and trivial to replace: no currencies, rarity, loot tables, modifiers,
## multipliers or balancing exist, and none of them belong in this milestone.
@export var reward_per_enemy := 100

## Whether the player's DEATH resets the carried balance to `starting_credits` and clears this
## run's reward history.
##
## true  - the rule the project now plays by, and the default. A Soulslike that keeps your
##         carried Credits through a death has no stake in dying, and the reward history had a
##         second, independent defect: enemies are REVIVED by the death circuit, so an actor
##         the run had already been paid for came back alive, killable and targetable while
##         being permanently worth nothing. Clearing the history is what makes a revived enemy
##         worth Credits again.
## false - death leaves the economy exactly as it found it. Kept as a POLICY because the
##         superseded decision is on record (roadmap 8L.7) and a save/load or a future
##         difficulty option may legitimately want it back.
##
## LIFETIME counters are deliberately NOT reset either way. `awards`, every refusal counter and
## `loads` describe what this process has SEEN, not what the run is carrying, and clearing them
## on a death would destroy the diagnostics that make the economy checkable.
@export var reset_on_death := true

## Whether a death's lost balance is DROPPED as a RETRIEVABLE stake at the death position
## (Milestone 19 - the Soulslike death-drop loop).
##
## true  - the rule the project now plays by, and the default. `reset_on_death` decides that dying
##         COSTS the run its carried Credits; this decides WHERE THEY GO. Dropping them makes the
##         cost a setback the player can undo by walking back to where they fell, which is the whole
##         point of the loop: a death that simply deletes the balance gives the player no reason to
##         return to the place that killed them.
##         Exactly ONE stake ever exists. A second death before the first is claimed DESTROYS the
##         first, so dying twice without recovering is what makes the loss permanent.
## false - the lost balance is destroyed outright. That is the Milestone 18 behaviour, kept as a
##         POLICY because it is on record and a difficulty option may legitimately want it back.
##
## A stake is RUN-LOCAL and is deliberately NOT saved: a load replaces the run's world state, so a
## stake created after the save point is destroyed rather than left standing in a world it did not
## belong to. That is also what stops a load from paying the same stake twice.
@export var drop_on_death := true

## Print each award and each refusal. Diagnostic.
@export var debug_logging := false

## The CARRIED balance. The only piece of economy state that exists.
var credits := 0

## Total ever earned since the last reset. Diagnostic: lets a probe check the running total
## independently of the current balance.
var credits_earned := 0

## Awards actually granted, and refusals split by CAUSE. Counted separately for the same reason every
## other refusal in Cascadia is: "it did not pay" must never be mistakable for "it was not asked".
var awards := 0
var awards_refused_duplicate := 0
var awards_refused_non_mortal := 0
var awards_refused_not_defeated := 0
var awards_refused_player := 0
var awards_refused_invalid := 0

## How many times the carried balance has been RESTORED from saved state. Counted separately from
## `awards` because a load is not a defeat: a restored balance must never inflate the award count.
var loads := 0

## Changes served by the player's death circuit, counted separately from every other reset so
## "the balance went back to the starting value because the player DIED" can never be confused
## with a new run, a load, or an award that merely happened to net out.
var death_resets := 0

## Stakes dropped, stakes claimed, and stakes destroyed unclaimed. Split three ways for the same
## reason every other outcome in Cascadia is: "the player got their Credits back" must never be
## mistakable for "the player lost them".
var stakes_placed := 0
var stakes_reclaimed := 0
var stakes_lost := 0

## Whether a stake is standing right now.
var _has_stake := false
## What the standing stake is worth.
var _stake_amount := 0
## Where the standing stake lies. Meaningless while `_has_stake` is false.
var _stake_position := Vector3.ZERO

## Instance ids of enemies already paid, so ONE enemy can never pay twice - however many times a
## signal fires, a frame repeats, or a check is re-run.
var _rewarded: Dictionary = {}
## Instance ids of defeat components already subscribed to, so re-scanning never double-connects.
var _watched: Dictionary = {}
## Instance ids of PLAYER death circuits already subscribed to, for the same reason.
var _watched_deaths: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP_LEDGER)
	# The carried balance belongs to the RUN, so it starts at the documented initial value here
	# rather than being left at whatever the editor last showed.
	credits = starting_credits
	_watch_enemies()
	_watch_death_circuits()


func _physics_process(_delta: float) -> void:
	# Enemies can be added at runtime, so the population is re-scanned. Cheap at this scale, and it
	# is what makes the reward path enumeration-driven rather than wired to a fixed actor list. The
	# death circuit is re-scanned the same way, so a player added later is picked up too.
	_watch_enemies()
	_watch_death_circuits()


# --- Queries -----------------------------------------------------------------

## The current CARRIED balance.
func get_credits() -> int:
	return credits


## How many distinct enemies have been paid since the last reset.
func rewarded_count() -> int:
	return _rewarded.size()


## Whether a stake is standing right now - Credits dropped by a death that the player has not yet
## walked back to claim.
func has_stake() -> bool:
	return _has_stake


## What the standing stake is worth, or 0 when there is none.
func stake_amount() -> int:
	return _stake_amount


## Where the standing stake lies, or the origin when there is none. Meaningless while `has_stake()`
## is false, so a presentation layer must ask that first rather than treating the origin as a place.
func stake_position() -> Vector3:
	return _stake_position


## The ledger in this tree, or null when there is none. Lets presentation and probes resolve it
## without a scene path.
static func find_ledger(tree: SceneTree) -> CreditLedger:
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP_LEDGER) as CreditLedger


# --- Awarding -----------------------------------------------------------------

## The carried balance gains Credits. Public because a future checkpoint, a pick-up or a test needs
## a way to move the balance that is NOT an enemy defeat; it does not decide eligibility.
func award_credits(amount: int, source: String = "") -> void:
	if amount <= 0:
		return
	credits += amount
	credits_earned += amount
	awards += 1
	_log("awarded %d from %s -> carried %d" % [amount, source, credits])
	credits_changed.emit(credits, amount)
	credits_awarded.emit(source, amount, credits)


## Whether ONE enemy defeat should pay, and if so, pay it.
##
## This is the REAL entry point: the `defeated` signal handler below calls exactly this, so a probe
## exercising it is testing the production path rather than reaching around it. Returns whether
## Credits were actually granted.
##
## `component` is deliberately UNTYPED: a freed or non-node reference must be refused rather than
## raise, which is the whole point of the invalid cases. Every path returns before touching state.
func handle_defeat(component) -> bool:
	if component == null or not is_instance_valid(component) or not (component is Node):
		awards_refused_invalid += 1
		return false

	var node := component as Node
	var id := node.get_instance_id()
	if _rewarded.has(id):
		awards_refused_duplicate += 1
		_log("refused: this actor has already been paid")
		return false

	var actor := node.get_parent()
	if actor == null or not is_instance_valid(actor):
		awards_refused_invalid += 1
		return false

	# The player has its own death/reset circuit and is never an enemy reward source.
	if actor.is_in_group(GROUP_PLAYER_ACTOR):
		awards_refused_player += 1
		_log("refused: the player is not an enemy reward source")
		return false

	# MORTALITY is checked BEFORE the defeated state, so a refusal is filed under the POLICY that
	# produced it. A non-mortal actor can never become defeated, so testing `is_defeated` first would
	# file every non-mortal refusal as NOT_DEFEATED - true about its current state, and silent about
	# the reason that state can never change - leaving awards_refused_non_mortal unreachable. Policy
	# first, state second, exactly as EnemyAttacker orders its own defeat and range gates.
	if not _is_mortal(node):
		awards_refused_non_mortal += 1
		_log("refused: the actor declares itself non-mortal")
		return false

	# Eligibility reads the component's OWN defeated state, so an actor that reached zero health
	# without entering the defeat path pays nothing.
	if not _reports_defeat(node):
		awards_refused_not_defeated += 1
		_log("refused: the actor is not in the authoritative defeated state")
		return false

	_rewarded[id] = true
	award_credits(int(reward_per_enemy), String(actor.name))
	return true


## Restore the carried balance from SAVED state. This is the controlled restoration path a load uses
## (Milestone 10).
##
## It is deliberately NOT award_credits(). A load is not an enemy defeat, so this does NOT increment
## `awards`, does NOT emit `credits_awarded`, and does NOT mark any actor as paid. It sets the balance
## and reports the change through the SAME `credits_changed` signal every other balance change uses,
## with a delta of 0 because nothing was EARNED.
##
## `credits_earned` is set to the restored total because the restored balance IS this run's accumulated
## earnings as of the save point; leaving it at the pre-load value would make earned-vs-carried
## disagree. A negative value is refused outright rather than silently clamped, so a corrupt save is
## reported rather than absorbed. Returns whether the restore was accepted.
func restore_carried_credits(amount: int) -> bool:
	if amount < 0:
		_log("refused: cannot restore a negative carried balance (%d)" % amount)
		return false
	# A LOAD REPLACES THE RUN'S WORLD STATE, and a stake is run-local and is NOT saved. The one
	# already standing was created at some point the restored world may never have reached, so
	# leaving it in place would pay the player for a death the loaded world never saw - the
	# double-dip. Destroyed rather than kept, and reported through `stake_lost`.
	clear_stake()
	credits = amount
	credits_earned = amount
	loads += 1
	_log("restored carried balance %d (load #%d)" % [credits, loads])
	credits_changed.emit(credits, 0)
	return true


## Whether this run has ALREADY been paid for the actor behind `component`.
##
## Public so the save service can record reward history through the ledger's own API instead of
## reading `_rewarded`, which is private for the same reason every other owner's state is.
## Safe on anything, including null and a freed reference, so a caller that has not validated its
## input gets a plain false rather than raising.
func is_rewarded(component) -> bool:
	if component == null or not is_instance_valid(component) or not (component is Node):
		return false
	return _rewarded.has((component as Node).get_instance_id())


## Re-establish the run's REWARD HISTORY from a snapshot (Milestone 10 world-state restore).
##
## WHY THIS EXISTS - the defect it fixes. `_rewarded` remembers which actors this run has already
## paid, keyed by the defeat component's INSTANCE ID, which belongs to the LIVE process. A load
## restores a world the run recorded EARLIER in its own life, so an actor that was defeated after
## the save is brought back to life. Without this call the ledger STILL remembers paying that
## actor, and the result is a live, killable, TARGETABLE enemy that is permanently worth nothing:
## it dies, the defeat is processed, and no Credits are paid for the rest of the session. The world
## and the economy disagree, and nothing detects it.
##
## `already_paid` is the list of defeat authorities the snapshot records as PAID. Every one of them
## was paid when this run reached that state, so the restored run has already earned them. An actor
## the snapshot records as ALIVE is therefore not in this list and pays normally when it is killed
## again - which is exactly the contract the quicksave probe measures.
##
## It deliberately does NOT award Credits, does NOT touch the carried balance, does NOT emit
## `credits_awarded`, and does NOT inflate `awards`: a load is not a defeat. Connections in
## `_watched` are left ALONE - those are live signal wiring, not history, and clearing them would
## let `_watch_enemies()` double-connect every defeat authority in the tree.
func restore_reward_tracking(already_paid: Array) -> int:
	_rewarded.clear()
	var restored := 0
	for entry in already_paid:
		if entry == null or not is_instance_valid(entry) or not (entry is Node):
			continue
		_rewarded[(entry as Node).get_instance_id()] = true
		restored += 1
	_log("reward history restored from the snapshot: %d actor(s) already paid" % restored)
	return restored


## Restore the run to its documented initial carried balance and clear every counter. Used by the
## deterministic probe so a run never depends on state left behind by a previous one.
func reset_credits() -> void:
	credits = starting_credits
	credits_earned = 0
	awards = 0
	awards_refused_duplicate = 0
	awards_refused_non_mortal = 0
	awards_refused_not_defeated = 0
	awards_refused_player = 0
	awards_refused_invalid = 0
	loads = 0
	death_resets = 0
	# A NEW RUN has no history at all, so a stake left by the previous run must not survive into it.
	# Destroyed BEFORE the counters are zeroed, so the destruction is not counted against the fresh
	# run's own tally.
	clear_stake()
	stakes_placed = 0
	stakes_reclaimed = 0
	stakes_lost = 0
	_rewarded.clear()
	_log("reset to the starting balance %d" % credits)
	credits_changed.emit(credits, 0)


## The carried balance and this run's reward history go back to the start, because the PLAYER DIED
## (Milestone 18).
##
## THE RULE, which SUPERSEDES roadmap section 8L.7. That section recorded the opposite decision -
## "carried Credits SURVIVE the player's death and reset" - and the user has now overruled it: dying
## costs the run its carried Credits, as a Soulslike does. The primary defect this closes is that
## the balance survived a death at all. The SECOND, independent defect is the reward history:
## `DeathComponent._restore_arena_actors()` brings every enemy back ALIVE at full health, so without
## this call the arena refills with actors the ledger still remembers paying - killable, targetable
## and permanently worth ZERO. Clearing `_rewarded` is what makes a revived enemy worth Credits
## again, and it is the same guard `restore_reward_tracking()` exists for on a load.
##
## WHAT IS RESET: the carried balance, `credits_earned`, and the per-run reward history.
## WHAT IS DELIBERATELY NOT: `awards`, every refusal counter and `loads`. Those are LIFETIME
## counters describing what this process has observed rather than what the run carries, and clearing
## them would destroy the diagnostics that make this module checkable. `_watched` is left alone too:
## those are live signal connections, not history, and clearing them would let `_watch_enemies()`
## double-connect every defeat authority in the tree.
##
## Returns whether anything actually changed, so a caller can report what it did rather than
## assuming, and is safe to call at any time - including twice for one death.
func on_player_death() -> bool:
	if not reset_on_death:
		_log("refused: death reset is disabled by policy")
		return false
	var carried_before := credits
	var records_before := _rewarded.size()
	var changed := credits != starting_credits or credits_earned != 0 or records_before > 0

	# THE DEATH SPOT IS READ FIRST, while the player is still lying where it fell. The reset below
	# restores the body's position, and a position read afterwards would drop the stake wherever the
	# reset happened to put the player rather than where the run was actually lost.
	var drop_position := _player_position()

	# THE BALANCE IS SETTLED BEFORE THE DROP, and that order is load-bearing rather than tidy.
	# Placing a stake EMITS `stake_placed`, so any listener is invited to react while a death is
	# still half-applied. MEASURED on the first run of this pass: with the drop first, the stake's
	# own marker claimed it from inside that signal, and this function then OVERWROTE the reclaimed
	# balance - the Credits were destroyed AND no stake was left standing, which is the worst of both
	# outcomes and silent. Settling the balance first makes the death atomic from the outside: a
	# listener can only ever observe a finished death.
	credits = starting_credits
	credits_earned = 0
	_rewarded.clear()
	death_resets += 1

	# The drop is placed from the balance this death TOOK - captured above, before the reset - which
	# is what makes the stake worth walking back for.
	if drop_on_death:
		var dropped := maxi(0, carried_before - starting_credits)
		if place_stake(dropped, drop_position):
			changed = true

	_log("death reset: carried %d -> %d, earned cleared, %d reward record(s) cleared"
		% [carried_before, credits, records_before])
	# Reported through the SAME signal every other balance change uses, with the real (negative)
	# delta, so a display can show the loss without comparing balances. Deliberately NOT
	# `credits_awarded`: a death earns nothing.
	credits_changed.emit(credits, credits - carried_before)
	return changed


# --- The death-drop stake (Milestone 19) ---------------------------------------

## Drop `amount` Credits at `position` as a RETRIEVABLE stake, DESTROYING any stake already standing.
##
## Public because the death path is not its only conceivable caller - a scripted loss, a boss arena
## or a test may all legitimately want to drop a stake - and it is the ONE place a stake is created,
## so "where did this stake come from" has a single answer.
##
## THE ONE-STAKE RULE. This always begins by destroying whatever stake was already standing, and
## reports that through `stake_lost`. A run has exactly ONE stake, which is what makes a SECOND
## death before the first was claimed cost the first one: the new stake replaces the old, and there
## is nowhere left for the old Credits to have gone.
##
## `amount` of zero or less still DESTROYS the standing stake and creates nothing - dying with an
## empty pocket is exactly that case, and it must not leave the previous stake alive.
##
## Returns whether a new stake was created.
func place_stake(amount: int, position: Vector3) -> bool:
	clear_stake()
	if amount <= 0:
		_log("no stake placed: this death had nothing to drop")
		return false
	_has_stake = true
	_stake_amount = amount
	_stake_position = position
	stakes_placed += 1
	_log("dropped a stake of %d at %s" % [amount, str(position)])
	stake_placed.emit(amount, position)
	return true


## Take the standing stake's contents back into the carried balance. This is the ONLY way a stake
## pays out, and it is a transaction rather than a transfer: the stake is gone afterwards whether or
## not the balance was empty.
##
## It deliberately does NOT count as an award. Nothing was defeated, so `awards` is untouched and
## `credits_awarded` is not emitted - the same discipline `restore_carried_credits()` follows for a
## load. `credits_earned` IS restored, because the stake holds Credits this run earned and the death
## took away, so leaving it at zero would make the run's earned total disagree with its balance.
##
## Returns the amount reclaimed, or 0 when there was no stake.
func reclaim_stake() -> int:
	if not _has_stake:
		return 0
	var amount := _stake_amount
	_has_stake = false
	_stake_amount = 0
	_stake_position = Vector3.ZERO
	stakes_reclaimed += 1
	credits += amount
	credits_earned += amount
	_log("reclaimed a stake of %d -> carried %d" % [amount, credits])
	credits_changed.emit(credits, amount)
	stake_reclaimed.emit(amount)
	return amount


## Destroy the standing stake WITHOUT paying it out, and report what was destroyed. Idempotent and
## safe to call at any time, including when no stake is standing.
##
## Returns the amount destroyed, or 0 when there was nothing to destroy.
func clear_stake() -> int:
	if not _has_stake:
		return 0
	var amount := _stake_amount
	_has_stake = false
	_stake_amount = 0
	_stake_position = Vector3.ZERO
	stakes_lost += 1
	_log("stake of %d destroyed without being claimed" % amount)
	stake_lost.emit(amount)
	return amount


# --- Wiring -------------------------------------------------------------------

## Subscribe to every PLAYER death circuit in the tree that is not already subscribed.
##
## Scoped to the player on purpose. `DeathComponent.GROUP_DEATH` holds the player-controlled actor's
## own death circuit, while an enemy carries `EnemyDeathComponent` in a deliberately different group
## - so "an enemy was defeated" and "the player died" can never be wired to the same handler. The
## group is the enumeration source, so a player added later is picked up without editing this file.
func _watch_death_circuits() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(DeathComponent.GROUP_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var id := node.get_instance_id()
		if _watched_deaths.has(id):
			continue
		if not node.has_signal("death_started"):
			continue
		_watched_deaths[id] = true
		node.connect("death_started", _on_player_death_started)
		_log("watching player death circuit %s" % node.name)


## The production death handler. It decides nothing - it hands the death to on_player_death() so
## there is exactly ONE place that decides what a death costs.
func _on_player_death_started() -> void:
	on_player_death()


## Subscribe to every defeat authority in the tree that is not already subscribed. The GROUP is the
## enumeration source, so an enemy added later is picked up without editing this file.
func _watch_enemies() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(EnemyDeathComponent.GROUP_ENEMY_DEATH):
		if node == null or not is_instance_valid(node):
			continue
		var id := node.get_instance_id()
		if _watched.has(id):
			continue
		_watched[id] = true
		if node.has_signal("defeated"):
			node.connect("defeated", _on_enemy_defeated.bind(node))
			_log("watching defeat authority %s" % node.name)


## The production signal handler. It decides nothing - it hands the component to handle_defeat() so
## there is exactly ONE place that decides whether a defeat pays.
func _on_enemy_defeated(component: Node) -> void:
	handle_defeat(component)


# --- Internals ----------------------------------------------------------------

## Whether the defeat authority reports its actor as defeated. Duck-typed on purpose: any component
## answering is_defeated() works, exactly as EnemyAttacker and EnemyDeathComponent already do.
func _reports_defeat(component: Node) -> bool:
	if not component.has_method("is_defeated"):
		return false
	return bool(component.call("is_defeated"))


## Whether the defeat authority declares its actor mortal.
##
## A component that does not answer at all is treated as MORTAL, matching EnemyDeathComponent's own
## default, so an actor wired with a future defeat component that has no mortality concept keeps
## paying rather than silently stopping.
func _is_mortal(component: Node) -> bool:
	if not component.has_method("is_mortal"):
		return true
	return bool(component.call("is_mortal"))


## The player-controlled actor's world position, or the origin when there is no player.
##
## Read at the MOMENT OF A DEATH, while the player is still standing where it fell - the death
## circuit restores the body's position later in the same death, so a position read afterwards would
## place the stake wherever the reset happened to put the player rather than where it died.
func _player_position() -> Vector3:
	var tree := get_tree()
	if tree == null:
		return Vector3.ZERO
	var actor := tree.get_first_node_in_group(GROUP_PLAYER_ACTOR) as Node3D
	if actor == null:
		return Vector3.ZERO
	return actor.global_position


func _log(message: String) -> void:
	if debug_logging:
		print("[CREDITS] %s" % message)
