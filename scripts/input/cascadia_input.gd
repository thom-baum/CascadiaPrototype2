class_name CascadiaInput
extends Node
## Cascadia's input layer (Milestone 0).
##
## Responsibilities:
## - Own every raw device read (mouse motion, mouse capture) in one place.
## - Expose semantic queries keyed by GameActions names.
## - Resolve the controller's contextual Circle behaviour: tap -> DODGE,
##   hold -> SPRINT, while keeping the two gameplay actions separate.
## - Buffer discrete presses briefly so a press is never lost between frames.
##
## It does NOT move anything, damage anything, or know what an attack is.
##
## Gameplay systems poll this node; nothing here decides what a game action means.
## If this node is missing or an action is unbound, gameplay simply sees no input
## rather than crashing.

enum MobilityState { IDLE, PENDING, SPRINTING }

const ACTION_GROUP := &"cascadia_input"

## How long a discrete press stays available to gameplay after it happens.
const INPUT_BUFFER_TIME := 0.15
## Circle press released before this duration counts as a tap -> DODGE.
const MOBILITY_TAP_MAX := 0.20
## Circle held for this duration becomes a hold -> SPRINT.
const MOBILITY_HOLD_MIN := 0.20
## Right stick look is converted to pixel-equivalent units so the camera can use
## one sensitivity value for both mouse and stick.
const LOOK_STICK_PIXELS_PER_SECOND := 420.0
const LOOK_STICK_DEADZONE := 0.18
const MOVE_DEADZONE := 0.15
## How many consecutive frames after regaining focus this layer keeps re-asking the host for the
## window and the cursor. The focus event fires the moment the host hands focus OVER, and a host can
## need a beat before it will act on a request made that early - so the request is repeated for a few
## frames and then stops. Bounded on purpose: this is a settle window, not a per-frame takeover, so
## the game can never fight the host for the foreground.
const FOCUS_REASSERT_FRAMES := 8

## Mouse look is only applied while the cursor is captured.
var mouse_look_enabled := true

var _buffers: Dictionary = {}
var _missing_actions: Array = []

## One tap/hold source's live state. BOTH the controller's face button and the
## keyboard's sprint key run through the SAME resolver with the SAME thresholds,
## so hold -> SPRINT and quick release -> DODGE behave identically on both
## devices. They are tracked separately only so that pressing both at once cannot
## confuse one state machine; nothing else differs between them.
var _pad_source := {"state": MobilityState.IDLE, "timer": 0.0, "sprint": false}
var _key_source := {"state": MobilityState.IDLE, "timer": 0.0, "sprint": false}
var _sprint_active := false

var _look_accum := Vector2.ZERO
var _mouse_look_accum := Vector2.ZERO
var _suppress_presses := false


func _enter_tree() -> void:
	add_to_group(ACTION_GROUP)


func _ready() -> void:
	_validate_actions()
	for action in GameActions.BUFFERED_ACTIONS:
		_buffers[action] = 0.0
	set_mouse_look(true)


## How many idle frames this layer has actually processed. Diagnostic, and load-bearing for ONE
## question a probe cannot otherwise answer: whether `_process` is still being CALLED. A node whose
## `is_processing()` reports true can still be skipped, so "is it enabled" is not the same question
## as "did it run".
var process_ticks := 0


func _process(delta: float) -> void:
	process_ticks += 1
	# FIRST, before anything reads input this frame: bring the focus belief up to date, then make
	# sure the cursor is where gameplay says it should be. Both are OWNERSHIP work - see
	# _refresh_focus and _keep_mouse_captured.
	_refresh_focus()
	_keep_clock_running()
	_keep_mouse_captured()
	_reassert_after_focus()
	# A window the player is not looking at is not the game's input. MEASURED DEFECT: with no focus
	# rule at all, mouse motion arriving while unfocused still turned the camera, a key held across
	# the change kept driving movement, and the half-finished motion was applied on the way back in.
	# Nothing advances while suspended - not mobility, not buffers, not look.
	if not is_input_active():
		return
	_update_mobility(delta)
	_update_buffers(delta)
	_update_look(delta)
	# A click that recaptures the cursor must not also fire an attack this frame.
	_suppress_presses = false


