extends PhaseATestBase


const HIDDEN_BLIND_KEYS := [
	"facing",
	"blind_facing",
	"blind_cell",
	"watermelon",
	"watermelon_cell",
	"board",
	"obstacles",
	"patterns",
	"sensor",
	"sensor_histories",
]

const HIDDEN_GUIDE_KEYS := [
	"facing",
	"blind_facing",
	"blind_cell",
	"watermelon",
	"watermelon_cell",
	"board",
	"obstacles",
	"patterns",
	"sensor_histories",
]


func run() -> Dictionary:
	var session := LocalDebugSession.new()
	expect_true(session.start_round(1), "local debug round starts")
	expect_eq(session.board_index, 1, "requested board selected")
	expect_eq(session.round_controller.state, GameTypes.RoundState.CONSULT, "debug round starts in CONSULT")
	expect_eq(session.round_controller.steps_remaining, 8, "debug round starts with eight steps")

	var blind := session.get_projection(GameTypes.PlayerRole.BLIND)
	expect_eq(blind["role"], GameTypes.PlayerRole.BLIND, "blind role projection")
	expect_true(blind.has("action_history"), "blind sees public action history")
	expect_eq(blind["steps_remaining"], 8, "blind projection exposes step budget")
	expect_true(bool(blind["can_choose_direction"]), "blind can choose direction in CONSULT")
	expect_true(bool(blind["can_request_swing"]), "blind can request swing in CONSULT")
	for hidden_key in HIDDEN_BLIND_KEYS:
		expect_false(blind.has(hidden_key), "blind projection hides %s" % hidden_key)

	var side := session.get_projection(GameTypes.PlayerRole.GUIDE_SIDE)
	expect_eq(side["sensor"]["kind"], "side", "side guide gets only side sensor")
	expect_true(side.has("action_history"), "side guide receives public action history")
	for hidden_key in HIDDEN_GUIDE_KEYS:
		expect_false(side.has(hidden_key), "side guide projection hides %s" % hidden_key)

	var step := session.get_projection(GameTypes.PlayerRole.GUIDE_STEP)
	expect_eq(step["sensor"]["kind"], "step", "step guide gets only step sensor")
	for hidden_key in HIDDEN_GUIDE_KEYS:
		expect_false(step.has(hidden_key), "step guide projection hides %s" % hidden_key)

	var pattern := session.get_projection(GameTypes.PlayerRole.GUIDE_PATTERN)
	expect_eq(pattern["sensor"]["kind"], "pattern", "pattern guide gets only pattern sensor")
	for hidden_key in HIDDEN_GUIDE_KEYS:
		expect_false(pattern.has(hidden_key), "pattern guide projection hides %s" % hidden_key)

	expect_true(session.set_role(GameTypes.PlayerRole.GUIDE_STEP), "role switch accepted")
	expect_eq(session.get_projection()["role"], GameTypes.PlayerRole.GUIDE_STEP, "current role projection follows switch")
	expect_false(session.set_role(99), "invalid role switch rejected")
	expect_true(session.get_projection(99).is_empty(), "invalid explicit role projection is empty")

	var initial_side_history: Array = session.sensor_histories["side"]
	expect_eq(initial_side_history.size(), 1, "S0 side history captured once")
	expect_eq(initial_side_history[0]["step"], 0, "initial sensor reading is S0")

	for index in range(8):
		var move_result := session.process_action(GameTypes.BlindAction.FORWARD)
		expect_true(bool(move_result.get("accepted", false)), "local step %d accepted" % (index + 1))
		expect_true(bool(move_result.get("step", false)), "local action %d produces a step beat" % (index + 1))
		if index < 7:
			expect_eq(session.round_controller.state, GameTypes.RoundState.CONSULT, "legacy debug helper stops after step %d" % (index + 1))

	expect_eq(session.round_controller.steps_taken, 8, "debug session records eight steps")
	expect_eq(session.round_controller.steps_remaining, 0, "debug session exhausts step budget")
	expect_eq(session.sensor_histories["side"].size(), 9, "sensor history captures S0 through S8")
	expect_eq(session.round_controller.state, GameTypes.RoundState.DECISION, "step eight enters final decision")

	var final_projection := session.get_projection(GameTypes.PlayerRole.BLIND)
	expect_true(bool(final_projection["can_confirm_swing"]), "blind can confirm swing in final decision")
	expect_false(bool(final_projection["can_continue_after_decision"]), "zero-step final decision cannot continue")
	for hidden_key in HIDDEN_BLIND_KEYS:
		expect_false(final_projection.has(hidden_key), "final blind projection still hides %s" % hidden_key)

	var final_swing := session.process_action(GameTypes.BlindAction.SWING)
	expect_true(bool(final_swing.get("accepted", false)), "final swing accepted from decision")
	expect_true(bool(final_swing.get("swing", false)), "final action recognized as swing")
	expect_eq(session.round_controller.state, GameTypes.RoundState.RESULT, "local round reaches result")
	expect_eq(session.action_history.size(), 9, "eight steps plus swing recorded in local history")

	var result_guide := session.get_projection(GameTypes.PlayerRole.GUIDE_SIDE)
	expect_true(bool(result_guide["result_known"]), "guide learns result at RESULT")
	for hidden_key in HIDDEN_GUIDE_KEYS:
		expect_false(result_guide.has(hidden_key), "result guide projection still hides %s" % hidden_key)

	expect_true(session.begin_reveal(), "local result enters reveal")
	var reveal := session.get_reveal_projection()
	expect_true(reveal.has("watermelon_cell"), "reveal exposes watermelon")
	expect_true(reveal.has("board"), "reveal exposes full board")
	expect_true(reveal.has("records"), "reveal exposes step records")
	expect_eq(reveal["records"].size(), 8, "reveal has all eight step records")
	expect_true(reveal.has("sensor_histories"), "reveal exposes all sensor histories")

	expect_true(session.rematch(2), "explicit rematch starts")
	expect_eq(session.board_index, 2, "rematch selects requested board")
	expect_eq(session.round_controller.steps_taken, 0, "rematch resets steps taken")
	expect_eq(session.round_controller.steps_remaining, 8, "rematch restores eight-step budget")
	expect_eq(session.action_history.size(), 0, "rematch clears action history")
	expect_eq(session.sensor_histories["step"].size(), 1, "rematch resets and captures S0 sensor")

	var walking_session := LocalDebugSession.new()
	expect_true(walking_session.start_round(3), "explicit walking session starts")
	var begin_walk := walking_session.begin_walk(GameTypes.BlindAction.RIGHT)
	expect_true(bool(begin_walk.get("accepted", false)), "debug session exposes begin_walk")
	expect_eq(walking_session.round_controller.state, GameTypes.RoundState.WALKING, "explicit begin enters WALKING")
	var walking_blind := walking_session.get_projection(GameTypes.PlayerRole.BLIND)
	expect_true(bool(walking_blind["can_stop"]), "blind can STOP while walking")
	expect_eq(walking_blind["walk_direction"], GameTypes.BlindAction.RIGHT, "walking projection exposes only chosen relative direction")
	expect_false(walking_blind.has("facing"), "walking projection still hides absolute facing")
	var live_step := walking_session.advance_step()
	expect_true(bool(live_step.get("accepted", false)), "debug session exposes live step beat")
	if walking_session.round_controller.state == GameTypes.RoundState.WALKING:
		var stopped := walking_session.stop_walk()
		expect_true(bool(stopped.get("accepted", false)), "debug session exposes STOP")
		expect_eq(walking_session.round_controller.state, GameTypes.RoundState.CONSULT, "STOP returns explicit walk to CONSULT")

	var early_session := LocalDebugSession.new()
	expect_true(early_session.start_round(3), "early swing session starts")
	var early_request := early_session.process_action(GameTypes.BlindAction.SWING)
	expect_true(bool(early_request.get("decision", false)), "first swing press requests decision")
	expect_eq(early_session.round_controller.state, GameTypes.RoundState.DECISION, "early request reaches decision")
	var early_projection := early_session.get_projection(GameTypes.PlayerRole.BLIND)
	expect_true(bool(early_projection["can_continue_after_decision"]), "early decision can return to consult with steps left")
	var early_result := early_session.process_action(GameTypes.BlindAction.SWING)
	expect_true(bool(early_result.get("swing", false)), "second swing press confirms swing")
	expect_eq(early_session.round_controller.state, GameTypes.RoundState.RESULT, "local early swing reaches result")
	expect_true(early_session.begin_reveal(), "early swing result can reveal")
	expect_eq(early_session.get_reveal_projection()["records"].size(), 0, "early swing reveal has no movement records")

	return make_result("Local debug session")
