extends PhaseATestBase


const HIDDEN_BLIND_KEYS := ["watermelon", "watermelon_cell", "board", "obstacles", "patterns", "sensor", "sensor_histories"]


func run() -> Dictionary:
	var session := LocalDebugSession.new()
	expect_true(session.start_round(1), "local debug round starts")
	expect_eq(session.board_index, 1, "requested board selected")

	var blind := session.get_projection(GameTypes.PlayerRole.BLIND)
	expect_eq(blind["role"], GameTypes.PlayerRole.BLIND, "blind role projection")
	expect_true(blind.has("facing"), "blind sees facing")
	expect_true(blind.has("action_history"), "blind sees action history")
	for hidden_key in HIDDEN_BLIND_KEYS:
		expect_false(blind.has(hidden_key), "blind projection hides %s" % hidden_key)

	var side := session.get_projection(GameTypes.PlayerRole.GUIDE_SIDE)
	expect_true(side.has("board"), "side guide sees safe board")
	expect_eq(side["sensor"]["kind"], "side", "side guide gets only side sensor")
	expect_false(side.has("watermelon_cell"), "side guide has no top-level watermelon")
	expect_false(side["board"].has("watermelon_cell"), "safe guide board hides watermelon")

	var step := session.get_projection(GameTypes.PlayerRole.GUIDE_STEP)
	expect_eq(step["sensor"]["kind"], "step", "step guide gets only step sensor")
	var pattern := session.get_projection(GameTypes.PlayerRole.GUIDE_PATTERN)
	expect_eq(pattern["sensor"]["kind"], "pattern", "pattern guide gets only pattern sensor")

	expect_true(session.set_role(GameTypes.PlayerRole.GUIDE_STEP), "role switch accepted")
	expect_eq(session.get_projection()["role"], GameTypes.PlayerRole.GUIDE_STEP, "current role projection follows switch")
	expect_false(session.set_role(99), "invalid role switch rejected")

	var initial_side_history: Array = session.sensor_histories["side"]
	expect_eq(initial_side_history.size(), 1, "turn 1 side history captured once")
	for index in range(7):
		var move_result := session.process_action(GameTypes.BlindAction.FORWARD)
		expect_true(bool(move_result.get("accepted", false)), "local move %d accepted" % (index + 1))
		expect_eq(session.round_controller.state, GameTypes.RoundState.TALK, "move %d returns to talk" % (index + 1))
	expect_eq(session.sensor_histories["side"].size(), 8, "sensor history captures turns 1 through 8")

	var final_move := session.process_action(GameTypes.BlindAction.FORWARD)
	expect_true(bool(final_move.get("accepted", false)), "turn 8 movement accepted")
	expect_true(bool(final_move.get("auto_swing", false)), "turn 8 movement auto swings")
	expect_eq(session.round_controller.state, GameTypes.RoundState.RESULT, "local round reaches result")
	expect_eq(session.action_history.size(), 8, "eight actions recorded in local history")

	expect_true(session.begin_reveal(), "local result enters reveal")
	var reveal := session.get_reveal_projection()
	expect_true(reveal.has("watermelon_cell"), "reveal exposes watermelon")
	expect_true(reveal.has("records"), "reveal exposes turn records")
	expect_eq(reveal["records"].size(), 8, "reveal has all turn records")
	expect_true(reveal.has("sensor_histories"), "reveal exposes all sensor histories")

	expect_true(session.rematch(2), "explicit rematch starts")
	expect_eq(session.board_index, 2, "rematch selects requested board")
	expect_eq(session.round_controller.turn, 1, "rematch resets to turn 1")
	expect_eq(session.action_history.size(), 0, "rematch clears action history")
	expect_eq(session.sensor_histories["step"].size(), 1, "rematch resets and captures turn 1 sensor")

	var early_session := LocalDebugSession.new()
	expect_true(early_session.start_round(3), "early swing session starts")
	var early_result := early_session.process_action(GameTypes.BlindAction.SWING)
	expect_true(bool(early_result.get("swing", false)), "local early swing recognized")
	expect_eq(early_session.round_controller.state, GameTypes.RoundState.RESULT, "local early swing reaches result")
	expect_true(early_session.begin_reveal(), "early swing result can reveal")
	expect_eq(early_session.get_reveal_projection()["records"].size(), 1, "early swing reveal has one record")

	return make_result("Local debug session")
