class_name Protocol
extends RefCounted

## Wire format shared by client and server: rates, input bits, room codes and
## the binary snapshot layout.

const DEFAULT_PORT := 9080
const LOCAL_URL := "ws://127.0.0.1:9080"
## wss:// address of the deployed game server. Empty until it is deployed.
const PRODUCTION_URL := ""

## Physics ticks per second, on server and client alike.
const TICK_RATE := 60
## Snapshots the server sends per second.
const SNAPSHOT_RATE := 30

enum Phase { LOBBY, PLAYING, CELEBRATING, ENDED }

## Input bits: one byte per physics tick describes everything a player does.
const IN_LEFT := 1
const IN_RIGHT := 2
const IN_UP := 4
const IN_DOWN := 8
const IN_SPRINT := 16
## Set only on the tick the kick key went down.
const IN_KICK := 32
const INPUT_MASK := 63

## No 0/O or 1/I, so codes read unambiguously when shared aloud.
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 4


## Movement vector for `bits`; matches Input.get_vector() for digital keys.
static func input_vector(bits: int) -> Vector2:
	var x := float((bits & IN_RIGHT) != 0) - float((bits & IN_LEFT) != 0)
	var y := float((bits & IN_DOWN) != 0) - float((bits & IN_UP) != 0)
	return Vector2(x, y).limit_length(1.0)


## Packs the current keyboard state. `kick` is passed in because "just
## pressed" must be read exactly once per physics tick by the caller.
static func keyboard_bits(kick: bool) -> int:
	var bits := 0
	if Input.is_action_pressed("move_left"):
		bits |= IN_LEFT
	if Input.is_action_pressed("move_right"):
		bits |= IN_RIGHT
	if Input.is_action_pressed("move_up"):
		bits |= IN_UP
	if Input.is_action_pressed("move_down"):
		bits |= IN_DOWN
	if Input.is_action_pressed("sprint"):
		bits |= IN_SPRINT
	if kick:
		bits |= IN_KICK
	return bits


## A random room code that is not a key of `taken`.
static func make_code(rng: RandomNumberGenerator, taken: Dictionary) -> String:
	var code := ""
	while code.is_empty() or taken.has(code):
		code = ""
		for i in CODE_LENGTH:
			code += CODE_ALPHABET[rng.randi_range(0, CODE_ALPHABET.length() - 1)]
	return code


## Snapshot layout (little-endian):
##   u32 tick, u8 phase, u8 score_left, u8 score_right, f32 time_left,
##   f32x2 ball_pos, f32x2 ball_vel, u8 player count, then per player:
##   u32 id, f32x2 pos, f32x2 vel, f32 stamina, f32 regen, u8 exhausted, u32 last_seq
static func encode_snapshot(snap: Dictionary) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(snap.tick)
	buf.put_u8(snap.phase)
	buf.put_u8(mini(snap.score_left, 255))
	buf.put_u8(mini(snap.score_right, 255))
	buf.put_float(snap.time_left)
	_put_vector(buf, snap.ball_pos)
	_put_vector(buf, snap.ball_vel)
	var players: Dictionary = snap.players
	buf.put_u8(players.size())
	for id in players:
		var player: Dictionary = players[id]
		buf.put_u32(id)
		_put_vector(buf, player.pos)
		_put_vector(buf, player.vel)
		buf.put_float(player.stamina)
		buf.put_float(player.regen)
		buf.put_u8(1 if player.exhausted else 0)
		buf.put_u32(player.last_seq)
	return buf.data_array


## Inverse of encode_snapshot(). Returns {} for empty input.
static func decode_snapshot(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	var snap := {}
	snap.tick = buf.get_u32()
	snap.phase = buf.get_u8()
	snap.score_left = buf.get_u8()
	snap.score_right = buf.get_u8()
	snap.time_left = buf.get_float()
	snap.ball_pos = _get_vector(buf)
	snap.ball_vel = _get_vector(buf)
	var players := {}
	for i in buf.get_u8():
		var id := buf.get_u32()
		var player := {}
		player.pos = _get_vector(buf)
		player.vel = _get_vector(buf)
		player.stamina = buf.get_float()
		player.regen = buf.get_float()
		player.exhausted = buf.get_u8() == 1
		player.last_seq = buf.get_u32()
		players[id] = player
	snap.players = players
	return snap


static func _put_vector(buf: StreamPeerBuffer, value: Vector2) -> void:
	buf.put_float(value.x)
	buf.put_float(value.y)


static func _get_vector(buf: StreamPeerBuffer) -> Vector2:
	var x := buf.get_float()
	return Vector2(x, buf.get_float())
