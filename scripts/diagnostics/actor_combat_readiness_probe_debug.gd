class_name ActorCombatReadinessProbeDebug
extends Node3D
## Temporary diagnostic (not production): can an actor be used cleanly as a combat
## PARTICIPANT, and does a stale/dead/invalid target fail safely?
##
## Why this exists: the actor death pass proved actors can die. It did not prove that
## a dead actor stops being a legal TARGET. The audit found target resolution was bare
## group membership (`get_first_node_in_group`), so a corpse was still returned as a
## target and the attacker would turn its body to face it. This probe measures that
## specific behaviour, plus the participant query that now answers it.
##
## Deterministic by construction. Every blow goes through the existing
## `HurtboxComponent.receive_hit` -> `HealthComponent.apply_damage` chain, which is the
## single place all damage in Cascadia lands. Nothing here depends on attack timing.
##
## It measures STATE TRANSITIONS and REFUSAL CAUSES, not labels:
##
##   AC1  player          the player is a valid participant (alive, targetable, can act)
##   AC2  dummy           the DummyActor is a valid participant
##   AC3  attacker        the TestAttacker is a valid participant AND attack-capable
##   AC4  damage          a non-lethal hit still applies through the existing chain
##   AC5  targetability   a dead actor is refused AS A TARGET, by cause
##   AC6  corpse-facing   the attacker does not turn to face a dead target
##   AC7  dead-no-attack  a defeated actor starts no attack, refusal counted by cause
##   AC8  invalid         null / non-participant / freed targets fail safely
##   AC9  death-once      death processes exactly once; post-death damage is refused
##   AC10 presentation    the defeat presentation is still readable and says DEFEATED
##   AC11 policy-axis     not-targetable is distinct from dead and from non-damageable
##   AC12 fallback        an actor with NO participant is still a usable target
##   AC13 player-reset    the player's own death/reset circuit is unchanged
##   AC14 persistence     the player's reset does NOT revive a defeated actor
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 12
## Frames held while the target is dead, so an auto-attacking enemy has every chance
## to start an attack it should be refusing.
const HOLD_FRAMES := 40
## Frames allowed for the player's automatic reset. Generously longer than the
## player's authored `death_delay` (1.5 s at 60 Hz).
const RESET_WAIT_FRAMES := 300
## Damage used for a lethal blow - far above any actor's pool.
const LETHAL := 9999.0
## Damage used for the non-lethal hit that must still apply normally.
const CHIP := 30.0

var _frame := 0
var _done := false
var _stage := 0
var _wait := 0
var _failures: Array = []

# Resolved once, in _run().
var _player: Node3D
var _dummy: Node3D
var _attacker_body: Node3D
var _attacker: Node
var _policy_target: Node3D
## A static fixture, used to check the DECLARED unkillable archetype.
var _fixture_target: Node3D
var _dummy_death: Node
var _player_death: Node

# Angles remembered so the arena is left as it was found.
var _attacker_yaw := 0.0
var _player_position := Vector3.ZERO


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	match _stage:
		0:
			if _frame < SETTLE_FRAMES:
				return
			_stand_down_ambient_attackers()
			_run_static_checks()
			_begin_live_target_window()
		1:
			_tick_live_target_window()
		2:
			_tick_wait_for_player_reset()
		3:
			_tick_defeated_attacker_window()


## Stop every attacker in the tree from starting an attack on its own. The arena's
## ambient attacker would otherwise swing at the player during the waits below.
func _stand_down_ambient_attackers() -> void:
	EnemyAttacker.stand_down_all(get_tree())


