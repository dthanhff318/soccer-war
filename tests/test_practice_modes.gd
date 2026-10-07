extends TestCase

## PRACTICE asks FREE PLAY or PENALTY before the character pick, and PLAY
## opens the matching scene.

const MENU_SCENE := "res://scenes/menu.tscn"
const CHARACTERS_SCENE := "res://scenes/characters.tscn"


func _current() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene else ""


func _to_pick(penalty: bool) -> Node:
	get_tree().change_scene_to_file(MENU_SCENE)
	await wait_until(func(): return _current() == MENU_SCENE, 30)
	var menu := get_tree().current_scene
	menu._practice_button.pressed.emit()
	check(menu._practice_panel.visible and not menu._home.visible, "mode choice shown")
	(menu._penalty_button if penalty else menu._free_play_button).pressed.emit()
	await wait_until(func(): return _current() == CHARACTERS_SCENE, 30)
	return get_tree().current_scene


func _finish() -> void:
	CharactersScreen.practice_character_id = CharactersScreen.DEFAULT_CHARACTER
	CharactersScreen.pick_for_practice = false
	CharactersScreen.practice_mode = CharactersScreen.MODE_FREE
	get_tree().unload_current_scene()
	await get_tree().process_frame


func test_penalty_route() -> void:
	var screen := await _to_pick(true)
	check(screen._play_button.visible, "pick mode")
	screen._play_button.pressed.emit()
	check(await wait_until(func(): return _current() == "res://scenes/penalty.tscn", 30), "penalty scene")
	await _finish()


func test_free_play_route() -> void:
	var screen := await _to_pick(false)
	screen._play_button.pressed.emit()
	check(await wait_until(func(): return _current() == "res://scenes/main.tscn", 30), "match scene")
	await _finish()


func test_back_from_the_mode_choice() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
	await wait_until(func(): return _current() == MENU_SCENE, 30)
	var menu := get_tree().current_scene
	menu._practice_button.pressed.emit()
	menu._practice_back_button.pressed.emit()
	check(menu._home.visible and not menu._practice_panel.visible, "home again")
	await _finish()
