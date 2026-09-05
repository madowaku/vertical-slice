extends Control


var session: LocalDebugSession = LocalDebugSession.new()
var round_started := false
var debug_visible := false

var board_selector: OptionButton
var start_button: Button
var role_label: Label
var status_label: Label
var privacy_label: Label
var sensor_label: Label
var sensor_history_label: Label
var action_history_label: Label
var reveal_label: Label
var result_label: Label
var debug_label: Label
var reveal_button: Button
var rematch_button: Button
var role_buttons: Dictionary = {}
var direction_buttons: Dictionary = {}
var step_button: Button
var stop_button: Button
var request_swing_button: Button
var confirm_swing_button: Button
var continue_button: Button


func _ready() -> void:
	_build_ui()
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			_on_role_pressed(GameTypes.PlayerRole.BLIND)
		KEY_F2:
			_on_role_pressed(GameTypes.PlayerRole.GUIDE_SIDE)
		KEY_F3:
			_on_role_pressed(GameTypes.PlayerRole.GUIDE_STEP)
		KEY_F4:
			_on_role_pressed(GameTypes.PlayerRole.GUIDE_PATTERN)
		KEY_F10:
			debug_visible = not debug_visible
			_refresh_debug()
		_:
			return
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)

	var title := Label.new()
	title.text = "SUIKAWARI  /  v1.2.1 C2 ROLE-SAFE DEBUG"
	title.add_theme_font_size_override("font_size", 26)
	page.add_child(title)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	page.add_child(controls)

	board_selector = OptionButton.new()
	board_selector.custom_minimum_size = Vector2(140, 40)
	for index in range(1, 13):
		board_selector.add_item("Board %02d" % index, index)
	controls.add_child(board_selector)

	start_button = Button.new()
	start_button.text = "START ROUND"
	start_button.custom_minimum_size = Vector2(150, 40)
	start_button.pressed.connect(_on_start_pressed)
	controls.add_child(start_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)

	for role in [
		GameTypes.PlayerRole.BLIND,
		GameTypes.PlayerRole.GUIDE_SIDE,
		GameTypes.PlayerRole.GUIDE_STEP,
		GameTypes.PlayerRole.GUIDE_PATTERN,
	]:
		var role_button := Button.new()
		role_button.text = _role_shortcut_text(role)
		role_button.custom_minimum_size = Vector2(112, 40)
		role_button.pressed.connect(_on_role_pressed.bind(role))
		controls.add_child(role_button)
		role_buttons[role] = role_button

	role_label = Label.new()
	role_label.add_theme_font_size_override("font_size", 22)
	page.add_child(role_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	page.add_child(status_label)

	privacy_label = Label.new()
	privacy_label.custom_minimum_size = Vector2(0, 110)
	privacy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	privacy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	privacy_label.add_theme_font_size_override("font_size", 20)
	page.add_child(privacy_label)

	var info_row := HBoxContainer.new()
	info_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_row.add_theme_constant_override("separation", 16)
	page.add_child(info_row)

	var sensor_panel := VBoxContainer.new()
	sensor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(sensor_panel)

	var sensor_heading := Label.new()
	sensor_heading.text = "YOUR PRIVATE SENSOR"
	sensor_heading.add_theme_font_size_override("font_size", 16)
	sensor_panel.add_child(sensor_heading)

	sensor_label = Label.new()
	sensor_label.custom_minimum_size = Vector2(0, 92)
	sensor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sensor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sensor_label.add_theme_font_size_override("font_size", 26)
	sensor_panel.add_child(sensor_label)

	sensor_history_label = Label.new()
	sensor_history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sensor_panel.add_child(sensor_history_label)

	var public_panel := VBoxContainer.new()
	public_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(public_panel)

	var public_heading := Label.new()
	public_heading.text = "PUBLIC ACTION HISTORY"
	public_heading.add_theme_font_size_override("font_size", 16)
	public_panel.add_child(public_heading)

	action_history_label = Label.new()
	action_history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_history_label.add_theme_font_size_override("font_size", 18)
	public_panel.add_child(action_history_label)

	reveal_label = Label.new()
	reveal_label.visible = false
	reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reveal_label.add_theme_font_size_override("font_size", 14)
	public_panel.add_child(reveal_label)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 24)
	page.add_child(result_label)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	page.add_child(action_row)

	for action in [
		GameTypes.BlindAction.LEFT,
		GameTypes.BlindAction.FORWARD,
		GameTypes.BlindAction.RIGHT,
		GameTypes.BlindAction.BACK,
	]:
		var button := Button.new()
		button.text = _action_name(action)
		button.custom_minimum_size = Vector2(125, 44)
		button.pressed.connect(_on_begin_walk.bind(action))
		action_row.add_child(button)
		direction_buttons[action] = button

	step_button = Button.new()
	step_button.text = "STEP BEAT"
	step_button.custom_minimum_size = Vector2(135, 44)
	step_button.pressed.connect(_on_step_pressed)
	action_row.add_child(step_button)

	stop_button = Button.new()
	stop_button.text = "STOP"
	stop_button.custom_minimum_size = Vector2(135, 44)
	stop_button.pressed.connect(_on_stop_pressed)
	action_row.add_child(stop_button)

	request_swing_button = Button.new()
	request_swing_button.text = "SWING?"
	request_swing_button.custom_minimum_size = Vector2(135, 44)
	request_swing_button.pressed.connect(_on_request_swing)
	action_row.add_child(request_swing_button)

	confirm_swing_button = Button.new()
	confirm_swing_button.text = "SWING!"
	confirm_swing_button.custom_minimum_size = Vector2(135, 44)
	confirm_swing_button.pressed.connect(_on_confirm_swing)
	action_row.add_child(confirm_swing_button)

	continue_button = Button.new()
	continue_button.text = "KEEP CHECKING"
	continue_button.custom_minimum_size = Vector2(150, 44)
	continue_button.pressed.connect(_on_continue_pressed)
	action_row.add_child(continue_button)

	var result_controls := HBoxContainer.new()
	result_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	result_controls.add_theme_constant_override("separation", 8)
	page.add_child(result_controls)

	reveal_button = Button.new()
	reveal_button.text = "REVEAL FULL TRUTH"
	reveal_button.custom_minimum_size = Vector2(180, 44)
	reveal_button.pressed.connect(_on_reveal_pressed)
	result_controls.add_child(reveal_button)

	rematch_button = Button.new()
	rematch_button.text = "REMATCH / NEXT BOARD"
	rematch_button.custom_minimum_size = Vector2(200, 44)
	rematch_button.pressed.connect(_on_rematch_pressed)
	result_controls.add_child(rematch_button)

	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 13)
	page.add_child(debug_label)

	var help := Label.new()
	help.text = "F1 Blind   F2 Side   F3 Step   F4 Pattern   F10 safe debug summary"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(help)


