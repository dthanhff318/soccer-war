extends TestCase

## Start menu -> Characters screen: lists all 10, shows the picked one's
## details, Back returns to the menu.

const MENU_SCENE := "res://scenes/menu.tscn"
const CHARACTERS_SCENE := "res://scenes/characters.tscn"


func _current() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene else ""


func test_menu_button_opens_the_character_list_and_back_returns() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
	check(await wait_until(func(): return _current() == MENU_SCENE, 30), "menu")
	get_tree().current_scene._characters_button.pressed.emit()
	check(await wait_until(func(): return _current() == CHARACTERS_SCENE, 30), "characters screen")
	var screen := get_tree().current_scene
	check_eq(screen._entries.size(), Characters.ALL.size(), "one entry per character")
	screen._entries[2].pressed.emit()
	check_eq(screen._detail_name.text, Characters.ALL[2].name, "detail name")
	check_eq(screen._detail_description.text, Characters.ALL[2].description, "detail description")
	check_eq(screen._stat_rows.get_child_count(), Characters.STAT_KEYS.size(), "outfield stat bars")
	var keeper_index := Characters.ALL.find(Characters.ALL.filter(func(c): return c.keeper)[0])
	screen._entries[keeper_index].pressed.emit()
	check_eq(screen._stat_rows.get_child_count(), Characters.STAT_KEYS.size() + Characters.KEEPER_KEYS.size(), "keeper shows keeper stats too")
	screen._back_button.pressed.emit()
	check(await wait_until(func(): return _current() == MENU_SCENE, 30), "back to menu")
	get_tree().unload_current_scene()
	await get_tree().process_frame
