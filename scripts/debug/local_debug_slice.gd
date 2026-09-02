extends Control


var session: LocalDebugSession = LocalDebugSession.new()
var round_started := false
var debug_visible := false

var role_label: Label
var status_label: Label
var board_heading: Label
var board_grid: GridContainer
var board_cells: Array[Label] = []
var blind_panel: VBoxContainer
var blind_facing_label: Label
var action_history_label: Label
var sensor_label: Label
var sensor_history_label: Label
var result_label: Label
var debug_label: Label
var start_button: Button
var reveal_button: Button
var rematch_button: Button
var board_selector: OptionButton
var action_row: HBoxContainer
var role_buttons: Dictionary = {}
var action_buttons: Array[Button] = []


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
	title.text = "SUICAWARI  /  LOCAL FOUR-ROLE DEBUG"
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
		role_button.custom_minimum_size = Vector2(110, 40)
		role_button.pressed.connect(_on_role_pressed.bind(role))
		controls.add_child(role_button)
		role_buttons[role] = role_button

	role_label = Label.new()
	role_label.add_theme_font_size_override("font_size", 22)
	page.add_child(role_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 16)
	page.add_child(status_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)

	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 8)
	body.add_child(left_column)

	board_heading = Label.new()
	board_heading.text = "GUIDE BOARD"
	board_heading.add_theme_font_size_override("font_size", 18)
	left_column.add_child(board_heading)

	board_grid = GridContainer.new()
	board_grid.columns = 6
	board_grid.add_theme_constant_override("h_separation", 4)
	board_grid.add_theme_constant_override("v_separation", 4)
	left_column.add_child(board_grid)

	for _index in range(36):
		var cell_panel := PanelContainer.new()
		cell_panel.custom_minimum_size = Vector2(72, 48)
		var cell_label := Label.new()
		cell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell_label.add_theme_font_size_override("font_size", 13)
		cell_panel.add_child(cell_label)
		board_grid.add_child(cell_panel)
		board_cells.append(cell_label)

	blind_panel = VBoxContainer.new()
	blind_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blind_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blind_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	left_column.add_child(blind_panel)

	var blindfold := Label.new()
	blindfold.text = "BLINDFOLD ACTIVE\n\nThe board is intentionally hidden.\nListen to the three Guides."
	blindfold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blindfold.add_theme_font_size_override("font_size", 20)
	blind_panel.add_child(blindfold)

	blind_facing_label = Label.new()
	blind_facing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blind_facing_label.add_theme_font_size_override("font_size", 30)
	blind_panel.add_child(blind_facing_label)

	action_history_label = Label.new()
	action_history_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blind_panel.add_child(action_history_label)

	var right_column := VBoxContainer.new()
	right_column.custom_minimum_size = Vector2(360, 0)
	right_column.add_theme_constant_override("separation", 10)
	body.add_child(right_column)

	var sensor_heading := Label.new()
	sensor_heading.text = "YOUR PRIVATE SENSOR"
	sensor_heading.add_theme_font_size_override("font_size", 17)
	right_column.add_child(sensor_heading)

	sensor_label = Label.new()
	sensor_label.custom_minimum_size = Vector2(0, 92)
	sensor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sensor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sensor_label.add_theme_font_size_override("font_size", 24)
	right_column.add_child(sensor_label)

	var history_heading := Label.new()
	history_heading.text = "SENSOR HISTORY"
	history_heading.add_theme_font_size_override("font_size", 16)
	right_column.add_child(history_heading)

	sensor_history_label = Label.new()
	sensor_history_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sensor_history_label.add_theme_font_size_override("font_size", 15)
	right_column.add_child(sensor_history_label)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 24)
	right_column.add_child(result_label)

	reveal_button = Button.new()
	reveal_button.text = "REVEAL WHAT EVERYONE SAW"
	reveal_button.custom_minimum_size = Vector2(0, 44)
	reveal_button.pressed.connect(_on_reveal_pressed)
	right_column.add_child(reveal_button)

	rematch_button = Button.new()
	rematch_button.text = "REMATCH / NEXT BOARD"
	rematch_button.custom_minimum_size = Vector2(0, 44)
	rematch_button.pressed.connect(_on_rematch_pressed)
	right_column.add_child(rematch_button)

	action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 8)
	page.add_child(action_row)

	for action in [
		GameTypes.BlindAction.LEFT,
		GameTypes.BlindAction.FORWARD,
		GameTypes.BlindAction.RIGHT,
		GameTypes.BlindAction.BACK,
		GameTypes.BlindAction.SWING,
	]:
		var action_button := Button.new()
		action_button.text = _action_name(action)
		action_button.custom_minimum_size = Vector2(132, 44)
		action_button.pressed.connect(_on_action_pressed.bind(action))
		action_row.add_child(action_button)
		action_buttons.append(action_button)

	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 13)
	page.add_child(debug_label)

	var help := Label.new()
	help.text = "F1 Blind   F2 Side Guide   F3 Step Guide   F4 Pattern Guide   F10 Debug info"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(help)


