extends TestCase

const LOBBY_SCENE := preload("res://scenes/lobby.tscn")


func test_copy_button_copies_the_room_code_and_confirms() -> void:
	Net.current_room = {"code": "K7QX", "phase": Protocol.Phase.LOBBY, "host_id": 1,
		"players": [{"id": 1, "name": "Thanh", "team": 0}]}
	var lobby: Control = LOBBY_SCENE.instantiate()
	add_child(lobby)
	await get_tree().process_frame
	var button: Button = lobby._copy_button
	button.pressed.emit()
	check_eq(button.text, "COPIED!", "confirms the copy")
	if DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		check_eq(DisplayServer.clipboard_get(), "K7QX", "code on the clipboard")
	Net.current_room = {}
	lobby.queue_free()
	await get_tree().process_frame
