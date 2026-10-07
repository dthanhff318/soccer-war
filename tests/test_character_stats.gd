extends TestCase

## Stats turn into real player numbers: 50 is today's default player, 99 and
## 1 are the ends of each range.

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	return player


func _average(keeper: bool) -> Dictionary:
	var stats := {}
	for key in Characters.STAT_KEYS:
		stats[key] = 50
	var character := {"id": "avg", "name": "AVG", "keeper": keeper, "stats": stats}
	if keeper:
		character.keeper_stats = {"reflexes": 50, "handling": 50, "diving": 50}
	return character


func test_scale_hits_low_mid_and_high() -> void:
	check_near(CharacterStats.scale(50, 130.0, 150.0, 175.0), 150.0, 0.001, "50 = default")
	check_near(CharacterStats.scale(99, 130.0, 150.0, 175.0), 175.0, 0.001, "99 = top")
	check_near(CharacterStats.scale(1, 130.0, 150.0, 175.0), 130.0, 0.001, "1 = bottom")
	check_near(CharacterStats.scale(99, 1.2, 1.0, 0.8), 0.8, 0.001, "works for falling ranges")


func test_average_character_plays_exactly_like_the_default_player() -> void:
	var plain := _player()
	var average := _player()
	CharacterStats.apply(average, _average(false))
	for property in ["move_speed", "sprint_speed", "acceleration", "max_stamina", "stamina_regen",
			"max_kick_speed", "kick_charge_time", "pass_strength", "dribble_push"]:
		check_near(average.get(property), plain.get(property), 0.001, property)
	check_near(average.reach(), plain.reach(), 0.001, "reach")
	plain.queue_free()
	average.queue_free()


func test_strengths_show_up_in_play() -> void:
	var blitz := _player()
	CharacterStats.apply(blitz, Characters.by_id("blitz"))
	check(blitz.move_speed > 170.0, "BLITZ runs fast (%.0f)" % blitz.move_speed)
	var cannon := _player()
	CharacterStats.apply(cannon, Characters.by_id("cannon"))
	check(cannon.max_kick_speed > 720.0, "CANNON shoots hard (%.0f)" % cannon.max_kick_speed)
	check(cannon.kick_charge_time < 0.85, "CANNON charges fast (%.2f)" % cannon.kick_charge_time)
	var maestro := _player()
	CharacterStats.apply(maestro, Characters.by_id("maestro"))
	check(maestro.pass_strength > 320.0, "MAESTRO passes far (%.0f)" % maestro.pass_strength)
	var dynamo := _player()
	CharacterStats.apply(dynamo, Characters.by_id("dynamo"))
	check(dynamo.max_stamina > 140.0 and dynamo.stamina == dynamo.max_stamina, "DYNAMO has a big, full tank")
	for p in [blitz, cannon, maestro, dynamo]:
		p.queue_free()


func test_dribbling_widens_reach_without_touching_other_players() -> void:
	var silk := _player()
	var other := _player()
	CharacterStats.apply(silk, Characters.by_id("silk"))
	check(silk.reach() > 42.0, "SILK reaches further (%.1f)" % silk.reach())
	check_near(other.reach(), 38.4, 0.001, "shared shape left alone")
	silk.queue_free()
	other.queue_free()


func test_keeper_stats_change_saves() -> void:
	var wall := _player()
	CharacterStats.apply(wall, Characters.by_id("the_wall"))
	var cat := _player()
	CharacterStats.apply(cat, Characters.by_id("cat"))
	check(wall.is_goalkeeper and cat.is_goalkeeper, "keepers")
	check(cat.catch_speed > wall.catch_speed, "CAT reacts to faster shots")
	check(Ball.keeper_rebound_speed(650.0, wall) < Ball.keeper_rebound_speed(650.0, cat), "THE WALL spills less")
	var average := _player()
	CharacterStats.apply(average, _average(true))
	check_near(Ball.keeper_rebound_speed(650.0, average), 292.5, 0.01, "average keeper = default rule")
	check_near(average.catch_speed, 300.0, 0.001, "average catch speed")
	for p in [wall, cat, average]:
		p.queue_free()
