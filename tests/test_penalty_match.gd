extends TestCase

## The shootout scene: countdown freeze, line-locked keeper, one touch,
## goal / miss resolution and the end screen. Timers are shortened.

const PENALTY_SCENE := preload("res://scenes/penalty.tscn")

var _game: Node
## Input the "human" sends; tests change it as they go.
var _bits: int = 0


func _start(countdown: float = 0.05) -> void:
	_game = PENALTY_SCENE.instantiate()
	_game.countdown_seconds = countdown
	_game.result_seconds = 0.05
	_game.human_input = func() -> int: return _bits
	add_child(_game)


func _ticks(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _until_phase(phase: int, max_ticks: int = 300) -> bool:
	for i in max_ticks:
		if _game.phase == phase:
			return true
		await get_tree().physics_frame
	return _game.phase == phase


func _end() -> void:
	_bits = 0
	_game.queue_free()
	await get_tree().process_frame


func test_nobody_moves_during_the_countdown() -> void:
	_start(1.0)
	check(await _until_phase(PenaltyMatch.Phase.COUNTDOWN), "countdown")
	var start: Vector2 = _game.blue.position
	_bits = Protocol.IN_RIGHT | Protocol.IN_UP
	await _ticks(20)
	check_eq(_game.blue.position, start, "frozen")
	check(_game.countdown_label.visible, "3-2-1 shown")
	await _end()


func test_no_touch_in_time_is_a_miss_then_the_ai_kicks_and_you_keep() -> void:
	_start()
	_game.shot_timeout = 0.2
	check(await _until_phase(PenaltyMatch.Phase.RESULT), "result")
	check_eq(_game.rules.history(Roster.Team.LEFT), [false], "blue missed")
	check_eq(_game.banner.text, "MISSED!", "banner")
	check(await _until_phase(PenaltyMatch.Phase.LIVE), "red's kick")
	check(_game.keeper() == _game.blue and _game.blue.is_goalkeeper, "you are in goal")
	check(_game.shooter() == _game.red, "AI shoots")
	await _end()


func test_keeper_is_locked_on_the_goal_line_between_the_posts() -> void:
	_start()
	_game.shot_timeout = 0.1
	await _until_phase(PenaltyMatch.Phase.RESULT)
	await _until_phase(PenaltyMatch.Phase.LIVE)
	_game.shot_timeout = 60.0
	_bits = Protocol.IN_LEFT | Protocol.IN_UP | Protocol.IN_SPRINT
	await _ticks(45)
	check_near(_game.blue.position.x, PenaltyRules.KEEPER_X, 0.01, "stays on the line")
	check_near(_game.blue.position.y, PenaltyRules.KEEPER_Y_RANGE.x, 0.5, "stops at the post")
	await _end()


func test_shooter_gets_one_touch_only() -> void:
	_start()
	check(await _until_phase(PenaltyMatch.Phase.LIVE), "live")
	# Walk up to the ball, then a short kick.
	var guard := 0
	while _game.blue.position.distance_to(_game.ball.position) > 32.0 and guard < 120:
		_bits = Protocol.IN_RIGHT
		await _ticks(1)
		guard += 1
	_bits = Protocol.IN_KICK
	await _ticks(3)
	_bits = 0
	await _ticks(2)
	check(_game.touched, "touched")
	_bits = Protocol.IN_RIGHT | Protocol.IN_SPRINT
	await _ticks(20)
	var frozen_at: Vector2 = _game.blue.position
	await _ticks(20)
	check_eq(_game.blue.position, frozen_at, "no more control after the touch")
	await _end()


func test_ball_over_the_line_is_a_goal() -> void:
	_start()
	check(await _until_phase(PenaltyMatch.Phase.LIVE), "live")
	_game.ball.reset(Vector2(MatchRules.GOAL_LINE_RIGHT + 30.0, MatchRules.CENTER.y))
	check(await _until_phase(PenaltyMatch.Phase.RESULT, 5), "resolved")
	check_eq(_game.rules.history(Roster.Team.LEFT), [true], "blue scored")
	check_eq(_game.banner.text, "GOAL!", "banner")
	await _end()


func test_end_screen_when_the_shootout_is_decided() -> void:
	_start()
	await _until_phase(PenaltyMatch.Phase.LIVE)
	for i in 3:
		_game.rules.record(Roster.Team.LEFT, true)
		_game.rules.record(Roster.Team.RIGHT, false)
	_game.finish()
	check(_game.result_panel.visible, "end screen")
	check_eq(_game.result_title.text, "YOU WIN", "title")
	check_eq(_game.phase, PenaltyMatch.Phase.FINISHED, "finished")
	await _end()
