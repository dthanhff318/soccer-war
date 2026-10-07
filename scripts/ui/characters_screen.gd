class_name CharactersScreen
extends Control

## Character list: every playable character on the left, the picked one's
## role, description and stats on the right. Opened from the start menu
## either to browse, or (Practice) to pick who to play as.

const MENU_SCENE := "res://scenes/menu.tscn"
const MATCH_SCENE := "res://scenes/main.tscn"
const DEFAULT_CHARACTER := "captain"

## Set by the menu before opening this screen: true shows PLAY (Practice).
static var pick_for_practice: bool = false
## Who Practice plays as; remembered between visits.
static var practice_character_id: String = DEFAULT_CHARACTER
const ARTWORK := preload("res://assets/image/background.jpg")
const LIST_WIDTH := 300
const DETAIL_WIDTH := 600

## One toggle button per character, in Characters.ALL order.
var _entries: Array[Button] = []
var _detail_chip: TextureRect
var _detail_name: Label
var _detail_role: Label
var _detail_description: Label
var _stat_rows: VBoxContainer
var _back_button: Button
var _play_button: Button
var _selected: int = 0
var _leaving: bool = false


func _ready() -> void:
	_build_ui()
	var start := 0
	if pick_for_practice:
		start = maxi(Characters.ALL.find(Characters.by_id(practice_character_id)), 0)
	_show(start)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func _build_ui() -> void:
	UiKit.artwork_backdrop(self, ARTWORK)
	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_top = 32
	layout.offset_bottom = -32
	layout.add_theme_constant_override("separation", 20)
	add_child(layout)
	layout.add_child(UiKit.title("PICK YOUR PLAYER" if pick_for_practice else "CHARACTERS", 48, UiKit.GOLD))

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)

	var list := UiKit.card(columns, LIST_WIDTH)
	list.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for i in Characters.ALL.size():
		var character: Dictionary = Characters.ALL[i]
		var entry := UiKit.list_entry(character.name, character.color, group, _show.bind(i))
		_entries.append(entry)
		list.add_child(entry)

	var detail := UiKit.card(columns, DETAIL_WIDTH)
	detail.add_theme_constant_override("separation", 14)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	_detail_chip = TextureRect.new()
	_detail_chip.custom_minimum_size = Vector2(48, 48)
	_detail_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_detail_chip)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	# Labels in a row get no width of their own, so they must not wrap.
	_detail_name = UiKit.title("", 40)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	titles.add_child(_detail_name)
	_detail_role = UiKit.caption("")
	_detail_role.autowrap_mode = TextServer.AUTOWRAP_OFF
	titles.add_child(_detail_role)
	header.add_child(titles)
	detail.add_child(header)
	_detail_description = UiKit.label("", 17)
	_detail_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail.add_child(_detail_description)
	_stat_rows = VBoxContainer.new()
	_stat_rows.add_theme_constant_override("separation", 8)
	detail.add_child(_stat_rows)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)
	_back_button = UiKit.button("Back", _on_back_pressed, UiKit.Style.GHOST)
	_back_button.custom_minimum_size.x = 220
	footer.add_child(_back_button)
	_play_button = UiKit.button("Play", _on_play_pressed, UiKit.Style.ACCENT)
	_play_button.custom_minimum_size.x = 260
	_play_button.visible = pick_for_practice
	footer.add_child(_play_button)


## Fills the detail card with the character at `index`.
func _show(index: int) -> void:
	var character: Dictionary = Characters.ALL[index]
	_selected = index
	_entries[index].button_pressed = true
	_detail_chip.texture = UiKit.color_chip(character.color, 48)
	_detail_name.text = character.name
	_detail_name.add_theme_color_override("font_color", character.color)
	_detail_role.text = character.role.to_upper()
	_detail_description.text = character.description
	for row in _stat_rows.get_children():
		_stat_rows.remove_child(row)
		row.queue_free()
	if character.keeper:
		for key in Characters.KEEPER_KEYS:
			_stat_rows.add_child(_stat_row(key, character.keeper_stats[key], UiKit.GOLD))
	for key in Characters.STAT_KEYS:
		_stat_rows.add_child(_stat_row(key, character.stats[key], _bar_color(character.stats[key])))


func _stat_row(key: String, value: int, fill: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := UiKit.title(Characters.STAT_LABELS[key], 16)
	name_label.custom_minimum_size.x = 56
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	row.add_child(UiKit.stat_bar(value, fill))
	var number := UiKit.title(str(value), 16)
	number.custom_minimum_size.x = 40
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(number)
	return row


## Green for strengths, yellow for average, orange for weak spots.
static func _bar_color(value: int) -> Color:
	if value >= 75:
		return Color(0.3, 0.85, 0.4)
	if value >= 50:
		return Color(0.95, 0.8, 0.25)
	return Color(0.95, 0.5, 0.2)


func _on_back_pressed() -> void:
	_leave_to(MENU_SCENE)


## Practice as the selected character.
func _on_play_pressed() -> void:
	practice_character_id = Characters.ALL[_selected].id
	_leave_to(MATCH_SCENE)


func _leave_to(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(path)
