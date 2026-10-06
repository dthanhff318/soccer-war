extends TestCase

## End-to-end over real WebSockets in one process. The server uses the root
## multiplayer (autoload /root/Net); each fake client gets its own Net node
## under a branch with its own SceneMultiplayer, so RPC paths ("Net") match.

const NET_SCRIPT := preload("res://scripts/net/net.gd")
const SERVER_SCENE := preload("res://scenes/server.tscn")
const PORT := 9181

var _server: Node
var _branches: Array[Node] = []


func _start_server() -> void:
	_server = SERVER_SCENE.instantiate()
	_server.port = PORT
	add_child(_server)


func _make_client(label: String) -> Node:
	var branch := Node.new()
	branch.name = label
	get_tree().root.add_child(branch)
	get_tree().set_multiplayer(SceneMultiplayer.new(), branch.get_path())
	var net: Node = NET_SCRIPT.new()
	net.name = "Net"
	branch.add_child(net)
	net.join("ws://127.0.0.1:%d" % PORT)
	_branches.append(branch)
	return net


func _room() -> Room:
	return _server.get_children().filter(func(n): return n is Room).front()


func _teardown() -> void:
	for branch in _branches:
		branch.get_node("Net").leave()
		branch.queue_free()
	_branches.clear()
	_server.queue_free()
	Net.leave()
	Net.server = null
	await get_tree().process_frame


func test_full_match_flow() -> void:
	_start_server()
	var host := _make_client("ClientA")
	var guest := _make_client("ClientB")
	check(await wait_until(func(): return host.is_online() and guest.is_online()), "clients connect")

	var guest_errors: Array[String] = []
	guest.error_received.connect(func(message): guest_errors.append(message))

	# Unknown room code is refused.
	guest.request_join.rpc_id(1, "ZZZZ", "Bob")
	check(await wait_until(func(): return guest_errors.size() == 1), "unknown code refused")
	check_eq(guest_errors.back(), "Room not found", "error text")

	# Host creates; guest joins with a lowercase code and a padded name.
	host.request_create.rpc_id(1, "Alice")
	check(await wait_until(func(): return host.current_room.has("code")), "host gets room state")
	var code: String = host.current_room.get("code", "")
	guest.request_join.rpc_id(1, code.to_lower(), "  Bob  ")
	check(await wait_until(func(): return host.current_room.get("players", []).size() == 2), "both in room")
	var players: Array = host.current_room.players
	check_eq(players[1].name, "Bob", "name trimmed")
	check(players[0].team != players[1].team, "joiner placed on the smaller team")
	check_eq(host.current_room.host_id, host.my_id(), "creator is host")

	# Only the host may start.
	guest.request_start.rpc_id(1)
	check(await wait_until(func(): return guest_errors.size() == 2), "guest start refused")
	check_eq(guest_errors.back(), "Only the host can start the match", "error text")

	var snaps: Array[Dictionary] = []
	var started: Array[bool] = []
	guest.snapshot_received.connect(func(snap): snaps.append(snap))
	guest.match_started.connect(func(): started.append(true))
	host.request_start.rpc_id(1)
	check(await wait_until(func(): return snaps.size() >= 5), "snapshots arrive")
	check(not started.is_empty(), "match_started received")
	var last: Dictionary = snaps.back()
	check_eq(last.players.size(), 2, "both players in snapshot")
	check_eq(last.phase, Protocol.Phase.PLAYING, "phase playing")
	check(last.time_left < MatchRules.MATCH_SECONDS and last.time_left > MatchRules.MATCH_SECONDS - 5.0, "clock running")

	# A third client cannot join a running match.
	var late := _make_client("ClientC")
	var late_errors: Array[String] = []
	late.error_received.connect(func(message): late_errors.append(message))
	check(await wait_until(func(): return late.is_online()), "late client connects")
	late.request_join.rpc_id(1, code, "Late")
	check(await wait_until(func(): return late_errors.size() == 1), "join during match refused")
	check_eq(late_errors.back() if not late_errors.is_empty() else "", "Match already in progress", "error text")

	# Guest moves right: inputs are acknowledged and the server position advances.
	var guest_id: int = guest.my_id()
	var start_x: float = snaps.back().players[guest_id].pos.x
	for seq in range(1, 31):
		guest.send_input.rpc_id(1, seq, Protocol.IN_RIGHT)
		await get_tree().physics_frame
	check(await wait_until(func(): return snaps.back().players[guest_id].last_seq == 30), "inputs acknowledged")
	check(snaps.back().players[guest_id].pos.x > start_x + 20.0, "guest moved right")

	# Ball placed in the right goal scores for the left team.
	var goals: Array[int] = []
	host.goal_scored.connect(func(team): goals.append(team))
	_room()._ball.reset(Vector2(MatchRules.GOAL_LINE_RIGHT + 30.0, 360.0))
	check(await wait_until(func(): return goals.size() == 1), "goal detected")
	check_eq(goals.front() if not goals.is_empty() else -1, Roster.Team.LEFT, "left team scored")
	check(await wait_until(func(): return snaps.back().score_left == 1), "score in snapshot")

	# Clock runs out: result, then everyone is back in the lobby.
	var ended: Array = []
	host.match_ended.connect(func(left, right): ended.append([left, right]))
	_room().time_left = 0.05
	check(await wait_until(func(): return ended.size() == 1), "match ends")
	check_eq(ended.front() if not ended.is_empty() else [], [1, 0], "final score")
	_room()._phase_timer = 0.0
	check(await wait_until(func(): return host.current_room.phase == Protocol.Phase.LOBBY), "back to lobby")

	# Guest disconnects: host stays. Host disconnects: room is deleted.
	guest.leave()
	check(await wait_until(func(): return host.current_room.players.size() == 1), "guest removed")
	host.leave()
	check(await wait_until(func(): return _server.room_count() == 0), "empty room deleted")
	await _teardown()


