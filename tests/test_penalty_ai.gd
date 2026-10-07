extends TestCase

## Penalty AI: the shooter lines up and strikes on target; the keeper guesses
## a side when the ball is hit and moves along its line towards it.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const DELTA := 1.0 / 60.0

var _world: SubViewport


func _setup() -> Array:
	_world = SubViewport.new()
	_world.world_2d = World2D.new()
	add_child(_world)
	var shooter: Player = PLAYER_SCENE.instantiate()
	shooter.position = PenaltyRules.shooter_start()
	_world.add_child(shooter)
	var ball: Ball = BALL_SCENE.instantiate()
	ball.simulated = false
	ball.position = PenaltyRules.spot()
	_world.add_child(ball)
	for i in 3:
		await get_tree().physics_frame
	return [shooter, ball]


func test_shooter_strikes_the_ball_cleanly_and_mostly_on_target() -> void:
	var on_target := 0
	for seed_value in range(1, 9):
		var parts := await _setup()
		var shooter: Player = parts[0]
		var ball: Ball = parts[1]
		var brain := PenaltyAI.ShooterBrain.new(seed_value)
		var hit := Vector2.ZERO
		for i in 240:
			shooter.simulate(brain.bits(shooter.position, ball.position), DELTA)
			ball.step(DELTA)
			if ball.velocity.length() > 1.0:
				hit = ball.velocity
				break
			await get_tree().physics_frame
		check(hit.length() >= 295.0, "seed %d: a real kick, not a nudge (%.0f)" % [seed_value, hit.length()])
		if hit.x > 0.0:
			var t := (MatchRules.GOAL_LINE_RIGHT - ball.position.x) / hit.x
			var y := ball.position.y + hit.y * t
			if y > MatchRules.GOAL_MOUTH_TOP and y < MatchRules.GOAL_MOUTH_BOTTOM:
				on_target += 1
		_world.queue_free()
		await get_tree().process_frame
	check(on_target >= 6, "most shots on target (%d / 8)" % on_target)


func test_shooter_waits_and_hides_its_aim_at_first() -> void:
	var brain := PenaltyAI.ShooterBrain.new(3)
	check_eq(brain.bits(PenaltyRules.shooter_start(), PenaltyRules.spot()), 0, "pauses before moving")


func test_keeper_moves_only_up_or_down_towards_its_guess_after_reacting() -> void:
	var brain := PenaltyAI.KeeperBrain.new(5)
	var start := PenaltyRules.keeper_start()
	check_eq(brain.bits(start, DELTA), 0, "waits in the middle before the kick")
	brain.on_shot(PenaltyRules.spot(), Vector2(600, -80))
	var target := brain.target_y
	check(target >= PenaltyRules.KEEPER_Y_RANGE.x and target <= PenaltyRules.KEEPER_Y_RANGE.y, "guess inside the posts")
	check_eq(brain.bits(start, DELTA), 0, "reaction delay")
	var bits := 0
	for i in 30:
		bits = brain.bits(start, DELTA)
	var expected := 0
	if target < start.y - PenaltyAI.KeeperBrain.DEADZONE:
		expected = Protocol.IN_UP
	elif target > start.y + PenaltyAI.KeeperBrain.DEADZONE:
		expected = Protocol.IN_DOWN
	check_eq(bits, expected, "heads for the guess")


func test_keeper_guesses_the_right_side_more_often_than_not() -> void:
	var right := 0
	for seed_value in range(200):
		var brain := PenaltyAI.KeeperBrain.new(seed_value)
		brain.on_shot(PenaltyRules.spot(), Vector2(600, -80))
		var predicted := PenaltyAI.KeeperBrain.predict_y(PenaltyRules.spot(), Vector2(600, -80))
		if absf(brain.target_y - predicted) < 1.0:
			right += 1
	check(right > 90 and right < 150, "about 60 %% right (%d / 200)" % right)
