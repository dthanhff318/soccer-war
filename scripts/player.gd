class_name Player
extends CharacterBody2D

## Top-down player controller. Moves on the pitch plane and kicks
## any ball within reach, away from the player's facing direction.

@export var move_speed: float = 320.0
@export var acceleration: float = 2400.0
@export var friction: float = 1800.0
@export var kick_strength: float = 700.0
@export var kick_radius: float = 48.0

## Last non-zero movement direction, used to aim kicks while standing still.
var _facing: Vector2 = Vector2.RIGHT

@onready var _kick_area: Area2D = $KickArea


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		_facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	if Input.is_action_just_pressed("kick"):
		_try_kick()


## Applies an impulse to every ball currently overlapping the kick area.
func _try_kick() -> void:
	for body in _kick_area.get_overlapping_bodies():
		if body is Ball:
			var to_ball := body.global_position - global_position
			# Prefer the direction toward the ball; fall back to facing when
			# the ball is sitting exactly on top of the player.
			var dir := to_ball.normalized() if to_ball.length() > 1.0 else _facing
			body.kick(dir * kick_strength)
