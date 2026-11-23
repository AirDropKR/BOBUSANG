extends GutTest
## 장부와 한 구간 장사 (사기 -> 이동 결과 -> 팔기 정산)

const ECONOMY: Dictionary = {
	"id": "economy_test", "starting_money": 200, "default_sell_multiplier": 0.9,
	"min_condition_factor": 0.3, "default_stock": 1,
}
const ITEMS: Dictionary = {
	"item_white_porcelain": { "id": "item_white_porcelain", "base_price": 120 },
	"item_salt_sack": { "id": "item_salt_sack", "base_price": 20 },
}
const ORIGIN: Dictionary = { "id": "market_a", "sells": { "item_white_porcelain": 0.6, "item_salt_sack": 1.0 }, "buys": {} }
const DEST: Dictionary = { "id": "market_b", "sells": {}, "buys": { "item_white_porcelain": 1.5, "item_salt_sack": 1.2 } }


func _trade() -> LegTrade:
	return LegTrade.new(ECONOMY, ITEMS, ORIGIN, DEST)


# --- 장부 ---

func test_ledger_pay_and_receive() -> void:
	var l: TradeLedger = TradeLedger.new(100)
	assert_true(l.pay(30))
	l.receive(50)
	assert_eq(l.money, 120)
	assert_eq(l.spent, 30)
	assert_eq(l.earned, 50)
	assert_eq(l.profit(), 20)


func test_ledger_cannot_overspend() -> void:
	var l: TradeLedger = TradeLedger.new(10)
	assert_false(l.pay(11))
	assert_eq(l.money, 10)
	assert_eq(l.spent, 0)


func test_ledger_ignores_negative() -> void:
	var l: TradeLedger = TradeLedger.new(10)
	assert_false(l.pay(-5))
	l.receive(-5)
	assert_eq(l.money, 10)


# --- 한 구간 ---

func test_starting_money_from_economy() -> void:
	assert_eq(_trade().ledger.money, 200)


func test_cart_total_and_shortage() -> void:
	var t: LegTrade = _trade()
	assert_eq(t.cart_total(["item_white_porcelain", "item_salt_sack"]), 92)
	assert_eq(t.shortage(["item_white_porcelain", "item_white_porcelain", "item_white_porcelain"]), 16)
	assert_eq(t.shortage(["item_salt_sack"]), 0)


func test_depart_pays_and_registers() -> void:
	var t: LegTrade = _trade()
	assert_true(t.depart([{ "uid": 1, "item_id": "item_white_porcelain" }, { "uid": 2, "item_id": "item_salt_sack" }]))
	assert_eq(t.ledger.money, 108)
	assert_eq(t.haul.carried_count(), 2)
	assert_eq(t.paid_for(1), 72)


func test_depart_fails_without_money() -> void:
	var t: LegTrade = _trade()
	var cart: Array = []
	for uid: int in range(3):
		cart.append({ "uid": uid, "item_id": "item_white_porcelain" })
	assert_false(t.depart(cart))
	assert_eq(t.ledger.money, 200, "돈이 모자라면 아무것도 사지 않음")
	assert_eq(t.haul.carried_count(), 0)


func test_depart_only_once() -> void:
	var t: LegTrade = _trade()
	assert_true(t.depart([]))
	assert_false(t.depart([{ "uid": 1, "item_id": "item_salt_sack" }]))


func test_full_leg_settlement() -> void:
	var t: LegTrade = _trade()
	t.depart([
		{ "uid": 1, "item_id": "item_white_porcelain" },
		{ "uid": 2, "item_id": "item_white_porcelain" },
		{ "uid": 3, "item_id": "item_salt_sack" },
	])
	t.haul.mark_broken(2)
	t.haul.finish([1, 3], { 1: 1.0, 3: 0.5 })
	assert_eq(t.sale_price(1), 180)
	assert_eq(t.sale_price(2), 0, "깨진 상품은 못 판다")
	assert_eq(t.sell(1), 180)
	assert_eq(t.sell(1), 0, "두 번 못 판다")
	assert_eq(t.sell_all(), MarketRules.sell_price(ITEMS["item_salt_sack"], DEST, ECONOMY, 0.5))
	assert_eq(t.ledger.spent, 164)
	assert_eq(t.ledger.earned, 180 + 16)
	assert_eq(t.ledger.profit(), 32)
	var losses: Array[Dictionary] = t.losses()
	assert_eq(losses.size(), 1)
	assert_eq(losses[0]["value"], 72, "깨진 백자는 산 값만큼 손해")


func test_lost_on_finish_counts_as_loss() -> void:
	var t: LegTrade = _trade()
	t.depart([{ "uid": 5, "item_id": "item_salt_sack" }])
	t.haul.finish([])
	assert_eq(t.losses().size(), 1)
	assert_eq(t.haul.get_status(5), HaulState.Status.LOST)


func test_haul_condition_and_sold() -> void:
	var h: HaulState = HaulState.new()
	h.register(1, "item_onggi")
	h.finish([1], { 1: 0.4 })
	assert_almost_eq(h.get_condition(1), 0.4, 0.0001)
	assert_true(h.mark_sold(1))
	assert_false(h.mark_sold(1))
	assert_eq(h.summary()["sold"], ["item_onggi"])