func _run_static_checks() -> void:
	print("[ACTRD] --- reusable actor combat readiness audit (measured) ---")
	_resolve_actors()
	if _player == null or _dummy == null or _attacker == null:
		_fail("could not resolve the player, the DummyActor and/or the TestAttacker")
		_done = true
		_report()
		return

	_dummy_death = _dummy.get_node_or_null("Death")
	_player_death = _player.get_node_or_null("Death")
	print("[ACTRD] resolved: player=%s dummy=%s attacker=%s" % [
		_name_of(_player), _name_of(_dummy), _name_of(_attacker_body)])

	_check_participants()
	_check_damage_still_applies()
	_check_death_once()
	_check_presentation()
	_check_invalid_targets()
	_check_policy_axis()
	_check_unwired_fallback()
	_check_unkillable_archetype()


# --- AC1/AC2/AC3: the three actors are valid participants ----------------------

func _check_participants() -> void:
	_check_one_participant(_player, "player", true)
	_check_one_participant(_dummy, "DummyActor", false)
	_check_one_participant(_attacker_body, "TestAttacker", true)


func _check_one_participant(actor: Node3D, label: String, expect_attack_capable: bool) -> void:
	var participant := CombatParticipant.find_for(actor)
	if participant == null:
		_fail("%s has no CombatParticipant" % label)
		return
	print("[ACTRD] %s: wired=%s %s" % [
		label, str(participant.is_wired()), participant.state_summary()])
	_expect(participant.is_wired(), "%s: participant is wired to its components" % label)
	_expect(participant.is_alive(), "%s: reports alive" % label)
	_expect(not participant.is_dead(), "%s: does not report dead" % label)
	_expect(participant.is_damageable(), "%s: reports damageable" % label)
	_expect(participant.is_mortal(), "%s: reports mortal" % label)
	_expect(participant.is_valid_target(), "%s: is a valid target" % label)
	_expect(participant.can_act(), "%s: can act" % label)
	_expect(participant.is_attack_capable() == expect_attack_capable,
		"%s: attack-capable=%s (expected %s)" % [
			label, str(participant.is_attack_capable()), str(expect_attack_capable)])


# --- AC4: ordinary damage still lands through the existing chain ---------------

func _check_damage_still_applies() -> void:
	var health := _health_of(_dummy)
	if health == null:
		_fail("DummyActor has no HealthComponent")
		return
	var before := health.current_health
	var applied := _apply_damage(_dummy, CHIP)
	print("[ACTRD] chip damage: applied=%s  %.1f -> %.1f" % [
		str(applied), before, health.current_health])
	_expect(applied, "damage still applies to a damageable actor through the existing chain")
	_expect(is_equal_approx(health.current_health, before - CHIP),
		"damage removed exactly the amount applied (%.1f)" % CHIP)


# --- AC9: death is processed exactly once --------------------------------------

func _check_death_once() -> void:
	var health := _health_of(_dummy)
	var first := _apply_damage(_dummy, LETHAL)
	var defeated := _is_defeated(_dummy_death)
	var defeats := int(_dummy_death.get("defeats")) if _dummy_death != null else -1
	var second := _apply_damage(_dummy, LETHAL)
	var defeats_after := int(_dummy_death.get("defeats")) if _dummy_death != null else -1

	print("[ACTRD] lethal then lethal: first=%s  health=%.1f  is_dead=%s  defeated=%s  defeats %d -> %d  second=%s" % [
		str(first), health.current_health, str(health.is_dead), str(defeated),
		defeats, defeats_after, str(second)])

	_expect(first and health.is_dead and is_zero_approx(health.current_health),
		"the lethal hit reached zero health and marked the actor dead")
	_expect(defeated and defeats == 1,
		"the defeat was processed exactly once (defeats=1)")
	_expect(not second and defeats_after == 1,
		"post-death damage was refused and produced no second defeat")


# --- AC10: the defeat presentation is still readable ---------------------------

func _check_presentation() -> void:
	var presentation := _dummy.get_node_or_null("DeathPresentation")
	if presentation == null:
		_fail("DummyActor has no defeat presentation to read")
		return
	var showing := bool(presentation.call("is_showing"))
	var text := String(presentation.call("status_text"))
	print("[ACTRD] presentation: showing=%s text=\"%s\"" % [str(showing), text])
	_expect(showing, "the defeat presentation is showing after the defeat")
	_expect(text == "DEFEATED", "the defeat presentation still reads DEFEATED")


