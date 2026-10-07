extends TestCase

## Keeper practice: a shooter lines up from a random spot in front of the left
## goal and shoots at a random point of the goal mouth, again and again.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const DELTA := 1.0 / 60.0

var _world: SubViewport


func _setup(seed_value: int) -> ShootingDrill:
	_world = SubViewport.new()
	_world.world_2d = World2D.new()
	add_child(_world)
	var shooter: Player = PLAYER_SCENE.instantiate()
	shooter.team = Roster.Team.RIGHT
	_world.add_child(shooter)
	var ball: Ball = BALL_SCENE.instantiate()
	ball.simulated = false
	_world.add_child(ball)
	var drill := ShootingDrill.new(shooter, ball, seed_value)
	_world.add_child(drill)
	for i in 3:
		await get_tree().physics_frame
	return drill


## Runs the drill tick by tick until the ball is moving; returns its velocity.
func _until_shot(drill: ShootingDrill) -> Vector2:
	for i in 200:
		drill.shooter.simulate(drill.next_bits(DELTA), DELTA)
		drill.ball.step(DELTA)
		if drill.ball.velocity.length() > 1.0:
			return drill.ball.velocity
		await get_tree().physics_frame
	return Vector2.ZERO


func test_shots_come_from_in_front_of_the_left_goal_and_aim_at_the_mouth() -> void:
	for seed_value in [1, 2, 3, 4, 5]:
		var drill := await _setup(seed_value)
		drill.next_bits(DELTA)  # sets up the first shot
		var start := drill.ball.position
		check(start.x > MatchRules.GOAL_LINE_LEFT + 100.0 and start.x < MatchRules.CENTER.x, "start x %s" % start)
		var velocity := await _until_shot(drill)
		check(velocity.x < 0.0, "towards the left goal")
		check(velocity.length() >= 295.0 and velocity.length() <= 655.0, "speed %.0f in 300..650" % velocity.length())
		var t := (MatchRules.GOAL_LINE_LEFT - start.x) / velocity.x
		var y_at_line := start.y + velocity.y * t
		check(y_at_line > MatchRules.GOAL_MOUTH_TOP and y_at_line < MatchRules.GOAL_MOUTH_BOTTOM,
			"on target (y %.0f at the goal line)" % y_at_line)
		_world.queue_free()
		await get_tree().process_frame


func test_a_new_shot_is_set_up_after_the_ball_stops() -> void:
	var drill := await _setup(7)
	drill.next_bits(DELTA)
	var first := drill.ball.position
	await _until_shot(drill)
	drill.ball.velocity = Vector2.ZERO  # e.g. the keeper caught it
	var caught_at := drill.ball.position
	var ticks := 0
	while drill.ball.position == caught_at and ticks < int((ShootingDrill.REST_SECONDS + 0.5) / DELTA):
		drill.shooter.simulate(drill.next_bits(DELTA), DELTA)
		ticks += 1
	check(drill.ball.position != first and drill.ball.position != caught_at, "ball moved to a new spot")
	check(drill.ball.velocity == Vector2.ZERO, "resting, ready for the next shot")
	check(ticks * DELTA >= ShootingDrill.REST_SECONDS, "after the rest pause (%.2f s)" % (ticks * DELTA))
	_world.queue_free()
