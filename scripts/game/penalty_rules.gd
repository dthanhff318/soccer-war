class_name PenaltyRules
extends RefCounted

## Penalty shootout scoring and geometry. Blue kicks first and teams
## alternate; five kicks each, finishing early once one side can no longer
## catch up, then sudden death until a round is won.

const REGULAR_KICKS := 5
## Keeper stands just in front of the right goal line, between the posts.
const KEEPER_X := MatchRules.GOAL_LINE_RIGHT - 18.0
const KEEPER_Y_RANGE := Vector2(
	MatchRules.GOAL_MOUTH_TOP + Player.BODY_RADIUS, MatchRules.GOAL_MOUTH_BOTTOM - Player.BODY_RADIUS)
## Shooter starts this far behind the ball, straight in line with the goal.
const SHOOTER_BACK_OFF := 40.0

## Kicks per team, in order: true = scored.
var _kicks: Array = [[], []]


static func spot() -> Vector2:
	return Vector2(MatchRules.GOAL_LINE_RIGHT - MatchRules.PENALTY_SPOT_DISTANCE, MatchRules.CENTER.y)


static func shooter_start() -> Vector2:
	return spot() - Vector2(SHOOTER_BACK_OFF, 0.0)


static func keeper_start() -> Vector2:
	return Vector2(KEEPER_X, MatchRules.CENTER.y)


func record(team: int, scored: bool) -> void:
	_kicks[team].append(scored)


## Team to kick next (blue whenever both have taken the same number).
func next_team() -> int:
	return Roster.Team.LEFT if kicks_taken(Roster.Team.LEFT) <= kicks_taken(Roster.Team.RIGHT) else Roster.Team.RIGHT


## Round of the next kick, starting at 1.
func round_number() -> int:
	return kicks_taken(next_team()) + 1


func is_sudden_death() -> bool:
	return round_number() > REGULAR_KICKS


func kicks_taken(team: int) -> int:
	return _kicks[team].size()


func goals(team: int) -> int:
	return _kicks[team].count(true)


func history(team: int) -> Array:
	return _kicks[team].duplicate()


func is_over() -> bool:
	return winner() != -1


## The winning team, or -1 while the shootout is still open.
func winner() -> int:
	var blue_kicks := kicks_taken(Roster.Team.LEFT)
	var red_kicks := kicks_taken(Roster.Team.RIGHT)
	var blue := goals(Roster.Team.LEFT)
	var red := goals(Roster.Team.RIGHT)
	if blue_kicks <= REGULAR_KICKS and red_kicks <= REGULAR_KICKS:
		# Regular kicks: over once the trailing side can't catch up with
		# the kicks it has left.
		if blue > red + (REGULAR_KICKS - red_kicks):
			return Roster.Team.LEFT
		if red > blue + (REGULAR_KICKS - blue_kicks):
			return Roster.Team.RIGHT
		return -1
	# Sudden death: decided only after both have kicked in the round.
	if blue_kicks == red_kicks and blue != red:
		return Roster.Team.LEFT if blue > red else Roster.Team.RIGHT
	return -1
