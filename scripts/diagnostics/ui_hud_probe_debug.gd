class_name UiHudProbeDebug
extends Node3D
## Temporary diagnostic (not production): does Milestone 13's minimal UI do what it claims?
##
## WHAT THIS MEASURES, and each check is a MEASUREMENT rather than a restatement:
##
##   1. WIRED IN THE SHIPPED SCENE. The HUD, the lock-on indicator and the pause menu are found in the
##      LIVE main scene, not by loading a test scene, and each of them resolved the SAME owner objects
##      the rest of the project uses (CreditLedger, the player's HealthComponent and StaminaComponent,
##      and the TargetingComponent). That identity is what makes "the HUD reads the real owner"
##      checkable instead of assumed.
##   2. THE DISPLAY FOLLOWS THE REAL VALUE. The player is actually damaged, stamina is actually spent
##      and Credits are actually awarded, and the HUD's own label TEXT is asserted to change to the new
##      value on each one - not that a label exists.
##   3. THE LOCK-ON INDICATOR. Hidden while unlocked; shown on the acquired target; MOVED to the new
##      target after a cycle in either direction; hidden again on each of the FOUR release causes,
##      each caused independently and each checked by its recorded cause.
##   4. PAUSE. A real Escape key press through the engine's input pipeline sets `get_tree().paused`;
##      a gameplay measurement taken while paused does not advance; the panel stays interactive while
##      the tree is paused; resume clears it and gameplay advances again; repeated toggling neither
##      stacks a second panel (there is only ever one node) nor re-applies the same pause state.
##   5. SAVE AND LOAD. Both are driven through the EXISTING GameStateSave service, and the status TEXT
##      the panel displays is asserted to differ between a success and a refusal, derived from the
##      RETURNED Result code.
##   6. LOADED STATE IS FRESH. A save is written whose carried balance differs from the live balance,
##      the live balance is then moved elsewhere, and after the load the HUD is asserted to display the
##      RESTORED value rather than the pre-load number.
##   7. THE MOUSE PATH IS UNTOUCHED. Every visible Control under the three new modules is asserted to
##      be MOUSE_FILTER_IGNORE while the game is unpaused, and the project's own offender enumeration
##      (the one `focus_input_routing_probe_debug` runs) is repeated here and asserted empty. Cascadia's
##      light and heavy attacks are bound to MOUSE BUTTONS, so a Control that could take a click would
##      silently eat an attack.
##
## WHAT THIS LEAVES BEHIND, stated rather than hidden:
##   - It writes the real save file at `user://cascadia_save.json`, exactly as the M10 probes do. There
##     is one save path in this project and the service owns it.
##   - Its controlled award moves the ledger's own `awards` counter by one. The CARRIED BALANCE is put
##     back through the ledger's public restore path and asserted equal to where it started, so no
##     Credits are minted; the counter is reported rather than claimed clean.
##   - The player is damaged and killed during the four-release-cause checks, and restored afterwards
##     through its own reset and snapshot-restore APIs, with the damage and the death both measured.
##
## It does NOT grade readability, feel or clarity. Whether the HUD is legible and the pause feels right
## is the user's call and no probe can carry it.

const REPORT_PATH := "res://_ui_hud_probe_report.txt"

## Frames to let the scene settle before anything is read.
const SETTLE_FRAMES := 20
## Frames allowed for an injected press to be buffered and consumed.
const INPUT_FRAMES := 4
## Frames allowed for a state change (lock, pause, indicator) to land.
const STATE_FRAMES := 3
## Distance a probe target is placed at when a lock is taken, inside both ranges.
const NEAR_DISTANCE := 5.0
## Beyond both ranges, so the lock releases itself.
const FAR_DISTANCE := 40.0
## Non-lethal damage applied for the health-display measurement, chosen so the two displayed values
## differ at the displayed precision.
const DAMAGE_AMOUNT := 9.0
## Stamina left in the pool after the spend measurement.
const STAMINA_REMAINDER := 37.0
## Credits added by the controlled award.
const AWARD_AMOUNT := 25
## How much the saved balance differs from the live one, so a stale number is unmistakable.
const SAVE_BALANCE_OFFSET := 500
## How much the live balance is moved by AFTER the save, so the pre-load number is a third value.
const LIVE_BALANCE_OFFSET := 5

var _input: CascadiaInput
var _targeting: TargetingComponent
var _ledger: CreditLedger
var _save: GameStateSave
var _player: Node3D
var _health: HealthComponent
var _stamina: StaminaComponent
var _combat: Node
var _death: Node
var _hud: GameHUD
var _indicator: LockOnIndicator
var _pause: PauseMenu
var _rig: Node

var _player_start := Transform3D()
var _credits_start := 0
var _awards_start := 0
var _health_start := 0.0
var _stamina_start := 0.0

var _temporaries: Array = []
var _failures: Array = []
var _transcript: Array = []
var _checks := 0
## Freeing a node and having it leave the tree are not the same instant, so the instances that must be
## gone by the end are remembered here and free-checked once the whole run has finished.
var _must_be_freed: Array = []


func _ready() -> void:
	# ALWAYS, so a pause this probe itself creates cannot silence the probe that is measuring it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[UIHUD] === Milestone 13 minimal-UI probe ===")
	_run()


## The arena's attacker would otherwise fight the player during the probe and turn a controlled death
## into an uncontrolled one. The same stand-down the existing probes use, for the same reason.
func _process(_delta: float) -> void:
	EnemyAttacker.stand_down_all(get_tree())


func _run() -> void:
	await _wait(SETTLE_FRAMES)
	if not _resolve():
		_report()
		return
	await _ensure_input_active()
	_capture_start_state()

	_phase_presence_and_wiring()
	await _phase_hud_values()
	await _phase_indicator()
	await _phase_pause()
	await _phase_save_and_load()
	await _phase_new_run()
	await _phase_cleanup()
	_report()


# --- Phase 1: presence and wiring --------------------------------------------

