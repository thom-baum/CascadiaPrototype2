class_name EnemyAttackProbeDebug
extends Node3D
## Temporary Milestone 8 diagnostic (not production).
##
## Drives the single test attacker through scripted attacks and records, every
## physics frame, the attacker's phase, whether its damage window is open, whether
## the telegraph is showing, and the player's health. That makes each Milestone 8
## claim checkable from output rather than taken on trust:
##
##   AC1 wiring    - the attacker, its hitbox and its target all resolve, and the
##                   hitbox is on HITBOX masking HURTBOX only.
##   AC2 timeline  - WINDUP -> ACTIVE -> RECOVERY once each, in order, for the
##                   authored durations, returning to IDLE by itself.
##   AC3 window    - the damage window is open on ACTIVE frames and nowhere else.
##   AC4 telegraph - the tell shows during WINDUP and nowhere else.
##   AC5 damage    - an undefended player loses exactly `damage`, exactly once,
##                   on an ACTIVE frame.
##   AC6 parry     - with M7's parry window open the hit is refused and counted
##                   as a PARRY, and no health is lost.
##   AC7 i-frames  - with M6's dodge i-frames open the hit is refused and counted
##                   as an I-FRAME refusal, and no health is lost.
##   AC8 range     - an out-of-range target is refused and counted by cause; an
##                   in-range target is accepted.
##   AC9 auto      - with auto_attack enabled the attacker starts on its own.
##
## The hurtbox REFUSAL COUNTERS are the proof of overlap, not decoration:
## receive_hit() only runs when the enemy hitbox genuinely overlaps the player's
## hurtbox, so a refusal count that increments proves the hit was real AND
## refused. A dodge that simply carried the player clear of the volume could not
## increment it. That is why AC6/AC7 read the counter rather than just observing
## that health did not move.
##
## It calls try_start() directly instead of synthesising input, so what is under
## test is the attacker's own timing and the hurtbox's refusal points.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const SETTLE_FRAMES := 12
const MAX_ATTACK_FRAMES := 300
## How far a measured phase may differ from the authored duration.
const DURATION_TOLERANCE := 0.06
## How far in front of the attacker the player stands. The enemy AttackHitbox is
## offset -1.7 m along the body's facing and is 2.4 m deep, so it spans 0.5 m to
## 2.9 m in front: 1.8 m sits inside it with margin on both sides.
const ATTACK_DISTANCE := 1.8
## Comfortably outside engage_range (2.8 m).
const FAR_DISTANCE := 6.0
## Windup remaining at which the probe arms the player's parry. Parry startup is
## 0.08 s and its window 0.18 s, so arming at 0.12 s of remaining windup opens the
## window just before the enemy's ACTIVE and holds it past ACTIVE's close.
const PARRY_TRIGGER_LEAD := 0.12
## Windup remaining at which the probe arms the player's dodge. I-frames run
## 0.05-0.30 s into a 0.45 s dodge, so arming at 0.14 s covers the whole window.
const DODGE_TRIGGER_LEAD := 0.14
## Bounded frames allowed for auto_attack to start an attack by itself.
const AUTO_ATTACK_FRAMES := 240
## IDLE frames to let the attacker re-face the target after the player is moved.
## The attacker only turns toward its target while IDLE, so starting an attack in
## the SAME frame the player is teleported fires along the STALE facing: on the
## first scenario the player spawns behind the body (+Z), the body is therefore
## rotated to face +Z, and the hitbox then points there too and misses the player
## at attack distance on the -Z side. Letting a few IDLE frames pass exercises the
## production facing path instead of bypassing it. Without this, PLAIN measured
## 0 damage while the defended scenarios passed - the harness's bug, not the
## attacker's.
const FACE_SETTLE_FRAMES := 4

enum Step { PLAIN, PARRY, DODGE, RANGE, AUTO, DONE }

var _player: CharacterBody3D
var _player_health: HealthComponent
var _player_parry: ParryComponent
var _player_dodge: DodgeComponent
var _hurtbox: HurtboxComponent
var _body: Node3D
var _attacker: EnemyAttacker
var _hitbox: HitboxComponent
var _telegraph: Node3D

var _step: int = Step.PLAIN
var _frame := 0
var _recording := false
var _done := false

