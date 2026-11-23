extends GutTest
## 실제 물리(Jolt)로 손 잡기 확인
## - 손 힘보다 무거운 상품은 들어 올려지지 않음 (끌기만)
## - 가벼운 상품은 커서를 따라 올라옴
## - 평면 물리: z 이동이 없음
## - 쌓아둔 짐이 가만히 있을 때 떨지 않음

const FLOOR_SIZE: Vector3 = Vector3(20, 1, 4)
const LIFT_TARGET_HEIGHT: float = 1.0
const SETTLE_FRAMES: int = 40
const PULL_FRAMES: int = 90


## 매 물리 프레임 손 힘을 주는 작은 노드
class Puller:
	extends Node
	var item: ItemBody
	var target: Vector3
	var params: HandForce.Params

	func _physics_process(delta: float) -> void:
		params.physics_dt = delta
		var f: Vector3 = HandForce.compute(item.mass, item.global_position, item.linear_velocity, target, params)
		item.apply_central_force(f)


var _items: Dictionary


func before_all() -> void:
	_items = JsonData.load_by_id("res://data/items")


func before_each() -> void:
	Tuning.reset_to_defaults()
	PhysicsServer3D.area_set_param(get_viewport().world_3d.space, PhysicsServer3D.AREA_PARAM_GRAVITY,
		Tuning.v("gravity"))
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = PhysicsLayers.WORLD
	var col: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = FLOOR_SIZE
	col.shape = shape
	floor_body.add_child(col)
	floor_body.position = Vector3(0, -FLOOR_SIZE.y * 0.5, 0)
	add_child_autofree(floor_body)


func _spawn(item_id: String, pos: Vector3) -> ItemBody:
	var item: ItemBody = ItemBody.new()
	item.setup(_items[item_id], 1)
	item.position = pos
	item.spawn_grace = 0.0
	add_child_autofree(item)
	return item


func _pull(item: ItemBody, target: Vector3) -> Puller:
	var puller: Puller = Puller.new()
	puller.item = item
	puller.target = target
	puller.params = HandForce.Params.new()
	puller.params.spring = Tuning.v("hand_spring")
	puller.params.damping_ratio = Tuning.v("hand_damping")
	puller.params.max_force = Tuning.v("hand_max_force")
	puller.params.gravity = Tuning.v("gravity")
	puller.params.gravity_comp = Tuning.v("hand_gravity_comp")
	puller.params.drag_lift_ratio = Tuning.v("hand_drag_lift_ratio")
	add_child_autofree(puller)
	return puller


func test_heavy_item_is_not_lifted() -> void:
	var bale: ItemBody = _spawn("item_rice_bale", Vector3(0, 0.25, 0))
	await wait_physics_frames(SETTLE_FRAMES)
	var start_y: float = bale.global_position.y
	assert_false(HandRules.can_lift(bale.mass, Tuning.v("hand_max_force"), Tuning.v("gravity")),
		"기본값에서 쌀섬은 손 힘보다 무거움")
	_pull(bale, Vector3(0.0, LIFT_TARGET_HEIGHT, 0))
	await wait_physics_frames(PULL_FRAMES)
	assert_lt(bale.global_position.y - start_y, 0.03, "무거운 상품은 들리지 않음")


func test_heavy_item_can_be_dragged() -> void:
	var bale: ItemBody = _spawn("item_rice_bale", Vector3(0, 0.25, 0))
	await wait_physics_frames(SETTLE_FRAMES)
	var start: Vector3 = bale.global_position
	_pull(bale, start + Vector3(2.0, LIFT_TARGET_HEIGHT, 0))
	await wait_physics_frames(PULL_FRAMES)
	assert_gt(bale.global_position.x - start.x, 0.2, "끌기는 됨")
	assert_lt(bale.global_position.y - start.y, 0.03)


func test_light_item_is_lifted() -> void:
	var bowl: ItemBody = _spawn("item_white_porcelain", Vector3(0, 0.25, 0))
	await wait_physics_frames(SETTLE_FRAMES)
	_pull(bowl, Vector3(0, LIFT_TARGET_HEIGHT, 0))
	await wait_physics_frames(PULL_FRAMES)
	assert_almost_eq(bowl.global_position.y, LIFT_TARGET_HEIGHT, 0.1, "가벼운 상품은 커서 높이까지 올라옴")


func test_plane_physics_no_z_motion() -> void:
	var melon: ItemBody = _spawn("item_watermelon", Vector3(0, 1.0, 0))
	melon.linear_velocity = Vector3(1, 0, 3)
	melon.angular_velocity = Vector3(4, 4, 4)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_almost_eq(melon.global_position.z, 0.0, 0.0001)
	assert_almost_eq(melon.rotation.x, 0.0, 0.0001)
	assert_almost_eq(melon.rotation.y, 0.0, 0.0001)


func test_stack_at_rest_does_not_jitter() -> void:
	var salt: ItemBody = _spawn("item_salt_sack", Vector3(0, 0.17, 0))
	var onggi: ItemBody = _spawn("item_onggi", Vector3(0, 0.32 + 0.22, 0))
	var porcelain: ItemBody = _spawn("item_white_porcelain", Vector3(0, 0.32 + 0.42 + 0.21, 0))
	await wait_physics_frames(120)
	var before: Array[Vector3] = [salt.global_position, onggi.global_position, porcelain.global_position]
	await wait_physics_frames(60)
	var after: Array[Vector3] = [salt.global_position, onggi.global_position, porcelain.global_position]
	for i: int in range(3):
		assert_lt(before[i].distance_to(after[i]), 0.001, "가만히 있는 짐 %d 이 움직이지 않음" % i)
	assert_true(porcelain.sleeping or porcelain.linear_velocity.length() < 0.01, "잠들거나 거의 정지")


func test_drop_from_carrier_height_breaks_porcelain() -> void:
	var porcelain: ItemBody = _spawn("item_white_porcelain", Vector3(0, 1.2, 0))
	watch_signals(porcelain)
	await wait_physics_frames(90)
	assert_signal_emitted(porcelain, "broken", "1m 정도 높이에서 떨어진 백자는 깨짐")


func test_gentle_placement_does_not_damage() -> void:
	var porcelain: ItemBody = _spawn("item_white_porcelain", Vector3(0, 0.21, 0))
	await wait_physics_frames(90)
	assert_eq(porcelain.durability, porcelain.max_durability, "살짝 놓으면 멀쩡")