# --- AC5/AC6: a dead actor is not a target, and is not faced -------------------

func _begin_live_target_window() -> void:
	# Put the player inside the attacker's reach, so any refusal below is attributable
	# to the target being DEAD rather than to it being out of range.
	_player_position = _player.global_position
	# Placed off to the attacker's +X side, NOT straight ahead. Straight ahead would put
	# the corpse-facing bearing at exactly PI, which is the yaw set below - the check
	# would then pass whether or not the gate works. Off-axis, a turn to face the corpse
	# moves the yaw by about 4.7 rad and cannot be mistaken for the starting angle.
	_player.global_position = _attacker_body.global_position + Vector3(1.5, 0.1, 0.0)
	_player.velocity = Vector3.ZERO

	# Facing directly away from the corpse. Kept only if the gate refuses the dead
	# target, which is exactly what makes "it did not turn" observable.
	_attacker_body.rotation.y = PI
	_attacker_yaw = PI

	var health := _health_of(_player)
	_apply_damage(_player, LETHAL)
	print("[ACTRD] player killed for the target window: health=%.1f is_dead=%s" % [
		health.current_health if health != null else -1.0,
		str(health.is_dead) if health != null else "n/a"])

	# With auto_attack ON, an attack is what a VALID target would produce. Any attack
	# that starts now would be the defect; a refusal is the system working.
	_attacker.set("auto_attack", true)
	_attacks_before = int(_attacker.get("attacks_started"))
	_dead_refusals_before = int(_attacker.get("target_refusals_dead"))
	_range_refusals_before = int(_attacker.get("attacks_refused_out_of_range"))
	_stage = 1
	_wait = 0


var _attacks_before := 0
var _dead_refusals_before := 0
var _range_refusals_before := 0
var _yaw_drift := 0.0


func _tick_live_target_window() -> void:
	_wait += 1
	_yaw_drift = maxf(_yaw_drift, absf(_attacker_body.rotation.y - _attacker_yaw))
	if _wait < HOLD_FRAMES:
		return

	var participant := CombatParticipant.find_for(_player)
	var refusal := CombatParticipant.target_refusal(_player)
	var attacks_now := int(_attacker.get("attacks_started"))
	var dead_now := int(_attacker.get("target_refusals_dead"))
	var range_now := int(_attacker.get("attacks_refused_out_of_range"))

	print("[ACTRD] dead target held %d frames: refusal=%s  attacks %d -> %d  dead_refusals %d -> %d  range_refusals %d -> %d  max_yaw_drift=%.4f" % [
		HOLD_FRAMES, CombatParticipant.refusal_name(refusal),
		_attacks_before, attacks_now, _dead_refusals_before, dead_now,
		_range_refusals_before, range_now, _yaw_drift])
	if participant != null:
		print("[ACTRD] dead player participant: %s" % participant.state_summary())

	# AC5: the dead actor is refused AS A TARGET, and the refusal is filed under the
	# DEAD cause rather than being lumped in with a distance refusal.
	_expect(refusal == CombatParticipant.Refusal.DEAD,
		"the dead actor is refused as a target with the DEAD cause")
	_expect(not CombatParticipant.is_usable_target(_player),
		"a dead actor is not a usable combat target")
	# AC6: no corpse-facing. Without the valid-target gate the body would swing round to
	# the corpse's bearing (about -PI/2 from here) within a frame.
	_expect(_yaw_drift < 0.01,
		"the attacker did not turn to face the dead target (max drift %.4f rad)" % _yaw_drift)
	# A refusal for the DEAD reason, not a distance one: the target is in range.
	_expect(range_now == _range_refusals_before,
		"the refusal was NOT recorded as an out-of-range refusal")
	_expect(attacks_now == _attacks_before,
		"a dead target produced no attack")

	# The by-cause counting is driven through try_start(), the ONE entry point an attack
	# can start from, rather than left to the cadence. The hold above proves the live
	# loop starts nothing; this proves the refusal is COUNTED and filed under the right
	# cause, which a cadence check cannot do deterministically - the attacker may still
	# be in its own cooldown when the window closes.
	var started := bool(_attacker.call("try_start"))
	var dead_after := int(_attacker.get("target_refusals_dead"))
	var range_after := int(_attacker.get("attacks_refused_out_of_range"))
	print("[ACTRD] dead target via try_start: started=%s  target_refusals_dead %d -> %d  out_of_range %d -> %d" % [
		str(started), _dead_refusals_before, dead_after, _range_refusals_before, range_after])
	_expect(not started, "an attack on a dead target is refused at the only entry point")
	_expect(dead_after > _dead_refusals_before,
		"the attacker counted the refusal by cause (target_refusals_dead increased)")
	_expect(range_after == _range_refusals_before,
		"the dead-target refusal was not filed as an out-of-range refusal")
	_expect(int(_attacker.get("attacks_started")) == _attacks_before,
		"the refused attempt started no attack")

	_attacker.set("auto_attack", false)
	_stage = 2
	_wait = 0


