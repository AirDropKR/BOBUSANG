class_name StackingShelf
extends StaticBody3D
## 출발 전에 상품을 올려 두는 2단 선반(장터 좌판). 벽걸이처럼 왼쪽 기둥만 있어 오른쪽으로 끌어내기 쉽다.
## 아래 칸은 지게 받침 높이와 같게 두어서, 들 수 없는 무거운 짐도 끌어서 옮길 수 있다.
## 선반 길이는 올릴 상품에 맞춰 늘어나고, 오른쪽 끝(지게 쪽)을 기준으로 왼쪽으로 자란다.

const BOARD_THICKNESS: float = 0.05
const BOARD_DEPTH: float = 0.6
const POST_WIDTH: float = 0.08
const UPPER_GAP: float = 0.75
const ITEM_GAP: float = 0.1
const DROP_CLEARANCE: float = 0.01
const MIN_WIDTH: float = 1.5
## 아래 칸이 위 칸보다 이만큼은 오른쪽으로 더 나와 있게 (위 칸 아래로 끌어내기 쉽게)
const LOWER_EXTRA: float = 0.6
## 이 질량 이상은 아래 칸
const HEAVY_MASS: float = 6.0
const COLOR_BOARD: Color = Color(0.45, 0.32, 0.2)
const FRICTION: float = 0.8

var left_x: float = 0.0
var lower_height: float = 0.0
var upper_height: float = 0.0


## 상품을 무거운 것(아래 칸)과 가벼운 것(위 칸)으로 나눈다. 반환: [아래, 위]
static func split_by_mass(items: Array[ItemBody]) -> Array:
	var lower: Array[ItemBody] = []
	var upper: Array[ItemBody] = []
	for item: ItemBody in items:
		if item.mass >= HEAVY_MASS:
			lower.append(item)
		else:
			upper.append(item)
	return [lower, upper]


## right_x: 선반 오른쪽 끝, ground_y: 땅 높이, board_height: 아래 칸 높이(땅 기준)
func build_for(right_x: float, ground_y: float, board_height: float,
		lower: Array[ItemBody], upper: Array[ItemBody]) -> void:
	name = "StackingShelf"
	collision_layer = PhysicsLayers.WORLD
	collision_mask = 0
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = FRICTION
	physics_material_override = pm
	var upper_width: float = maxf(_row_width(upper), MIN_WIDTH)
	var lower_width: float = maxf(maxf(_row_width(lower), upper_width + LOWER_EXTRA), MIN_WIDTH)
	left_x = right_x - lower_width
	lower_height = ground_y + board_height
	upper_height = lower_height + UPPER_GAP
	_add_board(left_x, right_x, lower_height)
	_add_board(left_x, left_x + upper_width, upper_height)
	var post_h: float = upper_height - ground_y
	_add_box(Vector3(POST_WIDTH, post_h, BOARD_DEPTH), Vector3(left_x - POST_WIDTH * 0.5, ground_y + post_h * 0.5, 0.0))
	_place_row(lower, left_x, lower_height)
	_place_row(upper, left_x, upper_height)


func _row_width(items: Array[ItemBody]) -> float:
	var width: float = ITEM_GAP
	for item: ItemBody in items:
		width += item.half_extents_2d().x * 2.0 + ITEM_GAP
	return width


func _place_row(items: Array[ItemBody], left: float, height: float) -> void:
	var cursor: float = left + ITEM_GAP
	for item: ItemBody in items:
		var half: Vector2 = item.half_extents_2d()
		item.position = Vector3(cursor + half.x, height + half.y + DROP_CLEARANCE, 0.0)
		item.reset_physics_interpolation()
		cursor += half.x * 2.0 + ITEM_GAP


func _add_board(left: float, right: float, top: float) -> void:
	_add_box(Vector3(right - left, BOARD_THICKNESS, BOARD_DEPTH),
		Vector3((left + right) * 0.5, top - BOARD_THICKNESS * 0.5, 0.0))


func _add_box(size: Vector3, pos: Vector3) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	add_child(col)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = COLOR_BOARD
	mi.material_override = mat
	add_child(mi)
