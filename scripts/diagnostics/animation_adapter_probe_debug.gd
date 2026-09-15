class_name AnimationAdapterProbeDebug
extends Node3D
## Temporary diagnostic (not production): is ONE presentation layer really consuming the shared
## actor contract for EVERY actor - and is it reading LIVE gameplay state rather than showing a
## static label?
##
## Why this exists. The adapter could parse, attach to four scenes, and still be wrong in the two
## ways a compile can never catch:
##
##   1. it could GUESS instead of read - re-deriving an action from velocity or a timer, which
##      silently drifts from the contract the first time gameplay changes;
##   2. it could be STATIC - building its label once at `_ready()` and never reacting again, which
##      looks correct in every screenshot and is completely useless.
##
## So this probe does two different things. It COMPARES every value the adapter consumed against
## what ActorState returns directly, and it DRIVES real gameplay changes - a real committed attack,
## a real killing blow through the hurtbox chain - and requires the adapter's intent to follow.
##
## Discovery is by GROUP, never a written actor list, so a fifth actor carrying the adapter is
## covered the moment it exists.
##
## WHY IT REACHES THE ADAPTER THROUGH A preload CONST RATHER THAN ITS GLOBAL CLASS NAME, and this is
## deliberate rather than stylistic. The editor registers a `class_name` only once its global class
## registry has scanned the file, and a brand-new script in a brand-new directory is not registered
## the moment it is written - so annotating against it makes this whole probe fail to PARSE with a
## wall of "Identifier not declared" errors. Preloading by path depends on no registry, and the
## adapter's methods are reached by duck typing for the same reason. A diagnostic that cannot run
## until the editor catches up is a diagnostic that silently measures nothing.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const AdapterScript := preload("res://scripts/animation/animation_adapter.gd")

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 20
## Frames allowed after the killing blow for the defeat to land.
const HOLD_FRAMES := 8
## Frame budget for the driven attack to run to completion.
const ATTACK_BUDGET_FRAMES := 240
## Damage used for a lethal blow - far above any actor's pool, so "lethal" never depends on tuning.
const LETHAL := 9999.0

const REPORT_PATH := "res://animation_adapter_probe_report.txt"

var _frame := 0
var _stage := 0
var _wait := 0
var _done := false
var _failures: Array = []
var _passed := 0
var _lines: Array = []
var _subjects: Array = []
var _adapters: Array = []
var _player_combat: PlayerCombat


## Early marker, so "the scene never ran" and "the world never settled" can be told apart. The full
## report OVERWRITES this line, so a marker still in the file means the settle never happened.
func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: animation adapter probe loaded and _ready() executed")
		file.close()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		0:
			_audit_static()
			_start_player_attack()
			_stage = 1
			_wait = 0
		1:
			_wait += 1
			if _player_attack_finished() or _wait > ATTACK_BUDGET_FRAMES:
				_audit_player_phases()
				_kill("HeavyBrute")
				_stage = 2
				_wait = 0
		2:
			_wait += 1
			if _wait >= HOLD_FRAMES:
				_audit_dead_intent()
				_audit_npc_passive()
				_audit_still_valid()
				_done = true
				_report()


# --- Static audit -------------------------------------------------------------

