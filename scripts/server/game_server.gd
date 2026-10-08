extends Node

## Dedicated server root (scenes/server.tscn). Listens for clients, creates
## rooms by code and routes every request to the sender's room.

## Port to listen on; 0 reads $PORT, falling back to Protocol.DEFAULT_PORT.
@export var port: int = 0
## Clients ping every second; one silent this long (frozen tab, dead mobile
## connection) is dropped so its player doesn't linger in the match.
@export var idle_timeout: float = 15.0

var _rooms: Dictionary = {}         # code -> Room
var _room_of_peer: Dictionary = {}  # peer id -> code
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	# Headless builds otherwise spin the main loop as fast as the CPU allows.
	Engine.max_fps = Protocol.TICK_RATE
	var listen_port := port if port > 0 else _env_port()
	Net.server = self
	var err := Net.host(listen_port)
	if err != OK:
		push_error("[server] could not listen on port %d (error %d)" % [listen_port, err])
		get_tree().quit(1)
		return
	print("[server] listening on port %d" % listen_port)


func _process(_delta: float) -> void:
	for id in Net.silent_peers(idle_timeout):
		print("[server] dropping silent peer %d" % id)
		Net.drop_peer(id)


func room_count() -> int:
	return _rooms.size()


func handle_create(peer: int, player_name: String) -> void:
	_leave(peer)
	if _rooms.size() >= Protocol.MAX_ROOMS:
		Net.send_error.rpc_id(peer, "Server is full")
		return
	var room := Room.new(Protocol.make_code(_rng, _rooms))
	_rooms[room.code] = room
	room.changed.connect(_broadcast_room_list)
	add_child(room)
	print("[server] room %s created by peer %d" % [room.code, peer])
	_join(peer, room, player_name)


func handle_join(peer: int, code: String, player_name: String) -> void:
	_leave(peer)
	var room: Room = _rooms.get(code.strip_edges().to_upper())
	if room == null:
		Net.send_error.rpc_id(peer, "Room not found")
	elif room.is_in_match():
		Net.send_error.rpc_id(peer, "Match already in progress")
	else:
		_join(peer, room, player_name)


func handle_room_list(peer: int) -> void:
	Net.send_room_list.rpc_id(peer, room_list())


func handle_character(peer: int, character_id: String) -> void:
	var room := _room_for(peer)
	if room:
		room.set_character(peer, character_id)


func handle_duration(peer: int, minutes: int) -> void:
	var room := _room_for(peer)
	if room:
		room.set_duration(peer, minutes)


## One row per room for the room browser.
func room_list() -> Array:
	var rows: Array = []
	for room: Room in _rooms.values():
		rows.append(room.summary())
	return rows


## Sends the room list to everyone browsing (connected but not in a room).
func _broadcast_room_list() -> void:
	var browsing: Array[int] = []
	for id in multiplayer.get_peers():
		if not _room_of_peer.has(id):
			browsing.append(id)
	var rows := room_list()
	for id in Net.open_peers(browsing):
		Net.send_room_list.rpc_id(id, rows)


func handle_team(peer: int, team: int) -> void:
	var room := _room_for(peer)
	if room:
		room.set_team(peer, team)


func handle_start(peer: int) -> void:
	var room := _room_for(peer)
	if room:
		room.start(peer)


func handle_input(peer: int, seq: int, bits: int) -> void:
	var room := _room_for(peer)
	if room:
		room.queue_input(peer, seq, bits)


func handle_leave(peer: int) -> void:
	_leave(peer)


func _join(peer: int, room: Room, player_name: String) -> void:
	var err := room.add_player(peer, player_name)
	if not err.is_empty():
		Net.send_error.rpc_id(peer, err)
		return
	_room_of_peer[peer] = room.code
	_broadcast_room_list()


func _leave(peer: int) -> void:
	var room := _room_for(peer)
	if room == null:
		return
	_room_of_peer.erase(peer)
	room.remove_player(peer)
	if room.is_empty():
		_rooms.erase(room.code)
		room.queue_free()
		print("[server] room %s closed" % room.code)
	_broadcast_room_list()


func _room_for(peer: int) -> Room:
	return _rooms.get(_room_of_peer.get(peer, ""))


static func _env_port() -> int:
	var value := OS.get_environment("PORT")
	return value.to_int() if value.is_valid_int() else Protocol.DEFAULT_PORT
