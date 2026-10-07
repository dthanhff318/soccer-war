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


func test_settings_opens_the_settings_panel() -> void:
	var menu := await _open_menu()
	menu._settings_button.pressed.emit()
	check(menu._settings_panel.visible, "panel open")
	check(menu._home.visible, "menu stays underneath")
	menu._settings_panel.close()
	menu.queue_free()


func test_practice_opens_the_character_pick() -> void:
	var menu := await _open_menu()
	menu._practice_button.pressed.emit()
	menu._free_play_button.pressed.emit()
	var reached := await wait_until(func(): return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == "res://scenes/characters.tscn", 30)
	check(reached, "character pick opened")
	if is_instance_valid(menu):
		menu.queue_free()
	get_tree().unload_current_scene()
	await get_tree().process_frame


func test_how_to_play_opens_a_modal_that_closes_three_ways() -> void:
	var menu := await _open_menu()
	check(not menu._help_modal.visible, "hidden at start")
	menu._help_button.pressed.emit()
	check(menu._help_modal.visible, "opens")
	menu._help_close_button.pressed.emit()
	check(not menu._help_modal.visible, "Got it closes")

	menu._help_button.pressed.emit()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	menu._unhandled_input(esc)
	check(not menu._help_modal.visible, "Esc closes")

	menu._help_button.pressed.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	menu._help_modal.gui_input.emit(click)
	check(not menu._help_modal.visible, "click outside closes")
	menu.queue_free()


func test_settings_label_uses_only_pixel_font_glyphs() -> void:
	var menu := await _open_menu()
	var font: FontFile = UiKit.PIXEL_FONT
	for c in menu._settings_button.text:
		check(c == " " or font.has_char(c.unicode_at(0)), "glyph '%s' exists" % c)
	menu.queue_free()
