extends Control


const WALK_BEAT_SECONDS := 1.4

var session: LocalDebugSession = LocalDebugSession.new()
var round_started := false
var ui_built := false

var board_selector: OptionButton
var maybe_toggle: CheckButton
var start_button: Button
var reveal_button: Button
var next_button: Button
var role_buttons: Dictionary = {}

var hud_round: Label
var hud_steps: Label
var hud_phase: Label
var public_state: Label
var public_instruction: Label
var role_title: Label
var role_subtitle: Label
var content_title: Label
var content_value: Label
var content_history: Label
var secret_banner: Label
var secret_board_label: Label
var team_strip: HBoxContainer
var action_area: VBoxContainer

var walk_timer: Timer


func _ready() -> void:
	_ensure_ui()
	_refresh()


func ensure_ui_for_test() -> void:
	_ensure_ui()


func get_c4_contract_snapshot() -> Dictionary:
	return {
		"guide_skills_passive": true,
		"guide_gameplay_buttons": 0,
		"blind_consult_actions": [
			GameTypes.BlindAction.FORWARD,
			GameTypes.BlindAction.LEFT,
			GameTypes.BlindAction.RIGHT,
			GameTypes.BlindAction.BACK,
			GameTypes.BlindAction.SWING,
		],
		"blind_walking_actions": [GameTypes.BlindAction.STOP],
		"watermelon_public_role": GameTypes.PublicRole.GUIDE,
		"watermelon_secret_role": GameTypes.SecretRole.WATERMELON,
		"watermelon_board_has_coordinates": false,
	}


