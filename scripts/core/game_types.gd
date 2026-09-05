class_name GameTypes
extends RefCounted


# Legacy local-debug selector. Product-facing identity is split into
# PublicRole + GuideSkill + SecretRole below.
enum PlayerRole {
	BLIND,
	GUIDE_SIDE,
	GUIDE_STEP,
	GUIDE_PATTERN,
}

enum PublicRole {
	BLIND,
	GUIDE,
}

enum GuideSkill {
	NONE,
	SIDE,
	STEP,
	PATTERN,
}

enum SecretRole {
	NONE,
	WATERMELON,
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
	STOP,
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
	CONSULT,
	WALKING,
	DECISION,
	RESULT,
	REVEAL,
	COMPLETE,

	# Legacy Phase A/B names kept temporarily so the old debug scene still parses.
	# The v1.2.1 core does not enter these states.
	SENSOR_UPDATE,
	TALK,
	WAIT_ACTION,
	RESOLVE_ACTION,
	RESOLVE_SWING,
}


static func is_player_role_valid(role: int) -> bool:
	return role >= PlayerRole.BLIND and role <= PlayerRole.GUIDE_PATTERN


static func is_guide_player_role(role: int) -> bool:
	return role >= PlayerRole.GUIDE_SIDE and role <= PlayerRole.GUIDE_PATTERN


static func public_role_for_player_role(role: int) -> int:
	match role:
		PlayerRole.BLIND:
			return PublicRole.BLIND
		PlayerRole.GUIDE_SIDE, PlayerRole.GUIDE_STEP, PlayerRole.GUIDE_PATTERN:
			return PublicRole.GUIDE
	return -1


static func guide_skill_for_player_role(role: int) -> int:
	match role:
		PlayerRole.BLIND:
			return GuideSkill.NONE
		PlayerRole.GUIDE_SIDE:
			return GuideSkill.SIDE
		PlayerRole.GUIDE_STEP:
			return GuideSkill.STEP
		PlayerRole.GUIDE_PATTERN:
			return GuideSkill.PATTERN
	return -1


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
