extends TestCase

## If "match started" arrives while the menu is still on screen, the menu
## has no handler for it. The lobby must notice from the room state that the
## match is already running and go straight to it.

const LOBBY_SCENE := "res://scenes/lobby.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"


func test_lobby_joins_a_match_that_already_started() -> void:
	Net.current_room = {"code": "TEST", "phase": Protocol.Phase.PLAYING, "host_id": 99,
		"players": [{"id": 99, "name": "Host", "team": 0}]}
	get_tree().change_scene_to_file(LOBBY_SCENE)
	var reached := await wait_until(func(): return get_tree().current_scene != null \
		and get_tree().current_scene.scene_file_path == MATCH_SCENE, 30)
	check(reached, "went on to the match")
	Net.current_room = {}
	get_tree().unload_current_scene()
	await get_tree().process_frame
