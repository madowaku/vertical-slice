class_name RoundController
extends RefCounted


const MAX_STEPS := 8

var state: int = GameTypes.RoundState.WAITING
var turn: int = 0 # Legacy 1-based display slot for the Phase B debug scene.
var steps_remaining: int = MAX_STEPS
var steps_taken: int = 0
var board_state: BoardState
var records: Array = []
var state_history: Array[int] = [GameTypes.RoundState.WAITING]
var previous_step_cell: Variant = null
var last_swing_success: bool = false
var active_walk_action: int = -1
var walk_has_stepped: bool = false


func setup(definition: BoardDefinition) -> void:
	board_state = BoardState.from_definition(definition)
	state = GameTypes.RoundState.WAITING
	turn = 0
	steps_remaining = MAX_STEPS
	steps_taken = 0
	records.clear()
	state_history = [state]
	previous_step_cell = null
	last_swing_success = false
	active_walk_action = -1
	walk_has_stepped = false


func change_state(next_state: int) -> bool:
	if not _is_transition_legal(next_state):
		return false
	state = next_state
	state_history.append(state)
	return true


func _is_transition_legal(next_state: int) -> bool:
	match state:
		GameTypes.RoundState.WAITING:
			return next_state == GameTypes.RoundState.ROLE_ASSIGN
		GameTypes.RoundState.ROLE_ASSIGN:
			return next_state == GameTypes.RoundState.INTRO
		GameTypes.RoundState.INTRO:
			return next_state == GameTypes.RoundState.CONSULT
		GameTypes.RoundState.CONSULT:
			return next_state in [GameTypes.RoundState.WALKING, GameTypes.RoundState.DECISION]
		GameTypes.RoundState.WALKING:
			return next_state in [GameTypes.RoundState.CONSULT, GameTypes.RoundState.DECISION]
		GameTypes.RoundState.DECISION:
			return next_state in [GameTypes.RoundState.CONSULT, GameTypes.RoundState.RESULT]
		GameTypes.RoundState.RESULT:
			return next_state == GameTypes.RoundState.REVEAL
		GameTypes.RoundState.REVEAL:
			return next_state == GameTypes.RoundState.COMPLETE
	return false


func start_round() -> bool:
	if board_state == null or state != GameTypes.RoundState.WAITING:
		return false
	turn = 1
	return (
		change_state(GameTypes.RoundState.ROLE_ASSIGN)
		and change_state(GameTypes.RoundState.INTRO)
		and change_state(GameTypes.RoundState.CONSULT)
	)


func can_choose_direction() -> bool:
	return state == GameTypes.RoundState.CONSULT and steps_remaining > 0


func can_stop() -> bool:
	return state == GameTypes.RoundState.WALKING


func can_request_swing() -> bool:
	return state == GameTypes.RoundState.CONSULT


func can_confirm_swing() -> bool:
	return state == GameTypes.RoundState.DECISION


func can_continue_after_decision() -> bool:
	return state == GameTypes.RoundState.DECISION and steps_remaining > 0


func can_accept_action() -> bool:
	# Compatibility helper for the Phase B debug scene. Product UI should use
	# can_choose_direction/can_stop/can_confirm_swing explicitly.
	return state in [GameTypes.RoundState.CONSULT, GameTypes.RoundState.DECISION]


func get_sensor_snapshot() -> Dictionary:
	return {
		"side": ObservationEngine.get_side_radar(board_state.blind_cell, board_state.blind_facing, board_state.watermelon_cell),
		"step": ObservationEngine.get_step_echo(previous_step_cell, board_state.blind_cell, board_state.watermelon_cell),
		"pattern": ObservationEngine.get_pattern_match(board_state.blind_cell, board_state.watermelon_cell, board_state.patterns),
	}


func begin_walk(direction: int) -> Dictionary:
	if not can_choose_direction():
		return {"accepted": false, "reason": "cannot begin walk in current state"}
	if direction < GameTypes.BlindAction.FORWARD or direction > GameTypes.BlindAction.BACK:
		return {"accepted": false, "reason": "invalid walk direction"}

	active_walk_action = direction
	walk_has_stepped = false
	change_state(GameTypes.RoundState.WALKING)
	return {
		"accepted": true,
		"walking": true,
		"direction": direction,
		"steps_remaining": steps_remaining,
	}


