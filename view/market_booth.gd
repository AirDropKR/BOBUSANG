class_name MarketBooth
extends Node3D
## 장터 표시 (보이기만 함): 기둥 두 개와 차양, 장터 이름 간판. 충돌 없음.

const POLE_HEIGHT: float = 2.6
const POLE_WIDTH: float = 0.1
const AWNING_THICKNESS: float = 0.06
const AWNING_DEPTH: float = 1.6
const BACK_Z: float = -0.9
const SIGN_FONT_SIZE: int = 72
const SIGN_PIXEL_SIZE: float = 0.007
const COLOR_POLE: Color = Color(0.38, 0.27, 0.17)
const COLOR_AWNING: Color = Color(0.86, 0.8, 0.66)


## left_x ~ right_x 위에 세운다. ground_y 는 땅 높이
func build(left_x: float, right_x: float, ground_y: float, title: String) -> void:
	var pole_mat: StandardMaterial3D = StandardMaterial3D.new()
	pole_mat.albedo_color = COLOR_POLE
	for x: float in [left_x, right_x]:
		_box(Vector3(POLE_WIDTH, POLE_HEIGHT, POLE_WIDTH), Vector3(x, ground_y + POLE_HEIGHT * 0.5, BACK_Z), pole_mat)
	var awning_mat: StandardMaterial3D = StandardMaterial3D.new()
	awning_mat.albedo_color = COLOR_AWNING
	var width: float = right_x - left_x + POLE_WIDTH * 4.0
	_box(Vector3(width, AWNING_THICKNESS, AWNING_DEPTH),
		Vector3((left_x + right_x) * 0.5, ground_y + POLE_HEIGHT, BACK_Z + AWNING_DEPTH * 0.5 - POLE_WIDTH), awning_mat)
	var sign_label: Label3D = Label3D.new()
	sign_label.text = title
	sign_label.font_size = SIGN_FONT_SIZE
	sign_label.pixel_size = SIGN_PIXEL_SIZE
	sign_label.outline_size = 12
	sign_label.position = Vector3((left_x + right_x) * 0.5, ground_y + POLE_HEIGHT + 0.35, BACK_Z)
	add_child(sign_label)


func _box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
