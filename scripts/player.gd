class_name Player
extends CharacterBody2D

## Top-down player controller. Moves on the pitch plane and kicks
## any ball within reach, away from the player's facing direction.
## Holding sprint runs faster at the cost of stamina.

signal stamina_changed(current: float, maximum: float, exhausted: bool)

@export var move_speed: float = 150.0
@export var sprint_speed: float = 220.0
@export var acceleration: float = 2400.0
@export var friction: float = 1800.0
@export var kick_strength: float = 700.0
@export var kick_radius: float = 38.4

@export_group("Stamina")
@export var max_stamina: float = 100.0
## Stamina spent per second while sprinting and moving.
@export var sprint_drain: float = 10.0
## Stamina recovered per second while not sprinting.
@export var stamina_regen: float = 2.0
## Pause after the last sprint before stamina starts recovering.
@export var regen_delay: float = 0.8
## Once drained to zero, sprinting stays locked until stamina reaches this.
@export var exhausted_recover_at: float = 30.0

var stamina: float
## True after stamina hit zero; prevents stutter-sprinting on an empty bar.
var is_exhausted: bool = false
var _regen_cooldown: float = 0.0

## Last non-zero movement direction, used to aim kicks while standing still.
var _facing: Vector2 = Vector2.RIGHT

@onready var _kick_area: Area2D = $KickArea


func _ready() -> void:
	stamina = max_stamina


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var sprinting := _update_stamina(input_dir != Vector2.ZERO, delta)
	var target_speed := sprint_speed if sprinting else move_speed

	if input_dir != Vector2.ZERO:
		_facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * target_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# Remember speed before sliding, since a collision with the ball eats it.
	var speed_before_move := velocity.length()
	move_and_slide()
	_push_touched_balls(speed_before_move)

	if Input.is_action_just_pressed("kick"):
		_try_kick()


## Drains or regenerates stamina for this frame and returns whether the
## player is actually sprinting (wants to, is moving, and has stamina).
func _update_stamina(is_moving: bool, delta: float) -> bool:
	var previous := stamina
	var was_exhausted := is_exhausted
	var sprinting := Input.is_action_pressed("sprint") and is_moving and not is_exhausted

	if sprinting:
		stamina = maxf(stamina - sprint_drain * delta, 0.0)
		_regen_cooldown = regen_delay
		if stamina == 0.0:
			is_exhausted = true
	elif _regen_cooldown > 0.0:
		_regen_cooldown -= delta
	else:
		stamina = minf(stamina + stamina_regen * delta, max_stamina)
		if is_exhausted and stamina >= exhausted_recover_at:
			is_exhausted = false

	if stamina != previous or is_exhausted != was_exhausted:
		stamina_changed.emit(stamina, max_stamina, is_exhausted)
	return sprinting


## Running into the ball sends it away from the player (dribbling).
func _push_touched_balls(speed: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var ball := collision.get_collider() as Ball
		if ball:
			# The normal points from the ball back toward the player.
			ball.push(-collision.get_normal(), speed)


## Applies an impulse to every ball currently overlapping the kick area.
func _try_kick() -> void:
	for body in _kick_area.get_overlapping_bodies():
		if body is Ball:
			var to_ball := body.global_position - global_position
			# Prefer the direction toward the ball; fall back to facing when
			# the ball is sitting exactly on top of the player.
			var dir := to_ball.normalized() if to_ball.length() > 1.0 else _facing
			body.kick(dir * kick_strength)
