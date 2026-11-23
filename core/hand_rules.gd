class_name HandRules
extends RefCounted
## 손(잡기) 규칙. 물리 힘 계산은 physics/hand 쪽에서 하고, 여기서는 "들 수 있나"만 정한다.


## 손 최대 힘으로 이 질량을 들어 올릴 수 있는가.
## 무게(질량 x 중력)가 손 최대 힘보다 작아야 들 수 있다. 같거나 크면 끌기만 된다.
static func can_lift(mass: float, hand_max_force: float, gravity: float) -> bool:
	return mass * gravity < hand_max_force


## 들 수 없는 물건에 줄 수 있는 위쪽 힘의 한계.
## 무게의 drag_lift_ratio(1 미만) 만큼만 받쳐 주어서, 바닥에서 떨어지지 않고 끌리기만 하게 한다.
static func max_upward_force(mass: float, hand_max_force: float, gravity: float, drag_lift_ratio: float) -> float:
	var weight: float = mass * gravity
	if can_lift(mass, hand_max_force, gravity):
		return hand_max_force
	return minf(weight * clampf(drag_lift_ratio, 0.0, 0.99), hand_max_force)