func _ensure_ui() -> void:
	if ui_built:
		return
	ui_built = true
	_build_ui()
	walk_timer = Timer.new()
	walk_timer.one_shot = true
	walk_timer.wait_time = WALK_BEAT_SECONDS
	walk_timer.timeout.connect(_on_walk_beat)
	add_child(walk_timer)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			_set_view_role(GameTypes.PlayerRole.BLIND)
		KEY_F2:
			_set_view_role(GameTypes.PlayerRole.GUIDE_SIDE)
		KEY_F3:
			_set_view_role(GameTypes.PlayerRole.GUIDE_STEP)
		KEY_F4:
			_set_view_role(GameTypes.PlayerRole.GUIDE_PATTERN)
		KEY_SPACE:
			if round_started and session.current_role == GameTypes.PlayerRole.BLIND and session.round_controller.can_stop():
				_on_stop_pressed()
		_:
			return
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#f7e7bb")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 18)
	root_margin.add_theme_constant_override("margin_right", 18)
	root_margin.add_theme_constant_override("margin_top", 14)
	root_margin.add_theme_constant_override("margin_bottom", 14)
	add_child(root_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	root_margin.add_child(page)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	page.add_child(top)

	var logo := Label.new()
	logo.text = "SUIKAWARI"
	logo.add_theme_font_size_override("font_size", 30)
	logo.add_theme_color_override("font_color", Color("#17324d"))
	top.add_child(logo)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	board_selector = OptionButton.new()
	board_selector.name = "BoardSelector"
	board_selector.custom_minimum_size = Vector2(118, 38)
	for index in range(1, 13):
		board_selector.add_item("盤面 %02d" % index, index)
	top.add_child(board_selector)

	maybe_toggle = CheckButton.new()
	maybe_toggle.name = "MaybeToggle"
	maybe_toggle.text = "MAYBE: P4がスイカ"
	maybe_toggle.button_pressed = true
	top.add_child(maybe_toggle)

	start_button = Button.new()
	start_button.name = "StartButton"
	start_button.text = "ラウンド開始"
	start_button.pressed.connect(_on_start_pressed)
	top.add_child(start_button)

	var hud := HBoxContainer.new()
	hud.add_theme_constant_override("separation", 8)
	page.add_child(hud)
	hud_round = _hud_chip(hud, "ラウンド 1")
	hud_steps = _hud_chip(hud, "あと 8歩")
	hud_phase = _hud_chip(hud, "待機中")
	var hud_spacer := Control.new()
	hud_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(hud_spacer)
	var hint := Label.new()
	hint.text = "F1 Blind  F2 Side  F3 Step  F4 Pattern"
	hint.add_theme_color_override("font_color", Color("#31526d"))
	hud.add_child(hint)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	page.add_child(body)

	var public_panel := PanelContainer.new()
	public_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_panel.size_flags_stretch_ratio = 1.45
	public_panel.add_theme_stylebox_override("panel", _style(Color("#caefff"), Color("#2f88b7"), 3, 18))
	body.add_child(public_panel)

	var public_box := VBoxContainer.new()
	public_box.alignment = BoxContainer.ALIGNMENT_CENTER
	public_box.add_theme_constant_override("separation", 14)
	public_panel.add_child(public_box)

	var sky_label := Label.new()
	sky_label.text = "青い空　　波の音　　夏のビーチ"
	sky_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sky_label.add_theme_font_size_override("font_size", 20)
	sky_label.add_theme_color_override("font_color", Color("#17648d"))
	public_box.add_child(sky_label)

	var avatar := Label.new()
	avatar.text = "\n　　　目隠ししたブラインド\n　　　　　│\n　　　　　│  棒\n"
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.add_theme_font_size_override("font_size", 28)
	avatar.add_theme_color_override("font_color", Color("#17324d"))
	public_box.add_child(avatar)

	public_state = Label.new()
	public_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	public_state.add_theme_font_size_override("font_size", 28)
	public_state.add_theme_color_override("font_color", Color("#d94d31"))
	public_box.add_child(public_state)

	public_instruction = Label.new()
	public_instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	public_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	public_instruction.add_theme_font_size_override("font_size", 17)
	public_instruction.add_theme_color_override("font_color", Color("#31526d"))
	public_box.add_child(public_instruction)

	var role_panel := PanelContainer.new()
	role_panel.custom_minimum_size = Vector2(430, 0)
	role_panel.add_theme_stylebox_override("panel", _style(Color("#fffdf5"), Color("#3275a8"), 3, 18))
	body.add_child(role_panel)

	var role_margin := MarginContainer.new()
	role_margin.add_theme_constant_override("margin_left", 18)
	role_margin.add_theme_constant_override("margin_right", 18)
	role_margin.add_theme_constant_override("margin_top", 16)
	role_margin.add_theme_constant_override("margin_bottom", 16)
	role_panel.add_child(role_margin)

	var role_box := VBoxContainer.new()
	role_box.add_theme_constant_override("separation", 10)
	role_margin.add_child(role_box)

	role_title = Label.new()
	role_title.add_theme_font_size_override("font_size", 30)
	role_title.add_theme_color_override("font_color", Color("#17324d"))
	role_box.add_child(role_title)

	role_subtitle = Label.new()
	role_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role_subtitle.add_theme_font_size_override("font_size", 16)
	role_subtitle.add_theme_color_override("font_color", Color("#45677e"))
	role_box.add_child(role_subtitle)

	secret_banner = Label.new()
	secret_banner.visible = false
	secret_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secret_banner.add_theme_font_size_override("font_size", 22)
	secret_banner.add_theme_color_override("font_color", Color("#b83a45"))
	role_box.add_child(secret_banner)

	content_title = Label.new()
	content_title.add_theme_font_size_override("font_size", 18)
	content_title.add_theme_color_override("font_color", Color("#31526d"))
	role_box.add_child(content_title)

	content_value = Label.new()
	content_value.custom_minimum_size = Vector2(0, 92)
	content_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_value.add_theme_font_size_override("font_size", 42)
	content_value.add_theme_color_override("font_color", Color("#174f79"))
	role_box.add_child(content_value)

	secret_board_label = Label.new()
	secret_board_label.visible = false
	secret_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	secret_board_label.add_theme_font_size_override("font_size", 18)
	secret_board_label.add_theme_color_override("font_color", Color("#4d3d2d"))
	role_box.add_child(secret_board_label)

	content_history = Label.new()
	content_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_history.add_theme_font_size_override("font_size", 15)
	content_history.add_theme_color_override("font_color", Color("#4e5d66"))
	role_box.add_child(content_history)

	action_area = VBoxContainer.new()
	action_area.name = "BlindActionArea"
	action_area.add_theme_constant_override("separation", 8)
	role_box.add_child(action_area)

	var result_row := HBoxContainer.new()
	result_row.alignment = BoxContainer.ALIGNMENT_CENTER
	result_row.add_theme_constant_override("separation", 8)
	role_box.add_child(result_row)

	reveal_button = Button.new()
	reveal_button.text = "リビール"
	reveal_button.visible = false
	reveal_button.pressed.connect(_on_reveal_pressed)
	result_row.add_child(reveal_button)

	next_button = Button.new()
	next_button.text = "次の盤面"
	next_button.visible = false
	next_button.pressed.connect(_on_next_pressed)
	result_row.add_child(next_button)

	team_strip = HBoxContainer.new()
	team_strip.add_theme_constant_override("separation", 8)
	page.add_child(team_strip)
	for role in [GameTypes.PlayerRole.BLIND, GameTypes.PlayerRole.GUIDE_SIDE, GameTypes.PlayerRole.GUIDE_STEP, GameTypes.PlayerRole.GUIDE_PATTERN]:
		var role_button := Button.new()
		role_button.custom_minimum_size = Vector2(0, 58)
		role_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		role_button.text = _public_player_label(role)
		role_button.pressed.connect(_set_view_role.bind(role))
		team_strip.add_child(role_button)
		role_buttons[role] = role_button


func _hud_chip(parent: HBoxContainer, text_value: String) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#294c61"), Color("#183447"), 2, 10))
	parent.add_child(panel)
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(150, 38)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	return label


func _on_start_pressed() -> void:
	_start_round(board_selector.get_selected_id())


func _start_round(board_id: int) -> void:
	walk_timer.stop()
	session = LocalDebugSession.new()
	if maybe_toggle.button_pressed:
		session.set_watermelon_role(GameTypes.PlayerRole.GUIDE_PATTERN)
	else:
		session.set_watermelon_role(LocalDebugSession.NO_WATERMELON_ROLE)
	round_started = session.start_round(board_id)
	_refresh()


func _on_next_pressed() -> void:
	var next_id := 1
	if round_started:
		next_id = session.board_index % LocalDebugSession.LAST_BOARD + 1
	board_selector.select(next_id - 1)
	_start_round(next_id)


func _set_view_role(role: int) -> void:
	if not session.set_role(role):
		return
	_refresh()


func _on_direction_pressed(action: int) -> void:
	if not _blind_view_active():
		return
	var result := session.begin_walk(action)
	if bool(result.get("accepted", false)):
		walk_timer.start(WALK_BEAT_SECONDS)
	_refresh()


func _on_walk_beat() -> void:
	if not round_started or session.round_controller.state != GameTypes.RoundState.WALKING:
		return
	session.advance_step()
	_refresh()
	if session.round_controller.state == GameTypes.RoundState.WALKING:
		walk_timer.start(WALK_BEAT_SECONDS)


func _on_stop_pressed() -> void:
	if not _blind_view_active():
		return
	walk_timer.stop()
	session.stop_walk()
	_refresh()


func _on_request_swing() -> void:
	if _blind_view_active():
		session.request_swing()
		_refresh()


func _on_confirm_swing() -> void:
	if _blind_view_active():
		walk_timer.stop()
		session.confirm_swing()
		_refresh()


func _on_continue_pressed() -> void:
	if _blind_view_active():
		session.continue_after_decision()
		_refresh()


func _on_reveal_pressed() -> void:
	if session.begin_reveal():
		_refresh()


func _blind_view_active() -> bool:
	return round_started and session.current_role == GameTypes.PlayerRole.BLIND


func _refresh() -> void:
	if not ui_built:
		return
	for role_variant in role_buttons.keys():
		var role := int(role_variant)
		var button: Button = role_buttons[role_variant]
		button.disabled = role == session.current_role

	_clear_actions()
	secret_banner.visible = false
	secret_board_label.visible = false
	reveal_button.visible = false
	next_button.visible = false

	if not round_started:
		hud_round.text = "ラウンド 1"
		hud_steps.text = "あと 8歩"
		hud_phase.text = "待機中"
		public_state.text = "夏のビーチでスイカ割り！"
		public_instruction.text = "ラウンドを開始すると、役割ごとに必要な情報だけが表示されます。"
		role_title.text = "ブラインド"
		role_subtitle.text = "みんなの声を聞いて、最後に決める人。"
		content_title.text = "まだラウンドは始まっていません"
		content_value.text = "準備OK"
		content_history.text = "MAYBEではP4がスイカになるデバッグ設定を切り替えられます。"
		return

	var projection := session.get_projection()
	var state := int(projection["state"])
	hud_round.text = "ラウンド 1"
	hud_steps.text = "あと %d歩" % int(projection["steps_remaining"])
	hud_phase.text = _phase_name(state)
	_refresh_public_stage(projection)

	if state == GameTypes.RoundState.REVEAL or state == GameTypes.RoundState.COMPLETE:
		_render_reveal(session.get_reveal_projection())
	elif session.current_role == GameTypes.PlayerRole.BLIND:
		_render_blind(projection)
	elif int(projection.get("secret_role", GameTypes.SecretRole.NONE)) == GameTypes.SecretRole.WATERMELON:
		_render_watermelon(projection)
	else:
		_render_guide(projection)

	if state == GameTypes.RoundState.RESULT:
		reveal_button.visible = true
	if state == GameTypes.RoundState.REVEAL or state == GameTypes.RoundState.COMPLETE:
		next_button.visible = true


func _refresh_public_stage(projection: Dictionary) -> void:
	match int(projection["state"]):
		GameTypes.RoundState.CONSULT:
			public_state.text = "停止中"
			public_instruction.text = "位置の手掛かりになる背景はありません。みんなの声だけを頼りに次の一手を決めます。"
		GameTypes.RoundState.WALKING:
			public_state.text = "スタッ…… スタッ……"
			public_instruction.text = "ブラインドが歩いています。ガイドの計器は一歩ごとに自動更新されます。"
		GameTypes.RoundState.DECISION:
			public_state.text = "振る直前"
			public_instruction.text = "ここで振るか、もう少し確かめるか。最後の相談タイム。"
		GameTypes.RoundState.RESULT:
			public_state.text = "SMASHED!" if bool(projection.get("success", false)) else "MISSED!"
			public_instruction.text = "結果が出ました。リビールで全員の見えていた真実を確認できます。"
		GameTypes.RoundState.REVEAL, GameTypes.RoundState.COMPLETE:
			public_state.text = "リビール"
			public_instruction.text = "ラウンド終了後だけ、盤面と秘密役が明かされます。"


func _render_blind(projection: Dictionary) -> void:
	role_title.text = "ブラインド"
	role_subtitle.text = "選ぶ → 止まる → 決める。センサーも盤面も見えません。"
	content_title.text = "みんなの声を聞こう"
	content_history.text = "公開行動履歴: %s" % _action_history_text(projection["action_history"])
	match int(projection["state"]):
		GameTypes.RoundState.CONSULT:
			content_value.text = "次はどうする？"
			_build_blind_consult_actions()
		GameTypes.RoundState.WALKING:
			content_value.text = "歩行中\n%s" % _action_name(int(projection.get("walk_direction", -1)))
			_build_blind_stop_action()
		GameTypes.RoundState.DECISION:
			content_value.text = "ここで振る？"
			_build_blind_decision_actions(bool(projection.get("can_continue_after_decision", false)))
		GameTypes.RoundState.RESULT:
			content_value.text = "割れた！" if bool(projection.get("success", false)) else "はずれ！"


func _render_guide(projection: Dictionary) -> void:
	role_title.text = "ガイド / %s" % _skill_name(int(projection["guide_skill"]))
	role_subtitle.text = "スキルは受動センサー。押して使いません。見る、覚える、考える、声で伝える。"
	var sensor: Dictionary = projection["sensor"]
	content_title.text = "いまの反応"
	content_value.text = _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))
	content_history.text = "センサー履歴\n%s\n\nBlindの行動\n%s\n\n操作ボタンはありません。自分の言葉でガイドしてください。" % [
		_sensor_history_text(sensor),
		_action_history_text(projection["action_history"]),
	]


