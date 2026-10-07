extends Control

## Title screen: enter a name, then create a room, join one by code, or play
## offline. Connects to the server on demand and sends the request once the
## connection is up.

const LOBBY_SCENE := "res://scenes/lobby.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"

var _name_edit: LineEdit
var _code_edit: LineEdit
var _status: Label
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
	var column := UiKit.screen(self)
	column.add_child(UiKit.title("SOCCER WAR", 64))
	column.add_child(UiKit.label("ONLINE 4V4 FOOTBALL", 14, UiKit.MUTED))

	var card := UiKit.card(column, 420)
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

	_buttons.append(UiKit.button("Play offline", _on_offline_pressed, UiKit.Style.GHOST))
	card.add_child(_buttons.back())
	_status = UiKit.label("", 14, UiKit.HIGHLIGHT)
	card.add_child(_status)

	UiKit.footer(self, "WASD move  ·  Shift sprint  ·  Hold Space shoot  ·  I pass")


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


func _on_offline_pressed() -> void:
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
