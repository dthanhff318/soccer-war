class_name Ball
extends CharacterBody2D

## Ball with simple linear drag. Uses CharacterBody2D (not RigidBody2D) so the
## motion stays fully deterministic and easy to tune for arcade-style play.

@export var drag: float = 420.0
@export var max_speed: float = 1200.0
@export var bounce_damping: float = 0.8


func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	velocity = velocity.limit_length(max_speed)

	var collision := move_and_slide()
	if collision:
		# Reflect off walls, losing a little energy each bounce.
		for i in get_slide_collision_count():
			var normal := get_slide_collision(i).get_normal()
			velocity = velocity.bounce(normal) * bounce_damping
			break


## Adds an impulse to the ball, clamped to max_speed on the next frame.
func kick(impulse: Vector2) -> void:
	velocity += impulse
