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

## Instance ids of enemies already paid, so ONE enemy can never pay twice - however many times a
## signal fires, a frame repeats, or a check is re-run.
var _rewarded: Dictionary = {}
## Instance ids of defeat components already subscribed to, so re-scanning never double-connects.
var _watched: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP_LEDGER)
	# The carried balance belongs to the RUN, so it starts at the documented initial value here
	# rather than being left at whatever the editor last showed.
	credits = starting_credits
	_watch_enemies()


func _physics_process(_delta: float) -> void:
	# Enemies can be added at runtime, so the population is re-scanned. Cheap at this scale, and it
	# is what makes the reward path enumeration-driven rather than wired to a fixed actor list.
	_watch_enemies()


# --- Queries -----------------------------------------------------------------

## The current CARRIED balance.
func get_credits() -> int:
	return credits


## How many distinct enemies have been paid since the last reset.
func rewarded_count() -> int:
	return _rewarded.size()


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
	_rewarded.clear()
	_log("reset to the starting balance %d" % credits)
	credits_changed.emit(credits, 0)


# --- Wiring -------------------------------------------------------------------

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


func _log(message: String) -> void:
	if debug_logging:
		print("[CREDITS] %s" % message)
