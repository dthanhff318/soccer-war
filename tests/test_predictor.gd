extends TestCase

## Runs a real Player in an empty physics world (no walls) so replay can be
## compared against the original prediction.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const DELTA := 1.0 / 60.0

var _world: SubViewport
var _player: Player


func _setup() -> void:
	_world = SubViewport.new()
	_world.world_2d = World2D.new()
	add_child(_world)
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(400, 360)
	_world.add_child(_player)
	await get_tree().physics_frame


func _teardown() -> void:
	_world.queue_free()


func test_replay_from_acked_state_reproduces_prediction() -> void:
	await _setup()
	var predictor := Predictor.new(_player)
	var acked_state := {}
	for i in 20:
		var seq := predictor.apply(Protocol.IN_RIGHT | Protocol.IN_SPRINT, DELTA)
		if seq == 8:
			acked_state = _player.get_state()
			acked_state.last_seq = seq
	var predicted := _player.position
	predictor.reconcile(acked_state, DELTA)
	check(_player.position.distance_to(predicted) < 0.01, "same position after replay")
	check(_player.visual_offset.length() < 0.01, "no visible correction")
	_teardown()


func test_small_correction_is_smoothed() -> void:
	await _setup()
	var predictor := Predictor.new(_player)
	for i in 10:
		predictor.apply(Protocol.IN_DOWN, DELTA)
	var predicted := _player.position
	var server_state := _player.get_state()
	server_state.pos += Vector2(10, 0)
	server_state.last_seq = 10
	predictor.reconcile(server_state, DELTA)
	check(_player.position.distance_to(predicted + Vector2(10, 0)) < 0.01, "body moved to server position")
	check(_player.visual_offset.distance_to(Vector2(-10, 0)) < 0.01, "sprite stays where it was")
	_teardown()


func test_large_correction_snaps() -> void:
	await _setup()
	var predictor := Predictor.new(_player)
	predictor.apply(0, DELTA)
	var server_state := _player.get_state()
	server_state.pos = Vector2(640, 200)
	server_state.last_seq = 1
	predictor.reconcile(server_state, DELTA)
	check_eq(_player.position, Vector2(640, 200), "kickoff teleport")
	check_eq(_player.visual_offset, Vector2.ZERO, "no smoothing across the pitch")
	_teardown()


func test_server_stamina_is_adopted() -> void:
	await _setup()
	var predictor := Predictor.new(_player)
	predictor.apply(0, DELTA)
	var server_state := _player.get_state()
	server_state.stamina = 12.0
	server_state.exhausted = true
	server_state.last_seq = 1
	predictor.reconcile(server_state, DELTA)
	check_near(_player.stamina, 12.0, 0.5, "stamina")
	check(_player.is_exhausted, "exhausted")
	_teardown()