func _render_watermelon(projection: Dictionary) -> void:
	role_title.text = "ガイド / %s" % _skill_name(int(projection["guide_skill"]))
	role_subtitle.text = "公開上は普通のガイド。通常センサーも本物です。"
	secret_banner.visible = true
	secret_banner.text = "あなたはスイカです　割られないでください"
	var sensor: Dictionary = projection["sensor"]
	content_title.text = "あなたの通常センサー"
	content_value.text = _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))
	secret_board_label.visible = true
	secret_board_label.text = _secret_board_text(projection["secret_board"])
	content_history.text = "他ガイドのセンサーは見えません。盤面と本当のセンサーを材料に、自然な言葉で誘導します。\n\nセンサー履歴\n%s" % _sensor_history_text(sensor)


func _render_reveal(reveal: Dictionary) -> void:
	role_title.text = "リビール"
	role_subtitle.text = "ここから先は全員が同じ真実を見ます。"
	content_title.text = "結果"
	content_value.text = "SMASHED!" if bool(reveal["success"]) else "MISSED!"
	secret_banner.visible = bool(reveal["watermelon_player_present"])
	if secret_banner.visible:
		secret_banner.text = "THE WATERMELON: %s" % _public_player_label(int(reveal["watermelon_player_role"]))
	secret_board_label.visible = true
	var full_board: Dictionary = reveal["board"].duplicate(true)
	full_board["watermelon_cell"] = reveal["watermelon_cell"]
	secret_board_label.text = _secret_board_text(full_board)
	content_history.text = "8歩のあと、盤面・経路・秘密役をまとめて答え合わせ。"


