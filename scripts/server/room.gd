class_name Room
extends SubViewport

## One room on the server: the lobby roster and, during a match, a physics
## world of its own (separate World2D) simulated at the physics tick rate.
## Clients only send input bits; everything they see comes from here.

const PITCH_SCENE := preload("res://scenes/pitch.tscn")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
@warning_ignore("integer_division")
const SNAPSHOT_EVERY := Protocol.TICK_RATE / Protocol.SNAPSHOT_RATE

## Emitted whenever the lobby state changes (members, phase, settings).
signal changed

var code: String
## Match length picked by the host.
var minutes: int = Protocol.DEFAULT_MATCH_MINUTES
var roster := Roster.new()
var phase: int = Protocol.Phase.LOBBY
## Goals, indexed by Roster.Team.
var score: Array[int] = [0, 0]
var time_left: float = 0.0

var _tick: int = 0
## Counts down the celebration or the result screen.
var _phase_timer: float = 0.0
var _players: Dictionary = {}  # peer id -> Player
var _inputs: Dictionary = {}   # peer id -> InputQueue
var _ball: Ball


func _init(room_code: String) -> void:
	code = room_code
	name = "Room_" + room_code
	world_2d = World2D.new()
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED


func _ready() -> void:
	add_child(PITCH_SCENE.instantiate())


func is_empty() -> bool:
	return roster.is_empty()


func is_in_match() -> bool:
	return phase != Protocol.Phase.LOBBY


func add_player(peer: int, player_name: String) -> String:
	var err := roster.add(peer, player_name)
	if err.is_empty():
		_broadcast_room_state()
	return err


func remove_player(peer: int) -> void:
	roster.remove(peer)
	_inputs.erase(peer)
	if _players.has(peer):
		_players[peer].queue_free()
		_players.erase(peer)
	if not roster.is_empty():
		_broadcast_room_state()


func set_team(peer: int, team: int) -> void:
	var err := "Teams are locked during a match" if is_in_match() else roster.set_team(peer, team)
	if err.is_empty():
		_broadcast_room_state()
	else:
		Net.send_error.rpc_id(peer, err)


func set_character(peer: int, character_id: String) -> void:
	var err := "Characters are locked during a match" if is_in_match() else roster.set_character(peer, character_id)
	if err.is_empty():
		_broadcast_room_state()
	else:
		Net.send_error.rpc_id(peer, err)


func set_duration(peer: int, new_minutes: int) -> void:
	var err := ""
	if peer != roster.host_id:
		err = "Only the host can change the match length"
	elif is_in_match():
		err = "The match has already started"
	elif not Protocol.MATCH_MINUTES.has(new_minutes):
		err = "Unknown match length"
	if err.is_empty():
		minutes = new_minutes
		_broadcast_room_state()
	else:
		Net.send_error.rpc_id(peer, err)


## Row for the room browser.
func summary() -> Dictionary:
	var members: Array = roster.to_dict().players
	var host_name := ""
	for member in members:
		if member.id == roster.host_id:
			host_name = member.name
	return {
		"code": code, "host_name": host_name, "players": roster.size(),
		"max_players": Roster.MAX_PER_TEAM * 2, "minutes": minutes, "phase": phase,
	}


func start(peer: int) -> void:
	if is_in_match():
		return
	var err := roster.can_start(peer)
	if err.is_empty():
		_start_match()
	else:
		Net.send_error.rpc_id(peer, err)


func queue_input(peer: int, seq: int, bits: int) -> void:
	if _inputs.has(peer):
		_inputs[peer].push(seq, bits & Protocol.INPUT_MASK)


func _start_match() -> void:
	score = [0, 0]
	time_left = minutes * 60.0
	_tick = 0
	_ball = BALL_SCENE.instantiate()
	_ball.simulated = false
	add_child(_ball)
	for id in roster.ids():
		var player: Player = PLAYER_SCENE.instantiate()
		player.name = "Player_%d" % id
		player.team = roster.team_of(id)
		add_child(player)
		CharacterStats.apply(player, Characters.by_id(roster.character_of(id)))
		_players[id] = player
		_inputs[id] = InputQueue.new()
	_kickoff()
	phase = Protocol.Phase.PLAYING
	for id in Net.open_peers(roster.ids()):
		Net.send_match_start.rpc_id(id)
	_broadcast_room_state()
	print("[server] room %s: match started with %d players" % [code, roster.size()])


## Ball to the centre, players to their team's formation.
func _kickoff() -> void:
	_ball.reset(MatchRules.CENTER)
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var ids := roster.ids_in_team(team)
		var spots := MatchRules.kickoff_positions(team, ids.size())
		for i in ids.size():
			var player: Player = _players[ids[i]]
			player.position = spots[i]
			player.velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not is_in_match():
		return
	_tick += 1
	if phase == Protocol.Phase.ENDED:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_return_to_lobby()
		return
	_simulate(delta)
	_update_phase(delta)
	if _tick % SNAPSHOT_EVERY == 0 or phase == Protocol.Phase.ENDED:
		_broadcast_snapshot()


## Players move first (they may push or kick the ball), then the ball.
func _simulate(delta: float) -> void:
	for id in _players:
		_players[id].simulate(_inputs[id].take(), delta)
	_ball.step(delta)


func _update_phase(delta: float) -> void:
	time_left = maxf(time_left - delta, 0.0)
	if phase == Protocol.Phase.PLAYING:
		var scorer := MatchRules.scoring_team(_ball.position, _ball.radius)
		if scorer >= 0:
			score[scorer] += 1
			phase = Protocol.Phase.CELEBRATING
			_phase_timer = MatchRules.CELEBRATION_SECONDS
			for id in Net.open_peers(roster.ids()):
				Net.send_goal.rpc_id(id, scorer)
	elif phase == Protocol.Phase.CELEBRATING:
		_phase_timer -= delta
		if _phase_timer <= 0.0:
			_kickoff()
			phase = Protocol.Phase.PLAYING
	if time_left <= 0.0:
		phase = Protocol.Phase.ENDED
		_phase_timer = MatchRules.RESULT_SECONDS
		for id in Net.open_peers(roster.ids()):
			Net.send_match_end.rpc_id(id, score[Roster.Team.LEFT], score[Roster.Team.RIGHT])


func _return_to_lobby() -> void:
	for player in _players.values():
		player.queue_free()
	_players.clear()
	_inputs.clear()
	_ball.queue_free()
	_ball = null
	phase = Protocol.Phase.LOBBY
	_broadcast_room_state()


func _broadcast_room_state() -> void:
	changed.emit()
	var state := roster.to_dict()
	state.code = code
	state.phase = phase
	state.minutes = minutes
	for id in Net.open_peers(roster.ids()):
		Net.send_room_state.rpc_id(id, state)


func _broadcast_snapshot() -> void:
	var players := {}
	for id in _players:
		var state: Dictionary = _players[id].get_state()
		state.last_seq = _inputs[id].last_seq
		players[id] = state
	var bytes := Protocol.encode_snapshot({
		"tick": _tick,
		"phase": phase,
		"score_left": score[Roster.Team.LEFT],
		"score_right": score[Roster.Team.RIGHT],
		"time_left": time_left,
		"ball_pos": _ball.position,
		"ball_vel": _ball.velocity,
		"players": players,
	})
	for id in Net.open_peers(roster.ids()):
		Net.send_snapshot.rpc_id(id, bytes)
