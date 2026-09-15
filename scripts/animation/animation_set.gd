class_name AnimationSet
extends Resource
## ONE weapon's (or one creature's) animation content, addressed by SLOT (Milestone 21 - animation
## lookup architecture, Slice A).
##
## WHY THIS EXISTS. The driver that presents an actor must not know that it is presenting a FIST, a
## machete or a crowbar. Before this resource, the only way to teach the presentation layer a new
## moveset would have been to write that moveset's clip names into the driver - which means the
## driver becomes a per-weapon script, and swapping weapons becomes a code change.
##
## This resource is the separation. The driver resolves a SLOT KEY and asks this set for the clips.
## The set is DATA, assigned to the driver's node, so:
##
##     FistAnimationSet      MacheteAnimationSet      BatAnimationSet
##
## are three `.tres` files and THREE ASSIGNMENTS. No script changes, and combat is untouched.
##
## THE SLOT KEY SPACE IS OPEN ON PURPOSE, and it is wider than the game can currently request. That
## is deliberate and it is the point: a machete set can declare `attack:heavy_charged` the day a
## charged heavy attack exists, and until then that key is simply never asked for. A set declares
## what its PACK ships; the driver asks only for what gameplay can actually produce.
##
## ATTACK SLOTS ARE KEYED BY ATTACK IDENTITY, not by phase. `attack:light` is one slot, and the
## three gameplay phases (startup / active / recovery) all resolve to it. Whether a set then splits
## that slot per phase, or supplies one continuous motion for the whole attack, is a decision this
## pass deliberately does NOT make - see `docs` in the roadmap, section 21. The set is shaped so
## either answer fits: give the slot one clip, or give it the phase clips in order.
##
## WHAT THIS RESOURCE MUST NEVER DO: decide anything about the game. It holds no timing, no damage
## and no phase. It is a lookup table from a slot the gameplay layer already decided on, to clips
## that exist on disk. Replacing it cannot change how an actor behaves.

## Non-attack state slots. One per intent the animation driver can be in outside an attack.
const SLOT_IDLE := "idle"
const SLOT_LOCOMOTION := "locomotion"
const SLOT_SPRINT := "sprint"
const SLOT_DODGE := "dodge"
const SLOT_PARRY := "parry"
const SLOT_HURT := "hurt"
const SLOT_STAGGER := "stagger"
const SLOT_DEAD := "dead"

## The prefix every attack slot carries. Attack slots are built with `attack_slot()` rather than
## spelled out, so the one place the prefix lives is here.
const ATTACK_PREFIX := "attack:"

## The slot used when an actor is attacking but reports NO attack identity at all. It exists so that
## "attacking, identity unknown" is a DIFFERENT slot from "attacking, identity known" - a set can
## therefore supply a generic swing for it, or leave it empty and be reported as missing. It is
## never silently redirected to a specific attack, because guessing which attack is being performed
## is exactly the kind of assumption that makes a presentation layer lie.
const SLOT_ATTACK_UNKNOWN := ATTACK_PREFIX + "unknown"

## Resolution statuses, returned by `resolve()`. Each names a DIFFERENT outcome, so a caller can
## tell "the exact clip exists" from "we deliberately used the declared substitute" from "there is
## no content for this and it MUST be visible as a content problem".
##
## EXACT    the requested slot is populated. Play it.
## FALLBACK the requested slot is empty but declared a substitute, and that substitute is populated.
## NEUTRAL  the slot is empty and undeclared, so the set's neutral slot stands in.
## MISSING  there is no content for this slot AND no neutral to fall back to. A CONFIGURATION
##          problem, not a gameplay event, and the driver must report it rather than invent motion.
## NONE     there is no set at all (or it declares nothing), so nothing can be resolved.
const STATUS_EXACT := "exact"
const STATUS_FALLBACK := "fallback"
const STATUS_NEUTRAL := "neutral"
const STATUS_MISSING := "missing"
const STATUS_NONE := "none"

@export_group("Identity")
## Shown in diagnostics. Names the weapon or creature this set belongs to.
@export var display_name := "Animation Set"

@export_group("Slots")
## Slot key -> the clip name(s) for that slot, in play order. A one-element list is the common case
## (one complete motion); an ordered list exists so a set whose pack ships a fragmented motion can
## declare its parts WITHOUT the driver changing shape.
##
## Values may be a PackedStringArray or a plain Array of String; both are accepted.
@export var slots: Dictionary = {}

## Slot key -> the slot to use instead, when this set genuinely has no content for that key.
##
## DECLARED, not inferred. There is no automatic "fall back to the nearest attack" rule, because a
## rule like that silently plays a wrong animation and calls it success. A substitute that nobody
## wrote down does not exist.
@export var fallbacks: Dictionary = {}

## The slot used when a slot is empty and nothing was declared for it. Leave it populated: it is
## what keeps an unpopulated slot a visible NEUTRAL outcome instead of an invisible empty one.
@export var neutral_slot := SLOT_IDLE


