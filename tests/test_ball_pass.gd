extends TestCase

## Passing and the "pass stops dead on a player" rule, in a real physics world.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const DELTA := 1.0 / 60.0

var _world: SubViewport


func _setup() -> void:
	_world = SubViewport.new()
	_world.world_2d = World2D.new()
	add_child(_world)


func _teardown() -> void:
	_world.queue_free()


func _player(pos: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = pos
	_world.add_child(player)
	return player


func _ball(pos: Vector2) -> Ball:
	var ball: Ball = BALL_SCENE.instantiate()
	ball.simulated = false
	ball.position = pos
	_world.add_child(ball)
	return ball


func _wall(pos: Vector2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 400)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = pos
	_world.add_child(wall)


## Lets the physics server register new bodies and area overlaps.
func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame


func _step(ball: Ball, ticks: int) -> void:
	for i in ticks:
		ball.step(DELTA)


func test_pass_goes_in_running_direction_with_pass_strength() -> void:
	_setup()
	var player := _player(Vector2(100, 100))
	var ball := _ball(Vector2(130, 100))
	await _settle()
	player.simulate(Protocol.IN_UP | Protocol.IN_PASS, DELTA)
	check(ball.is_pass, "ball is a pass")
	check_near(ball.velocity.normalized().dot(Vector2.UP), 1.0, 0.001, "goes up, the running direction")
	check_near(ball.velocity.length(), player.pass_strength, 0.5, "pass strength")
	_teardown()


func test_pass_that_hits_a_player_stops_dead() -> void:
	_setup()
	var receiver := _player(Vector2(300, 100))
	var ball := _ball(Vector2(100, 100))
	await _settle()
	ball.start_pass(Vector2(420, 0))
	_step(ball, 60)
	check_eq(ball.velocity, Vector2.ZERO, "stopped")
	check(not ball.is_pass, "no longer a pass")
	var gap := receiver.position.x - ball.position.x
	check(gap > 26.0 and gap < 30.0, "rests against the receiver (gap %.1f)" % gap)
	var resting := ball.position
	_step(ball, 30)
	check_eq(ball.position, resting, "stays where it stopped")
	_teardown()


func test_receiver_running_into_a_pass_traps_it() -> void:
	_setup()
	var receiver := _player(Vector2(200, 100))
	var ball := _ball(Vector2(100, 100))
	await _settle()
	ball.start_pass(Vector2(420, 0))
	for i in 30:
		receiver.simulate(Protocol.IN_LEFT, DELTA)
		ball.step(DELTA)
	check(not ball.is_pass, "pass ended on contact")
	check(ball.velocity.length() < receiver.move_speed * 1.3, "trapped, not knocked away (%.0f)" % ball.velocity.length())
	_teardown()


func test_kick_that_hits_a_player_still_bounces() -> void:
	_setup()
	_player(Vector2(300, 100))
	var ball := _ball(Vector2(100, 100))
	await _settle()
	ball.kick(Vector2(700, 0))
	_step(ball, 30)
	check(ball.velocity.x < 0.0, "bounced back off the player")
	_teardown()


func test_pass_off_a_wall_becomes_a_normal_ball() -> void:
	_setup()
	_wall(Vector2(250, 100))
	_player(Vector2(20, 100))
	var ball := _ball(Vector2(100, 100))
	await _settle()
	ball.start_pass(Vector2(600, 0))
	_step(ball, 20)
	check(not ball.is_pass, "wall ends the pass")
	check(ball.velocity.x < 0.0, "bounced off the wall")
	_step(ball, 40)
	check(ball.velocity.x > 0.0, "then bounces off the player like any ball")
	_teardown()


func test_pass_ends_when_the_ball_stops_rolling() -> void:
	_setup()
	var ball := _ball(Vector2(100, 100))
	await _settle()
	ball.start_pass(Vector2(30, 0))
	_step(ball, 30)
	check_eq(ball.velocity, Vector2.ZERO, "rolled to a stop")
	check(not ball.is_pass, "no longer a pass")
	_teardown()


func test_kick_cancels_a_pass() -> void:
	_setup()
	var ball := _ball(Vector2(100, 100))
	await _settle()
	ball.start_pass(Vector2(300, 0))
	ball.kick(Vector2(0, 500))
	check(not ball.is_pass, "kick turns it into a shot")
	_teardown()