## Presence recovery, and it deliberately runs BEFORE the GUI so nothing can consume it.
##
## WHY IT EXISTS. A suspension must never be a state the player cannot leave. The focus-in
## notification is the normal way out, but a focus report that never flips back - or a host that does
## not deliver the notification - would otherwise trap the game, because the click that should
## restore capture would be swallowed by the very gate that needs clearing. That is the reported
## "clicking the window does not restore mouse capture", so the escape hatch cannot live behind the
## gate. `_input` runs before GUI handling, so not even a debug panel can eat it.
##
## ONLY A DELIBERATE PRESS COUNTS: a key press or a mouse-button press. Mouse MOTION deliberately
## does not, because motion must stay inert while suspended - it is the reported defect, and it can
## arrive from the host without any interaction at all.
##
## This observes only. It accumulates nothing; `_unhandled_input` stays the single place look is
## gathered, so no event is ever counted twice.
func _input(event: InputEvent) -> void:
	if _focus_lost and _event_proves_presence(event):
		# The player is demonstrably at this window: they just pressed something in it. Resuming
		# here re-asserts the declared capture and drops the half-finished input, so movement and
		# look come straight back without an unrelated key press or a second click.
		_apply_focus(true)
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_recover_capture_on_press()


## Take the cursor back ON THE CLICK ITSELF, and do not let that same click become a swing.
##
## WHY HERE AND NOT IN THE PER-FRAME KEEPER. `_keep_mouse_captured()` asks the host for the pointer
## from a frame callback, and an embedded or browser host is entitled to refuse that: pointer lock is
## a USER-GESTURE permission in those environments, so a request made outside a real input event can
## be dropped while looking successful from inside the game. That is the reported state after a
## return from Alt-Tab - the camera responds and yet the cursor stays free. A mouse press is the
## gesture such a host wants, and `_input` runs inside that call stack, so this is the one place the
## request is made in the context that can actually grant it.
##
## It is deliberately NOT gated on the focus belief. That belief can be wrong in either direction,
## and recovering from exactly that is the point: a click that reached this game IS the player
## telling us they are here.
##
## The press is then SUPPRESSED as a gameplay action, for the same reason the Escape-recapture rule
## suppresses it - a player clicking to get their cursor back is asking for the window, not swinging.
## MEASURED CONSEQUENCE of not doing this: the refocus click reached `PlayerCombat` as a light
## attack, and a committed attack owns the body, so the player could not walk until it finished.
func _recover_capture_on_press() -> void:
	var intent_off := not mouse_look_enabled
	var believed_free := Input.mouse_mode != Input.MOUSE_MODE_CAPTURED

	# THE REQUEST IS UNCONDITIONAL, AND THAT IS HALF THE FIX. It deliberately does NOT return early
	# when the engine already believes the cursor is captured. MEASURED on this host: pointer lock can
	# be released while `Input.mouse_mode` still reads CAPTURED, so an early return skipped the ONLY
	# re-request made inside a context the host can actually grant - leaving a free cursor with no way
	# back. Re-requesting capture that is already held costs nothing; failing to request when the
	# belief is wrong is the reported failure.
	if intent_off:
		# Escape deliberately released the cursor; a click is the documented way back.
		mouse_look_enabled = true
	_force_capture()
	_take_window_focus()
	capture_requests_on_press += 1

	# SUPPRESS ONLY WHILE THERE IS SOMETHING TO RECOVER, AND ONLY ONCE PER LOSS - this is the other
	# half of the fix. The earlier version suppressed EVERY press while `Input.mouse_mode` was not
	# CAPTURED. While the host keeps refusing capture that condition never clears, so every attack
	# click was eaten as a "recovery" click and no attack ever began - MEASURED as the reported
	# "attack inputs are accepted, no attack phase begins". The first press after a loss asks for the
	# window and must not swing; presses after that behave normally, so the player is never left
	# unable to attack just because capture could not be re-taken.
	if intent_off or (believed_free and not _capture_recovery_attempted):
		_capture_recovery_attempted = true
		_suppress_presses = true
		capture_reasserted_by_click += 1