func _on_start_pressed() -> void:
	round_started = session.start_round(board_selector.get_selected_id())
	_refresh()


func _on_role_pressed(role: int) -> void:
	if session.set_role(role):
		_refresh()


func _on_begin_walk(action: int) -> void:
	if _blind_controls_allowed():
		session.begin_walk(action)
		_refresh()


func _on_step_pressed() -> void:
	if _blind_controls_allowed():
		session.advance_step()
		_refresh()


func _on_stop_pressed() -> void:
	if _blind_controls_allowed():
		session.stop_walk()
		_refresh()


func _on_request_swing() -> void:
	if _blind_controls_allowed():
		session.request_swing()
		_refresh()


func _on_confirm_swing() -> void:
	if _blind_controls_allowed():
		session.confirm_swing()
		_refresh()


func _on_continue_pressed() -> void:
	if _blind_controls_allowed():
		session.continue_after_decision()
		_refresh()


func _on_reveal_pressed() -> void:
	if session.begin_reveal():
		_refresh()


func _on_rematch_pressed() -> void:
	if not round_started:
		return
	if session.rematch():
		board_selector.select(session.board_index - 1)
		_refresh()


func _blind_controls_allowed() -> bool:
	return round_started and session.current_role == GameTypes.PlayerRole.BLIND


