extends PhaseATestBase


func _make_state(cell: Vector2i, facing: int, obstacles: Dictionary = {}) -> BoardState:
	var state := BoardState.new()
	state.blind_cell = cell
	state.blind_facing = facing
	state.obstacles = obstacles.duplicate(true)
	return state


func _expect_move(facing: int, action: int, expected_cell: Vector2i, expected_facing: int, label: String) -> void:
	var state := _make_state(Vector2i(2, 2), facing)
	var result := BoardManager.resolve_action(state, action)
	expect_eq(result["cell_after"], expected_cell, "%s cell" % label)
	expect_eq(result["facing_after"], expected_facing, "%s facing" % label)
	expect_eq(result["collision"], GameTypes.CollisionType.NONE, "%s no collision" % label)


func run() -> Dictionary:
	_expect_move(GameTypes.Facing.NORTH, GameTypes.BlindAction.FORWARD, Vector2i(2, 1), GameTypes.Facing.NORTH, "north forward")
	_expect_move(GameTypes.Facing.NORTH, GameTypes.BlindAction.LEFT, Vector2i(1, 2), GameTypes.Facing.WEST, "north left")
	_expect_move(GameTypes.Facing.NORTH, GameTypes.BlindAction.RIGHT, Vector2i(3, 2), GameTypes.Facing.EAST, "north right")
	_expect_move(GameTypes.Facing.NORTH, GameTypes.BlindAction.BACK, Vector2i(2, 3), GameTypes.Facing.SOUTH, "north back")

	_expect_move(GameTypes.Facing.EAST, GameTypes.BlindAction.FORWARD, Vector2i(3, 2), GameTypes.Facing.EAST, "east forward")
	_expect_move(GameTypes.Facing.EAST, GameTypes.BlindAction.LEFT, Vector2i(2, 1), GameTypes.Facing.NORTH, "east left")
	_expect_move(GameTypes.Facing.EAST, GameTypes.BlindAction.RIGHT, Vector2i(2, 3), GameTypes.Facing.SOUTH, "east right")
	_expect_move(GameTypes.Facing.EAST, GameTypes.BlindAction.BACK, Vector2i(1, 2), GameTypes.Facing.WEST, "east back")

	_expect_move(GameTypes.Facing.SOUTH, GameTypes.BlindAction.FORWARD, Vector2i(2, 3), GameTypes.Facing.SOUTH, "south forward")
	_expect_move(GameTypes.Facing.SOUTH, GameTypes.BlindAction.LEFT, Vector2i(3, 2), GameTypes.Facing.EAST, "south left")
	_expect_move(GameTypes.Facing.SOUTH, GameTypes.BlindAction.RIGHT, Vector2i(1, 2), GameTypes.Facing.WEST, "south right")
	_expect_move(GameTypes.Facing.SOUTH, GameTypes.BlindAction.BACK, Vector2i(2, 1), GameTypes.Facing.NORTH, "south back")

	_expect_move(GameTypes.Facing.WEST, GameTypes.BlindAction.FORWARD, Vector2i(1, 2), GameTypes.Facing.WEST, "west forward")
	_expect_move(GameTypes.Facing.WEST, GameTypes.BlindAction.LEFT, Vector2i(2, 3), GameTypes.Facing.SOUTH, "west left")
	_expect_move(GameTypes.Facing.WEST, GameTypes.BlindAction.RIGHT, Vector2i(2, 1), GameTypes.Facing.NORTH, "west right")
	_expect_move(GameTypes.Facing.WEST, GameTypes.BlindAction.BACK, Vector2i(3, 2), GameTypes.Facing.EAST, "west back")

	var parasol_state := _make_state(Vector2i(2, 2), GameTypes.Facing.NORTH, {Vector2i(2, 1): GameTypes.CollisionType.PARASOL})
	var parasol := BoardManager.resolve_action(parasol_state, GameTypes.BlindAction.FORWARD)
	expect_eq(parasol["collision"], GameTypes.CollisionType.PARASOL, "parasol collision type")
	expect_eq(parasol_state.blind_cell, Vector2i(2, 2), "parasol keeps cell")
	expect_eq(parasol_state.blind_facing, GameTypes.Facing.NORTH, "parasol preserves attempted facing")

	var cooler_state := _make_state(Vector2i(2, 2), GameTypes.Facing.NORTH, {Vector2i(3, 2): GameTypes.CollisionType.COOLER})
	var cooler := BoardManager.resolve_action(cooler_state, GameTypes.BlindAction.RIGHT)
	expect_eq(cooler["collision"], GameTypes.CollisionType.COOLER, "cooler collision type")
	expect_eq(cooler_state.blind_cell, Vector2i(2, 2), "cooler keeps cell")
	expect_eq(cooler_state.blind_facing, GameTypes.Facing.EAST, "cooler still rotates facing")

	var boundary_state := _make_state(Vector2i(0, 0), GameTypes.Facing.NORTH)
	var boundary := BoardManager.resolve_action(boundary_state, GameTypes.BlindAction.FORWARD)
	expect_eq(boundary["collision"], GameTypes.CollisionType.BOUNDARY, "boundary collision type")
	expect_eq(boundary_state.blind_cell, Vector2i(0, 0), "boundary keeps cell")

	var swing_state := _make_state(Vector2i(2, 2), GameTypes.Facing.SOUTH)
	var swing := BoardManager.resolve_action(swing_state, GameTypes.BlindAction.SWING)
	expect_eq(swing["cell_after"], Vector2i(2, 2), "swing does not move")
	expect_eq(swing["facing_after"], GameTypes.Facing.SOUTH, "swing does not rotate")

	return make_result("Movement")