var _label := ""
var _defence := ""
var _records: Array = []
var _failures: Array = []
var _health_before := 0.0
var _started_before := 0
var _parry_before := 0
var _iframe_before := 0
var _leads := 0
var _armed := false
var _auto_frames := 0
## One compact per-scenario phase breakdown, printed again in the summary. A HITSTOP pauses a
## participant's per-frame callbacks, so a raw frame count measures the attack's authored timing PLUS
## whatever freeze landed on it. "How many frames were sampled and how many of them the actor was
## actually PROCESSING" therefore has to be readable from the transcript, and the console tail is
## truncated - hence the re-print.
var _phase_trace: Array[String] = []
## The freeze service's own state on every frame where it CHANGED, for the first scenario only.
## A frame count alone cannot distinguish "the freeze was too long" from "the actor was frozen for
## some other reason", and those are different findings.
var _trace: Array[String] = []
var _last_stop_frozen := false
## True between moving the player and actually starting the attack, so the attacker
## gets FACE_SETTLE_FRAMES IDLE frames to turn toward the new position first.
var _pending := false
var _settle := 0


func _ready() -> void:
	_resolve()
	if _attacker == null or _hitbox == null or _hurtbox == null:
		_finish()
		return
	# Deterministic: the probe drives every scripted attack itself. auto_attack is
	# re-enabled for AC9 only.
	_attacker.auto_attack = false
	_audit()


func _resolve() -> void:
	# This probe is a sibling of Main, so Main is reached through the parent.
	var main := get_node_or_null("../Main")
	if main == null:
		main = get_node_or_null("Main")
	if main == null:
		_fail("main scene not found")
		return
	var base := "TestEnvironment/"
	_player = main.get_node_or_null(base + "Player") as CharacterBody3D
	_player_health = main.get_node_or_null(base + "Player/Health") as HealthComponent
	_player_parry = main.get_node_or_null(base + "Player/Parry") as ParryComponent
	_player_dodge = main.get_node_or_null(base + "Player/Dodge") as DodgeComponent
	_hurtbox = main.get_node_or_null(base + "Player/Hurtbox") as HurtboxComponent
	_body = main.get_node_or_null(base + "TestAttacker") as Node3D
	_attacker = main.get_node_or_null(base + "TestAttacker/Attacker") as EnemyAttacker
	_hitbox = main.get_node_or_null(base + "TestAttacker/AttackHitbox") as HitboxComponent
	_telegraph = main.get_node_or_null(base + "TestAttacker/Telegraph") as Node3D

	_expect(_player != null, "player found")
	_expect(_player_health != null, "player Health found")
	_expect(_player_parry != null, "player Parry found (M7)")
	_expect(_player_dodge != null, "player Dodge found (M6)")
	_expect(_hurtbox != null, "player Hurtbox found")
	_expect(_body != null, "test attacker body found in the arena")
	_expect(_attacker != null, "EnemyAttacker component found")
	_expect(_hitbox != null, "enemy AttackHitbox is a HitboxComponent")
	_expect(_telegraph != null, "enemy Telegraph node found")


func _audit() -> void:
	print("[ENEMYPROBE] --- wiring audit ---")
	print("[ENEMYPROBE] attacker windup=%.2f active=%.2f recovery=%.2f damage=%.0f (total %.2fs)" % [
		_attacker.windup, _attacker.active, _attacker.recovery, _attacker.damage,
		_attacker.total_duration()])
	print("[ENEMYPROBE] engage_range=%.2f cooldown=%.2f face_target=%s" % [
		_attacker.engage_range, _attacker.attack_cooldown, str(_attacker.face_target)])
	print("[ENEMYPROBE] enemy hitbox layer=%d mask=%d (expect %d / %d)" % [
		_hitbox.collision_layer, _hitbox.collision_mask,
		GameLayers.HITBOX, GameLayers.HURTBOX])
	print("[ENEMYPROBE] player at %s, attacker at %s, resolved distance %.2f m" % [
		str(_player.global_position), str(_body.global_position), _attacker.distance_to_target()])
	print("[ENEMYPROBE] player groups: %s" % str(_player.get_groups()))

	_expect(_hitbox.collision_layer == GameLayers.HITBOX, "enemy hitbox on HITBOX layer")
	_expect(_hitbox.collision_mask == GameLayers.HURTBOX, "enemy hitbox masks HURTBOX only")
	_expect(_body.collision_layer == GameLayers.ACTOR, "attacker body on ACTOR layer")
	_expect(not String(_hitbox.source_actor_path).is_empty(),
		"enemy hitbox declares its source actor")
	# The one that proves the wiring: the attacker finds the player by group.
	_expect(_player.is_in_group(_attacker.target_group),
		"player answers to the attacker's target group '%s'" % str(_attacker.target_group))
	_expect(_attacker.distance_to_target() < INF,
		"attacker resolved a target (got %.2f m)" % _attacker.distance_to_target())


