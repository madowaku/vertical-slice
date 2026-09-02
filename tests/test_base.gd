class_name PhaseATestBase
extends RefCounted


var passed: int = 0
var failures: Array[String] = []


func expect_true(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)


func expect_false(condition: bool, message: String) -> void:
	expect_true(not condition, message)


func expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failures.append("%s (expected=%s actual=%s)" % [message, str(expected), str(actual)])


func make_result(name: String) -> Dictionary:
	return {
		"name": name,
		"passed": passed,
		"failures": failures.duplicate(),
	}
