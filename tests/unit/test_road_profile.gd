extends GutTest
## 길 높이 선: 구간 이어 붙이기, 순서 바꾸기, 높이 계산

const SEGMENT_TYPES: Dictionary = {
	"flat": { "id": "flat", "length": 10.0, "params": {} },
	"rocks": { "id": "rocks", "length": 8.0, "params": { "bump_height": 0.06, "bump_spacing": 0.5, "bump_jitter": 0.3 } },
	"pothole": { "id": "pothole", "length": 4.0, "params": { "depth": 0.2, "width": 1.0, "edge": 0.1 } },
	"uphill": { "id": "uphill", "length": 10.0, "params": { "rise": 2.0 } },
	"downhill": { "id": "downhill", "length": 10.0, "params": { "rise": -2.0 } },
}


func _build(order: Array, bump_scale: float = 1.0) -> RoadProfile:
	var p: RoadProfile = RoadProfile.new()
	p.build(RoadProfile.resolve_segments(order, SEGMENT_TYPES), 1, bump_scale)
	return p


func test_segments_in_order() -> void:
	var p: RoadProfile = _build(["flat", "rocks", "uphill"])
	assert_eq(p.segments.size(), 3)
	assert_eq(p.segments[0]["type"], "flat")
	assert_eq(p.segments[1]["start_x"], 10.0)
	assert_eq(p.segments[2]["start_x"], 18.0)
	assert_eq(p.finish_x, 28.0)


func test_reordered_segments() -> void:
	var a: RoadProfile = _build(["uphill", "flat"])
	var b: RoadProfile = _build(["flat", "uphill"])
	assert_almost_eq(a.height_at(15.0), 2.0, 0.001, "오르막 먼저면 평지가 높다")
	assert_almost_eq(b.height_at(5.0), 0.0, 0.001)
	assert_almost_eq(b.height_at(b.finish_x), 2.0, 0.001)


func test_uphill_and_downhill() -> void:
	var p: RoadProfile = _build(["uphill", "downhill"])
	assert_almost_eq(p.height_at(10.0), 2.0, 0.001)
	assert_almost_eq(p.height_at(20.0), 0.0, 0.001)
	assert_gt(p.height_at(5.0), 0.5)


func test_pothole_dips() -> void:
	var p: RoadProfile = _build(["pothole"])
	assert_almost_eq(p.height_at(2.0), -0.2, 0.001, "구덩이 가운데는 깊이만큼 낮다")
	assert_almost_eq(p.height_at(0.2), 0.0, 0.001)


func test_rocks_have_bumps_and_scale() -> void:
	var p: RoadProfile = _build(["rocks"], 1.0)
	var flat: RoadProfile = _build(["rocks"], 0.0)
	var max_h: float = 0.0
	var max_flat: float = 0.0
	for i: int in range(800):
		var x: float = i * 0.01
		max_h = maxf(max_h, p.height_at(x))
		max_flat = maxf(max_flat, flat.height_at(x))
	assert_gt(max_h, 0.02)
	assert_lte(max_h, 0.06 + 0.001)
	assert_almost_eq(max_flat, 0.0, 0.0001, "요철 세기 0이면 평평")


func test_same_seed_same_road() -> void:
	var a: RoadProfile = _build(["rocks"])
	var b: RoadProfile = _build(["rocks"])
	assert_eq(a.points, b.points)


func test_overrides_and_unknown() -> void:
	var errors: Array = []
	var resolved: Array[Dictionary] = RoadProfile.resolve_segments(
		[{ "type": "rocks", "length": 3.0, "bump_height": 0.2 }, "nope"], SEGMENT_TYPES, errors)
	assert_eq(resolved.size(), 1)
	assert_eq(resolved[0]["length"], 3.0)
	assert_eq(resolved[0]["params"]["bump_height"], 0.2)
	assert_eq(errors.size(), 1)


func test_parse_order_text() -> void:
	assert_eq(RoadProfile.parse_order_text(" flat, rocks ,,pothole "), ["flat", "rocks", "pothole"])


func test_start_and_end_pads() -> void:
	var p: RoadProfile = _build(["flat"])
	assert_lt(p.start_x(), 0.0)
	assert_gt(p.end_x(), p.finish_x)
	assert_eq(p.segment_type_at(-1.0), "")
	assert_eq(p.segment_type_at(5.0), "flat")


func test_simplify_removes_collinear() -> void:
	var pts: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(2, 0), Vector2(3, 1)])
	var out: PackedVector2Array = RoadProfile.simplify(pts, 0.001)
	assert_eq(out.size(), 3)
