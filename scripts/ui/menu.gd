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
var _settings_button: Button
var _help_button: Button
var _characters_button: Button
var _help_modal: Control
var _help_close_button: Button
var _back_button: Button
var _name_edit: LineEdit
var _code_edit: LineEdit
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

	_status = UiKit.label("", 16, UiKit.HIGHLIGHT)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_status.add_theme_constant_override("outline_size", 6)
	layout.add_child(_status)
	layout.add_child(UiKit.label("WASD move  ·  Shift sprint  ·  Hold Space shoot  ·  I pass", 14, UiKit.MUTED))
	_help_modal = _build_help_modal()


func _build_home() -> VBoxContainer:
	var home := VBoxContainer.new()
	home.custom_minimum_size = Vector2(380, 0)
	home.add_theme_constant_override("separation", 14)
	_online_button = _big_button("Play online", _show_online, UiKit.Style.PRIMARY)
	_practice_button = _big_button("Practice", _on_practice_pressed, UiKit.Style.ACCENT)
	_characters_button = _big_button("Characters", _change_scene.bind(CHARACTERS_SCENE), UiKit.Style.GHOST)
	_help_button = _big_button("How to play", _show_help, UiKit.Style.GHOST)
	# The pixel font has no "·", so stick to letters, spaces and brackets.
	_settings_button = _big_button("Settings (soon)", _on_settings_pressed, UiKit.Style.GHOST)
	for button in [_online_button, _practice_button, _characters_button, _help_button, _settings_button]:
		home.add_child(button)
	return home


func _build_online_panel(parent: Control) -> Control:
	var card := UiKit.card(parent, 420)
	card.add_child(UiKit.caption("Your name"))
	_name_edit = UiKit.line_edit("Enter a name", Roster.MAX_NAME_LENGTH)
	card.add_child(_name_edit)
	_buttons.append(UiKit.button("Create room", _on_create_pressed, UiKit.Style.PRIMARY))
	card.add_child(_buttons.back())

	card.add_child(UiKit.divider("or join a room"))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	_code_edit = UiKit.line_edit("CODE", Protocol.CODE_LENGTH)
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.text_submitted.connect(func(_text: String) -> void: _on_join_pressed())
	join_row.add_child(_code_edit)
	var join := UiKit.button("Join", _on_join_pressed, UiKit.Style.DANGER)
	join.custom_minimum_size.x = 140
	_buttons.append(join)
	join_row.add_child(join)
	card.add_child(join_row)

	_back_button = UiKit.button("Back", _show_home, UiKit.Style.GHOST)
	_buttons.append(_back_button)
	card.add_child(_back_button)
	# card() returns the column inside the panel; show/hide the panel itself.
	return card.get_parent()


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
		[["ESC"], "Leave the match"],
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

	for section in [
		["Rules", [
			"Score in the other team's goal  -  own goals count for them.",
			"Matches last 5 minutes. Most goals wins.",
		]],
		["Play online", [
			"Create a room and share its 4-letter code.",
			"Friends join, pick Blue or Red, then the host presses Start.",
		]],
	]:
		card.add_child(UiKit.caption(section[0]))
		for line in section[1]:
			var bullet := UiKit.label("•  " + line, 16)
			bullet.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			card.add_child(bullet)

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
	button.add_theme_font_size_override("font_size", 28)
	return button


## Slow, endless "breathing" of the title around its centre.
func _pulse(title: Label) -> void:
	title.resized.connect(func() -> void: title.pivot_offset = title.size / 2.0)
	var tween := title.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title, "scale", Vector2.ONE * 1.04, TITLE_PULSE_SECONDS)
	tween.tween_property(title, "scale", Vector2.ONE, TITLE_PULSE_SECONDS)


func _show_online() -> void:
	_home.hide()
	_online_panel.show()
	_status.text = ""
	_name_edit.grab_focus()


func _show_home() -> void:
	_online_panel.hide()
	_home.show()
	_status.text = ""


func _on_settings_pressed() -> void:
	_status.text = "Settings are coming soon"


func _on_create_pressed() -> void:
	var player_name := _remember_name()
	_send(func() -> void: Net.request_create.rpc_id(1, player_name))


func _on_join_pressed() -> void:
	var code := _code_edit.text.strip_edges().to_upper()
	if code.length() != Protocol.CODE_LENGTH:
		_status.text = "Enter the %d-character room code" % Protocol.CODE_LENGTH
		return
	var player_name := _remember_name()
	_send(func() -> void: Net.request_join.rpc_id(1, code, player_name))


func _on_practice_pressed() -> void:
	Net.leave()
	_change_scene(MATCH_SCENE)


func _remember_name() -> String:
	Net.player_name = Roster.clean_name(_name_edit.text)
	return Net.player_name


## Sends `request` now if connected, otherwise connects first.
func _send(request: Callable) -> void:
	_set_busy(true)
	if Net.is_online():
		request.call()
		return
	_pending_request = request
	_status.text = "Connecting…"
	if Net.join(Net.server_url()) != OK:
		_on_connection_failed()


func _on_connected() -> void:
	if _pending_request.is_valid():
		_pending_request.call()
		_pending_request = Callable()


func _on_connection_failed() -> void:
	_pending_request = Callable()
	_set_busy(false)
	_status.text = "Could not reach the server at %s" % Net.server_url()


func _on_room_state(_state: Dictionary) -> void:
	_change_scene(LOBBY_SCENE)


func _on_error(message: String) -> void:
	_set_busy(false)
	_status.text = message


func _set_busy(busy: bool) -> void:
	for button in _buttons:
		button.disabled = busy


func _change_scene(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(path)
