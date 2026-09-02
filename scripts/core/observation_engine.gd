class_name ObservationEngine
extends RefCounted


static func get_side_radar(blind_cell: Vector2i, blind_facing: int, watermelon_cell: Vector2i) -> int:
	var delta: Vector2i = watermelon_cell - blind_cell
	var right: Vector2i = GameTypes.right_vector(blind_facing)
	var lateral: int = delta.x * right.x + delta.y * right.y
	if lateral < 0:
		return GameTypes.SideValue.LEFT
	if lateral > 0:
		return GameTypes.SideValue.RIGHT
	return GameTypes.SideValue.CENTER


static func get_step_echo(previous_cell: Variant, current_cell: Vector2i, watermelon_cell: Vector2i) -> int:
	if previous_cell == null:
		return GameTypes.StepValue.NO_BASELINE
	var previous: Vector2i = previous_cell
	var previous_distance := manhattan_distance(previous, watermelon_cell)
	var current_distance := manhattan_distance(current_cell, watermelon_cell)
	if current_distance < previous_distance:
		return GameTypes.StepValue.CLOSER
	if current_distance > previous_distance:
		return GameTypes.StepValue.FARTHER
	return GameTypes.StepValue.SAME


static func get_pattern_match(blind_cell: Vector2i, watermelon_cell: Vector2i, patterns: Dictionary) -> int:
	if not patterns.has(blind_cell) or not patterns.has(watermelon_cell):
		return GameTypes.PatternValue.DIFFERENT
	if int(patterns[blind_cell]) == int(patterns[watermelon_cell]):
		return GameTypes.PatternValue.MATCH
	return GameTypes.PatternValue.DIFFERENT


static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
