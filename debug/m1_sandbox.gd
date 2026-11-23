extends Node3D
## M1 물리 샌드박스. 선반에서 지게로 짐 쌓기 -> 출발 -> 길 걷기 -> 도착 결과.
## 물리 세계는 TripWorld 가 맡고, 짐 상태 기록은 core/HaulState 가 맡는다.
## M2 이후에도 물리 손맛 확인용으로 남겨 둔다 (상품 10개 전부, 돈 없음).

enum Phase { STACKING, WALKING, ARRIVING, RESULT }

const ITEMS_DIR: String = "res://data/items"
const ROADS_DIR: String = "res://data/roads"
const CARRIER_PATH: String = "res://data/carriers/carrier_jige.json"
const DEFAULT_ROAD_ID: String = "road_m1_mixed"
const PORTER_START_X: float = -2.0
## 지게 받침과 선반 사이 틈
const SHELF_GAP: float = 0.55
## 도착 후 짐이 가라앉기를 기다리는 시간
const ARRIVAL_SETTLE_TIME: float = 1.0

## 다시 시작해도 유지하는 선택 (길, 구간 순서, 정보 표시)
static var selected_road_id: String = DEFAULT_ROAD_ID
static var custom_order_text: String = ""
static var show_item_info: bool = false

var phase: Phase = Phase.STACKING
var haul: HaulState = HaulState.new()
var item_defs: Dictionary = {}
var road_defs: Dictionary = {}
var world: TripWorld

var _hud: Hud
var _panel: TuningPanel
var _arrive_timer: float = 0.0


func _ready() -> void:
	item_defs = JsonData.load_by_id(ITEMS_DIR)
	road_defs = RoadCatalog.load_roads(ROADS_DIR)
	if not road_defs.has(selected_road_id):
		selected_road_id = DEFAULT_ROAD_ID
	world = TripWorld.new()
	world.name = "World"
	add_child(world)
	world.setup(road_defs[selected_road_id], JsonData.load_file(CARRIER_PATH), PORTER_START_X, custom_order_text)
	world.item_broken.connect(_on_item_broken)
	world.untracked_item_broken.connect(_on_untracked_broken)
	world.item_lost.connect(_on_item_lost)
	world.porter_arrived.connect(_on_porter_arrived)
	world.heavy_grabbed.connect(func(_item: ItemBody) -> void: _hud.toast(tr("ui.too_heavy")))

	var spawned: Array[ItemBody] = []
	var ids: Array = item_defs.keys()
	ids.sort()
	for item_id: String in ids:
		spawned.append(world.spawn_item(item_defs[item_id]))
	var rows: Array = StackingShelf.split_by_mass(spawned)
	var shelf: StackingShelf = StackingShelf.new()
	world.add_child(shelf)
	var right_x: float = world.carrier_left_x() - SHELF_GAP
	shelf.build_for(right_x, world.profile.height_at(right_x), float(world.carrier_def["shelf_height"]), rows[0], rows[1])
	world.set_info_visible(show_item_info)
	world.show_stacking_area(shelf.left_x)

	_hud = Hud.new()
	add_child(_hud)
	_hud.start_pressed.connect(_on_start_pressed)
	_panel = TuningPanel.new()
	add_child(_panel)
	_panel.set_roads(road_defs, selected_road_id, custom_order_text)
	_panel.road_rebuild_requested.connect(_on_road_rebuild_requested)
	_panel.restart_requested.connect(_restart)
	_panel.info_toggled.connect(_on_info_toggled)


func _physics_process(delta: float) -> void:
	if phase == Phase.ARRIVING:
		_arrive_timer -= delta
		if _arrive_timer <= 0.0:
			_finish_trip()


func _process(_delta: float) -> void:
	var on_carrier: int = world.items_on_carrier().size()
	if phase == Phase.WALKING or phase == Phase.ARRIVING:
		_hud.set_info(on_carrier, maxf(world.profile.finish_x - world.porter.distance_x, 0.0), world.porter.is_slowed)
	elif phase == Phase.STACKING:
		_hud.set_info(on_carrier, -1.0, false)


func _on_start_pressed() -> void:
	if phase != Phase.STACKING:
		return
	# 지게 위 상품만 짐으로 등록하고, 선반에 남은 건 두고 간다
	for item: ItemBody in world.items.duplicate():
		if world.is_on_carrier(item):
			haul.register(item.uid, item.item_id)
			world.track(item)
		else:
			world.remove_item(item)
	phase = Phase.WALKING
	_hud.show_walking()
	world.start_walking()


func _on_porter_arrived() -> void:
	if phase != Phase.WALKING:
		return
	phase = Phase.ARRIVING
	_arrive_timer = ARRIVAL_SETTLE_TIME


func _finish_trip() -> void:
	phase = Phase.RESULT
	world.hand.release()
	world.hand.active = false
	world.checking_lost = false
	var on_carrier: Array = []
	for item: ItemBody in world.items_on_carrier():
		on_carrier.append(item.uid)
	haul.finish(on_carrier)
	var result: ResultPanel = ResultPanel.new()
	add_child(result)
	result.show_result(haul.summary(), item_defs)
	result.retry_pressed.connect(_restart)


func _on_item_broken(uid: int, definition: Dictionary) -> void:
	_hud.toast(Loc.format("ui.broke_toast", { "item": Loc.name_of(definition) }))
	haul.mark_broken(uid)


func _on_untracked_broken(definition: Dictionary) -> void:
	_hud.toast(Loc.format("ui.broke_toast", { "item": Loc.name_of(definition) }))


func _on_item_lost(uid: int, definition: Dictionary) -> void:
	if haul.mark_lost(uid):
		_hud.toast(Loc.format("ui.lost_toast", { "item": Loc.name_of(definition) }))


func _on_road_rebuild_requested(road_id: String, order_text: String) -> void:
	selected_road_id = road_id
	custom_order_text = order_text
	_restart()


func _on_info_toggled(on: bool) -> void:
	show_item_info = on
	world.set_info_visible(on)


func _restart() -> void:
	get_tree().reload_current_scene()
