class_name Characters
extends RefCounted

## The playable roster. Stats run 1–99, where 50 means today's default
## player. Every outfield character spends the same budget, and so does every
## keeper, so picking one is about play style rather than raw strength.

const STAT_KEYS: Array[String] = ["pace", "stamina", "shooting", "passing", "dribbling"]
const KEEPER_KEYS: Array[String] = ["reflexes", "handling", "diving"]
const STAT_LABELS := {
	"pace": "PAC", "stamina": "STA", "shooting": "SHO", "passing": "PAS", "dribbling": "DRI",
	"reflexes": "REF", "handling": "HAN", "diving": "DIV",
}

const OUTFIELD_BUDGET := 300
## Keepers trade outfield skill for their keeper stats.
const KEEPER_OUTFIELD_BUDGET := 200
const KEEPER_BUDGET := 210

const ALL: Array[Dictionary] = [
	{
		"id": "blitz", "name": "BLITZ", "role": "Winger", "keeper": false,
		"color": Color(1.0, 0.85, 0.2),
		"stats": {"pace": 95, "stamina": 60, "shooting": 50, "passing": 45, "dribbling": 50},
		"description": "Fastest legs in the game. Burns past anyone on the wing, but the shots lack power.",
	},
	{
		"id": "cannon", "name": "CANNON", "role": "Striker", "keeper": false,
		"color": Color(0.95, 0.3, 0.2),
		"stats": {"pace": 50, "stamina": 50, "shooting": 95, "passing": 50, "dribbling": 55},
		"description": "Charges a full-power shot quicker than anyone and hits it hardest. Slow on the turn.",
	},
	{
		"id": "maestro", "name": "MAESTRO", "role": "Playmaker", "keeper": false,
		"color": Color(0.55, 0.45, 1.0),
		"stats": {"pace": 50, "stamina": 60, "shooting": 45, "passing": 95, "dribbling": 50},
		"description": "Sees every pass. Long, accurate balls that send teammates through on goal.",
	},
	{
		"id": "dynamo", "name": "DYNAMO", "role": "Box to box", "keeper": false,
		"color": Color(0.3, 0.85, 0.45),
		"stats": {"pace": 60, "stamina": 95, "shooting": 45, "passing": 55, "dribbling": 45},
		"description": "Never stops running. Sprints for most of the match and presses all game long.",
	},
	{
		"id": "silk", "name": "SILK", "role": "Dribbler", "keeper": false,
		"color": Color(0.95, 0.45, 0.8),
		"stats": {"pace": 65, "stamina": 50, "shooting": 50, "passing": 45, "dribbling": 90},
		"description": "The ball sticks to those boots, and reaches it from further away than anyone.",
	},
	{
		"id": "rocket", "name": "ROCKET", "role": "Forward", "keeper": false,
		"color": Color(1.0, 0.55, 0.15),
		"stats": {"pace": 80, "stamina": 45, "shooting": 75, "passing": 50, "dribbling": 50},
		"description": "Quick and deadly in front of goal, but runs out of breath early.",
	},
	{
		"id": "captain", "name": "CAPTAIN", "role": "All rounder", "keeper": false,
		"color": Color(0.35, 0.65, 1.0),
		"stats": {"pace": 60, "stamina": 60, "shooting": 60, "passing": 60, "dribbling": 60},
		"description": "No weaknesses, no tricks. A safe pick for any position and for new players.",
	},
	{
		"id": "sniper", "name": "SNIPER", "role": "Second striker", "keeper": false,
		"color": Color(0.6, 0.9, 0.95),
		"stats": {"pace": 55, "stamina": 45, "shooting": 80, "passing": 70, "dribbling": 50},
		"description": "Picks out the corner from distance and threads passes through traffic.",
	},
	{
		"id": "the_wall", "name": "THE WALL", "role": "Goalkeeper", "keeper": true,
		"color": Color(0.75, 0.75, 0.8),
		"stats": {"pace": 40, "stamina": 60, "shooting": 40, "passing": 35, "dribbling": 25},
		"keeper_stats": {"reflexes": 65, "handling": 90, "diving": 55},
		"description": "Huge hands. Holds on to shots other keepers would spill.",
	},
	{
		"id": "cat", "name": "CAT", "role": "Goalkeeper", "keeper": true,
		"color": Color(0.2, 0.9, 0.75),
		"stats": {"pace": 50, "stamina": 50, "shooting": 35, "passing": 40, "dribbling": 25},
		"keeper_stats": {"reflexes": 90, "handling": 50, "diving": 70},
		"description": "Lightning reflexes and quick feet across the goal, but the ball often bounces loose.",
	},
]


## The character with `id`, or {} when there is none.
static func by_id(id: String) -> Dictionary:
	for character in ALL:
		if character.id == id:
			return character
	return {}