## Re-apply gameplay's pointer lock as a REAL state change.
##
## WHY THIS IS NOT JUST `Input.mouse_mode = CAPTURED`, and this is the reported defect. Assigning the
## value the engine ALREADY holds is a no-op: from the engine's point of view nothing changed, so it
## asks the host for nothing. MEASURED on this host: pointer lock can be dropped at the OS level while
## `Input.mouse_mode` still reads CAPTURED. In that state the ordinary write is silently ignored, which
## is exactly the reported failure - the camera still responds to motion, and yet the cursor stays free
## no matter how many times the player clicks.
##
## Stepping to VISIBLE first makes the following CAPTURED a genuine TRANSITION, which is what makes the
## engine actually re-apply pointer lock. It costs at most one frame of cursor visibility, and it is
## only ever reached from a real gesture or a real focus change - never per frame - so it cannot flicker.
func _force_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Ask the window for KEYBOARD focus, which is a separate thing from pointer capture and is the
## reported half of the failure that no amount of mouse handling can fix.
##
## WHY THIS EXISTS. MEASURED from the retarget probe: a suspended input layer cannot be what blocks
## movement, because movement and attacks read the SAME `is_input_active()` gate - and attacks work in
## the reported state. `_read_wish_direction()` only zeroes movement when the actor is dead, when a
## committed action owns the body, or when `get_move_vector()` returns zero. The first two are ruled
## out by the same measurement (attacks start and reach ACTIVE), which leaves `get_move_vector()` -
## built from `Input.get_vector()` over the MOVE_* ACTIONS. Those actions only carry a value if the
## KEY EVENTS REACH THIS GAME. A window that received the click (so attacks fire) and delivers mouse
## motion (so the camera turns) can still be missing keyboard focus in an embedded host, and that
## produces exactly the reported trio: camera yes, attacks yes, movement no.
##
## `grab_focus()` is the standard "click retargets the game" behaviour every other game has, and it is
## requested from the same real input event as the capture, for the same user-gesture reason. Guarded
## only against a missing window, because a headless or hostless context has nothing to ask.
##
## THE REQUEST IS UNCONDITIONAL ON THE FOCUS BELIEF, and that is deliberate - the same reasoning the
## capture request already uses, applied to the other half of the recovery. The earlier version returned
## early when `window.has_focus()` was true, and MEASURED against this host that belief is exactly the
## one that can be WRONG while the game still cannot see the keyboard:
##
##     the engine reports focus, mouse motion and mouse buttons reach the game,
##     and KEYBOARD events do not.
##
## Because only the keyboard-driven systems are affected, that state produces a very specific
## signature: the camera turns (mouse motion), light and heavy attacks fire (mouse buttons) - and the
## player will not walk, because MOVEMENT is the only gameplay path that needs the keyboard. An early
## return keyed on the belief therefore skipped the ONE call that could hand the game its keyboard.
## The engine's own `grab_focus()` is a no-op when the window is already focused, so asking
## unconditionally costs nothing and is the only version that can recover a wrong belief.
##
## It is still never called per frame - only from a real gesture (a click) or a real focus change - so
## it cannot fight the host for the foreground.
func _take_window_focus() -> void:
	var window := get_window()
	if window == null:
		return
	window.grab_focus()


