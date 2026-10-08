extends TestCase

## Players are drawn in code by default (a shirt in the team colour); a
## texture can still be dropped in per team or per player.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ANY_TEXTURE := preload("res://assets/field/player/18.png")


func _make(team: int, texture: Texture2D = null, keeper: bool = false) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.team = team
	player.is_goalkeeper = keeper
	if texture:
		player.sprite_texture = texture
	add_child(player)
	return player


func test_players_are_drawn_in_code_by_default() -> void:
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var player := _make(team)
		var look: PlayerLook = player.get_node("Look")
		check(look.visible, "drawn look for team %d" % team)
		check(not player.get_node("Sprite").visible, "no image for team %d" % team)
		check_eq(look.shirt_color, Teams.color_of(team), "shirt in the team colour")
		player.queue_free()
	await get_tree().process_frame


func test_goalkeepers_wear_a_different_shirt() -> void:
	var keeper := _make(Roster.Team.LEFT, null, true)
	await get_tree().process_frame
	var look: PlayerLook = keeper.get_node("Look")
	check(look.shirt_color != Teams.color_of(Roster.Team.LEFT), "keeper shirt")
	check(look.gloves, "keeper gloves")
	keeper.queue_free()
	await get_tree().process_frame


func test_an_image_can_replace_the_drawing_at_the_same_size() -> void:
	var player := _make(Roster.Team.RIGHT, ANY_TEXTURE)
	var sprite: Sprite2D = player.get_node("Sprite")
	check(sprite.visible, "image shown")
	check(not player.has_node("Look") or not player.get_node("Look").visible, "no drawing")
	var drawn := sprite.texture.get_size() * sprite.scale
	check_near(maxf(drawn.x, drawn.y), Player.SPRITE_SIZE, 0.5, "image fitted to the player size")
	player.queue_free()
	await get_tree().process_frame


func test_look_faces_the_way_the_player_moves() -> void:
	var player := _make(Roster.Team.LEFT)
	var look: PlayerLook = player.get_node("Look")
	for i in 10:
		player.position += Vector2(0, 3)
		await get_tree().process_frame
	check(look.facing.dot(Vector2.DOWN) > 0.9, "facing down (%s)" % look.facing)
	check(look.is_running, "running")
	for i in 20:
		await get_tree().process_frame
	check(not look.is_running, "stands still when it stops")
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