func _on_start_pressed() -> void:
	round_started = session.start_round(board_selector.get_selected_id())
	_refresh()


func _on_role_pressed(role: int) -> void:
	if not session.set_role(role):
		return
	_refresh()


func _on_action_pressed(action: int) -> void:
	if not round_started or session.current_role != GameTypes.PlayerRole.BLIND:
		return
	session.process_action(action)
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


func _refresh() -> void:
	for role_variant in role_buttons.keys():
		var role := int(role_variant)
		var button: Button = role_buttons[role_variant]
		button.disabled = role == session.current_role

	if not round_started:
		role_label.text = "ROLE: BLIND  [no active round]"
		status_label.text = "Choose a preset board and press START ROUND."
		board_heading.text = "GUIDE BOARD"
		board_grid.visible = false
		blind_panel.visible = true
		blind_facing_label.text = ""
		action_history_label.text = ""
		sensor_label.text = "NO ROUND"
		sensor_history_label.text = ""
		result_label.text = ""
		action_row.visible = false
		reveal_button.visible = false
		rematch_button.visible = false
		start_button.disabled = false
		_refresh_debug()
		return

	var projection := session.get_projection()
	var state := int(projection["state"])
	role_label.text = "ROLE: %s" % _role_name(session.current_role)
	status_label.text = "Board %02d   |   Turn %d / 8   |   State: %s" % [session.board_index, int(projection["turn"]), _state_name(state)]
	start_button.disabled = state != GameTypes.RoundState.RESULT and state != GameTypes.RoundState.REVEAL and state != GameTypes.RoundState.COMPLETE

	if state == GameTypes.RoundState.REVEAL or state == GameTypes.RoundState.COMPLETE:
		_render_reveal(session.get_reveal_projection())
	else:
		_render_active_role(projection)

	var at_result := state == GameTypes.RoundState.RESULT
	var at_reveal := state == GameTypes.RoundState.REVEAL or state == GameTypes.RoundState.COMPLETE
	reveal_button.visible = at_result
	rematch_button.visible = at_reveal

	if bool(projection.get("result_known", false)):
		result_label.text = "SMASHED!" if bool(projection.get("success", false)) else "MISSED!"
	else:
		result_label.text = ""

	var blind_can_act := session.current_role == GameTypes.PlayerRole.BLIND and bool(projection.get("can_act", false))
	action_row.visible = blind_can_act
	for action_button in action_buttons:
		action_button.disabled = not blind_can_act
	_refresh_debug()


func _render_active_role(projection: Dictionary) -> void:
	if session.current_role == GameTypes.PlayerRole.BLIND:
		board_grid.visible = false
		blind_panel.visible = true
		board_heading.text = "BLIND VIEW: BOARD HIDDEN"
		blind_facing_label.text = "Facing: %s" % _facing_name(int(projection["facing"]))
		action_history_label.text = "Actions: %s" % _action_history_text(projection["action_history"])
		sensor_label.text = "NO SENSOR\nListen to Guides"
		sensor_history_label.text = "Guide sensor values are intentionally absent from this view."
		return

	board_grid.visible = true
	blind_panel.visible = false
	board_heading.text = "GUIDE BOARD  [watermelon hidden]"
	_render_board(projection["board"], null)
	var sensor: Dictionary = projection["sensor"]
	sensor_label.text = "%s\n%s" % [_sensor_title(str(sensor["kind"])), _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))]
	sensor_history_label.text = _sensor_history_text(sensor)


func _render_reveal(reveal: Dictionary) -> void:
	board_grid.visible = true
	blind_panel.visible = false
	board_heading.text = "REVEAL: FULL BOARD + PATH"
	_render_board(reveal["board"], reveal)
	sensor_label.text = "REVEAL\n%s" % ("SMASHED" if bool(reveal["success"]) else "MISSED")

	var histories: Dictionary = reveal["sensor_histories"]
	var lines: Array[String] = []
	for kind in ["side", "step", "pattern"]:
		lines.append(_sensor_title(kind))
		for entry_variant in histories[kind]:
			var entry: Dictionary = entry_variant
			lines.append("  T%d  %s" % [int(entry["turn"]), _sensor_value_text(kind, int(entry["value"]))])
	sensor_history_label.text = "\n".join(lines)