## The slot key for one attack identity. Empty identity resolves to `attack:unknown` rather than to
## a specific attack, so an actor mid-attack with no identity is reported honestly.
static func attack_slot(attack_id: String) -> String:
	if String(attack_id).is_empty():
		return SLOT_ATTACK_UNKNOWN
	return ATTACK_PREFIX + attack_id


## Every slot key this resource declares, sorted, for a report or a completeness check.
func slot_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for key in slots.keys():
		keys.append(String(key))
	keys.sort()
	return keys


## Whether this set has any clips at all for `key`. An empty list counts as NOT populated, so a slot
## authored to nothing behaves as missing rather than as a zero-length animation.
func has_slot(key: String) -> bool:
	return clips_for(key).size() > 0


## The clips for `key`, or an EMPTY list when the slot is not populated. This is the raw lookup and
## it applies NO fallback rule - use `resolve()` when a substitute is acceptable.
func clips_for(key: String) -> PackedStringArray:
	if not slots.has(key):
		return PackedStringArray()
	var raw = slots[key]
	if raw == null:
		return PackedStringArray()
	var out: PackedStringArray = PackedStringArray()
	if raw is PackedStringArray:
		out = raw
	elif raw is Array:
		for entry in raw:
			out.append(String(entry))
	else:
		# A single clip authored as a bare String is a convenience, not a fourth schema.
		out.append(String(raw))
	return out


## The slot to use when `key` is empty: the declared substitute if it is populated, else the neutral
## slot if it is populated, else "".
func substitute_for(key: String) -> String:
	if fallbacks.has(key):
		var declared := String(fallbacks[key])
		if has_slot(declared):
			return declared
	if has_slot(neutral_slot):
		return neutral_slot
	return ""


## Resolve one slot key into the clips that should play, WITH the reason.
##
## Returns a Dictionary rather than a bare clip list so the CALLER can distinguish the outcomes,
## which is the whole point of the fallback policy: an exact hit, a declared substitute, a neutral
## stand-in and a genuine content gap must never be reported as the same result.
##
## Keys: status, requested, resolved, clips, note.
func resolve(key: String) -> Dictionary:
	var requested := String(key)
	if has_slot(requested):
		return _result(STATUS_EXACT, requested, requested, clips_for(requested), "")

	if fallbacks.has(requested):
		var declared := String(fallbacks[requested])
		if has_slot(declared):
			return _result(STATUS_FALLBACK, requested, declared, clips_for(declared),
				"declared substitute for '%s'" % requested)
		# A declared substitute that is itself empty is a CONFIGURATION ERROR, and it must not be
		# quietly retried as a neutral stand-in - the author's intent is on record and broken.
		return _result(STATUS_MISSING, requested, "", PackedStringArray(),
			"substitute '%s' is declared for '%s' but has no clips" % [declared, requested])

	if has_slot(neutral_slot):
		return _result(STATUS_NEUTRAL, requested, neutral_slot, clips_for(neutral_slot),
			"no content for '%s'; neutral slot '%s' stands in" % [requested, neutral_slot])

	return _result(STATUS_MISSING, requested, "", PackedStringArray(),
		"no content for '%s' and no neutral slot '%s' to stand in" % [requested, neutral_slot])


## Every declared slot-vocabulary key that has NO clips and NO usable substitute. This is the
## asset-completeness question asked in one call, which is what makes a thin set visible instead of
## mysterious.
func unpopulated_slots() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for key in slot_vocabulary():
		if has_slot(key):
			continue
		if substitute_for(key).is_empty():
			out.append(key)
	return out


## The whole set on readable lines, for a log or a probe report. Everything is printed, so a set can
## never be summarised as something it is not.
func summary() -> String:
	var lines: Array = []
	lines.append("%s: %d slot(s), neutral='%s'" % [display_name, slots.size(), neutral_slot])
	for key in slot_keys():
		var clips := clips_for(key)
		var note := ""
		if fallbacks.has(key):
			note = "  [fallback -> %s]" % String(fallbacks[key])
		lines.append("  %-28s %s%s" % [key, str(clips), note])
	return "\n".join(PackedStringArray(lines))


## Every non-attack slot key. The attack keys are open-ended and built with `attack_slot()`.
static func slot_vocabulary() -> PackedStringArray:
	return PackedStringArray([
		SLOT_IDLE, SLOT_LOCOMOTION, SLOT_SPRINT, SLOT_DODGE,
		SLOT_PARRY, SLOT_HURT, SLOT_STAGGER, SLOT_DEAD,
	])


func _result(status: String, requested: String, resolved: String, clips: PackedStringArray, note: String) -> Dictionary:
	return {
		"status": status,
		"requested": requested,
		"resolved": resolved,
		"clips": clips,
		"note": note,
	}
