extends GutTest
## 조정 값 저장소: 범위 자르기, 기본값, JSON 저장과 불러오기


func _make() -> TuningStore:
	var s: TuningStore = TuningStore.new()
	s.add_param({ "key": "gravity", "group": "world", "name_ko": "중력", "name_en": "Gravity",
		"default": 12.0, "min": 3.0, "max": 30.0, "step": 0.1 })
	s.add_param({ "key": "hand_spring", "group": "hand", "name_ko": "손", "name_en": "Hand",
		"default": 500.0, "min": 20.0, "max": 4000.0, "step": 10.0 })
	return s


func test_default_values() -> void:
	var s: TuningStore = _make()
	assert_eq(s.get_value("gravity"), 12.0)
	assert_eq(s.keys(), ["gravity", "hand_spring"] as Array[String])


func test_set_clamps() -> void:
	var s: TuningStore = _make()
	assert_eq(s.set_value("gravity", 100.0), 30.0)
	assert_eq(s.get_value("gravity"), 30.0)
	assert_eq(s.set_value("gravity", -5.0), 3.0)


func test_reset() -> void:
	var s: TuningStore = _make()
	s.set_value("gravity", 20.0)
	s.reset_to_defaults()
	assert_eq(s.get_value("gravity"), 12.0)


func test_json_round_trip() -> void:
	var a: TuningStore = _make()
	a.set_value("gravity", 15.5)
	a.set_value("hand_spring", 800.0)
	var b: TuningStore = _make()
	assert_eq(b.apply_json(a.to_json()), 2)
	assert_eq(b.get_value("gravity"), 15.5)
	assert_eq(b.get_value("hand_spring"), 800.0)


func test_apply_ignores_unknown_and_bad_values() -> void:
	var s: TuningStore = _make()
	var n: int = s.apply_dict({ "gravity": 9.0, "unknown": 1.0, "hand_spring": "abc" })
	assert_eq(n, 1)
	assert_eq(s.get_value("gravity"), 9.0)
	assert_eq(s.get_value("hand_spring"), 500.0)


func test_apply_bad_json() -> void:
	var s: TuningStore = _make()
	assert_eq(s.apply_json("not json"), -1)
