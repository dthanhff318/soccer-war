extends SceneTree

## End-to-end bot: drives the real menu, lobby and match scenes against a
## running server, as a player would. Run two at once (see tools/e2e.sh):
##   godot --headless -s tools/e2e_bot.gd -- --role=host  --code-file=/tmp/code
##   godot --headless -s tools/e2e_bot.gd -- --role=guest --code-file=/tmp/code
## Prints "E2E OK <role>" and exits 0 on success, "E2E FAIL ..." and 1 otherwise.

const MENU := "res://scenes/menu.tscn"
const LOBBY := "res://scenes/lobby.tscn"
const MATCH := "res://scenes/main.tscn"

var _role := ""
var _code_file := ""
## The Net autoload; looked up at runtime because -s scripts compile before autoloads exist.
var _net: Node


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			_role = arg.trim_prefix("--role=")
		elif arg.begins_with("--code-file="):
			_code_file = arg.trim_prefix("--code-file=")
	_run.call_deferred()


func _run() -> void:
	_net = root.get_node("Net")
	change_scene_to_file(MENU)
	if not await _wait(func(): return _scene_is(MENU), 60):
		return _fail("menu did not open")
	var menu := current_scene
	menu._name_edit.text = _role.capitalize()

	if _role == "host":
		menu._on_create_pressed()
		if not await _wait(func(): return _scene_is(LOBBY), 300):
			return _fail("lobby did not open: " + menu._status.text)
		FileAccess.open(_code_file, FileAccess.WRITE).store_string(_net.current_room.code)
		if not await _wait(func(): return _net.current_room.get("players", []).size() == 2, 1200):
			return _fail("guest never joined")
		current_scene._on_start_pressed()
	else:
		if not await _wait(func(): return FileAccess.file_exists(_code_file), 1200):
			return _fail("no room code")
		menu._code_edit.text = FileAccess.get_file_as_string(_code_file).to_lower()
		menu._on_join_pressed()
		if not await _wait(func(): return _scene_is(LOBBY), 300):
			return _fail("lobby did not open: " + menu._status.text)

	if not await _wait(func(): return _scene_is(MATCH), 600):
		return _fail("match did not start")
	var game := current_scene
	if not await _wait(func(): return not game._buffer.is_empty(), 300):
		return _fail("no snapshots")

	# Host runs right, guest runs left, for one second.
	var action := "move_right" if _role == "host" else "move_left"
	var local: Player = game._local
	var start_x := local.position.x
	var other_id: int = 0
	for id in game._players:
		if game._players[id] != local:
			other_id = id
	var other: Player = game._players[other_id]
	var other_start_x := other.position.x
	Input.action_press(action)
	for i in 60:
		await physics_frame
	Input.action_release(action)
	var moved := local.position.x - start_x
	if (_role == "host" and moved < 60.0) or (_role == "guest" and moved > -60.0):
		return _fail("local player did not move (dx=%.1f)" % moved)

	# The other player's movement must show up through snapshots.
	var other_moved := func(): return absf(other.position.x - other_start_x) > 60.0
	if not await _wait(other_moved, 180):
		return _fail("remote player did not move (dx=%.1f)" % (other.position.x - other_start_x))

	# Our predicted position must agree with the server once we stop.
	for i in 30:
		await physics_frame
	var server_x: float = game._buffer.latest().players[_net.my_id()].pos.x
	if absf(server_x - local.position.x) > 4.0:
		return _fail("prediction drifted from server (%.1f vs %.1f)" % [local.position.x, server_x])

	print("E2E OK %s (moved %.0f px, ping %d ms)" % [_role, moved, _net.ping_ms])
	# Give the other bot time to finish its checks before we disconnect.
	for i in 120:
		await process_frame
	quit(0)


func _scene_is(path: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == path


func _wait(condition: Callable, frames: int) -> bool:
	for i in frames:
		if condition.call():
			return true
		await process_frame
	return condition.call()


func _fail(reason: String) -> void:
	printerr("E2E FAIL %s: %s" % [_role, reason])
	quit(1)
