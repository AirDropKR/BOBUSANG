class_name TuningStore
extends RefCounted
## 조정 가능한 수치 저장소. 항목 정의(이름, 기본값, 범위)와 현재 값을 들고 있고, JSON으로 주고받는다.
## Node를 쓰지 않으므로 테스트에서 바로 만들 수 있다. 게임에서는 Tuning 자동 로드가 이걸 감싸서 쓴다.

## key -> 정의 Dictionary { key, group, name_ko, name_en, default, min, max, step }
var _specs: Dictionary = {}
## 정의 추가 순서 (패널 표시 순서)
var _order: Array[String] = []
var _values: Dictionary = {}


func add_param(spec: Dictionary) -> void:
	var key: String = spec["key"]
	if not _specs.has(key):
		_order.append(key)
	_specs[key] = spec
	_values[key] = _clamp_value(key, float(spec["default"]))


func has_param(key: String) -> bool:
	return _specs.has(key)


func keys() -> Array[String]:
	return _order.duplicate()


func get_spec(key: String) -> Dictionary:
	return _specs.get(key, {})


func get_value(key: String) -> float:
	if not _values.has(key):
		push_error("알 수 없는 조정 값: %s" % key)
		return 0.0
	return _values[key]


## 값을 바꾸고, 범위 밖이면 잘라낸 실제 값을 돌려준다.
func set_value(key: String, value: float) -> float:
	if not _specs.has(key):
		push_error("알 수 없는 조정 값: %s" % key)
		return 0.0
	var clamped: float = _clamp_value(key, value)
	_values[key] = clamped
	return clamped


func reset_to_defaults() -> void:
	for key: String in _order:
		_values[key] = _clamp_value(key, float(_specs[key]["default"]))


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key: String in _order:
		out[key] = _values[key]
	return out


## 저장된 값 적용. 모르는 키는 건너뛰고, 적용한 키 개수를 돌려준다.
func apply_dict(data: Dictionary) -> int:
	var applied: int = 0
	for key: Variant in data.keys():
		if typeof(key) != TYPE_STRING or not _specs.has(key):
			continue
		var raw: Variant = data[key]
		if typeof(raw) != TYPE_FLOAT and typeof(raw) != TYPE_INT:
			continue
		set_value(key, float(raw))
		applied += 1
	return applied


func to_json() -> String:
	return JSON.stringify({ "version": 1, "values": to_dict() }, "\t")


## JSON 문자열 적용. 실패하면 -1.
func apply_json(text: String) -> int:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return -1
	var dict: Dictionary = json.data
	if dict.has("values") and typeof(dict["values"]) == TYPE_DICTIONARY:
		return apply_dict(dict["values"])
	return apply_dict(dict)


func _clamp_value(key: String, value: float) -> float:
	var spec: Dictionary = _specs[key]
	return clampf(value, float(spec["min"]), float(spec["max"]))
