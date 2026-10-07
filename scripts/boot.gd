extends Node

## Entry scene. `godot --headless -- --server` starts the dedicated server;
## everything else (browser, editor run) opens the menu.

const SERVER_SCENE := "res://scenes/server.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"


func _ready() -> void:
	GameSettings.load_and_apply()
	var target := SERVER_SCENE if OS.get_cmdline_user_args().has("--server") else MENU_SCENE
	get_tree().change_scene_to_file.call_deferred(target)
