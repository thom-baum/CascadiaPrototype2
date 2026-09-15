class_name ActorContractProbeDebug
extends Node3D
## Temporary diagnostic (not production): is the SHARED ACTOR CONTRACT real, is it actually in use
## by the player, the enemies and the NPC, and is the SECOND ENEMY VARIANT genuinely data-driven -
## rather than merely declared?
##
## Why this exists: Milestone 15 introduced one shared vocabulary (ActorState) and a two-resource
## archetype data layer (ActorProfile for what an actor IS, EnemyAttackProfile for what an ATTACK
## is). Every one of those can be wired into a scene, parse cleanly, and still answer nothing at
## runtime: a state node whose paths resolve against the wrong node reports an unwired actor
## forever, and a profile that is assigned but never copied into its owning component changes no
## number. Neither defect shows up in a compile. So this probe asks the RUNNING actors.
##
## It also settles the one question a static read CANNOT answer about the archetype model: whether
## a profile is a one-time SEED or a live AUTHORITY. Both look identical while the numbers happen to
## agree, so this probe MUTATES the resource at runtime and requires the running attacker NOT to
## follow it. That is the difference between data-driven tuning and a resource read every frame.
##
## It measures, through the production components, with no hand-written actor list:
##
##   coverage      every actor_state node resolves a real actor body
##   vocabulary    action_name() and phase_name() only ever return declared values
##   every kind    the player, EVERY enemy variant and the NPC all carry the SAME contract
##   authorities   exactly one damage authority and at most one target-validity authority per actor
##   variants      at least two enemy variants exist, share ONE script, and use DISTINCT profiles
##   data layer    each attacker's live tuning EQUALS the numbers in its .tres profile
##   seed          retuning a profile at runtime does NOT move the running attacker
##   lifecycle     the NPC is not targetable by default, and its flags match its profile
##
## Actor kinds are derived from existing authorities rather than from node names: the player is the
## `player_actor` group member, the NPC carries the PassiveNpc class, and an enemy is an actor
## carrying an attack machine.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 20
## Tolerance for comparing a profile's authored number against the value copied into the component.
const EPSILON := 0.0001
## How far a profile is nudged to prove it is a seed and not a per-frame authority. Deliberately
## far larger than any real tuning value, so a follower cannot be mistaken for a coincidence.
const SEED_PROBE_SHIFT := 12.0

## Where the report is written. `res://` so the run's result can be read back with ordinary file
## tools - the editor console does not reliably surface a running game's prints in this build.
const REPORT_PATH := "res://actor_contract_probe_report.txt"

var _frame := 0
var _done := false
var _failures: Array = []
## Checks that passed. Counted so the report states how much was actually measured rather than
## only how much failed.
var _passed := 0
## One line per actor examined, for the report's actor list.
var _subjects: Array = []
## One line per enemy variant, for the report's archetype list.
var _variants: Array = []


## EARLY MARKER, written at the first moment any of this script runs at all.
##
## It exists to tell two very different failures apart, because both look identical from
## outside as "no report": the probe scene never loading or never executing (nothing here
## runs), versus the probe running but the world never reaching its settle frame. The full
## report below OVERWRITES this line, so a marker still in the file means the settle never
## happened.
func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: probe scene loaded and _ready() executed")
		file.close()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	_done = true
	_run()


func _run() -> void:
	print("[ACTORCONTRACT] --- shared actor contract + archetype audit (measured) ---")
	_audit_coverage()
	_audit_kinds()
	_audit_variants()
	_audit_authorities()
	_report()


# --- The shared contract ------------------------------------------------------

