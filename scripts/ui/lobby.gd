extends Control

## Room lobby: both teams with each player's character, a character picker,
## the match length (host picks 5 / 7 / 10 minutes) and Start for the host.

const MENU_SCENE := "res://scenes/menu.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"

## "<host>'s ROOM" heading.
var _title_label: Label
## One name list per team, indexed by Roster.Team.
var _team_lists: Array[VBoxContainer] = []
var _start_button: Button
var _character_button: Button
## Match length toggles, in Protocol.MATCH_MINUTES order.
var _duration_buttons: Array[Button] = []
var _picker: CharacterPicker
var _status: Label
var _leaving: bool = false


func _ready() -> void:
	_build_ui()
	Net.room_state_received.connect(_refresh)
	Net.match_started.connect(_on_match_started)
	Net.error_received.connect(_on_error)
	Net.disconnected.connect(_on_disconnected)
	_refresh(Net.current_room)
	# "Match started" can arrive while the menu is still on screen and be
	# missed; the room state already says so, so go straight to the match.
	if Net.current_room.get("phase", Protocol.Phase.LOBBY) != Protocol.Phase.LOBBY:
		_on_match_started.call_deferred()


func _build_ui() -> void:
	var column := UiKit.screen(self)
	_title_label = UiKit.title("", 48, UiKit.HIGHLIGHT)
	column.add_child(_title_label)

	var teams := HBoxContainer.new()
	teams.alignment = BoxContainer.ALIGNMENT_CENTER
	teams.add_theme_constant_override("separation", 24)
	for team in [Roster.Team.LEFT, Roster.Team.RIGHT]:
		var team_card := UiKit.card(teams, 280, Teams.color_of(team))
		team_card.add_child(UiKit.title(Teams.name_of(team), 28, Teams.color_of(team)))
		var names := VBoxContainer.new()
		names.custom_minimum_size = Vector2(0, Roster.MAX_PER_TEAM * 30)
		names.add_theme_constant_override("separation", 6)
		team_card.add_child(names)
		_team_lists.append(names)
		var style := UiKit.Style.PRIMARY if team == Roster.Team.LEFT else UiKit.Style.DANGER
		team_card.add_child(UiKit.button("Join " + Teams.name_of(team), _on_team_pressed.bind(team), style))
	column.add_child(teams)

	var settings := HBoxContainer.new()
	settings.alignment = BoxContainer.ALIGNMENT_CENTER
	settings.add_theme_constant_override("separation", 10)
	_character_button = UiKit.button("Character", _on_character_pressed, UiKit.Style.ACCENT)
	_character_button.custom_minimum_size.x = 300
	settings.add_child(_character_button)
	var length_label := UiKit.label("  MATCH", 16, UiKit.MUTED)
	length_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	settings.add_child(length_label)
	var lengths := ButtonGroup.new()
	for minutes in Protocol.MATCH_MINUTES:
		var option := UiKit.button("%d MIN" % minutes, _on_duration_pressed.bind(minutes), UiKit.Style.GHOST)
		option.toggle_mode = true
		option.button_group = lengths
		option.custom_minimum_size.x = 96
		option.add_theme_stylebox_override("pressed", option.get_theme_stylebox("hover"))
		settings.add_child(option)
		_duration_buttons.append(option)
	column.add_child(settings)

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
	_picker = CharacterPicker.new()
	_picker.picked.connect(_on_character_picked)
	add_child(_picker)


func _refresh(state: Dictionary) -> void:
	if state.is_empty():
		return
	var host_name := ""
	for member in state.players:
		if member.id == state.host_id:
			host_name = member.name
	_title_label.text = ("%s's room" % host_name).to_upper()
	for names in _team_lists:
		for child in names.get_children():
			names.remove_child(child)
			child.queue_free()
	for member in state.players:
		_team_lists[member.team].add_child(_member_row(member, state.host_id))
	var is_host: bool = state.host_id == Net.my_id()
	var minutes: int = state.get("minutes", Protocol.DEFAULT_MATCH_MINUTES)
	for i in _duration_buttons.size():
		_duration_buttons[i].set_pressed_no_signal(Protocol.MATCH_MINUTES[i] == minutes)
		_duration_buttons[i].disabled = not is_host
	for member in state.players:
		if member.id == Net.my_id():
			_character_button.text = "CHARACTER: %s" % Characters.by_id(member.get("character", "")).get("name", "?")
	_start_button.visible = is_host
	if is_host:
		var problem := Roster.start_problem(state.players)
		_start_button.disabled = not problem.is_empty()
		_status.text = problem
	else:
		_status.text = "Waiting for the host to start…"


## Colour chip, name, character and tags for one lobby member.
func _member_row(member: Dictionary, host_id: int) -> HBoxContainer:
	var character := Characters.by_id(member.get("character", ""))
	var is_me: bool = member.id == Net.my_id()
	var text := "%s  -  %s" % [member.name, character.get("name", "?")]
	if member.id == host_id:
		text += "  (host)"
	if is_me:
		text += "  - you"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var chip := TextureRect.new()
	chip.texture = UiKit.color_chip(character.get("color", Color.GRAY), 14)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	var label := UiKit.label(text, 17, UiKit.HIGHLIGHT if is_me else UiKit.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(label)
	row.set_meta("text", text)
	return row


func _on_character_pressed() -> void:
	_picker.open(Net.current_room, Net.my_id())


func _on_character_picked(character_id: String) -> void:
	Net.request_character.rpc_id(1, character_id)


func _on_duration_pressed(minutes: int) -> void:
	Net.request_duration.rpc_id(1, minutes)


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
