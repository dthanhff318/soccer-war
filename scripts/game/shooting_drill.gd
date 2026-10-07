class_name ShootingDrill
extends Node

## Keeper practice. Over and over: put the ball on a random spot in front of
## the left goal, stand the shooter behind it on the line to a random point
## of the goal mouth, hold Space for a random time, release, and wait for
## the ball to come to rest before the next shot.

## How far in front of the goal line, and how far off centre, shots start.
const DISTANCE_RANGE := Vector2(150.0, 300.0)
const SIDEWAYS_RANGE := 140.0
## Aim this far inside the posts so shots are on target.
const POST_MARGIN := 12.0
## Shooter stands this far behind the ball: just clear of it, within reach.
const SHOOTER_GAP := 30.0
## Held ticks of Space: a quick tap up to a full one-second charge.
const HOLD_TICKS := Vector2i(1, 60)
## Pause between the ball stopping (or a shot going on too long) and the next shot.
const REST_SECONDS := 1.2
const MAX_FLIGHT_SECONDS := 3.0

enum State { SETUP, CHARGING, FLIGHT, REST }

var shooter: Player
var ball: Ball
var _rng := RandomNumberGenerator.new()
var _state: int = State.SETUP
var _ticks_left: int = 0
var _timer: float = 0.0


func _init(drill_shooter: Player, drill_ball: Ball, seed_value: int = -1) -> void:
	shooter = drill_shooter
	ball = drill_ball
	name = "ShootingDrill"
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## Input bits for the shooter this tick; also moves the drill along.
func next_bits(delta: float) -> int:
	match _state:
		State.SETUP:
			_line_up()
			_state = State.CHARGING
			return Protocol.IN_KICK
		State.CHARGING:
			_ticks_left -= 1
			if _ticks_left > 0:
				return Protocol.IN_KICK
			_state = State.FLIGHT
			_timer = 0.0
			return 0  # releasing Space kicks
		State.FLIGHT:
			_timer += delta
			if ball.velocity.length() < 1.0 or _timer > MAX_FLIGHT_SECONDS:
				_state = State.REST
				_timer = 0.0
		State.REST:
			_timer += delta
			if _timer >= REST_SECONDS:
				_state = State.SETUP
	return 0


## Ball on a fresh spot, shooter right behind it facing a point in the goal.
func _line_up() -> void:
	var start := Vector2(
		MatchRules.GOAL_LINE_LEFT + _rng.randf_range(DISTANCE_RANGE.x, DISTANCE_RANGE.y),
		MatchRules.CENTER.y + _rng.randf_range(-SIDEWAYS_RANGE, SIDEWAYS_RANGE))
	var target := Vector2(MatchRules.GOAL_LINE_LEFT, _rng.randf_range(
		MatchRules.GOAL_MOUTH_TOP + POST_MARGIN, MatchRules.GOAL_MOUTH_BOTTOM - POST_MARGIN))
	var aim := (target - start).normalized()
	ball.reset(start)
	shooter.position = start - aim * SHOOTER_GAP
	shooter.velocity = Vector2.ZERO
	_ticks_left = _rng.randi_range(HOLD_TICKS.x, HOLD_TICKS.y)