func _audit_static() -> void:
	_adapters = _find_adapters()
	_lines.append("Animation adapters found (by group): %d" % _adapters.size())
	_expect(_adapters.size() >= 4,
		"at least FOUR actors are driven by one adapter (%d)" % _adapters.size())

	var vocabulary: PackedStringArray = AdapterScript.intent_vocabulary()
	var scripts: Dictionary = {}
	var kinds: Dictionary = {}
	## How many adapters sit on ENEMY archetypes. Two distinct enemy variants exist, and "one shared
	## script drives both" is the archetype claim this probe is here to check.
	var enemy_actors := 0

	for node in _adapters:
		var adapter: Variant = node
		if not adapter.has_method("intent_name"):
			_fail("a node in the animation_adapter group does not answer intent_name()")
			continue
		var body: Node3D = adapter.get_actor()
		if body == null:
			_fail("an adapter resolves NO actor body")
			continue
		var label := String(body.name)
		var kind := _kind_of(body)
		kinds[kind] = true
		if kind == "enemy":
			enemy_actors += 1

		_expect(adapter.is_wired(),
			"%s: the adapter is wired to a live ActorState" % label)

		var state: ActorState = ActorState.find_for(body)
		if state == null:
			_fail("%s: adapter present but the actor carries NO ActorState" % label)
			continue

		var intent: String = adapter.intent_name()
		_expect(not intent.is_empty(),
			"%s: the adapter reports a real intent rather than an empty one" % label)
		_expect(vocabulary.has(intent),
			"%s: intent '%s' is in the declared vocabulary" % [label, intent])

		# THE READ-THROUGH CHECK, and the reason this probe exists. Every value the adapter consumed
		# must EQUAL what the contract itself returns. A divergence means the adapter is deriving
		# its own answer, which is exactly how a presentation layer becomes a second authority.
		var snap: Variant = adapter.snapshot()
		var action: String = snap["action"]
		var phase: String = snap["phase"]
		_expect(action == state.action_name(),
			"%s: adapter's action EQUALS ActorState's (%s)" % [label, action])
		_expect(phase == state.phase_name(),
			"%s: adapter's phase EQUALS ActorState's (%s)" % [label, phase])
		_expect(bool(snap["moving"]) == state.is_moving(),
			"%s: adapter's moving flag EQUALS ActorState's" % label)
		_expect(bool(snap["sprinting"]) == state.is_sprinting(),
			"%s: adapter's sprinting flag EQUALS ActorState's" % label)
		_expect(bool(snap["grounded"]) == state.is_grounded(),
			"%s: adapter's grounded flag EQUALS ActorState's" % label)
		_expect(bool(snap["turning"]) == state.is_turning(),
			"%s: adapter's turning flag EQUALS ActorState's" % label)
		_expect(is_equal_approx(float(snap["yaw"]), state.facing_yaw()),
			"%s: adapter's facing yaw EQUALS ActorState's" % label)

		scripts[_script_path_of(adapter)] = true
		_subjects.append("%-13s kind=%-6s intent=%-14s script=%s" % [
			label, _kind_of(body), intent, _script_path_of(adapter)])

	_expect(scripts.size() == 1,
		"every adapter runs ONE shared script, not bespoke code per actor (%d distinct)" % scripts.size())
	# THERE ARE THREE KINDS, NOT FOUR, and correcting this is the point rather than loosening a bound.
	# Cascadia has exactly three actor KINDS - player, enemy and npc - while the arena has FOUR actors,
	# because two of them are enemy ARCHETYPES. The original wording demanded four distinct kinds,
	# which no arena can ever satisfy, so it could only ever have failed for a correct build. What
	# matters is that every kind is covered AND that BOTH enemy variants run the one shared script.
	_expect(kinds.size() >= 3,
		"the adapter covers EVERY actor kind in the arena (%d: %s)" % [
			kinds.size(), ", ".join(PackedStringArray(kinds.keys()))])
	_expect(enemy_actors >= 2,
		"BOTH enemy archetypes are driven by the same shared adapter (%d)" % enemy_actors)
	_lines.append("actor kinds covered: %s" % ", ".join(PackedStringArray(kinds.keys())))


# --- Driven gameplay: a real committed attack ---------------------------------

