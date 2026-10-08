class_name Roster
extends RefCounted

## Who is in a room: names, teams, characters and the host, plus the room's
## rules. Methods that can be refused return an error message, or "".
## Character rules: no two teammates share a character, and a team has at
## most one goalkeeper (exactly one once it has two or more players).

enum Team { LEFT, RIGHT }

const MAX_PER_TEAM := 4
const MAX_NAME_LENGTH := 12
## Order in which free outfield characters are handed out.
const DEFAULT_PICKS: Array[String] = ["captain", "blitz", "cannon", "maestro", "dynamo", "silk", "rocket", "sniper"]

var host_id: int = 0
## Members in join order: { id, name, team, character }.
var _members: Array[Dictionary] = []


static func clean_name(raw: String) -> String:
	var cleaned := raw.strip_edges().left(MAX_NAME_LENGTH)
	return cleaned if not cleaned.is_empty() else "Player"


## Adds a player to the smaller team (LEFT on a tie). The first player hosts.
func add(id: int, player_name: String) -> String:
	if has(id):
		return ""
	if size() >= MAX_PER_TEAM * 2:
		return "Room is full"
	var team := Team.LEFT if count(Team.LEFT) <= count(Team.RIGHT) else Team.RIGHT
	_members.append({"id": id, "name": clean_name(player_name), "team": team, "character": _free_outfielder(team)})
	if host_id == 0:
		host_id = id
	return ""


## Removes a player; the host role passes to the longest-standing member.
func remove(id: int) -> void:
	for i in _members.size():
		if _members[i].id == id:
			_members.remove_at(i)
			break
	if host_id == id:
		host_id = _members[0].id if not _members.is_empty() else 0


func set_team(id: int, team: int) -> String:
	var member := _find(id)
	if member.is_empty():
		return "Not in this room"
	if team != Team.LEFT and team != Team.RIGHT:
		return "Unknown team"
	if member.team == team:
		return ""
	if count(team) >= MAX_PER_TEAM:
		return "Team is full"
	member.team = team
	# Keep the character only if the new team allows it.
	var character: Dictionary = Characters.by_id(member.character)
	if _taken_in_team(team, member.character, id) or (character.keeper and _team_keeper(team, id) != 0):
		member.character = _free_outfielder(team, id)
	return ""


func set_character(id: int, character_id: String) -> String:
	var member := _find(id)
	if member.is_empty():
		return "Not in this room"
	var character := Characters.by_id(character_id)
	if character.is_empty():
		return "Unknown character"
	if _taken_in_team(member.team, character_id, id):
		return "Taken by a teammate"
	if character.keeper and _team_keeper(member.team, id) != 0:
		return "Your team already has a goalkeeper"
	member.character = character_id
	return ""


func character_of(id: int) -> String:
	return _find(id).get("character", "")


func can_start(requester: int) -> String:
	if requester != host_id:
		return "Only the host can start the match"
	return start_problem(_members)


## Why a lobby with these members (dicts with team and character) can't
## start yet, or "". Shared with the client to explain a disabled Start.
static func start_problem(members: Array) -> String:
	var players := [0, 0]
	var keepers := [0, 0]
	for member in members:
		players[member.team] += 1
		if Characters.by_id(member.get("character", "")).get("keeper", false):
			keepers[member.team] += 1
	if players[Team.LEFT] == 0 or players[Team.RIGHT] == 0:
		return "Each team needs at least one player"
	for team in [Team.LEFT, Team.RIGHT]:
		if players[team] >= 2 and keepers[team] == 0:
			return "%s needs a goalkeeper" % Teams.name_of(team)
	return ""


func has(id: int) -> bool:
	return not _find(id).is_empty()


func size() -> int:
	return _members.size()


func is_empty() -> bool:
	return _members.is_empty()


func count(team: int) -> int:
	return ids_in_team(team).size()


## Team of `id`, or -1 when not a member.
func team_of(id: int) -> int:
	return _find(id).get("team", -1)


func ids() -> Array[int]:
	var result: Array[int] = []
	for member in _members:
		result.append(member.id)
	return result


func ids_in_team(team: int) -> Array[int]:
	var result: Array[int] = []
	for member in _members:
		if member.team == team:
			result.append(member.id)
	return result


## Lobby state sent to clients.
func to_dict() -> Dictionary:
	return {"host_id": host_id, "players": _members.duplicate(true)}


## True when someone in `team` other than `except_id` plays `character_id`.
func _taken_in_team(team: int, character_id: String, except_id: int = 0) -> bool:
	for member in _members:
		if member.team == team and member.id != except_id and member.character == character_id:
			return true
	return false


## Id of the keeper in `team` other than `except_id`, or 0.
func _team_keeper(team: int, except_id: int = 0) -> int:
	for member in _members:
		if member.team == team and member.id != except_id and Characters.by_id(member.character).get("keeper", false):
			return member.id
	return 0


func _free_outfielder(team: int, except_id: int = 0) -> String:
	for character_id in DEFAULT_PICKS:
		if not _taken_in_team(team, character_id, except_id):
			return character_id
	return DEFAULT_PICKS[0]


func _find(id: int) -> Dictionary:
	for member in _members:
		if member.id == id:
			return member
	return {}