func _build_blind_consult_actions() -> void:
	var grid := GridContainer.new()
	grid.name = "BlindConsultGrid"
	grid.columns = 3
	action_area.add_child(grid)
	_grid_spacer(grid)
	_add_action_button(grid, "BlindForwardButton", "前へ", GameTypes.BlindAction.FORWARD, _on_direction_pressed)
	_grid_spacer(grid)
	_add_action_button(grid, "BlindLeftButton", "左へ", GameTypes.BlindAction.LEFT, _on_direction_pressed)
	_grid_spacer(grid)
	_add_action_button(grid, "BlindRightButton", "右へ", GameTypes.BlindAction.RIGHT, _on_direction_pressed)
	_grid_spacer(grid)
	_add_action_button(grid, "BlindBackButton", "後ろへ", GameTypes.BlindAction.BACK, _on_direction_pressed)
	_grid_spacer(grid)
	var swing := Button.new()
	swing.name = "BlindSwingRequestButton"
	swing.text = "振る？"
	swing.custom_minimum_size = Vector2(0, 52)
	swing.pressed.connect(_on_request_swing)
	action_area.add_child(swing)


func _build_blind_stop_action() -> void:
	var stop := Button.new()
	stop.name = "BlindStopButton"
	stop.text = "ストップ！"
	stop.custom_minimum_size = Vector2(0, 112)
	stop.add_theme_font_size_override("font_size", 34)
	stop.add_theme_color_override("font_color", Color.WHITE)
	stop.add_theme_stylebox_override("normal", _style(Color("#e94f3d"), Color("#992c25"), 4, 26))
	stop.pressed.connect(_on_stop_pressed)
	action_area.add_child(stop)


