extends Control

## Room lobby: shows the code to share and both teams, lets players switch
## team and the host start the match.

const MENU_SCENE := "res://scenes/menu.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"

var _code_label: Label
## One name list per team, indexed by Roster.Team.
var _team_lists: Array[VBoxContainer] = []
var _start_button: Button
var _status: Label
var _leaving: bool = false


func _ready() -> void:
	_build_ui()
	Net.room_state_received.connect(_refresh)
	Net.match_started.connect(_on_match_started)
	Net.error_received.connect(_on_error)
	Net.disconnected.connect(_on_disconnected)
	_refresh(Net.current_room)


func _build_ui() -> void:
	var column := UiKit.screen(self)
	column.add_child(UiKit.label("ROOM CODE", 14, UiKit.MUTED))
	_code_label = UiKit.title("", 64, UiKit.HIGHLIGHT)
	column.add_child(_code_label)
	column.add_child(UiKit.label("Share this code with your friends", 14, UiKit.MUTED))

	var teams := HBoxContainer.new()
	teams.alignment = BoxContainer.ALIGNMENT_CENTER
	teams.add_theme_constant_override("separation", 24)
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var team_card := UiKit.card(teams, 280, MatchRules.TEAM_COLORS[team])
		team_card.add_child(UiKit.title(MatchRules.TEAM_NAMES[team], 28, MatchRules.TEAM_COLORS[team]))
		var names := VBoxContainer.new()
		names.custom_minimum_size = Vector2(0, Roster.MAX_PER_TEAM * 30)
		names.add_theme_constant_override("separation", 6)
		team_card.add_child(names)
		_team_lists.append(names)
		var style := UiKit.Style.PRIMARY if team == Roster.Team.LEFT else UiKit.Style.DANGER
		team_card.add_child(UiKit.button("Join " + MatchRules.TEAM_NAMES[team], _on_team_pressed.bind(team), style))
	column.add_child(teams)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	_start_button = UiKit.button("Start match", _on_start_pressed, UiKit.Style.SUCCESS)
	_start_button.custom_minimum_size.x = 260
	actions.add_child(_start_button)
	var leave := UiKit.button("Leave", _on_leave_pressed, UiKit.Style.GHOST)
	leave.custom_minimum_size.x = 160
	actions.add_child(leave)
	column.add_child(actions)
	_status = UiKit.label("", 14, UiKit.HIGHLIGHT)
	column.add_child(_status)


func _refresh(state: Dictionary) -> void:
	if state.is_empty():
		return
	_code_label.text = state.code
	for names in _team_lists:
		for child in names.get_children():
			child.queue_free()
	for member in state.players:
		var text: String = member.name
		if member.id == state.host_id:
			text += "  (host)"
		var is_me: bool = member.id == Net.my_id()
		if is_me:
			text += "  - you"
		var row := UiKit.label(text, 18, UiKit.HIGHLIGHT if is_me else UiKit.TEXT)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_team_lists[member.team].add_child(row)
	var is_host: bool = state.host_id == Net.my_id()
	_start_button.visible = is_host
	_status.text = "" if is_host else "Waiting for the host to start…"


func _on_team_pressed(team: int) -> void:
	Net.request_team.rpc_id(1, team)


func _on_start_pressed() -> void:
	Net.request_start.rpc_id(1)


func _on_leave_pressed() -> void:
	Net.leave()
	_change_scene(MENU_SCENE)


func _on_match_started() -> void:
	_change_scene(MATCH_SCENE)


func _on_error(message: String) -> void:
	_status.text = message


func _on_disconnected() -> void:
	_change_scene(MENU_SCENE)


func _change_scene(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(path)
