class_name GoalkeeperAI
extends RefCounted

## Practice keeper: stands just in front of its goal line and slides up and
## down to stay level with the ball, never leaving the goal area. Produces
## the same input bits a human would send.

## Distance in front of the goal line the keeper stands.
const LINE_OFFSET := 24.0
## Furthest the keeper moves from the centre line (inside the goal area).
const MAX_OFFSET := MatchRules.GOAL_AREA.y / 2.0 - Player.BODY_RADIUS
## Close enough: no input, so the keeper doesn't jitter around its target.
const DEADZONE := 4.0


## Where the keeper of the goal on `side` (-1 left, 1 right) stands.
static func home_position(side: int) -> Vector2:
	var line := MatchRules.GOAL_LINE_LEFT if side < 0 else MatchRules.GOAL_LINE_RIGHT
	return Vector2(line - side * LINE_OFFSET, MatchRules.CENTER.y)


static func bits_for(keeper_pos: Vector2, ball_pos: Vector2, side: int) -> int:
	var home := home_position(side)
	var target_y := clampf(ball_pos.y, MatchRules.CENTER.y - MAX_OFFSET, MatchRules.CENTER.y + MAX_OFFSET)
	var bits := 0
	if target_y < keeper_pos.y - DEADZONE:
		bits |= Protocol.IN_UP
	elif target_y > keeper_pos.y + DEADZONE:
		bits |= Protocol.IN_DOWN
	if keeper_pos.x < home.x - DEADZONE:
		bits |= Protocol.IN_RIGHT
	elif keeper_pos.x > home.x + DEADZONE:
		bits |= Protocol.IN_LEFT
	return bits
