extends "res://scripts/ui/suikawari_c5_screen.gd"


var transition_notice := ""


func get_c6_contract_snapshot() -> Dictionary:
	return {
		"walk_beat_seconds": WALK_BEAT_SECONDS,
		"stop_has_immediate_feedback": true,
		"sensor_change_is_emphasized": true,
		"reveal_shows_coordinate_free_path": true,
		"reveal_calls_out_adjacent_miss": true,
		"guide_gameplay_buttons": 0,
		"watermelon_sabotage_buttons": 0,
	}


func get_current_c6_snapshot() -> Dictionary:
	var base := get_current_presentation_snapshot()
	base["transition_notice"] = transition_notice
	base["sensor_changed"] = false
	base["reveal_path_text"] = ""
	if not round_started:
		return base

	var projection := session.get_projection()
	if projection.has("sensor"):
		base["sensor_changed"] = _sensor_changed(projection["sensor"])
	if int(projection.get("state", GameTypes.RoundState.WAITING)) in [GameTypes.RoundState.REVEAL, GameTypes.RoundState.COMPLETE]:
		var reveal := session.get_reveal_projection()
		if not reveal.is_empty():
			base["reveal_path_text"] = _reveal_path_board_text(reveal)
	return base


func _start_round(board_id: int) -> void:
	transition_notice = ""
	super._start_round(board_id)


func _on_direction_pressed(action: int) -> void:
	transition_notice = ""
	super._on_direction_pressed(action)


func _on_walk_beat() -> void:
	if not round_started or session.round_controller.state != GameTypes.RoundState.WALKING:
		return
	var result := session.advance_step()
	if bool(result.get("accepted", false)) and bool(result.get("auto_stop", false)):
		match str(result.get("stop_reason", "")):
			"bump":
				transition_notice = "ゴン！ BUMP"
			"budget":
				transition_notice = "あと0歩　最終決断"
	_refresh()
	if session.round_controller.state == GameTypes.RoundState.WALKING and is_inside_tree():
		walk_timer.start(WALK_BEAT_SECONDS)


func _on_stop_pressed() -> void:
	if not _blind_view_active():
		return
	walk_timer.stop()
	var result := session.stop_walk()
	if bool(result.get("accepted", false)):
		transition_notice = "ストップ！"
	_refresh()


func _on_request_swing() -> void:
	if not _blind_view_active():
		return
	var result := session.request_swing()
	if bool(result.get("accepted", false)):
		transition_notice = "ここで振る？"
	_refresh()


func _on_continue_pressed() -> void:
	if not _blind_view_active():
		return
	var result := session.continue_after_decision()
	if bool(result.get("accepted", false)):
		transition_notice = ""
	_refresh()


func _on_confirm_swing() -> void:
	if not _blind_view_active():
		return
	walk_timer.stop()
	var result := session.confirm_swing()
	if bool(result.get("accepted", false)):
		transition_notice = "振った！"
	_refresh()


func _refresh_public_stage(projection: Dictionary) -> void:
	super._refresh_public_stage(projection)
	var state := int(projection["state"])
	if state == GameTypes.RoundState.CONSULT and not transition_notice.is_empty():
		public_state.text = transition_notice + "　ここで相談"
		public_instruction.text = "止まった瞬間に考える時間へ切り替わります。今までの反応を声で重ねて、次を決めます。"
	elif state == GameTypes.RoundState.DECISION and not transition_notice.is_empty():
		public_state.text = transition_notice
		public_instruction.text = "新しい情報は増えません。振るか、残り歩数で確かめるか、最後に相談します。"


func _render_guide(projection: Dictionary) -> void:
	super._render_guide(projection)
	content_value.add_theme_color_override("font_color", Color("#174f79"))
	if int(projection["state"]) != GameTypes.RoundState.WALKING:
		return
	var sensor: Dictionary = projection["sensor"]
	if _sensor_changed(sensor):
		content_title.text = "変化！　いまの反応"
		content_value.add_theme_color_override("font_color", Color("#d94d31"))
		content_history.text += "\n\n値が切り替わった。意味を決めるのはシステムではなく、あなたとチームです。"


