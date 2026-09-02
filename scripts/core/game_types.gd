class_name GameTypes
extends RefCounted


enum PlayerRole {
	BLIND,
	GUIDE_SIDE,
	GUIDE_STEP,
	GUIDE_PATTERN,
}

enum Facing {
	NORTH,
	EAST,
	SOUTH,
	WEST,
}

enum BlindAction {
	FORWARD,
	LEFT,
	RIGHT,
	BACK,
	SWING,
}

enum CollisionType {
	NONE,
	PARASOL,
	COOLER,
	BOUNDARY,
}

enum SideValue {
	LEFT,
	CENTER,
	RIGHT,
}

enum StepValue {
	NO_BASELINE,
	CLOSER,
	SAME,
	FARTHER,
}

enum PatternValue {
	MATCH,
	DIFFERENT,
}

enum PatternType {
	SHELL,
	STAR,
	CRAB,
}

enum RoundState {
	WAITING,
	ROLE_ASSIGN,
	INTRO,
	SENSOR_UPDATE,
	TALK,
	WAIT_ACTION,
	RESOLVE_ACTION,
	RESOLVE_SWING,
	RESULT,
	REVEAL,
	COMPLETE,
}


static func facing_from_string(value: String) -> int:
	match value.to_upper():
		"NORTH": return Facing.NORTH
		"EAST": return Facing.EAST
		"SOUTH": return Facing.SOUTH
		"WEST": return Facing.WEST
	return -1


static func collision_from_string(value: String) -> int:
	match value.to_upper():
		"PARASOL": return CollisionType.PARASOL
		"COOLER": return CollisionType.COOLER
	return -1


static func pattern_from_string(value: String) -> int:
	match value.to_upper():
		"SHELL": return PatternType.SHELL
		"STAR": return PatternType.STAR
		"CRAB": return PatternType.CRAB
	return -1


static func facing_vector(facing: int) -> Vector2i:
	match facing:
		Facing.NORTH: return Vector2i(0, -1)
		Facing.EAST: return Vector2i(1, 0)
		Facing.SOUTH: return Vector2i(0, 1)
		Facing.WEST: return Vector2i(-1, 0)
	return Vector2i.ZERO


static func right_vector(facing: int) -> Vector2i:
	match facing:
		Facing.NORTH: return Vector2i(1, 0)
		Facing.EAST: return Vector2i(0, 1)
		Facing.SOUTH: return Vector2i(-1, 0)
		Facing.WEST: return Vector2i(0, -1)
	return Vector2i.ZERO


static func rotated_facing(facing: int, action: int) -> int:
	match action:
		BlindAction.LEFT:
			return (facing + 3) % 4
		BlindAction.RIGHT:
			return (facing + 1) % 4
		BlindAction.BACK:
			return (facing + 2) % 4
		_:
			return facing
