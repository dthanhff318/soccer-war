extends TestCase

## Goalkeeper saves: slower than 300 px/s is caught dead where it touches;
## faster spills back at 20 % (at 300) rising to 45 % (at 650) of its speed.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const DELTA := 1.0 / 60.0

var _world: SubViewport


func _setup() -> void:
	_world = SubViewport.new()
	_world.world_2d = World2D.new()
	add_child(_world)


func _player(pos: Vector2, keeper: bool) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = pos
	player.is_goalkeeper = keeper
	_world.add_child(player)
	return player


func _ball(pos: Vector2) -> Ball:
	var ball: Ball = BALL_SCENE.instantiate()
	ball.simulated = false
	ball.position = pos
	_world.add_child(ball)
	return ball


func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame


## Steps the ball until its velocity flips direction or stops; returns the
## speed just before and just after that tick.
func _shoot_at(ball: Ball, velocity: Vector2) -> Vector2:
	ball.velocity = velocity
	for i in 120:
		var before := ball.velocity
		ball.step(DELTA)
		if ball.velocity.x <= 0.0:
			return Vector2(before.length(), ball.velocity.length())
	return Vector2(-1, -1)


func test_rebound_ratio_rises_from_20_to_45_percent() -> void:
	check_near(Ball.keeper_rebound_speed(299.0), 0.0, 0.001, "caught below 300")
	check_near(Ball.keeper_rebound_speed(300.0), 60.0, 0.01, "300 -> 60")
	check_near(Ball.keeper_rebound_speed(650.0), 292.5, 0.01, "650 -> 292.5")
	check_near(Ball.keeper_rebound_speed(475.0), 475.0 * 0.325, 0.01, "halfway ratio")
	check_near(Ball.keeper_rebound_speed(900.0), 900.0 * 0.45, 0.01, "capped at 45 %")


func test_slow_shot_is_caught_where_it_touches() -> void:
	_setup()
	var keeper := _player(Vector2(400, 300), true)
	var ball := _ball(Vector2(300, 300))
	await _settle()
	var speeds := _shoot_at(ball, Vector2(290, 0))
	check_eq(speeds.y, 0.0, "stopped dead")
	check(keeper.position.x - ball.position.x < 29.0, "resting against the keeper")
	_world.queue_free()


func test_hard_shot_spills_back_softly() -> void:
	_setup()
	_player(Vector2(400, 300), true)
	var ball := _ball(Vector2(250, 300))
	await _settle()
	var speeds := _shoot_at(ball, Vector2(650, 0))
	check(ball.velocity.x < 0.0, "bounced back")
	# Drag slows the ball by drag * delta within the tick, before it reaches the keeper.
	var at_impact := speeds.x - ball.drag * DELTA
	check_near(speeds.y, Ball.keeper_rebound_speed(at_impact), 1.0, "keeper rebound for %.0f" % at_impact)
	_world.queue_free()


func test_outfield_player_still_bounces_hard() -> void:
	_setup()
	_player(Vector2(400, 300), false)
	var ball := _ball(Vector2(250, 300))
	await _settle()
	var speeds := _shoot_at(ball, Vector2(650, 0))
	check(speeds.y > speeds.x * 0.7, "normal 80%% bounce (%.0f -> %.0f)" % [speeds.x, speeds.y])
	_world.queue_free()


func test_keeper_walking_into_a_slow_ball_does_not_push_it() -> void:
	_setup()
	var keeper := _player(Vector2(300, 300), true)
	var ball := _ball(Vector2(331, 300))
	await _settle()
	for i in 20:
		keeper.simulate(Protocol.IN_RIGHT, DELTA)
		ball.step(DELTA)
	check(ball.velocity.length() < 1.0, "ball stays at the keeper's feet")
	_world.queue_free()


func test_ai_follows_the_ball_along_the_goal_area() -> void:
	var line := MatchRules.GOAL_LINE_RIGHT
	var home := GoalkeeperAI.home_position(1)
	check(home.x < line and home.x > line - MatchRules.GOAL_AREA.x, "stands inside the goal area")
	check_eq(GoalkeeperAI.bits_for(home, home + Vector2(-200, -50), 1), Protocol.IN_UP, "ball above -> up")
	check_eq(GoalkeeperAI.bits_for(home, home + Vector2(-200, 50), 1), Protocol.IN_DOWN, "ball below -> down")
	check_eq(GoalkeeperAI.bits_for(home, home + Vector2(-200, 1), 1), 0, "level -> still")
	var top := Vector2(home.x, MatchRules.CENTER.y - GoalkeeperAI.MAX_OFFSET)
	check_eq(GoalkeeperAI.bits_for(top, Vector2(500, 0), 1), 0, "stops at the edge of the goal area")
	check_eq(GoalkeeperAI.bits_for(home + Vector2(-30, 0), home + Vector2(-200, 0), 1), Protocol.IN_RIGHT, "walks back onto its line")