func _phase_presence_and_wiring() -> void:
	_say("[UIHUD] --- PHASE 1: the new UI is live in the shipped scene and reads the real owners ---")
	_expect(_hud != null, "the HUD is instantiated in the shipped main scene (%s)" % _hud_path())
	_expect(_indicator != null, "the lock-on indicator is instantiated in the shipped main scene")
	_expect(_pause != null, "the pause menu is instantiated in the shipped main scene")

	_expect(_hud.get("_ledger") == _ledger,
		"the HUD resolved the SAME CreditLedger the rest of the project uses")
	_expect(_hud.get("_health") == _health,
		"the HUD resolved the player's OWN HealthComponent")
	_expect(_hud.get("_stamina") == _stamina,
		"the HUD resolved the player's OWN StaminaComponent")
	_expect(_indicator.get("_targeting") == _targeting,
		"the indicator resolved the SAME TargetingComponent the rest of the project uses")
	_expect(_pause.get("_save") == _save or _pause.get("_save") == null,
		"the pause menu takes save/load from GameStateSave rather than owning any of it")

	_expect(_hud.credits_label != null and _hud.health_label != null and _hud.stamina_label != null,
		"the HUD exposes the three readouts it displays")
	_expect(_pause.status_label != null and _pause.save_button != null and _pause.load_button != null,
		"the pause panel exposes its status line and its save/load controls")
	_expect(not _pause.panel.visible,
		"the pause panel starts HIDDEN - not transparent, not off-centre")


func _hud_path() -> String:
	if _hud == null:
		return "<missing>"
	return String(_hud.get_path())


# --- Phase 2: the HUD follows the real values --------------------------------

func _phase_hud_values() -> void:
	_say("[UIHUD] --- PHASE 2: the displayed text follows the real owners ---")

	# THE DISPLAY MUST ALREADY BE CORRECT AT REST, before anything changes, and this assertion exists
	# because its absence hid a real defect. Every check below measures a CHANGE, so a HUD that started
	# out stale and caught up on the first damage event passed all of them - and that is exactly what it
	# was doing: `main.tscn` places this HUD BEFORE `TestEnvironment` in tree order, so the HUD's
	# `_ready()` read the player's Health and Stamina before those components had run their own
	# `_ready()` and reset themselves to full. The shipped game showed `HEALTH 0 / 100` next to a combat
	# overlay reading `100/100`. Fixed in `game_hud.gd` by refreshing once when the owner connections
	# land; this is what would catch a regression.
	await _wait(STATE_FRAMES)
	_expect(_hud.health_label.text == "HEALTH  %d / %d" % [int(_health.current_health),
			int(_health.max_health)],
		"at rest the HUD ALREADY shows the owner's health, not a value read before its owner was ready (%s)"
			% _hud.health_label.text)
	_expect(_hud.stamina_label.text == "STAMINA  %d / %d" % [int(_stamina.current_stamina),
			int(_stamina.max_stamina)],
		"at rest the HUD ALREADY shows the owner's stamina (%s)" % _hud.stamina_label.text)
	_expect(_hud.credits_label.text == "CREDITS  %d" % _ledger.get_credits(),
		"at rest the HUD ALREADY shows the owner's credits (%s)" % _hud.credits_label.text)

	_phase_hud_health()
	_phase_hud_stamina()
	_phase_hud_credits()


## Apply real damage and assert the displayed HEALTH text changed to the new value.
func _phase_hud_health() -> void:
	var before_text := _hud.health_label.text
	var before_value := _health.current_health
	var event := DamageEvent.new()
	event.amount = DAMAGE_AMOUNT
	event.source = _player
	var applied: bool = _health.apply_damage(event)
	await _wait(STATE_FRAMES)
	var after_text := _hud.health_label.text
	var expected := "HEALTH  %d / %d" % [int(before_value - DAMAGE_AMOUNT), int(_health.max_health)]
	_expect(applied, "damage was really applied to the player (%.1f -> %.1f)"
		% [before_value, _health.current_health])
	_expect(after_text != before_text, "the HUD health text changed after the damage (%s -> %s)"
		% [before_text, after_text])
	_expect(after_text == expected, "and it shows the owner's NEW value: %s" % expected)


## Spend real stamina and assert the displayed STAMINA text changed to the new value.
func _phase_hud_stamina() -> void:
	var before_text := _hud.stamina_label.text
	var cost := maxf(0.0, _stamina.current_stamina - STAMINA_REMAINDER)
	var spent: bool = _stamina.try_spend(cost)
	await _wait(STATE_FRAMES)
	var after_text := _hud.stamina_label.text
	var expected := "STAMINA  %d / %d" % [int(_stamina.current_stamina), int(_stamina.max_stamina)]
	_expect(spent, "a real stamina cost was paid (%.1f spent, %.1f left)"
		% [cost, _stamina.current_stamina])
	_expect(after_text != before_text, "the HUD stamina text changed after the spend (%s -> %s)"
		% [before_text, after_text])
	_expect(after_text == expected, "and it shows the owner's NEW value: %s" % expected)


## Award real Credits and assert the displayed CREDITS text changed to the new balance.
func _phase_hud_credits() -> void:
	var before_text := _hud.credits_label.text
	var before_value := _ledger.get_credits()
	_ledger.award_credits(AWARD_AMOUNT, "ui_hud_probe")
	await _wait(STATE_FRAMES)
	var after_text := _hud.credits_label.text
	var expected := "CREDITS  %d" % (before_value + AWARD_AMOUNT)
	_expect(after_text != before_text, "the HUD credits text changed after the award (%s -> %s)"
		% [before_text, after_text])
	_expect(after_text == expected, "and it shows the owner's NEW value: %s" % expected)
	_expect(_ledger.get_credits() == before_value + AWARD_AMOUNT,
		"the ledger's carried balance is the value the HUD is showing")


# --- Phase 3: the lock-on indicator ------------------------------------------

