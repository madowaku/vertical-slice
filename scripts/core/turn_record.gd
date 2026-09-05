class_name TurnRecord
extends RefCounted


var step_number: int = 0
var turn_number: int = 0 # Legacy alias for Phase A/B reveal/debug code.
var walk_direction: int = GameTypes.BlindAction.FORWARD
var blind_cell_before: Vector2i = Vector2i.ZERO
var blind_facing_before: int = GameTypes.Facing.NORTH
var side_value: int = GameTypes.SideValue.CENTER
var step_value: int = GameTypes.StepValue.NO_BASELINE
var pattern_value: int = GameTypes.PatternValue.DIFFERENT
var action: int = GameTypes.BlindAction.FORWARD
var blind_cell_after: Vector2i = Vector2i.ZERO
var blind_facing_after: int = GameTypes.Facing.NORTH
var collision: int = GameTypes.CollisionType.NONE