func advance_step() -> Dictionary:
	if state != GameTypes.RoundState.WALKING:
		return {"accepted": false, "reason": "not walking"}
	if steps_remaining <= 0:
		return {"accepted": false, "reason": "step budget exhausted"}
	if active_walk_action < GameTypes.BlindAction.FORWARD or active_walk_action > GameTypes.BlindAction.BACK:
		return {"accepted": false, "reason": "no active walk direction"}

	var cell_before := board_state.blind_cell
	var facing_before := board_state.blind_facing
	var step_action := active_walk_action if not walk_has_stepped else GameTypes.BlindAction.FORWARD
	var resolution := BoardManager.resolve_action(board_state, step_action)

	previous_step_cell = cell_before
	steps_taken += 1
	steps_remaining -= 1
	turn = mini(steps_taken + 1, MAX_STEPS)
	walk_has_stepped = true

	var sensors := get_sensor_snapshot()
	var record := TurnRecord.new()
	record.step_number = steps_taken
	record.turn_number = steps_taken
	record.walk_direction = active_walk_action
	record.blind_cell_before = cell_before
	record.blind_facing_before = facing_before
	record.side_value = int(sensors["side"])
	record.step_value = int(sensors["step"])
	record.pattern_value = int(sensors["pattern"])
	record.action = step_action
	record.blind_cell_after = resolution["cell_after"]
	record.blind_facing_after = int(resolution["facing_after"])
	record.collision = int(resolution["collision"])
	records.append(record)

	var auto_stop := false
	var stop_reason := ""
	if steps_remaining <= 0:
		auto_stop = true
		stop_reason = "budget"
		_clear_walk()
		change_state(GameTypes.RoundState.DECISION)
	elif record.collision != GameTypes.CollisionType.NONE:
		auto_stop = true
		stop_reason = "bump"
		_clear_walk()
		change_state(GameTypes.RoundState.CONSULT)

	return {
		"accepted": true,
		"step": true,
		"record": record,
		"steps_taken": steps_taken,
		"steps_remaining": steps_remaining,
		"auto_stop": auto_stop,
		"stop_reason": stop_reason,
		"state": state,
	}


func stop_walk() -> Dictionary:
	if not can_stop():
		return {"accepted": false, "reason": "not walking"}
	_clear_walk()
	change_state(GameTypes.RoundState.CONSULT)
	return {
		"accepted": true,
		"stopped": true,
		"steps_remaining": steps_remaining,
	}


func request_swing() -> Dictionary:
	if not can_request_swing():
		return {"accepted": false, "reason": "cannot request swing in current state"}
	change_state(GameTypes.RoundState.DECISION)
	return {
		"accepted": true,
		"decision": true,
		"steps_remaining": steps_remaining,
	}


func continue_after_decision() -> Dictionary:
	if not can_continue_after_decision():
		return {"accepted": false, "reason": "cannot continue after decision"}
	change_state(GameTypes.RoundState.CONSULT)
	return {
		"accepted": true,
		"continued": true,
		"steps_remaining": steps_remaining,
	}


func confirm_swing() -> Dictionary:
	if not can_confirm_swing():
		return {"accepted": false, "reason": "not in swing decision"}
	last_swing_success = board_state.blind_cell == board_state.watermelon_cell
	change_state(GameTypes.RoundState.RESULT)
	return {
		"accepted": true,
		"swing": true,
		"success": last_swing_success,
		"steps_taken": steps_taken,
		"steps_remaining": steps_remaining,
	}


func process_action(action: int) -> Dictionary:
	# Transitional one-button compatibility for the Phase B debug slice.
	# Direction presses perform exactly one beat and then stop; the real v1.2.1
	# loop should call begin_walk(), advance_step() repeatedly, and stop_walk().
	if action == GameTypes.BlindAction.STOP:
		return stop_walk()

	if action == GameTypes.BlindAction.SWING:
		if state == GameTypes.RoundState.CONSULT:
			return request_swing()
		if state == GameTypes.RoundState.DECISION:
			return confirm_swing()
		return {"accepted": false, "reason": "swing unavailable in current state"}

	if action < GameTypes.BlindAction.FORWARD or action > GameTypes.BlindAction.BACK:
		return {"accepted": false, "reason": "invalid action"}

	var begin_result := begin_walk(action)
	if not bool(begin_result.get("accepted", false)):
		return begin_result
	var step_result := advance_step()
	if not bool(step_result.get("accepted", false)):
		return step_result
	if state == GameTypes.RoundState.WALKING:
		stop_walk()
	step_result["legacy_single_step"] = true
	step_result["state"] = state
	return step_result


func begin_reveal() -> bool:
	if state != GameTypes.RoundState.RESULT:
		return false
	return change_state(GameTypes.RoundState.REVEAL)


func complete_round() -> bool:
	if state != GameTypes.RoundState.REVEAL:
		return false
	return change_state(GameTypes.RoundState.COMPLETE)


func _clear_walk() -> void:
	active_walk_action = -1
	walk_has_stepped = false
