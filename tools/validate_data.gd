extends SceneTree
## 데이터 검증 실행: godot --headless --path . -s res://tools/validate_data.gd
## 오류가 있으면 출력하고 종료 코드 1


func _init() -> void:
	var errors: Array[String] = DataValidator.validate_all()
	if errors.is_empty():
		print("데이터 검증 통과")
		quit(0)
		return
	for err: String in errors:
		printerr(err)
	printerr("데이터 오류 %d개" % errors.size())
	quit(1)
