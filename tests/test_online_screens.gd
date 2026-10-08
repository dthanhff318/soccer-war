extends TestCase

## Client screens for online play, fed with room data directly (no server):
## the room browser on the start menu and the lobby's character / length
## controls.

const MENU_SCENE := preload("res://scenes/menu.tscn")
const LOBBY_SCENE := preload("res://scenes/lobby.tscn")


func _rooms() -> Array:
	return [
		{"code": "AAAA", "host_name": "Alice", "players": 3, "max_players": 8, "minutes": 7, "phase": Protocol.Phase.LOBBY},
		{"code": "BBBB", "host_name": "Bob", "players": 4, "max_players": 8, "minutes": 5, "phase": Protocol.Phase.PLAYING},
		{"code": "CCCC", "host_name": "Cid", "players": 8, "max_players": 8, "minutes": 10, "phase": Protocol.Phase.LOBBY},
	]


func _open_menu() -> Control:
	var menu: Control = MENU_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	return menu


func test_room_browser_lists_rooms_and_only_open_ones_can_be_joined() -> void:
	var menu := await _open_menu()
	menu._name_edit.text = "Thanh"
	menu._refresh_rooms(_rooms())
	check_eq(menu._room_rows.get_child_count(), 3, "one row per room")
	var open_row: Control = menu._room_rows.get_child(0)
	var running_row: Control = menu._room_rows.get_child(1)
	var full_row: Control = menu._room_rows.get_child(2)
	check(open_row.get_meta("joinable"), "waiting room can be joined")
	check(not running_row.get_meta("joinable"), "running room can't")
	check(running_row.modulate.a < 1.0, "running room dimmed")
	check(not full_row.get_meta("joinable"), "full room can't")
	menu.queue_free()


func test_name_is_required_before_joining_or_creating() -> void:
	var menu := await _open_menu()
	menu._name_edit.text = ""
	menu._refresh_rooms(_rooms())
	check(menu._create_button.disabled, "create needs a name")
	var join: Button = menu._room_rows.get_child(0).get_meta("join_button")
	check(join.disabled, "join needs a name")
	menu._name_edit.text = "Thanh"
	menu._name_edit.text_changed.emit("Thanh")
	join = menu._room_rows.get_child(0).get_meta("join_button")
	check(not join.disabled and not menu._create_button.disabled, "enabled with a name")
	menu.queue_free()


func test_create_is_disabled_when_the_server_is_full() -> void:
	var menu := await _open_menu()
	menu._name_edit.text = "Thanh"
	var five: Array = []
	for i in Protocol.MAX_ROOMS:
		five.append({"code": "R%d" % i, "host_name": "H", "players": 1, "max_players": 8, "minutes": 5, "phase": Protocol.Phase.LOBBY})
	menu._refresh_rooms(five)
	check(menu._create_button.disabled, "no sixth room")
	check(menu._rooms_note.text.contains("full"), "says why")
	menu.queue_free()


func _lobby_state(my_character: String, host_is_me: bool) -> Dictionary:
	var me := Net.my_id()
	return {"code": "AAAA", "phase": Protocol.Phase.LOBBY, "minutes": 7,
		"host_id": me if host_is_me else 99,
		"players": [
			{"id": me, "name": "Thanh", "team": 0, "character": my_character},
			{"id": 98, "name": "Lan", "team": 0, "character": "cat"},
			{"id": 99, "name": "Minh", "team": 1, "character": "blitz"},
		]}


func test_lobby_shows_characters_and_length_and_only_the_host_can_change_it() -> void:
	Net.current_room = _lobby_state("cannon", true)
	var lobby: Control = LOBBY_SCENE.instantiate()
	add_child(lobby)
	await get_tree().process_frame
	check(lobby._character_button.text.contains("CANNON"), "my character on the button")
	check(lobby._duration_buttons[1].button_pressed, "7 minutes selected")
	check(not lobby._duration_buttons[0].disabled, "host can change it")
	var row_text: String = lobby._team_lists[0].get_child(0).get_meta("text")
	check(row_text.contains("CANNON"), "row shows the character")
	Net.current_room = _lobby_state("cannon", false)
	lobby._refresh(Net.current_room)
	check(lobby._duration_buttons[0].disabled, "guests can't")
	Net.current_room = {}
	lobby.queue_free()


func test_character_picker_dims_taken_and_keeper_options() -> void:
	Net.current_room = _lobby_state("cannon", true)
	var lobby: Control = LOBBY_SCENE.instantiate()
	add_child(lobby)
	await get_tree().process_frame
	lobby._character_button.pressed.emit()
	var picker: CharacterPicker = lobby._picker
	check(picker.visible, "picker open")
	check(picker.option("cat").disabled, "teammate's character")
	check(picker.option("the_wall").disabled, "team already has a keeper")
	check(not picker.option("blitz").disabled, "other team's pick is free for us")
	check(not picker.option("cannon").disabled, "my own pick")
	Net.current_room = {}
	lobby.queue_free()


func test_lobby_is_titled_by_its_host_and_shows_no_code() -> void:
	Net.current_room = _lobby_state("cannon", false)
	var lobby: Control = LOBBY_SCENE.instantiate()
	add_child(lobby)
	await get_tree().process_frame
	check_eq(lobby._title_label.text, "MINH'S ROOM", "host's room")
	check(not lobby.get("_copy_button"), "no copy button")
	Net.current_room = {}
	lobby.queue_free()
