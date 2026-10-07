extends TestCase

## The pitch is built from MatchRules: 1.2x the old length, same width, with
## walls and goal nets that match the drawn lines.

const PITCH_SCENE := preload("res://scenes/pitch.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const DELTA := 1.0 / 60.0
## Goal line to goal line of the original image-based pitch.
const OLD_LENGTH := 1016.8 - 263.2

var _world: SubViewport


func _setup() -> Ball:
	_world = SubViewport.new()
	_world.world_2d = World2D.new()
	add_child(_world)
	_world.add_child(PITCH_SCENE.instantiate())
	var ball: Ball = BALL_SCENE.instantiate()
	ball.simulated = false
	_world.add_child(ball)
	for i in 3:
		await get_tree().physics_frame
	return ball


func _roll(ball: Ball, from: Vector2, velocity: Vector2, ticks: int = 180) -> void:
	ball.reset(from)
	ball.velocity = velocity
	for i in ticks:
		ball.step(DELTA)


func test_pitch_is_one_point_two_times_longer() -> void:
	check_near(MatchRules.GOAL_LINE_RIGHT - MatchRules.GOAL_LINE_LEFT, OLD_LENGTH * 1.2, 1.0, "length")
	check_near(MatchRules.CENTER.x, 640.0, 0.01, "centred horizontally")
	check(MatchRules.GOAL_LINE_LEFT - MatchRules.GOAL_DEPTH > 0.0, "left net on screen")
	check(MatchRules.GOAL_LINE_RIGHT + MatchRules.GOAL_DEPTH < 1280.0, "right net on screen")


func test_shot_into_the_goal_scores_and_stays_in_the_net() -> void:
	var ball := await _setup()
	_roll(ball, MatchRules.CENTER + Vector2(300, 0), Vector2(900, 0))
	check_eq(MatchRules.scoring_team(ball.position, ball.radius), Roster.Team.LEFT, "goal")
	check(ball.position.x < MatchRules.GOAL_LINE_RIGHT + MatchRules.GOAL_DEPTH, "held by the back of the net")
	_world.queue_free()


func test_shot_wide_of_the_goal_is_stopped_by_the_goal_line_wall() -> void:
	var ball := await _setup()
	var wide := Vector2(MatchRules.CENTER.x + 300, MatchRules.GOAL_MOUTH_TOP - 60)
	_roll(ball, wide, Vector2(900, 0), 40)
	check(ball.position.x < MatchRules.GOAL_LINE_RIGHT, "bounced back off the end wall")
	_world.queue_free()


func test_touchline_walls_keep_the_ball_on_the_pitch() -> void:
	var ball := await _setup()
	_roll(ball, MatchRules.CENTER, Vector2(0, -900), 40)
	check(ball.position.y > MatchRules.TOUCHLINE_TOP, "top wall")
	_roll(ball, MatchRules.CENTER, Vector2(0, 900), 40)
	check(ball.position.y < MatchRules.TOUCHLINE_BOTTOM, "bottom wall")
	_world.queue_free()


func test_kickoff_spots_are_in_the_right_halves() -> void:
	for count in range(1, 5):
		for spot in MatchRules.kickoff_positions(Roster.Team.LEFT, count):
			check(spot.x > MatchRules.GOAL_LINE_LEFT and spot.x < MatchRules.CENTER.x, "left half %s" % spot)
			check(spot.y > MatchRules.TOUCHLINE_TOP and spot.y < MatchRules.TOUCHLINE_BOTTOM, "on pitch %s" % spot)


func test_goal_is_one_point_two_five_times_wider() -> void:
	check_near(MatchRules.GOAL_WIDTH, 136.6 * 1.25, 0.01, "goal mouth")
	check_near(MatchRules.GOAL_MOUTH_BOTTOM - MatchRules.GOAL_MOUTH_TOP, MatchRules.GOAL_WIDTH, 0.01, "mouth from width")
	check(MatchRules.GOAL_AREA.y > MatchRules.GOAL_WIDTH + 40.0, "goal area still wraps the goal")
	check(MatchRules.PENALTY_BOX.y > MatchRules.GOAL_AREA.y, "penalty box wraps the goal area")


func test_shot_near_the_post_of_the_wider_goal_scores() -> void:
	var ball := await _setup()
	# Old mouth ended at CENTER.y + 68.3; this is past it, and the ball (radius
	# 11.2) still clears the new post at CENTER.y + 85.4.
	var near_post := Vector2(MatchRules.CENTER.x + 300, MatchRules.CENTER.y + 70)
	_roll(ball, near_post, Vector2(900, 0))
	check_eq(MatchRules.scoring_team(ball.position, ball.radius), Roster.Team.LEFT, "goal")
	_world.queue_free()
