extends TestCase


func test_first_player_becomes_host() -> void:
	var roster := Roster.new()
	check_eq(roster.add(10, "Alice"), "", "add ok")
	check_eq(roster.host_id, 10, "host")


func test_players_alternate_to_smaller_team() -> void:
	var roster := Roster.new()
	for id in [1, 2, 3, 4]:
		roster.add(id, "P%d" % id)
	check_eq(roster.team_of(1), Roster.Team.LEFT, "1st")
	check_eq(roster.team_of(2), Roster.Team.RIGHT, "2nd")
	check_eq(roster.team_of(3), Roster.Team.LEFT, "3rd")
	check_eq(roster.team_of(4), Roster.Team.RIGHT, "4th")


func test_ninth_player_is_refused() -> void:
	var roster := Roster.new()
	for id in range(1, 9):
		check_eq(roster.add(id, "P"), "", "player %d" % id)
	check_eq(roster.add(9, "P"), "Room is full", "9th")
	check_eq(roster.size(), 8, "size")


func test_switch_team_refused_when_full() -> void:
	var roster := Roster.new()
	for id in range(1, 8):
		roster.add(id, "P")
	# LEFT has 4 (ids 1,3,5,7), RIGHT has 3.
	check_eq(roster.set_team(2, Roster.Team.LEFT), "Team is full", "left full")
	check_eq(roster.set_team(1, Roster.Team.RIGHT), "", "switch to right")
	check_eq(roster.team_of(1), Roster.Team.RIGHT, "moved")


func test_set_team_rejects_unknown_team_and_player() -> void:
	var roster := Roster.new()
	roster.add(1, "A")
	check_eq(roster.set_team(1, 5), "Unknown team", "bad team")
	check_eq(roster.set_team(99, Roster.Team.LEFT), "Not in this room", "bad player")


func test_host_passes_to_oldest_member() -> void:
	var roster := Roster.new()
	roster.add(1, "A")
	roster.add(2, "B")
	roster.add(3, "C")
	roster.remove(1)
	check_eq(roster.host_id, 2, "next host")
	roster.remove(2)
	roster.remove(3)
	check_eq(roster.host_id, 0, "no host when empty")
	check(roster.is_empty(), "empty")


func test_can_start_rules() -> void:
	var roster := Roster.new()
	roster.add(1, "A")
	check_eq(roster.can_start(1), "Each team needs at least one player", "one team empty")
	roster.add(2, "B")
	check_eq(roster.can_start(2), "Only the host can start the match", "not host")
	check_eq(roster.can_start(1), "", "ok")


func test_clean_name() -> void:
	check_eq(Roster.clean_name("  Bob  "), "Bob", "trim")
	check_eq(Roster.clean_name("   "), "Player", "blank")
	check_eq(Roster.clean_name("ABCDEFGHIJKLMNOP"), "ABCDEFGHIJKL", "max length")


func test_to_dict_and_ids_keep_join_order() -> void:
	var roster := Roster.new()
	roster.add(5, "E")
	roster.add(3, "C")
	roster.add(9, "I")
	check_eq(roster.ids(), [5, 3, 9] as Array[int], "ids")
	check_eq(roster.ids_in_team(Roster.Team.LEFT), [5, 9] as Array[int], "left ids")
	var state := roster.to_dict()
	check_eq(state.host_id, 5, "host in dict")
	check_eq(state.players[1], {"id": 3, "name": "C", "team": Roster.Team.RIGHT, "character": "captain"}, "member dict")



func test_joining_assigns_the_first_free_outfield_character_per_team() -> void:
	var roster := Roster.new()
	roster.add(1, "A")  # left
	roster.add(2, "B")  # right
	roster.add(3, "C")  # left
	check_eq(roster.character_of(1), "captain", "first pick")
	check_eq(roster.character_of(2), "captain", "other team may share")
	check_eq(roster.character_of(3), "blitz", "next free in the same team")


func test_set_character_rules() -> void:
	var roster := Roster.new()
	roster.add(1, "A")  # left
	roster.add(2, "B")  # right
	roster.add(3, "C")  # left
	check_eq(roster.set_character(1, "nobody"), "Unknown character", "unknown")
	check_eq(roster.set_character(1, "blitz"), "Taken by a teammate", "teammate has it")
	check_eq(roster.set_character(2, "blitz"), "", "other team is fine")
	check_eq(roster.set_character(1, "cat"), "", "keeper")
	check_eq(roster.set_character(3, "the_wall"), "Your team already has a goalkeeper", "one keeper per team")
	check_eq(roster.set_character(1, "cat"), "", "re-picking your own is fine")
	check_eq(roster.character_of(1), "cat", "stored")


func test_switching_team_reassigns_a_taken_character() -> void:
	var roster := Roster.new()
	roster.add(1, "A")  # left, captain
	roster.add(2, "B")  # right, captain
	check_eq(roster.set_team(2, Roster.Team.LEFT), "", "switch")
	check(roster.character_of(2) != roster.character_of(1), "no duplicate after the switch")


func test_switching_team_drops_a_second_keeper() -> void:
	var roster := Roster.new()
	roster.add(1, "A")  # left
	roster.add(2, "B")  # right
	roster.set_character(1, "cat")
	roster.set_character(2, "the_wall")
	roster.set_team(2, Roster.Team.LEFT)
	check(not Characters.by_id(roster.character_of(2)).keeper, "became an outfield player")


func test_teams_of_two_or_more_need_exactly_one_keeper() -> void:
	var roster := Roster.new()
	for id in [1, 2, 3]:
		roster.add(id, "P%d" % id)  # 1,3 left; 2 right
	check_eq(roster.can_start(1), "BLUE needs a goalkeeper", "left has two outfielders")
	roster.set_character(3, "the_wall")
	check_eq(roster.can_start(1), "", "right has one player, no keeper needed")