# --- AC13/AC14: the player's reset, and what it must NOT restore ---------------

func _tick_wait_for_player_reset() -> void:
	if _player_death == null:
		_done = true
		_report()
		return
	_wait += 1
	var dead := bool(_player_death.call("is_dead"))
	if dead and _wait < RESET_WAIT_FRAMES:
		return

	var health := _health_of(_player)
	var resets := int(_player_death.get("resets"))
	var dummy_defeated := _is_defeated(_dummy_death)
	var dummy_health := _health_of(_dummy)

	print("[ACTRD] after %.2f s: player_dead=%s  player_health=%.1f  resets=%d" % [
		float(_wait) / 60.0, str(dead), health.current_health if health != null else -1.0, resets])
	print("[ACTRD] after reset: dummy defeated=%s  health=%.1f" % [
		str(dummy_defeated), dummy_health.current_health if dummy_health != null else -1.0])

	_expect(not dead and resets >= 1, "the player's automatic reset ran and the player is alive")
	_expect(health != null and not health.is_dead and health.current_health > 0.0,
		"the player's health was restored by the reset")
	# AC14: the reset must not revive what is not the player.
	_expect(dummy_defeated and dummy_health != null and dummy_health.is_dead,
		"the player's reset did NOT revive the defeated actor")

	# A revived actor must become targetable again - the refusal is a state, not a ban.
	_player.global_position = _attacker_body.global_position + Vector3(0.0, 0.1, 1.5)
	var refusal_after := CombatParticipant.target_refusal(_player)
	var in_range := bool(_attacker.call("is_target_in_range"))
	print("[ACTRD] revived player: refusal=%s  attacker_in_range=%s" % [
		CombatParticipant.refusal_name(refusal_after), str(in_range)])
	_expect(refusal_after == CombatParticipant.Refusal.NONE,
		"a revived actor is a usable target again (the refusal was a state, not a ban)")
	_expect(in_range, "the attacker resolves the revived player as a target in range")

	# AC7: kill the attacker and prove a defeated actor cannot act.
	_apply_damage(_attacker_body, LETHAL)
	_attacker.set("auto_attack", true)
	_attacks_before = int(_attacker.get("attacks_started"))
	_defeat_refusals_before = int(_attacker.get("attacks_refused_while_defeated"))
	print("[ACTRD] attacker killed: participant=%s  auto_attack re-enabled" % [
		_state_of(_attacker_body)])
	_stage = 3
	_wait = 0


var _defeat_refusals_before := 0


