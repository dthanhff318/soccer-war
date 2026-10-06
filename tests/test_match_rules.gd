extends TestCase

const R := 11.2


func test_no_goal_while_ball_on_pitch() -> void:
	check_eq(MatchRules.scoring_team(MatchRules.CENTER, R), -1, "centre")


func test_ball_wholly_past_right_line_scores_for_left() -> void:
	var pos := Vector2(MatchRules.GOAL_LINE_RIGHT + R + 1.0, 360)
	check_eq(MatchRules.scoring_team(pos, R), Roster.Team.LEFT, "right goal")


func test_ball_wholly_past_left_line_scores_for_right() -> void:
	var pos := Vector2(MatchRules.GOAL_LINE_LEFT - R - 1.0, 360)
	check_eq(MatchRules.scoring_team(pos, R), Roster.Team.RIGHT, "left goal")


func test_ball_on_the_line_is_not_a_goal() -> void:
	var pos := Vector2(MatchRules.GOAL_LINE_RIGHT + R - 1.0, 360)
	check_eq(MatchRules.scoring_team(pos, R), -1, "partly over")


func test_ball_outside_goal_mouth_is_not_a_goal() -> void:
	var pos := Vector2(MatchRules.GOAL_LINE_RIGHT + 50.0, MatchRules.GOAL_MOUTH_TOP - 5.0)
	check_eq(MatchRules.scoring_team(pos, R), -1, "above mouth")


func test_kickoff_positions_mirror_for_right_team() -> void:
	for count in range(0, 5):
		var left := MatchRules.kickoff_positions(Roster.Team.LEFT, count)
		var right := MatchRules.kickoff_positions(Roster.Team.RIGHT, count)
		check_eq(left.size(), count, "left count %d" % count)
		check_eq(right.size(), count, "right count %d" % count)
		for i in count:
			check(left[i].x < MatchRules.CENTER.x, "left half")
			check_near(right[i].x, MatchRules.CENTER.x * 2.0 - left[i].x, 0.001, "mirrored x")
			check_near(right[i].y, left[i].y, 0.001, "same y")


func test_format_clock_rounds_up() -> void:
	check_eq(MatchRules.format_clock(300.0), "5:00", "full")
	check_eq(MatchRules.format_clock(299.2), "5:00", "just started")
	check_eq(MatchRules.format_clock(298.9), "4:59", "a second in")
	check_eq(MatchRules.format_clock(0.3), "0:01", "last moment")
	check_eq(MatchRules.format_clock(-2.0), "0:00", "over")


func test_result_text() -> void:
	check_eq(MatchRules.result_text(2, 2), "DRAW", "draw")
	check_eq(MatchRules.result_text(3, 1), "BLUE WINS", "left")
	check_eq(MatchRules.result_text(0, 1), "RED WINS", "right")
