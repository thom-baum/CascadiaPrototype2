class_name GameLayers
extends RefCounted
## Physics layer assignments for Cascadia.
##
## Physical collision and combat collision are separate concerns and must never
## share a layer. Actors collide with the world as physical bodies; combat
## hitboxes and hurtboxes live on their own layers so an attack volume can never
## shove a body around, and a body can never block or absorb a hit.
##
## Layer map (bit 0 is layer 1 in the editor):
##
##   1  WORLD           static geometry and props; the camera ray respects this
##   2  ACTOR           player and enemy physical bodies
##   3  HITBOX          volumes that deal damage. Area3D only.
##   4  HURTBOX         volumes that receive damage. Area3D only.
##   5  CAMERA_BLOCKER  reserved; camera obstruction separate from the actor layer
##
## Keep these constants and the collision_layer / collision_mask values written
## into the scenes in sync.

## Layer 1 - static level geometry, props, collision the camera should respect.
const WORLD := 1 << 0

## Layer 2 - player and enemy physical bodies.
const ACTOR := 1 << 1

## Layer 3 - damage-dealing volumes (hitboxes). Milestone 2.
## Area3D only. Never used as physical body collision.
const HITBOX := 1 << 2

## Layer 4 - damage-receiving volumes (hurtboxes). Milestone 2.
## Area3D only. Never used as physical body collision.
const HURTBOX := 1 << 3

## Layer 5 - camera obstruction / spring arm blockers. Reserved.
const CAMERA_BLOCKER := 1 << 4


## Every combat volume layer. Anything on these must be an Area3D, never a body.
static func combat_layers() -> int:
	return HITBOX | HURTBOX