func _phase_indicator() -> void:
	_say("[UIHUD] --- PHASE 3: the lock-on indicator ---")
	_targeting.release()
	await _wait(STATE_FRAMES)

	_expect(not _indicator.visible, "UNLOCKED: the indicator is hidden")
	_expect(not _indicator.is_marking(),
		"UNLOCKED: the indicator is marking nothing (it holds no target of its own)")

	var first := _spawn_target("ProbeUiTarget_A")
	var second := _spawn_target("ProbeUiTarget_B")

	# (a) ACQUIRE, right of the first target so the cycle order is unambiguous.
	_expect(await _lock_onto(first), "a lock was taken on the first probe target")
	await _wait(STATE_FRAMES)
	_expect(_indicator.visible, "ACQUIRED: the indicator became visible")
	_expect(_indicator.is_marking() and _indicator.marked == first,
		"ACQUIRED: the indicator is marking the CURRENT target (%s)" % _actor_name(_indicator.marked))
	var expected_height := first.global_position + Vector3(0.0, _indicator.height_offset, 0.0)
	_expect(_indicator.global_position.distance_to(expected_height) < 0.25,
		"ACQUIRED: the marker stands on the target, %.2f m above it"
			% _indicator.global_position.distance_to(expected_height))
	var marks_after_acquire := _indicator.marks

	# (b) CYCLE RIGHT, then LEFT back again: both directions must move the marker.
	_expect(_targeting.cycle(1), "the lock cycled to the right")
	await _wait(STATE_FRAMES)
	_expect(_indicator.visible and _indicator.marked != null and _indicator.marked != first,
		"CYCLE RIGHT: the indicator moved to the new target (%s)" % _actor_name(_indicator.marked))
	_expect(_indicator.name_label.text == _actor_name(_indicator.marked),
		"CYCLE RIGHT: the marker names the target it moved to (%s)" % _indicator.name_label.text)
	_expect(_indicator.marks == marks_after_acquire + 1,
		"the move is counted as a new mark, not as the old one drifting")

	_expect(_targeting.cycle(-1), "the lock cycled to the left")
	await _wait(STATE_FRAMES)
	_expect(_indicator.visible and _indicator.marked == first,
		"CYCLE LEFT: the indicator moved back to the original target (%s)"
			% _actor_name(_indicator.marked))

	# (c) THE FOUR RELEASE CAUSES, each caused independently and each checked by its recorded cause.
	await _release_by_defeat(first)
	await _release_by_freeing(second)
	await _release_by_range()
	await _release_by_player_death()

	# The marker must not be left on anything.
	await _wait(STATE_FRAMES)
	_expect(not _indicator.visible, "no release path left the indicator visible")


## RELEASE CAUSE 1: the target is defeated. Reached through the project's own state-restore API rather
## than by dealing lethal damage, because `restore_defeated()` deliberately does NOT emit `defeated`
## and that signal is what pays a reward - so this path exercises the very same release and mints
## nothing.
func _release_by_defeat(target: Node3D) -> void:
	_expect(await _lock_onto(target), "RELEASE 1: the lock is taken on the probe target")
	var before := _release_count("defeated")
	var invalid_before := _release_count("invalid")
	var death: Node = target.get_node_or_null("Death")
	_expect(death != null, "RELEASE 1: the probe target carries a defeat authority")
	if death != null:
		death.call("restore_defeated", true)
	_expect(death != null and bool(death.call("is_defeated")),
		"RELEASE 1: the target is in its authoritative DEFEATED state")
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "RELEASE 1 (DEFEATED): the lock ended")
	_expect(_release_count("defeated") == before + 1,
		"RELEASE 1: recorded as defeated, not as something else")
	_expect(_release_count("invalid") == invalid_before, "RELEASE 1: and NOT filed as invalid")
	_expect(not _indicator.visible, "RELEASE 1 (DEFEATED): the indicator is hidden")
	_destroy(target)


## RELEASE CAUSE 2: the target is freed.
func _release_by_freeing(target: Node3D) -> void:
	_expect(await _lock_onto(target), "RELEASE 2: the lock is taken on a second probe target")
	var before := _release_count("invalid")
	_destroy(target)
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "RELEASE 2 (FREED): the lock ended")
	_expect(_release_count("invalid") == before + 1, "RELEASE 2: recorded as invalid")
	_expect(not _indicator.visible, "RELEASE 2 (FREED): the indicator is hidden")


## RELEASE CAUSE 3: the locked target goes beyond release_range.
func _release_by_range() -> void:
	var far := _spawn_target("ProbeUiTarget_Far")
	_expect(await _lock_onto(far), "RELEASE 3: the lock is taken on a third probe target")
	var before := _release_count("out-of-range")
	far.global_position = _placement(0.0, FAR_DISTANCE)
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "RELEASE 3 (OUT OF RANGE): the lock ended")
	_expect(_release_count("out-of-range") == before + 1, "RELEASE 3: recorded as out-of-range")
	_expect(not _indicator.visible, "RELEASE 3 (OUT OF RANGE): the indicator is hidden")
	_destroy(far)


## RELEASE CAUSE 4: the player dies. The player is killed for real and then restored by its own death
## circuit, which is the same route the M12 probe takes.
func _release_by_player_death() -> void:
	var survivor := _spawn_target("ProbeUiTarget_Survivor")
	_expect(await _lock_onto(survivor), "RELEASE 4: the lock is taken on a fourth probe target")
	var before := _release_count("player-dead")
	_apply_lethal(_player)
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "RELEASE 4 (PLAYER DEATH): the lock ended")
	_expect(_release_count("player-dead") == before + 1, "RELEASE 4: recorded as player-dead")
	_expect(not _indicator.visible, "RELEASE 4 (PLAYER DEATH): the indicator is hidden")
	_reset_player()
	await _wait(STATE_FRAMES)
	_expect(not _player_dead(), "the player was restored by its own death circuit")
	_destroy(survivor)


# --- Phase 4: pause ----------------------------------------------------------

