class_name SnapshotBuffer
extends RefCounted

## Client-side history of server snapshots. Remote players and the ball are
## drawn INTERP_TICKS behind the newest snapshot, interpolated between the
## two snapshots around that moment, so movement stays smooth even though
## snapshots arrive only every other tick and with jitter.

const MAX_SNAPSHOTS := 32
## Two snapshot intervals at 30 Hz snapshots / 60 Hz ticks (~66 ms).
const INTERP_TICKS := 4.0
## Past this drift the render clock jumps instead of easing.
const RESYNC_TICKS := 30.0
## Share of the remaining drift corrected per second.
const CLOCK_CORRECTION := 5.0
## Moves longer than this between snapshots (kickoff resets) are not tweened.
const TELEPORT_DISTANCE := 200.0

## Server tick currently being displayed; fractional between snapshots.
var render_tick: float = -1.0
var _snaps: Array[Dictionary] = []


func push(snap: Dictionary) -> void:
	if not _snaps.is_empty() and snap.tick <= _snaps.back().tick:
		return
	_snaps.append(snap)
	if _snaps.size() > MAX_SNAPSHOTS:
		_snaps.pop_front()


func is_empty() -> bool:
	return _snaps.is_empty()


func latest() -> Dictionary:
	return _snaps.back() if not _snaps.is_empty() else {}


## Advances the render clock by `delta` seconds, easing it toward
## INTERP_TICKS behind the newest snapshot.
func advance(delta: float) -> void:
	if _snaps.is_empty():
		return
	var target: float = _snaps.back().tick - INTERP_TICKS
	render_tick += delta * Protocol.TICK_RATE
	var drift := target - render_tick
	if render_tick < 0.0 or absf(drift) > RESYNC_TICKS:
		render_tick = target
	else:
		render_tick += drift * minf(delta * CLOCK_CORRECTION, 1.0)


## Positions at `render_tick`: { ball_pos, players: { id: pos } }.
func sample() -> Dictionary:
	if _snaps.is_empty():
		return {}
	var older: Dictionary = _snaps[0]
	var newer: Dictionary = _snaps[0]
	for snap in _snaps:
		newer = snap
		if snap.tick > render_tick:
			break
		older = snap
	var t := 0.0
	if newer.tick != older.tick:
		t = clampf((render_tick - older.tick) / float(newer.tick - older.tick), 0.0, 1.0)

	var players := {}
	for id in newer.players:
		var to: Vector2 = newer.players[id].pos
		players[id] = _lerp(older.players[id].pos, to, t) if older.players.has(id) else to
	return {"ball_pos": _lerp(older.ball_pos, newer.ball_pos, t), "players": players}


static func _lerp(from: Vector2, to: Vector2, t: float) -> Vector2:
	return to if from.distance_to(to) > TELEPORT_DISTANCE else from.lerp(to, t)
