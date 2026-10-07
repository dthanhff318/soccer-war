extends Node2D

## The pitch, built entirely from MatchRules. It adds the walls and goal nets
## as physics bodies (on the headless server too) and draws the markings in
## a crisp pixel-art style, so the picture always matches the physics.

const WALL_THICKNESS := 40.0
const NET_THICKNESS := 10.0
## Net side bars poke this far into the pitch so the ball can't clip a post.
const NET_LIP := 5.0
const LINE_WIDTH := 3.0
const STRIPES := 12
const SURROUND_MARGIN := 56.0
const CORNER_ARC_RADIUS := 10.0
const NET_MESH := 8.0
const POST_WIDTH := 4.0

const SURROUND := Color(0.12, 0.35, 0.15)
const GRASS_LIGHT := Color(0.25, 0.6, 0.28)
const GRASS_DARK := Color(0.21, 0.53, 0.24)
const LINE_COLOR := Color(0.95, 0.97, 0.93)
const NET_SHADOW := Color(0, 0, 0, 0.3)
const NET_COLOR := Color(0.92, 0.94, 0.95, 0.45)

const SIDES := [-1, 1]  # left goal, right goal


func _ready() -> void:
	_build_walls()
	for side: int in SIDES:
		_build_net(side)


## Touchline walls run the full length (behind the nets too); the goal-line
## walls leave the mouth open.
func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var reach := MatchRules.PITCH_LENGTH + 2.0 * (MatchRules.GOAL_DEPTH + WALL_THICKNESS)
	var half_t := WALL_THICKNESS / 2.0
	_add_box(walls, Vector2(MatchRules.CENTER.x, MatchRules.TOUCHLINE_TOP - half_t), Vector2(reach, WALL_THICKNESS))
	_add_box(walls, Vector2(MatchRules.CENTER.x, MatchRules.TOUCHLINE_BOTTOM + half_t), Vector2(reach, WALL_THICKNESS))
	for side: int in SIDES:
		var x: float = _goal_line(side) + side * half_t
		var upper_top := MatchRules.TOUCHLINE_TOP - WALL_THICKNESS
		var lower_bottom := MatchRules.TOUCHLINE_BOTTOM + WALL_THICKNESS
		_add_box(walls, Vector2(x, (upper_top + MatchRules.GOAL_MOUTH_TOP) / 2.0),
			Vector2(WALL_THICKNESS, MatchRules.GOAL_MOUTH_TOP - upper_top))
		_add_box(walls, Vector2(x, (MatchRules.GOAL_MOUTH_BOTTOM + lower_bottom) / 2.0),
			Vector2(WALL_THICKNESS, lower_bottom - MatchRules.GOAL_MOUTH_BOTTOM))


## Two side bars and a back bar behind the goal mouth; nets soak up the ball.
func _build_net(side: int) -> void:
	var net := StaticBody2D.new()
	net.name = "NetLeft" if side < 0 else "NetRight"
	net.collision_layer = 1
	net.collision_mask = 0
	net.add_to_group("goal_net")
	add_child(net)
	var line := _goal_line(side)
	var bar_length := MatchRules.GOAL_DEPTH + NET_THICKNESS + NET_LIP
	var bar_x := line + side * (MatchRules.GOAL_DEPTH + NET_THICKNESS - NET_LIP) / 2.0
	var half_n := NET_THICKNESS / 2.0
	_add_box(net, Vector2(bar_x, MatchRules.GOAL_MOUTH_TOP - half_n), Vector2(bar_length, NET_THICKNESS))
	_add_box(net, Vector2(bar_x, MatchRules.GOAL_MOUTH_BOTTOM + half_n), Vector2(bar_length, NET_THICKNESS))
	_add_box(net, Vector2(line + side * (MatchRules.GOAL_DEPTH + half_n), MatchRules.CENTER.y),
		Vector2(NET_THICKNESS, MatchRules.GOAL_WIDTH + 2.0 * NET_THICKNESS))


func _add_box(body: StaticBody2D, center: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)


