extends TestCase

## Each team wears its own shirt sprite, so online opponents are told apart.

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func test_each_team_gets_its_own_sprite() -> void:
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var player: Player = PLAYER_SCENE.instantiate()
		player.team = team
		add_child(player)
		var sprite: Sprite2D = player.get_node("Sprite")
		check_eq(sprite.texture, Teams.sprite_of(team), "team %d sprite" % team)
		player.queue_free()
	check(Teams.sprite_of(Roster.Team.LEFT) != Teams.sprite_of(Roster.Team.RIGHT), "teams differ")
	await get_tree().process_frame


func test_both_teams_draw_at_the_same_size() -> void:
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var player: Player = PLAYER_SCENE.instantiate()
		player.team = team
		add_child(player)
		var sprite: Sprite2D = player.get_node("Sprite")
		var drawn := sprite.texture.get_size() * sprite.scale
		check_near(maxf(drawn.x, drawn.y), Player.SPRITE_SIZE, 0.5, "team %d drawn size" % team)
		player.queue_free()
	await get_tree().process_frame


func test_power_bar_sits_above_the_player_and_name_below() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	var half := Player.SPRITE_SIZE / 2.0
	var bar := player.power_bar_rect()
	check(bar.end.y < -half, "bar above the head (bottom at %.1f)" % bar.end.y)
	check(bar.end.y > -half - 20.0, "bar close to the head")
	check_near(bar.get_center().x, 0.0, 0.5, "bar centred")
	var name_top := player.name_top()
	check(name_top > half, "name below the feet (top at %.1f)" % name_top)
	check(name_top < half + 20.0, "name close to the feet")
	player.queue_free()
	await get_tree().process_frame


func test_players_are_drawn_and_collide_at_0_8_of_the_old_size() -> void:
	check_near(Player.SPRITE_SIZE, 33.0 * 0.8, 0.01, "sprite")
	check_near(Player.RING_RADIUS, 18.0 * 0.8, 0.01, "ring")
	check_near(Player.BODY_RADIUS, 16.0 * 0.8, 0.01, "body")
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	var body: CircleShape2D = player.get_node("Collision").shape
	check_near(body.radius, Player.BODY_RADIUS, 0.01, "collision matches the drawing")
	player.queue_free()
	await get_tree().process_frame