func test_host_leaving_mid_match_passes_host_and_removes_body() -> void:
	_start_server()
	var host := _make_client("ClientA")
	var guest := _make_client("ClientB")
	var third := _make_client("ClientC")
	check(await wait_until(func(): return host.is_online() and guest.is_online() and third.is_online()), "connect")
	host.request_create.rpc_id(1, "Alice")
	check(await wait_until(func(): return host.current_room.has("code")), "room")
	guest.request_join.rpc_id(1, host.current_room.code, "Bob")
	third.request_join.rpc_id(1, host.current_room.code, "Cid")
	check(await wait_until(func(): return host.current_room.get("players", []).size() == 3), "three joined")

	var snaps: Array[Dictionary] = []
	guest.snapshot_received.connect(func(snap): snaps.append(snap))
	host.request_start.rpc_id(1)
	check(await wait_until(func(): return snaps.size() >= 2 and snaps.back().players.size() == 3), "playing")

	var host_id: int = host.my_id()
	host.leave()
	check(await wait_until(func(): return guest.current_room.host_id == guest.my_id()), "host passed to next member")
	check(await wait_until(func(): return not snaps.back().players.has(host_id)), "body removed from snapshots")
	check_eq(snaps.back().phase, Protocol.Phase.PLAYING, "match continues")
	await _teardown()


func test_team_switch_in_lobby() -> void:
	_start_server()
	var host := _make_client("ClientA")
	check(await wait_until(func(): return host.is_online()), "connect")
	host.request_create.rpc_id(1, "Alice")
	check(await wait_until(func(): return host.current_room.has("code")), "room")
	check_eq(host.current_room.players[0].team, Roster.Team.LEFT, "starts left")
	host.request_team.rpc_id(1, Roster.Team.RIGHT)
	check(await wait_until(func(): return host.current_room.players[0].team == Roster.Team.RIGHT), "switched")
	await _teardown()