func _render_watermelon(projection: Dictionary) -> void:
	super._render_watermelon(projection)
	content_value.add_theme_color_override("font_color", Color("#174f79"))
	if int(projection["state"]) != GameTypes.RoundState.WALKING:
		return
	var sensor: Dictionary = projection["sensor"]
	if _sensor_changed(sensor):
		content_title.text = "本当のセンサーが変化！"
		content_value.add_theme_color_override("font_color", Color("#d94d31"))


func _render_reveal(reveal: Dictionary) -> void:
	super._render_reveal(reveal)
	content_title.text = "答え合わせ"
	content_value.add_theme_color_override("font_color", Color("#174f79"))
	secret_board_label.visible = true
	secret_board_label.text = _reveal_path_board_text(reveal)
	content_history.text = "%s\n歩いた歩数: %d / %d\n\n3つの小さな真実\nサイド　%s\nステップ　%s\nパターン　%s" % [
		_reveal_result_comment(reveal),
		int(reveal["steps_taken"]),
		BoardManager.MAX_STEPS,
		_reveal_sensor_flow("side", reveal["sensor_histories"]["side"]),
		_reveal_sensor_flow("step", reveal["sensor_histories"]["step"]),
		_reveal_sensor_flow("pattern", reveal["sensor_histories"]["pattern"]),
	]


func _sensor_changed(sensor: Dictionary) -> bool:
	var history: Array = sensor["history"]
	if history.size() < 2:
		return false
	return int(history[-1]["value"]) != int(history[-2]["value"])


func _reveal_path_board_text(reveal: Dictionary) -> String:
	var board: Dictionary = reveal["board"]
	var records: Array = reveal["records"]
	var obstacles: Dictionary = {}
	for obstacle_variant in board["obstacles"]:
		var obstacle: Dictionary = obstacle_variant
		obstacles[_cell_key(obstacle["cell"])] = true

	var step_cells: Dictionary = {}
	var start_key := _cell_key(board["blind_cell"])
	if not records.is_empty():
		start_key = _cell_key(records[0]["cell_before"])
	for record_variant in records:
		var record: Dictionary = record_variant
		step_cells[_cell_key(record["cell_after"])] = int(record["step"])

	var final_key := _cell_key(board["blind_cell"])
	var watermelon_key := _cell_key(reveal["watermelon_cell"])
	var patterns: Array = board["patterns"]
	var rows: Array[String] = []
	for y in range(BoardManager.HEIGHT):
		var cells: Array[String] = []
		for x in range(BoardManager.WIDTH):
			var key := "%d,%d" % [x, y]
			var token := _pattern_token(int(patterns[y * BoardManager.WIDTH + x]))
			if obstacles.has(key):
				token = "障"
			if key == start_key:
				token = "始"
			if step_cells.has(key):
				token = str(int(step_cells[key]))
			if key == watermelon_key:
				token = "瓜"
			if key == final_key:
				token = "割" if bool(reveal["success"]) else "振"
			cells.append("[%s]" % token)
		rows.append(" ".join(cells))
	return "答え合わせマップ　始=開始 / 数字=歩いた順 / 振=SWING / 瓜=スイカ / 割=直撃\n" + "\n".join(rows)


func _reveal_result_comment(reveal: Dictionary) -> String:
	if bool(reveal["success"]):
		return "直撃！　みんなの情報がここで重なった。"
	var blind_cell: Array = reveal["board"]["blind_cell"]
	var watermelon_cell: Array = reveal["watermelon_cell"]
	var distance := absi(int(blind_cell[0]) - int(watermelon_cell[0])) + absi(int(blind_cell[1]) - int(watermelon_cell[1]))
	if distance == 1:
		return "惜しい！　スイカはとなりのマスだった。"
	return "はずれ！　リビールで『どこで読み違えたか』を見てみよう。"


func _reveal_sensor_flow(kind: String, history: Array) -> String:
	var values: Array[String] = []
	for entry_variant in history:
		var entry: Dictionary = entry_variant
		values.append(_sensor_value_text(kind, int(entry["value"])))
	if values.is_empty():
		return "なし"
	return " → ".join(values)
