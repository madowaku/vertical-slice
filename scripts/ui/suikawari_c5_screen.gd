extends "res://scripts/ui/suikawari_c4_screen.gd"


func get_c5_contract_snapshot() -> Dictionary:
	return {
		"guide_consult_focus": "analysis",
		"guide_walking_focus": "live_sensor",
		"guide_decision_focus": "summary",
		"watermelon_consult_focus": "map_reading",
		"watermelon_walking_focus": "threat_tracking",
		"watermelon_decision_focus": "last_word",
		"guide_gameplay_buttons": 0,
		"watermelon_sabotage_buttons": 0,
		"walk_beat_seconds": WALK_BEAT_SECONDS,
	}


func get_current_presentation_snapshot() -> Dictionary:
	var mode := "waiting"
	if round_started:
		var projection := session.get_projection()
		var state := int(projection.get("state", GameTypes.RoundState.WAITING))
		var is_watermelon := int(projection.get("secret_role", GameTypes.SecretRole.NONE)) == GameTypes.SecretRole.WATERMELON
		if session.current_role == GameTypes.PlayerRole.BLIND:
			match state:
				GameTypes.RoundState.CONSULT: mode = "blind_consult"
				GameTypes.RoundState.WALKING: mode = "blind_walking"
				GameTypes.RoundState.DECISION: mode = "blind_decision"
				_: mode = "blind_other"
		elif is_watermelon:
			match state:
				GameTypes.RoundState.CONSULT: mode = "watermelon_consult"
				GameTypes.RoundState.WALKING: mode = "watermelon_walking"
				GameTypes.RoundState.DECISION: mode = "watermelon_decision"
				_: mode = "watermelon_other"
		else:
			match state:
				GameTypes.RoundState.CONSULT: mode = "guide_consult"
				GameTypes.RoundState.WALKING: mode = "guide_walking"
				GameTypes.RoundState.DECISION: mode = "guide_decision"
				_: mode = "guide_other"
	return {
		"mode": mode,
		"action_button_count": action_area.get_child_count() if action_area != null else 0,
		"secret_board_visible": secret_board_label.visible if secret_board_label != null else false,
		"content_title": content_title.text if content_title != null else "",
		"content_value": content_value.text if content_value != null else "",
	}


func _on_direction_pressed(action: int) -> void:
	if not _blind_view_active():
		return
	var result := session.begin_walk(action)
	if bool(result.get("accepted", false)) and is_inside_tree():
		walk_timer.start(WALK_BEAT_SECONDS)
	_refresh()


func _refresh_public_stage(projection: Dictionary) -> void:
	match int(projection["state"]):
		GameTypes.RoundState.CONSULT:
			public_state.text = "停止中　考える時間"
			public_instruction.text = "焦らなくてOK。センサーの事実と、みんなの声を重ねて次の一手を決めます。"
		GameTypes.RoundState.WALKING:
			public_state.text = "スタッ…… スタッ……"
			public_instruction.text = "一歩ごとにセンサーが自動更新。次の足取りまで約1.4秒、変化を見て声で伝えます。"
		GameTypes.RoundState.DECISION:
			public_state.text = "振る直前　最後の相談"
			public_instruction.text = "ここでは新しい情報は増えません。今ある真実をどう読むか、最後に言葉を重ねます。"
		GameTypes.RoundState.RESULT:
			public_state.text = "SMASHED!" if bool(projection.get("success", false)) else "MISSED!"
			public_instruction.text = "結果が出ました。リビールで全員の見えていた真実を確認できます。"
		GameTypes.RoundState.REVEAL, GameTypes.RoundState.COMPLETE:
			public_state.text = "リビール"
			public_instruction.text = "ラウンド終了後だけ、盤面と秘密役が明かされます。"


