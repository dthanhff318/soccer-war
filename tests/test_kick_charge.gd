extends TestCase

## Charged kick: hold Space to charge (full after 1 s), release to shoot at
## 300–650 px/s. Holding 0.5 s past full cancels the kick until Space is
## pressed again.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const BALL_SCENE := preload("res://scenes/ball.tscn")
const DELTA := 1.0 / 60.0
const HOLD := Protocol.IN_KICK

var _world: SubViewport


func _setup() -> void:
	_world = SubViewport.new()
	_world.world_2d = World2D.new()
	add_child(_world)


func _teardown() -> void:
	_world.queue_free()


func _player(pos: Vector2) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = pos
	_world.add_child(player)
	return player


func _ball(pos: Vector2) -> Ball:
	var ball: Ball = BALL_SCENE.instantiate()
	ball.simulated = false
	ball.position = pos
	_world.add_child(ball)
	return ball


func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame


## Holds the kick key for `ticks` ticks, then releases it once.
func _hold_and_release(player: Player, ticks: int) -> void:
	for i in ticks:
		player.simulate(HOLD, DELTA)
	player.simulate(0, DELTA)


func test_power_grows_with_hold_time_and_caps() -> void:
	_setup()
	var player := _player(Vector2(300, 300))
	await _settle()
	check_eq(player.kick_power(), player.min_kick_speed, "nothing held")
	for i in 30:
		player.simulate(HOLD, DELTA)
	check_near(player.kick_power(), 475.0, 1.0, "half of 1 s")
	for i in 30:
		player.simulate(HOLD, DELTA)
	check_near(player.kick_power(), 650.0, 0.01, "full after 1 s")
	_teardown()


func test_holding_does_not_kick_release_does() -> void:
	_setup()
	var player := _player(Vector2(300, 300))
	var ball := _ball(Vector2(325, 300))
	await _settle()
	for i in 30:
		player.simulate(HOLD, DELTA)
	check_eq(ball.velocity, Vector2.ZERO, "no kick while charging")
	player.simulate(0, DELTA)
	check(ball.velocity.length() > 0.0, "kicked on release")
	check_eq(player.kick_charge, 0.0, "charge reset after the kick")
	_teardown()


func test_tap_kicks_at_minimum_speed() -> void:
	_setup()
	var player := _player(Vector2(300, 300))
	var ball := _ball(Vector2(325, 300))
	await _settle()
	_hold_and_release(player, 1)
	# One tick of charge: 300 + 350 / 60 ≈ 306.
	check_near(ball.velocity.length(), 300.0 + 350.0 / 60.0, 0.5, "tap")
	_teardown()


func test_full_charge_kicks_at_exactly_max_along_centre_line_even_if_rolling() -> void:
	_setup()
	var player := _player(Vector2(300, 300))
	var ball := _ball(Vector2(318, 282))
	await _settle()
	for i in 80:  # full, and still inside the 0.5 s grace
		player.simulate(HOLD, DELTA)
	ball.velocity = Vector2(200, 0)  # rolling sideways must not bend or speed up the shot
	var line := (ball.position - player.position).normalized()
	player.simulate(0, DELTA)
	check_near(ball.velocity.length(), 650.0, 0.5, "final speed is the charged power")
	check_near(rad_to_deg(line.angle_to(ball.velocity.normalized())), 0.0, 0.1, "centre-to-centre")
	_teardown()


func test_release_out_of_reach_does_nothing_and_resets() -> void:
	_setup()
	var player := _player(Vector2(300, 300))
	var ball := _ball(Vector2(500, 300))
	await _settle()
	_hold_and_release(player, 60)
	check_eq(ball.velocity, Vector2.ZERO, "ball untouched")
	check_eq(player.kick_charge, 0.0, "charge reset")
	_teardown()


func test_pass_speed_is_250() -> void:
	_setup()
	var player := _player(Vector2(300, 300))
	var ball := _ball(Vector2(325, 300))
	await _settle()
	player.simulate(Protocol.IN_PASS, DELTA)
	check_near(ball.velocity.length(), 250.0, 0.5, "pass speed")
	_teardown()


func test_replayed_inputs_never_charge_or_kick() -> void:
	# Reconciliation replays unacknowledged inputs; a replayed release must not
	# kick and must not disturb the live charge shown in the power bar.
	_setup()
	var player := _player(Vector2(300, 300))
	var ball := _ball(Vector2(325, 300))
	await _settle()
	var predictor := Predictor.new(player)
	var acked := player.get_state()
	acked.last_seq = predictor.apply(HOLD, DELTA)
	for i in 20:
		predictor.apply(HOLD, DELTA)
	var charge_before := player.kick_charge
	predictor.reconcile(acked, DELTA)
	check_eq(ball.velocity, Vector2.ZERO, "no kick from replay")
	check_eq(player.kick_charge, charge_before, "live charge untouched")
	_teardown()


func test_keyboard_kick_bit_means_space_is_held() -> void:
	Input.action_press("kick")
	check((Protocol.keyboard_bits(false) & Protocol.IN_KICK) != 0, "held")
	Input.action_release("kick")
	check_eq(Protocol.keyboard_bits(false) & Protocol.IN_KICK, 0, "released")


func test_holding_half_a_second_past_full_cancels_the_kick() -> void:
	_setup()
	var player := _player(Vector2(300, 300))
	var ball := _ball(Vector2(325, 300))
	await _settle()
	for i in 89:
		player.simulate(HOLD, DELTA)
	check(player.is_charging(), "still charging just before the limit")
	for i in 5:
		player.simulate(HOLD, DELTA)
	check(not player.is_charging(), "cancelled: power bar gone")
	check_eq(player.kick_charge, 0.0, "charge cleared")
	for i in 30:
		player.simulate(HOLD, DELTA)
	check(not player.is_charging(), "keeping Space down does not restart it")
	player.simulate(0, DELTA)
	check_eq(ball.velocity, Vector2.ZERO, "release after a cancel does not kick")
	_teardown()


func test_pressing_again_after_a_cancel_kicks_normally() -> void:
	_setup()
	var player := _player(Vector2(300, 300))
	var ball := _ball(Vector2(325, 300))
	await _settle()
	_hold_and_release(player, 100)
	check_eq(ball.velocity, Vector2.ZERO, "cancelled")
	_hold_and_release(player, 1)
	check_near(ball.velocity.length(), 300.0, 10.0, "fresh tap kicks")
	_teardown()
