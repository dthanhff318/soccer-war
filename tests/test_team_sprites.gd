extends TestCase

## Each team wears its own shirt sprite, so online opponents are told apart.

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func test_each_team_gets_its_own_sprite() -> void:
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var player: Player = PLAYER_SCENE.instantiate()
		player.team = team
		add_child(player)
		var sprite: Sprite2D = player.get_node("Sprite")
		check_eq(sprite.texture, Player.TEAM_SPRITES[team], "team %d sprite" % team)
		player.queue_free()
	check(Player.TEAM_SPRITES[Roster.Team.LEFT] != Player.TEAM_SPRITES[Roster.Team.RIGHT], "teams differ")
	await get_tree().process_frame
