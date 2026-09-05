class_name LocalDebugSession
extends RefCounted


const FIRST_BOARD := 1
const LAST_BOARD := 12

var current_role: int = GameTypes.PlayerRole.BLIND
var board_index: int = FIRST_BOARD
var round_controller: RoundController = RoundController.new()
var sensor_histories: Dictionary = {}
var action_history: Array[int] = []


func start_round(requested_board_index: int = FIRST_BOARD) -> bool:
	board_index = clampi(requested_board_index, FIRST_BOARD, LAST_BOARD)
	var definition := BoardManager.load_board(BoardManager.preset_path(board_index))
	if definition == null or not BoardManager.validate_definition(definition).is_empty():
		return false

	round_controller.setup(definition)
	sensor_histories = {
		"side": [],
		"step": [],
		"pattern": [],
	}
	action_history.clear()
	if not round_controller.start_round():
		return false
	_capture_current_sensors()
	return true


func set_role(role: int) -> bool:
	if role < GameTypes.PlayerRole.BLIND or role > GameTypes.PlayerRole.GUIDE_PATTERN:
		return false
	current_role = role
	return true


func process_action(action: int) -> Dictionary:
	var result := round_controller.process_action(action)
	if not bool(result.get("accepted", false)):
		return result
	if bool(result.get("step", false)):
		var record: TurnRecord = result["record"]
		action_history.append(record.action)
		_capture_current_sensors()
	elif bool(result.get("swing", false)):
		action_history.append(GameTypes.BlindAction.SWING)
	return result


func begin_walk(direction: int) -> Dictionary:
	return round_controller.begin_walk(direction)


func advance_step() -> Dictionary:
	var result := round_controller.advance_step()
	if bool(result.get("accepted", false)) and bool(result.get("step", false)):
		var record: TurnRecord = result["record"]
		action_history.append(record.action)
		_capture_current_sensors()
	return result


func stop_walk() -> Dictionary:
	return round_controller.stop_walk()


func request_swing() -> Dictionary:
	return round_controller.request_swing()


func continue_after_decision() -> Dictionary:
	return round_controller.continue_after_decision()


func confirm_swing() -> Dictionary:
	var result := round_controller.confirm_swing()
	if bool(result.get("accepted", false)) and bool(result.get("swing", false)):
		action_history.append(GameTypes.BlindAction.SWING)
	return result


func begin_reveal() -> bool:
	return round_controller.begin_reveal()


func complete_round() -> bool:
	return round_controller.complete_round()


func rematch(requested_board_index: int = -1) -> bool:
	var next_index := requested_board_index
	if next_index < FIRST_BOARD or next_index > LAST_BOARD:
		next_index = board_index % LAST_BOARD + 1
	return start_round(next_index)


func get_projection(role: int = -1) -> Dictionary:
	var resolved_role := current_role if role < 0 else role
	var common := {
		"role": resolved_role,
		"turn": round_controller.turn,
		"steps_taken": round_controller.steps_taken,
		"steps_remaining": round_controller.steps_remaining,
		"state": round_controller.state,
		"can_act": round_controller.can_accept_action(),
		"can_choose_direction": round_controller.can_choose_direction(),
		"can_stop": round_controller.can_stop(),
		"can_confirm_swing": round_controller.can_confirm_swing(),
		"result_known": round_controller.state >= GameTypes.RoundState.RESULT and round_controller.state <= GameTypes.RoundState.COMPLETE,
		"success": round_controller.last_swing_success if round_controller.state >= GameTypes.RoundState.RESULT and round_controller.state <= GameTypes.RoundState.COMPLETE else false,
	}

	if resolved_role == GameTypes.PlayerRole.BLIND:
		common["facing"] = round_controller.board_state.blind_facing
		common["action_history"] = action_history.duplicate()
		return common

	if resolved_role < GameTypes.PlayerRole.GUIDE_SIDE or resolved_role > GameTypes.PlayerRole.GUIDE_PATTERN:
		return {}

	common["board"] = _safe_guide_board()
	match resolved_role:
		GameTypes.PlayerRole.GUIDE_SIDE:
			common["sensor"] = _sensor_projection("side")
		GameTypes.PlayerRole.GUIDE_STEP:
			common["sensor"] = _sensor_projection("step")
		GameTypes.PlayerRole.GUIDE_PATTERN:
			common["sensor"] = _sensor_projection("pattern")
	return common


