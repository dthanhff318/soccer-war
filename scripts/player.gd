class_name Player
extends CharacterBody2D

## Top-down player controller. Moves on the pitch plane and kicks
## any ball within reach, away from the player's facing direction.
## Holding sprint runs faster at the cost of stamina.
##
## Each physics step is driven by input bits (see Protocol): read from the
## keyboard in offline play, received over the network on the server, and
## replayed by the client-side Predictor.

signal stamina_changed(current: float, maximum: float, exhausted: bool)

@export var move_speed: float = 150.0
@export var sprint_speed: float = 220.0
@export var acceleration: float = 2400.0
@export var friction: float = 1800.0
@export var kick_strength: float = 700.0
## Speed of a pass (I key): softer than a kick, along the running direction.
@export var pass_strength: float = 420.0
@export var kick_radius: float = 38.4
## Offline play: read the keyboard every physics tick. Online, the server
## room and the client Predictor call simulate() instead.
@export var keyboard_control: bool = false

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

const RING_RADIUS := 18.0
const NAME_FONT_SIZE := 12
## How quickly a smoothed prediction correction fades, per second.
const OFFSET_DECAY := 15.0

var stamina: float
## True after stamina hit zero; prevents stutter-sprinting on an empty bar.
var is_exhausted: bool = false
var team: int = Roster.Team.LEFT
var display_name: String = ""
## The player this client controls; drawn with an extra white ring.
var is_local: bool = false
## Draw offset that hides small prediction corrections; decays to zero.
var visual_offset: Vector2 = Vector2.ZERO
var _regen_cooldown: float = 0.0

## Last non-zero movement direction, used to aim kicks while standing still.
var _facing: Vector2 = Vector2.RIGHT

@onready var _kick_area: Area2D = $KickArea
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	stamina = max_stamina


func _process(delta: float) -> void:
	if visual_offset == Vector2.ZERO and _sprite.position == Vector2.ZERO:
		return
	visual_offset = visual_offset.lerp(Vector2.ZERO, minf(OFFSET_DECAY * delta, 1.0))
	if visual_offset.length() < 0.1:
		visual_offset = Vector2.ZERO
	_sprite.position = visual_offset
	queue_redraw()


func _physics_process(delta: float) -> void:
	if keyboard_control:
		simulate(Protocol.keyboard_bits(Input.is_action_just_pressed("kick"), Input.is_action_just_pressed("pass")), delta)


## Advances the player one physics step using `bits` (Protocol.IN_*).
func simulate(bits: int, delta: float) -> void:
	var input_dir := Protocol.input_vector(bits)
	var wants_sprint := (bits & Protocol.IN_SPRINT) != 0
	var sprinting := _update_stamina(input_dir != Vector2.ZERO, wants_sprint, delta)
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

	if bits & Protocol.IN_KICK:
		_try_kick()
	elif bits & Protocol.IN_PASS:
		_try_pass()


## Everything the server sends for this player in a snapshot.
func get_state() -> Dictionary:
	return {
		"pos": position,
		"vel": velocity,
		"stamina": stamina,
		"regen": _regen_cooldown,
		"exhausted": is_exhausted,
	}


func set_state(state: Dictionary) -> void:
	position = state.pos
	velocity = state.vel
	_regen_cooldown = state.regen
	var changed: bool = stamina != state.stamina or is_exhausted != state.exhausted
	stamina = state.stamina
	is_exhausted = state.exhausted
	if changed:
		stamina_changed.emit(stamina, max_stamina, is_exhausted)


## Drains or regenerates stamina for this frame and returns whether the
## player is actually sprinting (wants to, is moving, and has stamina).
func _update_stamina(is_moving: bool, wants_sprint: bool, delta: float) -> bool:
	var previous := stamina
	var was_exhausted := is_exhausted
	var sprinting := wants_sprint and is_moving and not is_exhausted

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


## Passes every ball within reach straight along the running direction.
func _try_pass() -> void:
	for body in _kick_area.get_overlapping_bodies():
		if body is Ball:
			body.start_pass(_facing * pass_strength)


## Team ring under the sprite, plus the name above it in online play.
func _draw() -> void:
	draw_arc(visual_offset, RING_RADIUS, 0.0, TAU, 32, MatchRules.TEAM_COLORS[team], 3.0, true)
	if is_local:
		draw_arc(visual_offset, RING_RADIUS + 3.0, 0.0, TAU, 32, Color.WHITE, 1.5, true)
	if not display_name.is_empty():
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
		var baseline := visual_offset + Vector2(-width / 2.0, -RING_RADIUS - 8.0)
		draw_string(font, baseline, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, Color.WHITE)
