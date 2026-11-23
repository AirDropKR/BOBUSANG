class_name Porter
extends Node3D
## 자동으로 걷는 주인공(캡슐)과 등의 지게. 길 높이를 따라 걷고, 몸은 스프링처럼 충격을 흡수한다.
## 입력 동작 lean(기울이기), slow(늦추기)는 GameInput 에서 읽는다.
## 몸 자세 = 발 위치를 중심으로 (기울이기 + 경사 따라 기울기) 만큼 회전.

signal arrived

const BODY_RADIUS: float = 0.24
const BODY_HEIGHT: float = 1.45
const HEAD_RADIUS: float = 0.15
const BODY_COLOR: Color = Color(0.86, 0.83, 0.74)
const HEAD_COLOR: Color = Color(0.85, 0.68, 0.52)
const HAT_COLOR: Color = Color(0.15, 0.13, 0.12)
## 경사를 잴 때 앞뒤로 보는 거리 (두 발 사이 정도)
const SLOPE_PROBE: float = 0.35
## 몸이 길보다 아래로 내려가지 않게 하는 한계 (m)
const MAX_SUSPENSION_SINK: float = 0.12
## 걷기를 멈춘 것으로 보는 속도
const STOPPED_SPEED: float = 0.01

var profile: RoadProfile
var carrier: CarrierBody
var body: AnimatableBody3D
var carrier_definition: Dictionary = {}

var walking: bool = false
var has_arrived: bool = false
var distance_x: float = 0.0
var speed: float = 0.0
var lean_degrees: float = 0.0
var is_slowed: bool = false

var _body_y: float = 0.0
var _body_vy: float = 0.0
var _step_phase: float = 0.0
var _carrier_local: Transform3D
var _body_local: Transform3D


func setup(p_profile: RoadProfile, p_carrier_definition: Dictionary, start_x: float) -> void:
	profile = p_profile
	carrier_definition = p_carrier_definition
	distance_x = start_x
	_body_y = profile.height_at(start_x)
	_build_body()
	carrier = CarrierBody.new()
	carrier.setup(carrier_definition)
	add_child(carrier)
	_carrier_local = Transform3D(Basis.IDENTITY,
		Vector3(float(carrier_definition["offset_x"]), float(carrier_definition["shelf_height"]), 0.0))
	_apply_pose(true)


func set_profile(p_profile: RoadProfile) -> void:
	profile = p_profile


func start_walking() -> void:
	walking = true


func pose_transform() -> Transform3D:
	var pivot: Vector3 = Vector3(distance_x, _body_y, 0.0)
	var angle: float = deg_to_rad(lean_degrees) + _slope_angle() * Tuning.v("slope_follow")
	var bob: float = Tuning.v("step_bob") * pow(sin(_step_phase), 2.0) if speed > STOPPED_SPEED else 0.0
	return Transform3D(Basis(Vector3.BACK, angle), pivot + Vector3(0.0, bob, 0.0))


func _physics_process(delta: float) -> void:
	_update_walk(delta)
	_update_lean(delta)
	_update_suspension(delta)
	_apply_pose(false)
	if walking and distance_x >= profile.finish_x:
		walking = false
	if not walking and not has_arrived and distance_x >= profile.finish_x and speed <= STOPPED_SPEED:
		has_arrived = true
		arrived.emit()


func _update_walk(delta: float) -> void:
	is_slowed = GameInput.is_slow_held()
	var target: float = 0.0
	if walking:
		target = Tuning.v("walk_speed") * float(carrier_definition.get("walk_speed_scale", 1.0))
		if is_slowed:
			target *= Tuning.v("slow_ratio")
	speed = move_toward(speed, target, Tuning.v("walk_accel") * delta)
	distance_x += speed * delta
	_step_phase += speed * delta / Tuning.v("step_length") * PI


## 기울이기 A(왼쪽, 입력 -1) = 반시계 = +z 회전이 되도록 부호를 뒤집는다.
func _update_lean(delta: float) -> void:
	var target: float = -GameInput.get_lean() * Tuning.v("lean_max_angle")
	lean_degrees = move_toward(lean_degrees, target, Tuning.v("lean_speed") * delta)


## 몸 높이를 길 높이에 스프링으로 따라가게 한다 (다리가 충격을 받아주는 느낌).
func _update_suspension(delta: float) -> void:
	var ground: float = profile.height_at(distance_x)
	var omega: float = Tuning.v("suspension_freq")
	var zeta: float = Tuning.v("suspension_damping")
	var accel: float = omega * omega * (ground - _body_y) - 2.0 * zeta * omega * _body_vy
	_body_vy += accel * delta
	_body_y += _body_vy * delta
	if _body_y < ground - MAX_SUSPENSION_SINK:
		_body_y = ground - MAX_SUSPENSION_SINK
		_body_vy = maxf(_body_vy, 0.0)


func _slope_angle() -> float:
	var h0: float = profile.height_at(distance_x - SLOPE_PROBE)
	var h1: float = profile.height_at(distance_x + SLOPE_PROBE)
	return atan2(h1 - h0, SLOPE_PROBE * 2.0)


func _apply_pose(teleport: bool) -> void:
	var pose: Transform3D = pose_transform()
	body.global_transform = pose * _body_local
	carrier.global_transform = pose * _carrier_local
	if teleport:
		body.reset_physics_interpolation()
		carrier.reset_physics_interpolation()


func _build_body() -> void:
	body = AnimatableBody3D.new()
	body.name = "PorterBody"
	body.sync_to_physics = true
	body.collision_layer = PhysicsLayers.PORTER
	body.collision_mask = 0
	add_child(body)
	_body_local = Transform3D(Basis.IDENTITY, Vector3(0.0, BODY_HEIGHT * 0.5, 0.0))
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = BODY_RADIUS
	shape.height = BODY_HEIGHT
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = BODY_RADIUS
	mesh.height = BODY_HEIGHT
	body.add_child(_mesh_node(mesh, BODY_COLOR, Vector3.ZERO))
	var head: SphereMesh = SphereMesh.new()
	head.radius = HEAD_RADIUS
	head.height = HEAD_RADIUS * 2.0
	body.add_child(_mesh_node(head, HEAD_COLOR, Vector3(0.05, BODY_HEIGHT * 0.5 + HEAD_RADIUS * 0.8, 0.0)))
	# 패랭이(모자) 대신 납작한 원통
	var hat: CylinderMesh = CylinderMesh.new()
	hat.top_radius = HEAD_RADIUS * 0.7
	hat.bottom_radius = HEAD_RADIUS * 1.9
	hat.height = 0.1
	body.add_child(_mesh_node(hat, HAT_COLOR, Vector3(0.05, BODY_HEIGHT * 0.5 + HEAD_RADIUS * 1.7, 0.0)))
	# 진행 방향 표시용 코 (얼굴 방향)
	var nose: BoxMesh = BoxMesh.new()
	nose.size = Vector3(0.06, 0.04, 0.04)
	body.add_child(_mesh_node(nose, HEAD_COLOR.darkened(0.2), Vector3(0.05 + HEAD_RADIUS, BODY_HEIGHT * 0.5 + HEAD_RADIUS * 0.8, 0.0)))


func _mesh_node(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	mi.position = pos
	return mi
