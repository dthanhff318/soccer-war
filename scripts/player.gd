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
## Ball speed of a kick: holding Space charges it from min to max.
@export var min_kick_speed: float = 300.0
@export var max_kick_speed: float = 650.0
## Seconds of holding Space to reach max_kick_speed.
@export var kick_charge_time: float = 1.0
## Holding this long past full power cancels the kick; Space must be
## released and pressed again to charge a new one.
@export var kick_overhold_time: float = 0.5
## Speed of a pass (I key), aimed like a kick.
@export var pass_strength: float = 250.0
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
const POWER_BAR_SIZE := Vector2(36, 5)
## On-screen size of the shirt sprite, whatever the resolution of its image.
const SPRITE_SIZE := 33.0
## Gap between the rings and the power bar above / the name below.
const LABEL_GAP := 3.0
const KEEPER_RING_COLOR := Color(1.0, 0.8, 0.25)

var stamina: float
## True after stamina hit zero; prevents stutter-sprinting on an empty bar.
var is_exhausted: bool = false
var team: int = Roster.Team.LEFT
var display_name: String = ""
## The player this client controls; drawn with an extra white ring.
var is_local: bool = false
## Keepers catch slow shots and spill hard ones softly (see Ball.keeper_touch).
var is_goalkeeper: bool = false
## Save stats used when is_goalkeeper (see Ball.keeper_rebound_speed).
var catch_speed: float = Ball.KEEPER_CATCH_SPEED
var rebound_min_ratio: float = Ball.KEEPER_MIN_RATIO
var rebound_max_ratio: float = Ball.KEEPER_MAX_RATIO
## How much faster than the player the ball leaves when run into (dribbling).
var dribble_push: float = 1.2
## Characters.ALL id this player was built from ("" for the default player).
var character_id: String = ""
## Draw offset that hides small prediction corrections; decays to zero.
var visual_offset: Vector2 = Vector2.ZERO
var _regen_cooldown: float = 0.0
## Charge for the coming kick, capped at kick_charge_time (0 when not charging).
var kick_charge: float = 0.0
var _kick_held: bool = false
## Seconds Space has been down in the current press.
var _hold_time: float = 0.0
## Set when a kick was cancelled by over-holding; ignored until Space is released.
var _kick_cancelled: bool = false

## Last non-zero movement direction, used to aim kicks while standing still.
var _facing: Vector2 = Vector2.RIGHT

@onready var _kick_area: Area2D = $KickArea
@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	stamina = max_stamina
	var texture := Teams.sprite_of(team)
	_sprite.texture = texture
	# Team images come in different resolutions; draw them all the same size.
	_sprite.scale = Vector2.ONE * SPRITE_SIZE / maxf(texture.get_width(), texture.get_height())


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
		simulate(Protocol.keyboard_bits(Input.is_action_just_pressed("pass")), delta)


## Advances the player one physics step using `bits` (Protocol.IN_*).
## `replay` is set when the Predictor re-runs inputs already applied once:
## only movement and stamina are redone, never charging, kicks or passes.
func simulate(bits: int, delta: float, replay: bool = false) -> void:
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

	if replay:
		return
	_update_kick((bits & Protocol.IN_KICK) != 0, delta)
	if bits & Protocol.IN_PASS:
		_try_pass()


## Radius within which this player can kick or pass the ball.
func reach() -> float:
	return (_kick_area.get_node("Collision").shape as CircleShape2D).radius


func set_reach(radius: float) -> void:
	var collision: CollisionShape2D = _kick_area.get_node("Collision")
	# The shape resource is shared by every player instance; give this one its own.
	var shape: CircleShape2D = collision.shape.duplicate()
	shape.radius = radius
	collision.shape = shape


## Ball speed a kick released now would have.
func kick_power() -> float:
	return lerpf(min_kick_speed, max_kick_speed, clampf(kick_charge / kick_charge_time, 0.0, 1.0))


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
			if is_goalkeeper:
				ball.keeper_touch(-collision.get_normal(), self)
			else:
				ball.push(-collision.get_normal(), speed, dribble_push)


