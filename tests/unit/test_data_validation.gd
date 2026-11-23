extends GutTest
## 상품 JSON 스키마 검증 (그리고 나머지 data/ 파일)


func _valid_item() -> Dictionary:
	return {
		"id": "item_test", "name_ko": "시험", "name_en": "Test", "base_price": 10, "mass": 1.0,
		"collider": { "shape": "box", "size": [0.2, 0.2, 0.2] },
		"friction": 0.5, "bounce": 0.1, "durability": 10, "damage_threshold": 1.0, "break_impulse": 5.0,
		"tags": [], "special": null,
	}


func test_all_project_data_valid() -> void:
	var errors: Array[String] = DataValidator.validate_all()
	assert_eq(errors, [] as Array[String], "\n".join(errors))


func test_ten_items_exist_with_unique_ids() -> void:
	var items: Dictionary = JsonData.load_by_id("res://data/items")
	assert_eq(items.size(), 10)


func test_items_have_different_physics() -> void:
	var items: Dictionary = JsonData.load_by_id("res://data/items")
	var masses: Dictionary = {}
	var shapes: Dictionary = {}
	for item: Dictionary in items.values():
		masses[item["mass"]] = true
		shapes[item["collider"]["shape"]] = true
	assert_gte(masses.size(), 7, "상품마다 질량이 다양해야 함")
	assert_eq(shapes.size(), 4, "상자, 원통, 구, 캡슐 모두 사용")


func test_valid_item_passes() -> void:
	assert_eq(DataValidator.validate_item(_valid_item()), [] as Array[String])


func test_missing_name_fails() -> void:
	var item: Dictionary = _valid_item()
	item.erase("name_en")
	assert_gt(DataValidator.validate_item(item).size(), 0)


func test_bad_id_prefix_fails() -> void:
	var item: Dictionary = _valid_item()
	item["id"] = "test"
	assert_gt(DataValidator.validate_item(item).size(), 0)


func test_bad_shape_fails() -> void:
	var item: Dictionary = _valid_item()
	item["collider"] = { "shape": "mesh" }
	assert_gt(DataValidator.validate_item(item).size(), 0, "복잡한 충돌 모양 금지")


func test_non_positive_mass_fails() -> void:
	var item: Dictionary = _valid_item()
	item["mass"] = 0
	assert_gt(DataValidator.validate_item(item).size(), 0)


func test_break_below_threshold_fails() -> void:
	var item: Dictionary = _valid_item()
	item["break_impulse"] = 0.5
	assert_gt(DataValidator.validate_item(item).size(), 0)


func test_bad_axis_fails() -> void:
	var item: Dictionary = _valid_item()
	item["collider"] = { "shape": "cylinder", "radius": 0.1, "height": 0.2, "axis": "w" }
	assert_gt(DataValidator.validate_item(item).size(), 0)


func test_bounce_out_of_range_fails() -> void:
	var item: Dictionary = _valid_item()
	item["bounce"] = 1.5
	assert_gt(DataValidator.validate_item(item).size(), 0)


func test_not_object_fails() -> void:
	assert_gt(DataValidator.validate_item([1, 2]).size(), 0)


func test_road_unknown_segment_fails() -> void:
	var road: Dictionary = { "id": "road_x", "name_ko": "길", "name_en": "Road", "segments": ["flat", "lava"] }
	assert_gt(DataValidator.validate_road(road, ["flat"]).size(), 0)


func _valid_market() -> Dictionary:
	return {
		"id": "market_x", "name_ko": "장", "name_en": "Market", "market_days": [2, 7],
		"sells": { "item_white_porcelain": 0.6 }, "stock": { "item_white_porcelain": 2 },
		"buys": { "item_onggi": 1.2 }, "routes": [{ "to": "market_y", "road": "road_a" }],
	}


func _validate_market(market: Dictionary) -> Array[String]:
	return DataValidator.validate_market(market, ["item_white_porcelain", "item_onggi"], ["road_a"],
		["market_x", "market_y"])


func test_valid_market_passes() -> void:
	assert_eq(_validate_market(_valid_market()), [] as Array[String])


func test_market_unknown_item_fails() -> void:
	var m: Dictionary = _valid_market()
	m["buys"] = { "item_dragon_egg": 2.0 }
	assert_gt(_validate_market(m).size(), 0)


func test_market_stock_not_sold_fails() -> void:
	var m: Dictionary = _valid_market()
	m["stock"] = { "item_onggi": 1 }
	assert_gt(_validate_market(m).size(), 0)


func test_market_bad_route_fails() -> void:
	var m: Dictionary = _valid_market()
	m["routes"] = [{ "to": "market_x", "road": "road_nope" }]
	assert_eq(_validate_market(m).size(), 2, "자기 자신으로 가는 길, 없는 길")


func test_market_bad_day_fails() -> void:
	var m: Dictionary = _valid_market()
	m["market_days"] = [0, 11]
	assert_eq(_validate_market(m).size(), 2)


func test_every_market_has_route_and_stall() -> void:
	var markets: Dictionary = JsonData.load_by_id("res://data/markets")
	assert_gte(markets.size(), 2)
	for market: Dictionary in markets.values():
		assert_gt((market["routes"] as Array).size(), 0, "%s: 갈 길이 있음" % market["id"])
		assert_gt((market["sells"] as Dictionary).size(), 0, "%s: 파는 상품이 있음" % market["id"])
