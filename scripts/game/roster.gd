class_name Roster
extends RefCounted

## Who is in a room: names, teams and the host, plus the room's membership
## rules. Methods that can be refused return an error message, or "".

enum Team { LEFT, RIGHT }

const MAX_PER_TEAM := 4
const MAX_NAME_LENGTH := 12

var host_id: int = 0
## Members in join order: { id, name, team }.
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
	_members.append({"id": id, "name": clean_name(player_name), "team": team})
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
	return ""


func can_start(requester: int) -> String:
	if requester != host_id:
		return "Only the host can start the match"
	if count(Team.LEFT) == 0 or count(Team.RIGHT) == 0:
		return "Each team needs at least one player"
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


func _find(id: int) -> Dictionary:
	for member in _members:
		if member.id == id:
			return member
	return {}