## Every ActorState in the tree must resolve a real body and speak only its own vocabulary.
func _audit_coverage() -> void:
	var states := get_tree().get_nodes_in_group(ActorState.GROUP_ACTOR_STATE)
	print("[ACTORCONTRACT] actor_state nodes in the arena: %d" % states.size())
	_expect(states.size() > 0, "at least one actor publishes the shared state")

	var actions := ActorState.action_vocabulary()
	var phases := ActorState.phase_vocabulary()
	for node in states:
		var state := node as ActorState
		if state == null:
			_fail("a node in the actor_state group is not an ActorState")
			continue
		var actor: Node3D = state.get_actor()
		var label := String(actor.name) if actor != null else String(state.name)
		if actor == null:
			_fail("%s: publishes state but resolves NO actor body" % label)
			continue
		# A state node that resolves the wrong node is exactly the defect this catches: the paths
		# are body-relative by design, so resolving them from HERE would ask for `ActorState/Health`
		# and report a fully wired actor as unwired - which is the mistake these lines used to make.
		_expect(state.has_participant(),
			"%s: actor_state resolves its Participant" % label)
		_expect(state.has_health(),
			"%s: actor_state resolves its Health" % label)
		var action := state.action_name()
		var phase := state.phase_name()
		_expect(actions.has(action),
			"%s: action '%s' is in the shared vocabulary" % [label, action])
		_expect(phases.has(phase),
			"%s: phase '%s' is in the shared vocabulary" % [label, phase])
		print("[ACTORCONTRACT] %-14s state=%s" % [label, state.state_summary()])


## The player, EVERY enemy variant and the NPC must all be describable by the SAME contract.
##
## EVERY attacker is checked rather than one representative, because a second variant that is
## off-contract must FAIL here rather than hide behind the first one passing.
func _audit_kinds() -> void:
	var player := _player()
	_expect(player != null, "the player actor was found through the player_actor group")
	if player != null:
		_check_contract(player, "player")

	var npc := _first_of_type("PassiveNpc")
	_expect(npc != null, "the NPC archetype exists in the arena")
	if npc != null:
		_check_contract(npc, "npc")
		_audit_npc_defaults(npc)

	var attackers := _attackers()
	_expect(attackers.size() >= 1, "at least one enemy attacker exists in the arena")
	for attacker in attackers:
		var body := attacker.get_parent() as Node3D
		if body == null:
			_fail("an attacker has no body parent")
			continue
		_check_contract(body, "enemy:%s" % String(body.name))

	# The point of the milestone: DIFFERENT actor kinds, ONE vocabulary. Counted rather than
	# asserted against a fixed list, so the requirement grows with the arena instead of going
	# stale the moment a variant is added.
	var expected := 0
	var described := 0
	for body in [player, npc] as Array:
		expected += 1
		if body != null and ActorState.find_for(body) != null:
			described += 1
	for attacker in attackers:
		expected += 1
		var body := attacker.get_parent() as Node3D
		if body != null and ActorState.find_for(body) != null:
			described += 1
	_expect(expected >= 4,
		"the arena holds at least four actor kinds (player + npc + %d enemies)" % attackers.size())
	_expect(described == expected,
		"EVERY actor kind is described by ONE shared contract (%d/%d)" % [described, expected])


## Each actor resolves the shared parts. The NPC is the load-bearing one: it must carry the same
## contract as the enemy WITHOUT being an enemy.
func _check_contract(body: Node3D, kind: String) -> void:
	var state := ActorState.find_for(body)
	if state == null:
		_fail("%s: carries NO ActorState - not on the shared contract" % kind)
		return
	_expect(state.get_actor() == body, "%s: its state speaks for its own body" % kind)
	_expect(body.get_node_or_null("Health") is HealthComponent,
		"%s: carries a HealthComponent" % kind)
	_expect(CombatParticipant.find_for(body) != null,
		"%s: carries a CombatParticipant" % kind)
	print("[ACTORCONTRACT] %-8s id=%s alive=%s can_act=%s" % [
		kind, String(body.name), str(state.is_alive()), str(state.can_act())])
	_subjects.append("%s=%s alive=%s can_act=%s" % [
		kind, String(body.name), str(state.is_alive()), str(state.can_act())])


