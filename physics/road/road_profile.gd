class_name RoadProfile
extends RefCounted
## 옆모습 길의 높이 선(꺾은선). 구간 데이터를 이어 붙여 만든다. 물리 노드는 모르는 순수 계산.
## x는 오른쪽(진행 방향), y는 위. 구간은 x=0 에서 시작하고, 앞에 출발 마당, 뒤에 도착 마당을 붙인다.

## 출발 마당 길이 (쌓기 선반이 놓이는 평지)
const START_PAD_LENGTH: float = 9.0
## 도착 뒤 평지 길이
const END_PAD_LENGTH: float = 10.0
## 기본 높이 선 간격
const BASE_STEP: float = 0.25
## 돌길 요철 높이 선 간격
const BUMP_STEP: float = 0.04
## 단순화할 때 허용하는 높이 오차
const SIMPLIFY_TOLERANCE: float = 0.0015

var points: PackedVector2Array = PackedVector2Array()
## [{ "type": String, "start_x": float, "end_x": float }]
var segments: Array[Dictionary] = []
var finish_x: float = 0.0


## 길 정의와 구간 종류 정의로 구간 목록을 만든다.
## road_segments: 문자열("rocks") 또는 { "type": "rocks", "length": 16, "bump_height": 0.1 } 의 배열
## segment_types: { id: { "length": float, "params": {...} } }
## 모르는 구간 종류는 건너뛰고 errors 에 넣는다.
static func resolve_segments(road_segments: Array, segment_types: Dictionary, errors: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw: Variant in road_segments:
		var type_id: String = ""
		var overrides: Dictionary = {}
		if typeof(raw) == TYPE_STRING:
			type_id = (raw as String).strip_edges()
		elif typeof(raw) == TYPE_DICTIONARY:
			overrides = raw
			type_id = str(overrides.get("type", ""))
		if not segment_types.has(type_id):
			errors.append("모르는 구간 종류: %s" % str(raw))
			continue
		var type_def: Dictionary = segment_types[type_id]
		var params: Dictionary = (type_def.get("params", {}) as Dictionary).duplicate()
		for key: Variant in overrides.keys():
			if key != "type" and key != "length":
				params[key] = overrides[key]
		out.append({
			"type": type_id,
			"length": float(overrides.get("length", type_def["length"])),
			"params": params,
		})
	return out


## "flat, rocks, pothole" 같은 글을 구간 목록 원본 배열로 바꾼다.
static func parse_order_text(text: String) -> Array:
	var out: Array = []
	for part: String in text.split(",", false):
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out


## 구간 목록으로 높이 선을 만든다. bump_scale 은 돌길 요철과 구덩이 깊이에 곱한다.
func build(resolved: Array[Dictionary], random_seed: int, bump_scale: float) -> void:
	points = PackedVector2Array()
	segments.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = random_seed
	var x: float = -START_PAD_LENGTH
	var h: float = 0.0
	points.append(Vector2(x, h))
	x = 0.0
	points.append(Vector2(x, h))
	for seg: Dictionary in resolved:
		var length: float = maxf(float(seg["length"]), BASE_STEP)
		var params: Dictionary = seg["params"]
		match seg["type"]:
			"rocks":
				h = _add_rocks(x, h, length, params, bump_scale, rng)
			"pothole":
				h = _add_pothole(x, h, length, params, bump_scale)
			"uphill", "downhill":
				h = _add_slope(x, h, length, float(params.get("rise", 0.0)))
			_:
				points.append(Vector2(x + length, h))
		segments.append({ "type": seg["type"], "start_x": x, "end_x": x + length })
		x += length
	finish_x = x
	points.append(Vector2(x + END_PAD_LENGTH, h))
	points = simplify(points, SIMPLIFY_TOLERANCE)


func start_x() -> float:
	return points[0].x if points.size() > 0 else 0.0


func end_x() -> float:
	return points[points.size() - 1].x if points.size() > 0 else 0.0


## x 위치의 길 높이 (선형 보간). 범위 밖이면 끝 높이.
func height_at(x: float) -> float:
	var n: int = points.size()
	if n == 0:
		return 0.0
	if x <= points[0].x:
		return points[0].y
	if x >= points[n - 1].x:
		return points[n - 1].y
	var lo: int = 0
	var hi: int = n - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if points[mid].x <= x:
			lo = mid
		else:
			hi = mid
	var a: Vector2 = points[lo]
	var b: Vector2 = points[hi]
	var span: float = b.x - a.x
	if span <= 0.0:
		return a.y
	return lerpf(a.y, b.y, (x - a.x) / span)


## x 위치가 속한 구간 종류 (마당이면 "")
func segment_type_at(x: float) -> String:
	for seg: Dictionary in segments:
		if x >= seg["start_x"] and x < seg["end_x"]:
			return seg["type"]
	return ""


## 거의 일직선인 가운데 점을 지운다.
static func simplify(src: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if src.size() <= 2:
		return src
	var out: PackedVector2Array = PackedVector2Array([src[0]])
	for i: int in range(1, src.size() - 1):
		var a: Vector2 = out[out.size() - 1]
		var b: Vector2 = src[i]
		var c: Vector2 = src[i + 1]
		var span: float = c.x - a.x
		if span <= 0.0:
			continue
		var expected: float = lerpf(a.y, c.y, (b.x - a.x) / span)
		if absf(expected - b.y) > tolerance:
			out.append(b)
	out.append(src[src.size() - 1])
	return out


func _add_rocks(x0: float, h0: float, length: float, params: Dictionary, bump_scale: float,
		rng: RandomNumberGenerator) -> float:
	var bump_height: float = float(params.get("bump_height", 0.05)) * bump_scale
	var spacing: float = maxf(float(params.get("bump_spacing", 0.5)), BUMP_STEP * 4.0)
	var jitter: float = clampf(float(params.get("bump_jitter", 0.3)), 0.0, 0.9)
	var cursor: float = x0
	var end: float = x0 + length
	while cursor < end:
		var bump_len: float = spacing * (1.0 + rng.randf_range(-jitter, jitter))
		bump_len = minf(bump_len, end - cursor)
		var height: float = bump_height * rng.randf_range(0.5, 1.0)
		var steps: int = maxi(int(ceil(bump_len / BUMP_STEP)), 2)
		for s: int in range(1, steps + 1):
			var t: float = float(s) / float(steps)
			# 반쯤 솟은 돌부리: 앞쪽은 가파르고 뒤쪽은 완만하게 (sin 모양을 기울임)
			var shaped: float = sin(PI * pow(t, 0.7))
			points.append(Vector2(cursor + bump_len * t, h0 + height * shaped))
		cursor += bump_len
	return h0


func _add_pothole(x0: float, h0: float, length: float, params: Dictionary, bump_scale: float) -> float:
	var depth: float = float(params.get("depth", 0.2)) * bump_scale
	var width: float = minf(float(params.get("width", 1.0)), length * 0.8)
	var edge: float = clampf(float(params.get("edge", 0.15)), 0.02, width * 0.45)
	var hole_start: float = x0 + (length - width) * 0.5
	points.append(Vector2(hole_start, h0))
	points.append(Vector2(hole_start + edge, h0 - depth))
	points.append(Vector2(hole_start + width - edge, h0 - depth))
	points.append(Vector2(hole_start + width, h0))
	points.append(Vector2(x0 + length, h0))
	return h0


func _add_slope(x0: float, h0: float, length: float, rise: float) -> float:
	var steps: int = maxi(int(ceil(length / BASE_STEP)), 2)
	for s: int in range(1, steps + 1):
		var t: float = float(s) / float(steps)
		# 시작과 끝이 부드럽게 꺾이도록 smoothstep
		var eased: float = t * t * (3.0 - 2.0 * t)
		points.append(Vector2(x0 + length * t, h0 + rise * eased))
	return h0 + rise
