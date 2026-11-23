extends GutTest
## 손 힘 규칙: 손 힘보다 무거운 상품은 들어 올려지지 않음

const G: float = 12.0
const MAX_FORCE: float = 260.0


func test_light_item_liftable() -> void:
	assert_true(HandRules.can_lift(1.2, MAX_FORCE, G))


func test_heavy_item_not_liftable() -> void:
	assert_false(HandRules.can_lift(30.0, MAX_FORCE, G), "무게 360N > 손 힘 260N")


func test_exact_weight_not_liftable() -> void:
	assert_false(HandRules.can_lift(MAX_FORCE / G, MAX_FORCE, G), "무게와 손 힘이 같으면 못 든다")


func test_upward_force_below_weight_for_heavy() -> void:
	var mass: float = 30.0
	var up: float = HandRules.max_upward_force(mass, MAX_FORCE, G, 0.5)
	assert_lt(up, mass * G)
	assert_almost_eq(up, mass * G * 0.5, 0.001)


func test_upward_force_ratio_clamped_below_one() -> void:
	var mass: float = 30.0
	var up: float = HandRules.max_upward_force(mass, MAX_FORCE, G, 5.0)
	assert_lt(up, mass * G, "비율을 크게 줘도 무게 이상 받쳐주지 않음")


func test_hand_force_never_lifts_heavy() -> void:
	var p: HandForce.Params = HandForce.Params.new()
	p.max_force = MAX_FORCE
	p.gravity = G
	p.spring = 4000.0
	var mass: float = 30.0
	# 목표가 바로 위 1m: 위쪽 힘이 무게보다 작아야 한다
	var f: Vector3 = HandForce.compute(mass, Vector3.ZERO, Vector3.ZERO, Vector3(0, 1, 0), p)
	assert_lt(f.y, mass * G)


func test_hand_force_limited_by_max_force() -> void:
	var p: HandForce.Params = HandForce.Params.new()
	p.max_force = 100.0
	p.gravity = G
	p.spring = 4000.0
	var f: Vector3 = HandForce.compute(2.0, Vector3.ZERO, Vector3.ZERO, Vector3(5, 5, 0), p)
	assert_true(f.length() <= 100.0 + 0.001)


func test_hand_force_light_item_lifts() -> void:
	var p: HandForce.Params = HandForce.Params.new()
	p.max_force = MAX_FORCE
	p.gravity = G
	var mass: float = 1.2
	var f: Vector3 = HandForce.compute(mass, Vector3.ZERO, Vector3.ZERO, Vector3(0, 1, 0), p)
	assert_gt(f.y, mass * G, "가벼운 물건은 무게보다 큰 힘으로 들어 올린다")


func test_hand_force_ignores_z() -> void:
	var p: HandForce.Params = HandForce.Params.new()
	var f: Vector3 = HandForce.compute(1.0, Vector3.ZERO, Vector3(0, 0, 3), Vector3(0, 0, 5), p)
	assert_eq(f.z, 0.0)


func test_hold_torque_points_to_target() -> void:
	assert_gt(HandForce.hold_torque(0.1, 0.0, 0.0, 1.0, 8.0, 100.0), 0.0)
	assert_lt(HandForce.hold_torque(0.1, 0.0, 0.0, -1.0, 8.0, 100.0), 0.0)
	assert_eq(HandForce.hold_torque(0.1, 0.0, 0.0, 1.0, 0.0, 100.0), 0.0)
