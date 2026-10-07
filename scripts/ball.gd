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

## Off on online clients, where server snapshots place the ball via show_at().
## On the server the room calls step() itself, after the players move.
@export var simulated: bool = true

## True while the ball travels from a pass. A pass stops dead on the first
## player it touches; hitting anything else, a kick, or coming to rest turns
## it back into an ordinary ball.
var is_pass: bool = false

## Goalkeeper saves: slower than this is caught dead where it touches.
const KEEPER_CATCH_SPEED := 300.0
## Faster shots spill back at this share of their speed, rising linearly
## from KEEPER_MIN_RATIO at the catch speed to KEEPER_MAX_RATIO at this speed.
const KEEPER_FULL_SPEED := 650.0
const KEEPER_MIN_RATIO := 0.2
const KEEPER_MAX_RATIO := 0.45

## Caps collisions resolved per frame so a ball wedged in a corner can't loop.
const MAX_BOUNCES := 4


func _physics_process(delta: float) -> void:
	if simulated:
		step(delta)


## Advances the ball one physics step: drag, movement and bounces.
func step(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	velocity = velocity.limit_length(max_speed)
	_move_with_bounces(velocity * delta)
	if velocity == Vector2.ZERO:
		is_pass = false

	# Roll the ball visually: arc length travelled / radius = radians turned.
	rotation += velocity.length() * delta / radius


## Moves along `motion`, reflecting off anything hit and continuing with the
## leftover distance so fast balls don't lose a frame of travel on impact.
func _move_with_bounces(motion: Vector2) -> void:
	for i in MAX_BOUNCES:
		var collision := move_and_collide(motion)
		if collision == null:
			return
		var collider := collision.get_collider() as Node
		if is_pass:
			is_pass = false
			if collider is Player:
				# Trapped: rest where it touched the player.
				velocity = Vector2.ZERO
				return
		var normal := collision.get_normal()
		if collider is Player and collider.is_goalkeeper:
			var speed := velocity.length()
			keeper_touch(normal, collider)
			if velocity == Vector2.ZERO:
				return
			motion = collision.get_remainder().bounce(normal) * (velocity.length() / speed)
			continue
		var damping := net_damping if collider and collider.is_in_group("goal_net") else bounce_damping
		velocity = velocity.bounce(normal) * damping
		motion = collision.get_remainder().bounce(normal) * damping


## Speed a shot keeps after `keeper` touches it (0 = caught). Without a
## keeper the default save stats apply.
static func keeper_rebound_speed(speed: float, keeper: Player = null) -> float:
	var catch_at: float = keeper.catch_speed if keeper else KEEPER_CATCH_SPEED
	var min_ratio: float = keeper.rebound_min_ratio if keeper else KEEPER_MIN_RATIO
	var max_ratio: float = keeper.rebound_max_ratio if keeper else KEEPER_MAX_RATIO
	if speed < catch_at:
		return 0.0
	var t := clampf((speed - catch_at) / maxf(KEEPER_FULL_SPEED - catch_at, 1.0), 0.0, 1.0)
	return speed * lerpf(min_ratio, max_ratio, t)


## A goalkeeper touched the ball; `normal` points from the keeper to the ball.
## Slow balls are caught dead, fast ones spill back softly.
func keeper_touch(normal: Vector2, keeper: Player = null) -> void:
	is_pass = false
	var rebound := keeper_rebound_speed(velocity.length(), keeper)
	if rebound == 0.0:
		velocity = Vector2.ZERO
	else:
		velocity = velocity.bounce(normal).normalized() * rebound


## Puts the ball at rest at `pos` (kickoff).
func reset(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	is_pass = false


## Places the ball from a snapshot, rolling it by the distance it moved.
func show_at(pos: Vector2) -> void:
	rotation += position.distance_to(pos) / radius
	position = pos


## Shoots the ball exactly along `impulse`: its length is the final speed,
## whatever the ball was doing before.
func kick(impulse: Vector2) -> void:
	velocity = impulse
	is_pass = false


## Sends the ball exactly along `impulse` as a pass (see is_pass).
func start_pass(impulse: Vector2) -> void:
	velocity = impulse
	is_pass = true


## Called when a moving player runs into the ball. Ensures the ball travels
## away along `direction` at least a little faster than the player was moving.
func push(direction: Vector2, player_speed: float, factor: float = push_factor) -> void:
	if is_pass:
		# A player ran into a pass: it stops at their feet.
		is_pass = false
		velocity = Vector2.ZERO
		return
	var target_speed := player_speed * factor
	var current_along := velocity.dot(direction)
	if current_along < target_speed:
		velocity += direction * (target_speed - current_along)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.96, 0.96, 0.96))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.1, 0.1, 0.1), 2.0, true)
	# Dark patch off-centre so rolling/spin is visible.
	draw_circle(Vector2(radius * 0.4, 0), radius * 0.3, Color(0.15, 0.15, 0.15))
