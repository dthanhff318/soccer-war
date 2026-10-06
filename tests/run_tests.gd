extends SceneTree

## Headless test runner:
##   godot --headless -s tests/run_tests.gd            # every suite
##   godot --headless -s tests/run_tests.gd -- roster  # suites whose file name contains "roster"
## Runs each tests/test_*.gd suite and exits with code 1 if any check failed.

const TEST_DIR := "res://tests/"


## Counts engine and script errors so a test that crashes mid-way (which
## GDScript otherwise survives silently) is reported as failed.
class ErrorCounter extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		errors.append("%s (%s:%d) %s" % [rationale if not rationale.is_empty() else code, file, line, ""])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

var _errors := ErrorCounter.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	OS.add_logger(_errors)
	var args := OS.get_cmdline_user_args()
	var filter: String = args[0] if not args.is_empty() else ""
	var files: Array[String] = []
	for file in DirAccess.get_files_at(TEST_DIR):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd" \
				and (filter.is_empty() or file.contains(filter)):
			files.append(file)
	files.sort()

	var count := 0
	for file in files:
		var script: GDScript = load(TEST_DIR + file)
		if script == null or not script.can_instantiate():
			TestCase.failures.append("%s: suite failed to load (parse error?)" % file)
			continue
		var suite: TestCase = script.new()
		root.add_child(suite)
		for method in suite.get_script().get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			suite.current_test = "%s.%s" % [file.get_basename(), test_name]
			var failures_before := TestCase.failures.size()
			var errors_before := _errors.errors.size()
			await suite.call(test_name)
			for error in _errors.errors.slice(errors_before):
				TestCase.failures.append("%s: error: %s" % [suite.current_test, error])
			count += 1
			var passed := TestCase.failures.size() == failures_before
			print("%s %s" % ["PASS" if passed else "FAIL", suite.current_test])
		suite.queue_free()
		await process_frame

	for failure in TestCase.failures:
		printerr("  x ", failure)
	print("%d tests, %d failures" % [count, TestCase.failures.size()])
	quit(1 if TestCase.failures.size() > 0 else 0)
