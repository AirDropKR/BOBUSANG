class_name RoadBuilder
extends Node3D
## RoadProfile 높이 선으로 길의 충돌체(상자 이어 붙이기)와 보이는 메쉬를 만든다.
## 충돌은 꺾은선 한 마디마다 회전한 상자 하나 (원칙 3: 단순 모양만).

## 충돌 상자 두께 (아래로)
const COLLIDER_THICKNESS: float = 0.6
## 충돌 상자 앞뒤 폭 (상품은 z=0 평면에만 있으므로 넉넉히)
const COLLIDER_DEPTH: float = 2.0
## 보이는 길의 앞쪽(z+), 뒤쪽(z-) 끝
const VISUAL_FRONT_Z: float = 1.1
const VISUAL_BACK_Z: float = -2.5
## 보이는 땅 밑면 높이 (가장 낮은 지점 기준)
const VISUAL_BOTTOM_MARGIN: float = 4.0
const ROAD_FRICTION: float = 0.8
const ROAD_BOUNCE: float = 0.0
const COLOR_TOP: Color = Color(0.58, 0.49, 0.36)
const COLOR_FRONT: Color = Color(0.40, 0.31, 0.22)
## 구간 종류별 윗면 색 (미리 보고 기울이기 타이밍을 잡을 수 있게)
const SEGMENT_TINT: Dictionary = {
	"rocks": Color(0.50, 0.47, 0.43),
	"pothole": Color(0.45, 0.33, 0.22),
	"uphill": Color(0.55, 0.52, 0.34),
	"downhill": Color(0.55, 0.52, 0.34),
}
const SIGN_HEIGHT: float = 1.6
const SIGN_Z: float = -1.2
const FINISH_POLE_HEIGHT: float = 2.4

var profile: RoadProfile
var _body: StaticBody3D
var _visual_root: Node3D


func build(p_profile: RoadProfile, segment_names: Dictionary) -> void:
	profile = p_profile
	for child: Node in get_children():
		child.queue_free()
	_body = StaticBody3D.new()
	_body.name = "RoadBody"
	_body.collision_layer = PhysicsLayers.WORLD
	_body.collision_mask = 0
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = ROAD_FRICTION
	material.bounce = ROAD_BOUNCE
	_body.physics_material_override = material
	add_child(_body)
	_build_colliders()
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)
	_build_mesh()
	_build_signs(segment_names)


func _build_colliders() -> void:
	var pts: PackedVector2Array = profile.points
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var edge: Vector2 = b - a
		var length: float = edge.length()
		if length <= 0.0001:
			continue
		var angle: float = edge.angle()
		var normal: Vector2 = Vector2(-edge.y, edge.x) / length
		var center: Vector2 = (a + b) * 0.5 - normal * COLLIDER_THICKNESS * 0.5
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(length, COLLIDER_THICKNESS, COLLIDER_DEPTH)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		col.transform = Transform3D(Basis(Vector3.BACK, angle), Vector3(center.x, center.y, 0.0))
		_body.add_child(col)


func _build_mesh() -> void:
	var pts: PackedVector2Array = profile.points
	var min_y: float = 0.0
	for p: Vector2 in pts:
		min_y = minf(min_y, p.y)
	var bottom: float = min_y - VISUAL_BOTTOM_MARGIN
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mid_type: String = profile.segment_type_at((a.x + b.x) * 0.5)
		var top_color: Color = SEGMENT_TINT.get(mid_type, COLOR_TOP)
		# 윗면
		var edge: Vector2 = (b - a).normalized()
		var up: Vector3 = Vector3(-edge.y, edge.x, 0.0)
		_quad(st, top_color, up,
			Vector3(a.x, a.y, VISUAL_BACK_Z), Vector3(b.x, b.y, VISUAL_BACK_Z),
			Vector3(b.x, b.y, VISUAL_FRONT_Z), Vector3(a.x, a.y, VISUAL_FRONT_Z))
		# 앞면 (땅 단면)
		_quad(st, COLOR_FRONT, Vector3.BACK,
			Vector3(a.x, a.y, VISUAL_FRONT_Z), Vector3(b.x, b.y, VISUAL_FRONT_Z),
			Vector3(b.x, bottom, VISUAL_FRONT_Z), Vector3(a.x, bottom, VISUAL_FRONT_Z))
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	st.set_material(mat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	_visual_root.add_child(mi)


## 시계 방향 네 점을 삼각형 두 개로. 바깥에서 보이도록 감는 방향을 맞춘다.
func _quad(st: SurfaceTool, color: Color, normal: Vector3, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3) -> void:
	st.set_color(color)
	st.set_normal(normal)
	var tri_normal: Vector3 = (p1 - p0).cross(p2 - p0)
	if tri_normal.dot(normal) > 0.0:
		for p: Vector3 in [p0, p2, p1, p0, p3, p2]:
			st.add_vertex(p)
	else:
		for p: Vector3 in [p0, p1, p2, p0, p2, p3]:
			st.add_vertex(p)


func _build_signs(segment_names: Dictionary) -> void:
	for seg: Dictionary in profile.segments:
		var x: float = seg["start_x"]
		var label: Label3D = Label3D.new()
		label.text = segment_names.get(seg["type"], seg["type"])
		label.font_size = 48
		label.pixel_size = 0.006
		label.modulate = Color(1, 1, 1, 0.85)
		label.outline_size = 8
		label.position = Vector3(x, profile.height_at(x) + SIGN_HEIGHT, SIGN_Z)
		_visual_root.add_child(label)
		var pole: MeshInstance3D = MeshInstance3D.new()
		var pole_mesh: BoxMesh = BoxMesh.new()
		pole_mesh.size = Vector3(0.05, SIGN_HEIGHT - 0.2, 0.05)
		pole.mesh = pole_mesh
		pole.position = Vector3(x, profile.height_at(x) + (SIGN_HEIGHT - 0.2) * 0.5, SIGN_Z)
		_visual_root.add_child(pole)
	# 도착 깃대
	var fx: float = profile.finish_x
	var finish: MeshInstance3D = MeshInstance3D.new()
	var fmesh: BoxMesh = BoxMesh.new()
	fmesh.size = Vector3(0.08, FINISH_POLE_HEIGHT, 0.08)
	finish.mesh = fmesh
	var fmat: StandardMaterial3D = StandardMaterial3D.new()
	fmat.albedo_color = Color(0.75, 0.15, 0.12)
	finish.material_override = fmat
	finish.position = Vector3(fx, profile.height_at(fx) + FINISH_POLE_HEIGHT * 0.5, SIGN_Z)
	_visual_root.add_child(finish)
