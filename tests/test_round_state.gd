extends PhaseATestBase


func run() -> Dictionary:
	var definition := BoardManager.load_board(BoardManager.preset_path(1))

	var invalid := RoundController.new()
	invalid.setup(definition)
	expect_false(invalid.change_state(GameTypes.RoundState.TALK), "invalid WAITING -> TALK rejected")
	expect_eq(invalid.state, GameTypes.RoundState.WAITING, "invalid transition keeps state")

	var round := RoundController.new()
	round.setup(definition)
	expect_true(round.start_round(), "round starts")
	expect_eq(round.state, GameTypes.RoundState.TALK, "start reaches TALK")
	expect_eq(round.turn, 1, "start is turn 1")

	for index in range(8):
		var result := round.process_action(GameTypes.BlindAction.FORWARD)
		expect_true(bool(result.get("accepted", false)), "turn %d action accepted" % (index + 1))
		if index < 7:
			expect_eq(round.state, GameTypes.RoundState.TALK, "turn %d returns to TALK" % (index + 1))
			expect_eq(round.turn, index + 2, "turn counter advances after %d" % (index + 1))
		else:
			expect_true(bool(result.get("auto_swing", false)), "turn 8 triggers final auto swing")

	expect_eq(round.records.size(), 8, "eight turn records created")
	expect_eq(round.state, GameTypes.RoundState.RESULT, "turn 8 ends at RESULT")
	expect_true(round.begin_reveal(), "result enters reveal")
	expect_eq(round.state, GameTypes.RoundState.REVEAL, "reveal state active")
	expect_true(round.complete_round(), "reveal completes round")
	expect_eq(round.state, GameTypes.RoundState.COMPLETE, "round complete")

	var wait_action := RoundController.new()
	wait_action.setup(definition)
	wait_action.start_round()
	expect_true(wait_action.end_talk(), "talk can end without action")
	expect_eq(wait_action.state, GameTypes.RoundState.WAIT_ACTION, "wait action state")
	var waited_result := wait_action.process_action(GameTypes.BlindAction.LEFT)
	expect_true(bool(waited_result.get("accepted", false)), "action accepted from WAIT_ACTION")

	var early_swing := RoundController.new()
	early_swing.setup(definition)
	early_swing.start_round()
	var swing_result := early_swing.process_action(GameTypes.BlindAction.SWING)
	expect_true(bool(swing_result.get("accepted", false)), "early swing accepted")
	expect_true(bool(swing_result.get("swing", false)), "early action identified as swing")
	expect_eq(early_swing.records.size(), 1, "early swing recorded")
	expect_eq(early_swing.state, GameTypes.RoundState.RESULT, "early swing reaches result")

	return make_result("Round flow")
