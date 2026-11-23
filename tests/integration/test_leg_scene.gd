extends GutTest
## M2 구간 씬과 M1 샌드박스가 뜨는지 (물리 테스트 씬이 계속 살아 있는지 확인)

const LEG_SCENE: String = "res://game/leg_scene.tscn"
const SANDBOX_SCENE: String = "res://debug/m1_sandbox.tscn"


func test_leg_scene_builds_stall_with_prices() -> void:
	var scene: Node = (load(LEG_SCENE) as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(5)
	var market: Dictionary = scene.origin
	var expected: int = 0
	for item_id: String in (market["sells"] as Dictionary).keys():
		expected += MarketRules.stock_count(item_id, market, scene.trade.economy)
	assert_eq(scene.world.items.size(), expected, "좌판에 재고 개수만큼 상품")
	assert_eq(scene.world.items_on_carrier().size(), 0, "처음엔 지게가 비어 있음")
	assert_eq(scene.phase, 0)


func test_leg_scene_depart_charges_for_carrier_items() -> void:
	var scene: Node = (load(LEG_SCENE) as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(5)
	var world: TripWorld = scene.world
	var item: ItemBody = world.items[0]
	item.global_position = world.porter.carrier.global_position + Vector3(0, item.half_extents_2d().y + 0.02, 0)
	await wait_physics_frames(30)
	var money_before: int = scene.trade.ledger.money
	scene._on_start_pressed()
	assert_eq(scene.phase, 1, "출발함")
	assert_eq(scene.trade.ledger.money, money_before - scene.trade.buy_price(item.item_id))
	assert_eq(world.items.size(), 1, "사지 않은 상품은 좌판에 두고 감")


func test_m1_sandbox_still_loads_all_items() -> void:
	var scene: Node = (load(SANDBOX_SCENE) as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(5)
	assert_eq(scene.world.items.size(), 10, "M1 샌드박스에 상품 10개")
