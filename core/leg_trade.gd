class_name LegTrade
extends RefCounted
## 한 구간 장사: 출발 장터에서 사서 -> 이동 -> 도착 장터에서 판다.
## 돈(TradeLedger), 짐 상태(HaulState), 시세(MarketRules)를 묶는다. 물리 쪽은 결과만 알려준다.

var economy: Dictionary
var item_defs: Dictionary
var origin_market: Dictionary
var destination_market: Dictionary
var ledger: TradeLedger
var haul: HaulState = HaulState.new()
var departed: bool = false
## uid -> 출발 장터에서 치른 값
var _paid: Dictionary = {}


func _init(p_economy: Dictionary, p_item_defs: Dictionary, p_origin: Dictionary, p_destination: Dictionary,
		starting_money: int = -1) -> void:
	economy = p_economy
	item_defs = p_item_defs
	origin_market = p_origin
	destination_market = p_destination
	var money: int = int(economy["starting_money"]) if starting_money < 0 else starting_money
	ledger = TradeLedger.new(money)


func buy_price(item_id: String) -> int:
	return MarketRules.buy_price(item_defs[item_id], origin_market)


## 지게 위 상품 값의 합 (item_id 배열)
func cart_total(item_ids: Array) -> int:
	var defs: Array = []
	for item_id: String in item_ids:
		defs.append(item_defs[item_id])
	return MarketRules.total_buy_price(defs, origin_market)


## 모자라는 돈 (모자라지 않으면 0)
func shortage(item_ids: Array) -> int:
	return maxi(cart_total(item_ids) - ledger.money, 0)


## 출발: cart 는 [{ "uid": int, "item_id": String }]. 값을 치르고 짐으로 등록한다. 돈이 모자라면 false
func depart(cart: Array) -> bool:
	if departed:
		return false
	var ids: Array = []
	for entry: Dictionary in cart:
		ids.append(entry["item_id"])
	var total: int = cart_total(ids)
	if total == MarketRules.NOT_SOLD or not ledger.pay(total):
		return false
	for entry: Dictionary in cart:
		haul.register(entry["uid"], entry["item_id"])
		_paid[entry["uid"]] = buy_price(entry["item_id"])
	departed = true
	return true


## 도착 장터에서 이 상품을 팔 때 값 (도착한 상품만, 아니면 0)
func sale_price(uid: int) -> int:
	var status: int = haul.get_status(uid)
	if status != HaulState.Status.ARRIVED and status != HaulState.Status.SOLD:
		return 0
	var item_def: Dictionary = item_defs[haul.get_item_id(uid)]
	return MarketRules.sell_price(item_def, destination_market, economy, haul.get_condition(uid))


## 판다. 받은 돈 (못 팔면 0)
func sell(uid: int) -> int:
	if haul.get_status(uid) != HaulState.Status.ARRIVED:
		return 0
	var price: int = sale_price(uid)
	haul.mark_sold(uid)
	ledger.receive(price)
	return price


func sell_all() -> int:
	var total: int = 0
	for uid: int in haul.uids_with_status(HaulState.Status.ARRIVED):
		total += sell(uid)
	return total


func paid_for(uid: int) -> int:
	return _paid.get(uid, 0)


## 깨지거나 잃어서 날린 값 목록 [{ uid, item_id, status, value }]
func losses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for status: HaulState.Status in [HaulState.Status.BROKEN, HaulState.Status.LOST]:
		for uid: int in haul.uids_with_status(status):
			out.append({ "uid": uid, "item_id": haul.get_item_id(uid), "status": status, "value": paid_for(uid) })
	return out
