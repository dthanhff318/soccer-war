extends TestCase


func _snap(tick: int, ball_x: float, players: Dictionary = {}) -> Dictionary:
	var player_states := {}
	for id in players:
		player_states[id] = {"pos": players[id]}
	return {"tick": tick, "ball_pos": Vector2(ball_x, 360), "players": player_states}


func test_sample_interpolates_between_bracketing_snapshots() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snap(10, 100.0, {7: Vector2(0, 0)}))
	buffer.push(_snap(12, 120.0, {7: Vector2(20, 10)}))
	buffer.render_tick = 11.0
	var view := buffer.sample()
	check_near(view.ball_pos.x, 110.0, 0.001, "ball midpoint")
	check_eq(view.players[7], Vector2(10, 5), "player midpoint")


func test_sample_clamps_outside_the_buffer() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snap(10, 100.0))
	buffer.push(_snap(12, 120.0))
	buffer.render_tick = 5.0
	check_near(buffer.sample().ball_pos.x, 100.0, 0.001, "before first")
	buffer.render_tick = 50.0
	check_near(buffer.sample().ball_pos.x, 120.0, 0.001, "after last")


func test_teleports_are_not_interpolated() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snap(10, 1000.0, {7: Vector2(900, 360)}))
	buffer.push(_snap(12, 640.0, {7: Vector2(500, 360)}))
	buffer.render_tick = 11.0
	var view := buffer.sample()
	check_near(view.ball_pos.x, 640.0, 0.001, "ball jumps to kickoff")
	check_eq(view.players[7], Vector2(500, 360), "player jumps to kickoff")


func test_player_new_in_snapshot_uses_newest_position() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snap(10, 100.0))
	buffer.push(_snap(12, 100.0, {3: Vector2(50, 50)}))
	buffer.render_tick = 11.0
	check_eq(buffer.sample().players[3], Vector2(50, 50), "no older position")


func test_old_snapshots_are_ignored() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snap(12, 120.0))
	buffer.push(_snap(10, 999.0))
	check_eq(buffer.latest().tick, 12, "latest unchanged")


func test_render_clock_starts_interp_ticks_behind() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snap(100, 0.0))
	buffer.advance(1.0 / 60.0)
	check_near(buffer.render_tick, 100.0 - SnapshotBuffer.INTERP_TICKS, 0.001, "initial")


func test_render_clock_eases_toward_target() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snap(100, 0.0))
	buffer.advance(0.0)
	buffer.push(_snap(110, 0.0))
	var before := buffer.render_tick
	buffer.advance(1.0 / 60.0)
	var target := 110.0 - SnapshotBuffer.INTERP_TICKS
	check(buffer.render_tick > before + 1.0, "moved faster than real time to catch up")
	check(buffer.render_tick < target, "but eased, not jumped")


func test_render_clock_resyncs_after_large_drift() -> void:
	var buffer := SnapshotBuffer.new()
	buffer.push(_snap(100, 0.0))
	buffer.advance(0.0)
	buffer.push(_snap(500, 0.0))
	buffer.advance(1.0 / 60.0)
	check_near(buffer.render_tick, 500.0 - SnapshotBuffer.INTERP_TICKS, 0.001, "jumped")
