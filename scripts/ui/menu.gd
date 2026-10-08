extends Control

## Start screen over the stadium artwork: Play Online, Practice and Settings.
## Play Online swaps the buttons for a panel to create a room or join one by
## code; it connects to the server on demand and sends the request once the
## connection is up. Practice starts the offline match.

const LOBBY_SCENE := "res://scenes/lobby.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"
const CHARACTERS_SCENE := "res://scenes/characters.tscn"
const ARTWORK := preload("res://assets/image/background.jpg")
## Gentle pulse of the title, in seconds per beat.
const TITLE_PULSE_SECONDS := 1.6

var _home: VBoxContainer
var _online_panel: Control
var _online_button: Button
var _practice_button: Button
## Practice mode choice: FREE PLAY / PENALTY / BACK.
var _practice_panel: VBoxContainer
var _free_play_button: Button
var _penalty_button: Button
var _practice_back_button: Button
var _settings_button: Button
var _help_button: Button
var _characters_button: Button
var _help_modal: Control
var _help_close_button: Button
var _settings_panel: SettingsPanel
var _back_button: Button
var _name_edit: LineEdit
var _room_rows: VBoxContainer
var _rooms_note: Label
var _create_button: Button
## Room rows currently shown, and whether a request is in flight.
var _rows_shown: Array = []
var _busy: bool = false
var _status: Label
## Buttons disabled while a request is in flight.
var _buttons: Array[Button] = []
## Request to send as soon as the connection opens.
var _pending_request: Callable
var _leaving: bool = false


func _ready() -> void:
	_build_ui()
	_name_edit.text = Net.player_name
	_status.text = Net.last_error
	Net.last_error = ""
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.room_state_received.connect(_on_room_state)
	Net.error_received.connect(_on_error)
	Net.room_list_received.connect(_refresh_rooms)


func _build_ui() -> void:
	UiKit.artwork_backdrop(self, ARTWORK)
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_top = 48
	layout.offset_bottom = -40
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)

	var title := UiKit.title("SOCCER WAR", 88, UiKit.GOLD)
	layout.add_child(title)
	_pulse(title)
	layout.add_child(UiKit.title("4V4 ONLINE FOOTBALL", 20))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var center := CenterContainer.new()
	layout.add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	_home = _build_home()
	stack.add_child(_home)
	_online_panel = _build_online_panel(stack)
	_online_panel.hide()
	_practice_panel = _build_practice_panel()
	stack.add_child(_practice_panel)
	_practice_panel.hide()

	_status = UiKit.label("", 16, UiKit.HIGHLIGHT)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 6)
	layout.add_child(_status)
	layout.add_child(UiKit.label("WASD move  ·  Shift sprint  ·  Hold Space shoot  ·  I pass", 14, UiKit.MUTED))
	_help_modal = _build_help_modal()
	_settings_panel = SettingsPanel.new()
	add_child(_settings_panel)


func _build_home() -> VBoxContainer:
	var home := VBoxContainer.new()
	home.custom_minimum_size = Vector2(380, 0)
	home.add_theme_constant_override("separation", 14)
	_online_button = _big_button("Play online", _show_online, UiKit.Style.PRIMARY)
	_practice_button = _big_button("Practice", _show_practice, UiKit.Style.ACCENT)
	_characters_button = _big_button("Characters", _on_characters_pressed, UiKit.Style.GHOST)
	_help_button = _big_button("How to play", _show_help, UiKit.Style.GHOST)
	_settings_button = _big_button("Settings", _on_settings_pressed, UiKit.Style.GHOST)
	for button in [_online_button, _practice_button, _characters_button, _help_button, _settings_button]:
		home.add_child(button)
	return home


