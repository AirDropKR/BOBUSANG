extends Node
## 자동 로드 "Tuning". 조정 패널 수치를 들고 있고, 바뀌면 changed 신호를 보낸다.
## 항목 정의: data/tuning/params.json / 기본값 덮어쓰기: data/tuning/default_values.json (있으면)
## 이름 붙여 저장: user://tuning_presets/<이름>.json

signal changed(key: String, value: float)
## 여러 값이 한꺼번에 바뀜 (불러오기, 기본값)
signal reloaded

const PARAMS_PATH: String = "res://data/tuning/params.json"
const DEFAULT_VALUES_PATH: String = "res://data/tuning/default_values.json"
const ITEMS_DIR: String = "res://data/items"
const PRESET_DIR: String = "user://tuning_presets"
const PER_ITEM_GROUP: String = "item"

var store: TuningStore = TuningStore.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_store()


func v(key: String) -> float:
	return store.get_value(key)


func mass_scale(item_id: String) -> float:
	var key: String = mass_scale_key(item_id)
	return store.get_value(key) if store.has_param(key) else 1.0


static func mass_scale_key(item_id: String) -> String:
	return "mass_scale." + item_id


func set_value(key: String, value: float) -> void:
	var actual: float = store.set_value(key, value)
	changed.emit(key, actual)


func reset_to_defaults() -> void:
	store.reset_to_defaults()
	_apply_default_file()
	reloaded.emit()


func save_preset(preset_name: String) -> String:
	var safe_name: String = preset_name.strip_edges().validate_filename()
	if safe_name.is_empty():
		safe_name = "preset"
	DirAccess.make_dir_recursive_absolute(PRESET_DIR)
	var path: String = PRESET_DIR.path_join(safe_name + ".json")
	if not _write_text(path, store.to_json()):
		return ""
	return path


## 불러온 값 개수, 실패하면 -1
func load_preset(preset_name: String) -> int:
	var path: String = PRESET_DIR.path_join(preset_name.strip_edges().validate_filename() + ".json")
	if not FileAccess.file_exists(path):
		return -1
	var applied: int = store.apply_json(FileAccess.get_file_as_string(path))
	if applied >= 0:
		reloaded.emit()
	return applied


func list_presets() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(PRESET_DIR)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			out.append(file_name.get_basename())
	out.sort()
	return out


## 지금 값을 프로젝트 기본값 파일로 쓴다. 에디터에서 실행할 때만 된다 (내보낸 게임에선 res:// 가 읽기 전용).
func save_as_project_default() -> String:
	if not OS.has_feature("editor"):
		return ""
	return DEFAULT_VALUES_PATH if _write_text(DEFAULT_VALUES_PATH, store.to_json()) else ""


func _build_store() -> void:
	var params_data: Variant = JsonData.load_file(PARAMS_PATH)
	if typeof(params_data) != TYPE_DICTIONARY:
		push_error("조정 항목 정의를 읽지 못함")
		return
	var items: Dictionary = JsonData.load_by_id(ITEMS_DIR)
	var item_ids: Array = items.keys()
	item_ids.sort()
	for spec: Dictionary in params_data["params"]:
		if spec["group"] == PER_ITEM_GROUP:
			for item_id: String in item_ids:
				var item_spec: Dictionary = spec.duplicate()
				item_spec["key"] = mass_scale_key(item_id)
				item_spec["name_ko"] = items[item_id]["name_ko"]
				item_spec["name_en"] = items[item_id]["name_en"]
				store.add_param(item_spec)
		else:
			store.add_param(spec)
	_apply_default_file()


func _apply_default_file() -> void:
	if FileAccess.file_exists(DEFAULT_VALUES_PATH):
		store.apply_json(FileAccess.get_file_as_string(DEFAULT_VALUES_PATH))


func _write_text(path: String, text: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("저장 실패: %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true
