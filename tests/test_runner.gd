extends Node


const SUITES := [
	preload("res://tests/test_board_validation.gd"),
	preload("res://tests/test_sensor_logic.gd"),
	preload("res://tests/test_movement.gd"),
	preload("res://tests/test_round_state.gd"),
	preload("res://tests/test_turn_record.gd"),
	preload("res://tests/test_local_debug_session.gd"),
	preload("res://tests/test_projection_safety.gd"),
	preload("res://tests/test_debug_scene.gd"),
]


func _ready() -> void:
	var total_passed := 0
	var all_failures: Array[String] = []
	var summaries: Array[String] = []

	for suite_script in SUITES:
		var suite = suite_script.new()
		var result: Dictionary = suite.run()
		var suite_failures: Array = result["failures"]
		var suite_passed: int = int(result["passed"])
		total_passed += suite_passed
		summaries.append("%s: %d / %d failures" % [result["name"], suite_passed, suite_failures.size()])
		for failure in suite_failures:
			all_failures.append("[%s] %s" % [result["name"], failure])

	for summary in summaries:
		print(summary)

	if all_failures.is_empty():
		print("Tests: %d passed" % total_passed)
		print("Failures: 0")
		get_tree().quit(0)
		return

	for failure in all_failures:
		push_error(failure)
	print("Tests: %d passed" % total_passed)
	print("Failures: %d" % all_failures.size())
	get_tree().quit(1)