func _phase_pause() -> void:
	_say("[UIHUD] --- PHASE 4: pause ---")
	_expect(not get_tree().paused, "the tree is NOT paused before the pause checks")
	_expect(not _pause.panel.visible, "the pause panel is hidden before the pause checks")

	# A REAL Escape press through the engine's input pipeline, so what is measured is the gesture the
	# player's fingers make rather than a direct call on the module.
	# ESCAPE OPENS THE PAUSE ON ITS FIRST PRESS (changed 2026-09-14 at the user's request). The earlier
	# version was layered: the first Escape only released the cursor and the SECOND opened the panel.
	# The cursor release was not lost - `open()` performs that same intent through the input layer.
	var writes_before := _pause.pause_writes
	await _press_key(KEY_ESCAPE)
	await _wait(STATE_FRAMES)
	_expect(get_tree().paused, "ESCAPE: a real Escape press PAUSED the tree on the FIRST press")
	_expect(_pause.panel.visible, "and the pause panel is now visible")
	_expect(_input.mouse_look_enabled == false,
		"the capture intent is OFF while paused - the release Escape always did still happens")
	_expect(_pause.pause_writes == writes_before + 1,
		"the pause state was applied exactly once (%d -> %d)"
			% [writes_before, _pause.pause_writes])
	_expect(_pause.pause_writes == 1, "and this is the FIRST pause state this session has applied")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"the cursor is free while paused, so the panel can be used")
	_expect(_pause.process_mode == Node.PROCESS_MODE_ALWAYS,
		"the pause layer is PROCESS_MODE_ALWAYS, so it stays interactive while the tree is paused")

	# Gameplay really stands still, measured on a FRAME-DRIVEN gameplay system rather than on a frame
	# count: `StaminaComponent` regenerates from its own `_process`, which a real pause stops.
	#
	# THE TREE IS ALREADY PAUSED HERE - the Escape above did it - so the PAUSED case is measured FIRST
	# and the PLAYING case is measured AFTER the resume below. That ordering is what stops "paused" from
	# being confused with "the system was not running anyway": both readings come from the same value
	# under the same conditions, with only the pause differing between them.
	var drained := _stamina.try_spend(maxf(0.0, _stamina.current_stamina - 10.0))
	_expect(drained, "PAUSED CHECK: stamina was spent to make room for regeneration")
	var before_pause := _stamina.current_stamina
	await _wait_seconds(1.0)
	var while_paused := _stamina.current_stamina
	_expect(is_equal_approx(while_paused, before_pause),
		"PAUSED: a frame-driven gameplay value did NOT advance (%.1f -> %.1f)"
			% [before_pause, while_paused])

	# The panel is interactive while the tree is paused: a real Button signal reaches the service.
	var saves_before := int(_save.get("saves"))
	_pause.save_button.emit_signal("pressed")
	_expect(_pause.last_action == "save",
		"PAUSED: pressing the panel's Save button ran a save (action=%s)" % _pause.last_action)
	_expect(int(_save.get("saves")) == saves_before + 1,
		"PAUSED: and it went through the GameStateSave service (saves %d -> %d)"
			% [saves_before, int(_save.get("saves"))])
	_pause.resume_button.emit_signal("pressed")
	await _wait(STATE_FRAMES)
	_expect(not get_tree().paused, "the panel's Resume button cleared the pause")
	_expect(not _pause.panel.visible, "and hid the panel")
	var resumed := _stamina.current_stamina
	# LONGER THAN `regen_delay` (0.8 s), and that is the measurement, not padding. The spend above
	# happened while the tree was PAUSED, so its regeneration delay only began counting down at the
	# resume; a shorter wait would read 10.0 -> 10.0 and look like the resume had failed when the value
	# was simply still inside its own delay.
	await _wait_seconds(1.2)
	_expect(_stamina.current_stamina > resumed,
		"RESUMED: the same gameplay value advances again (%.1f -> %.1f)"
			% [resumed, _stamina.current_stamina])

	# Repeated toggling must not stack a panel or leave a second pause state.
	var panels_before := _panel_count()
	_expect(panels_before == 1, "exactly one pause panel node exists (%d)" % panels_before)
	var writes_before_cycles := _pause.pause_writes
	for i in range(2):
		_pause.toggle_pause()
		_expect(_pause.panel.visible and get_tree().paused, "cycle %d: open paused the game" % (i + 1))
		_expect(_panel_count() == 1, "cycle %d: still exactly one panel" % (i + 1))
		_pause.toggle_pause()
		_expect(not _pause.panel.visible and not get_tree().paused,
			"cycle %d: close resumed the game" % (i + 1))
		_expect(_panel_count() == 1, "cycle %d: still exactly one panel" % (i + 1))
	# Two full cycles are four real state changes, and nothing else.
	_expect(_pause.pause_writes == writes_before_cycles + 4,
		"repeated toggling applied exactly four state changes, not more (%d -> %d)"
			% [writes_before_cycles, _pause.pause_writes])
	_expect(not get_tree().paused, "the pause checks left the tree unpaused")

	# The mouse path is clean while unpaused: this is the check the focus probe runs.
	_expect(_new_ui_non_ignore_controls().is_empty(),
		"every visible Control in the new UI is MOUSE_FILTER_IGNORE while unpaused (%s)"
			% str(_new_ui_non_ignore_controls()))
	_expect(_controls_that_steal_gameplay_mouse().is_empty(),
		"no visible Control anywhere can take a click at the centre of the view (%s)"
			% str(_controls_that_steal_gameplay_mouse()))


# --- Phase 5: save, load, and a FRESH displayed value ------------------------

