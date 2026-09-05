extends PhaseATestBase


const PUBLIC_FORBIDDEN_KEYS := [
	"secret_role",
	"secret_board",
	"watermelon_player_present",
	"watermelon_player_role",
	"watermelon_cell",
]


func run() -> Dictionary:
	_test_identity_mapping()
	_test_picnic_has_no_secret_player()
	_test_watermelon_projection_and_reveal()
	return make_result("Watermelon role")


func _test_identity_mapping() -> void:
	expect_eq(
		GameTypes.public_role_for_player_role(GameTypes.PlayerRole.BLIND),
		GameTypes.PublicRole.BLIND,
		"Blind maps to public BLIND",
	)
	expect_eq(
		GameTypes.public_role_for_player_role(GameTypes.PlayerRole.GUIDE_SIDE),
		GameTypes.PublicRole.GUIDE,
		"Side maps to public GUIDE",
	)
	expect_eq(
		GameTypes.public_role_for_player_role(GameTypes.PlayerRole.GUIDE_PATTERN),
		GameTypes.PublicRole.GUIDE,
		"Pattern maps to public GUIDE",
	)
	expect_eq(
		GameTypes.guide_skill_for_player_role(GameTypes.PlayerRole.BLIND),
		GameTypes.GuideSkill.NONE,
		"Blind has no Guide skill",
	)
	expect_eq(
		GameTypes.guide_skill_for_player_role(GameTypes.PlayerRole.GUIDE_SIDE),
		GameTypes.GuideSkill.SIDE,
		"Side Guide maps to SIDE skill",
	)
	expect_eq(
		GameTypes.guide_skill_for_player_role(GameTypes.PlayerRole.GUIDE_STEP),
		GameTypes.GuideSkill.STEP,
		"Step Guide maps to STEP skill",
	)
	expect_eq(
		GameTypes.guide_skill_for_player_role(GameTypes.PlayerRole.GUIDE_PATTERN),
		GameTypes.GuideSkill.PATTERN,
		"Pattern Guide maps to PATTERN skill",
	)
	expect_true(GameTypes.is_guide_player_role(GameTypes.PlayerRole.GUIDE_STEP), "Guide role recognized")
	expect_false(GameTypes.is_guide_player_role(GameTypes.PlayerRole.BLIND), "Blind cannot be a Watermelon player")


func _test_picnic_has_no_secret_player() -> void:
	var session := LocalDebugSession.new()
	expect_true(session.set_watermelon_role(LocalDebugSession.NO_WATERMELON_ROLE), "PICNIC explicitly selects no Watermelon player")
	var roster := session.get_public_roster_projection()
	expect_eq(roster.size(), 4, "public roster has four player slots")
	_assert_public_roster_safe(roster, "PICNIC roster")

	expect_true(session.start_round(1), "PICNIC round starts")
	for role in [
		GameTypes.PlayerRole.BLIND,
		GameTypes.PlayerRole.GUIDE_SIDE,
		GameTypes.PlayerRole.GUIDE_STEP,
		GameTypes.PlayerRole.GUIDE_PATTERN,
	]:
		var projection := session.get_projection(role)
		expect_eq(projection["secret_role"], GameTypes.SecretRole.NONE, "PICNIC player %d has no secret role" % role)
		expect_false(projection.has("secret_board"), "PICNIC player %d has no secret board" % role)

	var request := session.request_swing()
	expect_true(bool(request.get("accepted", false)), "PICNIC can enter early decision")
	var swing := session.confirm_swing()
	expect_true(bool(swing.get("accepted", false)), "PICNIC can resolve swing")
	expect_true(session.begin_reveal(), "PICNIC enters reveal")
	var reveal := session.get_reveal_projection()
	expect_false(bool(reveal["watermelon_player_present"]), "PICNIC reveal confirms no Watermelon player")
	expect_eq(reveal["watermelon_player_role"], LocalDebugSession.NO_WATERMELON_ROLE, "PICNIC reveal uses no-player sentinel")


