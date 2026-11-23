extends Node
## 자동 로드 "Loc". data/locale/*.json 을 읽어 TranslationServer 에 넣는다. 화면 문구는 tr("키")로 쓴다.

const LOCALE_DIR: String = "res://data/locale"
const DEFAULT_LOCALE: String = "ko"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path: String in JsonData.list_json_files(LOCALE_DIR):
		var data: Variant = JsonData.load_file(path)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var translation: Translation = Translation.new()
		translation.locale = path.get_file().get_basename()
		var strings: Dictionary = data["strings"]
		for key: String in strings.keys():
			translation.add_message(key, strings[key])
		TranslationServer.add_translation(translation)
	TranslationServer.set_locale(DEFAULT_LOCALE)


## 지금 언어로 데이터 항목 이름 (name_ko / name_en)
func name_of(entry: Dictionary) -> String:
	var lang: String = TranslationServer.get_locale().substr(0, 2)
	var key: String = "name_" + lang
	if entry.has(key):
		return entry[key]
	return entry.get("name_ko", entry.get("id", "?"))


## tr() 후 {이름} 자리 채우기
func format(key: String, values: Dictionary = {}) -> String:
	return tr(key).format(values)
