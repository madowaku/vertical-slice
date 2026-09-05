extends PhaseATestBase


func run() -> Dictionary:
	var definition := BoardManager.load_board(BoardManager.preset_path(1))
	var round := RoundController.new()
	round.setup(definition)
	round.start_round()

	var pre_cell := round.board_state.blind_cell
	var pre_facing := round.board_state.blind_facing
	var initial_sensors := round.get_sensor_snapshot()
	expect_eq(initial_sensors["step"], GameTypes.StepValue.NO_BASELINE, "S0 step has no baseline")

	var begin := round.begin_walk(GameTypes.BlindAction.LEFT)
	expect_true(bool(begin.get("accepted", false)), "walk direction accepted")
	expect_eq(round.board_state.blind_cell, pre_cell, "begin walk does not move before beat")
	expect_eq(round.board_state.blind_facing, pre_facing, "begin walk does not rotate before beat")

	var result := round.advance_step()
	var record: TurnRecord = result["record"]
	var post_sensors := round.get_sensor_snapshot()

	expect_eq(record.step_number, 1, "record step number")
	expect_eq(record.turn_number, 1, "legacy turn alias matches step")
	expect_eq(record.walk_direction, GameTypes.BlindAction.LEFT, "record stores chosen walk direction")
	expect_eq(record.action, GameTypes.BlindAction.LEFT, "first beat applies chosen relative action")
	expect_eq(record.blind_cell_before, pre_cell, "record pre cell")
	expect_eq(record.blind_facing_before, pre_facing, "record pre facing")
	expect_eq(record.side_value, post_sensors["side"], "record stores post-step side sensor")
	expect_eq(record.step_value, post_sensors["step"], "record stores post-step echo")
	expect_eq(record.pattern_value, post_sensors["pattern"], "record stores post-step pattern sensor")
	expect_eq(record.blind_cell_after, round.board_state.blind_cell, "record post cell")
	expect_eq(record.blind_facing_after, round.board_state.blind_facing, "record post facing")

	var expected_step := ObservationEngine.get_step_echo(pre_cell, round.board_state.blind_cell, round.board_state.watermelon_cell)
	expect_eq(record.step_value, expected_step, "step echo compares cell before this beat to cell after")

	if round.state == GameTypes.RoundState.WALKING:
		var second_result := round.advance_step()
		var second_record: TurnRecord = second_result["record"]
		expect_eq(second_record.step_number, 2, "continuous walk creates second step record")
		expect_eq(second_record.action, GameTypes.BlindAction.FORWARD, "later beats continue straight without rotating again")
		expect_eq(second_record.walk_direction, GameTypes.BlindAction.LEFT, "continuous walk retains original chosen direction")

	return make_result("Step record")
