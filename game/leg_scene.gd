extends Node3D
## M2 한 구간: 출발 장터 좌판에서 상품을 지게에 쌓기(사기) -> 출발 -> 길 -> 도착 장터에서 팔기.
## 돈과 짐 규칙은 core/LegTrade, 물리 세계는 physics/trip/TripWorld 가 맡는다.

enum Phase { MARKET, WALKING, ARRIVING, SELLING }

const ITEMS_DIR: String = "res://data/items"
const ROADS_DIR: String = "res://data/roads"
const MARKETS_DIR: String = "res://data/markets"
const ECONOMY_PATH: String = "res://data/economy.json"
const CARRIER_PATH: String = "res://data/carriers/carrier_jige.json"
const DEFAULT_ORIGIN_ID: String = "market_gwangju"
const PORTER_START_X: float = -2.0
## 지게 받침과 좌판 사이 틈
const STALL_GAP: float = 0.55
## 도착 장터 표시를 도착 지점에서 이만큼 앞에
const DESTINATION_BOOTH_OFFSET: float = 1.5
const DESTINATION_BOOTH_WIDTH: float = 3.0
const ARRIVAL_SETTLE_TIME: float = 1.0

## 다시 시작해도 유지하는 선택
static var origin_market_id: String = DEFAULT_ORIGIN_ID
## 비어 있지 않으면 장터 사이 길 대신 이 길로 (조정 패널에서 바꿈)
static var road_override_id: String = ""
static var custom_order_text: String = ""
static var show_item_info: bool = false

var phase: Phase = Phase.MARKET
var trade: LegTrade
var world: TripWorld
var item_defs: Dictionary = {}
var markets: Dictionary = {}
var road_defs: Dictionary = {}
var origin: Dictionary = {}
var destination: Dictionary = {}

var _hud: Hud
var _panel: TuningPanel
var _sell_panel: SellPanel
var _arrive_timer: float = 0.0


func _ready() -> void:
	item_defs = JsonData.load_by_id(ITEMS_DIR)
	markets = JsonData.load_by_id(MARKETS_DIR)
	road_defs = RoadCatalog.load_roads(ROADS_DIR)
	if not markets.has(origin_market_id):
		origin_market_id = DEFAULT_ORIGIN_ID
	origin = markets[origin_market_id]
	var route: Dictionary = origin["routes"][0]
	destination = markets[route["to"]]
	var road_id: String = road_override_id if road_defs.has(road_override_id) else String(route["road"])
	trade = LegTrade.new(JsonData.load_file(ECONOMY_PATH), item_defs, origin, destination)

	world = TripWorld.new()
	world.name = "World"
	add_child(world)
	world.setup(road_defs[road_id], JsonData.load_file(CARRIER_PATH), PORTER_START_X, custom_order_text)
	world.item_broken.connect(_on_item_broken)
	world.untracked_item_broken.connect(_on_untracked_broken)
	world.item_lost.connect(_on_item_lost)
	world.porter_arrived.connect(_on_porter_arrived)
	world.heavy_grabbed.connect(func(_item: ItemBody) -> void: _hud.toast(tr("ui.too_heavy")))
	_build_stall()
	_build_destination_booth()
	world.set_info_visible(show_item_info)

	_hud = Hud.new()
	add_child(_hud)
	_hud.start_pressed.connect(_on_start_pressed)
	_hud.show_stacking(Loc.format("ui.hint_market", { "market": Loc.name_of(origin) }))
	_panel = TuningPanel.new()
	add_child(_panel)
	_panel.set_roads(road_defs, road_id, custom_order_text)
	_panel.road_rebuild_requested.connect(_on_road_rebuild_requested)
	_panel.restart_requested.connect(_restart)
	_panel.info_toggled.connect(_on_info_toggled)


func _physics_process(delta: float) -> void:
	if phase == Phase.ARRIVING:
		_arrive_timer -= delta
		if _arrive_timer <= 0.0:
			_open_selling()


func _process(_delta: float) -> void:
	var on_carrier: Array[ItemBody] = world.items_on_carrier()
	match phase:
		Phase.MARKET:
			var ids: Array = _item_ids(on_carrier)
			var short: int = trade.shortage(ids)
			_hud.set_trade(trade.ledger.money, trade.cart_total(ids), short)
			_hud.set_start_enabled(short == 0)
			_hud.set_info(on_carrier.size(), -1.0, false)
		Phase.WALKING, Phase.ARRIVING:
			_hud.set_trade(trade.ledger.money, -1, 0)
			_hud.set_info(on_carrier.size(), maxf(world.profile.finish_x - world.porter.distance_x, 0.0),
				world.porter.is_slowed)


# --- 장터 (사기) ------------------------------------------------------------

func _build_stall() -> void:
	var spawned: Array[ItemBody] = []
	var ids: Array = (origin["sells"] as Dictionary).keys()
	ids.sort()
	for item_id: String in ids:
		for i: int in range(MarketRules.stock_count(item_id, origin, trade.economy)):
			var item: ItemBody = world.spawn_item(item_defs[item_id])
			item.set_tag(Loc.format("ui.price_tag", { "n": trade.buy_price(item_id) }))
			spawned.append(item)
	var rows: Array = StackingShelf.split_by_mass(spawned)
	var shelf: StackingShelf = StackingShelf.new()
	world.add_child(shelf)
	var right_x: float = world.carrier_left_x() - STALL_GAP
	var ground: float = world.profile.height_at(right_x)
	shelf.build_for(right_x, ground, float(world.carrier_def["shelf_height"]), rows[0], rows[1])
	var booth: MarketBooth = MarketBooth.new()
	world.add_child(booth)
	booth.build(shelf.left_x, right_x, ground, Loc.name_of(origin))
	world.show_stacking_area(shelf.left_x)


