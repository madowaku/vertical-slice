extends PhaseATestBase


func run() -> Dictionary:
	var resource := load("res://scenes/debug/local_debug_slice.tscn")
	expect_true(resource is PackedScene, "local debug scene loads as PackedScene")
	if resource is PackedScene:
		var instance := (resource as PackedScene).instantiate()
		expect_true(instance is Control, "local debug scene root is Control")
		expect_true(instance.get_script() != null, "local debug scene has controller script")
		instance.free()
	return make_result("Debug scene")
