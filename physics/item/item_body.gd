class_name ItemBody
extends RigidBody3D
## 상품 물체. 데이터(data/items)로 모양과 물성을 만들고, 충돌 충격으로 내구도를 깎는다.
## 평면 물리: z 이동, x/y 회전 고정. 연속 충돌 감지와 최대 속도 제한.

signal broken(item: ItemBody)
signal damaged(item: ItemBody, amount: float)

## 생성 직후 겹침 때문에 생기는 가짜 충격을 무시하는 시간 (초)
const SPAWN_GRACE_TIME: float = 0.6
const MAX_CONTACTS: int = 8
## 내구도가 줄수록 섞는 색 (금 간 느낌)
const DAMAGE_TINT: Color = Color(0.35, 0.08, 0.05)
const DAMAGE_TINT_MAX: float = 0.6
## 굴러가는 물건 회전이 보이도록 붙이는 표시 띠
const ROLL_MARK_COLOR: Color = Color(0.1, 0.1, 0.1, 1.0)
const ROLL_MARK_THICKNESS: float = 0.025
const ROLL_MARK_DOT_RATIO: float = 0.22
const INFO_LABEL_OFFSET: float = 0.15
const INFO_FONT_SIZE: int = 28
const INFO_PIXEL_SIZE: float = 0.005

var uid: int = 0
var definition: Dictionary = {}
var item_id: String = ""
var max_durability: float = 1.0
var durability: float = 1.0
var is_broken: bool = false
var is_held: bool = false
## 가장 최근에 받은 충격 (디버그 표시용)
var last_impact: float = 0.0
## 이 시간 동안은 충격을 무시 (테스트에서 0으로 둘 수 있다)
var spawn_grace: float = SPAWN_GRACE_TIME

var _base_color: Color = Color.WHITE
var _material: StandardMaterial3D
var _physics_material: PhysicsMaterial
var _age: float = 0.0
var _prev_linear_velocity: Vector3 = Vector3.ZERO
var _prev_angular_velocity: Vector3 = Vector3.ZERO
var _prev_contacts: Dictionary = {}
var _info_label: Label3D
var _tag_text: String = ""
var _show_info: bool = false


func setup(p_definition: Dictionary, p_uid: int) -> void:
	definition = p_definition
	uid = p_uid
	item_id = definition["id"]
	name = "%s_%d" % [item_id, uid]
	max_durability = float(definition["durability"])
	durability = max_durability
	_base_color = Color.html(definition.get("color", "#cccccc"))

	var collider: Dictionary = definition["collider"]
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.shape = ItemShapeFactory.make_shape(collider)
	shape_node.basis = ItemShapeFactory.axis_basis(collider)
	add_child(shape_node)

	_material = StandardMaterial3D.new()
	_material.albedo_color = _base_color
	_material.roughness = 0.7
	if definition.get("tags", []).has("metal"):
		_material.metallic = 0.8
		_material.roughness = 0.35
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.mesh = ItemShapeFactory.make_mesh(collider)
	mesh_node.basis = ItemShapeFactory.axis_basis(collider)
	mesh_node.material_override = _material
	add_child(mesh_node)
	if ItemShapeFactory.is_round_in_plane(collider):
		_add_roll_mark(collider)

	# 평면 물리
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = MAX_CONTACTS
	can_sleep = true
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	collision_layer = PhysicsLayers.ITEMS
	collision_mask = PhysicsLayers.ITEM_MASK
	_physics_material = PhysicsMaterial.new()
	physics_material_override = _physics_material
	apply_tuning()


func _ready() -> void:
	Tuning.changed.connect(_on_tuning_changed)
	Tuning.reloaded.connect(apply_tuning)


## 조정 값(질량 배율, 마찰, 튕김, 감쇠)을 다시 적용한다.
func apply_tuning() -> void:
	mass = float(definition["mass"]) * Tuning.mass_scale(item_id)
	_physics_material.friction = float(definition["friction"]) * Tuning.v("friction_scale")
	_physics_material.bounce = clampf(float(definition["bounce"]) * Tuning.v("bounce_scale"), 0.0, 1.0)
	linear_damp = Tuning.v("linear_damp")
	angular_damp = Tuning.v("angular_damp")
	if sleeping:
		sleeping = false


func is_unbreakable() -> bool:
	return bool(definition.get("unbreakable", false))


func half_extents_2d() -> Vector2:
	return ItemShapeFactory.half_extents_2d(definition["collider"])


## 정보 표시 (내구도 %) 켜고 끄기
func set_info_visible(show_info: bool) -> void:
	_show_info = show_info
	_update_label_visibility()


## 물건 위에 띄우는 글 (예: 좌판 가격). 빈 글이면 숨김
func set_tag(text: String) -> void:
	_tag_text = text
	_update_label_visibility()


