extends TestCase

## Crowd sounds: a looping crowd bed while a match runs, a loud cheer on
## every goal, in free play, online and the penalty shootout.

const MATCH_SCENE := preload("res://scenes/main.tscn")
const PENALTY_SCENE := preload("res://scenes/penalty.tscn")


func test_crowd_bed_loops_and_starts_with_the_match() -> void:
	var audio := MatchAudio.new()
	add_child(audio)
	await get_tree().process_frame
	check(audio.crowd.stream.loop, "crowd bed loops")
	check(audio.crowd.playing, "crowd bed playing")
	check(not audio.cheer.stream.loop, "cheer plays once")
	check(not audio.cheer.playing, "no cheer yet")
	audio.play_goal()
	check(audio.cheer.playing, "cheer on goal")
	audio.queue_free()


func test_free_play_goal_cheers() -> void:
	var game: Node = MATCH_SCENE.instantiate()
	add_child(game)
	await get_tree().physics_frame
	var audio: MatchAudio = game.get_node("MatchAudio")
	check(audio.crowd.playing, "crowd during free play")
	game._ball.reset(Vector2(MatchRules.GOAL_LINE_RIGHT + 30.0, MatchRules.CENTER.y))
	check(await wait_until(func(): return audio.cheer.playing, 30), "cheer after the goal")
	game.queue_free()
	await get_tree().process_frame


func test_penalty_goal_cheers() -> void:
	var game: PenaltyMatch = PENALTY_SCENE.instantiate()
	game.countdown_seconds = 0.05
	game.human_input = func() -> int: return 0
	add_child(game)
	var audio: MatchAudio = game.get_node("MatchAudio")
	check(await wait_until(func(): return game.phase == PenaltyMatch.Phase.LIVE, 60), "live")
	check(audio.crowd.playing, "crowd during the shootout")
	game.ball.reset(Vector2(MatchRules.GOAL_LINE_RIGHT + 30.0, MatchRules.CENTER.y))
	check(await wait_until(func(): return audio.cheer.playing, 10), "cheer after the goal")
	game.queue_free()
	await get_tree().process_frame