func _physics_process(_delta: float) -> void:
	if _done or _attacker == null:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	if _step == Step.AUTO:
		_tick_auto()
		return
	if _recording:
		# End BEFORE sampling. The completing frame reports IDLE, which is the
		# ABSENCE of an attack, not a fourth phase: sampling it appended a synthetic
		# IDLE to the phase-order sequence and failed an otherwise correct attack.
		if not _attacker.is_attacking():
			_end_recording()
			return
		_arm_if_needed()
		_sample()
		if _records.size() >= MAX_ATTACK_FRAMES:
			_fail("%s did not finish within %d frames" % [_label, MAX_ATTACK_FRAMES])
			_end_recording()
		return
	_drive()


func _drive() -> void:
	# Never begin a run while the previous run's defence is still committing.
	if _player_parry.is_parrying() or _player_dodge.is_dodging():
		return
	# Second half of a scenario. See FACE_SETTLE_FRAMES: the attacker only turns
	# toward its target while IDLE, so the attack must start a few frames AFTER the
	# player is moved, never in the same frame.
	if _pending:
		_settle += 1
		if _settle < FACE_SETTLE_FRAMES:
			return
		_pending = false
		_start_pending()
		return
	match _step:
		Step.PLAIN:
			_prepare("PLAIN", "NONE")
		Step.PARRY:
			_prepare("PARRY", "PARRY")
		Step.DODGE:
			_prepare("DODGE", "DODGE")
		Step.RANGE:
			_range_gate()
		_:
			_finish()


## First half of a scenario: reset both actors and place the player at attack
## distance. Deliberately does NOT start the attack - that happens after the settle
## frames, once the attacker has turned toward the new position.
func _prepare(label: String, defence: String) -> void:
	_label = label
	_defence = defence
	_records.clear()
	_armed = false
	_leads = 0
	_attacker.reset()
	_player_health.reset()
	_player.velocity = Vector3.ZERO
	_reposition(ATTACK_DISTANCE)
	_pending = true
	_settle = 0


## Second half: the attacker now faces the player, so start the scripted attack and
## begin recording. Baselines are captured here, immediately before the attack, so
## the settle frames cannot contaminate them.
func _start_pending() -> void:
	_started_before = _attacker.attacks_started
	_health_before = _player_health.current_health
	_parry_before = _hurtbox.refusals_by_parry
	_iframe_before = _hurtbox.refusals_by_iframes
	var accepted := _attacker.try_start()
	_expect(accepted, "%s: in-range attack accepted" % _label)
	_recording = true


func _reposition(distance: float) -> void:
	var a := _body.global_position
	_player.global_position = Vector3(a.x, 0.1, a.z - distance)
	_player.rotation.y = 0.0
	_player.velocity = Vector3.ZERO


## Arm the player's defence at the moment that puts its window over the enemy's
## ACTIVE phase, rather than at a fixed frame count. Driving it off the attacker's
## own remaining windup keeps the two timelines locked together even if a frame is
## dropped.
func _arm_if_needed() -> void:
	if _armed or _defence == "NONE":
		return
	if _attacker.phase_name() != "WINDUP":
		return
	var remaining := _attacker.phase_remaining()
	if _defence == "PARRY" and remaining <= PARRY_TRIGGER_LEAD:
		_armed = true
		if _player_parry.try_start():
			_leads += 1
	elif _defence == "DODGE" and remaining <= DODGE_TRIGGER_LEAD:
		_armed = true
		if _player_dodge.try_start(_perp_direction()):
			_leads += 1


