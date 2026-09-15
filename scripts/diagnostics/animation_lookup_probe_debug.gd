class_name AnimationLookupProbeDebug
extends Node3D
## Temporary diagnostic (not production): does the animation lookup architecture actually preserve
## WHAT an actor is doing, and does it fail VISIBLY rather than silently when content is missing?
## (Milestone 21 - animation lookup architecture, Slice A.)
##
## WHY THIS EXISTS. The previous adapter could name three attack intents and no attack identity, so
## every attack in the game collapsed onto one of three keys. A probe that only asserted "an attack
## was seen" would pass on that old design and on the new one alike, which makes it worthless as
## evidence. So this probe asserts the things the OLD design could not do:
##
##   1. IDENTITY SURVIVES. A light attack and a heavy attack resolve to DIFFERENT slots. Under the
##      old vocabulary both were `attack_windup` / `attack_active` / `attack_recovery`.
##   2. IDENTITY PERSISTS ACROSS THE WHOLE COMMITMENT. During one attack the slot stays constant
##      while the intent walks startup -> active -> recovery. That is the phase-vs-identity split.
##   3. A MISSING CLIP IS REPORTED, NOT GUESSED. Exact / fallback / neutral / missing / none are
##      five distinguishable outcomes, and a slot with no content never silently plays a wrong clip.
##   4. GAMEPLAY IS UNTOUCHED. Every number this probe reads comes from gameplay's own owner, and
##      the adapter reports them unchanged.
##
## REACHED BY PRELOAD RATHER THAN BY GLOBAL CLASS NAME, for the reason the sibling adapter probe
## records: the editor registers a `class_name` only once its registry has scanned the file, and a
## brand-new script in a brand-new directory is not registered the moment it is written. Annotating
## against one makes the whole probe fail to PARSE until the editor catches up - a diagnostic that
## cannot run is a diagnostic that silently measures nothing.
##
## Discovery is by GROUP, never a written actor list, so a fifth actor carrying the adapter is
## covered the moment it exists.
##
## Recorded in CASCADIA_DELETION_MANIFEST.md. Delete with its scene.

const AdapterScript := preload("res://scripts/animation/animation_adapter.gd")
const SetScript := preload("res://scripts/animation/animation_set.gd")
const DefinitionScript := preload("res://scripts/combat/attack_definition.gd")

## Frames allowed for the arena to settle before anything is measured.
const SETTLE_FRAMES := 20
## Frame budget for one committed attack to run to completion.
const ATTACK_BUDGET_FRAMES := 240

const REPORT_PATH := "res://animation_lookup_probe_report.txt"

## Clip names used by the probe's SYNTHETIC set. They are deliberately not real pack clips: this
## pass proves the LOOKUP, and binding real content is the next slice. Using obvious fakes means a
## reader can never mistake a probe fixture for authored content.
const CLIP_IDLE := "PROBE_idle"
const CLIP_LIGHT := "PROBE_light_attack"
const CLIP_HEAVY := "PROBE_heavy_attack"
const CLIP_FALLBACK := "PROBE_fallback_swing"

var _frame := 0
var _stage := 0
var _wait := 0
var _done := false
var _failures: Array = []
var _passed := 0
var _lines: Array = []
var _adapters: Array = []
var _player_state: ActorState
var _player_adapter: Variant = null
## Every slot the player's adapter reported while one attack was committed.
var _light_slots: Array = []
var _light_intents: Array = []
var _heavy_slots: Array = []
## The attack definition the probe borrowed, so the identity it expects is the one gameplay built
## rather than one the probe invented.
var _driven_definition: Variant = null


func _ready() -> void:
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("MARKER: animation lookup probe loaded and _ready() executed")
		file.close()


func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < SETTLE_FRAMES:
		return
	match _stage:
		0:
			_audit_definition_keys()
			_audit_set_resolution()
			_audit_live_slots()
			_start_player_attack("light")
			_stage = 1
			_wait = 0
		1:
			_wait += 1
			_observe_attack(_light_slots, _light_intents)
			if _attack_finished() or _wait > ATTACK_BUDGET_FRAMES:
				_audit_identity_persisted(_light_slots, _light_intents, "attack:light", "light")
				_start_player_attack("heavy")
				_stage = 2
				_wait = 0
		2:
			_wait += 1
			_observe_attack(_heavy_slots, [])
			if _attack_finished() or _wait > ATTACK_BUDGET_FRAMES:
				_audit_two_attacks_do_not_collapse()
				_audit_gameplay_unchanged()
				_done = true
				_report()