func _update_label_visibility() -> void:
	var needed: bool = _show_info or not _tag_text.is_empty()
	if needed and _info_label == null:
		_info_label = Label3D.new()
		_info_label.font_size = INFO_FONT_SIZE
		_info_label.pixel_size = INFO_PIXEL_SIZE
		_info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_info_label.no_depth_test = true
		_info_label.outline_size = 6
		_info_label.top_level = true
		_info_label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_info_label)
	if _info_label:
		_info_label.visible = needed


func _process(delta: float) -> void:
	_age += delta
	if _info_label == null or not _info_label.visible:
		return
	var lines: PackedStringArray = PackedStringArray()
	if not _tag_text.is_empty():
		lines.append(_tag_text)
	if _show_info:
		var pct: int = roundi(Breakage.durability_ratio(durability, max_durability) * 100.0)
		lines.append("%s %d%%  m%.1f  (%.1f)" % [Loc.name_of(definition), pct, mass, last_impact])
	_info_label.text = "\n".join(lines)
	var top: float = half_extents_2d().y
	_info_label.global_position = get_global_transform_interpolated().origin + Vector3.UP * (top + INFO_LABEL_OFFSET)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# 최대 속도 제한: 작은 물건이 튀어 날아가지 않게
	var max_lin: float = Tuning.v("max_linear_speed")
	var max_ang: float = Tuning.v("max_angular_speed")
	if state.linear_velocity.length() > max_lin:
		state.linear_velocity = state.linear_velocity.normalized() * max_lin
	if state.angular_velocity.length() > max_ang:
		state.angular_velocity = state.angular_velocity.normalized() * max_ang

	var strongest: float = 0.0
	var contacts: Dictionary = {}
	for i: int in range(state.get_contact_count()):
		var other_id: int = state.get_contact_collider_id(i)
		if not _prev_contacts.has(other_id) and not contacts.has(other_id):
			strongest = maxf(strongest, _estimate_impact(state, i))
		contacts[other_id] = true
	_prev_contacts = contacts
	_prev_linear_velocity = state.linear_velocity
	_prev_angular_velocity = state.angular_velocity
	if strongest > 0.0 and _age >= spawn_grace:
		_receive_impact.call_deferred(strongest)


## 새로 닿은 접촉 하나의 충격량 추정: 직전 속도로 다가오던 접촉면 방향 속도 x 환산 질량
func _estimate_impact(state: PhysicsDirectBodyState3D, index: int) -> float:
	var contact_pos: Vector3 = state.get_contact_local_position(index)
	var r: Vector3 = contact_pos - state.transform.origin
	var own_point_velocity: Vector3 = _prev_linear_velocity + _prev_angular_velocity.cross(r)
	var other_velocity: Vector3 = state.get_contact_collider_velocity_at_position(index)
	var normal: Vector3 = state.get_contact_local_normal(index)
	var approach: float = absf((own_point_velocity - other_velocity).dot(normal))
	var other: Object = state.get_contact_collider_object(index)
	var other_mass: float = 0.0
	if other is RigidBody3D and not (other as RigidBody3D).freeze:
		other_mass = (other as RigidBody3D).mass
	return Breakage.impact_impulse(approach, mass, other_mass)


func _receive_impact(impact: float) -> void:
	if is_broken:
		return
	last_impact = impact
	var result: Breakage.Result = Breakage.apply_impact(
		durability, impact,
		float(definition["damage_threshold"]), float(definition["break_impulse"]),
		Tuning.v("damage_scale"), is_unbreakable())
	if result.damage <= 0.0 and not result.broken:
		return
	durability = result.durability
	damaged.emit(self, result.damage)
	_update_damage_tint()
	if result.broken:
		is_broken = true
		broken.emit(self)


func _update_damage_tint() -> void:
	var lost: float = 1.0 - Breakage.durability_ratio(durability, max_durability)
	_material.albedo_color = _base_color.lerp(DAMAGE_TINT, lost * DAMAGE_TINT_MAX)


func _on_tuning_changed(_key: String, _value: float) -> void:
	apply_tuning()


func _add_roll_mark(collider: Dictionary) -> void:
	var r: float = float(collider["radius"])
	var mark: MeshInstance3D = MeshInstance3D.new()
	if collider["shape"] == "sphere":
		# 공: 앞쪽 위에 꼭지 점 하나
		var dot: SphereMesh = SphereMesh.new()
		dot.radius = r * ROLL_MARK_DOT_RATIO
		dot.height = dot.radius * 2.0
		mark.mesh = dot
		mark.position = Vector3(0.0, r * 0.6, r * 0.72)
	else:
		# 눕힌 원통: 앞쪽 마구리에 줄 하나
		var stripe: BoxMesh = BoxMesh.new()
		stripe.size = Vector3(ROLL_MARK_THICKNESS, r * 1.9, 0.01)
		mark.mesh = stripe
		mark.position = Vector3(0.0, 0.0, float(collider["height"]) * 0.5 + 0.006)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = ROLL_MARK_COLOR.lerp(_base_color, 0.3)
	mark.material_override = mat
	add_child(mark)