func _perp_direction() -> Vector3:
	var to := _player.global_position - _body.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return Vector3.RIGHT
	return Vector3(-to.z, 0.0, to.x).normalized()


## Record the freeze service's transitions for the first scenario. Print-again-in-summary, because a
## reading that only exists mid-run can be truncated out of the transcript.
func _trace_freeze() -> void:
	if _step != Step.PLAIN:
		return
	var stop := HitStop.find_hit_stop(get_tree())
	if stop == null:
		return
	if stop.is_frozen() == _last_stop_frozen:
		return
	_last_stop_frozen = stop.is_frozen()
	_trace.append("PLAIN frame %d, phase %s: hitstop is_frozen -> %s (n=%d, remaining=%d ms, body_proc=%s)" % [
		_frame, _attacker.phase_name(), str(_last_stop_frozen), stop.frozen_count(),
		int(stop.remaining_seconds() * 1000.0), str(_body.is_physics_processing())])


func _sample() -> void:
	_trace_freeze()
	_records.append({
		"phase": _attacker.phase_name(),
		"open": _attacker.hitbox_is_open(),
		"tell": _telegraph.visible,
		"health": _player_health.current_health,
		# Whether the MEASURED enemy was FROZEN on this frame. Milestone 18's hitstop freezes the
		# two participants of a confirmed hit, and this probe instantiates `main.tscn`, so the
		# service is live in its tree. On a frame the enemy is frozen its phase does NOT advance,
		# yet this probe still samples it - so counting those frames as phase duration measures the
		# hitstop rather than the attack, and MEASURED on the PLAIN scenario (the one where the
		# enemy's hit actually lands on an undefended player) it inflated ACTIVE past tolerance.
		# The frames are recorded rather than dropped, so the correction is visible in the report.
		#
		# The gate is the SERVICE's own state, NOT `_body.is_physics_processing()`. MEASURED, and
		# it is why this line reads the way it does: that body reports its physics flag FALSE from
		# spawn until the FIRST release enables it, so on PLAIN - the only scenario in which a
		# freeze runs - all 35 windup frames read as "frozen" and the windup measured 0.000 s. The
		# freeze trace showed the real picture: the single freeze ran from frame 52 to frame 57,
		# about 75 ms, exactly the authored duration. Both participants are frozen by the service,
		# and this scenario's freeze includes the measured enemy, so its own state is the correct
		# question to ask.
		"frozen": _hitstop_is_frozen(),
	})


## Whether a hitstop is running right now, resolved through the service that owns the fact. By group,
## so no scene path is hard-coded, and safe in a tree that has no hitstop at all.
func _hitstop_is_frozen() -> bool:
	var stop := HitStop.find_hit_stop(get_tree())
	return stop != null and stop.is_frozen()


func _end_recording() -> void:
	_recording = false
	_evaluate()
	_step += 1


