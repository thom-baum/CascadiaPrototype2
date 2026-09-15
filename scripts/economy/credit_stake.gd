class_name CreditStake
extends Area3D
## The world marker that holds a dead run's dropped Credits (Milestone 19).
##
## THE LOOP THIS COMPLETES. A Soulslike death takes your carried Credits and leaves them on the
## ground where you fell, so dying costs you a walk rather than the whole purse - and dying AGAIN
## before you get back is what makes them truly lost. Milestone 18 built the first half (death
## empties the carried balance) and left the retrieval half unbuilt: the Credits were destroyed
## outright, so there was no reason to go back for anything. This node is the second half.
##
## WHAT IT IS NOT. It is NOT an economy authority and it stores NO amount of its own. The ledger owns
## the stake's amount and position; this node is the marker that READS them and reports a body
## standing inside it. Nothing here decides what a stake is worth, whether one exists, or what a
## pick-up pays - all three belong to `CreditLedger`, which is the single owner of the answer.
##
## WHY IT READS RATHER THAN RECEIVES. The node re-syncs from the ledger every physics frame instead
## of trusting a one-shot signal. A signal-only marker would silently show a stake that no longer
## exists whenever a placement was missed (a node added after the drop, a ledger that resolved
## late), and a marker that disagrees with the economy is worse than no marker. The signals are used
## for the immediate case; the per-frame sync is what makes the display TRUE.
##
## WHY AN Area3D ON NO LAYER. Detection only: `collision_layer` is 0 so nothing in the world can see
## or collide with the stake, and `collision_mask` is the ACTOR layer so the player's body is the
## only thing that can be detected. An Area3D never applies physical collision, so walking over a
## stake can never nudge the player's movement - the same separation every combat volume in this
## project already keeps.
##
## Attach ONE of these to the world, as a sibling of the player rather than a child of it: the stake
## marks where the player DIED, so it must not follow the player around afterwards.

## Every stake marker joins this group, so a probe or a future UI can resolve it without a scene
## path - the same resolution pattern the ledger, the hitboxes and the actors already use.
const GROUP_STAKE := &"credit_stake"

@export_group("Wiring")
## The ledger this marker displays. Leave EMPTY to resolve the ledger through its group, which is
## how a marker added to a scene later picks up the existing economy without being rewired.
@export var ledger_path: NodePath

@export_group("Pick-up")
## How close the player's body must come, in metres, before the stake is claimed. Also the radius of
## the detection sphere, so the reach a player sees and the reach the game uses cannot drift apart.
@export var pickup_radius := 1.6

@export_group("Debug")
## Print each placement, claim and hide. Diagnostic.
@export var debug_logging := false

## Stakes this marker has shown since load.
var placements := 0
## Stakes this marker has watched the player claim.
var claims := 0

var _ledger: CreditLedger
## The stake amount this marker was last showing, so a per-frame sync only acts on a real change.
var _shown_amount := 0
var _was_armed := false
## Whether the player has been seen OUTSIDE the stake's volume since the current stake appeared.
## A claim requires it, so retrieving a stake is a WALK BACK rather than something that happens
## while the player is still standing where they fell. See `_player_inside()`.
var _departed := false


func _ready() -> void:
	add_to_group(GROUP_STAKE)
	# Detection only. Layer 0 means nothing can collide with or even see this volume; the mask is
	# what lets it notice the player's physical body.
	collision_layer = 0
	collision_mask = GameLayers.ACTOR
	# Monitoring is the mechanism, and it is deliberately not the gate: the gate is whether a stake
	# is standing. Detection runs continuously so a stake that appears around a player who is already
	# standing there is still claimed - the same reasoning the hitbox uses to keep monitoring on.
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	# LEAVING is what ARMS the stake. Driven by the physics detection itself rather than by a
	# per-frame sample, so it cannot depend on this node's own process callbacks running.
	body_exited.connect(_on_body_exited)
	_apply_radius()
	_ledger = _resolve_ledger()
	if _ledger != null:
		_ledger.stake_placed.connect(_on_stake_placed)
		# The ledger's OWN state changes drive the display, so hiding is immediate rather than
		# deferred to the next frame: a marker left on screen for a stake that no longer exists is
		# the stale-display defect this project has already paid for once.
		_ledger.stake_reclaimed.connect(_on_stake_settled)
		_ledger.stake_lost.connect(_on_stake_settled)
	_sync()


