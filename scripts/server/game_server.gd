extends Node

## Dedicated server root (scenes/server.tscn). Listens for clients, creates
## rooms by code and routes every request to the sender's room.

## Port to listen on; 0 reads $PORT, falling back to Protocol.DEFAULT_PORT.
@export var port: int = 0

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


func room_count() -> int:
	return _rooms.size()


func handle_create(peer: int, player_name: String) -> void:
	_leave(peer)
	var room := Room.new(Protocol.make_code(_rng, _rooms))
	_rooms[room.code] = room
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


func _room_for(peer: int) -> Room:
	return _rooms.get(_room_of_peer.get(peer, ""))


static func _env_port() -> int:
	var value := OS.get_environment("PORT")
	return value.to_int() if value.is_valid_int() else Protocol.DEFAULT_PORT