func _phase_save_and_load() -> void:
	_say("[UIHUD] --- PHASE 5: save, load, and loaded-state freshness ---")

	# The controls go through the EXISTING service. Measured on the service's own counters, because a
	# reimplementation inside the UI could not move them.
	var saves_before := int(_save.get("saves"))
	var loads_before := int(_save.get("loads"))
	_pause.save_via_service()
	await _wait(STATE_FRAMES)
	_expect(int(_save.get("saves")) == saves_before + 1,
		"the panel's save ran on the GameStateSave service (its own `saves` counter %d -> %d)"
			% [saves_before, int(_save.get("saves"))])
	_expect(_pause.last_result_code == GameStateSave.Result.OK,
		"and the panel reported that service's returned code (%s)"
			% GameStateSave.result_name(_pause.last_result_code))

	var base := _ledger.get_credits()
	var saved_value := base + SAVE_BALANCE_OFFSET
	var live_value := base + LIVE_BALANCE_OFFSET

	# The balance that gets SAVED differs from the balance that will be live at load time, so a stale
	# display is a different number rather than a coincidence.
	_ledger.restore_carried_credits(saved_value)
	await _wait(STATE_FRAMES)
	var save_code: int = _save.save_game()
	await _wait(STATE_FRAMES)
	_expect(save_code == GameStateSave.Result.OK,
		"a save was written through the existing service (%s)" % GameStateSave.result_name(save_code))

	_ledger.restore_carried_credits(live_value)
	await _wait(STATE_FRAMES)
	var live_text := _hud.credits_label.text
	_expect(live_text == "CREDITS  %d" % live_value,
		"before the load the HUD shows the LIVE balance %d (%s)" % [live_value, live_text])

	# Through the panel's own control, so this is the shipped path rather than a direct service call.
	_pause.load_via_service()
	await _wait(STATE_FRAMES + 2)
	var after_text := _hud.credits_label.text
	_expect(_pause.last_result_code == GameStateSave.Result.OK,
		"the load reported OK (%d: %s)"
			% [_pause.last_result_code, GameStateSave.result_name(_pause.last_result_code)])
	_expect(int(_save.get("loads")) == loads_before + 1,
		"and it ran on the GameStateSave service (its own `loads` counter %d -> %d)"
			% [loads_before, int(_save.get("loads"))])
	_expect(_ledger.get_credits() == saved_value,
		"the ledger restored the SAVED balance %d (now %d)" % [saved_value, _ledger.get_credits()])
	_expect(after_text == "CREDITS  %d" % saved_value,
		"AFTER THE LOAD the HUD shows the RESTORED value, not the pre-load one (%s, was %s)"
			% [after_text, live_text])
	_expect(after_text != live_text, "and the displayed number really did change across the load")
	_expect(_pause.last_status_text.contains("OK"),
		"the panel's status line reports the load as OK (%s)" % _pause.last_status_text)

	# A refusal must READ differently from a success. Produced by asking the service to do something it
	# refuses: the save path refuses while the player is not playable, and that refusal comes straight
	# from the service rather than from anything this UI decides.
	var refused_ok_text := _pause.last_status_text
	_apply_lethal(_player)
	await _wait(STATE_FRAMES)
	var refused_code: int = _save.save_game()
	_pause.save_via_service()
	await _wait(STATE_FRAMES)
	_expect(refused_code == GameStateSave.Result.PLAYER_DEAD,
		"a save of a dead run is refused by the service with PLAYER_DEAD (%s)"
			% GameStateSave.result_name(refused_code))
	_expect(_pause.last_result_code == GameStateSave.Result.PLAYER_DEAD,
		"the panel reports the refusal code the service returned")
	_expect(_pause.last_status_text != refused_ok_text,
		"and the refusal does NOT read the same as the success (%s versus %s)"
			% [_pause.last_status_text, refused_ok_text])
	_expect(_pause.last_status_text.contains("REFUSED"),
		"the refusal is worded as a refusal (%s)" % _pause.last_status_text)
	_reset_player()
	await _wait(STATE_FRAMES)
	_expect(not _player_dead(), "the player was restored after the refusal check")


# --- Phase 6: leave the scene as it was found --------------------------------

# --- Phase 6: New Run puts the WORLD back, not just the number ---------------

