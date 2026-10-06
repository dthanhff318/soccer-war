class_name MatchRules
extends RefCounted

## Pitch geometry and match timing shared by the server simulation and the
## offline game. Coordinates match the lines on field.png at 1280x720.

const GOAL_LINE_LEFT := 263.2
const GOAL_LINE_RIGHT := 1016.8
const GOAL_MOUTH_TOP := 291.8
const GOAL_MOUTH_BOTTOM := 428.4
const CENTER := Vector2(640, 360)

const MATCH_SECONDS := 300.0
## Ball stays in the net this long before the kickoff reset.
const CELEBRATION_SECONDS := 2.5
## Final score is shown this long before everyone returns to the lobby.
const RESULT_SECONDS := 5.0

## Indexed by Roster.Team; LEFT matches the scoreboard's home colour.
const TEAM_COLORS: Array[Color] = [Color(0.2, 0.35, 1.0), Color(0.95, 0.25, 0.25)]
const TEAM_NAMES: Array[String] = ["BLUE", "RED"]

## Kickoff spots for the left team, by player count; the right team mirrors them.
const FORMATIONS := [
	[],
	[Vector2(500, 360)],
	[Vector2(500, 300), Vector2(500, 420)],
	[Vector2(520, 360), Vector2(420, 250), Vector2(420, 470)],
	[Vector2(520, 290), Vector2(520, 430), Vector2(400, 220), Vector2(400, 500)],
]


## Team that scored once the whole ball is past a goal line inside the
## mouth, or -1. The left team attacks the right goal.
static func scoring_team(ball_pos: Vector2, radius: float) -> int:
	if ball_pos.y < GOAL_MOUTH_TOP or ball_pos.y > GOAL_MOUTH_BOTTOM:
		return -1
	if ball_pos.x + radius < GOAL_LINE_LEFT:
		return Roster.Team.RIGHT
	if ball_pos.x - radius > GOAL_LINE_RIGHT:
		return Roster.Team.LEFT
	return -1


static func kickoff_positions(team: int, count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for spot: Vector2 in FORMATIONS[clampi(count, 0, FORMATIONS.size() - 1)]:
		result.append(spot if team == Roster.Team.LEFT else Vector2(CENTER.x * 2.0 - spot.x, spot.y))
	return result


## "m:ss", rounded up so the clock reads 0:00 only once time is over.
static func format_clock(seconds: float) -> String:
	var total := int(ceilf(maxf(seconds, 0.0)))
	return "%d:%02d" % [total / 60, total % 60]


static func result_text(score_left: int, score_right: int) -> String:
	if score_left == score_right:
		return "DRAW"
	var winner := Roster.Team.LEFT if score_left > score_right else Roster.Team.RIGHT
	return "%s WINS" % TEAM_NAMES[winner]
