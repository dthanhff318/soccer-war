class_name TestCase
extends Node

## Base for suites run by tests/run_tests.gd. Every method named test_* runs
## in declaration order; a failed check records a message and the test
## carries on, so one run reports every broken expectation.

static var failures: Array[String] = []

## "suite.test_name" of the running test, prefixed to failure messages.
var current_test: String = ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


## Strict equality: values must also share a type (1 and 1.0 differ).
func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: %s expected %s, got %s" % [current_test, message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: %s expected %s ± %s, got %s" % [current_test, message, expected, tolerance, actual])


## Waits up to `max_frames` process frames for `condition` to return true.
func wait_until(condition: Callable, max_frames: int = 300) -> bool:
	for i in max_frames:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()