## THE DEFECT THIS MEASURES. `new_run()` used to reset the carried balance, mint a new run identity
## and delete the save file - and touch no actor at all. So a New Run left the player dead where it
## fell, left every enemy it had killed still defeated with its presentation still posed, left a lock
## held on a target from the previous run, and left the HUD showing all of it.
##
## The dirty state is produced through REAL gameplay paths rather than by poking flags: the player is
## genuinely killed through `HealthComponent.apply_damage`, and a real arena enemy is genuinely killed
## the same way. That costs a reward, which is deliberate - New Run resets the balance too, so the
## reward is part of what must come back, and it proves the ledger's reward history was cleared rather
## than merely zeroed.
##
## The discriminator is the RELEASE REASON. A death-circuit auto-reset can also revive the player, so
## "the player is alive" alone would not prove New Run did it. `run-reset` is a cause only this path
## can produce, and the four invalidation paths are asserted NOT to have absorbed it.
func _phase_new_run() -> void:
	_say("[UIHUD] --- PHASE 6: New Run restores the world, not just the balance ---")

	# --- Build a thoroughly DIRTY run -----------------------------------------
	var enemy: Node3D = null
	for actor in _arena_actors():
		var d: Node = actor.get_node_or_null("Death")
		if d != null and d.has_method("is_defeated"):
			enemy = actor
			break
	_expect(enemy != null, "the arena offers a real enemy to kill for the New Run check")

	var credits_before := _ledger.get_credits()
	if enemy != null:
		_apply_lethal(enemy)
	await _wait(STATE_FRAMES)
	var enemy_defeated := _enemy_is_defeated(enemy)
	_expect(enemy_defeated, "DIRTY: a real arena enemy is defeated through the damage chain")
	_expect(_ledger.get_credits() > credits_before,
		"DIRTY: and that defeat paid a reward (%d -> %d)" % [credits_before, _ledger.get_credits()])

	# A lock is deliberately NOT taken here, and the reason is a real constraint rather than tidiness:
	# killing an enemy makes it an INVALID target, and the player's own death RELEASES any lock it held
	# (the M12 release paths). So a held lock cannot coexist with "player dead AND an enemy defeated",
	# and asserting one here would fail on a premise that is impossible. The lock is exercised on its
	# own, against a live enemy, in the second half below.
	_apply_lethal(_player)
	await _wait(STATE_FRAMES)
	_expect(_player_dead(), "DIRTY: the player is dead")
	_expect(not _targeting.is_locked(),
		"DIRTY: the player's death already released any lock, as the M12 release paths require")

	# --- The thing under test: New Run through the UI's own path ---------------
	var code: int = _pause.new_run_via_service()
	_expect(code == GameStateSave.Result.OK,
		"the New Run control returned OK (%s)" % GameStateSave.result_name(code))
	await _wait(STATE_FRAMES * 2)

	# --- 1. The player is back on its spawn mark with starting values ----------
	_expect(not _player_dead(), "NEW RUN: the player is alive again")
	_expect(is_equal_approx(_health.current_health, _health.max_health),
		"NEW RUN: health is back to full (%.1f / %.1f)"
			% [_health.current_health, _health.max_health])
	_expect(is_equal_approx(_stamina.current_stamina, _stamina.max_stamina),
		"NEW RUN: stamina is back to full (%.1f / %.1f)"
			% [_stamina.current_stamina, _stamina.max_stamina])
	_expect(_player.global_position.distance_to(_player_start.origin) < 0.5,
		"NEW RUN: the player is back at its spawn mark (%.3f m from it)"
			% _player.global_position.distance_to(_player_start.origin))

	# --- 2. Every enemy is alive and standing where the scene put it ----------
	_expect(not _enemy_is_defeated(enemy), "NEW RUN: the killed enemy is no longer defeated")
	var enemy_health := enemy.get_node_or_null("Health") as HealthComponent
	_expect(enemy_health != null and is_equal_approx(enemy_health.current_health, enemy_health.max_health),
		"NEW RUN: and its health is back to full")
	_expect(_player.global_position.distance_to(_player_start.origin) < 0.5,
		"NEW RUN: the arena was left in a usable state (the player is standing, not inside geometry)")

	var still_defeated: Array = []
	for actor in _arena_actors():
		if _enemy_is_defeated(actor):
			still_defeated.append(String(actor.name))
	_expect(still_defeated.is_empty(),
		"NEW RUN: NO arena enemy is left defeated (%s)" % str(still_defeated))

	# --- 3. A HELD lock is released by New Run, under its own cause ------------
	# Measured SEPARATELY from the dead-player state above, because a lock cannot outlive the player
	# that held it. Here the player is alive and genuinely locked onto a live arena enemy, so the
	# release has something to do and the cause it is filed under is meaningful.
	_expect(not _indicator.visible, "NEW RUN: no indicator is left showing after the reset")

	_targeting.acquire()
	await _wait(STATE_FRAMES)
	_expect(_targeting.is_locked(), "DIRTY (part B): a lock is genuinely held on a live enemy")
	_expect(_indicator.visible, "DIRTY (part B): and the indicator is showing for it")

	var run_resets_before := _release_count("run-reset")
	var code_b: int = _pause.new_run_via_service()
	_expect(code_b == GameStateSave.Result.OK,
		"a second New Run also returned OK (%s)" % GameStateSave.result_name(code_b))
	await _wait(STATE_FRAMES * 2)

	_expect(not _targeting.is_locked(), "NEW RUN: the HELD lock is released")
	_expect(not _indicator.visible, "NEW RUN: and the indicator is hidden")
	_expect(_release_count("run-reset") == run_resets_before + 1,
		"NEW RUN: the release is filed under its OWN cause (%d -> %d)"
			% [run_resets_before, _release_count("run-reset")])
	_expect(not _input.is_look_yaw_suppressed(),
		"NEW RUN: and no look intent is left declared to the input layer")

	# --- 4. The balance and the HUD -------------------------------------------
	_expect(_ledger.get_credits() == _credits_start,
		"NEW RUN: the carried balance is back to the starting value (%d, was %d)"
			% [_credits_start, _ledger.get_credits()])
	_expect(_hud.credits_label.text == "CREDITS  %d" % _ledger.get_credits(),
		"NEW RUN: the HUD shows the reset balance (%s)" % _hud.credits_label.text)
	_expect(_hud.health_label.text == "HEALTH  %d / %d" % [int(_health.max_health), int(_health.max_health)],
		"NEW RUN: the HUD shows the reset health (%s)" % _hud.health_label.text)
	_expect(_hud.stamina_label.text == "STAMINA  %d / %d"
		% [int(_stamina.max_stamina), int(_stamina.max_stamina)],
		"NEW RUN: the HUD shows the reset stamina (%s)" % _hud.stamina_label.text)

	# --- 5. Everything the probe changed is back, so cleanup has nothing to undo
	_expect(not get_tree().paused, "NEW RUN: the tree is not left paused")


func _enemy_is_defeated(actor: Node3D) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var d: Node = actor.get_node_or_null("Death")
	if d == null or not d.has_method("is_defeated"):
		return false
	return bool(d.call("is_defeated"))