func _physics_process(_delta: float) -> void:
	# A ledger can be added after this marker, so it is re-resolved rather than assumed. Cheap, and
	# it keeps the wiring enumeration-driven instead of bound to load order.
	if _ledger == null:
		_ledger = _resolve_ledger()
		if _ledger != null and not _ledger.stake_placed.is_connected(_on_stake_placed):
			_ledger.stake_placed.connect(_on_stake_placed)
			_ledger.stake_reclaimed.connect(_on_stake_settled)
			_ledger.stake_lost.connect(_on_stake_settled)
	_sync()
	# The moment the player is seen outside a standing stake's volume, that stake becomes claimable.
	# Sampled every frame rather than driven only by `body_exited`, because the revive TELEPORTS the
	# body off the stake and a teleport is not guaranteed to produce an exit event.
	if _ledger != null and _ledger.has_stake() and not _departed and not _player_inside():
		_departed = true
		_log("the player left the stake - walking back onto it will now claim it")


# --- Queries -----------------------------------------------------------------

## Whether a stake is standing and this marker is displaying it.
func is_armed() -> bool:
	return _ledger != null and _ledger.has_stake()


## The amount being displayed, or 0 when no stake is standing.
func displayed_amount() -> int:
	if _ledger == null:
		return 0
	return _ledger.stake_amount()


## How far the player's body is from the stake, or -1 when either is missing. Used by probes to
## state a pick-up distance rather than imply one.
func distance_to_player() -> float:
	var tree := get_tree()
	if tree == null:
		return -1.0
	var actor := tree.get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	if actor == null:
		return -1.0
	return global_position.distance_to(actor.global_position)


## A diagnostic snapshot of the claim gate, so a probe can MEASURE why a claim did or did not happen
## instead of inferring it from the absence of a log line.
func claim_state() -> Dictionary:
	return {
		"departed": _departed,
		"player_inside": _player_inside(),
		"physics_process": is_physics_processing(),
		"distance": distance_to_player(),
	}


# --- Claiming ------------------------------------------------------------------

## The production pick-up path. A body entered the volume: if a stake is standing and the body is
## the player-controlled actor, the ledger is asked to pay it out.
func _on_body_entered(body: Node3D) -> void:
	_try_claim(body)


## The player left the volume. This is what ARMS the stake: a death drops it at the spot the player
## fell, so claiming must require that the player has been away and come back. Driven by the same
## physics detection `body_entered` uses, so it does not depend on this node's process callbacks.
func _on_body_exited(body: Node3D) -> void:
	if body == null or not body.is_in_group(CreditLedger.GROUP_PLAYER_ACTOR):
		return
	_departed = true
	_log("the player left the stake - walking back onto it will now claim it")


func _try_claim(body: Node3D) -> void:
	if _ledger == null or not _ledger.has_stake():
		return
	if body == null or not body.is_in_group(CreditLedger.GROUP_PLAYER_ACTOR):
		return
	# A CORPSE CANNOT PICK UP ITS OWN STAKE, and this gate is the whole reason the mechanic works.
	# A stake is dropped at the spot the player FELL, so at the instant it is created the player is
	# standing on it - and the sweep below would therefore reclaim it immediately, leaving the run
	# with nothing to go back for. Measured: before this gate the drop was claimed inside its own
	# creation signal. It is also the honest rule rather than a workaround: the stake exists to be
	# COME BACK for, so it is claimed by a LIVING actor or not at all.
	if _actor_is_dead(body):
		return
	# AND THE PLAYER MUST HAVE LEFT AND COME BACK. A death drops the stake at the spot the player
	# fell, and the revive restores the body BEFORE it clears `is_dead()` - MEASURED: the player
	# reports itself ALIVE for a few frames while still standing on the stake, so the corpse gate
	# above is not sufficient on its own. Requiring a departure is also the honest rule: the stake
	# exists to be walked back to, so a player who never left has retrieved nothing.
	if not _departed:
		_log("refused: the player has not left this stake since it appeared - a stake is claimed by walking back onto it")
		return
	# AND THE CLAIM IS GATED ON LIVE DISTANCE. MEASURED: `get_overlapping_bodies()` lags the live
	# transforms by one physics step, so on the frame the revive teleported the player off this
	# stake the overlap STILL reported them standing on it - and with liveness and departure both
	# already satisfied, the stake was claimed by a player who had already walked away from it,
	# paying out a retrieval that never happened. Distance comes from this frame's transforms.
	var actor := _player_actor()
	if actor == null or global_position.distance_to(actor.global_position) > pickup_radius:
		return
	# The ledger is the one place that decides what claiming does, so the amount, the balance and
	# the history are all its business and none of it is reimplemented here.
	var amount := _ledger.reclaim_stake()
	if amount > 0:
		claims += 1
		_log("claimed %d Credits" % amount)
	_sync()


