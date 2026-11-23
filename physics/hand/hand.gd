class_name Hand
extends Node3D
## 손 (한 번에 하나만 잡는다). 커서 위치를 목표로 물리 힘을 주어 끌어당긴다. 위치를 직접 옮기지 않는다.
## 입력은 GameInput 의 grab / drag / release / rotate 동작으로만 받는다.

signal grabbed(item: ItemBody, liftable: bool)
signal released_item(item: ItemBody)

## 잡은 물건을 돌리는 토크 한계 = 손 최대 힘 x 이 길이 (m)
const TORQUE_ARM: float = 0.25
const RAY_LENGTH: float = 100.0
const CURSOR_RADIUS: float = 0.05
const COLOR_OK: Color = Color(1.0, 0.95, 0.7)
const COLOR_HEAVY: Color = Color(1.0, 0.35, 0.25)
## 줄 그리기: 커서와 물건 사이 거리가 이보다 작으면 안 그린다
const LINE_MIN_LENGTH: float = 0.03

var camera: Camera3D
var held: ItemBody = null
var held_liftable: bool = true
var target_position: Vector3 = Vector3.ZERO
var target_angle: float = 0.0
## false 면 잡기 시작을 받지 않는다 (결과 화면 등)
var active: bool = true

var _params: HandForce.Params = HandForce.Params.new()
var _cursor: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _cursor_material: StandardMaterial3D


func _ready() -> void:
	GameInput.grab_started.connect(_on_grab_started)
	GameInput.released.connect(_on_released)
	_build_visuals()


func setup(p_camera: Camera3D) -> void:
	camera = p_camera


## 화면 좌표를 z=0 평면 위 점으로
func screen_to_plane(screen_position: Vector2) -> Vector3:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var dir: Vector3 = camera.project_ray_normal(screen_position)
	if absf(dir.z) < 0.0001:
		return origin
	var t: float = -origin.z / dir.z
	return origin + dir * t


func grab(item: ItemBody) -> void:
	if held:
		release()
	held = item
	held.is_held = true
	held.sleeping = false
	held_liftable = HandRules.can_lift(held.mass, Tuning.v("hand_max_force"), Tuning.v("gravity"))
	target_angle = held.rotation.z
	grabbed.emit(held, held_liftable)


func release() -> void:
	if held == null:
		return
	var item: ItemBody = held
	held.is_held = false
	held = null
	released_item.emit(item)


func _physics_process(delta: float) -> void:
	if camera == null:
		return
	target_position = screen_to_plane(GameInput.get_pointer_position())
	if held == null:
		return
	if not is_instance_valid(held) or held.is_broken:
		held = null
		return
	_params.spring = Tuning.v("hand_spring")
	_params.damping_ratio = Tuning.v("hand_damping")
	_params.max_force = Tuning.v("hand_max_force")
	_params.gravity = Tuning.v("gravity")
	_params.gravity_comp = Tuning.v("hand_gravity_comp")
	_params.drag_lift_ratio = Tuning.v("hand_drag_lift_ratio")
	_params.physics_dt = delta
	held_liftable = HandRules.can_lift(held.mass, _params.max_force, _params.gravity)
	var force: Vector3 = HandForce.compute(held.mass, held.global_position, held.linear_velocity, target_position, _params)
	held.apply_central_force(force)

	target_angle += GameInput.get_rotate() * deg_to_rad(Tuning.v("hand_rotate_speed")) * delta * -1.0
	var state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(held.get_rid())
	if state:
		var inv_inertia_z: float = state.inverse_inertia.z
		var inertia: float = 1.0 / inv_inertia_z if inv_inertia_z > 0.0 else 0.0
		var torque: float = HandForce.hold_torque(inertia, held.rotation.z, held.angular_velocity.z, target_angle,
			Tuning.v("hand_rotate_freq"), _params.max_force * TORQUE_ARM)
		held.apply_torque(Vector3(0.0, 0.0, torque))


func _process(_delta: float) -> void:
	if camera == null:
		return
	var cursor_pos: Vector3 = screen_to_plane(GameInput.get_pointer_position())
	_cursor.global_position = cursor_pos
	_cursor.visible = held != null
	_line_mesh.clear_surfaces()
	if held == null or not is_instance_valid(held):
		return
	_cursor_material.albedo_color = COLOR_OK if held_liftable else COLOR_HEAVY
	var from: Vector3 = held.get_global_transform_interpolated().origin
	if from.distance_to(cursor_pos) < LINE_MIN_LENGTH:
		return
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _cursor_material)
	_line_mesh.surface_add_vertex(from)
	_line_mesh.surface_add_vertex(cursor_pos)
	_line_mesh.surface_end()


func _on_grab_started(screen_position: Vector2) -> void:
	if not active or camera == null:
		return
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var dir: Vector3 = camera.project_ray_normal(screen_position)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * RAY_LENGTH,
		PhysicsLayers.ITEMS)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider is ItemBody and not (collider as ItemBody).is_broken:
		grab(collider)


func _on_released(_screen_position: Vector2) -> void:
	release()


func _build_visuals() -> void:
	_cursor_material = StandardMaterial3D.new()
	_cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_material.albedo_color = COLOR_OK
	_cursor_material.no_depth_test = true
	_cursor = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = CURSOR_RADIUS
	sphere.height = CURSOR_RADIUS * 2.0
	_cursor.mesh = sphere
	_cursor.material_override = _cursor_material
	_cursor.top_level = true
	_cursor.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_cursor)
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.top_level = true
	_line.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_line)
