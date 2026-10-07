class_name PenaltyAI
extends RefCounted

## AI for the penalty shootout. Both brains return the same input bits a
## human sends, so the AI plays by the same rules (one touch, line-locked
## keeper) as the player.


## Waits a moment, picks a point in the goal, steps onto the line through the
## ball towards it, charges and releases.
class ShooterBrain:
	## Ticks of hesitation after the whistle (keeps the aim hidden a little).
	const WAIT_TICKS := Vector2i(12, 40)
	## Aim this far inside the posts.
	const POST_MARGIN := 16.0
	## Stand this far behind the ball: clear of it, but within kicking reach.
	const STRIKE_GAP := 34.0
	## Close enough to the strike spot to stop walking (momentum carries a bit).
	const ARRIVE := 8.0
	const HOLD_TICKS := Vector2i(18, 60)

	var _rng := RandomNumberGenerator.new()
	var _wait: int
	var _hold: int
	var _aim_y: float
	var _in_position: bool = false
	var _released: bool = false

	func _init(seed_value: int = -1) -> void:
		if seed_value >= 0:
			_rng.seed = seed_value
		else:
			_rng.randomize()
		_wait = _rng.randi_range(WAIT_TICKS.x, WAIT_TICKS.y)
		_hold = _rng.randi_range(HOLD_TICKS.x, HOLD_TICKS.y)
		_aim_y = _rng.randf_range(MatchRules.GOAL_MOUTH_TOP + POST_MARGIN, MatchRules.GOAL_MOUTH_BOTTOM - POST_MARGIN)

	func bits(shooter_pos: Vector2, ball_pos: Vector2) -> int:
		if _released:
			return 0
		if _wait > 0:
			_wait -= 1
			return 0
		var aim := (Vector2(MatchRules.GOAL_LINE_RIGHT, _aim_y) - ball_pos).normalized()
		var strike_spot := ball_pos - aim * STRIKE_GAP
		if not _in_position:
			var to_spot := strike_spot - shooter_pos
			if to_spot.length() > ARRIVE:
				return _walk(to_spot)
			_in_position = true
		if _hold > 0:
			_hold -= 1
			return Protocol.IN_KICK
		_released = true
		return 0

	static func _walk(direction: Vector2) -> int:
		var result := 0
		if direction.x > 2.0:
			result |= Protocol.IN_RIGHT
		elif direction.x < -2.0:
			result |= Protocol.IN_LEFT
		if direction.y > 2.0:
			result |= Protocol.IN_DOWN
		elif direction.y < -2.0:
			result |= Protocol.IN_UP
		return result


## Stays central until the ball is struck, then commits to a guess (right
## about GUESS_RIGHT_CHANCE of the time) and moves along the line towards it.
class KeeperBrain:
	const GUESS_RIGHT_CHANCE := 0.6
	const REACTION_SECONDS := Vector2(0.1, 0.2)
	const DEADZONE := 3.0

	## Where the keeper is heading on the line.
	var target_y: float = MatchRules.CENTER.y
	var _rng := RandomNumberGenerator.new()
	var _reaction_left: float = -1.0

	func _init(seed_value: int = -1) -> void:
		if seed_value >= 0:
			_rng.seed = seed_value
		else:
			_rng.randomize()

	## Where a ball from `ball_pos` moving at `velocity` crosses the keeper's line.
	static func predict_y(ball_pos: Vector2, velocity: Vector2) -> float:
		if velocity.x <= 0.0:
			return MatchRules.CENTER.y
		var t := (PenaltyRules.KEEPER_X - ball_pos.x) / velocity.x
		return clampf(ball_pos.y + velocity.y * t, PenaltyRules.KEEPER_Y_RANGE.x, PenaltyRules.KEEPER_Y_RANGE.y)

	func on_shot(ball_pos: Vector2, velocity: Vector2) -> void:
		var predicted := predict_y(ball_pos, velocity)
		if _rng.randf() < GUESS_RIGHT_CHANCE:
			target_y = predicted
		else:
			# Commit to one of the other two thirds of the goal.
			var zones := [PenaltyRules.KEEPER_Y_RANGE.x, MatchRules.CENTER.y, PenaltyRules.KEEPER_Y_RANGE.y]
			zones.sort_custom(func(a, b): return absf(a - predicted) < absf(b - predicted))
			target_y = zones[_rng.randi_range(1, 2)]
		_reaction_left = _rng.randf_range(REACTION_SECONDS.x, REACTION_SECONDS.y)

	func bits(keeper_pos: Vector2, delta: float) -> int:
		if _reaction_left < 0.0:
			return _towards(keeper_pos.y, MatchRules.CENTER.y)
		if _reaction_left > 0.0:
			_reaction_left = maxf(_reaction_left - delta, 0.0)
			return 0
		return _towards(keeper_pos.y, target_y)

	static func _towards(from_y: float, to_y: float) -> int:
		if to_y < from_y - DEADZONE:
			return Protocol.IN_UP
		if to_y > from_y + DEADZONE:
			return Protocol.IN_DOWN
		return 0
