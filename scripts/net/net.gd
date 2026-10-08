extends Node

## Networking hub, autoloaded as "Net". Owns the WebSocket peer and declares
## every RPC, so client and server share one node path. On clients, RPCs
## from the server become signals. On the server, client requests are handed
## to `server` (the GameServer) together with the sender's peer id.

signal connected
signal connection_failed
## The server went away unexpectedly (not emitted by leave()).
signal disconnected
signal room_state_received(state: Dictionary)
signal error_received(message: String)
signal match_started
signal snapshot_received(snap: Dictionary)
signal goal_scored(team: int)
signal match_ended(score_left: int, score_right: int)
## Rows of the room browser: { code, host_name, players, max_players, minutes, phase }.
signal room_list_received(rooms: Array)

const PING_INTERVAL := 1.0

## The GameServer; set on the server only.
var server: Node = null
## Latest lobby state from the server, kept across scene changes:
## { code, phase, host_id, players: [{ id, name, team }] }.
var current_room: Dictionary = {}
## Latest room browser rows (see room_list_received).
var room_list: Array = []
var room_list_received_once: bool = false
## Shown by the menu after an unexpected disconnect.
var last_error: String = ""
var player_name: String = ""
## Round-trip time to the server, measured once per PING_INTERVAL.
var ping_ms: int = 0
var _ping_elapsed: float = 0.0
## Server only: peer id -> Time.get_ticks_msec() of the last RPC received.
var _last_heard: Dictionary = {}


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(delta: float) -> void:
	if not is_online() or multiplayer.is_server():
		return
	_ping_elapsed += delta
	if _ping_elapsed >= PING_INTERVAL:
		_ping_elapsed = 0.0
		ping.rpc_id(1, Time.get_ticks_msec())


## Starts listening for clients (dedicated server).
func host(port: int) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	# Clients never talk to each other; don't relay their packets.
	(multiplayer as SceneMultiplayer).server_relay = false
	return OK


## Connects to a server; `connected` or `connection_failed` follows.
func join(url: String) -> Error:
	leave()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


## Closes the connection on purpose; `disconnected` is not emitted.
func leave() -> void:
	current_room = {}
	room_list = []
	room_list_received_once = false
	_last_heard.clear()
	if multiplayer.multiplayer_peer is WebSocketMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func is_online() -> bool:
	var peer := multiplayer.multiplayer_peer
	return peer is WebSocketMultiplayerPeer \
		and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


## The ids in `ids` whose socket is still open. A peer whose connection is
## closing stays in the roster until its disconnect is processed; sending to
## it in that window only logs errors.
func open_peers(ids: Array[int]) -> Array[int]:
	var result: Array[int] = []
	var peer := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
	if peer == null:
		return result
	var connected := multiplayer.get_peers()
	for id in ids:
		if connected.has(id) and peer.get_peer(id).get_ready_state() == WebSocketPeer.STATE_OPEN:
			result.append(id)
	return result


## Server only: peers that sent nothing (not even a ping) for `seconds`.
func silent_peers(seconds: float) -> Array[int]:
	var cutoff := Time.get_ticks_msec() - int(seconds * 1000.0)
	var result: Array[int] = []
	for id in _last_heard:
		if _last_heard[id] < cutoff:
			result.append(id)
	return result


## Server only: closes a client's connection; peer_disconnected follows.
func drop_peer(id: int) -> void:
	_last_heard.erase(id)
	if multiplayer.get_peers().has(id):
		(multiplayer.multiplayer_peer as WebSocketMultiplayerPeer).disconnect_peer(id)


func my_id() -> int:
	return multiplayer.get_unique_id()


## Server address: `--url=` on the command line, `?server=` in the page URL,
## Protocol.PRODUCTION_URL when served from a real host, else localhost.
func server_url() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--url="):
			return arg.trim_prefix("--url=")
	if OS.has_feature("web"):
		var from_query := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('server') || ''"))
		if not from_query.is_empty():
			return from_query
		var hostname := str(JavaScriptBridge.eval("window.location.hostname"))
		var is_local_page := hostname == "localhost" or hostname == "127.0.0.1"
		if not is_local_page and not Protocol.PRODUCTION_URL.is_empty():
			return Protocol.PRODUCTION_URL
	return Protocol.LOCAL_URL


## Id of the peer whose RPC is running; also records that it is alive.
func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	if server:
		_last_heard[id] = Time.get_ticks_msec()
	return id


func _on_connected_to_server() -> void:
	connected.emit()


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	last_error = "Lost connection to the server"
	disconnected.emit()


func _on_peer_connected(id: int) -> void:
	if server:
		_last_heard[id] = Time.get_ticks_msec()


func _on_peer_disconnected(id: int) -> void:
	_last_heard.erase(id)
	if server:
		server.handle_leave(id)


# --- Client -> server ---------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func request_create(requested_name: String) -> void:
	if server:
		server.handle_create(_sender(), requested_name)


@rpc("any_peer", "call_remote", "reliable")
func request_join(code: String, requested_name: String) -> void:
	if server:
		server.handle_join(_sender(), code, requested_name)


@rpc("any_peer", "call_remote", "reliable")
func request_room_list() -> void:
	if server:
		server.handle_room_list(_sender())


@rpc("any_peer", "call_remote", "reliable")
func request_character(character_id: String) -> void:
	if server:
		server.handle_character(_sender(), character_id)


@rpc("any_peer", "call_remote", "reliable")
func request_duration(minutes: int) -> void:
	if server:
		server.handle_duration(_sender(), minutes)


@rpc("any_peer", "call_remote", "reliable")
func request_team(team: int) -> void:
	if server:
		server.handle_team(_sender(), team)


@rpc("any_peer", "call_remote", "reliable")
func request_start() -> void:
	if server:
		server.handle_start(_sender())


@rpc("any_peer", "call_remote", "reliable")
func request_leave() -> void:
	if server:
		server.handle_leave(_sender())


@rpc("any_peer", "call_remote", "unreliable_ordered")
func send_input(seq: int, bits: int) -> void:
	if server:
		server.handle_input(_sender(), seq, bits)


@rpc("any_peer", "call_remote", "reliable")
func ping(sent_msec: int) -> void:
	if server:
		pong.rpc_id(_sender(), sent_msec)


# --- Server -> client ---------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func send_room_state(state: Dictionary) -> void:
	current_room = state
	room_state_received.emit(state)


@rpc("authority", "call_remote", "reliable")
func send_room_list(rooms: Array) -> void:
	room_list = rooms
	room_list_received_once = true
	room_list_received.emit(rooms)


@rpc("authority", "call_remote", "reliable")
func send_error(message: String) -> void:
	error_received.emit(message)


@rpc("authority", "call_remote", "reliable")
func send_match_start() -> void:
	match_started.emit()


@rpc("authority", "call_remote", "unreliable_ordered")
func send_snapshot(bytes: PackedByteArray) -> void:
	snapshot_received.emit(Protocol.decode_snapshot(bytes))


@rpc("authority", "call_remote", "reliable")
func send_goal(team: int) -> void:
	goal_scored.emit(team)


@rpc("authority", "call_remote", "reliable")
func send_match_end(score_left: int, score_right: int) -> void:
	match_ended.emit(score_left, score_right)


@rpc("authority", "call_remote", "reliable")
func pong(sent_msec: int) -> void:
	ping_ms = Time.get_ticks_msec() - sent_msec
