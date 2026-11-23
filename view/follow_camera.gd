class_name FollowCamera
extends Camera3D
## 주인공을 따라가는 옆모습 카메라. 살짝 위에서, 살짝 앞쪽(오른쪽)에서 비스듬히 본다.
## 진행 방향 앞쪽 길이 더 보이도록 바라보는 점을 앞으로 당긴다.

const FOV_DEGREES: float = 38.0
const HEIGHT_OFFSET: float = 1.6
const LOOK_HEIGHT: float = 1.0
## 비스듬히 보는 정도 (카메라를 x 방향으로 비킨 거리 / 카메라 거리)
const YAW_SHIFT_RATIO: float = 0.08
const FOLLOW_SHARPNESS: float = 4.0
const FOLLOW_SHARPNESS_Y: float = 2.5

var target: Node3D
## 따라갈 점을 직접 정할 때 (출발 전 선반 보기)
var fixed_focus: Variant = null
## 0보다 크면 이 너비(m)가 화면에 다 들어오도록 카메라를 뒤로 뺀다 (출발 전 좌판 보기)
var min_view_width: float = 0.0
var _focus: Vector3 = Vector3.ZERO
var _initialized: bool = false


func _ready() -> void:
	fov = FOV_DEGREES
	# _process 에서 움직이므로 물리 보간을 끈다
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	current = true


func snap() -> void:
	_focus = _desired_focus()
	_initialized = true
	_place()
	reset_physics_interpolation()


func _process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = _desired_focus()
	if not _initialized:
		_focus = desired
		_initialized = true
	var kx: float = 1.0 - exp(-FOLLOW_SHARPNESS * delta)
	var ky: float = 1.0 - exp(-FOLLOW_SHARPNESS_Y * delta)
	_focus.x = lerpf(_focus.x, desired.x, kx)
	_focus.y = lerpf(_focus.y, desired.y, ky)
	_place()


func _desired_focus() -> Vector3:
	if fixed_focus != null:
		return fixed_focus
	var origin: Vector3 = target.get_global_transform_interpolated().origin
	return Vector3(origin.x + Tuning.v("camera_lookahead"), origin.y + LOOK_HEIGHT, 0.0)


func _place() -> void:
	var dist: float = Tuning.v("camera_distance")
	if fixed_focus != null and min_view_width > 0.0:
		dist = maxf(dist, _distance_for_width(min_view_width))
	var look_at_point: Vector3 = _focus
	global_position = look_at_point + Vector3(dist * YAW_SHIFT_RATIO, HEIGHT_OFFSET, dist)
	look_at(look_at_point, Vector3.UP)


## 가로 너비 width(m)가 화면에 들어오는 카메라 거리
func _distance_for_width(width: float) -> float:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_h_fov: float = atan(tan(deg_to_rad(fov) * 0.5) * aspect)
	return width * 0.5 / tan(half_h_fov)
