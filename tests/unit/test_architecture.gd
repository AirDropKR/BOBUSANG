extends GutTest
## 구조 규칙 검사
## - 입력 동작이 장치와 분리되어 있음: input/ 밖의 게임 코드는 Input, InputEvent 를 직접 읽지 않음
## - core/ 는 Node, 물리, 입력, 렌더링 API 를 쓰지 않음

const GAME_CODE_DIRS: Array[String] = ["res://core", "res://physics", "res://view", "res://ui", "res://debug"]
const INPUT_PATTERN: String = "\\bInput\\.|\\bInputEvent|func _input\\(|func _unhandled_input\\(|func _unhandled_key_input\\(|func _shortcut_input\\(|\\bInputMap\\."
const CORE_FORBIDDEN_PATTERN: String = "extends\\s+(Node|Node2D|Node3D|Control|CanvasItem|RigidBody3D|StaticBody3D|Area3D)\\b|PhysicsServer|RenderingServer|DisplayServer|\\bInput\\b|get_tree\\(|RigidBody|Camera3D|Viewport"


func _scripts_in(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub: String in dir.get_directories():
		out.append_array(_scripts_in(dir_path.path_join(sub)))
	return out


## 주석(# 뒤)을 뺀 코드 줄에서 찾는다
func _find(path: String, regex: RegEx) -> Array[String]:
	var hits: Array[String] = []
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	for i: int in range(lines.size()):
		var line: String = lines[i]
		var hash_pos: int = line.find("#")
		var code: String = line if hash_pos < 0 else line.substr(0, hash_pos)
		if regex.search(code) != null:
			hits.append("%s:%d %s" % [path, i + 1, line.strip_edges()])
	return hits


func test_game_code_does_not_read_input_devices() -> void:
	var regex: RegEx = RegEx.create_from_string(INPUT_PATTERN)
	var hits: Array[String] = []
	var count: int = 0
	for dir_path: String in GAME_CODE_DIRS:
		for path: String in _scripts_in(dir_path):
			count += 1
			hits.append_array(_find(path, regex))
	assert_gt(count, 10, "검사한 스크립트가 있어야 함")
	assert_eq(hits, [] as Array[String], "\n".join(hits))


func test_input_layer_exposes_actions() -> void:
	for action: StringName in [InputBindings.GRAB, InputBindings.LEAN_LEFT, InputBindings.LEAN_RIGHT,
			InputBindings.SLOW, InputBindings.ROTATE_CCW, InputBindings.ROTATE_CW, InputBindings.tool_action(1)]:
		assert_true(InputMap.has_action(action), "동작 %s 있음" % action)
	for sig: String in ["grab_started", "drag_moved", "released", "tool_used"]:
		assert_true(GameInput.has_signal(sig), "GameInput 신호 %s" % sig)


func test_game_input_reports_drive_actions() -> void:
	var got: Array = []
	var on_grab: Callable = func(pos: Vector2) -> void: got.append(["grab", pos])
	var on_release: Callable = func(pos: Vector2) -> void: got.append(["release", pos])
	GameInput.grab_started.connect(on_grab)
	GameInput.released.connect(on_release)
	GameInput.report_grab(Vector2(10, 20))
	GameInput.report_release(Vector2(30, 40))
	GameInput.report_lean(&"test_device", -1.0)
	assert_eq(GameInput.get_lean(), -1.0)
	GameInput.report_lean(&"test_device", 0.0)
	GameInput.grab_started.disconnect(on_grab)
	GameInput.released.disconnect(on_release)
	assert_eq(got, [["grab", Vector2(10, 20)], ["release", Vector2(30, 40)]])


func test_core_uses_no_engine_runtime_api() -> void:
	var regex: RegEx = RegEx.create_from_string(CORE_FORBIDDEN_PATTERN)
	var hits: Array[String] = []
	for path: String in _scripts_in("res://core"):
		hits.append_array(_find(path, regex))
	assert_eq(hits, [] as Array[String], "\n".join(hits))


func test_no_hardcoded_korean_ui_text_in_ui_code() -> void:
	# 화면 문구는 data/locale 에서 읽는다: ui/ 코드의 문자열에 한글이 있으면 안 된다 (주석은 괜찮음)
	# 개발자용 로그(push_error 등)는 예외
	var regex: RegEx = RegEx.create_from_string("\"[^\"]*[가-힣][^\"]*\"")
	var log_regex: RegEx = RegEx.create_from_string("push_error|push_warning|printerr|print\\(")
	var hits: Array[String] = []
	for dir_path: String in ["res://ui", "res://debug", "res://view"]:
		for path: String in _scripts_in(dir_path):
			for hit: String in _find(path, regex):
				if log_regex.search(hit) == null:
					hits.append(hit)
	assert_eq(hits, [] as Array[String], "\n".join(hits))