## Start a real attack on the PLAYER through its own state machine.
##
## Deliberately not faked by poking the adapter: `PlayerCombat.try_start()` is the production entry
## point, so the phases the probe then observes are the ones gameplay actually produced.
func _start_player_attack() -> void:
	var player: Node3D = _player()
	if player == null:
		_fail("the player actor was not found")
		return
	_player_combat = player.get_node_or_null("Combat") as PlayerCombat
	if _player_combat == null:
		_fail("the player has no Combat state machine to drive")
		return
	var definition := AttackDefinition.make("Probe Attack", 0.25, 0.12, 0.40, 15.0)
	var started: bool = _player_combat.try_start(definition)
	_expect(started, "the player's attack was accepted, so its phases are observable")
	_lines.append("drove the player's attack: PlayerCombat.try_start -> %s" % str(started))


func _player_attack_finished() -> bool:
	if _player_combat == null:
		return true
	return not _player_combat.is_busy()


## The adapter must have OBSERVED the attack's phases, not merely ended up idle again afterwards.
func _audit_player_phases() -> void:
	var adapter: Variant = _adapter_for(_player())
	if adapter == null:
		_fail("the player carries no animation adapter")
		return
	var history: Array = adapter.history_values()
	_lines.append("player intent history: %s" % ", ".join(PackedStringArray(history)))
	_expect(history.has(AdapterScript.INTENT_ATTACK_WINDUP),
		"the adapter OBSERVED the player's attack windup")
	_expect(history.has(AdapterScript.INTENT_ATTACK_ACTIVE),
		"the adapter OBSERVED the player's attack active window")
	_expect(history.has(AdapterScript.INTENT_ATTACK_RECOVERY),
		"the adapter OBSERVED the player's attack recovery")


# --- Driven gameplay: a real kill ---------------------------------------------

## One lethal blow through the existing receiving volume - the same route a real attack takes.
func _kill(actor_name: String) -> void:
	var body: Node3D = _actor_named(actor_name)
	if body == null:
		_fail("%s was not found to kill" % actor_name)
		return
	var event := DamageEvent.new()
	event.amount = LETHAL
	event.source = null
	var hurtbox := body.get_node_or_null("Hurtbox") as HurtboxComponent
	if hurtbox != null:
		hurtbox.receive_hit(event)
	else:
		var health := body.get_node_or_null("Health") as HealthComponent
		if health != null:
			health.apply_damage(event)
	_lines.append("applied a lethal blow to %s through the existing damage chain" % actor_name)


func _audit_dead_intent() -> void:
	var body: Node3D = _actor_named("HeavyBrute")
	var adapter: Variant = _adapter_for(body)
	if adapter == null:
		_fail("the HeavyBrute carries no animation adapter")
		return
	var intent: String = adapter.intent_name()
	_expect(intent == AdapterScript.INTENT_DEAD,
		"HeavyBrute: the adapter follows a lethal hit into the DEAD intent (got '%s')" % intent)
	_lines.append("HeavyBrute intent after the killing blow: %s" % intent)


## The NPC is a non-combatant, so no combat intent may EVER appear for it - which is also what
## proves the adapter is per-actor rather than one shared label.
func _audit_npc_passive() -> void:
	var adapter: Variant = _adapter_for(_first_of_type("PassiveNpc"))
	if adapter == null:
		_fail("the NPC carries no animation adapter")
		return
	var history: Array = adapter.history_values()
	_lines.append("NPC intent history: %s" % ", ".join(PackedStringArray(history)))
	var hostile := PackedStringArray([
		AdapterScript.INTENT_ATTACK_WINDUP,
		AdapterScript.INTENT_ATTACK_ACTIVE,
		AdapterScript.INTENT_ATTACK_RECOVERY,
		AdapterScript.INTENT_DODGE,
		AdapterScript.INTENT_PARRY,
		AdapterScript.INTENT_STAGGER,
	])
	var seen := ""
	for value in hostile:
		if history.has(value):
			seen = value
	_expect(seen.is_empty(),
		"the NPC NEVER reported a combat intent across the whole run (saw: %s)" % (
			"none" if seen.is_empty() else seen))


