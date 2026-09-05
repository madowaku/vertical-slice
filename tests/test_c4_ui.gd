extends PhaseATestBase


func run() -> Dictionary:
	var resource := load("res://scenes/debug/local_debug_slice.tscn")
	expect_true(resource is PackedScene, "C4 scene loads")
	if not resource is PackedScene:
		return make_result("C4 UI")

	var instance := (resource as PackedScene).instantiate()
	expect_true(instance is Control, "C4 root is Control")
	instance.call("ensure_ui_for_test")

	var contract: Dictionary = instance.call("get_c4_contract_snapshot")
	expect_true(bool(contract["guide_skills_passive"]), "Guide skills are passive sensors")
	expect_eq(int(contract["guide_gameplay_buttons"]), 0, "Guides have no gameplay skill buttons")
	expect_eq(contract["blind_consult_actions"].size(), 5, "Blind consult exposes four directions plus swing")
	expect_true(contract["blind_consult_actions"].has(GameTypes.BlindAction.RIGHT), "Blind consult includes RIGHT")
	expect_eq(contract["blind_walking_actions"], [GameTypes.BlindAction.STOP], "Blind walking exposes STOP only")
	expect_eq(int(contract["watermelon_public_role"]), GameTypes.PublicRole.GUIDE, "Watermelon stays publicly GUIDE")
	expect_eq(int(contract["watermelon_secret_role"]), GameTypes.SecretRole.WATERMELON, "Watermelon secret identity remains private")
	expect_false(bool(contract["watermelon_board_has_coordinates"]), "Watermelon secret board has no coordinate labels")

	instance.call("_start_round", 1)
	expect_true(instance.find_child("BlindForwardButton", true, false) is Button, "Blind consult has forward button")
	expect_true(instance.find_child("BlindLeftButton", true, false) is Button, "Blind consult has left button")
	expect_true(instance.find_child("BlindRightButton", true, false) is Button, "Blind consult has right button")
	expect_true(instance.find_child("BlindBackButton", true, false) is Button, "Blind consult has back button")
	expect_true(instance.find_child("BlindSwingRequestButton", true, false) is Button, "Blind consult has swing request button")

	instance.free()
	return make_result("C4 UI")
