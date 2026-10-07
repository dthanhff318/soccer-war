class_name MatchRules
extends RefCounted

## Pitch geometry and match timing shared by the server simulation and the
## offline game. Every line, wall and net is derived from the few sizes
## below (screen pixels at 1280x720): change PITCH_LENGTH and the drawn
## pitch, its walls, the goals and the kickoff spots all follow.

const CENTER := Vector2(640, 360)
## Goal line to goal line, and touchline to touchline.
const PITCH_LENGTH := 904.0
const PITCH_WIDTH := 565.0
## Width of the goal mouth, and how far the net reaches behind the goal line.
const GOAL_WIDTH := 136.6
const GOAL_DEPTH := 73.0
## Markings, scaled from a real 105 x 68 m pitch.
const PENALTY_BOX := Vector2(142.0, 335.0)   # depth from goal line, width
const GOAL_AREA := Vector2(47.0, 152.0)
const PENALTY_SPOT_DISTANCE := 95.0
const CENTER_CIRCLE_RADIUS := 76.0

const GOAL_LINE_LEFT := CENTER.x - PITCH_LENGTH / 2.0
const GOAL_LINE_RIGHT := CENTER.x + PITCH_LENGTH / 2.0
const TOUCHLINE_TOP := CENTER.y - PITCH_WIDTH / 2.0
const TOUCHLINE_BOTTOM := CENTER.y + PITCH_WIDTH / 2.0
const GOAL_MOUTH_TOP := CENTER.y - GOAL_WIDTH / 2.0
const GOAL_MOUTH_BOTTOM := CENTER.y + GOAL_WIDTH / 2.0

const MATCH_SECONDS := 300.0
## Ball stays in the net this long before the kickoff reset.
const CELEBRATION_SECONDS := 2.5
## Final score is shown this long before everyone returns to the lobby.
const RESULT_SECONDS := 5.0

## Kickoff spots for the left team as offsets from the centre spot, by
## player count; the right team mirrors them.
const FORMATIONS := [
	[],
	[Vector2(-168, 0)],
	[Vector2(-168, -60), Vector2(-168, 60)],
	[Vector2(-144, 0), Vector2(-264, -110), Vector2(-264, 110)],
	[Vector2(-144, -70), Vector2(-144, 70), Vector2(-288, -140), Vector2(-288, 140)],
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
	for offset: Vector2 in FORMATIONS[clampi(count, 0, FORMATIONS.size() - 1)]:
		var mirrored := offset if team == Roster.Team.LEFT else Vector2(-offset.x, offset.y)
		result.append(CENTER + mirrored)
	return result


## "m:ss", rounded up so the clock reads 0:00 only once time is over.
static func format_clock(seconds: float) -> String:
	var total := int(ceilf(maxf(seconds, 0.0)))
	return "%d:%02d" % [total / 60, total % 60]


static func result_text(score_left: int, score_right: int) -> String:
	if score_left == score_right:
		return "DRAW"
	var winner := Roster.Team.LEFT if score_left > score_right else Roster.Team.RIGHT
	return "%s WINS" % Teams.name_of(winner)
