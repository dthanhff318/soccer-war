class_name InputQueue
extends RefCounted

## Server-side buffer of one player's inputs. Exactly one input is simulated
## per tick, so sending faster never moves a player faster.
##
## - Starved (nothing queued): the last movement repeats, without the kick,
##   for up to MAX_REPEAT ticks; after that the player stands still.
## - Each repeated tick stood in for an input that is still on its way; when
##   that input arrives it is acknowledged but not simulated again.
## - More than MAX_BACKLOG queued: the oldest are skipped the same way, so a
##   burst never leaves a standing delay.
## Skipped inputs pass their kick on to the next input, so no kick is lost.

const MAX_BACKLOG := 2
const MAX_REPEAT := 6
## Upper bound on remembered repeats (half a second of ticks).
const MAX_DEBT := 30

## Sequence number of the last consumed input, echoed in snapshots so the
## client knows which of its inputs the server state already includes.
var last_seq: int = 0
var _last_bits: int = 0
## Repeated ticks whose real inputs have not arrived yet.
var _debt: int = 0
## Consecutive ticks with nothing queued.
var _starved_ticks: int = 0
## (seq, bits) pairs, oldest first.
var _queue: Array[Vector2i] = []


func push(seq: int, bits: int) -> void:
	var newest: int = _queue.back().x if not _queue.is_empty() else last_seq
	if seq > newest:
		_queue.append(Vector2i(seq, bits))


## Input bits to simulate this tick.
func take() -> int:
	while _queue.size() > 1 and (_debt > 0 or _queue.size() > MAX_BACKLOG):
		_skip_oldest()
	if _queue.is_empty():
		_debt = mini(_debt + 1, MAX_DEBT)
		_starved_ticks += 1
		return _last_bits & ~Protocol.IN_KICK if _starved_ticks <= MAX_REPEAT else 0
	_starved_ticks = 0
	var entry: Vector2i = _queue.pop_front()
	last_seq = entry.x
	_last_bits = entry.y
	return entry.y


## Acknowledges the oldest input without simulating it.
func _skip_oldest() -> void:
	var skipped: Vector2i = _queue.pop_front()
	last_seq = skipped.x
	_debt = maxi(_debt - 1, 0)
	var next: Vector2i = _queue[0]
	next.y |= skipped.y & Protocol.IN_KICK
	_queue[0] = next
