class_name TripWorld
extends Node3D
## 한 번의 이동에 필요한 물리 세계를 묶는다: 길, 주인공과 지게, 손, 카메라, 상품, 깨짐 연출.
## M1 샌드박스와 M2 장터 구간이 같이 쓴다. 규칙(돈, 짐 상태)은 모르고 결과만 신호로 알린다.

## 짐으로 등록한 상품이 깨짐 (이미 세계에서 지운 뒤)
signal item_broken(uid: int, definition: Dictionary)
## 짐으로 등록한 상품을 잃음 (화면 밖, 너무 깊이 떨어짐)
signal item_lost(uid: int, definition: Dictionary)
## 등록하지 않은 상품(좌판 위 등)이 깨짐
signal untracked_item_broken(definition: Dictionary)
signal porter_arrived
signal heavy_grabbed(item: ItemBody)

const SEGMENT_TYPES_PATH: String = "res://data/roads/segment_types.json"
## 화면 왼쪽 밖으로 이만큼(픽셀) 나가면 잃음
const OFFSCREEN_MARGIN_PX: float = 40.0
## 길보다 이만큼 아래로 떨어지면 잃음
const KILL_DEPTH: float = 15.0
## 요철 세기를 바꾼 뒤 길을 다시 만들기까지 기다리는 시간
const ROAD_REBUILD_DELAY: float = 0.35
## 출발 전 화면: 좌판과 지게가 다 보이도록 잡는 여유 (m)
const STACKING_VIEW_MARGIN: float = 1.2
const STACKING_FOCUS_HEIGHT: float = 0.9

var road_def: Dictionary = {}
var order_text: String = ""
var segment_types: Dictionary = {}
var carrier_def: Dictionary = {}
var profile: RoadProfile
var porter: Porter
var hand: Hand
var camera: FollowCamera
var items: Array[ItemBody] = []
## 잃음 검사를 할지 (걷는 동안)
var checking_lost: bool = false

var _road: RoadBuilder
var _effects: Node3D
var _tracked: Dictionary = {}
var _next_uid: int = 1
var _rebuild_timer: float = -1.0
var _show_info: bool = false


## p_order_text 가 비어 있지 않으면 길 정의의 구간 대신 이 순서를 쓴다
func setup(p_road_def: Dictionary, p_carrier_def: Dictionary, porter_start_x: float, p_order_text: String = "") -> void:
	road_def = p_road_def
	carrier_def = p_carrier_def
	order_text = p_order_text
	segment_types = {}
	for entry: Dictionary in JsonData.load_file(SEGMENT_TYPES_PATH):
		segment_types[entry["id"]] = entry
	_apply_gravity()
	SceneLighting.add_to(self)
	profile = _make_profile()
	_road = RoadBuilder.new()
	_road.name = "Road"
	add_child(_road)
	_road.build(profile, segment_names())
	_effects = Node3D.new()
	_effects.name = "Effects"
	add_child(_effects)

	porter = Porter.new()
	porter.name = "Porter"
	add_child(porter)
	porter.setup(profile, carrier_def, porter_start_x)
	porter.arrived.connect(func() -> void: porter_arrived.emit())

	camera = FollowCamera.new()
	add_child(camera)
	camera.target = porter.body

	hand = Hand.new()
	hand.name = "Hand"
	add_child(hand)
	hand.setup(camera)
	hand.grabbed.connect(_on_hand_grabbed)

	Tuning.changed.connect(_on_tuning_changed)
	Tuning.reloaded.connect(_on_tuning_reloaded)


func _physics_process(delta: float) -> void:
	if _rebuild_timer >= 0.0:
		_rebuild_timer -= delta
		if _rebuild_timer < 0.0:
			_rebuild_road()
	if checking_lost:
		_check_lost_items()


func segment_names() -> Dictionary:
	var names: Dictionary = {}
	for type_id: String in segment_types.keys():
		names[type_id] = Loc.name_of(segment_types[type_id])
	return names


## 지게 받침 바깥쪽 끝 x (좌판을 이 왼쪽에 놓는다)
func carrier_left_x() -> float:
	return porter.distance_x + float(carrier_def["offset_x"]) - float(carrier_def["shelf_width"]) * 0.5


func spawn_item(definition: Dictionary) -> ItemBody:
	var item: ItemBody = ItemBody.new()
	item.setup(definition, _next_uid)
	_next_uid += 1
	add_child(item)
	item.broken.connect(_on_item_broken)
	item.set_info_visible(_show_info)
	items.append(item)
	return item


