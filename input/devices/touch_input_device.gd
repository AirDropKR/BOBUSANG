extends Node
## 터치와 자이로 연결 자리 (M7에서 채운다).
## 지금은 프로젝트 설정의 "터치로 마우스 흉내"가 켜져 있어서 한 손가락 끌기는 마우스 연결로 동작한다.
##
## 할 일
## - InputEventScreenTouch / InputEventScreenDrag 를 report_grab / report_drag / report_release 로 연결
##   (손가락 하나만 손으로 쓰고, 나머지 손가락은 화면 버튼용)
## - 화면 좌우 버튼 -> report_lean(DEVICE, -1 또는 1)
## - 늦추기 버튼 -> report_slow(DEVICE, true/false)
## - 도구 버튼 -> report_tool(slot)
## - 자이로: Input.get_gravity() 로 폰 기울기를 읽어 report_lean(GYRO_DEVICE, 값) (켜고 끄는 설정 필요)

const DEVICE: StringName = &"touch"
const GYRO_DEVICE: StringName = &"gyro"

## 터치 연결을 켜면 터치 흉내 마우스와 겹치지 않게 프로젝트 설정을 바꿔야 한다.
var active: bool = false

@onready var _game_input: Node = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		pass  # TODO(M7): 손가락 하나를 손으로 연결
	elif event is InputEventScreenDrag:
		pass  # TODO(M7)
