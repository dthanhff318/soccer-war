class_name CharacterStats
extends RefCounted

## Turns a character's 1–99 stats into the numbers a Player actually uses.
## 50 is today's default player; 1 and 99 are the ends of each range.


## `stat` mapped onto lo..mid..hi, with 50 landing exactly on `mid`.
## Ranges may fall as well as rise (e.g. a shorter charge time is better).
static func scale(stat: float, lo: float, mid: float, hi: float) -> float:
	if stat >= 50.0:
		return mid + (hi - mid) * (stat - 50.0) / 49.0
	return mid - (mid - lo) * (50.0 - stat) / 49.0


static func apply(player: Player, character: Dictionary) -> void:
	var stats: Dictionary = character.stats
	player.move_speed = scale(stats.pace, 130.0, 150.0, 175.0)
	player.sprint_speed = scale(stats.pace, 190.0, 220.0, 260.0)
	player.acceleration = scale(stats.pace, 2000.0, 2400.0, 2900.0)
	player.max_stamina = scale(stats.stamina, 70.0, 100.0, 150.0)
	player.stamina_regen = scale(stats.stamina, 1.5, 2.0, 3.0)
	player.stamina = player.max_stamina
	player.max_kick_speed = scale(stats.shooting, 560.0, 650.0, 740.0)
	player.kick_charge_time = scale(stats.shooting, 1.2, 1.0, 0.8)
	player.pass_strength = scale(stats.passing, 200.0, 250.0, 340.0)
	player.dribble_push = scale(stats.dribbling, 1.0, 1.2, 1.5)
	player.set_reach(scale(stats.dribbling, 34.0, 38.4, 44.0))

	player.is_goalkeeper = character.keeper
	if character.keeper:
		var keeper: Dictionary = character.keeper_stats
		player.catch_speed = scale(keeper.reflexes, 250.0, 300.0, 380.0)
		# Better handling: hard shots spill back less.
		player.rebound_min_ratio = scale(keeper.handling, 0.25, 0.2, 0.1)
		player.rebound_max_ratio = scale(keeper.handling, 0.55, 0.45, 0.25)
		var dive := scale(keeper.diving, 0.9, 1.0, 1.2)
		player.move_speed *= dive
		player.sprint_speed *= dive
		player.acceleration *= dive
	player.character_id = character.id
	player.stamina_changed.emit(player.stamina, player.max_stamina, player.is_exhausted)
