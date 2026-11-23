extends Node
## 자동 로드 "GameInput". 입력 동작(grab, drag, release, lean, slow, use_tool, rotate)을 게임에 알려준다.
## 장치(마우스와 키보드, 터치, 자이로)는 각각의 연결 노드가 이 노드의 report_* 함수를 불러 동작을 전한다.
## 게임 코드는 Input 이나 InputEvent 를 직접 읽지 않고 이 노드의 신호와 값만 쓴다.

## 잡기 시작 (화면 좌표)
signal grab_started(screen_position: Vector2)
## 잡은 채로 움직임
signal drag_moved(screen_position: Vector2)
## 놓기
signal released(screen_position: Vector2)
## 도구 사용 (1부터 시작하는 칸 번호)
signal tool_used(slot: int)
## 조정 패널 열고 닫기
signal debug_toggled

const PcInputDevice: GDScript = preload("res://input/devices/pc_input_device.gd")
const TouchInputDevice: GDScript = preload("res://input/devices/touch_input_device.gd")

## 장치별 몸 기울이기 값. 가장 큰 값을 쓴다 (-1 왼쪽 ~ 1 오른쪽).
var _lean_by_device: Dictionary = {}
var _slow_by_device: Dictionary = {}
var _rotate_by_device: Dictionary = {}
var _pointer_position: Vector2 = Vector2.ZERO
var _pointer_down: bool = false
## 동작을 막아 둘 때 (예: UI 위에 있을 때) true
var enabled: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.ensure_actions()
	add_child(PcInputDevice.new())
	add_child(TouchInputDevice.new())


# --- 게임 코드가 읽는 값 ---------------------------------------------------

## 몸 기울이기 (-1 왼쪽 ~ 1 오른쪽)
func get_lean() -> float:
	return _combined(_lean_by_device) if enabled else 0.0


func is_slow_held() -> bool:
	if not enabled:
		return false
	for device: Variant in _slow_by_device.keys():
		if _slow_by_device[device]:
			return true
	return false


## 잡은 물건 회전 (-1 반시계 ~ 1 시계)
func get_rotate() -> float:
	return _combined(_rotate_by_device) if enabled else 0.0


func get_pointer_position() -> Vector2:
	return _pointer_position


func is_pointer_down() -> bool:
	return _pointer_down


# --- 장치 연결 노드가 부르는 함수 --------------------------------------------

func report_grab(screen_position: Vector2) -> void:
	_pointer_position = screen_position
	if not enabled:
		return
	_pointer_down = true
	grab_started.emit(screen_position)


func report_drag(screen_position: Vector2) -> void:
	_pointer_position = screen_position
	if _pointer_down:
		drag_moved.emit(screen_position)


func report_pointer_move(screen_position: Vector2) -> void:
	_pointer_position = screen_position


func report_release(screen_position: Vector2) -> void:
	_pointer_position = screen_position
	if not _pointer_down:
		return
	_pointer_down = false
	released.emit(screen_position)


func report_lean(device: StringName, value: float) -> void:
	_lean_by_device[device] = clampf(value, -1.0, 1.0)


func report_slow(device: StringName, held: bool) -> void:
	_slow_by_device[device] = held


func report_rotate(device: StringName, value: float) -> void:
	_rotate_by_device[device] = clampf(value, -1.0, 1.0)


func report_tool(slot: int) -> void:
	if enabled:
		tool_used.emit(slot)


func report_debug_toggle() -> void:
	debug_toggled.emit()


func _combined(by_device: Dictionary) -> float:
	var best: float = 0.0
	for device: Variant in by_device.keys():
		var v: float = by_device[device]
		if absf(v) > absf(best):
			best = v
	return best
