extends Node3D
## M1 물리 샌드박스. 선반에서 지게로 짐 쌓기 -> 출발 -> 길 걷기 -> 도착 결과.
## 규칙(짐 상태 기록)은 core/HaulState 가 맡고, 이 노드는 물리 결과(깨짐, 잃음, 도착)를 알려주기만 한다.

enum Phase { STACKING, WALKING, ARRIVING, RESULT }

const ITEMS_DIR: String = "res://data/items"
const ROADS_DIR: String = "res://data/roads"
const SEGMENT_TYPES_PATH: String = "res://data/roads/segment_types.json"
const CARRIER_PATH: String = "res://data/carriers/carrier_jige.json"
const DEFAULT_ROAD_ID: String = "road_m1_mixed"

## 주인공 출발 위치와 선반 배치
const PORTER_START_X: float = -2.0
const SHELF_GAP: float = 0.55
const SHELF_LOWER_WIDTH: float = 3.4
const SHELF_UPPER_WIDTH: float = 2.6
## 아래 칸에 둘 무거운 상품 (나머지는 위 칸)
const LOWER_SHELF_ITEMS: Array[String] = ["item_rice_bale", "item_salt_sack", "item_firewood", "item_onggi"]
## 출발 전 카메라가 볼 곳 (선반과 지게 사이)
const STACKING_FOCUS_OFFSET: Vector3 = Vector3(-2.0, 0.9, 0.0)
## 화면 왼쪽 밖으로 이만큼(픽셀) 나가면 잃음
const OFFSCREEN_MARGIN_PX: float = 40.0
## 이보다 낮게 떨어지면 잃음 (월드 높이)
const KILL_DEPTH: float = 15.0
## 도착 후 짐이 가라앉기를 기다리는 시간
const ARRIVAL_SETTLE_TIME: float = 1.0
## 요철 세기를 바꾼 뒤 길을 다시 만들기까지 기다리는 시간
const ROAD_REBUILD_DELAY: float = 0.35
const SKY_COLOR: Color = Color(0.72, 0.82, 0.9)
const AMBIENT_COLOR: Color = Color(0.75, 0.75, 0.7)
const AMBIENT_ENERGY: float = 0.6
const SUN_ENERGY: float = 1.1
const SUN_ROTATION_DEG: Vector3 = Vector3(-50.0, 30.0, 0.0)

## 다시 시작해도 유지하는 선택 (길, 구간 순서, 정보 표시)
static var selected_road_id: String = DEFAULT_ROAD_ID
static var custom_order_text: String = ""
static var show_item_info: bool = false

var phase: Phase = Phase.STACKING
var haul: HaulState = HaulState.new()
var item_defs: Dictionary = {}
var road_defs: Dictionary = {}
var segment_types: Dictionary = {}
var carrier_def: Dictionary = {}
var profile: RoadProfile
var items: Array[ItemBody] = []

var _road: RoadBuilder
var _porter: Porter
var _shelf: StackingShelf
var _hand: Hand
var _camera: FollowCamera
var _hud: Hud
var _panel: TuningPanel
var _effects: Node3D
var _arrive_timer: float = 0.0
var _rebuild_timer: float = -1.0
var _next_uid: int = 1


func _ready() -> void:
	_load_data()
	_apply_gravity()
	_build_environment()
	_build_road()
	_effects = Node3D.new()
	_effects.name = "Effects"
	add_child(_effects)

	_porter = Porter.new()
	_porter.name = "Porter"
	add_child(_porter)
	_porter.setup(profile, carrier_def, PORTER_START_X)
	_porter.arrived.connect(_on_porter_arrived)

	_shelf = StackingShelf.new()
	add_child(_shelf)
	var shelf_right: float = PORTER_START_X + float(carrier_def["offset_x"]) \
		- float(carrier_def["shelf_width"]) * 0.5 - SHELF_GAP
	_shelf.setup(shelf_right, profile.height_at(shelf_right), float(carrier_def["shelf_height"]),
		SHELF_LOWER_WIDTH, SHELF_UPPER_WIDTH)
	_spawn_items()

	_camera = FollowCamera.new()
	add_child(_camera)
	_camera.target = _porter.body
	_camera.fixed_focus = Vector3(PORTER_START_X, profile.height_at(PORTER_START_X), 0.0) + STACKING_FOCUS_OFFSET
	_camera.snap()

	_hand = Hand.new()
	_hand.name = "Hand"
	add_child(_hand)
	_hand.setup(_camera)
	_hand.grabbed.connect(_on_hand_grabbed)

	_hud = Hud.new()
	add_child(_hud)
	_hud.start_pressed.connect(_on_start_pressed)
	_panel = TuningPanel.new()
	add_child(_panel)
	_panel.set_roads(road_defs, selected_road_id, custom_order_text)
	_panel.road_rebuild_requested.connect(_on_road_rebuild_requested)
	_panel.restart_requested.connect(_restart)
	_panel.info_toggled.connect(_on_info_toggled)

	Tuning.changed.connect(_on_tuning_changed)
	Tuning.reloaded.connect(_on_tuning_reloaded)