func _test_watermelon_projection_and_reveal() -> void:
	var session := LocalDebugSession.new()
	expect_false(session.set_watermelon_role(GameTypes.PlayerRole.BLIND), "Blind cannot be assigned THE WATERMELON")
	expect_false(session.set_watermelon_role(99), "invalid slot cannot be assigned THE WATERMELON")
	expect_true(session.set_watermelon_role(GameTypes.PlayerRole.GUIDE_PATTERN), "Pattern Guide can be assigned THE WATERMELON")

	var roster_before := session.get_public_roster_projection()
	_assert_public_roster_safe(roster_before, "MAYBE roster before round")
	expect_eq(roster_before[3]["public_role"], GameTypes.PublicRole.GUIDE, "Watermelon slot is publicly still GUIDE")
	expect_eq(roster_before[3]["guide_skill"], GameTypes.GuideSkill.PATTERN, "Watermelon keeps normal Guide skill publicly")

	expect_true(session.start_round(2), "MAYBE round starts")
	expect_false(session.set_watermelon_role(GameTypes.PlayerRole.GUIDE_SIDE), "secret assignment cannot mutate mid-round")

	var blind := session.get_projection(GameTypes.PlayerRole.BLIND)
	expect_eq(blind["public_role"], GameTypes.PublicRole.BLIND, "Blind projection exposes public role")
	expect_eq(blind["secret_role"], GameTypes.SecretRole.NONE, "Blind has no secret role")
	expect_false(blind.has("secret_board"), "Blind never receives secret board")

	var side := session.get_projection(GameTypes.PlayerRole.GUIDE_SIDE)
	expect_eq(side["public_role"], GameTypes.PublicRole.GUIDE, "normal Side player is public GUIDE")
	expect_eq(side["guide_skill"], GameTypes.GuideSkill.SIDE, "normal Side player keeps own skill")
	expect_eq(side["secret_role"], GameTypes.SecretRole.NONE, "normal Guide learns only that they are not Watermelon")
	expect_false(side.has("secret_board"), "normal Guide gets no secret board")
	expect_eq(side["sensor"]["kind"], "side", "normal Guide still gets only own sensor")

	var watermelon := session.get_projection(GameTypes.PlayerRole.GUIDE_PATTERN)
	expect_eq(watermelon["public_role"], GameTypes.PublicRole.GUIDE, "THE WATERMELON is publicly GUIDE")
	expect_eq(watermelon["guide_skill"], GameTypes.GuideSkill.PATTERN, "THE WATERMELON keeps PATTERN as normal sensor")
	expect_eq(watermelon["secret_role"], GameTypes.SecretRole.WATERMELON, "Watermelon player privately learns secret role")
	expect_true(watermelon.has("secret_board"), "Watermelon player receives secret full board")
	expect_eq(watermelon["sensor"]["kind"], "pattern", "Watermelon player still receives exactly own normal sensor")

	var secret_board: Dictionary = watermelon["secret_board"]
	expect_true(secret_board.has("blind_cell"), "secret board contains Blind cell")
	expect_true(secret_board.has("blind_facing"), "secret board contains Blind facing")
	expect_true(secret_board.has("watermelon_cell"), "secret board contains fruit cell")
	expect_true(secret_board.has("obstacles"), "secret board contains obstacles")
	expect_true(secret_board.has("patterns"), "secret board contains patterns")
	expect_eq(secret_board["patterns"].size(), 36, "secret board contains all 36 pattern cells")
	expect_eq(secret_board["blind_cell"], _cell_array(session.round_controller.board_state.blind_cell), "secret Blind cell matches authority")
	expect_eq(secret_board["blind_facing"], session.round_controller.board_state.blind_facing, "secret Blind facing matches authority")
	expect_eq(secret_board["watermelon_cell"], _cell_array(session.round_controller.board_state.watermelon_cell), "secret fruit cell matches authority")
	expect_false(watermelon.has("sensor_histories"), "Watermelon does not receive other Guides' sensor histories")

	var begin := session.begin_walk(GameTypes.BlindAction.RIGHT)
	expect_true(bool(begin.get("accepted", false)), "MAYBE walk begins")
	var step := session.advance_step()
	expect_true(bool(step.get("accepted", false)), "MAYBE walk advances one beat")
	var live_watermelon := session.get_projection(GameTypes.PlayerRole.GUIDE_PATTERN)
	expect_eq(
		live_watermelon["secret_board"]["blind_cell"],
		_cell_array(session.round_controller.board_state.blind_cell),
		"Watermelon secret board tracks Blind live",
	)
	var live_side := session.get_projection(GameTypes.PlayerRole.GUIDE_SIDE)
	expect_false(live_side.has("secret_board"), "other Guide remains blind to secret board during movement")
	expect_eq(live_side["secret_role"], GameTypes.SecretRole.NONE, "other Guide receives no hint that Watermelon exists")

	if session.round_controller.state == GameTypes.RoundState.WALKING:
		var stop := session.stop_walk()
		expect_true(bool(stop.get("accepted", false)), "MAYBE walk can STOP")
	expect_eq(session.round_controller.state, GameTypes.RoundState.CONSULT, "MAYBE is back in CONSULT before swing request")
	var request := session.request_swing()
	expect_true(bool(request.get("accepted", false)), "MAYBE enters decision")
	var swing := session.confirm_swing()
	expect_true(bool(swing.get("accepted", false)), "MAYBE resolves swing")

	var result_side := session.get_projection(GameTypes.PlayerRole.GUIDE_SIDE)
	expect_false(result_side.has("secret_board"), "result does not reveal secret board to ordinary Guide")
	expect_false(result_side.has("watermelon_player_present"), "result does not reveal whether Watermelon player existed")

	expect_true(session.begin_reveal(), "MAYBE enters reveal")
	var reveal := session.get_reveal_projection()
	expect_true(bool(reveal["watermelon_player_present"]), "REVEAL confirms Watermelon player existed")
	expect_eq(reveal["watermelon_player_role"], GameTypes.PlayerRole.GUIDE_PATTERN, "REVEAL identifies Pattern slot as Watermelon player")
	_assert_public_roster_safe(reveal["public_roster"], "REVEAL public roster remains public-only")


func _assert_public_roster_safe(roster: Array, label: String) -> void:
	for forbidden_key in PUBLIC_FORBIDDEN_KEYS:
		expect_false(_contains_key_recursive(roster, forbidden_key), "%s excludes %s" % [label, forbidden_key])


func _contains_key_recursive(value: Variant, key_name: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value
		if dictionary.has(key_name):
			return true
		for nested_value in dictionary.values():
			if _contains_key_recursive(nested_value, key_name):
				return true
		return false
	if typeof(value) == TYPE_ARRAY:
		for nested_value in value:
			if _contains_key_recursive(nested_value, key_name):
				return true
	return false


static func _cell_array(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]
