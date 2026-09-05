extends PhaseATestBase


func run() -> Dictionary:
	var definition := BoardManager.load_board(BoardManager.preset_path(1))

	var invalid := RoundController.new()
	invalid.setup(definition)
	expect_false(invalid.change_state(GameTypes.RoundState.CONSULT), "invalid WAITING -> CONSULT rejected")
	expect_eq(invalid.state, GameTypes.RoundState.WAITING, "invalid transition keeps state")

	var round := RoundController.new()
	round.setup(definition)
	expect_true(round.start_round(), "round starts")
	expect_eq(round.state, GameTypes.RoundState.CONSULT, "start reaches CONSULT")
	expect_eq(round.steps_remaining, 8, "start has eight steps")
	expect_eq(round.steps_taken, 0, "start has taken no steps")

	var start_cell := round.board_state.blind_cell
	var start_facing := round.board_state.blind_facing
	var expected_right_facing := GameTypes.rotated_facing(start_facing, GameTypes.BlindAction.RIGHT)
	var begin := round.begin_walk(GameTypes.BlindAction.RIGHT)
	expect_true(bool(begin.get("accepted", false)), "direction starts walking")
	expect_eq(round.state, GameTypes.RoundState.WALKING, "begin walk enters WALKING")
	expect_eq(round.steps_remaining, 8, "choosing direction costs no step")
	expect_eq(round.board_state.blind_cell, start_cell, "choosing direction does not move")
	expect_eq(round.board_state.blind_facing, start_facing, "choosing direction does not rotate before first beat")

	var pre_step_stop := round.stop_walk()
	expect_true(bool(pre_step_stop.get("accepted", false)), "STOP before first beat accepted")
	expect_eq(round.state, GameTypes.RoundState.CONSULT, "STOP returns to CONSULT")
	expect_eq(round.steps_remaining, 8, "STOP costs no step")
	expect_eq(round.board_state.blind_facing, start_facing, "STOP before first beat gives no free rotation")

	round.begin_walk(GameTypes.BlindAction.RIGHT)
	var first_step := round.advance_step()
	expect_true(bool(first_step.get("accepted", false)), "first walking beat accepted")
	expect_true(bool(first_step.get("step", false)), "first walking beat identified as a step")
	expect_eq(round.steps_taken, 1, "first beat increments steps taken")
	expect_eq(round.steps_remaining, 7, "first beat consumes one step")
	expect_eq(round.board_state.blind_facing, expected_right_facing, "first beat applies chosen relative direction once")

	if round.state == GameTypes.RoundState.WALKING:
		var manual_stop := round.stop_walk()
		expect_true(bool(manual_stop.get("accepted", false)), "manual STOP accepted after a beat")
		expect_eq(round.state, GameTypes.RoundState.CONSULT, "manual STOP returns to CONSULT")
		expect_eq(round.steps_remaining, 7, "manual STOP does not consume an extra step")
	else:
		expect_eq(round.state, GameTypes.RoundState.CONSULT, "BUMP auto-stops at CONSULT")

	while round.steps_remaining > 0:
		if round.state == GameTypes.RoundState.CONSULT:
			var resume := round.begin_walk(GameTypes.BlindAction.FORWARD)
			expect_true(bool(resume.get("accepted", false)), "resume walking accepted")
		var before := round.steps_remaining
		var step_result := round.advance_step()
		expect_true(bool(step_result.get("accepted", false)), "budget step accepted")
		expect_eq(round.steps_remaining, before - 1, "every beat consumes exactly one step")

	expect_eq(round.steps_taken, 8, "eight beats consume full budget")
	expect_eq(round.records.size(), 8, "eight step records created")
	expect_eq(round.state, GameTypes.RoundState.DECISION, "step eight enters final DECISION")
	expect_false(round.can_continue_after_decision(), "zero-step final decision cannot return to walking")
	var final_swing := round.confirm_swing()
	expect_true(bool(final_swing.get("accepted", false)), "final swing accepted")
	expect_true(bool(final_swing.get("swing", false)), "final action identified as swing")
	expect_eq(round.state, GameTypes.RoundState.RESULT, "confirmed swing reaches RESULT")
	expect_true(round.begin_reveal(), "result enters reveal")
	expect_eq(round.state, GameTypes.RoundState.REVEAL, "reveal state active")
	expect_true(round.complete_round(), "reveal completes round")
	expect_eq(round.state, GameTypes.RoundState.COMPLETE, "round complete")

	var early := RoundController.new()
	early.setup(definition)
	early.start_round()
	var request := early.request_swing()
	expect_true(bool(request.get("accepted", false)), "early swing request accepted")
	expect_eq(early.state, GameTypes.RoundState.DECISION, "early swing request enters DECISION")
	expect_eq(early.steps_remaining, 8, "swing request costs no step")
	var continue_result := early.continue_after_decision()
	expect_true(bool(continue_result.get("accepted", false)), "decision can return to CONSULT with steps left")
	expect_eq(early.state, GameTypes.RoundState.CONSULT, "continue returns to CONSULT")
	early.request_swing()
	var early_swing := early.confirm_swing()
	expect_true(bool(early_swing.get("accepted", false)), "early confirmed swing accepted")
	expect_eq(early.state, GameTypes.RoundState.RESULT, "early confirmed swing reaches RESULT")

	var compatibility := RoundController.new()
	compatibility.setup(definition)
	compatibility.start_round()
	var legacy_step := compatibility.process_action(GameTypes.BlindAction.FORWARD)
	expect_true(bool(legacy_step.get("accepted", false)), "legacy single-step helper accepted")
	expect_true(bool(legacy_step.get("legacy_single_step", false)), "legacy helper labels one-step mode")
	expect_eq(compatibility.steps_remaining, 7, "legacy helper still uses step budget")
	expect_eq(compatibility.state, GameTypes.RoundState.CONSULT, "legacy helper stops after one beat")

	return make_result("Round flow")