## True while a kick is charging (the power bar is showing).
func is_charging() -> bool:
	return _kick_held


## Charges while Space is held and kicks on the tick it is released. Holding
## kick_overhold_time past full power cancels the kick for this press.
func _update_kick(held: bool, delta: float) -> void:
	if not held:
		if _kick_held:
			_try_kick()
		_reset_kick()
		_kick_cancelled = false
		return
	if _kick_cancelled:
		return
	_kick_held = true
	_hold_time += delta
	kick_charge = minf(_hold_time, kick_charge_time)
	# Small epsilon: summed 1/60 steps land a hair under the exact limit.
	if _hold_time >= kick_charge_time + kick_overhold_time - 0.0001:
		_reset_kick()
		_kick_cancelled = true
	queue_redraw()


func _reset_kick() -> void:
	if _kick_held or kick_charge > 0.0:
		queue_redraw()
	_kick_held = false
	_hold_time = 0.0
	kick_charge = 0.0


## Kicks every ball currently overlapping the kick area at the charged power.
func _try_kick() -> void:
	for body in _kick_area.get_overlapping_bodies():
		if body is Ball:
			body.kick(_strike_direction(body) * kick_power())


## Passes every ball within reach, aimed the same way as a kick.
func _try_pass() -> void:
	for body in _kick_area.get_overlapping_bodies():
		if body is Ball:
			body.start_pass(_strike_direction(body) * pass_strength)


## Direction from the player's centre to the ball's centre; falls back to
## facing when the ball is sitting exactly on top of the player.
func _strike_direction(ball: Ball) -> Vector2:
	var to_ball := ball.global_position - global_position
	return to_ball.normalized() if to_ball.length() > 1.0 else _facing


## Power bar above the head (relative to the player's centre).
func power_bar_rect() -> Rect2:
	var bottom := -_outer_ring_radius() - LABEL_GAP
	return Rect2(Vector2(-POWER_BAR_SIZE.x / 2.0, bottom - POWER_BAR_SIZE.y), POWER_BAR_SIZE)


## Top edge of the name label below the feet (relative to the player's centre).
func name_top() -> float:
	return _outer_ring_radius() + LABEL_GAP


## Team ring under the sprite, the power bar above it while charging, and the
## name below it in online play.
func _draw() -> void:
	draw_arc(visual_offset, RING_RADIUS, 0.0, TAU, 32, Teams.color_of(team), 3.0, true)
	if is_local:
		draw_arc(visual_offset, RING_RADIUS + 3.0, 0.0, TAU, 32, Color.WHITE, 1.5, true)
	elif is_goalkeeper:
		draw_arc(visual_offset, RING_RADIUS + 3.0, 0.0, TAU, 32, KEEPER_RING_COLOR, 2.0, true)
	if is_local and _kick_held:
		_draw_power_bar()
	if not display_name.is_empty():
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE).x
		var baseline := visual_offset + Vector2(-width / 2.0, name_top() + font.get_ascent(NAME_FONT_SIZE))
		draw_string_outline(font, baseline, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, 4, Color(0, 0, 0, 0.7))
		draw_string(font, baseline, display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_FONT_SIZE, Color.WHITE)


## Charge bar above the head while Space is held: yellow, turning red when full.
func _draw_power_bar() -> void:
	var ratio := clampf(kick_charge / kick_charge_time, 0.0, 1.0)
	var frame := power_bar_rect()
	frame.position += visual_offset
	var top_left := frame.position
	draw_rect(frame, Color(0, 0, 0, 0.6))
	var fill := Color(1.0, 0.85, 0.2).lerp(Color(0.95, 0.2, 0.15), ratio)
	draw_rect(Rect2(top_left, Vector2(POWER_BAR_SIZE.x * ratio, POWER_BAR_SIZE.y)), fill)
	draw_rect(frame, Color.WHITE, false, 1.0)


## The white "you" ring is a little larger than the team ring.
func _outer_ring_radius() -> float:
	return RING_RADIUS + (3.0 if is_local or is_goalkeeper else 0.0)
