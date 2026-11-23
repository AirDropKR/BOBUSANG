class_name HandForce
extends RefCounted
## 손이 잡은 물건에 줄 힘 계산 (순수 계산이라 테스트하기 쉽게 따로 둔다).
## 스프링-감쇠 힘 + 무게 받쳐주기, 전체 크기는 손 최대 힘으로 자르고, 못 드는 물건은 위쪽 힘을 무게보다 작게 자른다.

## 스프링 고유 진동수 한계 = STABILITY_FACTOR / 물리 틱 간격. 아주 가벼운 물건이 떨지 않게.
const STABILITY_FACTOR: float = 0.5


class Params:
	extends RefCounted
	var spring: float = 500.0
	var damping_ratio: float = 0.9
	var max_force: float = 260.0
	var gravity: float = 12.0
	var gravity_comp: float = 1.0
	var drag_lift_ratio: float = 0.5
	var physics_dt: float = 1.0 / 60.0


## mass 물체가 position, velocity 일 때 target 으로 끌어당기는 힘 (z 성분은 0)
static func compute(mass: float, position: Vector3, velocity: Vector3, target: Vector3, p: Params) -> Vector3:
	var max_omega: float = STABILITY_FACTOR / maxf(p.physics_dt, 0.0001)
	var omega: float = minf(sqrt(p.spring / mass), max_omega)
	var k: float = mass * omega * omega
	var c: float = 2.0 * p.damping_ratio * mass * omega
	var error: Vector3 = target - position
	error.z = 0.0
	var vel: Vector3 = velocity
	vel.z = 0.0
	var force: Vector3 = error * k - vel * c
	force.y += mass * p.gravity * p.gravity_comp
	force = force.limit_length(p.max_force)
	var max_up: float = HandRules.max_upward_force(mass, p.max_force, p.gravity, p.drag_lift_ratio)
	if force.y > max_up:
		force.y = max_up
	return force


## 잡은 물건 각도를 target_angle 로 유지하는 토크 (z축). inertia 는 z축 관성 모멘트.
static func hold_torque(inertia: float, angle: float, angular_velocity: float, target_angle: float,
		frequency: float, max_torque: float) -> float:
	if frequency <= 0.0 or inertia <= 0.0:
		return 0.0
	var err: float = wrapf(target_angle - angle, -PI, PI)
	var torque: float = inertia * (frequency * frequency * err - 2.0 * frequency * angular_velocity)
	return clampf(torque, -max_torque, max_torque)