func _physics_process(delta: float) -> void:
	if _rebuild_timer >= 0.0:
		_rebuild_timer -= delta
		if _rebuild_timer < 0.0:
			_rebuild_road_live()
	match phase:
		Phase.WALKING:
			_check_lost_items()
		Phase.ARRIVING:
			_check_lost_items()
			_arrive_timer -= delta
			if _arrive_timer <= 0.0:
				_finish_trip()


func _process(_delta: float) -> void:
	if phase == Phase.WALKING or phase == Phase.ARRIVING:
		_hud.set_info(_count_on_carrier(), maxf(profile.finish_x - _porter.distance_x, 0.0), _porter.is_slowed)
	elif phase == Phase.STACKING:
		_hud.set_info(_count_on_carrier(), -1.0, false)


# --- 준비 ------------------------------------------------------------------

func _load_data() -> void:
	item_defs = JsonData.load_by_id(ITEMS_DIR)
	segment_types = {}
	for entry: Dictionary in JsonData.load_file(SEGMENT_TYPES_PATH):
		segment_types[entry["id"]] = entry
	road_defs = {}
	for path: String in JsonData.list_json_files(ROADS_DIR):
		if path == SEGMENT_TYPES_PATH:
			continue
		var data: Variant = JsonData.load_file(path)
		if typeof(data) == TYPE_DICTIONARY:
			road_defs[data["id"]] = data
	if not road_defs.has(selected_road_id):
		selected_road_id = DEFAULT_ROAD_ID
	carrier_def = JsonData.load_file(CARRIER_PATH)


func _make_profile() -> RoadProfile:
	var road: Dictionary = road_defs[selected_road_id]
	var raw_segments: Array = road["segments"]
	if not custom_order_text.strip_edges().is_empty():
		raw_segments = RoadProfile.parse_order_text(custom_order_text)
	var errors: Array = []
	var resolved: Array[Dictionary] = RoadProfile.resolve_segments(raw_segments, segment_types, errors)
	for err: String in errors:
		push_warning(err)
	var p: RoadProfile = RoadProfile.new()
	p.build(resolved, int(road.get("seed", 0)), Tuning.v("road_bump_scale"))
	return p


func _segment_names() -> Dictionary:
	var names: Dictionary = {}
	for type_id: String in segment_types.keys():
		names[type_id] = Loc.name_of(segment_types[type_id])
	return names


func _build_road() -> void:
	profile = _make_profile()
	_road = RoadBuilder.new()
	_road.name = "Road"
	add_child(_road)
	_road.build(profile, _segment_names())


func _rebuild_road_live() -> void:
	profile = _make_profile()
	_road.build(profile, _segment_names())
	_porter.set_profile(profile)


func _build_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = SUN_ENERGY
	sun.rotation_degrees = SUN_ROTATION_DEG
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	add_child(sun)


func _spawn_items() -> void:
	var lower: Array[ItemBody] = []
	var upper: Array[ItemBody] = []
	var ids: Array = item_defs.keys()
	ids.sort()
	for item_id: String in LOWER_SHELF_ITEMS:
		if item_defs.has(item_id):
			lower.append(_spawn_item(item_defs[item_id]))
	for item_id: String in ids:
		if not LOWER_SHELF_ITEMS.has(item_id):
			upper.append(_spawn_item(item_defs[item_id]))
	_shelf.place_items(lower, upper)


