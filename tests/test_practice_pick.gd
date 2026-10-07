extends TestCase

## Practice opens the character list in "pick" mode; PLAY starts practice as
## the picked character. Picking a keeper starts the shooting drill instead.

const MENU_SCENE := "res://scenes/menu.tscn"
const CHARACTERS_SCENE := "res://scenes/characters.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"


func _current() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene else ""


func _open_pick_screen() -> Node:
	get_tree().change_scene_to_file(MENU_SCENE)
	await wait_until(func(): return _current() == MENU_SCENE, 30)
	get_tree().current_scene._practice_button.pressed.emit()
	await wait_until(func(): return _current() == CHARACTERS_SCENE, 30)
	return get_tree().current_scene


func _play_as(id: String) -> Node:
	var screen := await _open_pick_screen()
	var index := Characters.ALL.find(Characters.by_id(id))
	screen._entries[index].pressed.emit()
	screen._play_button.pressed.emit()
	await wait_until(func(): return _current() == MATCH_SCENE, 30)
	for i in 3:
		await get_tree().physics_frame
	return get_tree().current_scene


func _local(game: Node) -> Player:
	for child in game.get_children():
		if child is Player and child.keyboard_control:
			return child
	return null


func _finish() -> void:
	CharactersScreen.practice_character_id = CharactersScreen.DEFAULT_CHARACTER
	CharactersScreen.pick_for_practice = false
	get_tree().unload_current_scene()
	await get_tree().process_frame


func test_practice_opens_the_list_in_pick_mode() -> void:
	var screen := await _open_pick_screen()
	check(screen._play_button.visible, "PLAY shown")
	screen._back_button.pressed.emit()
	await wait_until(func(): return _current() == MENU_SCENE, 30)
	get_tree().current_scene._characters_button.pressed.emit()
	await wait_until(func(): return _current() == CHARACTERS_SCENE, 30)
	check(not get_tree().current_scene._play_button.visible, "browsing has no PLAY")
	await _finish()


func test_playing_as_an_outfield_character_applies_its_stats() -> void:
	var game := await _play_as("cannon")
	var me := _local(game)
	check(me != null, "local player")
	if me:
		check_eq(me.character_id, "cannon", "character")
		check_eq(me.display_name, "CANNON", "name shown")
		check(me.max_kick_speed > 720.0, "shooting stat applied")
		check(not me.is_goalkeeper, "outfield")
	check(game._drill == null, "normal practice")
	await _finish()


func test_playing_as_a_keeper_starts_the_shooting_drill_in_goal() -> void:
	var game := await _play_as("cat")
	var me := _local(game)
	check(me != null and me.is_goalkeeper, "keeper")
	if me:
		check(me.position.distance_to(GoalkeeperAI.home_position(-1)) < 30.0, "standing in the left goal")
	check(game._drill != null, "drill running")
	var mates := game.get_children().filter(func(n): return n is Player and n.team == Roster.Team.LEFT and n != me)
	check_eq(mates.size(), 0, "no teammates in the way")
	await _finish()
