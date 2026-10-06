extends TestCase

const R := Protocol.IN_RIGHT
const L := Protocol.IN_LEFT


func test_empty_queue_before_any_input_stands_still() -> void:
	var queue := InputQueue.new()
	check_eq(queue.take(), [0] as Array[int], "idle")
	check_eq(queue.last_seq, 0, "nothing acked")


func test_consumes_one_input_per_tick_in_order() -> void:
	var queue := InputQueue.new()
	queue.push(1, R)
	queue.push(2, L)
	check_eq(queue.take(), [R] as Array[int], "first")
	check_eq(queue.last_seq, 1, "acked 1")
	check_eq(queue.take(), [L] as Array[int], "second")
	check_eq(queue.last_seq, 2, "acked 2")


func test_ignores_duplicate_and_stale_inputs() -> void:
	var queue := InputQueue.new()
	queue.push(5, R)
	queue.push(5, L)
	queue.push(3, L)
	check_eq(queue.take(), [R] as Array[int], "only seq 5")
	queue.push(4, L)
	check_eq(queue.take(), [R] as Array[int], "seq 4 is older than acked 5, repeat last")


func test_backlog_drains_two_per_tick() -> void:
	var queue := InputQueue.new()
	for seq in range(1, 6):
		queue.push(seq, R)
	check_eq(queue.take().size(), 2, "5 queued -> catch up")
	check_eq(queue.take().size(), 1, "3 queued -> normal")
	check_eq(queue.last_seq, 3, "acked")


func test_empty_queue_repeats_movement_without_kick() -> void:
	var queue := InputQueue.new()
	queue.push(1, R | Protocol.IN_SPRINT | Protocol.IN_KICK)
	queue.take()
	check_eq(queue.take(), [R | Protocol.IN_SPRINT] as Array[int], "repeat, no kick")
	check_eq(queue.last_seq, 1, "repeat does not ack")


func test_queue_is_bounded() -> void:
	var queue := InputQueue.new()
	for seq in range(1, 100):
		queue.push(seq, R)
	var drained := 0
	while queue.last_seq < 99:
		drained += queue.take().size()
	check(drained <= InputQueue.MAX_QUEUED, "at most MAX_QUEUED kept (%d)" % drained)