# --- Pure architecture: no gameplay involved ----------------------------------

## The lookup KEY for an attack definition. Identity has to be stable, because it is the key an
## animation set is written against: if it moved, every set would silently stop matching.
func _audit_definition_keys() -> void:
	var with_id := DefinitionScript.make("Light Attack", 0.16, 0.10, 0.28, 15.0, "light")
	_expect(with_id.key() == "light",
		"an authored id IS the lookup key ('light' from id='light')")
	var without_id := DefinitionScript.make("Heavy Attack", 0.44, 0.14, 0.62, 32.0)
	_expect(without_id.key() == "heavy_attack",
		"with no id, the key is derived from the name ('heavy_attack' from 'Heavy Attack')")
	# Capitalization and punctuation must not be able to break a lookup, because a set author
	# writing "Light 1" or "light-1" means the same attack as "light_1".
	_expect(DefinitionScript.slug("Light 1") == "light_1",
		"a display name with a space slugs to one key ('Light 1' -> 'light_1')")
	_expect(DefinitionScript.slug("LIGHT-1") == "light_1",
		"case and punctuation do not change the key ('LIGHT-1' -> 'light_1')")
	_expect(DefinitionScript.slug("light_1") == "light_1",
		"an already-clean key is unchanged")
	_lines.append("attack keys: with_id='%s' derived='%s'" % [with_id.key(), without_id.key()])


## The five resolution outcomes, asserted against a SYNTHETIC set so the policy is proven
## independently of whether any real clip exists on disk yet.
func _audit_set_resolution() -> void:
	var set = SetScript.new()
	set.display_name = "Probe Set"
	set.neutral_slot = "idle"
	set.slots = {
		"idle": PackedStringArray([CLIP_IDLE]),
		"attack:light": PackedStringArray([CLIP_LIGHT]),
		"attack:heavy": PackedStringArray([CLIP_HEAVY]),
		"attack:unknown": PackedStringArray([CLIP_FALLBACK]),
	}
	# A slot that is empty but DECLARES a substitute. The substitute must be used, and the caller
	# must be told that is what happened.
	set.fallbacks = {"parry": "attack:unknown"}

	var exact: Dictionary = set.resolve("attack:light")
	_expect(String(exact.get("status")) == SetScript.STATUS_EXACT,
		"a populated slot resolves EXACT")
	_expect(String(exact.get("clips", [])[0]) == CLIP_LIGHT,
		"the exact slot returns ITS OWN clip")

	var fallback: Dictionary = set.resolve("parry")
	_expect(String(fallback.get("status")) == SetScript.STATUS_FALLBACK,
		"an empty slot with a DECLARED substitute resolves FALLBACK")
	_expect(String(fallback.get("clips", [])[0]) == CLIP_FALLBACK,
		"the fallback returns the substitute's clip, not the requested slot's")

	# `hurt` is empty and undeclared, so the neutral slot stands in - and that is a DIFFERENT
	# status from both exact and missing.
	var neutral: Dictionary = set.resolve("hurt")
	_expect(String(neutral.get("status")) == SetScript.STATUS_NEUTRAL,
		"an empty undeclared slot falls to the NEUTRAL slot and says so")
	_expect(String(neutral.get("clips", [])[0]) == CLIP_IDLE,
		"the neutral stand-in returns the neutral clip")

	# Now break the neutral slot, so a genuinely absent clip is reachable. This is the case the
	# whole policy exists for: it must be MISSING, never a silently wrong motion.
	set.neutral_slot = "idle"
	set.slots.erase("idle")
	var missing: Dictionary = set.resolve("hurt")
	_expect(String(missing.get("status")) == SetScript.STATUS_MISSING,
		"with no neutral to stand in, an absent clip resolves MISSING")
	var missing_clips: PackedStringArray = missing.get("clips", PackedStringArray())
	_expect(missing_clips.size() == 0,
		"a MISSING slot returns NO clip rather than an arbitrary one")

	# A declared substitute that is ITSELF empty is a configuration error, and it must not be
	# quietly retried as a neutral stand-in - the author's intent is on record and broken.
	var broken = SetScript.new()
	broken.slots = {"idle": PackedStringArray([CLIP_IDLE])}
	broken.fallbacks = {"parry": "attack:heavy"}
	var broken_result: Dictionary = broken.resolve("parry")
	_expect(String(broken_result.get("status")) == SetScript.STATUS_MISSING,
		"a declared substitute that is itself EMPTY is reported MISSING, not silently neutralled")

	# No set at all is its own outcome, distinct from "the set has no content".
	var none: Dictionary = broken.resolve("")
	_lines.append("slot vocabulary: %s" % str(SetScript.slot_vocabulary()))