func _refresh() -> void:
	for role_variant in role_buttons.keys():
		var role := int(role_variant)
		var button: Button = role_buttons[role_variant]
		button.disabled = role == session.current_role

	if not round_started:
		role_label.text = "ROLE: BLIND  [no active round]"
		status_label.text = "Choose a preset board and press START ROUND."
		privacy_label.text = "C2 privacy boundary active. Active-role projections contain no hidden board truth."
		sensor_label.text = "NO ROUND"
		sensor_history_label.text = ""
		action_history_label.text = ""
		reveal_label.visible = false
		result_label.text = ""
		_set_all_action_buttons_hidden()
		reveal_button.visible = false
		rematch_button.visible = false
		start_button.disabled = false
		_refresh_debug()
		return

	var projection := session.get_projection()
	var state := int(projection["state"])
	role_label.text = "ROLE: %s" % _role_name(session.current_role)
	status_label.text = "Board %02d   |   Steps %d / 8   |   Remaining %d   |   State: %s" % [
		session.board_index,
		int(projection["steps_taken"]),
		int(projection["steps_remaining"]),
		_state_name(state),
	]
	start_button.disabled = state < GameTypes.RoundState.RESULT

	if state == GameTypes.RoundState.REVEAL or state == GameTypes.RoundState.COMPLETE:
		_render_reveal(session.get_reveal_projection())
	else:
		_render_active_role(projection)

	if bool(projection.get("result_known", false)):
		result_label.text = "SMASHED!" if bool(projection.get("success", false)) else "MISSED!"
	else:
		result_label.text = ""

	reveal_button.visible = state == GameTypes.RoundState.RESULT
	rematch_button.visible = state == GameTypes.RoundState.REVEAL or state == GameTypes.RoundState.COMPLETE
	_refresh_action_buttons(projection)
	_refresh_debug()


func _render_active_role(projection: Dictionary) -> void:
	reveal_label.visible = false
	action_history_label.text = _action_history_text(projection["action_history"])

	if session.current_role == GameTypes.PlayerRole.BLIND:
		privacy_label.text = "BLINDFOLD ACTIVE\nBoard, absolute position, absolute facing, obstacles, patterns, and Guide sensors are NOT in this projection."
		sensor_label.text = "NO SENSOR\nListen to the Guides"
		sensor_history_label.text = "Relative walk choice is visible only because the Blind selected it.\nAbsolute facing remains hidden."
		if int(projection.get("walk_direction", -1)) >= 0:
			sensor_history_label.text += "\nWalking choice: %s" % _action_name(int(projection["walk_direction"]))
		return

	privacy_label.text = "GUIDE PRIVACY\nFull board, Blind cell/facing, obstacles, patterns, watermelon position, and other Guide sensors are NOT in this projection."
	var sensor: Dictionary = projection["sensor"]
	sensor_label.text = "%s\n%s" % [
		_sensor_title(str(sensor["kind"])),
		_sensor_value_text(str(sensor["kind"]), int(sensor["value"])),
	]
	sensor_history_label.text = _sensor_history_text(sensor)


func _render_reveal(reveal: Dictionary) -> void:
	privacy_label.text = "REVEAL\nThe round is over. Full board truth and all sensor histories are now intentionally available."
	sensor_label.text = "REVEAL\n%s" % ("SMASHED" if bool(reveal["success"]) else "MISSED")
	var histories: Dictionary = reveal["sensor_histories"]
	var lines: Array[String] = []
	for kind in ["side", "step", "pattern"]:
		lines.append(_sensor_title(kind))
		for entry_variant in histories[kind]:
			var entry: Dictionary = entry_variant
			lines.append("  S%d  %s" % [int(entry["step"]), _sensor_value_text(kind, int(entry["value"]))])
	sensor_history_label.text = "\n".join(lines)
	action_history_label.text = "Steps taken: %d\nRemaining: %d" % [int(reveal["steps_taken"]), int(reveal["steps_remaining"])]
	reveal_label.text = _reveal_board_text(reveal)
	reveal_label.visible = true


