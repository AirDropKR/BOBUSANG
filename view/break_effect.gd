class_name BreakEffect
extends Node3D
## 깨짐 연출: 상품 색 조각 몇 개가 흩어지고 "쨍그랑" 글자가 떠올랐다 사라진다.
## 조각은 길하고만 부딪혀서 짐 더미를 흔들지 않는다.

const FRAGMENT_COUNT: int = 6
const FRAGMENT_SIZE_RATIO: float = 0.35
const FRAGMENT_MASS: float = 0.1
const FRAGMENT_SPEED: float = 2.5
const LIFETIME: float = 2.5
const FADE_TIME: float = 0.6
const TEXT_RISE_SPEED: float = 0.6
const TEXT_FONT_SIZE: int = 64
const TEXT_PIXEL_SIZE: float = 0.006
const TEXT_COLOR: Color = Color(1.0, 0.85, 0.3)
const TEXT_OFFSET: float = 0.4

var _age: float = 0.0
var _fragments: Array[RigidBody3D] = []
var _label: Label3D


func setup(at: Transform3D, color: Color, half_extents: Vector2, text: String) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var size: float = maxf(half_extents.x, half_extents.y) * FRAGMENT_SIZE_RATIO
	for i: int in range(FRAGMENT_COUNT):
		var frag: RigidBody3D = RigidBody3D.new()
		frag.collision_layer = PhysicsLayers.DEBRIS
		frag.collision_mask = PhysicsLayers.DEBRIS_MASK
		frag.mass = FRAGMENT_MASS
		frag.axis_lock_linear_z = true
		frag.axis_lock_angular_x = true
		frag.axis_lock_angular_y = true
		var s: float = size * rng.randf_range(0.6, 1.2)
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(s, s * 0.6, s)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		frag.add_child(col)
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = shape.size
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		frag.add_child(mi)
		var offset: Vector3 = Vector3(rng.randf_range(-half_extents.x, half_extents.x),
			rng.randf_range(-half_extents.y, half_extents.y), 0.0)
		frag.position = at.origin + offset * 0.6
		frag.rotation.z = rng.randf_range(-PI, PI)
		frag.linear_velocity = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.3, 1.2), 0.0) * FRAGMENT_SPEED
		frag.angular_velocity = Vector3(0.0, 0.0, rng.randf_range(-10.0, 10.0))
		add_child(frag)
		_fragments.append(frag)
	_label = Label3D.new()
	_label.text = text
	_label.font_size = TEXT_FONT_SIZE
	_label.pixel_size = TEXT_PIXEL_SIZE
	_label.modulate = TEXT_COLOR
	_label.outline_size = 12
	_label.no_depth_test = true
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_label.position = at.origin + Vector3.UP * TEXT_OFFSET
	add_child(_label)


func _process(delta: float) -> void:
	_age += delta
	_label.position.y += TEXT_RISE_SPEED * delta
	var fade: float = clampf((LIFETIME - _age) / FADE_TIME, 0.0, 1.0)
	_label.modulate.a = fade
	for frag: RigidBody3D in _fragments:
		var mi: MeshInstance3D = frag.get_child(1)
		(mi.material_override as StandardMaterial3D).albedo_color.a = fade
	if _age >= LIFETIME:
		queue_free()
