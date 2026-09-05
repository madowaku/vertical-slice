extends PhaseATestBase


const BLIND_FORBIDDEN_KEYS := [
	"facing",
	"blind_facing",
	"blind_cell",
	"watermelon",
	"watermelon_cell",
	"board",
	"obstacles",
	"patterns",
	"sensor",
	"sensor_histories",
]

const GUIDE_FORBIDDEN_KEYS := [
	"facing",
	"blind_facing",
	"blind_cell",
	"watermelon",
	"watermelon_cell",
	"board",
	"obstacles",
	"patterns",
	"sensor_histories",
]


func run() -> Dictionary:
	var session := LocalDebugSession.new()
	expect_true(session.start_round(1), "privacy test round starts")

	_assert_active_projections_safe(session, "CONSULT")

	var begin_walk := session.begin_walk(GameTypes.BlindAction.RIGHT)
	expect_true(bool(begin_walk.get("accepted", false)), "walk begins for WALKING privacy check")
	expect_eq(session.round_controller.state, GameTypes.RoundState.WALKING, "privacy test enters WALKING")
	_assert_active_projections_safe(session, "WALKING before step")

	var live_step := session.advance_step()
	expect_true(bool(live_step.get("accepted", false)), "privacy test advances one step")
	_assert_active_projections_safe(session, "after live step")
	if session.round_controller.state == GameTypes.RoundState.WALKING:
		var stopped := session.stop_walk()
		expect_true(bool(stopped.get("accepted", false)), "privacy test stops walk")
	_assert_active_projections_safe(session, "CONSULT after STOP or BUMP")

	if session.round_controller.state != GameTypes.RoundState.CONSULT:
		return make_result("Projection safety")

	var request := session.request_swing()
	expect_true(bool(request.get("accepted", false)), "privacy test enters DECISION")
	expect_eq(session.round_controller.state, GameTypes.RoundState.DECISION, "privacy test DECISION active")
	_assert_active_projections_safe(session, "DECISION")

	var swing := session.confirm_swing()
	expect_true(bool(swing.get("accepted", false)), "privacy test confirms swing")
	expect_eq(session.round_controller.state, GameTypes.RoundState.RESULT, "privacy test RESULT active")
	_assert_active_projections_safe(session, "RESULT")

	expect_true(session.begin_reveal(), "privacy test enters reveal")
	var reveal := session.get_reveal_projection()
	expect_true(reveal.has("board"), "REVEAL deliberately exposes board")
	expect_true(reveal.has("watermelon_cell"), "REVEAL deliberately exposes watermelon cell")
	expect_true(reveal["board"].has("blind_cell"), "REVEAL deliberately exposes blind cell")
	expect_true(reveal["board"].has("blind_facing"), "REVEAL deliberately exposes blind facing")

	return make_result("Projection safety")


func _assert_active_projections_safe(session: LocalDebugSession, phase_label: String) -> void:
	var blind := session.get_projection(GameTypes.PlayerRole.BLIND)
	for key in BLIND_FORBIDDEN_KEYS:
		expect_false(_contains_key_recursive(blind, key), "%s blind projection excludes %s recursively" % [phase_label, key])

	for role in [
		GameTypes.PlayerRole.GUIDE_SIDE,
		GameTypes.PlayerRole.GUIDE_STEP,
		GameTypes.PlayerRole.GUIDE_PATTERN,
	]:
		var guide := session.get_projection(role)
		for key in GUIDE_FORBIDDEN_KEYS:
			expect_false(_contains_key_recursive(guide, key), "%s guide %d projection excludes %s recursively" % [phase_label, role, key])
		expect_true(guide.has("sensor"), "%s guide %d has one sensor envelope" % [phase_label, role])
		expect_true(guide["sensor"].has("kind"), "%s guide %d sensor has kind" % [phase_label, role])
		expect_true(guide["sensor"].has("value"), "%s guide %d sensor has value" % [phase_label, role])
		expect_true(guide["sensor"].has("history"), "%s guide %d sensor has own history" % [phase_label, role])


func _contains_key_recursive(value: Variant, key_name: String) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		var dictionary: Dictionary = value
		if dictionary.has(key_name):
			return true
		for nested_value in dictionary.values():
			if _contains_key_recursive(nested_value, key_name):
				return true
		return false

	if typeof(value) == TYPE_ARRAY:
		var array: Array = value
		for nested_value in array:
			if _contains_key_recursive(nested_value, key_name):
				return true
	return false