func _evaluate() -> void:
	var label := _label
	print("[ENEMYPROBE] --- %s: %d frames recorded ---" % [label, _records.size()])
	if _records.is_empty():
		_fail("%s recorded nothing" % label)
		return

	# AC3 + AC4: window and telegraph discipline.
	var open_outside := 0
	var closed_inside := 0
	var tell_outside := 0
	for r in _records:
		var is_active: bool = r["phase"] == "ACTIVE"
		if r["open"] and not is_active:
			open_outside += 1
		if is_active and not r["open"]:
			closed_inside += 1
		if r["tell"] and r["phase"] != "WINDUP":
			tell_outside += 1
	_expect(open_outside == 0,
		"%s: window never open outside ACTIVE (found %d)" % [label, open_outside])
	_expect(closed_inside == 0,
		"%s: window open on every ACTIVE frame (found %d closed)" % [label, closed_inside])
	_expect(tell_outside == 0,
		"%s: telegraph shows only during WINDUP (found %d outside)" % [label, tell_outside])

	# AC2: phase order, each exactly once.
	var seen: Array = []
	for r in _records:
		var p: String = r["phase"]
		if seen.is_empty() or seen[seen.size() - 1] != p:
			seen.append(p)
	print("[ENEMYPROBE] %s phase order: %s" % [label, str(seen)])
	_expect(seen == ["WINDUP", "ACTIVE", "RECOVERY"],
		"%s: phases run once each in order (got %s)" % [label, str(seen)])

	# FROZEN FRAMES ARE NOT PHASE DURATION. A frame on which the measured enemy did not process is
	# not a frame of its attack; counting it measures Milestone 18's hitstop instead. They are
	# counted separately and PRINTED, so the correction is visible rather than silent.
	var counts := {"WINDUP": 0, "ACTIVE": 0, "RECOVERY": 0}
	var frozen_frames := 0
	for r in _records:
		if bool(r.get("frozen", false)):
			frozen_frames += 1
			continue
		var p: String = r["phase"]
		if counts.has(p):
			counts[p] += 1
	if frozen_frames > 0:
		print("[ENEMYPROBE] %s: %d frame(s) excluded - the enemy was frozen by a hitstop, not running its attack"
			% [label, frozen_frames])
	# Per-phase totals, INCLUDING how many of those frames the actor was actually processing. A
	# HITSTOP pauses a participant's per-frame callbacks, so a raw frame count measures the attack's
	# authored timing PLUS whatever freeze landed on it - and a freeze that covers a whole phase makes
	# that phase read as 0.00 s.
	var total := {"WINDUP": 0, "ACTIVE": 0, "RECOVERY": 0}
	var frozen := {"WINDUP": 0, "ACTIVE": 0, "RECOVERY": 0}
	for r in _records:
		var tp: String = r["phase"]
		if not total.has(tp):
			continue
		total[tp] += 1
		if bool(r.get("frozen", false)):
			frozen[tp] += 1
	_phase_trace.append("%s: windup %d/%d frozen, active %d/%d, recovery %d/%d" % [
		label, frozen["WINDUP"], total["WINDUP"], frozen["ACTIVE"], total["ACTIVE"],
		frozen["RECOVERY"], total["RECOVERY"]])
	var fps := float(Engine.physics_ticks_per_second)
	print("[ENEMYPROBE] %s measured windup=%.2fs active=%.2fs recovery=%.2fs (authored %.2f/%.2f/%.2f)" % [
		label, counts["WINDUP"] / fps, counts["ACTIVE"] / fps, counts["RECOVERY"] / fps,
		_attacker.windup, _attacker.active, _attacker.recovery])
	# THE MEASURED VALUES ARE IN THE LABEL, so a failure reports its own numbers. The console is
	# truncated, and the mid-run print is early enough to be dropped from the transcript a reader
	# actually sees - which would leave a failure with no measurement attached to it.
	_expect(absf(counts["WINDUP"] / fps - _attacker.windup) <= DURATION_TOLERANCE,
		"%s: measured windup matches authored (%.3f s over %d frame(s), authored %.2f)"
		% [label, counts["WINDUP"] / fps, counts["WINDUP"], _attacker.windup])
	_expect(absf(counts["ACTIVE"] / fps - _attacker.active) <= DURATION_TOLERANCE,
		"%s: measured ACTIVE matches authored (%.3f s over %d frame(s), authored %.2f)"
		% [label, counts["ACTIVE"] / fps, counts["ACTIVE"], _attacker.active])
	_expect(absf(counts["RECOVERY"] / fps - _attacker.recovery) <= DURATION_TOLERANCE,
		"%s: measured recovery matches authored (%.3f s over %d frame(s), authored %.2f)"
		% [label, counts["RECOVERY"] / fps, counts["RECOVERY"], _attacker.recovery])

	# Damage accounting across the whole run.
	var changes := 0
	var change_phase := "-"
	var previous := _health_before
	for r in _records:
		var h: float = r["health"]
		if not is_equal_approx(h, previous):
			changes += 1
			change_phase = r["phase"]
			previous = h
	_expect(changes <= 1,
		"%s: at most one health change in the run (got %d)" % [label, changes])
	var lost := _health_before - _player_health.current_health

	if _defence == "NONE":
		# AC5
		_expect(is_equal_approx(lost, _attacker.damage),
			"%s: undefended player lost exactly %.0f (got %.1f)" % [label, _attacker.damage, lost])
		_expect(changes == 1,
			"%s: undefended damage applied exactly once (got %d)" % [label, changes])
		_expect(change_phase == "ACTIVE",
			"%s: undefended damage landed on an ACTIVE frame (got %s)" % [label, change_phase])
	else:
		# AC6 / AC7. No health lost AND the refusal was counted - the counter is
		# what proves the hitbox really overlapped the hurtbox and was refused.
		_expect(is_equal_approx(lost, 0.0),
			"%s: defended player lost no health (got %.1f lost)" % [label, lost])
		_expect(_leads == 1,
			"%s: the defence was armed exactly once (got %d)" % [label, _leads])
		if _defence == "PARRY":
			_expect(_hurtbox.refusals_by_parry > _parry_before,
				"%s: the hit was refused and counted as a PARRY (%d -> %d)" % [
					label, _parry_before, _hurtbox.refusals_by_parry])
		else:
			_expect(_hurtbox.refusals_by_iframes > _iframe_before,
				"%s: the hit was refused and counted as an I-FRAME refusal (%d -> %d)" % [
					label, _iframe_before, _hurtbox.refusals_by_iframes])

	_expect(_attacker.attacks_started == _started_before + 1,
		"%s: exactly one attack counted (got %d)" % [
			label, _attacker.attacks_started - _started_before])
	_expect(not _attacker.hitbox_is_open(), "%s: window closed at the end" % label)