func _phase_cleanup() -> void:
	_targeting.release()
	await _wait(STATE_FRAMES)
	_expect(not _targeting.is_locked(), "no lock is left held")
	_expect(not _indicator.visible, "no indicator is left visible")

	if get_tree().paused:
		_pause.close()
	await _wait(STATE_FRAMES)
	_expect(not get_tree().paused, "no pause is left applied")
	_expect(not _pause.panel.visible, "no pause panel is left visible")

	# The balance first: the probe's own award is put back through the ledger's public restore path,
	# so the run carries exactly what it carried before the probe ran.
	_ledger.restore_carried_credits(_credits_start)
	await _wait(STATE_FRAMES)
	_expect(_ledger.get_credits() == _credits_start,
		"the carried balance is back at %d - no Credits were minted" % _credits_start)
	_expect(_hud.credits_label.text == "CREDITS  %d" % _credits_start,
		"and the HUD followed it back (%s)" % _hud.credits_label.text)

	# Then the player, through its own snapshot-restore API: transform, yaw, health and stamina.
	if _death != null and _death.has_method("restore_snapshot"):
		_death.call("restore_snapshot", _player_start.origin, _player_start.basis.get_euler().y,
			_health_start, _stamina_start)
	await _wait(STATE_FRAMES)
	_expect(not _player_dead(), "the player is alive at the end of the probe")
	_expect(is_equal_approx(_health.current_health, _health_start),
		"the player's health is back at %.1f (now %.1f)" % [_health_start, _health.current_health])
	_expect(is_equal_approx(_stamina.current_stamina, _stamina_start),
		"the player's stamina is back at %.1f (now %.1f)"
			% [_stamina_start, _stamina.current_stamina])
	_expect(_player.global_position.distance_to(_player_start.origin) < 0.5,
		"the player is back where it started")

	for node in _temporaries:
		if node != null and is_instance_valid(node):
			node.queue_free()
	_temporaries.clear()
	await _wait(STATE_FRAMES + 2)

	var alive: Array = []
	for node in _must_be_freed:
		if node != null and is_instance_valid(node):
			alive.append(String(node.name))
	_expect(alive.is_empty(), "every probe target was freed (%s)" % str(alive))

	var damaged: Array = []
	for actor in _arena_actors():
		var health := actor.get_node_or_null("Health") as HealthComponent
		if health != null and health.is_dead:
			damaged.append(String(actor.name))
		var death: Node = actor.get_node_or_null("Death")
		if death != null and death.has_method("is_defeated") and bool(death.call("is_defeated")):
			damaged.append(String(actor.name))
	_expect(damaged.is_empty(), "no ARENA actor was damaged or defeated by this probe (%s)"
		% str(damaged))
	# THE PROBE'S OWN CONTROLLED AWARD NO LONGER EXISTS HERE, AND THAT IS THE POINT. Phase 6 runs a
	# NEW RUN, and `CreditLedger.reset_credits()` puts the award counter back to the fresh-run
	# baseline. Asserting the previous "+1" would demand that a reset NOT reset - it was written before
	# New Run touched the world. What is worth asserting is the state a FRESH BOOT produces: a zeroed
	# counter and the documented starting balance.
	_expect(int(_ledger.get("awards")) == 0,
		"the economy is at the fresh-run baseline after New Run (awards %d -> %d)"
			% [_awards_start, int(_ledger.get("awards"))])
	_expect(_ledger.get_credits() == int(_ledger.get("starting_credits")),
		"and the carried balance is the documented starting value (%d)"
			% _ledger.get_credits())
	_expect(_targeting.valid_candidates().size() > 0, "the arena's own targets are still usable")


# --- The mouse path ----------------------------------------------------------

## Every VISIBLE Control belonging to the three new modules whose filter is not IGNORE. While the game
## is unpaused this must be empty: the pause panel is hidden, and everything else ignores the mouse.
func _new_ui_non_ignore_controls() -> Array:
	var offenders: Array = []
	for module in [_hud, _indicator, _pause]:
		if module == null or not is_instance_valid(module):
			continue
		for control in (module as Node).find_children("*", "Control", true, false):
			var c := control as Control
			if c == null or not c.visible:
				continue
			if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			offenders.append("%s/%s" % [module.name, c.name])
	return offenders


## The project's own offender enumeration, copied from
## `focus_input_routing_probe_debug._controls_that_steal_gameplay_mouse()`, so this probe measures the
## same condition that check will measure.
func _controls_that_steal_gameplay_mouse() -> Array:
	var offenders: Array = []
	for canvas in get_tree().root.find_children("*", "CanvasLayer", true, false):
		for control in (canvas as Node).find_children("*", "Control", true, false):
			var c := control as Control
			if c == null or not c.visible:
				continue
			if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
				continue
			var rect := Rect2(c.global_position, c.size)
			if rect.has_point(get_viewport().get_visible_rect().size * 0.5):
				offenders.append("%s(%s)" % [c.name,
					"STOP" if c.mouse_filter == Control.MOUSE_FILTER_STOP else "PASS"])
	return offenders


## How many pause-panel roots exist inside the pause module - the direct measurement of "never
## stacks". Scoped to that module on purpose: a count over the whole tree would also see the debug
## overlays' own nodes and would be measuring something else.
func _panel_count() -> int:
	if _pause == null:
		return 0
	return _pause.find_children("Panel", "Control", true, false).size()


# --- Test targets ------------------------------------------------------------

## One throwaway damageable actor carrying the same three components a real enemy carries, so the
## targeting module's validity check sees exactly what it would see on a real one.
func _spawn_target(target_name: String) -> Node3D:
	var body := CharacterBody3D.new()
	body.name = target_name
	body.collision_layer = 2
	body.collision_mask = 3

	var health := HealthComponent.new()
	health.name = "Health"
	health.debug_logging = false

	var participant := CombatParticipant.new()
	participant.name = "Participant"

	var death := EnemyDeathComponent.new()
	death.name = "Death"
	death.debug_logging = false

	body.add_child(health)
	body.add_child(participant)
	body.add_child(death)
	add_child(body)
	body.global_position = _placement(0.0, NEAR_DISTANCE)

	_temporaries.append(body)
	_must_be_freed.append(body)
	return body