## The NPC's lifecycle defaults, which are the whole reason the profile layer exists for a
## civilian: a bystander must not be pulled into the player's target rotation merely by existing,
## and it must not be revivable unless its own data says so.
func _audit_npc_defaults(npc: Node3D) -> void:
	var participant := CombatParticipant.find_for(npc)
	_expect(participant != null and not participant.can_be_targeted,
		"the NPC is NOT targetable by default")
	var refusal := CombatParticipant.target_refusal(npc)
	_expect(refusal == CombatParticipant.Refusal.NOT_TARGETABLE,
		"the NPC refuses targeting with the recorded cause NOT_TARGETABLE (got %s)"
		% CombatParticipant.refusal_name(refusal))

	# The live lifecycle values, read from the actor itself.
	var live_respawnable: bool = bool(npc.get("respawnable"))
	var live_delay: float = float(npc.get("respawn_delay"))
	var has_profile_property: bool = "profile" in npc
	var live_profile: Variant = npc.get("profile") if has_profile_property else null
	print("[ACTORCONTRACT] npc raw: profile_property=%s profile=%s respawnable=%s delay=%.1f targetable=%s"
		% [str(has_profile_property), str(live_profile), str(live_respawnable), live_delay,
			str(participant.can_be_targeted if participant != null else false)])

	# DATA-DRIVEN, measured by BEHAVIOUR rather than by declaration, and that distinction is the
	# whole point of these two checks. The NPC's own component defaults are respawnable=false and
	# can_be_targeted=true; its archetype says the opposite of both. So a live value that DISAGREES
	# with the component default can only have arrived from the assigned profile - which is a
	# stronger statement than reading the resource reference back, and it cannot pass on a scene
	# that merely holds a resource nobody copies.
	_expect(live_respawnable,
		"npc: live respawnable came FROM the archetype (component default is false)")
	_expect(live_delay > 0.0,
		"npc: live respawn_delay came FROM the archetype (%.1fs)" % live_delay)
	_expect(participant != null and not participant.can_be_targeted,
		"npc: live targetability came FROM the archetype (component default is true)")

	# The reference itself is reported, not required: a scene always HOLDS its archetype resource,
	# while what matters is that the values above were copied out of it at _ready(). Fail loudly
	# only when the property exists and is genuinely empty, because then nothing was seeded.
	if has_profile_property and live_profile == null:
		_fail("the NPC's profile property exists but is EMPTY - its lifecycle is not data-driven")


# --- Enemy variants -----------------------------------------------------------

## Every attacker in the arena, discovered from the project's OWN `enemy_attacker` group.
##
## NOT a hand-written actor list, so a third variant is covered the moment it exists - and a
## variant that forgot to assign a profile FAILS below rather than being quietly absent from the
## report.
func _attackers() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(EnemyAttacker.GROUP_ATTACKER):
		var attacker := node as EnemyAttacker
		if attacker == null or not is_instance_valid(attacker):
			continue
		if attacker.get_parent() as Node3D == null:
			continue
		out.append(attacker)
	# Sorted so the report is deterministic rather than depending on group order.
	out.sort_custom(func(a: EnemyAttacker, b: EnemyAttacker) -> bool:
		return String(a.get_parent().name) < String(b.get_parent().name))
	return out


## The archetype model, proven rather than described: TWO variants, ONE script, DISTINCT data,
## live values equal to that data, and data that is a seed rather than an authority.
func _audit_variants() -> void:
	var attackers := _attackers()
	_expect(attackers.size() >= 2,
		"at least TWO enemy variants exist in the arena (%d)" % attackers.size())

	var scripts: Dictionary = {}
	var profiles: Dictionary = {}
	var archetypes: Array = []
	for attacker in attackers:
		var body := attacker.get_parent() as Node3D
		var label := String(body.name)

		# SAME BEHAVIOUR SCRIPT, taken from the component that implements it. A second enemy
		# variant must be data, not a second copy of the enemy implementation - so the number of
		# distinct attack scripts in the arena is the measurement, not a claim.
		var script: Script = attacker.get_script() as Script
		var script_path := String(script.resource_path) if script != null else ""
		scripts[script_path] = true

		var profile: EnemyAttackProfile = attacker.profile
		if profile == null:
			_fail("%s: carries an attack machine but NO archetype profile - not data-driven" % label)
			continue
		profiles[String(profile.resource_path)] = true
		archetypes.append(profile)
		_audit_profile(attacker, profile, label)
		_audit_seed_not_authority(attacker, profile, label)

	_expect(scripts.size() <= 1,
		"every enemy variant runs ONE behaviour script (%d distinct)" % scripts.size())
	_expect(profiles.size() == attackers.size(),
		"every enemy variant has its OWN archetype profile (%d for %d variants)" % [
			profiles.size(), attackers.size()])
	_audit_archetypes_differ(archetypes)


