extends PhaseATestBase


func run() -> Dictionary:
	var resource := load("res://scenes/debug/local_debug_slice.tscn")
	expect_true(resource is PackedScene, "C6 scene loads")
	if not resource is PackedScene:
		return make_result("C6 playfeel")

	var instance := (resource as PackedScene).instantiate()
	expect_true(instance is Control, "C6 root is Control")
	instance.call("ensure_ui_for_test")

	var contract: Dictionary = instance.call("get_c6_contract_snapshot")
	expect_eq(float(contract["walk_beat_seconds"]), 1.4, "C6 keeps the 1.4 second walk beat")
	expect_true(bool(contract["stop_has_immediate_feedback"]), "STOP has immediate feedback")
	expect_true(bool(contract["sensor_change_is_emphasized"]), "live sensor changes are emphasized")
	expect_true(bool(contract["reveal_shows_coordinate_free_path"]), "reveal shows the walked path")
	expect_true(bool(contract["reveal_calls_out_adjacent_miss"]), "reveal calls out one-step misses")
	expect_eq(int(contract["guide_gameplay_buttons"]), 0, "C6 adds no Guide gameplay buttons")
	expect_eq(int(contract["watermelon_sabotage_buttons"]), 0, "C6 adds no Watermelon sabotage buttons")

	# Board 01 has a clean three-step route from (3,3) facing north to (4,5):
	# RIGHT, STOP, RIGHT, STOP, FORWARD, STOP, SWING.
	instance.call("_start_round", 1)
	instance.call("_set_view_role", GameTypes.PlayerRole.BLIND)
	instance.call("_on_direction_pressed", GameTypes.BlindAction.RIGHT)
	instance.call("_on_walk_beat")
	instance.call("_on_stop_pressed")
	var first_stop: Dictionary = instance.call("get_current_c6_snapshot")
	expect_eq(str(first_stop["transition_notice"]), "ストップ！", "STOP feedback survives into consult")

	instance.call("_on_direction_pressed", GameTypes.BlindAction.RIGHT)
	instance.call("_on_walk_beat")
	instance.call("_set_view_role", GameTypes.PlayerRole.GUIDE_SIDE)
	var changed_side: Dictionary = instance.call("get_current_c6_snapshot")
	expect_eq(str(changed_side["mode"]), "guide_walking", "Guide remains in live monitor mode during a walk")
	expect_true(bool(changed_side["sensor_changed"]), "Side Radar highlights RIGHT to CENTER change")

	instance.call("_set_view_role", GameTypes.PlayerRole.BLIND)
	instance.call("_on_stop_pressed")
	instance.call("_on_direction_pressed", GameTypes.BlindAction.FORWARD)
	instance.call("_on_walk_beat")
	instance.call("_on_stop_pressed")
	expect_eq(instance.session.round_controller.steps_taken, 3, "clean route uses three walk beats")
	expect_eq(instance.session.round_controller.steps_remaining, 5, "clean route preserves five exploratory steps")

	instance.call("_on_request_swing")
	expect_eq(instance.session.round_controller.state, GameTypes.RoundState.DECISION, "swing request creates a final discussion beat")
	instance.call("_on_confirm_swing")
	expect_eq(instance.session.round_controller.state, GameTypes.RoundState.RESULT, "confirmed swing reaches result")
	expect_true(instance.session.round_controller.last_swing_success, "scripted C6 route smashes the watermelon")

	instance.call("_on_reveal_pressed")
	expect_eq(instance.session.round_controller.state, GameTypes.RoundState.REVEAL, "result enters reveal")
	var reveal_snapshot: Dictionary = instance.call("get_current_c6_snapshot")
	var reveal_path := str(reveal_snapshot["reveal_path_text"])
	expect_true(reveal_path.contains("始"), "reveal path marks the start")
	expect_true(reveal_path.contains("[1]") and reveal_path.contains("[2]"), "reveal path preserves walked order")
	expect_true(reveal_path.contains("割"), "successful swing is visibly marked on reveal map")
	expect_false(reveal_path.contains("A  B  C") or reveal_path.contains("1  2  3  4  5  6"), "reveal map does not introduce coordinate labels")

	instance.free()

	# A second deterministic run stops one cell early so the reveal can reward
	# an 'almost!' failure instead of showing only a generic miss.
	var near_miss := (resource as PackedScene).instantiate()
	near_miss.call("ensure_ui_for_test")
	near_miss.call("_start_round", 1)
	near_miss.call("_set_view_role", GameTypes.PlayerRole.BLIND)
	near_miss.call("_on_direction_pressed", GameTypes.BlindAction.RIGHT)
	near_miss.call("_on_walk_beat")
	near_miss.call("_on_stop_pressed")
	near_miss.call("_on_direction_pressed", GameTypes.BlindAction.RIGHT)
	near_miss.call("_on_walk_beat")
	near_miss.call("_on_stop_pressed")
	near_miss.call("_on_request_swing")
	near_miss.call("_on_confirm_swing")
	expect_false(near_miss.session.round_controller.last_swing_success, "one-cell-early swing misses")
	near_miss.call("_on_reveal_pressed")
	var near_reveal: Dictionary = near_miss.session.get_reveal_projection()
	var near_comment := str(near_miss.call("_reveal_result_comment", near_reveal))
	expect_true(near_comment.contains("となり"), "adjacent miss reveal says the watermelon was next door")
	near_miss.free()

	return make_result("C6 playfeel")