## Offer the claim to a LIVING player who is ALREADY inside the volume. `body_entered` covers a
## player who walks in; this covers a stake that appears under a player who is already standing
## there, which happens whenever a death drops a stake at the spot the player fell - the body is
## restored onto that same spot by the reset, so the player is inside the volume the whole time.
##
## THE LIVENESS GATE IN `_try_claim` IS WHAT MAKES THIS SAFE. Without it this sweep would pay the
## player at the instant of death, because the corpse is standing exactly where the stake lands.
func _sweep() -> void:
	if _ledger == null or not _ledger.has_stake():
		return
	# DISTANCE ONLY, deliberately not `get_overlapping_bodies()`. That reading is one physics step
	# behind the transforms, which is exactly how the revive frame claimed a stake the player had
	# already left - see `_try_claim`. A body already inside the volume when the stake appears never
	# fires `body_entered`, so this check also covers that case, and a repeat call after a successful
	# claim is a no-op because `_try_claim` re-checks `has_stake()`.
	var actor := _player_actor()
	if actor == null:
		return
	if global_position.distance_to(actor.global_position) <= pickup_radius:
		_try_claim(actor)


# --- Display -------------------------------------------------------------------

## Bring the marker into agreement with the ledger: position, visibility and readout.
func _sync() -> void:
	if _ledger == null:
		visible = false
		_was_armed = false
		return
	var armed := _ledger.has_stake()
	var amount := _ledger.stake_amount()
	if armed:
		global_position = _ledger.stake_position()
	if armed and not _was_armed:
		placements += 1
		# A NEW stake begins UNCLAIMABLE while the player is standing on it, which is the normal
		# case: the death that dropped it put the body down exactly here.
		_departed = not _player_inside()
		_log("showing a stake of %d at %s (claimable=%s)"
			% [amount, str(global_position), str(_departed)])
	_was_armed = armed
	_shown_amount = amount
	# HIDDEN, not merely transparent: a visible Control or mesh that nobody should interact with is
	# exactly the class of defect this project has already paid for once (the pause panel).
	visible = armed
	if armed:
		_sweep()


func _on_stake_placed(_amount: int, position: Vector3) -> void:
	global_position = position
	_sync()


## The ledger settled a stake - paid out, replaced or destroyed - so the display follows it at once.
func _on_stake_settled(_amount: int) -> void:
	_sync()


## Size the detection sphere from `pickup_radius`, so the authored shape and the stated reach are the
## same number rather than two values that can drift.
func _apply_radius() -> void:
	var shape_node := get_node_or_null("Shape") as CollisionShape3D
	if shape_node == null:
		return
	var sphere := shape_node.shape as SphereShape3D
	if sphere == null:
		sphere = SphereShape3D.new()
		shape_node.shape = sphere
	sphere.radius = pickup_radius


# --- Resolution ------------------------------------------------------------------

## Whether this actor's OWN death circuit reports it dead.
##
## Duck-typed on `is_dead()` exactly the way `GameStateSave.get_player_death()` resolves the same
## circuit, so this stays independent of the death component's type. An actor with NO death circuit
## is simply alive as far as a stake is concerned, which preserves the pre-existing behaviour for
## anything that can never die.
func _actor_is_dead(actor: Node) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var death := actor.get_node_or_null("Death")
	if death == null or not death.has_method("is_dead"):
		return false
	return bool(death.call("is_dead"))


## Whether the player-controlled actor is within claiming reach of this stake RIGHT NOW.
##
## DISTANCE, and deliberately NOT `get_overlapping_bodies()`. MEASURED: the physics overlap reading
## lags the live transforms by one physics step, so on the frame the death reset teleported the
## revived player off the stake the overlap still reported them standing ON it - the stake was then
## claimed by a player who had already walked away from it, and the run was paid for a retrieval
## that never happened. Distance is computed from this frame's transforms and cannot go stale. Used
## to decide whether a freshly placed stake has been left yet; claiming is the ledger's business.
func _player_inside() -> bool:
	var actor := _player_actor()
	if actor == null:
		return false
	return global_position.distance_to(actor.global_position) <= pickup_radius


## The player-controlled actor, resolved through the same group every other consumer uses, or null
## when there is none.
func _player_actor() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D


func _resolve_ledger() -> CreditLedger:
	if not String(ledger_path).is_empty():
		var direct := get_node_or_null(ledger_path) as CreditLedger
		if direct != null:
			return direct
	var tree := get_tree()
	if tree == null:
		return null
	return CreditLedger.find_ledger(tree)


func _log(message: String) -> void:
	if debug_logging:
		print("[STAKE] %s: %s" % [name, message])
