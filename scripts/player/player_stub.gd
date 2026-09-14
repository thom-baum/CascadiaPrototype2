class_name PlayerStub
extends CharacterBody3D
## Milestone 0 placeholder actor.
##
## This exists so the test environment has a physical body for the camera to
## follow and for physical collision to be exercised. It deliberately implements
## NO locomotion: gravity and floor settling only. Pressing WASD will not move it
## yet.
##
## Horizontal movement, acceleration, deceleration, rotation and camera-relative
## input arrive in Milestone 1 (grounded player movement).
##
## Jumping is intentionally absent from Cascadia's foundation and this script must
## never grow one by accident.

## Multiplier on the project's default 3D gravity.
@export var gravity_scale := 1.0


func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if not is_on_floor():
		velocity.y -= gravity * gravity_scale * delta
	else:
		velocity.y = 0.0

	# No locomotion yet. Stated explicitly so the stub cannot drift.
	velocity.x = 0.0
	velocity.z = 0.0

	move_and_slide()
