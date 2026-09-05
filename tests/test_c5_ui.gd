extends PhaseATestBase


func run() -> Dictionary:
	var resource := load("res://scenes/debug/local_debug_slice.tscn")
	expect_true(resource is PackedScene, "C5 scene loads")
	if not resource is PackedScene:
		return make_result("C5 UI")

	var instance := (resource as PackedScene).instantiate()
	expect_true(instance is Control, "C5 root is Control")
	instance.call("ensure_ui_for_test")

	var contract: Dictionary = instance.call("get_c5_contract_snapshot")
	expect_eq(str(contract["guide_consult_focus"]), "analysis", "Guide CONSULT focuses on analysis")
	expect_eq(str(contract["guide_walking_focus"]), "live_sensor", "Guide WALKING focuses on live sensor")
	expect_eq(str(contract["guide_decision_focus"]), "summary", "Guide DECISION focuses on summary")
	expect_eq(str(contract["watermelon_consult_focus"]), "map_reading", "Watermelon CONSULT focuses on reading secret map")
	expect_eq(str(contract["watermelon_walking_focus"]), "threat_tracking", "Watermelon WALKING focuses on threat tracking")
	expect_eq(str(contract["watermelon_decision_focus"]), "last_word", "Watermelon DECISION focuses on final persuasion")
	expect_eq(int(contract["guide_gameplay_buttons"]), 0, "Guide still has no gameplay buttons")
	expect_eq(int(contract["watermelon_sabotage_buttons"]), 0, "Watermelon has no sabotage buttons")
	expect_eq(float(contract["walk_beat_seconds"]), 1.4, "Walk beat remains 1.4 seconds")

	instance.call("_start_round", 1)
	instance.call("_set_view_role", GameTypes.PlayerRole.GUIDE_SIDE)
	var guide_consult: Dictionary = instance.call("get_current_presentation_snapshot")
	expect_eq(str(guide_consult["mode"]), "guide_consult", "Guide stopped screen is distinct")
	expect_eq(int(guide_consult["action_button_count"]), 0, "Guide stopped screen has no gameplay buttons")

	instance.call("_set_view_role", GameTypes.PlayerRole.BLIND)
	instance.call("_on_direction_pressed", GameTypes.BlindAction.FORWARD)
	instance.call("_set_view_role", GameTypes.PlayerRole.GUIDE_SIDE)
	var guide_walk: Dictionary = instance.call("get_current_presentation_snapshot")
	expect_eq(str(guide_walk["mode"]), "guide_walking", "Guide walking screen is distinct")
	expect_eq(int(guide_walk["action_button_count"]), 0, "Guide walking screen has no gameplay buttons")

	instance.call("_set_view_role", GameTypes.PlayerRole.BLIND)
	instance.call("_on_stop_pressed")
	instance.call("_on_request_swing")
	instance.call("_set_view_role", GameTypes.PlayerRole.GUIDE_SIDE)
	var guide_decision: Dictionary = instance.call("get_current_presentation_snapshot")
	expect_eq(str(guide_decision["mode"]), "guide_decision", "Guide decision screen is distinct")
	expect_eq(int(guide_decision["action_button_count"]), 0, "Guide decision screen has no gameplay buttons")

	instance.call("_set_view_role", GameTypes.PlayerRole.GUIDE_PATTERN)
	var watermelon_decision: Dictionary = instance.call("get_current_presentation_snapshot")
	expect_eq(str(watermelon_decision["mode"]), "watermelon_decision", "Watermelon decision screen is distinct")
	expect_true(bool(watermelon_decision["secret_board_visible"]), "Watermelon decision keeps secret board visible")
	expect_eq(int(watermelon_decision["action_button_count"]), 0, "Watermelon decision has no sabotage buttons")

	instance.free()
	return make_result("C5 UI")