## Name plus the live room list: join a waiting room or create one.
func _build_online_panel(parent: Control) -> Control:
	var card := UiKit.card(parent, 560)
	card.add_child(UiKit.caption("Your name"))
	_name_edit = UiKit.line_edit("Enter your name (required)", Roster.MAX_NAME_LENGTH)
	_name_edit.text_changed.connect(func(_text: String) -> void: _update_online_buttons())
	card.add_child(_name_edit)

	card.add_child(UiKit.caption("Rooms"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, Protocol.MAX_ROOMS * 46)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	_room_rows = VBoxContainer.new()
	_room_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_room_rows)
	_rooms_note = UiKit.label("", 14, UiKit.MUTED)
	card.add_child(_rooms_note)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_create_button = UiKit.button("Create room", _on_create_pressed, UiKit.Style.PRIMARY)
	_create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_create_button)
	_back_button = UiKit.button("Back", _show_home, UiKit.Style.GHOST)
	_back_button.custom_minimum_size.x = 160
	actions.add_child(_back_button)
	card.add_child(actions)
	# card() returns the column inside the panel; show/hide the panel itself.
	return card.get_parent()


## Rebuilds the room list. Rooms in a match or full are shown but can't be joined.
func _refresh_rooms(rows: Array) -> void:
	_rows_shown = rows
	for row in _room_rows.get_children():
		_room_rows.remove_child(row)
		row.queue_free()
	for room in rows:
		var running: bool = room.phase != Protocol.Phase.LOBBY
		var full: bool = room.players >= room.max_players
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var title := UiKit.label("%s's room" % room.host_name, 18)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(title)
		for text in ["%d/%d" % [room.players, room.max_players], "%d MIN" % room.minutes]:
			var info := UiKit.label(text, 16, UiKit.MUTED)
			info.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(info)
		row.set_meta("joinable", not running and not full)
		if running or full:
			var state := UiKit.label("IN MATCH" if running else "FULL", 16, UiKit.MUTED)
			state.custom_minimum_size.x = 110
			state.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(state)
			row.modulate.a = 0.5 if running else 0.75
		else:
			var join := UiKit.button("Join", _join_room.bind(room.code), UiKit.Style.DANGER)
			join.custom_minimum_size = Vector2(110, 38)
			row.add_child(join)
			row.set_meta("join_button", join)
		_room_rows.add_child(row)
	if rows.size() >= Protocol.MAX_ROOMS:
		_rooms_note.text = "Server is full (%d/%d rooms)" % [rows.size(), Protocol.MAX_ROOMS]
	elif rows.is_empty():
		_rooms_note.text = "No rooms yet - create one!" if Net.room_list_received_once else ""
	else:
		_rooms_note.text = ""
	_update_online_buttons()


## Join and Create need a name, no request in flight, and (Create) a free slot.
func _update_online_buttons() -> void:
	var has_name := not _name_edit.text.strip_edges().is_empty()
	_create_button.disabled = _busy or not has_name or _rows_shown.size() >= Protocol.MAX_ROOMS
	for row in _room_rows.get_children():
		if row.has_meta("join_button"):
			(row.get_meta("join_button") as Button).disabled = _busy or not has_name


## Dimmed full-screen overlay with the controls and rules. Closes with
## Got it, Esc, or a click outside the panel.
func _build_help_modal() -> Control:
	var modal := ColorRect.new()
	modal.color = Color(0, 0, 0, 0.72)
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.gui_input.connect(_on_help_backdrop_input)
	add_child(modal)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(center)

	var card := UiKit.card(center, 660)
	card.add_child(UiKit.title("HOW TO PLAY", 36, UiKit.GOLD))
	card.add_child(UiKit.caption("Controls"))
	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 20)
	controls.add_theme_constant_override("v_separation", 10)
	for row in [
		[["W", "A", "S", "D"], "Move  (or the arrow keys)"],
		[["SHIFT"], "Sprint  -  uses stamina"],
		[["SPACE"], "Hold, then release to shoot  -  hold longer for a harder shot"],
		[["I"], "Pass  -  stops at the first player it reaches"],
		[["ESC"], "Settings  -  pauses practice"],
	]:
		var keys := HBoxContainer.new()
		keys.add_theme_constant_override("separation", 4)
		for key in row[0]:
			keys.add_child(UiKit.key_cap(key))
		controls.add_child(keys)
		var what := UiKit.label(row[1], 16)
		what.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		what.autowrap_mode = TextServer.AUTOWRAP_OFF
		controls.add_child(what)
	card.add_child(controls)

	_help_close_button = UiKit.button("Got it", _hide_help, UiKit.Style.PRIMARY)
	card.add_child(_help_close_button)
	modal.hide()
	return modal


