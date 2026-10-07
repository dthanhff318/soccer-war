class_name Predictor
extends RefCounted

## Client-side prediction for the local player. Inputs are simulated as soon
## as they are read and kept in a history; each server state rewinds the
## player to the last input the server applied and replays the newer ones.
## Small corrections are hidden by the player's visual offset; large ones
## (kickoff resets) snap.

const SNAP_DISTANCE := 48.0
const MAX_HISTORY := 120

var _player: Player
## (seq, bits) of inputs the server has not acknowledged yet.
var _history: Array[Vector2i] = []
## Shared by every Predictor, so sequence numbers keep rising from one match
## to the next and late inputs from an old match are ignored as stale.
static var _next_seq: int = 1


func _init(player: Player) -> void:
	_player = player


## Simulates `bits` locally and returns the sequence number to send with them.
## Must run inside _physics_process (move_and_slide uses the physics delta).
func apply(bits: int, delta: float) -> int:
	var seq := _next_seq
	_next_seq += 1
	_history.append(Vector2i(seq, bits))
	if _history.size() > MAX_HISTORY:
		_history.pop_front()
	_player.simulate(bits, delta)
	return seq


## Adopts the server's `state` (a Player state plus `last_seq`) and replays
## every input the server has not processed yet. The replay redoes movement
## only (see Player.simulate): the ball is server-driven, and the live kick
## charge must keep counting for the power bar.
func reconcile(state: Dictionary, delta: float) -> void:
	var acked: int = state.last_seq
	while not _history.is_empty() and _history[0].x <= acked:
		_history.pop_front()
	var predicted := _player.position
	_player.set_state(state)
	for entry in _history:
		_player.simulate(entry.y, delta, true)
	var error := predicted - _player.position
	if error.length() > SNAP_DISTANCE:
		_player.visual_offset = Vector2.ZERO
	else:
		_player.visual_offset += error