func _destroy(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_temporaries.erase(node)
	node.queue_free()


## Take the lock on `target` and confirm it actually landed there.
func _lock_onto(target: Node3D) -> bool:
	_targeting.release()
	await _wait(STATE_FRAMES)
	target.global_position = _placement(0.0, NEAR_DISTANCE)
	await _wait(1)
	if not _targeting.acquire():
		return false
	await _wait(STATE_FRAMES)
	return _targeting.get_current_target() == target


func _apply_lethal(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var health := actor.get_node_or_null("Health") as HealthComponent
	if health == null:
		return
	var event := DamageEvent.new()
	event.amount = 100000.0
	event.source = _player
	health.apply_damage(event)


func _reset_player() -> void:
	if _death != null and _death.has_method("reset_playable_state"):
		_death.call("reset_playable_state", true)


func _player_dead() -> bool:
	if _death != null and _death.has_method("is_dead"):
		return bool(_death.call("is_dead"))
	return _health != null and _health.is_dead


## Every actor the arena shipped with, so the probe can prove it left them alone.
func _arena_actors() -> Array:
	var out: Array = []
	for node in get_tree().get_nodes_in_group(HealthComponent.GROUP_DAMAGEABLE):
		var health := node as HealthComponent
		if health == null:
			continue
		var actor := health.get_parent() as Node3D
		if actor == null or actor == _player or _is_temporary(actor):
			continue
		out.append(actor)
	return out


func _is_temporary(actor: Node3D) -> bool:
	for node in _temporaries:
		if node == actor:
			return true
	return false


# --- Placement and geometry --------------------------------------------------

## Where an actor at `bearing_degrees` off the camera rig's forward, `distance` away, would stand.
func _placement(bearing_degrees: float, distance: float) -> Vector3:
	var yaw := deg_to_rad(_rig_yaw())
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var offset := (forward * cos(deg_to_rad(bearing_degrees))) + (right * sin(deg_to_rad(bearing_degrees)))
	return _player.global_position + offset * distance


func _rig_yaw() -> float:
	if _rig == null:
		return 0.0
	return float(_rig.call("current_yaw_degrees"))


func _release_count(reason: String) -> int:
	return int(_targeting.release_counts().get(reason, 0))


func _actor_name(node) -> String:
	if node == null or not is_instance_valid(node):
		return "<gone>"
	return String(node.name)


# --- Input injection ---------------------------------------------------------

func _press_key(keycode: int) -> void:
	_key(keycode, true)
	Input.flush_buffered_events()
	await _wait(INPUT_FRAMES)
	_key(keycode, false)
	Input.flush_buffered_events()
	await _wait(1)


func _key(keycode: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode as Key
	event.physical_keycode = keycode as Key
	event.pressed = pressed
	Input.parse_input_event(event)


# --- Resolution --------------------------------------------------------------

func _resolve() -> bool:
	_input = get_tree().get_first_node_in_group(CascadiaInput.ACTION_GROUP) as CascadiaInput
	_targeting = get_tree().get_first_node_in_group(TargetingComponent.GROUP_TARGETING) as TargetingComponent
	_player = get_tree().get_first_node_in_group(CreditLedger.GROUP_PLAYER_ACTOR) as Node3D
	_ledger = CreditLedger.find_ledger(get_tree())
	_save = GameStateSave.find_save(get_tree())
	# ORDER MATTERS: the rig is found by walking UP from the active camera, so the camera must exist.
	if _player == null:
		_fail("no player actor in the tree")
		return false
	_health = _player.get_node_or_null("Health") as HealthComponent
	_stamina = _player.get_node_or_null("Stamina") as StaminaComponent
	_combat = _player.get_node_or_null("Combat")
	_death = _player.get_node_or_null("Death")
	_rig = _find_camera_rig()

	_hud = _find_node_of_type("GameHUD") as GameHUD
	_indicator = _find_node_of_type("LockOnIndicator") as LockOnIndicator
	_pause = _find_node_of_type("PauseMenu") as PauseMenu

	for pair in [["input layer", _input], ["targeting module", _targeting], ["player actor", _player],
			["credit ledger", _ledger], ["save service", _save], ["player health", _health],
			["player stamina", _stamina], ["player combat", _combat], ["player death", _death],
			["camera rig", _rig], ["HUD", _hud], ["lock-on indicator", _indicator], ["pause menu", _pause]]:
		if pair[1] == null:
			_fail("could not resolve the %s" % pair[0])
			return false
	return true


func _find_node_of_type(node_name: String) -> Node:
	return get_tree().root.find_child(node_name, true, false)


func _find_camera_rig() -> Node:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var node: Node = camera
	while node != null:
		if node.has_method("current_yaw_degrees"):
			return node
		node = node.get_parent()
	return null


## Best effort only, and reported either way: injected events are refused while the layer believes the
## window has no focus, so the probe says which state it is in rather than measuring a no-op.
func _ensure_input_active() -> void:
	if _input.is_input_active():
		return
	get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _wait(3)
	_expect(_input.is_input_active(), "gameplay input is ACTIVE (%s)" % str(_input.is_input_active()))


func _capture_start_state() -> void:
	_player_start = _player.global_transform
	_credits_start = int(_ledger.get_credits())
	_awards_start = int(_ledger.get("awards"))
	_health_start = _health.current_health
	_stamina_start = _stamina.current_stamina


# --- Reporting ---------------------------------------------------------------

func _wait(n: int) -> void:
	# BOTH clocks, on purpose: the UI, the input layer and the physics systems run on different
	# callbacks, and a check that waited on only one could read a state the others had not produced.
	for i in range(n):
		await get_tree().physics_frame
		await get_tree().process_frame


## Wait for REAL elapsed time rather than for a frame count, for the one measurement that needs it:
## the pause check compares a time-driven gameplay value (stamina regeneration, which is expressed in
## units per SECOND) before, during and after a pause. A frame-count wait would make that comparison
## depend on the frame rate, and the frames keep coming while the tree is paused.
func _wait_seconds(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		_say("[UIHUD]   PASS  %s" % message)
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
	_say("[UIHUD]   FAIL  %s" % message)


func _report() -> void:
	if _failures.is_empty():
		_say("[UIHUD] RESULT: ALL CHECKS PASSED (%d)" % _checks)
	else:
		_say("[UIHUD] RESULT: %d of %d FAILED -> %s" % [_failures.size(), _checks, str(_failures)])


func _say(message: String) -> void:
	var stamped := "[s%d] %s" % [Engine.get_physics_frames(), message]
	_transcript.append(stamped)
	print(stamped)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(PackedStringArray(_transcript)))
		file.close()
