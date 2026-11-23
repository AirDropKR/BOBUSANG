class_name DataValidator
extends RefCounted
## data/ 폴더 JSON 스키마 검사. 오류 문장 배열을 돌려준다 (비어 있으면 통과).
## 실행: godot --headless -s res://tools/validate_data.gd

const DATA_ROOT: String = "res://data"
const ITEM_REQUIRED_NUMBERS: Array[String] = [
	"base_price", "mass", "friction", "bounce", "durability", "damage_threshold", "break_impulse",
]
const CARRIER_REQUIRED_NUMBERS: Array[String] = [
	"shelf_width", "shelf_thickness", "shelf_depth", "shelf_height", "offset_x", "frame_height", "rim_height",
	"rim_thickness", "pivot_height", "load_zone_height", "load_zone_margin", "friction", "bounce",
]
const MAX_FRICTION: float = 2.0


static func validate_all(root: String = DATA_ROOT) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for path: String in JsonData.list_json_files(root.path_join("items")):
		errors.append_array(_with_path(path, validate_item(_load(path, errors)), seen))
	for path: String in JsonData.list_json_files(root.path_join("carriers")):
		errors.append_array(_with_path(path, validate_carrier(_load(path, errors)), seen))
	var segment_path: String = root.path_join("roads/segment_types.json")
	var segment_data: Variant = _load(segment_path, errors)
	var segment_ids: Array = []
	errors.append_array(_prefix(segment_path, validate_segment_types(segment_data)))
	if typeof(segment_data) == TYPE_ARRAY:
		for entry: Variant in segment_data:
			if typeof(entry) == TYPE_DICTIONARY:
				segment_ids.append(entry.get("id"))
	for path: String in JsonData.list_json_files(root.path_join("roads")):
		if path == segment_path:
			continue
		errors.append_array(_with_path(path, validate_road(_load(path, errors), segment_ids), seen))
	errors.append_array(validate_locales(root.path_join("locale")))
	var params_path: String = root.path_join("tuning/params.json")
	errors.append_array(_prefix(params_path, validate_tuning_params(_load(params_path, errors))))
	return errors


static func validate_item(d: Variant) -> Array[String]:
	var e: Array[String] = []
	if not _check_common(d, "item_", e):
		return e
	var item: Dictionary = d
	for key: String in ITEM_REQUIRED_NUMBERS:
		_require_number(item, key, e)
	if e.size() > 0:
		return e
	if float(item["mass"]) <= 0.0:
		e.append("mass 는 0보다 커야 함")
	if float(item["base_price"]) < 0.0:
		e.append("base_price 는 0 이상")
	if float(item["friction"]) < 0.0 or float(item["friction"]) > MAX_FRICTION:
		e.append("friction 범위 0~%s" % MAX_FRICTION)
	if float(item["bounce"]) < 0.0 or float(item["bounce"]) > 1.0:
		e.append("bounce 범위 0~1")
	if float(item["durability"]) <= 0.0:
		e.append("durability 는 0보다 커야 함")
	if float(item["damage_threshold"]) < 0.0:
		e.append("damage_threshold 는 0 이상")
	if float(item["break_impulse"]) <= float(item["damage_threshold"]):
		e.append("break_impulse 는 damage_threshold 보다 커야 함")
	if item.has("unbreakable") and typeof(item["unbreakable"]) != TYPE_BOOL:
		e.append("unbreakable 은 true/false")
	if not item.has("tags") or typeof(item["tags"]) != TYPE_ARRAY:
		e.append("tags 배열 필요")
	else:
		for tag: Variant in item["tags"]:
			if typeof(tag) != TYPE_STRING:
				e.append("tags 에는 문자열만")
	if not item.has("special"):
		e.append("special 필요 (없으면 null)")
	elif item["special"] != null and typeof(item["special"]) != TYPE_STRING:
		e.append("special 은 null 또는 문자열")
	if item.has("color") and not Color.html_is_valid(str(item["color"])):
		e.append("color 형식 오류: %s" % str(item["color"]))
	e.append_array(validate_collider(item.get("collider")))
	return e


static func validate_collider(c: Variant) -> Array[String]:
	var e: Array[String] = []
	if typeof(c) != TYPE_DICTIONARY:
		e.append("collider 객체 필요")
		return e
	var col: Dictionary = c
	var shape: String = str(col.get("shape", ""))
	if not ItemShapeFactory.SHAPES.has(shape):
		e.append("collider.shape 는 %s 중 하나: %s" % [str(ItemShapeFactory.SHAPES), shape])
		return e
	match shape:
		"box":
			var size: Variant = col.get("size")
			if typeof(size) != TYPE_ARRAY or (size as Array).size() != 3:
				e.append("box 는 size [x, y, z] 필요")
			else:
				for v: Variant in size:
					if not _is_number(v) or float(v) <= 0.0:
						e.append("box size 는 양수")
		"sphere":
			_require_positive(col, "radius", e, "collider.")
		"cylinder", "capsule":
			_require_positive(col, "radius", e, "collider.")
			_require_positive(col, "height", e, "collider.")
			if col.has("axis") and not ItemShapeFactory.AXES.has(str(col["axis"])):
				e.append("collider.axis 는 x, y, z 중 하나")
	return e


static func validate_carrier(d: Variant) -> Array[String]:
	var e: Array[String] = []
	if not _check_common(d, "carrier_", e):
		return e
	for key: String in CARRIER_REQUIRED_NUMBERS:
		_require_number(d, key, e)
	return e


