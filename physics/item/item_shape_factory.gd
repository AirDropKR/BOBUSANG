class_name ItemShapeFactory
extends RefCounted
## 상품 데이터의 collider 로 충돌 모양과 보이는 도형을 만든다. 상자, 원통, 구, 캡슐만 지원.
## axis: 원통과 캡슐의 긴 축. "y" 세움, "x" 눕혀서 좌우로 길게, "z" 화면 안쪽으로 (옆에서 보면 원이라 굴러감)

const SHAPES: Array[String] = ["box", "cylinder", "sphere", "capsule"]
const AXES: Array[String] = ["x", "y", "z"]
## 원기둥, 공 메쉬 분할 수 (도형이라 낮게)
const RADIAL_SEGMENTS: int = 20
const RINGS: int = 10


static func make_shape(collider: Dictionary) -> Shape3D:
	match collider.get("shape", ""):
		"box":
			var box: BoxShape3D = BoxShape3D.new()
			box.size = _size3(collider["size"])
			return box
		"cylinder":
			var cyl: CylinderShape3D = CylinderShape3D.new()
			cyl.radius = float(collider["radius"])
			cyl.height = float(collider["height"])
			return cyl
		"sphere":
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = float(collider["radius"])
			return sphere
		"capsule":
			var cap: CapsuleShape3D = CapsuleShape3D.new()
			cap.radius = float(collider["radius"])
			# 데이터의 height 는 가운데 원통 길이, Godot 캡슐 height 는 전체 길이
			cap.height = float(collider["height"]) + 2.0 * cap.radius
			return cap
	push_error("지원하지 않는 충돌 모양: %s" % str(collider))
	return null


static func make_mesh(collider: Dictionary) -> Mesh:
	match collider.get("shape", ""):
		"box":
			var box: BoxMesh = BoxMesh.new()
			box.size = _size3(collider["size"])
			return box
		"cylinder":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = float(collider["radius"])
			cyl.bottom_radius = float(collider["radius"])
			cyl.height = float(collider["height"])
			cyl.radial_segments = RADIAL_SEGMENTS
			return cyl
		"sphere":
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = float(collider["radius"])
			sphere.height = float(collider["radius"]) * 2.0
			sphere.radial_segments = RADIAL_SEGMENTS
			sphere.rings = RINGS
			return sphere
		"capsule":
			var cap: CapsuleMesh = CapsuleMesh.new()
			cap.radius = float(collider["radius"])
			cap.height = float(collider["height"]) + 2.0 * cap.radius
			cap.radial_segments = RADIAL_SEGMENTS
			cap.rings = RINGS
			return cap
	return null


## 긴 축 방향을 맞추는 회전 (Godot 원통과 캡슐은 기본이 y축)
static func axis_basis(collider: Dictionary) -> Basis:
	var shape: String = collider.get("shape", "")
	if shape != "cylinder" and shape != "capsule":
		return Basis.IDENTITY
	match collider.get("axis", "y"):
		"x":
			return Basis(Vector3.BACK, PI * 0.5)
		"z":
			return Basis(Vector3.RIGHT, PI * 0.5)
	return Basis.IDENTITY


## 화면 평면(xy)에서 본 대략의 반 크기 (선반 배치, 화면 밖 판정 여유에 쓴다)
static func half_extents_2d(collider: Dictionary) -> Vector2:
	match collider.get("shape", ""):
		"box":
			var s: Vector3 = _size3(collider["size"])
			return Vector2(s.x, s.y) * 0.5
		"sphere":
			var r: float = float(collider["radius"])
			return Vector2(r, r)
		"cylinder", "capsule":
			var r2: float = float(collider["radius"])
			var h: float = float(collider["height"]) * 0.5
			if collider.get("shape") == "capsule":
				h += r2
			match collider.get("axis", "y"):
				"x":
					return Vector2(h, r2)
				"z":
					return Vector2(r2, r2)
			return Vector2(r2, h)
	return Vector2(0.2, 0.2)


## 굴러가는 모양인지 (옆에서 보면 원)
static func is_round_in_plane(collider: Dictionary) -> bool:
	var shape: String = collider.get("shape", "")
	return shape == "sphere" or (shape == "cylinder" and collider.get("axis", "y") == "z")


static func _size3(raw: Variant) -> Vector3:
	var arr: Array = raw
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
