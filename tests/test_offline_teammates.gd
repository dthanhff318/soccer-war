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
			else:
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
