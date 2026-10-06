class_name InputQueue
extends RefCounted

## Server-side buffer of one player's inputs. One input is consumed per tick;
## a backlog drains two at a time, and an empty queue repeats the last
## movement (without the kick) so a late packet doesn't freeze the player.

const MAX_QUEUED := 30
const CATCH_UP_THRESHOLD := 3

## Sequence number of the last consumed input, echoed in snapshots so the
## client knows which of its inputs the server state already includes.
var last_seq: int = 0
var _last_bits: int = 0
## (seq, bits) pairs, oldest first.
var _queue: Array[Vector2i] = []


func push(seq: int, bits: int) -> void:
	var newest: int = _queue.back().x if not _queue.is_empty() else last_seq
	if seq <= newest:
		return
	_queue.append(Vector2i(seq, bits))
	if _queue.size() > MAX_QUEUED:
		_queue.pop_front()


## Input bits to simulate this tick, oldest first.
func take() -> Array[int]:
	var result: Array[int] = []
	if _queue.is_empty():
		result.append(_last_bits & ~Protocol.IN_KICK)
		return result
	var count := 2 if _queue.size() > CATCH_UP_THRESHOLD else 1
	for i in count:
		var entry: Vector2i = _queue.pop_front()
		last_seq = entry.x
		_last_bits = entry.y
		result.append(entry.y)
	return result
