class_name Teams
extends RefCounted

## How each team looks, indexed by Roster.Team. This is the only place team
## names, colours and sprites are defined: restyle a team by editing its row.

const STYLES: Array[Dictionary] = [
	{
		"name": "BLUE",
		"color": Color(0.2, 0.35, 1.0),
		"sprite": preload("res://assets/field/player/18.png"),
	},
	{
		"name": "RED",
		"color": Color(0.95, 0.25, 0.25),
		"sprite": preload("res://assets/field/player/6.png"),
	},
]


static func name_of(team: int) -> String:
	return STYLES[team].name


static func color_of(team: int) -> Color:
	return STYLES[team].color


static func sprite_of(team: int) -> Texture2D:
	return STYLES[team].sprite
