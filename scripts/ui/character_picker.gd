class_name CharacterPicker
extends Control

## Lobby overlay to choose a character. Options a player can't take are
## dimmed with the reason as a tooltip (a teammate has it, or the team
## already has a goalkeeper); the server checks the same rules again.

signal picked(character_id: String)

var _options: Dictionary = {}  # character id -> Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UiKit.card(center, 820)
	card.add_child(UiKit.title("PICK YOUR CHARACTER", 32, UiKit.GOLD))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	card.add_child(grid)
	for character in Characters.ALL:
		var option := UiKit.button(character.name, _on_option.bind(character.id), UiKit.Style.GHOST)
		option.icon = UiKit.color_chip(character.color, 14)
		option.custom_minimum_size = Vector2(150, 52)
		option.add_theme_font_size_override("font_size", 24)
		grid.add_child(option)
		_options[character.id] = option
	card.add_child(UiKit.button("Cancel", hide, UiKit.Style.GHOST))


## Shows the picker for `my_id` given the lobby `state`.
func open(state: Dictionary, my_id: int) -> void:
	for character_id in _options:
		var reason := unavailable_reason(state, my_id, character_id)
		var option: Button = _options[character_id]
		option.disabled = not reason.is_empty()
		option.tooltip_text = reason
	show()


func option(character_id: String) -> Button:
	return _options[character_id]


## Why `my_id` can't pick `character_id` in `state`, or "".
static func unavailable_reason(state: Dictionary, my_id: int, character_id: String) -> String:
	var players: Array = state.get("players", [])
	var my_team := -1
	for member in players:
		if member.id == my_id:
			my_team = member.team
	var wants_keeper: bool = Characters.by_id(character_id).get("keeper", false)
	for member in players:
		if member.id == my_id or member.team != my_team:
			continue
		if member.get("character", "") == character_id:
			return "Taken by a teammate"
		if wants_keeper and Characters.by_id(member.get("character", "")).get("keeper", false):
			return "Your team already has a goalkeeper"
	return ""


func _on_option(character_id: String) -> void:
	hide()
	picked.emit(character_id)