func _build_destination_booth() -> void:
	var left: float = world.profile.finish_x + DESTINATION_BOOTH_OFFSET
	var booth: MarketBooth = MarketBooth.new()
	world.add_child(booth)
	booth.build(left, left + DESTINATION_BOOTH_WIDTH, world.profile.height_at(left), Loc.name_of(destination))


func _on_start_pressed() -> void:
	if phase != Phase.MARKET:
		return
	var cart: Array = []
	var on_carrier: Array[ItemBody] = world.items_on_carrier()
	for item: ItemBody in on_carrier:
		cart.append({ "uid": item.uid, "item_id": item.item_id })
	var cost: int = trade.cart_total(_item_ids(on_carrier))
	if not trade.depart(cart):
		return
	for item: ItemBody in world.items.duplicate():
		if on_carrier.has(item):
			world.track(item)
			item.set_tag("")
		else:
			world.remove_item(item)
	phase = Phase.WALKING
	_hud.show_walking()
	_hud.toast(Loc.format("ui.paid_toast", { "n": cost }))
	world.start_walking()


# --- 이동 -------------------------------------------------------------------

func _on_porter_arrived() -> void:
	if phase != Phase.WALKING:
		return
	phase = Phase.ARRIVING
	_arrive_timer = ARRIVAL_SETTLE_TIME
	_hud.toast(Loc.format("ui.arrived_at", { "market": Loc.name_of(destination) }))


func _on_item_broken(uid: int, definition: Dictionary) -> void:
	_hud.toast(Loc.format("ui.broke_toast", { "item": Loc.name_of(definition) }))
	trade.haul.mark_broken(uid)


func _on_untracked_broken(definition: Dictionary) -> void:
	_hud.toast(Loc.format("ui.untracked_broke", { "item": Loc.name_of(definition) }))


func _on_item_lost(uid: int, definition: Dictionary) -> void:
	if trade.haul.mark_lost(uid):
		_hud.toast(Loc.format("ui.lost_toast", { "item": Loc.name_of(definition) }))


# --- 도착 (팔기) ------------------------------------------------------------

func _open_selling() -> void:
	phase = Phase.SELLING
	world.hand.release()
	world.hand.active = false
	world.checking_lost = false
	var on_carrier: Array = []
	var conditions: Dictionary = {}
	for item: ItemBody in world.items_on_carrier():
		on_carrier.append(item.uid)
		conditions[item.uid] = Breakage.durability_ratio(item.durability, item.max_durability)
	trade.haul.finish(on_carrier, conditions)
	_sell_panel = SellPanel.new()
	add_child(_sell_panel)
	_sell_panel.sell_requested.connect(_on_sell_requested)
	_sell_panel.sell_all_requested.connect(_on_sell_all)
	_sell_panel.retry_pressed.connect(_restart)
	_refresh_sell_panel()


func _on_sell_requested(uid: int) -> void:
	if trade.sell(uid) > 0:
		_remove_sold(uid)
	_refresh_sell_panel()


func _on_sell_all() -> void:
	var arrived: Array[int] = trade.haul.uids_with_status(HaulState.Status.ARRIVED)
	trade.sell_all()
	for uid: int in arrived:
		_remove_sold(uid)
	_refresh_sell_panel()


## 판 상품은 지게에서 내려 사라진다
func _remove_sold(uid: int) -> void:
	for item: ItemBody in world.items:
		if item.uid == uid:
			world.remove_item(item)
			return


func _refresh_sell_panel() -> void:
	var rows: Array = []
	for status: HaulState.Status in [HaulState.Status.ARRIVED, HaulState.Status.SOLD]:
		for uid: int in trade.haul.uids_with_status(status):
			rows.append({
				"uid": uid,
				"name": Loc.name_of(item_defs[trade.haul.get_item_id(uid)]),
				"condition": trade.haul.get_condition(uid),
				"price": trade.sale_price(uid),
				"sold": status == HaulState.Status.SOLD,
			})
	var losses: Array = []
	for loss: Dictionary in trade.losses():
		var kind_key: String = "ui.broken" if loss["status"] == HaulState.Status.BROKEN else "ui.lost"
		losses.append({ "kind": "[%s]" % tr(kind_key), "name": Loc.name_of(item_defs[loss["item_id"]]),
			"value": loss["value"] })
	var totals: Dictionary = {
		"money": trade.ledger.money, "spent": trade.ledger.spent,
		"earned": trade.ledger.earned, "profit": trade.ledger.profit(),
	}
	_sell_panel.refresh(Loc.name_of(destination), rows, losses, totals)


# --- 기타 -------------------------------------------------------------------

func _item_ids(items: Array[ItemBody]) -> Array:
	var ids: Array = []
	for item: ItemBody in items:
		ids.append(item.item_id)
	return ids


func _on_road_rebuild_requested(road_id: String, order_text: String) -> void:
	road_override_id = road_id
	custom_order_text = order_text
	_restart()


func _on_info_toggled(on: bool) -> void:
	show_item_info = on
	world.set_info_visible(on)


func _restart() -> void:
	get_tree().reload_current_scene()
