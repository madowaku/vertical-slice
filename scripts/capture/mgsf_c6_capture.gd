extends Node


const DEFAULT_OUTPUT_DIR := "user://mgsf-capture"
const CAPTURE_ID := "vertical-slice-c6-direct"
const SESSION_ID := "capture-direct-001"

var screen: Control


func _ready() -> void:
	var output_dir := OS.get_environment("MGSF_CAPTURE_DIR")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path(DEFAULT_OUTPUT_DIR)
	elif not output_dir.is_absolute_path():
		output_dir = ProjectSettings.globalize_path(output_dir)

	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		_fail("could not create output directory: %s" % output_dir)
		return

	var resource := load("res://scenes/debug/local_debug_slice.tscn")
	if not resource is PackedScene:
		_fail("could not load C6 gameplay scene")
		return

	screen = (resource as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	screen.call("_start_round", 1)
	screen.call("_set_view_role", GameTypes.PlayerRole.BLIND)

	# Board 01 near-miss route from the verified C6 playfeel test:
	# RIGHT, STOP, RIGHT, STOP, then SWING one cell early.
	screen.call("_on_direction_pressed", GameTypes.BlindAction.RIGHT)
	screen.call("_on_walk_beat")
	screen.call("_on_stop_pressed")
	screen.call("_on_direction_pressed", GameTypes.BlindAction.RIGHT)
	screen.call("_on_walk_beat")
	screen.call("_on_stop_pressed")
	await get_tree().process_frame

	var before_path := output_dir.path_join("before-swing.png")
	if not await _capture_viewport(before_path):
		return

	screen.call("_on_request_swing")
	screen.call("_on_confirm_swing")
	await get_tree().process_frame

	if bool(screen.session.round_controller.last_swing_success):
		_fail("expected one-cell-early swing to miss")
		return

	screen.call("_on_reveal_pressed")
	await get_tree().process_frame
	var reveal := screen.session.get_reveal_projection()
	if reveal.is_empty():
		_fail("reveal projection was empty")
		return

	var blind_cell: Array = reveal["board"]["blind_cell"]
	var watermelon_cell: Array = reveal["watermelon_cell"]
	var distance := absi(int(blind_cell[0]) - int(watermelon_cell[0])) + absi(int(blind_cell[1]) - int(watermelon_cell[1]))
	if distance != 1:
		_fail("expected verified adjacent miss, got distance=%d" % distance)
		return

	var reveal_path := output_dir.path_join("reveal.png")
	if not await _capture_viewport(reveal_path):
		return

	if not _write_capture_files(output_dir):
		return

	print("MGSF_CAPTURE_OK dir=%s" % output_dir)
	get_tree().quit(0)


func _capture_viewport(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		_fail("captured viewport image is empty")
		return false
	if image.get_width() < 100 or image.get_height() < 100:
		_fail("captured viewport dimensions are unexpectedly small")
		return false
	var save_error := image.save_png(path)
	if save_error != OK:
		_fail("could not save PNG: %s" % path)
		return false
	return true


func _write_capture_files(output_dir: String) -> bool:
	var version := Engine.get_version_info()
	var source_head := OS.get_environment("MGSF_SOURCE_HEAD_SHA")
	if source_head.is_empty():
		source_head = "unknown"

	var capture := {
		"version": 1,
		"capture_id": CAPTURE_ID,
		"session_id": SESSION_ID,
		"source": {
			"repository": "madowaku/vertical-slice",
			"source_head_sha": source_head,
			"engine": "Godot %s" % str(version.get("string", "unknown")),
			"evidence_class": "recorded_gameplay_capture",
			"capture_adapter": "mgsf-c6-capture-scene",
			"scene": "res://scenes/debug/local_debug_slice.tscn",
			"scenario": "C6 one-cell-early near miss"
		},
		"media": [
			{
				"id": "frame-before-swing",
				"path": "before-swing.png",
				"kind": "frame",
				"at_ms": 1200
			},
			{
				"id": "frame-reveal",
				"path": "reveal.png",
				"kind": "frame",
				"at_ms": 1800
			}
		]
	}

	var timeline := [
		{
			"at_ms": 1200,
			"event_id": "capture-event-001",
			"kind": "observation",
			"label": "Blind player is one cell short before the swing.",
			"media_id": "frame-before-swing"
		},
		{
			"at_ms": 1400,
			"event_id": "capture-event-002",
			"kind": "input",
			"input": "SWING",
			"label": "Blind player confirms swing."
		},
		{
			"action": "SWING",
			"actual_result": "The swing misses one cell early.",
			"at_ms": 1600,
			"category": "near_miss",
			"confusion": 0.3,
			"event_id": "capture-event-003",
			"evidence_media_ids": ["frame-before-swing", "frame-reveal"],
			"expected_result": "The swing succeeds because the target has been reached.",
			"kind": "friction",
			"label": "Swing misses one cell early.",
			"media_id": "frame-before-swing",
			"reason": "The observed result conflicts with the modeled expectation of a hit.",
			"recommendation": "Keep the adjacent-miss reveal explicit and surface equally clear feedback at RESULT.",
			"result": "miss",
			"surprise": 0.6
		},
		{
			"at_ms": 1800,
			"event_id": "capture-event-004",
			"kind": "result",
			"label": "Reveal confirms the watermelon was next door.",
			"media_id": "frame-reveal"
		}
	]

	var capture_file := FileAccess.open(output_dir.path_join("capture.json"), FileAccess.WRITE)
	if capture_file == null:
		_fail("could not open capture.json")
		return false
	capture_file.store_string(JSON.stringify(capture, "  ") + "\n")
	capture_file.close()

	var timeline_file := FileAccess.open(output_dir.path_join("timeline.jsonl"), FileAccess.WRITE)
	if timeline_file == null:
		_fail("could not open timeline.jsonl")
		return false
	for event in timeline:
		timeline_file.store_line(JSON.stringify(event))
	timeline_file.close()
	return true


func _fail(message: String) -> void:
	push_error("MGSF_CAPTURE_FAIL %s" % message)
	get_tree().quit(1)
