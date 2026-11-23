class_name InputBindings
extends RefCounted
## 동작 이름과 기본 키 배치. 게임 코드는 이 이름(동작)만 알고, 키나 버튼은 모른다.

const GRAB: StringName = &"grab"
const LEAN_LEFT: StringName = &"lean_left"
const LEAN_RIGHT: StringName = &"lean_right"
const SLOW: StringName = &"slow"
const ROTATE_CCW: StringName = &"rotate_ccw"
const ROTATE_CW: StringName = &"rotate_cw"
const TOGGLE_DEBUG: StringName = &"toggle_debug"
const TOOL_PREFIX: String = "use_tool_"
const TOOL_SLOTS: int = 4

## 동작 -> 기본 키 (PC)
const DEFAULT_KEYS: Dictionary = {
	&"lean_left": [KEY_A, KEY_LEFT],
	&"lean_right": [KEY_D, KEY_RIGHT],
	&"slow": [KEY_SPACE],
	&"rotate_ccw": [KEY_Q],
	&"rotate_cw": [KEY_E],
	&"toggle_debug": [KEY_F1, KEY_QUOTELEFT],
}


static func tool_action(slot: int) -> StringName:
	return StringName(TOOL_PREFIX + str(slot))


## InputMap 에 동작이 없으면 기본 배치로 만든다. 이미 있으면 (사용자가 바꾼 배치) 건드리지 않는다.
static func ensure_actions() -> void:
	for action: StringName in DEFAULT_KEYS.keys():
		_ensure_key_action(action, DEFAULT_KEYS[action])
	for slot: int in range(1, TOOL_SLOTS + 1):
		_ensure_key_action(tool_action(slot), [KEY_0 + slot])
	if not InputMap.has_action(GRAB):
		InputMap.add_action(GRAB)
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(GRAB, mouse_event)


static func _ensure_key_action(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode: int in keys:
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = keycode
		InputMap.action_add_event(action, key_event)