func _spawn_item(definition: Dictionary) -> ItemBody:
	var item: ItemBody = ItemBody.new()
	item.setup(definition, _next_uid)
	_next_uid += 1
	add_child(item)
	item.broken.connect(_on_item_broken)
	item.set_info_visible(show_item_info)
	items.append(item)
	return item


func _apply_gravity() -> void:
	PhysicsServer3D.area_set_param(get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY, Tuning.v("gravity"))


# --- 진행 ------------------------------------------------------------------

func _on_start_pressed() -> void:
	if phase != Phase.STACKING:
		return
	_hand.release()
	# 지게 위 상품만 짐으로 등록하고, 선반에 남은 건 두고 간다
	for item: ItemBody in items.duplicate():
		if _porter.carrier.is_in_load_zone(item.global_position):
			haul.register(item.uid, item.item_id)
		else:
			_remove_item(item)
	phase = Phase.WALKING
	_camera.fixed_focus = null
	_hud.show_walking()
	_porter.start_walking()


func _on_porter_arrived() -> void:
	if phase != Phase.WALKING:
		return
	phase = Phase.ARRIVING
	_arrive_timer = ARRIVAL_SETTLE_TIME


func _finish_trip() -> void:
	phase = Phase.RESULT
	_hand.release()
	_hand.active = false
	var on_carrier: Array = []
	for item: ItemBody in items:
		if _porter.carrier.is_in_load_zone(item.global_position):
			on_carrier.append(item.uid)
	haul.finish(on_carrier)
	var result: ResultPanel = ResultPanel.new()
	add_child(result)
	result.show_result(haul.summary(), item_defs)
	result.retry_pressed.connect(_restart)


func _check_lost_items() -> void:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	for item: ItemBody in items.duplicate():
		if item.is_held or not haul.has(item.uid):
			continue
		var pos: Vector3 = item.global_position
		if _porter.carrier.is_in_load_zone(pos):
			continue
		# 물건의 오른쪽 끝까지 화면 왼쪽 밖으로 나가면 잃음
		var right_edge: Vector3 = pos + Vector3(item.half_extents_2d().length(), 0.0, 0.0)
		var screen: Vector2 = _camera.unproject_position(right_edge)
		var off_left: bool = screen.x < viewport_rect.position.x - OFFSCREEN_MARGIN_PX
		var fell: bool = pos.y < profile.height_at(pos.x) - KILL_DEPTH
		if off_left or fell:
			if haul.mark_lost(item.uid):
				_hud.toast(Loc.format("ui.lost_toast", { "item": Loc.name_of(item.definition) }))
			_remove_item(item)


func _count_on_carrier() -> int:
	var n: int = 0
	for item: ItemBody in items:
		if _porter.carrier.is_in_load_zone(item.global_position):
			n += 1
	return n


func _remove_item(item: ItemBody) -> void:
	if _hand.held == item:
		_hand.release()
	items.erase(item)
	item.queue_free()


# --- 사건 ------------------------------------------------------------------

func _on_item_broken(item: ItemBody) -> void:
	var text: String = Loc.format("ui.broke_toast", { "item": Loc.name_of(item.definition) })
	var effect: BreakEffect = BreakEffect.new()
	_effects.add_child(effect)
	effect.setup(item.global_transform, Color.html(item.definition.get("color", "#cccccc")), item.half_extents_2d(), text)
	_hud.toast(text)
	haul.mark_broken(item.uid)
	_remove_item(item)


func _on_hand_grabbed(_item: ItemBody, liftable: bool) -> void:
	if not liftable:
		_hud.toast(tr("ui.too_heavy"))


func _on_tuning_changed(key: String, _value: float) -> void:
	if key == "gravity":
		_apply_gravity()
	elif key == "road_bump_scale":
		_rebuild_timer = ROAD_REBUILD_DELAY


func _on_tuning_reloaded() -> void:
	_apply_gravity()
	_rebuild_timer = ROAD_REBUILD_DELAY


func _on_road_rebuild_requested(road_id: String, order_text: String) -> void:
	selected_road_id = road_id
	custom_order_text = order_text
	_restart()


func _on_info_toggled(on: bool) -> void:
	show_item_info = on
	for item: ItemBody in items:
		item.set_info_visible(on)


func _restart() -> void:
	get_tree().reload_current_scene()