static func validate_segment_types(d: Variant) -> Array[String]:
	var e: Array[String] = []
	if typeof(d) != TYPE_ARRAY or (d as Array).is_empty():
		e.append("구간 종류는 비어 있지 않은 배열이어야 함")
		return e
	for entry: Variant in d:
		if not _check_common(entry, "", e):
			continue
		_require_positive(entry, "length", e)
		if typeof((entry as Dictionary).get("params")) != TYPE_DICTIONARY:
			e.append("%s: params 객체 필요" % str(entry.get("id")))
	return e


static func validate_road(d: Variant, segment_ids: Array) -> Array[String]:
	var e: Array[String] = []
	if not _check_common(d, "road_", e):
		return e
	var segs: Variant = (d as Dictionary).get("segments")
	if typeof(segs) != TYPE_ARRAY or (segs as Array).is_empty():
		e.append("segments 는 비어 있지 않은 배열")
		return e
	for seg: Variant in segs:
		var type_id: String = ""
		if typeof(seg) == TYPE_STRING:
			type_id = seg
		elif typeof(seg) == TYPE_DICTIONARY:
			type_id = str((seg as Dictionary).get("type", ""))
			if (seg as Dictionary).has("length") and (not _is_number(seg["length"]) or float(seg["length"]) <= 0.0):
				e.append("구간 length 는 양수")
		if not segment_ids.has(type_id):
			e.append("모르는 구간 종류: %s" % str(seg))
	if (d as Dictionary).has("seed") and not _is_number(d["seed"]):
		e.append("seed 는 숫자")
	return e


## 모든 언어 파일이 같은 키를 갖는지
static func validate_locales(dir_path: String) -> Array[String]:
	var e: Array[String] = []
	var key_sets: Dictionary = {}
	for path: String in JsonData.list_json_files(dir_path):
		var data: Variant = JsonData.load_file(path)
		var sub: Array[String] = []
		if _check_common(data, "locale_", sub) and typeof((data as Dictionary).get("strings")) == TYPE_DICTIONARY:
			var keys: Array = (data["strings"] as Dictionary).keys()
			keys.sort()
			key_sets[path] = keys
		else:
			sub.append("strings 객체 필요")
		e.append_array(_prefix(path, sub))
	var reference: Array = []
	for path: String in key_sets.keys():
		if reference.is_empty():
			reference = key_sets[path]
		elif key_sets[path] != reference:
			e.append("%s: 다른 언어 파일과 문구 키가 다름" % path)
	if key_sets.is_empty():
		e.append("%s: 언어 파일이 없음" % dir_path)
	return e


static func validate_tuning_params(d: Variant) -> Array[String]:
	var e: Array[String] = []
	if typeof(d) != TYPE_DICTIONARY or typeof((d as Dictionary).get("params")) != TYPE_ARRAY:
		e.append("params 배열 필요")
		return e
	var keys: Dictionary = {}
	for spec: Variant in d["params"]:
		if typeof(spec) != TYPE_DICTIONARY:
			e.append("항목은 객체")
			continue
		var before: int = e.size()
		var key: String = str(spec.get("key", ""))
		if key.is_empty() or keys.has(key):
			e.append("key 가 없거나 중복: %s" % key)
		keys[key] = true
		for field: String in ["group", "name_ko", "name_en"]:
			if typeof(spec.get(field)) != TYPE_STRING or str(spec[field]).is_empty():
				e.append("%s: %s 필요" % [key, field])
		for field: String in ["default", "min", "max", "step"]:
			if not _is_number(spec.get(field)):
				e.append("%s: %s 숫자 필요" % [key, field])
		if e.size() == before:
			if not (float(spec["min"]) <= float(spec["default"]) and float(spec["default"]) <= float(spec["max"])):
				e.append("%s: min <= default <= max 이어야 함" % key)
			if float(spec["step"]) <= 0.0:
				e.append("%s: step 은 양수" % key)
	return e


# --- 도우미 ------------------------------------------------------------------

## id, name_ko, name_en 검사. 객체가 아니면 false
static func _check_common(d: Variant, id_prefix: String, e: Array[String]) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		e.append("객체(JSON object)가 아님")
		return false
	var dict: Dictionary = d
	var id: Variant = dict.get("id")
	if typeof(id) != TYPE_STRING or (id as String).is_empty():
		e.append("id 문자열 필요")
	elif not id_prefix.is_empty() and not (id as String).begins_with(id_prefix):
		e.append("id 는 %s 로 시작: %s" % [id_prefix, id])
	for key: String in ["name_ko", "name_en"]:
		if typeof(dict.get(key)) != TYPE_STRING or (dict[key] as String).is_empty():
			e.append("%s 필요" % key)
	return true


static func _require_number(d: Dictionary, key: String, e: Array[String]) -> void:
	if not _is_number(d.get(key)):
		e.append("%s 숫자 필요" % key)


static func _require_positive(d: Dictionary, key: String, e: Array[String], label_prefix: String = "") -> void:
	if not _is_number(d.get(key)) or float(d[key]) <= 0.0:
		e.append("%s%s 양수 필요" % [label_prefix, key])


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT


static func _load(path: String, errors: Array[String]) -> Variant:
	var data: Variant = JsonData.load_file(path)
	if data == null:
		errors.append("%s: 읽기 실패 또는 JSON 오류" % path)
	return data


static func _prefix(path: String, errs: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for err: String in errs:
		out.append("%s: %s" % [path, err])
	return out


## 파일 경로를 붙이고, id 중복도 잡는다
static func _with_path(path: String, errs: Array[String], seen: Dictionary) -> Array[String]:
	var out: Array[String] = _prefix(path, errs)
	var data: Variant = JsonData.load_file(path)
	if typeof(data) == TYPE_DICTIONARY and (data as Dictionary).has("id"):
		var id: String = str(data["id"])
		if seen.has(id):
			out.append("%s: id 중복 %s (%s 에도 있음)" % [path, id, seen[id]])
		seen[id] = path
	return out