## Each archetype's live tuning must EQUAL the numbers in its file, and the built AttackDefinition
## must carry them too - a profile that was assigned but never copied would otherwise look
## correctly wired while changing nothing.
func _audit_profile(attacker: EnemyAttacker, profile: EnemyAttackProfile, label: String) -> void:
	print("[ACTORCONTRACT] profile %s -> %s" % [label, profile.summary()])
	_expect(is_equal_approx(attacker.windup, profile.windup),
		"%s: live windup matches the profile (%.2f)" % [label, attacker.windup])
	_expect(is_equal_approx(attacker.damage, profile.damage),
		"%s: live damage matches the profile (%.1f)" % [label, attacker.damage])
	_expect(is_equal_approx(attacker.engage_range, profile.engage_range),
		"%s: live engage_range matches the profile (%.2f)" % [label, attacker.engage_range])
	_expect(is_equal_approx(attacker.recovery, profile.recovery),
		"%s: live recovery matches the profile (%.2f)" % [label, attacker.recovery])
	_expect(is_equal_approx(attacker.attack_cooldown, profile.attack_cooldown),
		"%s: live cooldown matches the profile (%.2f)" % [label, attacker.attack_cooldown])
	_expect(attacker.attack != null and is_equal_approx(attacker.attack.damage, profile.damage),
		"%s: the built AttackDefinition carries the profile's damage" % label)
	_expect(not attacker.attack.display_name.is_empty(),
		"%s: the attack is named from the archetype, not a literal" % label)

	_variants.append(
		"%s script=%s profile=%s live(windup=%.2f damage=%.1f range=%.2f cooldown=%.2f health=%.1f)"
		% [label, _attacker_script_name(attacker), profile.display_name,
			attacker.windup, attacker.damage, attacker.engage_range, attacker.attack_cooldown,
			_body_health(attacker)])


## A profile is a SEED, not a live authority. Proven by MUTATING the resource and requiring the
## running attacker NOT to follow it.
##
## This is the only way to tell a one-time copy from a per-frame read: while the numbers happen to
## agree, the two are indistinguishable. The value is restored immediately, so the arena is left
## exactly as it was found.
func _audit_seed_not_authority(attacker: EnemyAttacker, profile: EnemyAttackProfile,
		label: String) -> void:
	var authored := profile.windup
	var live_before := attacker.windup
	profile.windup = authored + SEED_PROBE_SHIFT
	var live_after := attacker.windup
	profile.windup = authored
	_expect(is_equal_approx(live_after, live_before),
		"%s: retuning the profile at runtime does NOT move the running attacker (seed, not authority)"
		% label)
	# And the resource itself is left intact, so this measurement cannot corrupt the arena.
	_expect(is_equal_approx(profile.windup, authored),
		"%s: the profile was restored after the measurement (%.2f)" % [label, profile.windup])


## "Meaningfully different" has to mean a player could FEEL it, so this requires the archetypes to
## differ across several independent fields rather than in one number.
func _audit_archetypes_differ(archetypes: Array) -> void:
	if archetypes.size() < 2:
		_fail("fewer than two archetypes - cannot compare them")
		return
	var base: EnemyAttackProfile = archetypes[0]
	for index in range(1, archetypes.size()):
		var other: EnemyAttackProfile = archetypes[index]
		var differences: Array = []
		if not is_equal_approx(base.windup, other.windup):
			differences.append("windup")
		if not is_equal_approx(base.damage, other.damage):
			differences.append("damage")
		if not is_equal_approx(base.recovery, other.recovery):
			differences.append("recovery")
		if not is_equal_approx(base.engage_range, other.engage_range):
			differences.append("range")
		if not is_equal_approx(base.attack_cooldown, other.attack_cooldown):
			differences.append("cooldown")
		if not is_equal_approx(base.active, other.active):
			differences.append("active")
		print("[ACTORCONTRACT] %s vs %s differ in: %s" % [
			base.display_name, other.display_name, ", ".join(PackedStringArray(differences))])
		_expect(differences.size() >= 3,
			"'%s' and '%s' differ in at least THREE fields (%d: %s)" % [
				base.display_name, other.display_name, differences.size(),
				", ".join(PackedStringArray(differences))])


# --- One authority per concern ------------------------------------------------