func _render_board(board: Dictionary, reveal: Variant) -> void:
	var obstacle_by_cell: Dictionary = {}
	for obstacle_variant in board["obstacles"]:
		var obstacle: Dictionary = obstacle_variant
		obstacle_by_cell[_cell_key(obstacle["cell"])] = int(obstacle["type"])

	var path_by_cell: Dictionary = {}
	var watermelon_key := ""
	if reveal != null:
		var reveal_data: Dictionary = reveal
		watermelon_key = _cell_key(reveal_data["watermelon_cell"])
		for record_variant in reveal_data["records"]:
			var record: Dictionary = record_variant
			path_by_cell[_cell_key(record["cell_after"])] = int(record["turn"])

	var blind_key := _cell_key(board["blind_cell"])
	var patterns: Array = board["patterns"]
	for index in range(36):
		var x := index % 6
		var y := int(index / 6)
		var key := "%d,%d" % [x, y]
		var parts: Array[String] = [_pattern_name(int(patterns[index]))]
		if obstacle_by_cell.has(key):
			parts.append(_collision_name(int(obstacle_by_cell[key])))
		if path_by_cell.has(key):
			parts.append("T%d" % int(path_by_cell[key]))
		if key == blind_key:
			parts.append("BLIND %s" % _facing_arrow(int(board["blind_facing"])))
		if not watermelon_key.is_empty() and key == watermelon_key:
			parts.append("WATERMELON")
		board_cells[index].text = "\n".join(parts)


func _refresh_debug() -> void:
	debug_label.visible = debug_visible
	if not debug_visible:
		debug_label.text = ""
		return
	if not round_started:
		debug_label.text = "DEBUG | no round | no secret state displayed"
		return
	debug_label.text = "DEBUG | board=%02d state=%s turn=%d role=%s | secret positions intentionally omitted" % [
		session.board_index,
		_state_name(session.round_controller.state),
		session.round_controller.turn,
		_role_name(session.current_role),
	]


func _sensor_history_text(sensor: Dictionary) -> String:
	var lines: Array[String] = []
	var kind := str(sensor["kind"])
	for entry_variant in sensor["history"]:
		var entry: Dictionary = entry_variant
		lines.append("T%d   %s" % [int(entry["turn"]), _sensor_value_text(kind, int(entry["value"]))])
	return "\n".join(lines)


func _action_history_text(history: Array) -> String:
	if history.is_empty():
		return "(none)"
	var names: Array[String] = []
	for action_variant in history:
		names.append(_action_name(int(action_variant)))
	return " > ".join(names)


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
		GameTypes.RoundState.SENSOR_UPDATE: return "SENSOR_UPDATE"
		GameTypes.RoundState.TALK: return "TALK / ACTION"
		GameTypes.RoundState.WAIT_ACTION: return "WAIT_ACTION"
		GameTypes.RoundState.RESOLVE_ACTION: return "RESOLVE_ACTION"
		GameTypes.RoundState.RESOLVE_SWING: return "RESOLVE_SWING"
		GameTypes.RoundState.RESULT: return "RESULT"
		GameTypes.RoundState.REVEAL: return "REVEAL"
		GameTypes.RoundState.COMPLETE: return "COMPLETE"
	return "UNKNOWN"


static func _facing_name(facing: int) -> String:
	match facing:
		GameTypes.Facing.NORTH: return "NORTH"
		GameTypes.Facing.EAST: return "EAST"
		GameTypes.Facing.SOUTH: return "SOUTH"
		GameTypes.Facing.WEST: return "WEST"
	return "?"


static func _facing_arrow(facing: int) -> String:
	match facing:
		GameTypes.Facing.NORTH: return "N"
		GameTypes.Facing.EAST: return "E"
		GameTypes.Facing.SOUTH: return "S"
		GameTypes.Facing.WEST: return "W"
	return "?"


static func _action_name(action: int) -> String:
	match action:
		GameTypes.BlindAction.FORWARD: return "FORWARD"
		GameTypes.BlindAction.LEFT: return "LEFT"
		GameTypes.BlindAction.RIGHT: return "RIGHT"
		GameTypes.BlindAction.BACK: return "BACK"
		GameTypes.BlindAction.SWING: return "SWING"
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


static func _pattern_name(pattern: int) -> String:
	match pattern:
		GameTypes.PatternType.SHELL: return "SHELL"
		GameTypes.PatternType.STAR: return "STAR"
		GameTypes.PatternType.CRAB: return "CRAB"
	return "?"


static func _collision_name(collision: int) -> String:
	match collision:
		GameTypes.CollisionType.PARASOL: return "PARASOL"
		GameTypes.CollisionType.COOLER: return "COOLER"
		GameTypes.CollisionType.BOUNDARY: return "BOUNDARY"
	return ""
