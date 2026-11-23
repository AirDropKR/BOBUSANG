class_name RoadCatalog
extends RefCounted
## data/roads 의 길 정의를 읽는다 (구간 종류 파일은 빼고).

const SEGMENT_TYPES_FILE: String = "segment_types.json"


static func load_roads(dir_path: String) -> Dictionary:
	var roads: Dictionary = {}
	for path: String in JsonData.list_json_files(dir_path):
		if path.get_file() == SEGMENT_TYPES_FILE:
			continue
		var data: Variant = JsonData.load_file(path)
		if typeof(data) == TYPE_DICTIONARY:
			roads[data["id"]] = data
	return roads