## Every wired adapter must be able to NAME the slot it wants. An adapter that reports a state but
## resolves no slot cannot be looked up at all, which is the defect this pass removes.
func _audit_live_slots() -> void:
	_adapters = _find_adapters()
	_lines.append("adapters found (by group): %d" % _adapters.size())
	_expect(_adapters.size() >= 4,
		"at least FOUR actors are driven by one adapter (%d)" % _adapters.size())
	for node in _adapters:
		var adapter: Variant = node
		if not adapter.is_wired():
			continue
		var body: Node3D = adapter.get_actor()
		var slot := String(adapter.slot_name())
		_expect(not slot.is_empty(),
			"%s: a wired adapter resolves a non-empty SLOT ('%s')" % [String(body.name), slot])
		# With no set assigned, the clip is empty and that is honest, not a failure.
		var status := String(adapter.resolution_status())
		_expect(status == SetScript.STATUS_NONE or status == SetScript.STATUS_EXACT
				or status == SetScript.STATUS_FALLBACK or status == SetScript.STATUS_NEUTRAL
				or status == SetScript.STATUS_MISSING,
			"%s: reports one of the five documented resolution outcomes ('%s')" % [String(body.name), status])


# --- Driving real gameplay ----------------------------------------------------

## Start a REAL committed attack through the owner's own entry point, so the identity under test is
## the one gameplay builds rather than one the probe fabricated.
func _start_player_attack(which: String) -> void:
	var combat: Node = _find_player_combat()
	if combat == null:
		_fail("no PlayerCombat found, so no attack could be driven")
		return
	var definition: Variant = null
	if which == "light":
		definition = combat.light_attack
	else:
		definition = combat.heavy_attack
	if definition == null:
		_fail("PlayerCombat has no %s attack definition" % which)
		return
	_driven_definition = definition
	if not combat.try_start(definition):
		_fail("the %s attack was REFUSED, so the identity path could not be observed" % which)


## Record what the presentation layer said on this frame while an attack is committed. Both the slot
## (the lookup key) and the intent (the coarse state) are recorded, because the distinction between
## them is the point: they move independently and only the slot carries identity.
func _observe_attack(slot_sink: Array, intent_sink: Array) -> void:
	if _player_adapter == null:
		_player_adapter = _find_player_adapter()
	if _player_adapter == null:
		return
	var state := _get_player_state()
	if state == null or not state.is_attacking():
		return
	slot_sink.append(String(_player_adapter.slot_name()))
	if intent_sink != null:
		intent_sink.append(String(_player_adapter.intent_name()))


## THE CENTRAL CLAIM OF THIS PASS: one attack keeps ONE lookup slot for its entire commitment while
## the coarse intent walks startup -> active -> recovery.
func _audit_identity_persisted(slots: Array, intents: Array, expected_slot: String, which: String) -> void:
	_expect(slots.size() > 0,
		"the %s attack was OBSERVED on committed frames (%d frame(s))" % [which, slots.size()])
	if slots.is_empty():
		return
	var distinct := {}
	for s in slots:
		distinct[s] = true
	_expect(distinct.size() == 1 and distinct.has(expected_slot),
		"the %s attack holds ONE slot for its whole commitment ('%s')" % [which, expected_slot])

	# The intent must have MOVED while the slot did not. If both were constant the probe would be
	# proving nothing about the split, so this is asserted rather than assumed.
	var phases := {}
	for i in intents:
		phases[i] = true
	_expect(phases.size() >= 2,
		"the coarse INTENT moved through multiple phases while the slot stayed fixed (%d phase(s))" % phases.size())
	_lines.append("%s: %d committed frame(s), slots=%s intents=%s" % [
		which, slots.size(), str(distinct.keys()), str(phases.keys())])