func _show_help() -> void:
	_help_modal.show()
	_help_close_button.grab_focus()


func _hide_help() -> void:
	_help_modal.hide()


func _on_help_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_help()


func _unhandled_input(event: InputEvent) -> void:
	if _help_modal.visible and event.is_action_pressed("ui_cancel"):
		_hide_help()
		get_viewport().set_input_as_handled()


func _big_button(text: String, on_pressed: Callable, style: UiKit.Style) -> Button:
	var button := UiKit.button(text, on_pressed, style)
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 38)
	return button


## Slow, endless "breathing" of the title around its centre.
func _pulse(title: Label) -> void:
	title.resized.connect(func() -> void: title.pivot_offset = title.size / 2.0)
	var tween := title.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title, "scale", Vector2.ONE * 1.04, TITLE_PULSE_SECONDS)
	tween.tween_property(title, "scale", Vector2.ONE, TITLE_PULSE_SECONDS)


func _build_practice_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.add_theme_constant_override("separation", 14)
	_free_play_button = _big_button("Free play", _start_practice.bind(CharactersScreen.MODE_FREE), UiKit.Style.ACCENT)
	_penalty_button = _big_button("Penalty", _start_practice.bind(CharactersScreen.MODE_PENALTY), UiKit.Style.PRIMARY)
	_practice_back_button = _big_button("Back", _show_home, UiKit.Style.GHOST)
	for button in [_free_play_button, _penalty_button, _practice_back_button]:
		panel.add_child(button)
	return panel


func _show_practice() -> void:
	_home.hide()
	_practice_panel.show()
	_status.text = ""


func _show_online() -> void:
	_home.hide()
	_online_panel.show()
	_status.text = ""
	_refresh_rooms(Net.room_list)
	_name_edit.grab_focus()
	# Connect straight away so the room list can come in.
	_send(func() -> void: Net.request_room_list.rpc_id(1), false)


func _show_home() -> void:
	_online_panel.hide()
	_practice_panel.hide()
	_home.show()
	_status.text = ""


func _on_settings_pressed() -> void:
	_settings_panel.open()


func _on_create_pressed() -> void:
	var player_name := _remember_name()
	_send(func() -> void: Net.request_create.rpc_id(1, player_name))


func _join_room(code: String) -> void:
	var player_name := _remember_name()
	_send(func() -> void: Net.request_join.rpc_id(1, code, player_name))


## Practice in `mode` starts by picking who to play as.
func _start_practice(mode: String) -> void:
	Net.leave()
	CharactersScreen.pick_for_practice = true
	CharactersScreen.practice_mode = mode
	_change_scene(CHARACTERS_SCENE)


func _on_characters_pressed() -> void:
	CharactersScreen.pick_for_practice = false
	_change_scene(CHARACTERS_SCENE)


func _remember_name() -> String:
	Net.player_name = Roster.clean_name(_name_edit.text)
	return Net.player_name


## Sends `request` now if connected, otherwise connects first. `blocking`
## requests (join/create) disable the buttons until the server answers.
func _send(request: Callable, blocking: bool = true) -> void:
	if blocking:
		_set_busy(true)
	if Net.is_online():
		request.call()
		return
	_pending_request = request
	_rooms_note.text = "Connecting…"
	if Net.join(Net.server_url()) != OK:
		_on_connection_failed()


func _on_connected() -> void:
	if _pending_request.is_valid():
		_pending_request.call()
		_pending_request = Callable()


func _on_connection_failed() -> void:
	_pending_request = Callable()
	_set_busy(false)
	_rooms_note.text = ""
	_status.text = "Could not reach the server at %s" % Net.server_url()


func _on_room_state(_state: Dictionary) -> void:
	_change_scene(LOBBY_SCENE)


func _on_error(message: String) -> void:
	_set_busy(false)
	_status.text = message


func _set_busy(busy: bool) -> void:
	_busy = busy
	for button in _buttons:
		button.disabled = busy
	_update_online_buttons()


func _change_scene(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(path)
