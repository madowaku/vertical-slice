class_name BoardState
extends RefCounted


var board_id: String = ""
var blind_cell: Vector2i = Vector2i.ZERO
var blind_facing: int = GameTypes.Facing.NORTH
var watermelon_cell: Vector2i = Vector2i.ZERO
var obstacles: Dictionary = {}
var patterns: Dictionary = {}


static func from_definition(definition: BoardDefinition) -> BoardState:
	var state := BoardState.new()
	state.board_id = definition.id
	state.blind_cell = definition.blind_start
	state.blind_facing = definition.blind_facing
	state.watermelon_cell = definition.watermelon
	state.obstacles = definition.obstacles.duplicate(true)
	state.patterns = definition.patterns.duplicate(true)
	return state
