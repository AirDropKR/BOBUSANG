class_name JsonData
extends RefCounted
## data/ 폴더의 JSON 파일을 읽는 도우미. 파일 접근만 하고 게임 규칙은 모른다.


## JSON 파일 하나를 읽는다. 실패하면 null.
static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("파일이 없음: %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_error("JSON 오류 %s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## 폴더 안의 *.json 파일 경로 목록 (이름순).
static func list_json_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			out.append(dir_path.path_join(file_name))
	out.sort()
	return out


## 폴더의 JSON 객체들을 id 기준으로 모은다. 배열 파일은 각 원소를 넣는다.
static func load_by_id(dir_path: String) -> Dictionary:
	var out: Dictionary = {}
	for path: String in list_json_files(dir_path):
		var data: Variant = load_file(path)
		var entries: Array = data if typeof(data) == TYPE_ARRAY else [data]
		for entry: Variant in entries:
			if typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).has("id"):
				out[entry["id"]] = entry
	return out