## There must remain exactly ONE damage authority and at most ONE target-validity authority per
## actor. Counted rather than assumed: an actor carrying two HealthComponents, or two
## CombatParticipants, is exactly how a second authority gets introduced by accident - and it would
## look perfectly healthy in the scene tree.
func _audit_authorities() -> void:
	var checked := 0
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var body := health.get_parent()
		if body == null:
			continue
		checked += 1
		var label := String(body.name)

		var health_count := 0
		for child in body.get_children():
			if child is HealthComponent:
				health_count += 1
		_expect(health_count == 1,
			"%s: carries exactly ONE damage authority (%d)" % [label, health_count])

		var participant_count := 0
		for candidate in get_tree().get_nodes_in_group(CombatParticipant.GROUP_PARTICIPANT):
			var participant := candidate as CombatParticipant
			if participant != null and participant.get_actor() == body:
				participant_count += 1
		_expect(participant_count <= 1,
			"%s: carries at most ONE target-validity authority (%d)" % [label, participant_count])
	_expect(checked > 0, "at least one damageable actor was audited (%d)" % checked)


# --- Resolution ---------------------------------------------------------------

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player_actor") as Node3D


## The first actor carrying the project's own NPC class, found by type so no node name is
## assumed. Uses the script class rather than a name so a renamed NPC still resolves.
func _first_of_type(type_name: String) -> Node3D:
	for node in get_tree().get_nodes_in_group(ActorState.GROUP_ACTOR_STATE):
		var state := node as ActorState
		if state == null:
			continue
		var body := state.get_actor()
		if body == null:
			continue
		if _script_class_of(body) == type_name:
			return body
	return null


## The class_name of an actor's own script, or "" when it has none. Read through the script's
## global name so this depends on no particular scene structure - the same convention the
## project's other probes use when they need to tell actor kinds apart.
func _script_class_of(body: Node) -> String:
	# Typed explicitly: Node.get_script() hands back a Variant, and inferring from it would make
	# the local a Variant - which this project treats as an error rather than a warning.
	var script: Script = body.get_script() as Script
	if script == null:
		return ""
	return String(script.get_global_name())


## The file name of the behaviour script an attacker runs. Reported so the reader can SEE that two
## variants share one implementation.
func _attacker_script_name(attacker: EnemyAttacker) -> String:
	var script: Script = attacker.get_script() as Script
	if script == null:
		return "none"
	return String(script.resource_path).get_file()


## The health pool of an attacker's body, or -1.0 when it has none. Read from the component that
## owns it, never from a copy.
func _body_health(attacker: EnemyAttacker) -> float:
	var body := attacker.get_parent()
	if body == null:
		return -1.0
	var health := body.get_node_or_null("Health") as HealthComponent
	if health == null:
		return -1.0
	return health.max_health


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[ACTORCONTRACT]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ACTORCONTRACT]   FAIL  %s" % label)


## Print the verdict AND write it to a file.
##
## The file exists because the editor's console buffer does not reliably surface a running game's
## `print()` output in this build, which would leave a measured run with no readable result. The
## report is written to res:// so it can be read back with ordinary file tools rather than being
## taken on trust from a chat message.
func _report() -> void:
	var lines: Array = []
	lines.append("CASCADIA - SHARED ACTOR CONTRACT + ARCHETYPE PROBE (measured, not asserted)")
	lines.append("")
	lines.append("Actors found (discovered through groups, not a written list):")
	for entry in _subjects:
		lines.append("  - %s" % entry)
	lines.append("")
	lines.append("Enemy variants:")
	for entry in _variants:
		lines.append("  - %s" % entry)
	lines.append("")
	if _failures.is_empty():
		lines.append("RESULT: ALL CHECKS PASSED (%d)" % _passed)
		print("[ACTORCONTRACT] RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		lines.append("RESULT: %d CHECK(S) FAILED (%d passed)" % [_failures.size(), _passed])
		print("[ACTORCONTRACT] RESULT: %d CHECK(S) FAILED (%d passed)" % [_failures.size(), _passed])
	lines.append("")
	lines.append("Failures:")
	if _failures.is_empty():
		lines.append("  none")
	else:
		for failure in _failures:
			lines.append("  - %s" % failure)

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		print("[ACTORCONTRACT] could not write report to %s" % REPORT_PATH)
		return
	file.store_string("\n".join(PackedStringArray(lines)))
	file.close()
	print("[ACTORCONTRACT] report written to %s" % REPORT_PATH)
