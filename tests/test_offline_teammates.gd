extends TestCase

## Offline practice: the match scene adds stationary teammates to pass to.

const MATCH_SCENE := preload("res://scenes/main.tscn")


func test_offline_match_has_three_stationary_teammates() -> void:
	var game: Node = MATCH_SCENE.instantiate()
	add_child(game)
	for i in 30:
		await get_tree().physics_frame

	var mates: Array[Player] = []
	var keyboard_players := 0
	for child in game.get_children():
		if child is Player:
			if child.keyboard_control:
				keyboard_players += 1
			elif not child.is_goalkeeper:
				mates.append(child)
	check_eq(keyboard_players, 1, "one player on the keyboard")
	check_eq(mates.size(), 3, "three teammates")

	var spots: Array = game.OFFLINE_TEAMMATE_SPOTS
	for i in mates.size():
		check_eq(mates[i].team, Roster.Team.LEFT, "teammate %d is blue" % i)
		check_eq(mates[i].display_name, "Mate %d" % (i + 1), "teammate %d name" % i)
		check_eq(mates[i].position, spots[i], "teammate %d did not move" % i)
	game.queue_free()
	await get_tree().process_frame


func test_practice_has_an_opponent_goalkeeper() -> void:
	var game: Node = MATCH_SCENE.instantiate()
	add_child(game)
	await get_tree().physics_frame
	var keepers: Array = game.get_children().filter(func(n): return n is Player and n.is_goalkeeper)
	check_eq(keepers.size(), 1, "one keeper")
	if keepers.size() == 1:
		check_eq(keepers[0].team, Roster.Team.RIGHT, "on the red team")
		check_eq(keepers[0].position, GoalkeeperAI.home_position(1), "in front of the right goal")
	game.queue_free()
	await get_tree().process_frame