func _audit_still_valid() -> void:
	var vocabulary: PackedStringArray = AdapterScript.intent_vocabulary()
	for node in _adapters:
		var adapter: Variant = node
		if not is_instance_valid(adapter) or not adapter.has_method("intent_name"):
			continue
		var body: Node3D = adapter.get_actor()
		if body == null:
			continue
		var intent: String = adapter.intent_name()
		_expect(vocabulary.has(intent),
			"%s: still reports a declared intent at the end of the run" % String(body.name))


# --- Resolution ---------------------------------------------------------------

func _player() -> Node3D:
	return get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D


func _find_adapters() -> Array:
	return get_tree().get_nodes_in_group(AdapterScript.GROUP_ANIMATION_ADAPTER)


## The adapter belonging to `body`, or null. Duck-typed rather than cast, so this depends on no
## global class registration.
func _adapter_for(body: Node3D) -> Variant:
	if body == null:
		return null
	for node in _find_adapters():
		var adapter: Variant = node
		if not is_instance_valid(adapter) or not adapter.has_method("get_actor"):
			continue
		var actor: Node3D = adapter.get_actor()
		if actor == body:
			return adapter
	return null


func _actor_named(actor_name: String) -> Node3D:
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var body := health.get_parent() as Node3D
		if body != null and String(body.name) == actor_name:
			return body
	return null


## The first actor carrying the project's own NPC class, found by type so no node name is assumed.
func _first_of_type(type_name: String) -> Node3D:
	for node in _find_adapters():
		var adapter: Variant = node
		if not is_instance_valid(adapter) or not adapter.has_method("get_actor"):
			continue
		var body: Node3D = adapter.get_actor()
		if body != null and _script_class_of(body) == type_name:
			return body
	return null


## Which KIND of actor this is, derived from existing authorities rather than a node name.
func _kind_of(body: Node3D) -> String:
	if body.is_in_group(CreditLedger.GROUP_PLAYER_ACTOR):
		return "player"
	if _script_class_of(body) == "PassiveNpc":
		return "npc"
	if body.get_node_or_null("Attacker") != null:
		return "enemy"
	return "other"


func _script_class_of(body: Node) -> String:
	# Typed explicitly: get_script() hands back a Variant, and inferring from it would make the
	# local a Variant - which this project treats as an error rather than a warning.
	var script: Script = body.get_script() as Script
	if script == null:
		return ""
	return String(script.get_global_name())


func _script_path_of(node: Node) -> String:
	var script: Script = node.get_script() as Script
	if script == null:
		return ""
	return script.resource_path


# --- Reporting ----------------------------------------------------------------

func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[ANIMPROBE]   PASS  %s" % label)
	else:
		_fail(label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[ANIMPROBE]   FAIL  %s" % label)


## The report is written to res:// because this build's editor console does not reliably surface a
## running game's `print()` output - so the result has to be readable with ordinary file tools.
func _report() -> void:
	_lines.append("")
	_lines.append("Actors driven by the adapter:")
	for entry in _subjects:
		_lines.append("  - %s" % entry)
	_lines.append("")
	if _failures.is_empty():
		_lines.append("RESULT: ALL CHECKS PASSED (%d)" % _passed)
		print("[ANIMPROBE] RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		_lines.append("RESULT: %d CHECK(S) FAILED (%d passed)" % [_failures.size(), _passed])
		print("[ANIMPROBE] RESULT: %d CHECK(S) FAILED (%d passed)" % [_failures.size(), _passed])
	_lines.append("")
	_lines.append("Failures:")
	if _failures.is_empty():
		_lines.append("  none")
	else:
		for failure in _failures:
			_lines.append("  - %s" % failure)

	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		print("[ANIMPROBE] could not write report to %s" % REPORT_PATH)
		return
	file.store_string("\n".join(PackedStringArray(_lines)))
	file.close()
	print("[ANIMPROBE] report written to %s" % REPORT_PATH)
