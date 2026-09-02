class_name BoardManager
extends RefCounted


const WIDTH := 6
const HEIGHT := 6
const MAX_TURNS := 8


static func load_board(path: String) -> BoardDefinition:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return null
	return BoardDefinition.from_dict(parsed)


static func preset_path(index: int) -> String:
	return "res://data/boards/slice_board_%02d.json" % index


static func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT


static func validate_definition(definition: BoardDefinition) -> Array[String]:
	var errors: Array[String] = []
	if definition == null:
		errors.append("definition is null")
		return errors

	if definition.id.is_empty():
		errors.append("id is empty")
	if not is_inside(definition.blind_start):
		errors.append("blind start outside board")
	if not is_inside(definition.watermelon):
		errors.append("watermelon outside board")
	if definition.blind_start == definition.watermelon:
		errors.append("watermelon overlaps blind start")
	if definition.blind_facing < GameTypes.Facing.NORTH or definition.blind_facing > GameTypes.Facing.WEST:
		errors.append("invalid blind facing")
	if definition.obstacle_entry_count != definition.obstacles.size():
		errors.append("duplicate obstacle cell")

	for cell_variant in definition.obstacles.keys():
		var cell: Vector2i = cell_variant
		if not is_inside(cell):
			errors.append("obstacle outside board")
		if cell == definition.blind_start:
			errors.append("obstacle overlaps blind start")
		if cell == definition.watermelon:
			errors.append("obstacle overlaps watermelon")
		var collision: int = int(definition.obstacles[cell])
		if collision != GameTypes.CollisionType.PARASOL and collision != GameTypes.CollisionType.COOLER:
			errors.append("invalid obstacle type")

	if definition.patterns.size() != WIDTH * HEIGHT:
		errors.append("pattern cell count must be 36")
	else:
		var seen_patterns := {
			GameTypes.PatternType.SHELL: false,
			GameTypes.PatternType.STAR: false,
			GameTypes.PatternType.CRAB: false,
		}
		for y in range(HEIGHT):
			for x in range(WIDTH):
				var cell := Vector2i(x, y)
				if not definition.patterns.has(cell):
					errors.append("missing pattern cell")
					continue
				var pattern: int = int(definition.patterns[cell])
				if not seen_patterns.has(pattern):
					errors.append("invalid pattern type")
				else:
					seen_patterns[pattern] = true
		for pattern_seen in seen_patterns.values():
			if not pattern_seen:
				errors.append("all three pattern types must be present")
				break

	if errors.is_empty():
		var distance := shortest_path_distance(definition.blind_start, definition.watermelon, definition.obstacles)
		if distance < 0:
			errors.append("watermelon unreachable")
		elif distance < 3 or distance > 6:
			errors.append("shortest path must be 3 to 6 moves")
		elif distance > MAX_TURNS:
			errors.append("watermelon exceeds turn budget")
	return errors


static func shortest_path_distance(start: Vector2i, goal: Vector2i, obstacles: Dictionary) -> int:
	if start == goal:
		return 0
	var queue: Array = [start]
	var distances := {start: 0}
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = int(distances[current])
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := current + direction
			if not is_inside(next) or obstacles.has(next) or distances.has(next):
				continue
			if next == goal:
				return current_distance + 1
			distances[next] = current_distance + 1
			queue.append(next)
	return -1


static func resolve_action(state: BoardState, action: int) -> Dictionary:
	var cell_before := state.blind_cell
	var facing_before := state.blind_facing
	var facing_after := GameTypes.rotated_facing(facing_before, action)
	state.blind_facing = facing_after

	if action == GameTypes.BlindAction.SWING:
		return {
			"cell_before": cell_before,
			"facing_before": facing_before,
			"cell_after": state.blind_cell,
			"facing_after": state.blind_facing,
			"collision": GameTypes.CollisionType.NONE,
		}

	var target := cell_before + GameTypes.facing_vector(facing_after)
	var collision := GameTypes.CollisionType.NONE
	if not is_inside(target):
		collision = GameTypes.CollisionType.BOUNDARY
	elif state.obstacles.has(target):
		collision = int(state.obstacles[target])
	else:
		state.blind_cell = target

	return {
		"cell_before": cell_before,
		"facing_before": facing_before,
		"cell_after": state.blind_cell,
		"facing_after": state.blind_facing,
		"collision": collision,
	}