func remove_item(item: ItemBody) -> void:
	if hand.held == item:
		hand.release()
	items.erase(item)
	_tracked.erase(item.uid)
	item.queue_free()


## 짐으로 등록: 깨짐과 잃음을 신호로 알린다
func track(item: ItemBody) -> void:
	_tracked[item.uid] = true


func is_tracked(item: ItemBody) -> bool:
	return _tracked.has(item.uid)


func is_on_carrier(item: ItemBody) -> bool:
	return porter.carrier.is_in_load_zone(item.global_position)


func items_on_carrier() -> Array[ItemBody]:
	var out: Array[ItemBody] = []
	for item: ItemBody in items:
		if is_on_carrier(item):
			out.append(item)
	return out


func start_walking() -> void:
	hand.release()
	checking_lost = true
	camera.fixed_focus = null
	porter.start_walking()


## 출발 전 화면: left_x 부터 지게까지 보이게 카메라를 고정
func show_stacking_area(left_x: float) -> void:
	var right_x: float = porter.distance_x + STACKING_VIEW_MARGIN
	var left: float = left_x - STACKING_VIEW_MARGIN
	var ground: float = profile.height_at(porter.distance_x)
	camera.fixed_focus = Vector3((left + right_x) * 0.5, ground + STACKING_FOCUS_HEIGHT, 0.0)
	camera.min_view_width = right_x - left
	camera.snap()


func set_info_visible(on: bool) -> void:
	_show_info = on
	for item: ItemBody in items:
		item.set_info_visible(on)


func _make_profile() -> RoadProfile:
	var raw_segments: Array = road_def["segments"]
	if not order_text.strip_edges().is_empty():
		raw_segments = RoadProfile.parse_order_text(order_text)
	var errors: Array = []
	var resolved: Array[Dictionary] = RoadProfile.resolve_segments(raw_segments, segment_types, errors)
	for err: String in errors:
		push_warning(err)
	var p: RoadProfile = RoadProfile.new()
	p.build(resolved, int(road_def.get("seed", 0)), Tuning.v("road_bump_scale"))
	return p


func _rebuild_road() -> void:
	profile = _make_profile()
	_road.build(profile, segment_names())
	porter.set_profile(profile)


func _apply_gravity() -> void:
	PhysicsServer3D.area_set_param(get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, Tuning.v("gravity"))


func _check_lost_items() -> void:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	for item: ItemBody in items.duplicate():
		if item.is_held or not is_tracked(item) or is_on_carrier(item):
			continue
		var pos: Vector3 = item.global_position
		# 물건의 오른쪽 끝까지 화면 왼쪽 밖으로 나가면 잃음
		var right_edge: Vector3 = pos + Vector3(item.half_extents_2d().length(), 0.0, 0.0)
		var off_left: bool = camera.unproject_position(right_edge).x < viewport_rect.position.x - OFFSCREEN_MARGIN_PX
		var fell: bool = pos.y < profile.height_at(pos.x) - KILL_DEPTH
		if off_left or fell:
			var uid: int = item.uid
			var definition: Dictionary = item.definition
			remove_item(item)
			item_lost.emit(uid, definition)


func _on_item_broken(item: ItemBody) -> void:
	var text: String = Loc.format("ui.broke_toast", { "item": Loc.name_of(item.definition) })
	var effect: BreakEffect = BreakEffect.new()
	_effects.add_child(effect)
	effect.setup(item.global_transform, Color.html(item.definition.get("color", "#cccccc")), item.half_extents_2d(), text)
	var uid: int = item.uid
	var definition: Dictionary = item.definition
	var was_tracked: bool = is_tracked(item)
	remove_item(item)
	if was_tracked:
		item_broken.emit(uid, definition)
	else:
		untracked_item_broken.emit(definition)


func _on_hand_grabbed(item: ItemBody, liftable: bool) -> void:
	if not liftable:
		heavy_grabbed.emit(item)


func _on_tuning_changed(key: String, _value: float) -> void:
	if key == "gravity":
		_apply_gravity()
	elif key == "road_bump_scale":
		_rebuild_timer = ROAD_REBUILD_DELAY


func _on_tuning_reloaded() -> void:
	_apply_gravity()
	_rebuild_timer = ROAD_REBUILD_DELAY