## True when an event could only have happened if the player was interacting with THIS window. A
## press that reached the game was aimed at the game - clicks and keys follow the focused window -
## so this cannot fire from whatever application the player switched to.
func _event_proves_presence(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false


func _unhandled_input(event: InputEvent) -> void:
	# A suspended layer sees nothing. The events still ARRIVE at the engine while unfocused - that is
	# precisely what the measured defect was - so the refusal has to live here, not in the camera.
	# `_input` has already run for this event and would have resumed the layer if it were a
	# deliberate press, so reaching this line suspended means this event is one to ignore.
	if not is_input_active():
		return

	if event is InputEventMouseMotion:
		if mouse_look_enabled:
			_mouse_look_accum += event.relative
		return

	if event is InputEventMouseButton and event.pressed and not mouse_look_enabled:
		set_mouse_look(true)
		_suppress_presses = true
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(&"ui_cancel"):
		set_mouse_look(false)


# --- Semantic queries -------------------------------------------------------

## Movement intent as Vector2(x = right, y = forward). Length is clamped to 1.
func get_move_vector() -> Vector2:
	# No focus, no movement. The engine releases held keys when the window loses focus, but that is
	# engine behaviour this project should not depend on: a key that stays down across a focus change
	# must not keep walking the player while they are in another window.
	if not is_input_active():
		return Vector2.ZERO
	var raw := Input.get_vector(
		GameActions.MOVE_LEFT,
		GameActions.MOVE_RIGHT,
		GameActions.MOVE_FORWARD,
		GameActions.MOVE_BACKWARD,
		MOVE_DEADZONE
	)
	return Vector2(raw.x, -raw.y)


## Relative look delta for this frame, in pixel-equivalent units. Consumes the
## accumulated delta, so exactly one consumer per frame.
func get_look_delta() -> Vector2:
	# Motion earned in another window must never be spent on the first frame back, and none may be
	# produced while suspended. Clearing on BOTH sides of the transition - here, and when the focus
	# changes - means the camera cannot be moved by a delta the player did not make in this window.
	if not is_input_active():
		_look_accum = Vector2.ZERO
		_mouse_look_accum = Vector2.ZERO
		return Vector2.ZERO
	var delta := _look_accum
	_look_accum = Vector2.ZERO
	return delta


## The look delta WITHOUT consuming it, for a display-only reader.
##
## WHY THIS EXISTS - the defect it fixes, and it was a real one. `get_look_delta()` deliberately
## CONSUMES the delta so that exactly ONE gameplay consumer per frame can spend it. A diagnostic that
## calls it is therefore not a passive reader at all: it BECOMES the consumer, and whoever runs later
## in the frame reads ZERO. MEASURED: `InputDebugOverlay` is a CanvasLayer sibling ordered BEFORE the
## world in `main.tscn`, so its per-frame display read consumed the motion every single frame and
## `ThirdPersonCamera` never turned - mouse look was dead while movement, attacks and dodge all worked.
##
## Read-only by contract: this may be used to DISPLAY the pending delta and must never be used to move
## anything, because two readers of the same unconsumed value is exactly the ambiguity the consuming
## accessor exists to prevent.
func peek_look_delta() -> Vector2:
	if not is_input_active():
		return Vector2.ZERO
	return _look_accum


## Resolved sprint state: keyboard sprint key OR controller Circle hold.
func is_sprinting() -> bool:
	return _sprint_active and is_input_active()


## Remaining buffer time for a discrete action. Used by diagnostic tooling.
func buffer_time(action: StringName) -> float:
	return _buffers.get(action, 0.0)


## Consume a buffered discrete press. Returns true at most once per press.
func consume(action: StringName) -> bool:
	if GameActions.is_reserved(action):
		return false
	# A suspended layer has no actions to give: gameplay must not receive a press that happened in
	# another window, nor one buffered in the frame before the window lost focus.
	if not is_input_active():
		return false
	if float(_buffers.get(action, 0.0)) > 0.0:
		_buffers[action] = 0.0
		return true
	return false


func consume_dodge() -> bool:
	return consume(GameActions.DODGE)


func consume_light_attack() -> bool:
	return consume(GameActions.LIGHT_ATTACK)


func consume_heavy_attack() -> bool:
	return consume(GameActions.HEAVY_ATTACK)


func consume_parry() -> bool:
	return consume(GameActions.PARRY)


func consume_critical() -> bool:
	return consume(GameActions.CRITICAL)


func consume_quick_item() -> bool:
	return consume(GameActions.QUICK_ITEM)


func consume_interact() -> bool:
	return consume(GameActions.INTERACT)


func consume_lock_on() -> bool:
	return consume(GameActions.LOCK_ON)


## The arena restart. A system action, still read through this layer like every
## other semantic action, so the reset path never reads a raw key.
func consume_restart() -> bool:
	return consume(GameActions.RESTART)


## True while the semantic action is held. Reserved actions always report false.
func is_action_held(action: StringName) -> bool:
	if GameActions.is_reserved(action) or not InputMap.has_action(action):
		return false
	if not is_input_active():
		return false
	return Input.is_action_pressed(action)


## True on the frame the semantic action was pressed.
func is_action_pressed_now(action: StringName) -> bool:
	if GameActions.is_reserved(action) or not InputMap.has_action(action):
		return false
	if not is_input_active():
		return false
	return Input.is_action_just_pressed(action)


## Longest press that still resolves as a Dodge, in seconds. Exposed so tooling and
## a future rebinding UI can read the rule instead of hardcoding it.
func command_sprint_tap_max() -> float:
	return MOBILITY_TAP_MAX


## Shortest hold that resolves as a Sprint, in seconds.
func command_sprint_hold_min() -> float:
	return MOBILITY_HOLD_MIN


func mobility_state_name() -> String:
	return _source_state_name(_pad_source)


## The keyboard sprint key's tap/hold state. Separate from the controller's only
## so tooling can show which device is mid-decision; both resolve identically.
func sprint_key_state_name() -> String:
	return _source_state_name(_key_source)


func _source_state_name(source: Dictionary) -> String:
	match int(source["state"]):
		MobilityState.PENDING:
			return "PENDING"
		MobilityState.SPRINTING:
			return "SPRINTING"
		_:
			return "IDLE"


## Actions listed in GameActions that are missing from the project InputMap.
func missing_actions() -> Array:
	return _missing_actions


func set_mouse_look(enabled: bool) -> void:
	mouse_look_enabled = enabled
	if not enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	# Capture is granted only while the game's window holds focus. Asking for a captured cursor from
	# a window the player is not looking at is how the game used to take the pointer back from
	# whatever else the user was doing.
	if is_input_active():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Throttle for the re-assert report, so a host that cannot grant capture cannot flood the log.
var _capture_logged_msec := 0


## Re-assert capture whenever gameplay still WANTS it.
##
## WHY THIS EXISTS - the defect it fixes. `set_mouse_look(true)` used to be a ONE-SHOT side effect:
## it ran at _ready() and capture was afterwards only ever re-acquired by a mouse click. Nothing
## owned the state, so NOTHING ever noticed when capture was LOST - and capture can be lost without
## this project doing anything at all: the host window taking focus, a dropped pointer lock in an
## embedded or browser view, the OS releasing the cursor. When that happened the game was left with
## a free cursor and no way back on its own, which is the reported failure - mouse un-captured and
## the game unplayable.
##
## Capture is not a one-off command; it is a STATE gameplay declares, and the layer that owns the
## mouse keeps that state true. The gate is `mouse_look_enabled`, which remains the ONLY thing that
## decides the intent: Escape still sets it false and this never fights that decision, and nothing
## here forces capture on a game that has asked for the cursor to be free.
## Throttle for the clock-resume report.
var _clock_logged_msec := 0
## How many times this layer had to put a RUNNING clock back. It is the measurement that decides
## whether a frozen-clock state is the game's fault or the host's: this layer re-asserts the clock at
## the top of every frame, so a count that keeps climbing means something OUTSIDE is stopping it again
## every frame and no in-game code can win. A count of zero with a stopped clock means this layer is
## not running at all.
var clock_resumes := 0


## Re-assert a RUNNING clock when the tree is NOT paused but the clock has been stopped from outside.
##
## WHY THIS EXISTS - the measured defect. After a load this project was observed in exactly this
## state, and it is the reported "the game stops after F9":
##
##     SceneTree.paused == false    Engine.time_scale == 0.0    window focus == true
##
## With a zero time scale the frame loop keeps ticking while every delta-driven system stands
## still - movement, stamina regeneration, and every attack phase - so the game LOOKS alive (frames
## render, nodes report themselves as processing, the tree is not paused) and is completely
## unplayable. Nothing in Cascadia writes `Engine.time_scale`: every occurrence in the project is a
## diagnostic READING it. A zero scale with an unpaused tree is therefore not a state this game can
## enter on its own, and a game that never pauses by scale must not be silently frozen by one.
func _keep_clock_running() -> void:
	if Engine.time_scale > 0.0:
		return
	if get_tree() != null and get_tree().paused:
		return
	Engine.time_scale = 1.0
	# Counted OUTSIDE the print throttle: the throttle limits the log, not the measurement, and the
	# count is the evidence.
	clock_resumes += 1
	var now := Time.get_ticks_msec()
	if now - _clock_logged_msec >= 1000:
		_clock_logged_msec = now
		print("[INPUT] clock resumed: time_scale had been stopped externally while the tree was NOT paused")


func _keep_mouse_captured() -> void:
	if not mouse_look_enabled:
		return
	# FOCUS GATE - the deliberate opposite of what this keeper did during the F9 investigation, and
	# the earlier reasoning is NOT discarded, it is satisfied a different way. That pass removed the
	# gate because the embedded window can lose focus for a moment and the gate then refused to put
	# the cursor back, leaving the game unplayable. That failure is real and is not reintroduced: the
	# gate below is re-evaluated EVERY FRAME from the engine's own live focus report, and the focus-in
	# path re-asserts capture immediately, so the cursor is re-taken on the first frame after the
	# window regains focus - with no click required and no way for the gate to stay stuck closed.
	#
	# The gate is needed because the ungated keeper did the opposite damage, which is the reported
	# defect: with no focus rule anywhere in the project, the game re-grabbed the cursor every frame
	# while the player was in another window, `mouse_look_enabled` stayed true, and mouse motion kept
	# turning the camera. Capture is gameplay's declared INTENT; whether the game may hold the
	# pointer at this instant is a separate question, and the answer is "only while it is focused".
	if not is_input_active():
		capture_held_while_unfocused += 1
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Capture is CONFIRMED HELD, so any earlier failed recovery attempt is over: the next press is
		# an ordinary attack press again, and can be suppressed only if capture is lost anew.
		_capture_recovery_attempted = false
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Reported, because a re-assert means capture was LOST, and that moment is the physical failure
	# made visible. Throttled so a host that cannot grant capture cannot flood the log.
	var now := Time.get_ticks_msec()
	if now - _capture_logged_msec >= 1000:
		_capture_logged_msec = now
		print("[INPUT] mouse capture re-asserted (gameplay still wants it captured)")


# --- Window focus -----------------------------------------------------------

## True while gameplay input is suspended because the game's window does not hold focus.
##
## Set from the focus notifications AND recomputed from the engine's own live report every frame, so
## it cannot stay stuck: if a notification is ever missed, `_refresh_focus()` corrects the belief on
## the next frame. That is what guarantees the player can never be left without control, which is the
## risk a focus gate has to answer for.
var _focus_lost := false

## How many focus transitions this layer has handled, and how many capture re-asserts it refused
## because the window was not focused. Diagnostics: they prove the notifications ARRIVED and the gate
## actually engaged, instead of leaving that to be inferred from a symptom.
var focus_lost_count := 0
var focus_gained_count := 0
var capture_held_while_unfocused := 0
## Frames left in the settle window opened by a focus GAIN. While it is non-zero both ownership
## requests are repeated; see `_reassert_after_focus()`.
var _focus_reassert_frames := 0
## How many times the settle window actually had to re-ask. Diagnostic: a non-zero count means the
## host did not act on the first request, which is the measurement that justifies the retry existing.
var focus_reasserts := 0
## How many times a mouse press had to take the cursor back because the host had released it while
## the layer still believed it was focused. Diagnostic: this is the reported failure made countable,
## so "the click does not recapture" is a number rather than an impression.
var capture_reasserted_by_click := 0
## How many presses asked the host for the cursor. Compared against `capture_reasserted_by_click` this
## separates "the player never clicked" from "the player clicked and the host refused".
var capture_requests_on_press := 0
## True once a press has been spent trying to recover capture and the cursor is STILL free.
##
## It exists to stop the recovery from starving combat. MEASURED CONSEQUENCE of not having it: with a
## free cursor, every attack click set `_suppress_presses`, so the press never reached `PlayerCombat`
## and attacks could never fire again for as long as the host refused capture - which is exactly the
## reported "attack inputs are accepted but no attack phase begins". One press per loss asks for the
## window; the rest behave as ordinary gameplay presses.
var _capture_recovery_attempted := false


## True when gameplay input is accepted right now.
##
## This is the ONE focus rule in the project. Every semantic query below consults it, so no gameplay
## system needs a focus rule of its own, and no system can keep reading input from a window the
## player is not looking at.
func is_input_active() -> bool:
	return not _focus_lost


## Bring the belief about window focus up to date, and it is RESUME-ONLY.
##
## The engine's live focus report is allowed to END a suspension but never to START one, so this can
## only ever give the player control back. It cannot take it away.
##
## WHY - MEASURED, in the reproduction the user ran. This used to match `has_focus()` in BOTH
## directions on every frame. A host that keeps reporting `has_focus() == false` after the player
## comes back therefore re-suspended the game on every single frame, and the resulting failure is
## exactly the one reported: no mouse capture (the capture keeper is gated on being active), no mouse
## look, and a player who would not walk even though the keys were plainly arriving - because the
## debug overlay reads raw `Input`, so it kept showing presses while every GAMEPLAY query answered
## nothing. A stale or wrong focus report has to be survivable, so the LOSS signal is the engine's
## explicit focus-out NOTIFICATION - a real transition event - and nothing else. Recovery has two
## paths, and neither can be stuck: the focus-in notification, and `_input`'s presence recovery.
func _refresh_focus() -> void:
	if _focus_lost and _engine_reports_focus():
		_apply_focus(true)


## The engine's own answer to "does this game's window hold OS focus". Deliberately the authority:
## it is re-read every frame, so a missed or duplicated notification cannot suspend the game forever.
func _engine_reports_focus() -> bool:
	var window := get_window()
	if window == null:
		return true
	return window.has_focus()


## Apply a focus state, running the one-time work each DIRECTION needs. Idempotent: a repeat call for
## the state already held does nothing, so this is safe to call every frame and from a notification.
func _apply_focus(focused: bool) -> void:
	if _focus_lost == not focused:
		return
	_focus_lost = not focused
	if _focus_lost:
		_on_focus_lost()
	else:
		_on_focus_gained()


## FOCUS LOST - the game stops reading input the player is aiming somewhere else, and gives the
## pointer back.
##
## It deliberately does NOT touch `mouse_look_enabled`. That flag is gameplay's declared INTENT, and a
## focus change is not a decision by the player: Escape is the only thing that clears the intent.
## Keeping intent and permission separate is what lets capture come back on its own when the player
## returns, instead of leaving them a free cursor and a click to make.
func _on_focus_lost() -> void:
	focus_lost_count += 1
	_clear_pending_input()
	if mouse_look_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_log_focus("window focus LOST: gameplay input suspended, cursor released (capture intent kept)")


## FOCUS GAINED - input resumes and gameplay's declared capture is re-applied immediately, before any
## input is read, so the player never has to click or press an unrelated key to get control back.
func _on_focus_gained() -> void:
	focus_gained_count += 1
	_clear_pending_input()
	# BOTH halves of the recovery, in the order that matters: the window first, then the cursor. A
	# return that delivers mouse input but no keyboard input is the reported "camera and attacks work,
	# movement does not", and the keyboard is claimed by the window call - so it runs even when this
	# layer never saw itself as suspended, which is the case when the host drops keyboard delivery
	# WITHOUT changing its focus report.
	_take_window_focus()
	if mouse_look_enabled:
		_force_capture()
	# A host can need a beat after the focus event before it will grant either request, so keep asking
	# for a bounded handful of frames. See `_reassert_after_focus()`.
	_focus_reassert_frames = FOCUS_REASSERT_FRAMES
	# The click or key that brought the window back must not also become a gameplay action: the player
	# was asking for the window, not swinging.
	_suppress_presses = true
	_log_focus("window focus GAINED: gameplay input resumed, window focus and capture re-asserted")


## Keep re-asking the host, for a BOUNDED number of frames, for the two things a refocus has to hand
## back: keyboard delivery to this window, and the captured cursor.
##
## WHY A RETRY IS NEEDED AT ALL, and this is the defect this exists to fix. Both requests are made
## from the focus event, which fires the moment the host HANDS FOCUS OVER - and a host can need a beat
## before it will act on a request made that early. MEASURED signature of missing it: the first request
## is dropped, the focus event never comes again (the window is focused now, so there is no further
## transition to hang the request on), and the game is left exactly as reported - the cursor free, and
## movement dead because movement is the only gameplay path that needs the keyboard.
##
## WHY IT IS BOUNDED, AND WHY IT STOPS. An unbounded per-frame request would fight the host and could
## steal the foreground from whatever the player switched to, which is a worse defect than the one it
## fixes. This is a settle window, not a takeover: a few frames after a real focus change, then nothing
## until the next real focus change. It is only ever opened by `_on_focus_gained()`.
##
## It re-asserts only while gameplay still WANTS input active and a captured cursor, so it can never
## override the player's own decisions - `is_input_active()` is still the single focus authority.
func _reassert_after_focus() -> void:
	if _focus_reassert_frames <= 0:
		return
	if not is_input_active():
		_focus_reassert_frames = 0
		return
	_focus_reassert_frames -= 1
	var window := get_window()
	if window != null and not window.has_focus():
		_take_window_focus()
		focus_reasserts += 1
	if not mouse_look_enabled:
		return
	# A REAL TRANSITION, and that is the whole reason this retry is not just the per-frame keeper again.
	# `_keep_mouse_captured()` cannot help here: when the HOST releases pointer lock while the engine's
	# own value still reads CAPTURED, the keeper sees "already captured", returns, and asks the host for
	# nothing forever - which is the reported free cursor that no amount of clicking fixed. Stepping
	# through VISIBLE makes the following CAPTURED a genuine change, so the host is actually asked.
	# It is bounded to this settle window, so it cannot flicker or fight the host indefinitely.
	_force_capture()
	focus_reasserts += 1


## Drop every half-finished input.
##
## Stale motion is the reported defect: motion accumulated while unfocused was spent by the camera on
## the first frame back. The same reasoning covers the rest of the half-finished state - the engine
## releases held keys during a focus change, so a pending tap/hold would resolve into a DODGE the
## player never asked for, and a buffer armed just before the change would fire on the way back in.
func _clear_pending_input() -> void:
	_mouse_look_accum = Vector2.ZERO
	_look_accum = Vector2.ZERO
	_sprint_active = false
	for source in [_pad_source, _key_source]:
		source["state"] = MobilityState.IDLE
		source["timer"] = 0.0
		source["sprint"] = false
	for action in _buffers.keys():
		_buffers[action] = 0.0


func _log_focus(message: String) -> void:
	print("[INPUT] %s" % message)


## Focus, BOTH directions. The notification is the immediate half of the same ownership the per-frame
## keeper handles: gaining focus re-applies gameplay's declared capture at once instead of waiting
## for a click the player may never make, and LOSING focus is what stops the game from consuming
## input the player is aiming at another window - the reported defect, which had no handling at all.
##
## Re-application on the way IN is deliberately unconditional on the engine's belief, even when
## `Input.mouse_mode` still reads CAPTURED: an embedded or browser host can drop pointer lock while
## Godot's own value still says captured, so that value is not proof the cursor is actually locked.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_apply_focus(false)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_apply_focus(true)


# --- Internals --------------------------------------------------------------

func _validate_actions() -> void:
	_missing_actions.clear()
	for action in GameActions.all_actions():
		if not InputMap.has_action(action):
			_missing_actions.append(action)
	if not _missing_actions.is_empty():
		push_warning("CascadiaInput: actions missing from InputMap: %s" % str(_missing_actions))


## Keyboard and controller mobility are resolved here, in the input layer, and
## exposed as two independent semantic states. Tap and hold thresholds are
## intentionally equal and independently tunable.
func _update_mobility(delta: float) -> void:
	_advance_source(_pad_source, GameActions.MOBILITY_BUTTON, delta)
	_advance_source(_key_source, GameActions.SPRINT, delta)
	# Sprint is active when EITHER source has resolved to a hold. A dodge can never
	# be active at the same time as a sprint, because a source only ever buffers a
	# DODGE on the frame it RETURNS TO IDLE from PENDING - the SPRINTING branch
	# buffers nothing on release, so letting go of a sprint cannot also fire a dodge.
	_sprint_active = bool(_pad_source["sprint"]) or bool(_key_source["sprint"])


## Advance ONE tap/hold source by a frame. This is the single place the
## tap-versus-hold decision is made, for both devices.
##
##   press                     -> PENDING (the decision starts here)
##   release within TAP_MAX    -> buffer DODGE (a tap)
##   held past HOLD_MIN        -> SPRINTING until release (a hold)
##   release while SPRINTING   -> IDLE, and NO dodge
##
## An action missing from the InputMap leaves its source idle rather than
## erroring, so a project without one of the two bindings still works.
func _advance_source(source: Dictionary, action: StringName, delta: float) -> void:
	if not InputMap.has_action(action):
		source["state"] = MobilityState.IDLE
		source["timer"] = 0.0
		source["sprint"] = false
		return

	var held := Input.is_action_pressed(action)
	var elapsed: float = float(source["timer"])

	match int(source["state"]):
		MobilityState.IDLE:
			if Input.is_action_just_pressed(action):
				source["state"] = MobilityState.PENDING
				source["timer"] = 0.0
		MobilityState.PENDING:
			elapsed += delta
			source["timer"] = elapsed
			if not held:
				if elapsed <= MOBILITY_TAP_MAX:
					_buffer_action(GameActions.DODGE)
				source["state"] = MobilityState.IDLE
				source["sprint"] = false
			elif elapsed >= MOBILITY_HOLD_MIN:
				source["state"] = MobilityState.SPRINTING
				source["sprint"] = true
		MobilityState.SPRINTING:
			if not held:
				source["state"] = MobilityState.IDLE
				source["sprint"] = false


func _update_buffers(delta: float) -> void:
	for action in _buffers.keys():
		_buffers[action] = maxf(0.0, float(_buffers[action]) - delta)

	if _suppress_presses:
		return

	for action in GameActions.BUFFERED_ACTIONS:
		if not InputMap.has_action(action):
			continue
		if Input.is_action_just_pressed(action):
			_buffers[action] = INPUT_BUFFER_TIME


func _buffer_action(action: StringName) -> void:
	if _buffers.has(action):
		_buffers[action] = INPUT_BUFFER_TIME


func _update_look(delta: float) -> void:
	var stick := Vector2.ZERO
	if InputMap.has_action(GameActions.CAMERA_LOOK_LEFT):
		stick = Input.get_vector(
			GameActions.CAMERA_LOOK_LEFT,
			GameActions.CAMERA_LOOK_RIGHT,
			GameActions.CAMERA_LOOK_UP,
			GameActions.CAMERA_LOOK_DOWN,
			LOOK_STICK_DEADZONE
		)
	_look_accum += _mouse_look_accum
	_look_accum += stick * LOOK_STICK_PIXELS_PER_SECOND * delta
	_mouse_look_accum = Vector2.ZERO
