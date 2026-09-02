extends PhaseATestBase


func _check_side(facing: int, right_cell: Vector2i, left_cell: Vector2i, center_cell: Vector2i, label: String) -> void:
	var blind := Vector2i(2, 2)
	expect_eq(ObservationEngine.get_side_radar(blind, facing, right_cell), GameTypes.SideValue.RIGHT, "%s right" % label)
	expect_eq(ObservationEngine.get_side_radar(blind, facing, left_cell), GameTypes.SideValue.LEFT, "%s left" % label)
	expect_eq(ObservationEngine.get_side_radar(blind, facing, center_cell), GameTypes.SideValue.CENTER, "%s center" % label)


func run() -> Dictionary:
	_check_side(GameTypes.Facing.NORTH, Vector2i(3, 2), Vector2i(1, 2), Vector2i(2, 5), "north")
	_check_side(GameTypes.Facing.EAST, Vector2i(2, 3), Vector2i(2, 1), Vector2i(5, 2), "east")
	_check_side(GameTypes.Facing.SOUTH, Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 0), "south")
	_check_side(GameTypes.Facing.WEST, Vector2i(2, 1), Vector2i(2, 3), Vector2i(0, 2), "west")

	var watermelon := Vector2i(5, 2)
	expect_eq(ObservationEngine.get_step_echo(null, Vector2i(2, 2), watermelon), GameTypes.StepValue.NO_BASELINE, "step no baseline")
	expect_eq(ObservationEngine.get_step_echo(Vector2i(2, 2), Vector2i(3, 2), watermelon), GameTypes.StepValue.CLOSER, "step closer")
	expect_eq(ObservationEngine.get_step_echo(Vector2i(2, 2), Vector2i(1, 2), watermelon), GameTypes.StepValue.FARTHER, "step farther")
	expect_eq(ObservationEngine.get_step_echo(Vector2i(2, 2), Vector2i(3, 3), watermelon), GameTypes.StepValue.SAME, "step same")
	expect_eq(ObservationEngine.get_step_echo(Vector2i(2, 2), Vector2i(2, 2), watermelon), GameTypes.StepValue.SAME, "collision produces same")

	var patterns := {
		Vector2i(0, 0): GameTypes.PatternType.SHELL,
		Vector2i(1, 0): GameTypes.PatternType.STAR,
		Vector2i(2, 0): GameTypes.PatternType.CRAB,
		Vector2i(3, 0): GameTypes.PatternType.SHELL,
	}
	expect_eq(ObservationEngine.get_pattern_match(Vector2i(0, 0), Vector2i(3, 0), patterns), GameTypes.PatternValue.MATCH, "shell match")
	expect_eq(ObservationEngine.get_pattern_match(Vector2i(1, 0), Vector2i(1, 0), patterns), GameTypes.PatternValue.MATCH, "star self match")
	expect_eq(ObservationEngine.get_pattern_match(Vector2i(2, 0), Vector2i(2, 0), patterns), GameTypes.PatternValue.MATCH, "crab self match")
	expect_eq(ObservationEngine.get_pattern_match(Vector2i(0, 0), Vector2i(1, 0), patterns), GameTypes.PatternValue.DIFFERENT, "different patterns")

	return make_result("Sensors")