func _draw() -> void:
	var field := Rect2(MatchRules.GOAL_LINE_LEFT, MatchRules.TOUCHLINE_TOP,
		MatchRules.PITCH_LENGTH, MatchRules.PITCH_WIDTH)
	draw_rect(field.grow(SURROUND_MARGIN), SURROUND)
	var stripe := MatchRules.PITCH_LENGTH / STRIPES
	for i in STRIPES:
		var band := Rect2(field.position.x + i * stripe, field.position.y, stripe, field.size.y)
		draw_rect(band, GRASS_LIGHT if i % 2 == 0 else GRASS_DARK)
	for side: int in SIDES:
		_draw_goal(side)

	draw_rect(field, LINE_COLOR, false, LINE_WIDTH)
	var center := MatchRules.CENTER
	draw_line(Vector2(center.x, field.position.y), Vector2(center.x, field.end.y), LINE_COLOR, LINE_WIDTH)
	draw_arc(center, MatchRules.CENTER_CIRCLE_RADIUS, 0.0, TAU, 64, LINE_COLOR, LINE_WIDTH)
	draw_rect(Rect2(center - Vector2(3, 3), Vector2(6, 6)), LINE_COLOR)
	for side: int in SIDES:
		_draw_box_markings(side)
	for corner: Vector2 in [field.position, Vector2(field.end.x, field.position.y), field.end, Vector2(field.position.x, field.end.y)]:
		# Quarter circle between the two lines meeting at this corner, on the pitch side.
		var into: Vector2 = (center - corner).sign()
		var along_goal_line := Vector2(0.0, into.y).angle()
		var along_touchline := Vector2(into.x, 0.0).angle()
		draw_arc(corner, CORNER_ARC_RADIUS, along_touchline,
			along_touchline + angle_difference(along_touchline, along_goal_line), 8, LINE_COLOR, LINE_WIDTH)


## Penalty box, goal area, penalty spot and the arc outside the box.
func _draw_box_markings(side: int) -> void:
	var line := _goal_line(side)
	var inward := -side
	var center_y := MatchRules.CENTER.y
	for size: Vector2 in [MatchRules.PENALTY_BOX, MatchRules.GOAL_AREA]:
		var left := line if inward > 0 else line - size.x
		draw_rect(Rect2(left, center_y - size.y / 2.0, size.x, size.y), LINE_COLOR, false, LINE_WIDTH)
	var spot := Vector2(line + inward * MatchRules.PENALTY_SPOT_DISTANCE, center_y)
	draw_rect(Rect2(spot - Vector2(2.5, 2.5), Vector2(5, 5)), LINE_COLOR)
	# Only the part of the "D" outside the box is drawn.
	var reach := (MatchRules.PENALTY_BOX.x - MatchRules.PENALTY_SPOT_DISTANCE) / MatchRules.CENTER_CIRCLE_RADIUS
	var half_angle := acos(clampf(reach, -1.0, 1.0))
	var facing := 0.0 if inward > 0 else PI
	draw_arc(spot, MatchRules.CENTER_CIRCLE_RADIUS, facing - half_angle, facing + half_angle, 24, LINE_COLOR, LINE_WIDTH)


## Net mesh behind the goal line, framed by white posts and crossbar.
func _draw_goal(side: int) -> void:
	var line := _goal_line(side)
	var depth := MatchRules.GOAL_DEPTH
	var net := Rect2(line if side > 0 else line - depth, MatchRules.GOAL_MOUTH_TOP, depth, MatchRules.GOAL_WIDTH)
	draw_rect(net, NET_SHADOW)
	var x := net.position.x
	while x <= net.end.x:
		draw_line(Vector2(x, net.position.y), Vector2(x, net.end.y), NET_COLOR, 1.0)
		x += NET_MESH
	var y := net.position.y
	while y <= net.end.y:
		draw_line(Vector2(net.position.x, y), Vector2(net.end.x, y), NET_COLOR, 1.0)
		y += NET_MESH
	# Frame: the two side bars and the back of the net.
	var back := line + side * depth
	for frame_y in [MatchRules.GOAL_MOUTH_TOP, MatchRules.GOAL_MOUTH_BOTTOM]:
		draw_line(Vector2(line, frame_y), Vector2(back, frame_y), LINE_COLOR, POST_WIDTH)
	draw_line(Vector2(back, MatchRules.GOAL_MOUTH_TOP), Vector2(back, MatchRules.GOAL_MOUTH_BOTTOM), LINE_COLOR, POST_WIDTH)
	for post_y in [MatchRules.GOAL_MOUTH_TOP, MatchRules.GOAL_MOUTH_BOTTOM]:
		draw_rect(Rect2(Vector2(line, post_y) - Vector2(4, 4), Vector2(8, 8)), LINE_COLOR)


func _goal_line(side: int) -> float:
	return MatchRules.GOAL_LINE_LEFT if side < 0 else MatchRules.GOAL_LINE_RIGHT