## AC8 plus the hand-off into AC9.
func _range_gate() -> void:
	_attacker.reset()
	_reposition(FAR_DISTANCE)
	var refused_before := _attacker.attacks_refused_out_of_range
	var started_before := _attacker.attacks_started
	var accepted := _attacker.try_start()
	_expect(not accepted, "out-of-range attack is refused")
	_expect(_attacker.attacks_refused_out_of_range == refused_before + 1,
		"the out-of-range refusal was counted by cause")
	_expect(_attacker.attacks_started == started_before,
		"the refused out-of-range attack did not start")

	_player_health.reset()
	_attacker.reset()
	_reposition(ATTACK_DISTANCE)
	_auto_frames = 0
	_attacker.auto_attack = true
	print("[ENEMYPROBE] auto_attack re-enabled at %.2f m" % _attacker.distance_to_target())
	_step = Step.AUTO


## AC9: with nothing driving it, the attacker starts an attack on its own.
func _tick_auto() -> void:
	_auto_frames += 1
	if _attacker.is_attacking():
		_expect(true, "auto_attack started an attack on its own")
		_attacker.auto_attack = false
		_step = Step.DONE
		return
	if _auto_frames >= AUTO_ATTACK_FRAMES:
		_fail("auto_attack did not start an attack within %d frames" % AUTO_ATTACK_FRAMES)
		_attacker.auto_attack = false
		_step = Step.DONE


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("[ENEMYPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ENEMYPROBE]   FAIL  %s" % label)


func _finish() -> void:
	if _done:
		return
	_done = true
	if _attacker != null:
		_attacker.auto_attack = false
	print("[ENEMYPROBE] --- summary ---")
	print("[ENEMYPROBE] attacker damage=%.0f, player health=%.1f/%.1f, parry refusals=%d, i-frame refusals=%d" % [
		_attacker.damage if _attacker != null else -1.0,
		_player_health.current_health if _player_health != null else -1.0,
		_player_health.max_health if _player_health != null else -1.0,
		_hurtbox.refusals_by_parry if _hurtbox != null else -1,
		_hurtbox.refusals_by_iframes if _hurtbox != null else -1])
	# Re-printed here, and for the same reason the failure list is: the console tail is TRUNCATED, so
	# a reading printed only mid-run can be missing from the transcript a reader actually sees.
	for line in _phase_trace:
		print("[ENEMYPROBE] phase frames - %s" % line)
	for line in _trace:
		print("[ENEMYPROBE] freeze trace - %s" % line)
	var stop := HitStop.find_hit_stop(get_tree())
	if stop != null:
		print("[ENEMYPROBE] hitstop over the whole run: freezes=%d extensions=%d releases=%d frozen_now=%d"
			% [stop.freezes, stop.extensions, stop.releases, stop.frozen_count()])
	if _failures.is_empty():
		print("[ENEMYPROBE] RESULT: ALL CHECKS PASSED")
	else:
		print("[ENEMYPROBE] RESULT: %d FAILED -> %s" % [_failures.size(), str(_failures)])
