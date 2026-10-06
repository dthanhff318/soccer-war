class_name Ball
extends CharacterBody2D

## Ball with simple linear drag. Uses CharacterBody2D (not RigidBody2D) so the
## motion stays fully deterministic and easy to tune for arcade-style play.

@export var radius: float = 11.2
@export var drag: float = 420.0
@export var max_speed: float = 1200.0
## Fraction of speed kept after hitting a wall or player.
@export var bounce_damping: float = 0.8
## Fraction of speed kept after hitting a goal net (nets absorb the ball).
@export var net_damping: float = 0.25
## How much faster than the player the ball leaves after being run into.
@export var push_factor: float = 1.2

## Caps collisions resolved per frame so a ball wedged in a corner can't loop.
const MAX_BOUNCES := 4


func _physics_process(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	velocity = velocity.limit_length(max_speed)
	_move_with_bounces(velocity * delta)

	# Roll the ball visually: arc length travelled / radius = radians turned.
	rotation += velocity.length() * delta / radius


## Moves along `motion`, reflecting off anything hit and continuing with the
## leftover distance so fast balls don't lose a frame of travel on impact.
func _move_with_bounces(motion: Vector2) -> void:
	for i in MAX_BOUNCES:
		var collision := move_and_collide(motion)
		if collision == null:
			return
		var normal := collision.get_normal()
		var collider := collision.get_collider() as Node
		var damping := net_damping if collider and collider.is_in_group("goal_net") else bounce_damping
		velocity = velocity.bounce(normal) * damping
		motion = collision.get_remainder().bounce(normal) * damping


## Adds an impulse to the ball, clamped to max_speed on the next frame.
func kick(impulse: Vector2) -> void:
	velocity += impulse


## Called when a moving player runs into the ball. Ensures the ball travels
## away along `direction` at least a little faster than the player was moving.
func push(direction: Vector2, player_speed: float) -> void:
	var target_speed := player_speed * push_factor
	var current_along := velocity.dot(direction)
	if current_along < target_speed:
		velocity += direction * (target_speed - current_along)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.96, 0.96, 0.96))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.1, 0.1, 0.1), 2.0, true)
	# Dark patch off-centre so rolling/spin is visible.
	draw_circle(Vector2(radius * 0.4, 0), radius * 0.3, Color(0.15, 0.15, 0.15))