func _refresh_action_buttons(projection: Dictionary) -> void:
	_set_all_action_buttons_hidden()
	if session.current_role != GameTypes.PlayerRole.BLIND:
		return

	if bool(projection.get("can_choose_direction", false)):
		for button_variant in direction_buttons.values():
			var button: Button = button_variant
			button.visible = true
		request_swing_button.visible = bool(projection.get("can_request_swing", false))
		return

	if bool(projection.get("can_stop", false)):
		step_button.visible = true
		stop_button.visible = true
		return

	if bool(projection.get("can_confirm_swing", false)):
		confirm_swing_button.visible = true
		continue_button.visible = bool(projection.get("can_continue_after_decision", false))


func _set_all_action_buttons_hidden() -> void:
	for button_variant in direction_buttons.values():
		var button: Button = button_variant
		button.visible = false
	step_button.visible = false
	stop_button.visible = false
	request_swing_button.visible = false
	confirm_swing_button.visible = false
	continue_button.visible = false


func _refresh_debug() -> void:
	debug_label.visible = debug_visible
	if not debug_visible:
		debug_label.text = ""
		return
	if not round_started:
		debug_label.text = "DEBUG | no round | no secret state displayed"
		return
	debug_label.text = "DEBUG | board preset=%02d state=%s steps=%d remaining=%d role=%s | secret positions omitted" % [
		session.board_index,
		_state_name(session.round_controller.state),
		session.round_controller.steps_taken,
		session.round_controller.steps_remaining,
		_role_name(session.current_role),
	]


func _sensor_history_text(sensor: Dictionary) -> String:
	var lines: Array[String] = []
	var kind := str(sensor["kind"])
	for entry_variant in sensor["history"]:
		var entry: Dictionary = entry_variant
		lines.append("S%d   %s" % [int(entry["step"]), _sensor_value_text(kind, int(entry["value"]))])
	return "\n".join(lines)


func _action_history_text(history: Array) -> String:
	if history.is_empty():
		return "(none yet)"
	var names: Array[String] = []
	for action_variant in history:
		names.append(_action_name(int(action_variant)))
	return " > ".join(names)


func _reveal_board_text(reveal: Dictionary) -> String:
	var board: Dictionary = reveal["board"]
	var obstacle_by_cell: Dictionary = {}
	for obstacle_variant in board["obstacles"]:
		var obstacle: Dictionary = obstacle_variant
		obstacle_by_cell[_cell_key(obstacle["cell"])] = int(obstacle["type"])

	var path_by_cell: Dictionary = {}
	for record_variant in reveal["records"]:
		var record: Dictionary = record_variant
		path_by_cell[_cell_key(record["cell_after"])] = int(record["step"])

	var blind_key := _cell_key(board["blind_cell"])
	var watermelon_key := _cell_key(reveal["watermelon_cell"])
	var patterns: Array = board["patterns"]
	var rows: Array[String] = []
	for y in range(6):
		var cells: Array[String] = []
		for x in range(6):
			var index := y * 6 + x
			var key := "%d,%d" % [x, y]
			var token := _pattern_short(int(patterns[index]))
			if obstacle_by_cell.has(key):
				token += _collision_short(int(obstacle_by_cell[key]))
			if path_by_cell.has(key):
				token += "S%d" % int(path_by_cell[key])
			if key == blind_key:
				token += "B%s" % _facing_arrow(int(board["blind_facing"]))
			if key == watermelon_key:
				token += "W"
			cells.append("[%s]" % token)
		rows.append(" ".join(cells))
	return "FULL REVEAL BOARD\n" + "\n".join(rows)


