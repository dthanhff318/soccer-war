class_name PlayerLook
extends Node2D

## A top-down footballer drawn in code, used when the player has no image:
## shirt in the team colour (each team's keeper has its own, plus gloves), arms, head
## with hair at the back, and boots that stride while running. It faces the
## way it moves, worked out from its own on-screen movement, so it also
## turns correctly for players driven by network snapshots.

const OUTLINE := Color(0.05, 0.05, 0.08)
const GLOVES := Color(0.97, 0.97, 0.95)
const BOOTS := Color(0.12, 0.12, 0.14)
const SHADOW := Color(0, 0, 0, 0.28)
const SKIN_TONES: Array[Color] = [
	Color(0.98, 0.82, 0.66), Color(0.9, 0.7, 0.52), Color(0.76, 0.56, 0.38), Color(0.55, 0.38, 0.25),
]
const HAIR_COLORS: Array[Color] = [
	Color(0.12, 0.09, 0.07), Color(0.35, 0.2, 0.1), Color(0.8, 0.62, 0.3), Color(0.6, 0.25, 0.12),
]
## Distance travelled per half stride of the run cycle.
const STRIDE := 9.0
## Frames without movement before the run cycle stops.
const IDLE_FRAMES := 6

## On-screen size of the figure (shoulder width).
var size: float = Player.SPRITE_SIZE
var shirt_color: Color = Color.WHITE
var gloves: bool = false
var skin: Color = SKIN_TONES[0]
var hair: Color = HAIR_COLORS[0]
## Direction the figure faces; follows its movement.
var facing: Vector2 = Vector2.RIGHT
var is_running: bool = false

var _step_phase: float = 0.0
var _last_position := Vector2.INF
var _idle_frames: int = 0


func _ready() -> void:
	_sync_with_player()


func _process(_delta: float) -> void:
	_sync_with_player()
	var now := get_parent().global_position as Vector2
	if _last_position != Vector2.INF:
		var moved := now - _last_position
		if moved.length() > 0.3:
			facing = moved.normalized()
			is_running = true
			_idle_frames = 0
			_step_phase += moved.length() / STRIDE
		else:
			_idle_frames += 1
			if _idle_frames > IDLE_FRAMES:
				is_running = false
	_last_position = now
	queue_redraw()


## Shirt, gloves and skin/hair follow the owning Player (team, keeper role,
## name), which can change after spawning (e.g. penalty role swaps).
func _sync_with_player() -> void:
	var player := get_parent() as Player
	if player == null:
		return
	gloves = player.is_goalkeeper
	shirt_color = Teams.keeper_color_of(player.team) if player.is_goalkeeper else Teams.color_of(player.team)
	var seed_value := absi(hash(player.display_name))
	skin = SKIN_TONES[seed_value % SKIN_TONES.size()]
	hair = HAIR_COLORS[(seed_value / SKIN_TONES.size()) % HAIR_COLORS.size()]


func _draw() -> void:
	var s := size
	_draw_ellipse(Vector2(1.5, 2.5), Vector2(s * 0.5, s * 0.42), SHADOW, false)
	# Everything else is drawn in "facing space": +x is forward.
	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
	var stride := sin(_step_phase * PI) * s * 0.22 if is_running else 0.0
	for side: float in [-1.0, 1.0]:
		var forward: float = stride * side
		var foot := Rect2(Vector2(forward - s * 0.1, side * s * 0.2 - s * 0.08), Vector2(s * 0.28, s * 0.16))
		draw_rect(foot, BOOTS)
	_draw_ellipse(Vector2.ZERO, Vector2(s * 0.3, s * 0.5), shirt_color, true)
	for side: float in [-1.0, 1.0]:
		var hand := Vector2(stride * -side * 0.5, side * s * 0.5)
		draw_circle(hand, s * 0.11, OUTLINE)
		draw_circle(hand, s * 0.08, GLOVES if gloves else skin)
	var head := Vector2(s * 0.04, 0.0)
	draw_circle(head, s * 0.18, OUTLINE)
	draw_circle(head, s * 0.15, skin)
	# Hair covers the back half of the head, so the face points forward.
	var back := PackedVector2Array([head])
	for i in 9:
		var angle := PI * 0.5 + PI * i / 8.0
		back.append(head + Vector2.from_angle(angle) * s * 0.15)
	draw_colored_polygon(back, hair)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color, outlined: bool) -> void:
	var points := PackedVector2Array()
	for i in 20:
		points.append(center + Vector2.from_angle(TAU * i / 20.0) * radii)
	draw_colored_polygon(points, color)
	if outlined:
		points.append(points[0])
		draw_polyline(points, OUTLINE, 2.0)
