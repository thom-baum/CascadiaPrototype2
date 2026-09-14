class_name GameActions
extends RefCounted
## Single source of truth for Cascadia's semantic input action names.
##
## Input layering:
##
##   physical device  ->  InputMap action  ->  CascadiaInput  ->  gameplay systems
##
## Gameplay code never reads physical keys, mouse buttons or controller buttons
## directly. It asks the input layer about a semantic action by name, so controls
## stay rebindable and control decisions never leak into gameplay code.
##
## SPRINT and DODGE are separate gameplay actions even though the controller
## presents both through Circle (see MOBILITY_BUTTON). The keyboard keeps them on
## separate physical keys on purpose so each system can be tuned independently.
##
## Actions in RESERVED_ACTIONS are bound so the controller layout is complete and
## future-proof, but they have NO gameplay implementation and must not be wired
## into any system yet.

# --- Locomotion -------------------------------------------------------------
const MOVE_FORWARD := &"move_forward"
const MOVE_BACKWARD := &"move_backward"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"

# --- Camera -----------------------------------------------------------------
# Godot's InputMap cannot bind mouse motion as an action, so camera look is a
# semantic family: four directional actions drive the right stick, and the input
# layer delivers mouse movement as a separate relative look delta. Both reach
# gameplay as one Vector2 from CascadiaInput.get_look_delta().
const CAMERA_LOOK_LEFT := &"camera_look_left"
const CAMERA_LOOK_RIGHT := &"camera_look_right"
const CAMERA_LOOK_UP := &"camera_look_up"
const CAMERA_LOOK_DOWN := &"camera_look_down"

# --- Mobility (separate systems, deliberately) ------------------------------
const SPRINT := &"sprint"
const DODGE := &"dodge"

# Device-level contextual source for the controller's Circle button. CascadiaInput
# resolves tap -> DODGE and hold -> SPRINT. Gameplay never reads this action.
const MOBILITY_BUTTON := &"mobility_button"

# --- Combat -----------------------------------------------------------------
const LIGHT_ATTACK := &"light_attack"
const HEAVY_ATTACK := &"heavy_attack"
const PARRY := &"parry"
const CRITICAL := &"critical"

# --- Targeting / interaction ------------------------------------------------
const LOCK_ON := &"lock_on"
const QUICK_ITEM := &"quick_item"
const INTERACT := &"interact"
## X button. Reserved future behaviour, recorded but NOT implemented:
## tap X = contextual Use / Interact, hold X = open Quick Bar, D-pad selects
## while the bar is held open and release confirms. See res://.summerrules.
const QUICK_ACTION := &"quick_action"
const SECONDARY_ACTION := &"secondary_action"

# --- Item selection ---------------------------------------------------------
const ITEM_UP := &"item_up"
const ITEM_DOWN := &"item_down"
const ITEM_LEFT := &"item_left"
const ITEM_RIGHT := &"item_right"

# --- Reserved slots (bound, NOT implemented) --------------------------------
const RANGED_ATTACK := &"ranged_attack"
const JUMP := &"jump"

# --- System -----------------------------------------------------------------
const MENU := &"menu"

## Restarts the current arena after a death. A system action rather than a
## gameplay action: the gameplay systems never see it, the death/reset circuit
## does, and it is deliberately NOT in RESERVED_ACTIONS because it has a real
## implementation.
const RESTART := &"restart"

# --- Development tooling ----------------------------------------------------
## Shows / hides the diagnostic input overlay. Not a gameplay action; nothing in
## the gameplay architecture may read it.
const TOGGLE_DEBUG_OVERLAY := &"toggle_debug_overlay"

## Actions that have a reserved input slot but no gameplay implementation.
## Nothing may consume these during the current foundation phase.
const RESERVED_ACTIONS := [RANGED_ATTACK, JUMP]

## Presses that gameplay consumes through CascadiaInput.consume() and that are
## therefore buffered briefly so an input is never lost between frames.
const BUFFERED_ACTIONS := [
	LIGHT_ATTACK,
	HEAVY_ATTACK,
	PARRY,
	CRITICAL,
	DODGE,
	QUICK_ITEM,
	INTERACT,
	QUICK_ACTION,
	SECONDARY_ACTION,
	LOCK_ON,
	ITEM_UP,
	ITEM_DOWN,
	ITEM_LEFT,
	ITEM_RIGHT,
	RESTART,
]

## Ordered groups used by tooling (the diagnostic overlay) and by future
## rebinding UI. Insertion order is preserved.
const GROUPS := {
	"LOCOMOTION": [MOVE_FORWARD, MOVE_BACKWARD, MOVE_LEFT, MOVE_RIGHT, SPRINT, DODGE],
	"CAMERA": [CAMERA_LOOK_LEFT, CAMERA_LOOK_RIGHT, CAMERA_LOOK_UP, CAMERA_LOOK_DOWN],
	"COMBAT": [LIGHT_ATTACK, HEAVY_ATTACK, PARRY, CRITICAL],
	"TARGETING": [LOCK_ON],
	"ITEMS": [QUICK_ITEM, INTERACT, QUICK_ACTION, SECONDARY_ACTION],
	"ITEM SELECTION": [ITEM_UP, ITEM_DOWN, ITEM_LEFT, ITEM_RIGHT],
	"RESERVED - NO IMPLEMENTATION": [RANGED_ATTACK, JUMP],
	"SYSTEM": [MENU, RESTART],
	"DEV TOOLING": [TOGGLE_DEBUG_OVERLAY],
	"DEVICE - CONTEXTUAL SOURCE": [MOBILITY_BUTTON],
}


## Every semantic action name, flattened from GROUPS.
static func all_actions() -> Array:
	var out := []
	for group_name in GROUPS:
		for action in GROUPS[group_name]:
			if not out.has(action):
				out.append(action)
	return out


## True when the action is a reserved slot with no gameplay implementation.
static func is_reserved(action: StringName) -> bool:
	return RESERVED_ACTIONS.has(action)


## True when gameplay is allowed to consume the action this phase.
static func is_gameplay_action(action: StringName) -> bool:
	return not is_reserved(action) and action != MOBILITY_BUTTON and action != MENU
