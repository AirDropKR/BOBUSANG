class_name CarrierBody
extends AnimatableBody3D
## 지게 받침대. 상자 모양 받침과 테두리(주인공 쪽 등태는 높게, 바깥쪽은 낮게).
## 주인공(Porter)이 매 물리 프레임 자세를 정해 주고, 물리 엔진이 그 움직임으로 위의 짐을 밀어준다.
## 이 노드의 원점 = 받침 윗면 가운데.

const VISUAL_LEG_THICKNESS: float = 0.05
const VISUAL_LEG_COLOR_DARKEN: float = 0.25

var definition: Dictionary = {}
var shelf_width: float = 0.8


func setup(p_definition: Dictionary) -> void:
	definition = p_definition
	name = "Carrier"
	sync_to_physics = true
	collision_layer = PhysicsLayers.PORTER
	collision_mask = 0
	var pm: PhysicsMaterial = PhysicsMaterial.new()
	pm.friction = float(definition["friction"])
	pm.bounce = float(definition["bounce"])
	physics_material_override = pm

	shelf_width = float(definition["shelf_width"])
	var thick: float = float(definition["shelf_thickness"])
	var depth: float = float(definition["shelf_depth"])
	var rim_t: float = float(definition["rim_thickness"])
	var frame_h: float = float(definition["frame_height"])
	var rim_h: float = float(definition["rim_height"])
	var color: Color = Color.html(definition.get("color", "#9c7448"))
	var half: float = shelf_width * 0.5
	# 받침
	_add_box(Vector3(shelf_width + rim_t * 2.0, thick, depth), Vector3(0.0, -thick * 0.5, 0.0), color)
	# 주인공 쪽 등태 (+x)
	_add_box(Vector3(rim_t, frame_h + thick, depth), Vector3(half + rim_t * 0.5, (frame_h - thick) * 0.5, 0.0), color)
	# 바깥쪽 낮은 테두리 (-x)
	_add_box(Vector3(rim_t, rim_h + thick, depth), Vector3(-half - rim_t * 0.5, (rim_h - thick) * 0.5, 0.0), color)
	_add_legs(color.darkened(VISUAL_LEG_COLOR_DARKEN))


## 지게 위(짐 싣는 공간)에 있는 점인가
func is_in_load_zone(global_point: Vector3) -> bool:
	var local: Vector3 = global_transform.affine_inverse() * global_point
	var margin: float = float(definition["load_zone_margin"])
	return absf(local.x) <= shelf_width * 0.5 + margin \
		and local.y >= -margin and local.y <= float(definition["load_zone_height"])


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
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
	mat.albedo_color = color
	mi.material_override = mat
	add_child(mi)


## 보이기만 하는 지게 다리 (충돌 없음)
func _add_legs(color: Color) -> void:
	var height: float = float(definition["shelf_height"])
	var half: float = shelf_width * 0.5
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	for z: float in [-0.18, 0.18]:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(VISUAL_LEG_THICKNESS, height * 1.05, VISUAL_LEG_THICKNESS)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(half * 0.6, -height * 0.5, z)
		mi.rotation = Vector3(0.0, 0.0, -0.25)
		add_child(mi)