static func _cell_key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]), int(cell[1])]


static func _role_name(role: int) -> String:
	match role:
		GameTypes.PlayerRole.BLIND: return "BLIND"
		GameTypes.PlayerRole.GUIDE_SIDE: return "GUIDE / SIDE RADAR"
		GameTypes.PlayerRole.GUIDE_STEP: return "GUIDE / STEP ECHO"
		GameTypes.PlayerRole.GUIDE_PATTERN: return "GUIDE / PATTERN MATCH"
	return "UNKNOWN"


static func _role_shortcut_text(role: int) -> String:
	match role:
		GameTypes.PlayerRole.BLIND: return "F1 BLIND"
		GameTypes.PlayerRole.GUIDE_SIDE: return "F2 SIDE"
		GameTypes.PlayerRole.GUIDE_STEP: return "F3 STEP"
		GameTypes.PlayerRole.GUIDE_PATTERN: return "F4 PATTERN"
	return "?"


static func _state_name(state: int) -> String:
	match state:
		GameTypes.RoundState.WAITING: return "WAITING"
		GameTypes.RoundState.ROLE_ASSIGN: return "ROLE_ASSIGN"
		GameTypes.RoundState.INTRO: return "INTRO"
		GameTypes.RoundState.CONSULT: return "CONSULT"
		GameTypes.RoundState.WALKING: return "WALKING"
		GameTypes.RoundState.DECISION: return "DECISION"
		GameTypes.RoundState.RESULT: return "RESULT"
		GameTypes.RoundState.REVEAL: return "REVEAL"
		GameTypes.RoundState.COMPLETE: return "COMPLETE"
	return "LEGACY / UNKNOWN"


static func _action_name(action: int) -> String:
	match action:
		GameTypes.BlindAction.FORWARD: return "FORWARD"
		GameTypes.BlindAction.LEFT: return "LEFT"
		GameTypes.BlindAction.RIGHT: return "RIGHT"
		GameTypes.BlindAction.BACK: return "BACK"
		GameTypes.BlindAction.SWING: return "SWING"
		GameTypes.BlindAction.STOP: return "STOP"
	return "?"


static func _sensor_title(kind: String) -> String:
	match kind:
		"side": return "SIDE RADAR"
		"step": return "STEP ECHO"
		"pattern": return "PATTERN MATCH"
	return "SENSOR"


static func _sensor_value_text(kind: String, value: int) -> String:
	match kind:
		"side":
			match value:
				GameTypes.SideValue.LEFT: return "LEFT"
				GameTypes.SideValue.CENTER: return "CENTER"
				GameTypes.SideValue.RIGHT: return "RIGHT"
		"step":
			match value:
				GameTypes.StepValue.NO_BASELINE: return "NO BASELINE"
				GameTypes.StepValue.CLOSER: return "CLOSER"
				GameTypes.StepValue.SAME: return "SAME"
				GameTypes.StepValue.FARTHER: return "FARTHER"
		"pattern":
			match value:
				GameTypes.PatternValue.MATCH: return "MATCH"
				GameTypes.PatternValue.DIFFERENT: return "DIFFERENT"
	return "?"


static func _pattern_short(pattern: int) -> String:
	match pattern:
		GameTypes.PatternType.SHELL: return "S"
		GameTypes.PatternType.STAR: return "*"
		GameTypes.PatternType.CRAB: return "C"
	return "?"


static func _collision_short(collision: int) -> String:
	match collision:
		GameTypes.CollisionType.PARASOL: return "P"
		GameTypes.CollisionType.COOLER: return "K"
		GameTypes.CollisionType.BOUNDARY: return "X"
	return ""


static func _facing_arrow(facing: int) -> String:
	match facing:
		GameTypes.Facing.NORTH: return "^"
		GameTypes.Facing.EAST: return ">"
		GameTypes.Facing.SOUTH: return "v"
		GameTypes.Facing.WEST: return "<"
	return "?"
