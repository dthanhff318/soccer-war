extends TestCase

## Start screen: Play Online opens the online panel (Back returns), Practice
## starts the offline match, Settings is not built yet.

const MENU_SCENE := preload("res://scenes/menu.tscn")
const MATCH_SCENE := "res://scenes/main.tscn"


func _open_menu() -> Control:
	var menu: Control = MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	return menu


func test_home_shows_three_buttons_and_hides_the_online_panel() -> void:
	var menu := await _open_menu()
	check(menu._home.visible, "home visible")
	check(not menu._online_panel.visible, "online panel hidden")
	check_eq(menu._online_button.text, "PLAY ONLINE", "play online")
	check_eq(menu._practice_button.text, "PRACTICE", "practice")
	check(menu._settings_button.text.begins_with("SETTINGS"), "settings")
	menu.queue_free()


func test_play_online_opens_panel_and_back_returns() -> void:
	var menu := await _open_menu()
	menu._online_button.pressed.emit()
	check(not menu._home.visible, "home hidden")
	check(menu._online_panel.visible, "online panel shown")
	menu._back_button.pressed.emit()
	check(menu._home.visible, "home again")
	check(not menu._online_panel.visible, "panel hidden again")
	menu.queue_free()


func test_settings_is_coming_soon() -> void:
	var menu := await _open_menu()
	menu._settings_button.pressed.emit()
	check_eq(menu._status.text, "Settings are coming soon", "message")
	check(menu._home.visible, "stays on home")
	menu.queue_free()


func test_practice_starts_the_offline_match() -> void:
	var menu := await _open_menu()
	menu._practice_button.pressed.emit()
	var reached := await wait_until(func(): return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == MATCH_SCENE, 30)
	check(reached, "offline match opened")
	if is_instance_valid(menu):
		menu.queue_free()
	get_tree().unload_current_scene()
	await get_tree().process_frame