func _tick_defeated_attacker_window() -> void:
	_wait += 1
	if _wait < HOLD_FRAMES:
		return

	var attacks_now := int(_attacker.get("attacks_started"))
	var refusals_now := int(_attacker.get("attacks_refused_while_defeated"))
	var participant := CombatParticipant.find_for(_attacker_body)

	print("[ACTRD] defeated attacker held %d frames: attacks %d -> %d  defeat_refusals %d -> %d" % [
		HOLD_FRAMES, _attacks_before, attacks_now, _defeat_refusals_before, refusals_now])
	if participant != null:
		print("[ACTRD] defeated attacker participant: %s  can_act=%s  valid_target=%s" % [
			participant.state_summary(), str(participant.can_act()),
			str(participant.is_valid_target())])

	_expect(attacks_now == _attacks_before,
		"a defeated actor started no attack while standing in range of a live target")
	# Driven through try_start() for the same reason as the dead-target case: a defeated
	# attacker's own _physics_process returns before it can reach any refusal path, so
	# waiting on the cadence here would measure the early return rather than the refusal.
	# This asks the production entry point directly and checks the cause it files.
	var started := bool(_attacker.call("try_start"))
	var refusals_after := int(_attacker.get("attacks_refused_while_defeated"))
	print("[ACTRD] defeated attacker via try_start: started=%s  defeat_refusals %d -> %d" % [
		str(started), _defeat_refusals_before, refusals_after])
	_expect(not started, "a defeated actor refuses to start an attack at the only entry point")
	_expect(refusals_after > _defeat_refusals_before,
		"the defeated actor's refusal to act was counted by cause")
	_expect(participant != null and not participant.can_act(),
		"a defeated actor reports that it cannot act")
	_expect(participant != null and not participant.is_valid_target(),
		"a defeated actor is not a valid target")

	_attacker.set("auto_attack", false)
	_restore_arena()
	_done = true
	_report()


## Leave the arena as it was found: the attacker's facing and the player's position
## were moved only so this probe could measure something specific.
func _restore_arena() -> void:
	_attacker_body.rotation.y = 0.0
	_player.global_position = _player_position


# --- AC8: invalid targets fail safely ------------------------------------------

func _check_invalid_targets() -> void:
	_expect(CombatParticipant.target_refusal(null) == CombatParticipant.Refusal.MISSING,
		"a null target is refused as MISSING")
	_expect(not CombatParticipant.is_usable_target(null),
		"a null target is not usable")
	_expect(CombatParticipant.find_for(null) == null,
		"looking up a participant for null returns null")

	# A real node that is not a combat actor at all.
	var plain := Node3D.new()
	plain.name = "NotACandidate"
	add_child(plain)
	var refusal := CombatParticipant.target_refusal(plain)
	print("[ACTRD] non-participant node: refusal=%s" % CombatParticipant.refusal_name(refusal))
	_expect(refusal == CombatParticipant.Refusal.NOT_PARTICIPANT,
		"a node with no health is refused as NOT_PARTICIPANT")
	remove_child(plain)

	# A freed node: the classic stale reference. Must not raise, must not be usable.
	var doomed := Node3D.new()
	doomed.name = "FreedCandidate"
	add_child(doomed)
	doomed.free()
	var freed_refusal := CombatParticipant.target_refusal(doomed)
	print("[ACTRD] freed node: refusal=%s" % CombatParticipant.refusal_name(freed_refusal))
	_expect(freed_refusal == CombatParticipant.Refusal.MISSING,
		"a freed target is refused as MISSING without raising")


# --- AC11: the targetability policy is its own axis ----------------------------

