extends TestCase

## Shootout scoring: five each, stop when it can't be caught, then sudden death.

const BLUE := Roster.Team.LEFT
const RED := Roster.Team.RIGHT


## Plays alternating kicks starting with blue: "1" scored, "0" missed.
func _play(blue: String, red: String) -> PenaltyRules:
	var rules := PenaltyRules.new()
	for i in maxi(blue.length(), red.length()):
		if i < blue.length():
			check_eq(rules.next_team(), BLUE, "blue's turn at kick %d" % i)
			rules.record(BLUE, blue[i] == "1")
		if i < red.length():
			check_eq(rules.next_team(), RED, "red's turn at kick %d" % i)
			rules.record(RED, red[i] == "1")
	return rules


func test_blue_kicks_first_and_teams_alternate() -> void:
	var rules := PenaltyRules.new()
	check_eq(rules.next_team(), BLUE, "first")
	check_eq(rules.round_number(), 1, "round 1")
	rules.record(BLUE, true)
	check_eq(rules.next_team(), RED, "second")
	check_eq(rules.round_number(), 1, "still round 1")
	rules.record(RED, false)
	check_eq(rules.round_number(), 2, "round 2")


func test_five_rounds_most_goals_wins() -> void:
	var rules := _play("11011", "11010")
	check(rules.is_over(), "over")
	check_eq(rules.winner(), BLUE, "blue 4-3")
	check_eq(rules.goals(BLUE), 4, "blue goals")
	check_eq(rules.goals(RED), 3, "red goals")


func test_stops_early_when_it_cannot_be_caught() -> void:
	var rules := _play("111", "00")
	check(not rules.is_over(), "3-0 after 3 blue / 2 red: red still has 3 kicks")
	rules.record(RED, false)
	check(rules.is_over(), "3-0 with 2 kicks left each: over")
	check_eq(rules.winner(), BLUE, "blue")


func test_red_can_win_early_before_blue_kicks_again() -> void:
	var rules := _play("0000", "1111")
	check(rules.is_over(), "0-4 with one blue kick left")
	check_eq(rules.winner(), RED, "red")


func test_level_after_five_goes_to_sudden_death() -> void:
	var rules := _play("11100", "11010")
	check(not rules.is_over(), "3-3")
	check(rules.is_sudden_death(), "sudden death next")
	check_eq(rules.round_number(), 6, "round 6")
	rules.record(BLUE, true)
	check(not rules.is_over(), "red must answer")
	rules.record(RED, true)
	check(not rules.is_over(), "both scored, round 7")
	rules.record(BLUE, false)
	rules.record(RED, true)
	check(rules.is_over(), "red scored, blue missed")
	check_eq(rules.winner(), RED, "red wins in sudden death")
	check_eq(rules.kicks_taken(BLUE), 7, "seven kicks")


func test_kick_history_for_the_dots() -> void:
	var rules := _play("10", "01")
	check_eq(rules.history(BLUE), [true, false], "blue")
	check_eq(rules.history(RED), [false, true], "red")


func test_spot_and_keeper_line_geometry() -> void:
	var spot := PenaltyRules.spot()
	check_near(MatchRules.GOAL_LINE_RIGHT - spot.x, MatchRules.PENALTY_SPOT_DISTANCE, 0.01, "spot distance")
	check_near(spot.y, MatchRules.CENTER.y, 0.01, "centred")
	check(PenaltyRules.KEEPER_X < MatchRules.GOAL_LINE_RIGHT, "keeper stands just in front of the line")
	check(PenaltyRules.KEEPER_Y_RANGE.x > MatchRules.GOAL_MOUTH_TOP, "keeper between the posts (top)")
	check(PenaltyRules.KEEPER_Y_RANGE.y < MatchRules.GOAL_MOUTH_BOTTOM, "keeper between the posts (bottom)")
