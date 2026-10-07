extends TestCase

const R := Protocol.IN_RIGHT
const L := Protocol.IN_LEFT
const KICK := Protocol.IN_KICK
const PASS := Protocol.IN_PASS


func test_empty_queue_before_any_input_stands_still() -> void:
	var queue := InputQueue.new()
	check_eq(queue.take(), 0, "idle")
	check_eq(queue.last_seq, 0, "nothing acked")


func test_consumes_one_input_per_tick_in_order() -> void:
	var queue := InputQueue.new()
	queue.push(1, R)
	check_eq(queue.take(), R, "first")
	check_eq(queue.last_seq, 1, "acked 1")
	queue.push(2, L)
	check_eq(queue.take(), L, "second")
	check_eq(queue.last_seq, 2, "acked 2")


func test_ignores_duplicate_and_stale_inputs() -> void:
	var queue := InputQueue.new()
	queue.push(5, R)
	queue.push(5, L)
	queue.push(3, L)
	check_eq(queue.take(), R, "only seq 5")
	queue.push(4, L)
	check_eq(queue.take(), R, "seq 4 is older than acked 5, repeat last")


func test_flooding_never_gives_more_than_one_step_per_tick() -> void:
	# A client sending at 120 Hz must not move faster: one input per tick is
	# simulated and the surplus is acknowledged without being simulated.
	var queue := InputQueue.new()
	var seq := 0
	for tick in 60:
		for i in 2:
			seq += 1
			queue.push(seq, R)
		queue.take()
	check(queue.last_seq >= seq - InputQueue.MAX_BACKLOG, "backlog stays short (acked %d of %d)" % [queue.last_seq, seq])


func test_standing_backlog_is_trimmed_to_keep_latency_low() -> void:
	var queue := InputQueue.new()
	for seq in range(1, 6):
		queue.push(seq, R)
	queue.take()
	check_eq(queue.last_seq, 5 - InputQueue.MAX_BACKLOG + 1, "older surplus skipped, newest kept queued")


func test_inputs_covered_by_repeats_are_skipped_when_they_arrive() -> void:
	# The server repeated movement for 2 starved ticks; when the 2 late inputs
	# arrive they are acknowledged but not simulated again (no double step).
	var queue := InputQueue.new()
	queue.push(1, R)
	queue.take()
	queue.take()
	queue.take()
	queue.push(2, R)
	queue.push(3, R)
	queue.push(4, L)
	check_eq(queue.take(), L, "jumps to the newest input")
	check_eq(queue.last_seq, 4, "late inputs acknowledged")


func test_skipped_input_keeps_its_pass() -> void:
	var queue := InputQueue.new()
	queue.push(1, R)
	queue.take()
	queue.take()
	queue.push(2, R | PASS)
	queue.push(3, R)
	check_eq(queue.take(), R | PASS, "pass carried into the simulated input")


func test_repeat_stops_after_a_few_ticks() -> void:
	var queue := InputQueue.new()
	queue.push(1, R | Protocol.IN_SPRINT | PASS)
	queue.take()
	check_eq(queue.take(), R | Protocol.IN_SPRINT, "repeat without pass")
	for i in InputQueue.MAX_REPEAT:
		queue.take()
	check_eq(queue.take(), 0, "silent client stops moving")
	check_eq(queue.last_seq, 1, "repeats do not ack")


func test_held_kick_survives_starvation_so_a_stall_is_not_a_release() -> void:
	var queue := InputQueue.new()
	queue.push(1, R | KICK)
	queue.take()
	check_eq(queue.take(), R | KICK, "still holding while repeating")
	for i in InputQueue.MAX_REPEAT + 5:
		queue.take()
	check_eq(queue.take(), KICK, "stops moving but keeps holding")