func _check_policy_axis() -> void:
	if _policy_target == null:
		_fail("no static target available to test the targetability policy")
		return
	var health := _health_of(_policy_target)
	if health == null:
		_fail("policy target has no HealthComponent")
		return

	# The actor's OWN participant has its targetability policy flipped, so the axis is
	# proved against the SAME query a consumer would call and against the same
	# component the actor really uses, then restored.
	var participant := CombatParticipant.find_for(_policy_target)
	if participant == null:
		_fail("policy target has no participant to flip")
		return
	participant.can_be_targeted = false

	var refusal := CombatParticipant.target_refusal(_policy_target)
	print("[ACTRD] not-targetable policy: refusal=%s  alive=%s  damageable=%s  state=\"%s\"" % [
		CombatParticipant.refusal_name(refusal), str(participant.is_alive()),
		str(participant.is_damageable()), participant.state_summary()])

	_expect(refusal == CombatParticipant.Refusal.NOT_TARGETABLE,
		"an alive actor can be refused AS A TARGET by policy alone")
	_expect(participant.is_alive() and not participant.is_dead(),
		"the not-targetable actor is still ALIVE - targetability is not health")
	_expect(participant.is_damageable(),
		"the not-targetable actor is still DAMAGEABLE - targetability is not damageability")
	_expect(not participant.can_be_targeted and not participant.is_valid_target(),
		"the actor reports itself as not targetable")

	participant.can_be_targeted = true


# --- AC12: an actor with no participant keeps working ---------------------------

## An actor with NO participant must keep the pre-8K health-based behaviour instead of
## being silently refused. Built at runtime on purpose: every actor in the arena now
## declares its archetype, so scenery is no longer a component-less actor, and the
## fallback is a property of the QUERY rather than of any one scene.
func _check_unwired_fallback() -> void:
	var holder := Node3D.new()
	holder.name = "UnwiredCandidate"
	var health := HealthComponent.new()
	health.name = "Health"
	holder.add_child(health)
	add_child(holder)

	var participant := CombatParticipant.find_for(holder)
	var refusal := CombatParticipant.target_refusal(holder)
	print("[ACTRD] unwired actor: has_participant=%s  refusal=%s" % [
		str(participant != null), CombatParticipant.refusal_name(refusal)])
	_expect(participant == null, "the unwired actor genuinely has no participant")
	_expect(refusal == CombatParticipant.Refusal.NONE,
		"an actor with no participant is still a usable target (no silent refusal)")

	_apply_damage(holder, LETHAL)
	var refusal_dead := CombatParticipant.target_refusal(holder)
	print("[ACTRD] unwired actor at zero health: refusal=%s  health=%.1f" % [
		CombatParticipant.refusal_name(refusal_dead), health.current_health])
	_expect(refusal_dead == CombatParticipant.Refusal.DEAD,
		"an unwired actor that reaches zero health is still refused as DEAD")

	remove_child(holder)
	holder.queue_free()


# --- AC15: the unkillable archetype is DECLARED, not accidental -----------------

## The static fixtures are unkillable ON PURPOSE, and until this pass that was true
## only by OMISSION: they carried no defeat component, so nothing processed a death,
## and a participant would have reported mortal=true for an actor with no death path
## at all - which is exactly the ambiguous state reported by the user. They now declare
## it, and this measures the declaration rather than the absence.
func _check_unkillable_archetype() -> void:
	# Built AT RUNTIME on purpose. Every actor in the arena is now a mortal enemy (or
	# the player), because an actor that was "unkillable" only because nobody had
	# wired a death path was NOT an archetype - it was a hole. This proves the other
	# archetype still exists and behaves as declared: damageable, explicitly
	# non-mortal, and therefore never entering the mortal defeat path.
	var holder := Node3D.new()
	holder.name = "UnkillableCandidate"
	var health := HealthComponent.new()
	health.name = "Health"
	holder.add_child(health)
	var death := EnemyDeathComponent.new()
	death.name = "Death"
	death.mortal = false
	death.health_path = NodePath("../Health")
	holder.add_child(death)
	var participant := CombatParticipant.new()
	participant.name = "Participant"
	holder.add_child(participant)
	add_child(holder)

	print("[ACTRD] unkillable actor before: %s" % participant.state_summary())
	_apply_damage(holder, LETHAL)

	var defeated := _is_defeated(death)
	var defeats := int(death.get("defeats"))
	var refusals := int(death.get("lethal_refusals"))
	var refusal_now := CombatParticipant.target_refusal(holder)
	var summary := participant.state_summary()

	print("[ACTRD] unkillable actor at zero health: health=%.1f is_dead=%s mortal=%s is_defeated=%s defeats=%d lethal_refusals=%d refusal=%s state=\"%s\"" % [
		health.current_health, str(health.is_dead), str(participant.is_mortal()), str(defeated),
		defeats, refusals, CombatParticipant.refusal_name(refusal_now), summary])

	_expect(not participant.is_mortal(),
		"an UNKILLABLE actor DECLARES itself non-mortal instead of being unkillable by omission")
	_expect(health.is_dead and is_zero_approx(health.current_health),
		"the unkillable actor still takes damage and still reaches zero health")
	_expect(not defeated and defeats == 0,
		"the unkillable actor NEVER enters the mortal defeat path (is_defeated=false, defeats=0)")
	_expect(refusals >= 1,
		"its lethal hit is recorded by cause (lethal_refusals) rather than passing silently")
	_expect(refusal_now == CombatParticipant.Refusal.DEAD,
		"at zero health it is refused as a target for being DEPLETED, not as a defeated enemy")
	_expect(summary.begins_with("depleted"),
		"it reports as DEPLETED, not as a dead enemy (got \"%s\")" % summary)
	_expect(not participant.can_act(), "a depleted actor cannot act")

	remove_child(holder)
	holder.queue_free()


