class_name RoundController
extends RefCounted


const MAX_TURNS := 8

const LEGAL_TRANSITIONS := {
	GameTypes.RoundState.WAITING: [GameTypes.RoundState.ROLE_ASSIGN],
	GameTypes.RoundState.ROLE_ASSIGN: [GameTypes.RoundState.INTRO],
	GameTypes.RoundState.INTRO: [GameTypes.RoundState.SENSOR_UPDATE],
	GameTypes.RoundState.SENSOR_UPDATE: [GameTypes.RoundState.TALK],
	GameTypes.RoundState.TALK: [GameTypes.RoundState.WAIT_ACTION, GameTypes.RoundState.RESOLVE_ACTION, GameTypes.RoundState.RESOLVE_SWING],
	GameTypes.RoundState.WAIT_ACTION: [GameTypes.RoundState.RESOLVE_ACTION, GameTypes.RoundState.RESOLVE_SWING],
	GameTypes.RoundState.RESOLVE_ACTION: [GameTypes.RoundState.SENSOR_UPDATE, GameTypes.RoundState.RESOLVE_SWING],
	GameTypes.RoundState.RESOLVE_SWING: [GameTypes.RoundState.RESULT],
	GameTypes.RoundState.RESULT: [GameTypes.RoundState.REVEAL],
	GameTypes.RoundState.REVEAL: [GameTypes.RoundState.COMPLETE],
	GameTypes.RoundState.COMPLETE: [],
}

var state: int = GameTypes.RoundState.WAITING
var turn: int = 0
var board_state: BoardState
var records: Array = []
var state_history: Array[int] = [GameTypes.RoundState.WAITING]
var previous_turn_cell: Variant = null
var last_swing_success: bool = false


func setup(definition: BoardDefinition) -> void:
	board_state = BoardState.from_definition(definition)
	state = GameTypes.RoundState.WAITING
	turn = 0
	records.clear()
	state_history = [state]
	previous_turn_cell = null
	last_swing_success = false


func change_state(next_state: int) -> bool:
	var allowed: Array = LEGAL_TRANSITIONS.get(state, [])
	if not allowed.has(next_state):
		return false
	state = next_state
	state_history.append(state)
	return true


func start_round() -> bool:
	if board_state == null or state != GameTypes.RoundState.WAITING:
		return false
	turn = 1
	return (
		change_state(GameTypes.RoundState.ROLE_ASSIGN)
		and change_state(GameTypes.RoundState.INTRO)
		and change_state(GameTypes.RoundState.SENSOR_UPDATE)
		and change_state(GameTypes.RoundState.TALK)
	)


func end_talk() -> bool:
	if state != GameTypes.RoundState.TALK:
		return false
	return change_state(GameTypes.RoundState.WAIT_ACTION)


func can_accept_action() -> bool:
	return state == GameTypes.RoundState.TALK or state == GameTypes.RoundState.WAIT_ACTION


func get_sensor_snapshot() -> Dictionary:
	return {
		"side": ObservationEngine.get_side_radar(board_state.blind_cell, board_state.blind_facing, board_state.watermelon_cell),
		"step": ObservationEngine.get_step_echo(previous_turn_cell, board_state.blind_cell, board_state.watermelon_cell),
		"pattern": ObservationEngine.get_pattern_match(board_state.blind_cell, board_state.watermelon_cell, board_state.patterns),
	}


func process_action(action: int) -> Dictionary:
	if not can_accept_action():
		return {"accepted": false, "reason": "state does not accept actions"}
	if action < GameTypes.BlindAction.FORWARD or action > GameTypes.BlindAction.SWING:
		return {"accepted": false, "reason": "invalid action"}

	var sensors := get_sensor_snapshot()
	var record := TurnRecord.new()
	record.turn_number = turn
	record.blind_cell_before = board_state.blind_cell
	record.blind_facing_before = board_state.blind_facing
	record.side_value = int(sensors["side"])
	record.step_value = int(sensors["step"])
	record.pattern_value = int(sensors["pattern"])
	record.action = action

	if action == GameTypes.BlindAction.SWING:
		record.blind_cell_after = board_state.blind_cell
		record.blind_facing_after = board_state.blind_facing
		record.collision = GameTypes.CollisionType.NONE
		records.append(record)
		change_state(GameTypes.RoundState.RESOLVE_SWING)
		last_swing_success = board_state.blind_cell == board_state.watermelon_cell
		change_state(GameTypes.RoundState.RESULT)
		return {"accepted": true, "swing": true, "success": last_swing_success, "record": record}

	change_state(GameTypes.RoundState.RESOLVE_ACTION)
	var resolution := BoardManager.resolve_action(board_state, action)
	record.blind_cell_after = resolution["cell_after"]
	record.blind_facing_after = int(resolution["facing_after"])
	record.collision = int(resolution["collision"])
	records.append(record)
	previous_turn_cell = record.blind_cell_before

	if turn >= MAX_TURNS:
		change_state(GameTypes.RoundState.RESOLVE_SWING)
		last_swing_success = board_state.blind_cell == board_state.watermelon_cell
		change_state(GameTypes.RoundState.RESULT)
		return {"accepted": true, "auto_swing": true, "success": last_swing_success, "record": record}

	turn += 1
	change_state(GameTypes.RoundState.SENSOR_UPDATE)
	change_state(GameTypes.RoundState.TALK)
	return {"accepted": true, "auto_swing": false, "record": record}


func begin_reveal() -> bool:
	if state != GameTypes.RoundState.RESULT:
		return false
	return change_state(GameTypes.RoundState.REVEAL)


func complete_round() -> bool:
	if state != GameTypes.RoundState.REVEAL:
		return false
	return change_state(GameTypes.RoundState.COMPLETE)
