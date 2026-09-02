class_name BoardDefinition
extends RefCounted


var id: String = ""
var blind_start: Vector2i = Vector2i.ZERO
var blind_facing: int = -1
var watermelon: Vector2i = Vector2i.ZERO
var obstacles: Dictionary = {}
var patterns: Dictionary = {}
var obstacle_entry_count: int = 0
var difficulty_note: String = ""
var expected_turn: String = ""


static func from_dict(data: Dictionary) -> BoardDefinition:
	var definition := BoardDefinition.new()
	definition.id = str(data.get("id", ""))

	var blind_start_data: Array = data.get("blind_start", [])
	if blind_start_data.size() == 2:
		definition.blind_start = Vector2i(int(blind_start_data[0]), int(blind_start_data[1]))

	definition.blind_facing = GameTypes.facing_from_string(str(data.get("blind_facing", "")))

	var watermelon_data: Array = data.get("watermelon", [])
	if watermelon_data.size() == 2:
		definition.watermelon = Vector2i(int(watermelon_data[0]), int(watermelon_data[1]))

	var obstacle_data: Array = data.get("obstacles", [])
	definition.obstacle_entry_count = obstacle_data.size()
	for obstacle_variant in obstacle_data:
		if not obstacle_variant is Dictionary:
			continue
		var obstacle: Dictionary = obstacle_variant
		var cell_data: Array = obstacle.get("cell", [])
		if cell_data.size() != 2:
			continue
		var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
		definition.obstacles[cell] = GameTypes.collision_from_string(str(obstacle.get("type", "")))

	var pattern_data: Array = data.get("patterns", [])
	for index in range(pattern_data.size()):
		var cell := Vector2i(index % 6, index / 6)
		definition.patterns[cell] = GameTypes.pattern_from_string(str(pattern_data[index]))

	definition.difficulty_note = str(data.get("difficulty_note", ""))
	definition.expected_turn = str(data.get("expected_turn", ""))
	return definition