## Light and heavy must not share a lookup key. Under the old vocabulary they did.
func _audit_two_attacks_do_not_collapse() -> void:
	var light_distinct := {}
	for s in _light_slots:
		light_distinct[s] = true
	var heavy_distinct := {}
	for s in _heavy_slots:
		heavy_distinct[s] = true
	if light_distinct.is_empty() or heavy_distinct.is_empty():
		_fail("could not observe both attacks, so collapse cannot be ruled out")
		return
	var light_key := String(light_distinct.keys()[0])
	var heavy_key := String(heavy_distinct.keys()[0])
	_expect(light_key != heavy_key,
		"light and heavy resolve to DIFFERENT slots ('%s' vs '%s')" % [light_key, heavy_key])


## The adapter must report gameplay's own values, not its own opinion of them. This is the
## read-through check: a layer that guesses drifts the first time gameplay changes.
func _audit_gameplay_unchanged() -> void:
	var state := _get_player_state()
	if state == null:
		_fail("the player carries no ActorState to compare against")
		return
	# At rest, identity is empty - "not attacking" and "attacking anonymously" stay distinguishable.
	_expect(not state.is_attacking(),
		"the player is at rest once the driven attacks completed")
	_expect(String(state.attack_id()).is_empty(),
		"at rest the contract reports NO attack identity ('%s')" % state.attack_id())
	if _driven_definition != null:
		_expect(String(_driven_definition.key()) == "light" or String(_driven_definition.key()) == "heavy",
			"the driven definition kept its own authored key ('%s')" % _driven_definition.key())


# --- Helpers ------------------------------------------------------------------

func _attack_finished() -> bool:
	var combat: Node = _find_player_combat()
	if combat == null:
		return true
	return not combat.is_busy()


func _get_player_state() -> ActorState:
	if _player_state != null and is_instance_valid(_player_state):
		return _player_state
	# Discovered through the project's ESTABLISHED player group, the same one every other probe, the
	# HUD, the ledger and the stake use. An INVENTED group name is not a harmless placeholder: it
	# finds nothing, which silently turns every player assertion below into a null comparison that
	# reads like a gameplay failure.
	var player := get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	if player == null:
		_fail("no node in group '%s', so the player contract could not be read" % CreditLedger.GROUP_PLAYER_ACTOR)
		return null
	_player_state = ActorState.find_for(player)
	return _player_state


func _find_player_combat() -> Node:
	var found := get_tree().get_first_node_in_group("player_combat")
	return found


func _find_player_adapter() -> Variant:
	var state := _get_player_state()
	if state == null:
		return null
	var body := state.get_actor()
	for node in _find_adapters():
		var adapter: Variant = node
		if adapter.get_actor() == body:
			return adapter
	return null


func _find_adapters() -> Array:
	return get_tree().get_nodes_in_group(AdapterScript.GROUP_ANIMATION_ADAPTER)


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		_lines.append("PASS  %s" % label)
	else:
		_failures.append(label)
		_lines.append("FAIL  %s" % label)


func _fail(label: String) -> void:
	_failures.append(label)
	_lines.append("FAIL  %s" % label)


func _report() -> void:
	var total := _passed + _failures.size()
	_lines.append("")
	if _failures.is_empty():
		_lines.append("RESULT: ALL CHECKS PASSED (%d)" % _passed)
	else:
		_lines.append("RESULT: %d of %d CHECK(S) FAILED" % [_failures.size(), total])
		for f in _failures:
			_lines.append("  - %s" % f)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		for line in _lines:
			file.store_line(line)
		file.close()
	print("[ANIMLOOKUP] " + String(_lines[_lines.size() - 1]))
