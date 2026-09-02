extends PhaseATestBase


func run() -> Dictionary:
	for index in range(1, 13):
		var board := BoardManager.load_board(BoardManager.preset_path(index))
		expect_true(board != null, "preset %02d loads" % index)
		if board == null:
			continue
		var errors := BoardManager.validate_definition(board)
		expect_true(errors.is_empty(), "preset %02d validates: %s" % [index, str(errors)])
		var distance := BoardManager.shortest_path_distance(board.blind_start, board.watermelon, board.obstacles)
		expect_true(distance >= 3 and distance <= 6, "preset %02d shortest path in range" % index)

	var overlap := BoardManager.load_board(BoardManager.preset_path(1))
	overlap.watermelon = overlap.blind_start
	var overlap_errors := BoardManager.validate_definition(overlap)
	expect_true(overlap_errors.has("watermelon overlaps blind start"), "overlap fixture fails for expected reason")

	var duplicate := BoardManager.load_board(BoardManager.preset_path(1))
	duplicate.obstacle_entry_count += 1
	var duplicate_errors := BoardManager.validate_definition(duplicate)
	expect_true(duplicate_errors.has("duplicate obstacle cell"), "duplicate obstacle fixture fails for expected reason")

	var missing_patterns := BoardManager.load_board(BoardManager.preset_path(1))
	missing_patterns.patterns.clear()
	var pattern_errors := BoardManager.validate_definition(missing_patterns)
	expect_true(pattern_errors.has("pattern cell count must be 36"), "missing pattern fixture fails for expected reason")

	return make_result("Board validation")
