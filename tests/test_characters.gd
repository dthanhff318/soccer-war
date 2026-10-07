extends TestCase

## The character roster: 10 unique characters, 2 of them keepers, with equal
## stat budgets so no one is simply stronger.


func test_ten_characters_with_unique_ids_and_names() -> void:
	check_eq(Characters.ALL.size(), 10, "count")
	var ids := {}
	var names := {}
	for c in Characters.ALL:
		ids[c.id] = true
		names[c.name] = true
	check_eq(ids.size(), 10, "unique ids")
	check_eq(names.size(), 10, "unique names")


func test_two_goalkeepers() -> void:
	check_eq(Characters.ALL.filter(func(c): return c.keeper).size(), 2, "keepers")


func test_outfield_players_share_the_same_stat_budget() -> void:
	for c in Characters.ALL:
		var total := 0
		for key in Characters.STAT_KEYS:
			var value: int = c.stats[key]
			check(value >= 1 and value <= 99, "%s %s in 1..99" % [c.name, key])
			total += value
		var budget := Characters.KEEPER_OUTFIELD_BUDGET if c.keeper else Characters.OUTFIELD_BUDGET
		check_eq(total, budget, "%s outfield total" % c.name)


func test_keepers_share_the_same_keeper_budget() -> void:
	for c in Characters.ALL.filter(func(c): return c.keeper):
		var total := 0
		for key in Characters.KEEPER_KEYS:
			total += int(c.keeper_stats[key])
		check_eq(total, Characters.KEEPER_BUDGET, "%s keeper total" % c.name)


func test_every_character_has_a_short_description_and_role() -> void:
	for c in Characters.ALL:
		check(not c.role.is_empty(), "%s role" % c.name)
		check(c.description.length() > 20 and c.description.length() <= 110, "%s description length %d" % [c.name, c.description.length()])


func test_names_and_roles_render_in_the_pixel_font() -> void:
	var font: FontFile = UiKit.PIXEL_FONT
	for c in Characters.ALL:
		for text in [c.name, c.role.to_upper()]:
			for ch in text:
				check(ch == " " or font.has_char(ch.unicode_at(0)), "'%s' in %s" % [ch, text])


func test_lookup_by_id() -> void:
	check_eq(Characters.by_id("cannon").name, "CANNON", "found")
	check_eq(Characters.by_id("nobody"), {}, "missing")