# --- Damage -------------------------------------------------------------------

func _lethal_event(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = amount
	event.source = null
	return event


## One hit through the existing receiving volume, which is the same route a real attack
## takes. Falls back to the health component only when the actor has no hurtbox at all.
func _apply_damage(actor: Node3D, amount: float) -> bool:
	if actor == null:
		return false
	var hurtbox := _hurtbox_of(actor)
	if hurtbox != null:
		return hurtbox.receive_hit(_lethal_event(amount))
	var health := _health_of(actor)
	if health != null:
		return health.apply_damage(_lethal_event(amount))
	return false


# --- Resolution ---------------------------------------------------------------

func _resolve_actors() -> void:
	_player = get_tree().get_first_node_in_group("player_actor") as Node3D
	if _player == null:
		_player = _actor_named("Player")
	_dummy = _actor_named("DummyActor")
	_attacker_body = _actor_named("TestAttacker")
	if _attacker_body != null:
		_attacker = _attacker_body.get_node_or_null("Attacker")

	# Sorted so the choice is deterministic instead of depending on group order.
	var statics := _static_targets()
	if statics.size() >= 1:
		_policy_target = statics[0]
	if statics.size() >= 2:
		_fixture_target = statics[1]


func _actor_named(actor_name: String) -> Node3D:
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var body := health.get_parent() as Node3D
		if body != null and String(body.name) == actor_name:
			return body
	return null


## Static (non-grounding) damageable actors, sorted by name.
func _static_targets() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var body := health.get_parent()
		if body is StaticBody3D:
			out.append(body)
	out.sort_custom(func(a: Node, b: Node) -> bool:
		return String(a.name) < String(b.name))
	return out


func _health_of(actor: Node) -> HealthComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null


func _hurtbox_of(actor: Node) -> HurtboxComponent:
	if actor == null:
		return null
	for child in actor.get_children():
		if child is HurtboxComponent:
			return child as HurtboxComponent
	return null


func _is_defeated(death: Node) -> bool:
	if death == null or not death.has_method("is_defeated"):
		return false
	return bool(death.call("is_defeated"))


func _name_of(actor: Node) -> String:
	return String(actor.name) if actor != null else "none"


func _state_of(actor: Node3D) -> String:
	var participant := CombatParticipant.find_for(actor)
	if participant == null:
		return "no participant"
	return participant.state_summary()


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[ACTRD]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ACTRD]   FAIL  %s" % label)


func _report() -> void:
	print("[ACTRD] --- summary ---")
	if _failures.is_empty():
		print("[ACTRD] RESULT: ALL CHECKS PASSED")
	else:
		print("[ACTRD] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
