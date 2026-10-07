extends TestCase


func _init() -> void:
	GameSettings.save_path = "user://test_settings.cfg"

## The settings panel from the start menu, and in a match where it pauses
## practice and offers Resume / Quit to menu.

const MENU_SCENE := "res://scenes/menu.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"
const PENALTY_SCENE := "res://scenes/penalty.tscn"


func _current() -> String:
	return get_tree().current_scene.scene_file_path if get_tree().current_scene else ""


func _open(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await wait_until(func(): return _current() == path, 30)
	await get_tree().process_frame
	return get_tree().current_scene


func _cleanup() -> void:
	get_tree().paused = false
	GameSettings.volume = GameSettings.DEFAULT_VOLUME
	GameSettings.music_on = true
	GameSettings.apply()
	DirAccess.remove_absolute(GameSettings.save_path)
	get_tree().unload_current_scene()
	await get_tree().process_frame


func test_menu_settings_change_volume_and_music() -> void:
	var menu := await _open(MENU_SCENE)
	check(not menu._settings_button.text.contains("SOON"), "settings is live")
	menu._settings_button.pressed.emit()
	var panel: SettingsPanel = menu._settings_panel
	check(panel.visible, "panel open")
	check(not panel.resume_button.visible and not panel.quit_button.visible, "no match buttons in the menu")
	panel.volume_slider.value = 40
	check_near(GameSettings.volume, 0.4, 0.001, "volume follows the slider")
	panel.music_button.pressed.emit()
	check(not GameSettings.music_on, "music off")
	check_eq(panel.music_button.text, "MUSIC  OFF", "label says off")
	panel.back_button.pressed.emit()
	check(not panel.visible, "closed")
	await _cleanup()


func test_practice_pauses_while_settings_are_open() -> void:
	var game := await _open(MATCH_SCENE)
	game._settings_button.pressed.emit()
	check(game._settings_panel.visible, "open")
	check(get_tree().paused, "paused")
	game._settings_panel.resume_button.pressed.emit()
	check(not game._settings_panel.visible, "closed")
	check(not get_tree().paused, "running again")
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	game._unhandled_input(esc)
	check(game._settings_panel.visible, "Esc opens settings")
	game._settings_panel.quit_button.pressed.emit()
	check(await wait_until(func(): return _current() == MENU_SCENE, 30), "quit to menu")
	check(not get_tree().paused, "unpaused on the way out")
	await _cleanup()


func test_penalty_pauses_while_settings_are_open() -> void:
	var game := await _open(PENALTY_SCENE)
	game._settings_button.pressed.emit()
	check(get_tree().paused, "paused")
	game._settings_panel.resume_button.pressed.emit()
	check(not get_tree().paused, "running again")
	await _cleanup()
