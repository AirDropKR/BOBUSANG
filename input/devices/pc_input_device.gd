extends Node
## 마우스와 키보드를 입력 동작으로 바꾼다. 실제 장치를 읽는 곳은 input/ 폴더뿐이다.

const DEVICE: StringName = &"pc"

@onready var _game_input: Node = get_parent()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_game_input.report_grab(mb.position)
		else:
			_game_input.report_release(mb.position)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.is_action(InputBindings.TOGGLE_DEBUG):
			_game_input.report_debug_toggle()
			return
		for slot: int in range(1, InputBindings.TOOL_SLOTS + 1):
			if event.is_action(InputBindings.tool_action(slot)):
				_game_input.report_tool(slot)


func _input(event: InputEvent) -> void:
	# 버튼 위에서 마우스를 놓아도 잡기가 풀리도록 놓기는 UI보다 먼저 본다.
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_game_input.report_release(mb.position)
	elif event is InputEventMouseMotion:
		_game_input.report_pointer_move((event as InputEventMouseMotion).position)
		_game_input.report_drag((event as InputEventMouseMotion).position)


func _process(_delta: float) -> void:
	# 키보드 포커스가 글 입력칸에 있으면 기울이기 등을 보내지 않는다.
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or focus is SpinBox:
		_game_input.report_lean(DEVICE, 0.0)
		_game_input.report_slow(DEVICE, false)
		_game_input.report_rotate(DEVICE, 0.0)
		return
	_game_input.report_lean(DEVICE, Input.get_axis(InputBindings.LEAN_LEFT, InputBindings.LEAN_RIGHT))
	_game_input.report_slow(DEVICE, Input.is_action_pressed(InputBindings.SLOW))
	_game_input.report_rotate(DEVICE, Input.get_axis(InputBindings.ROTATE_CCW, InputBindings.ROTATE_CW))