func _build_blind_decision_actions(can_continue: bool) -> void:
	var swing := Button.new()
	swing.name = "BlindConfirmSwingButton"
	swing.text = "振る！"
	swing.custom_minimum_size = Vector2(0, 78)
	swing.add_theme_font_size_override("font_size", 30)
	swing.pressed.connect(_on_confirm_swing)
	action_area.add_child(swing)
	if can_continue:
		var keep := Button.new()
		keep.name = "BlindContinueButton"
		keep.text = "まだ確認する"
		keep.custom_minimum_size = Vector2(0, 48)
		keep.pressed.connect(_on_continue_pressed)
		action_area.add_child(keep)


func _add_action_button(parent: Control, node_name: String, text_value: String, action: int, callback: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(112, 54)
	button.pressed.connect(callback.bind(action))
	parent.add_child(button)


func _grid_spacer(parent: Control) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(112, 54)
	parent.add_child(spacer)


func _clear_actions() -> void:
	for child in action_area.get_children():
		child.free()


func _secret_board_text(board: Dictionary) -> String:
	var blind_key := _cell_key(board["blind_cell"])
	var watermelon_key := _cell_key(board["watermelon_cell"])
	var obstacles: Dictionary = {}
	for obstacle_variant in board["obstacles"]:
		var obstacle: Dictionary = obstacle_variant
		obstacles[_cell_key(obstacle["cell"])] = int(obstacle["type"])
	var patterns: Array = board["patterns"]
	var rows: Array[String] = []
	for y in range(6):
		var cells: Array[String] = []
		for x in range(6):
			var key := "%d,%d" % [x, y]
			var token := _pattern_token(int(patterns[y * 6 + x]))
			if obstacles.has(key):
				token = "障"
			if key == watermelon_key:
				token = "瓜"
			if key == blind_key:
				token = "目%s" % _facing_arrow(int(board["blind_facing"]))
			if key == blind_key and key == watermelon_key:
				token = "目瓜"
			cells.append("[%s]" % token)
		rows.append(" ".join(cells))
	return "ひみつ作戦マップ（座標表示なし）\n" + "\n".join(rows)


func _sensor_history_text(sensor: Dictionary) -> String:
	var lines: Array[String] = []
	var kind := str(sensor["kind"])
	for entry_variant in sensor["history"]:
		var entry: Dictionary = entry_variant
		lines.append("S%d  %s" % [int(entry["step"]), _sensor_value_text(kind, int(entry["value"]))])
	return "\n".join(lines)


func _action_history_text(history: Array) -> String:
	if history.is_empty():
		return "まだなし"
	var names: Array[String] = []
	for action_variant in history:
		names.append(_action_name(int(action_variant)))
	return " → ".join(names)


static func _public_player_label(role: int) -> String:
	match role:
		GameTypes.PlayerRole.BLIND: return "P1  ブラインド"
		GameTypes.PlayerRole.GUIDE_SIDE: return "P2  ガイド / サイド"
		GameTypes.PlayerRole.GUIDE_STEP: return "P3  ガイド / ステップ"
		GameTypes.PlayerRole.GUIDE_PATTERN: return "P4  ガイド / パターン"
	return "?"


static func _skill_name(skill: int) -> String:
	match skill:
		GameTypes.GuideSkill.SIDE: return "サイドレーダー"
		GameTypes.GuideSkill.STEP: return "ステップエコー"
		GameTypes.GuideSkill.PATTERN: return "パターン一致"
	return "ガイド"


static func _phase_name(state: int) -> String:
	match state:
		GameTypes.RoundState.CONSULT: return "相談中"
		GameTypes.RoundState.WALKING: return "歩行中"
		GameTypes.RoundState.DECISION: return "決断"
		GameTypes.RoundState.RESULT: return "結果"
		GameTypes.RoundState.REVEAL: return "リビール"
		GameTypes.RoundState.COMPLETE: return "完了"
	return "待機中"


static func _action_name(action: int) -> String:
	match action:
		GameTypes.BlindAction.FORWARD: return "前"
		GameTypes.BlindAction.LEFT: return "左"
		GameTypes.BlindAction.RIGHT: return "右"
		GameTypes.BlindAction.BACK: return "後ろ"
		GameTypes.BlindAction.SWING: return "振る"
		GameTypes.BlindAction.STOP: return "STOP"
	return "?"


static func _sensor_value_text(kind: String, value: int) -> String:
	match kind:
		"side":
			match value:
				GameTypes.SideValue.LEFT: return "左"
				GameTypes.SideValue.CENTER: return "真ん中"
				GameTypes.SideValue.RIGHT: return "右"
		"step":
			match value:
				GameTypes.StepValue.NO_BASELINE: return "基準なし"
				GameTypes.StepValue.CLOSER: return "近づいた"
				GameTypes.StepValue.SAME: return "同じ"
				GameTypes.StepValue.FARTHER: return "遠ざかった"
		"pattern":
			match value:
				GameTypes.PatternValue.MATCH: return "一致"
				GameTypes.PatternValue.DIFFERENT: return "不一致"
	return "?"


static func _pattern_token(pattern: int) -> String:
	match pattern:
		GameTypes.PatternType.SHELL: return "貝"
		GameTypes.PatternType.STAR: return "星"
		GameTypes.PatternType.CRAB: return "蟹"
	return "・"


static func _facing_arrow(facing: int) -> String:
	match facing:
		GameTypes.Facing.NORTH: return "↑"
		GameTypes.Facing.EAST: return "→"
		GameTypes.Facing.SOUTH: return "↓"
		GameTypes.Facing.WEST: return "←"
	return "?"


static func _cell_key(cell: Array) -> String:
	return "%d,%d" % [int(cell[0]), int(cell[1])]


static func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
