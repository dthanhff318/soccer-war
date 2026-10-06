extends TestCase


func test_input_vector_directions() -> void:
	check_eq(Protocol.input_vector(0), Vector2.ZERO, "no keys")
	check_eq(Protocol.input_vector(Protocol.IN_LEFT), Vector2.LEFT, "left")
	check_eq(Protocol.input_vector(Protocol.IN_RIGHT), Vector2.RIGHT, "right")
	check_eq(Protocol.input_vector(Protocol.IN_UP), Vector2.UP, "up")
	check_eq(Protocol.input_vector(Protocol.IN_DOWN), Vector2.DOWN, "down")


func test_input_vector_diagonal_is_unit_length() -> void:
	var diagonal := Protocol.input_vector(Protocol.IN_RIGHT | Protocol.IN_DOWN)
	check_near(diagonal.length(), 1.0, 0.0001, "diagonal length")
	check(diagonal.x > 0.0 and diagonal.y > 0.0, "diagonal points down-right")


func test_input_vector_opposites_cancel() -> void:
	check_eq(Protocol.input_vector(Protocol.IN_LEFT | Protocol.IN_RIGHT), Vector2.ZERO, "left+right")


func test_input_vector_ignores_sprint_and_kick() -> void:
	check_eq(Protocol.input_vector(Protocol.IN_SPRINT | Protocol.IN_KICK | Protocol.IN_UP), Vector2.UP, "up with extras")


func test_make_code_uses_alphabet_and_length() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var code := Protocol.make_code(rng, {})
		check_eq(code.length(), Protocol.CODE_LENGTH, "code length")
		for c in code:
			check(Protocol.CODE_ALPHABET.contains(c), "char %s in alphabet" % c)


func test_make_code_skips_taken_codes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var first := Protocol.make_code(rng, {})
	rng.seed = 42
	var second := Protocol.make_code(rng, {first: true})
	check(second != first, "taken code is not reused")


func test_snapshot_round_trip() -> void:
	var snap := {
		"tick": 1234,
		"phase": Protocol.Phase.CELEBRATING,
		"score_left": 3,
		"score_right": 2,
		"time_left": 187.5,
		"ball_pos": Vector2(640.5, 360.25),
		"ball_vel": Vector2(-120.0, 33.5),
		"players": {
			17: {"pos": Vector2(100.5, 200.0), "vel": Vector2(150.0, 0.0), "stamina": 42.5,
				"regen": 0.25, "exhausted": false, "last_seq": 999},
			123456789: {"pos": Vector2(800.0, 300.0), "vel": Vector2.ZERO, "stamina": 0.0,
				"regen": 0.0, "exhausted": true, "last_seq": 5},
		},
	}
	var decoded: Dictionary = Protocol.decode_snapshot(Protocol.encode_snapshot(snap))
	check_eq(decoded, snap, "decoded snapshot")


func test_decode_empty_snapshot_is_empty() -> void:
	check_eq(Protocol.decode_snapshot(PackedByteArray()), {}, "empty bytes")


func test_pass_bit_is_in_mask_and_does_not_move() -> void:
	check((Protocol.INPUT_MASK & Protocol.IN_PASS) == Protocol.IN_PASS, "mask keeps pass")
	check_eq(Protocol.input_vector(Protocol.IN_PASS | Protocol.IN_LEFT), Vector2.LEFT, "pass + left")
