extends Node2D

## Match scene.
## Offline: the scene's own Player reads the keyboard and the ball simulates
## locally; this script keeps score and resets after goals.
## Online: the server is authoritative. The local player is predicted (moves
## the instant a key is pressed); other players and the ball are drawn from
## interpolated server snapshots.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MENU_SCENE := "res://scenes/menu.tscn"
const LOBBY_SCENE := "res://scenes/lobby.tscn"
## Offline practice: stationary blue teammates to pass to.
const OFFLINE_TEAMMATE_SPOTS: Array[Vector2] = [Vector2(520, 220), Vector2(520, 500), Vector2(800, 360)]

var score: Array[int] = [0, 0]

## True between a goal and the kickoff reset, so one goal can't count twice.
var _celebrating: bool = false
var _online: bool = false
var _players: Dictionary = {}  # peer id -> Player (online)
var _local: Player
var _predictor: Predictor
var _buffer := SnapshotBuffer.new()
## Newest server state of the local player, reconciled on the next physics
## tick (replaying inputs must happen inside _physics_process).
var _pending_state: Dictionary = {}
var _leaving: bool = false

@onready var _ball: Ball = $Ball
@onready var _scoreboard: Scoreboard = $UI/Scoreboard
@onready var _stamina_bar: StaminaBar = $UI/StaminaBar
@onready var _goal_banner: GoalBanner = $UI/GoalBanner
@onready var _status: Label = $UI/Status
@onready var _result: Label = $UI/Result


func _ready() -> void:
	_result.hide()
	_online = Net.is_online() and not Net.current_room.is_empty()
	if _online:
		_setup_online()
	else:
		_setup_offline()


func _setup_offline() -> void:
	_local = $Player
	_local.keyboard_control = true
	_local.is_local = true
	_local.stamina_changed.connect(_stamina_bar.set_stamina)
	for i in OFFLINE_TEAMMATE_SPOTS.size():
		var mate: Player = PLAYER_SCENE.instantiate()
		mate.team = Roster.Team.LEFT
		mate.display_name = "Mate %d" % (i + 1)
		mate.position = OFFLINE_TEAMMATE_SPOTS[i]
		add_child(mate)


func _setup_online() -> void:
	$Player.queue_free()
	_ball.simulated = false
	# Same kickoff formation the server uses, so nobody jumps on the first snapshot.
	var team_slots: Array[int] = [0, 0]
	var team_sizes: Array[int] = [0, 0]
	for member in Net.current_room.players:
		team_sizes[member.team] += 1
	for member in Net.current_room.players:
		var player: Player = PLAYER_SCENE.instantiate()
		player.team = member.team
		player.position = MatchRules.kickoff_positions(member.team, team_sizes[member.team])[team_slots[member.team]]
		team_slots[member.team] += 1
		player.display_name = member.name
		player.is_local = member.id == Net.my_id()
		add_child(player)
		_players[member.id] = player
		if player.is_local:
			_local = player
	if _local == null:
		_leave_to(MENU_SCENE)
		return
	_predictor = Predictor.new(_local)
	_local.stamina_changed.connect(_stamina_bar.set_stamina)
	_scoreboard.set_clock(MatchRules.format_clock(MatchRules.MATCH_SECONDS))
	Net.snapshot_received.connect(_on_snapshot)
	Net.goal_scored.connect(_on_goal_scored)
	Net.match_ended.connect(_on_match_ended)
	Net.room_state_received.connect(_on_room_state)
	Net.disconnected.connect(_on_disconnected)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _online:
			Net.leave()
		_leave_to(MENU_SCENE)


func _physics_process(delta: float) -> void:
	if not _online:
		_check_offline_goal()
		return
	if _predictor == null:
		return
	if not _pending_state.is_empty():
		_predictor.reconcile(_pending_state, delta)
		_pending_state = {}
	var bits := Protocol.keyboard_bits(Input.is_action_just_pressed("kick"), Input.is_action_just_pressed("pass"))
	var seq := _predictor.apply(bits, delta)
	Net.send_input.rpc_id(1, seq, bits)


func _process(delta: float) -> void:
	if not _online:
		return
	_status.text = "Ping %d ms" % Net.ping_ms
	_buffer.advance(delta)
	var view := _buffer.sample()
	if view.is_empty():
		return
	_ball.show_at(view.ball_pos)
	for id in view.players:
		var player: Player = _players.get(id)
		if player and player != _local:
			player.position = view.players[id]


func _on_snapshot(snap: Dictionary) -> void:
	_buffer.push(snap)
	_scoreboard.set_score(snap.score_left, snap.score_right)
	_scoreboard.set_clock(MatchRules.format_clock(snap.time_left))
	if snap.players.has(Net.my_id()):
		_pending_state = snap.players[Net.my_id()]


func _on_goal_scored(_team: int) -> void:
	_goal_banner.play()


func _on_match_ended(score_left: int, score_right: int) -> void:
	_result.text = "%s\n%d - %d" % [MatchRules.result_text(score_left, score_right), score_left, score_right]
	_result.show()


## Back in the lobby once the server ends the match; otherwise drop players
## who left mid-match.
func _on_room_state(state: Dictionary) -> void:
	if state.phase == Protocol.Phase.LOBBY:
		_leave_to(LOBBY_SCENE)
		return
	var present := {}
	for member in state.players:
		present[member.id] = true
	for id in _players.keys():
		if not present.has(id):
			_players[id].queue_free()
			_players.erase(id)


func _on_disconnected() -> void:
	_leave_to(MENU_SCENE)


func _leave_to(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file.call_deferred(path)


func _check_offline_goal() -> void:
	if _celebrating:
		return
	var team := MatchRules.scoring_team(_ball.global_position, _ball.radius)
	if team >= 0:
		_on_offline_goal(team)


## Scores for `team`, celebrates while the ball settles in the net, then
## resets for kickoff.
func _on_offline_goal(team: int) -> void:
	_celebrating = true
	score[team] += 1
	_scoreboard.set_score(score[Roster.Team.LEFT], score[Roster.Team.RIGHT])
	_goal_banner.play()

	await get_tree().create_timer(MatchRules.CELEBRATION_SECONDS, false, true).timeout
	_ball.reset(MatchRules.CENTER)
	_celebrating = false