func _render_guide(projection: Dictionary) -> void:
	role_title.text = "ガイド / %s" % _skill_name(int(projection["guide_skill"]))
	role_subtitle.text = "スキルは受動センサー。見る → 覚える → 考える → 喋る。"
	var sensor: Dictionary = projection["sensor"]
	var state := int(projection["state"])
	content_value.add_theme_font_size_override("font_size", 42)

	match state:
		GameTypes.RoundState.CONSULT:
			content_title.text = "考える時間"
			content_value.text = "現在　%s" % _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))
			content_history.text = "センサー履歴\n%s\n\nBlindの行動\n%s\n\n他ガイドの計器は見えません。声を聞いて、自分の履歴と組み合わせてください。" % [
				_sensor_history_text(sensor),
				_action_history_text(projection["action_history"]),
			]
		GameTypes.RoundState.WALKING:
			content_title.text = "いまの反応　変化を見逃さない"
			content_value.add_theme_font_size_override("font_size", 54)
			content_value.text = _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))
			content_history.text = "直近の反応\n%s\n\nスタッ…のたびに自動更新。STOPのタイミングはボタンではなく声でBlindへ伝えます。" % _recent_sensor_lines(sensor, 3)
		GameTypes.RoundState.DECISION:
			content_title.text = "最後の判断材料"
			content_value.text = _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))
			content_history.text = "直近の流れ\n%s\n\nBlindの行動\n%s\n\n『振る』『まだ』はシステムに押さされる答えではありません。自分の言葉で理由ごと伝えます。" % [
				_recent_sensor_flow(sensor, 4),
				_action_history_text(projection["action_history"]),
			]
		GameTypes.RoundState.RESULT:
			content_title.text = "結果"
			content_value.text = "割れた！" if bool(projection.get("success", false)) else "はずれ！"
			content_history.text = "リビールで、3人の小さな真実がどう重なっていたか確認できます。"
		_:
			super._render_guide(projection)


func _render_watermelon(projection: Dictionary) -> void:
	role_title.text = "ガイド / %s" % _skill_name(int(projection["guide_skill"]))
	role_subtitle.text = "公開上は普通のガイド。通常センサーも本物です。"
	secret_banner.visible = true
	secret_banner.text = "あなたはスイカです　割られないでください"
	secret_board_label.visible = true
	secret_board_label.text = _secret_board_text(projection["secret_board"])
	var sensor: Dictionary = projection["sensor"]
	var state := int(projection["state"])
	content_value.add_theme_font_size_override("font_size", 38)

	match state:
		GameTypes.RoundState.CONSULT:
			content_title.text = "ひみつ作戦会議"
			content_value.text = "通常センサー　%s" % _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))
			content_history.text = "盤面は全部見えています。でも他ガイドのセンサーは見えません。\n会話を聞きながら、普通のガイドとして何を言うか考えます。\n\n自分のセンサー履歴\n%s" % _sensor_history_text(sensor)
		GameTypes.RoundState.WALKING:
			content_title.text = "Blindが歩いている"
			content_value.text = "本当の反応　%s" % _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))
			content_history.text = "秘密盤面ではBlindが一歩ずつ動きます。妨害ボタンはありません。\n近づかれても、できることは自然に喋ることだけ。\n\n直近の反応　%s" % _recent_sensor_flow(sensor, 3)
		GameTypes.RoundState.DECISION:
			content_title.text = "最後の一言"
			content_value.text = "本当の反応　%s" % _sensor_value_text(str(sensor["kind"]), int(sensor["value"]))
			content_history.text = "Blindは今、振るか迷っています。盤面が見えていても特殊能力はありません。\n真実を壊さず、どう解釈させるか。最後まで喋るだけです。\n\n直近の反応　%s" % _recent_sensor_flow(sensor, 4)
		GameTypes.RoundState.RESULT:
			content_title.text = "結果"
			content_value.text = "割られた！" if bool(projection.get("success", false)) else "生き残った！"
			content_history.text = "リビールで、誰がスイカだったか全員に明かされます。"
		_:
			super._render_watermelon(projection)


func _recent_sensor_lines(sensor: Dictionary, count: int) -> String:
	var history: Array = sensor["history"]
	var kind := str(sensor["kind"])
	var start := maxi(0, history.size() - count)
	var lines: Array[String] = []
	for index in range(start, history.size()):
		var entry: Dictionary = history[index]
		lines.append("S%d  %s" % [int(entry["step"]), _sensor_value_text(kind, int(entry["value"]))])
	if lines.is_empty():
		return "まだなし"
	return "\n".join(lines)


func _recent_sensor_flow(sensor: Dictionary, count: int) -> String:
	var history: Array = sensor["history"]
	var kind := str(sensor["kind"])
	var start := maxi(0, history.size() - count)
	var values: Array[String] = []
	for index in range(start, history.size()):
		var entry: Dictionary = history[index]
		values.append(_sensor_value_text(kind, int(entry["value"])))
	if values.is_empty():
		return "まだなし"
	return " → ".join(values)