func get_reveal_projection() -> Dictionary:
	if round_controller.state != GameTypes.RoundState.REVEAL and round_controller.state != GameTypes.RoundState.COMPLETE:
		return {}
	var records: Array[Dictionary] = []
	for record_variant in round_controller.records:
		var record: TurnRecord = record_variant
		records.append({
			"step": record.step_number,
			"turn": record.turn_number,
			"cell_before": _cell_array(record.blind_cell_before),
			"facing_before": record.blind_facing_before,
			"side": record.side_value,
			"step_sensor": record.step_value,
			"pattern": record.pattern_value,
			"action": record.action,
			"walk_direction": record.walk_direction,
			"cell_after": _cell_array(record.blind_cell_after),
			"facing_after": record.blind_facing_after,
			"collision": record.collision,
		})
	return {
		"board_index": board_index,
		"turn": round_controller.turn,
		"steps_taken": round_controller.steps_taken,
		"steps_remaining": round_controller.steps_remaining,
		"success": round_controller.last_swing_success,
		"board": _safe_guide_board(),
		"watermelon_cell": _cell_array(round_controller.board_state.watermelon_cell),
		"records": records,
		"sensor_histories": {
			"side": sensor_histories["side"].duplicate(true),
			"step": sensor_histories["step"].duplicate(true),
			"pattern": sensor_histories["pattern"].duplicate(true),
		},
	}


func _capture_current_sensors() -> void:
	var snapshot := round_controller.get_sensor_snapshot()
	_append_sensor("side", int(snapshot["side"]))
	_append_sensor("step", int(snapshot["step"]))
	_append_sensor("pattern", int(snapshot["pattern"]))


func _append_sensor(kind: String, value: int) -> void:
	var history: Array = sensor_histories[kind]
	if not history.is_empty() and int(history[-1]["step"]) == round_controller.steps_taken:
		return
	history.append({
		"step": round_controller.steps_taken,
		"turn": round_controller.steps_taken,
		"value": value,
	})
	sensor_histories[kind] = history


func _sensor_projection(kind: String) -> Dictionary:
	var history: Array = sensor_histories[kind]
	var current_value := -1
	if not history.is_empty():
		current_value = int(history[-1]["value"])
	return {
		"kind": kind,
		"value": current_value,
		"history": history.duplicate(true),
	}


func _safe_guide_board() -> Dictionary:
	var obstacle_entries: Array[Dictionary] = []
	for cell_variant in round_controller.board_state.obstacles.keys():
		var cell: Vector2i = cell_variant
		obstacle_entries.append({
			"cell": _cell_array(cell),
			"type": int(round_controller.board_state.obstacles[cell]),
		})
	obstacle_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac: Array = a["cell"]
		var bc: Array = b["cell"]
		return int(ac[1]) * BoardManager.WIDTH + int(ac[0]) < int(bc[1]) * BoardManager.WIDTH + int(bc[0])
	)

	var pattern_values: Array[int] = []
	for y in range(BoardManager.HEIGHT):
		for x in range(BoardManager.WIDTH):
			pattern_values.append(int(round_controller.board_state.patterns[Vector2i(x, y)]))

	return {
		"board_index": board_index,
		"blind_cell": _cell_array(round_controller.board_state.blind_cell),
		"blind_facing": round_controller.board_state.blind_facing,
		"obstacles": obstacle_entries,
		"patterns": pattern_values,
	}


static func _cell_array(cell: Vector2i) -> Array[int]:
	return [cell.x, cell.y]
