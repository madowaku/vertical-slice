extends PhaseATestBase


func run() -> Dictionary:
	var definition := BoardManager.load_board(BoardManager.preset_path(1))
	var round := RoundController.new()
	round.setup(definition)
	round.start_round()

	var pre_cell := round.board_state.blind_cell
	var pre_facing := round.board_state.blind_facing
	var sensors := round.get_sensor_snapshot()
	var result := round.process_action(GameTypes.BlindAction.LEFT)
	var record: TurnRecord = result["record"]

	expect_eq(record.turn_number, 1, "record turn")
	expect_eq(record.blind_cell_before, pre_cell, "record pre cell")
	expect_eq(record.blind_facing_before, pre_facing, "record pre facing")
	expect_eq(record.side_value, sensors["side"], "record side sensor")
	expect_eq(record.step_value, GameTypes.StepValue.NO_BASELINE, "record turn 1 step baseline")
	expect_eq(record.pattern_value, sensors["pattern"], "record pattern sensor")
	expect_eq(record.action, GameTypes.BlindAction.LEFT, "record action")
	expect_eq(record.blind_cell_after, round.board_state.blind_cell, "record post cell")
	expect_eq(record.blind_facing_after, round.board_state.blind_facing, "record post facing")

	var turn_two_sensors := round.get_sensor_snapshot()
	var expected_step := ObservationEngine.get_step_echo(pre_cell, round.board_state.blind_cell, round.board_state.watermelon_cell)
	expect_eq(turn_two_sensors["step"], expected_step, "turn 2 step compares previous cell")

	return make_result("Turn record")
