extends GutTest
## 시세 계산: 사는 값, 파는 값, 상태 배율, 좌판 개수

const ECONOMY: Dictionary = {
	"id": "economy_test", "starting_money": 300, "default_sell_multiplier": 0.9,
	"min_condition_factor": 0.3, "default_stock": 1,
}
const PORCELAIN: Dictionary = { "id": "item_white_porcelain", "base_price": 120 }
const BOWL: Dictionary = { "id": "item_brass_bowl", "base_price": 60, "unbreakable": true }
const SALT: Dictionary = { "id": "item_salt_sack", "base_price": 20 }
const ORIGIN: Dictionary = {
	"id": "market_a", "sells": { "item_white_porcelain": 0.6, "item_salt_sack": 1.1 },
	"stock": { "item_white_porcelain": 3 }, "buys": {},
}
const DEST: Dictionary = { "id": "market_b", "sells": {}, "buys": { "item_white_porcelain": 1.5 } }


func test_buy_price_uses_sell_multiplier() -> void:
	assert_eq(MarketRules.buy_price(PORCELAIN, ORIGIN), 72)
	assert_eq(MarketRules.buy_price(SALT, ORIGIN), 22)


func test_buy_price_not_sold() -> void:
	assert_eq(MarketRules.buy_price(BOWL, ORIGIN), MarketRules.NOT_SOLD)


func test_sell_price_intact_uses_buys_multiplier() -> void:
	assert_eq(MarketRules.sell_price(PORCELAIN, DEST, ECONOMY, 1.0), 180)


func test_sell_price_default_multiplier() -> void:
	assert_eq(MarketRules.sell_price(SALT, DEST, ECONOMY, 1.0), 18, "buys 에 없으면 기본 배율 0.9")


func test_damaged_sells_for_less() -> void:
	var intact: int = MarketRules.sell_price(PORCELAIN, DEST, ECONOMY, 1.0)
	var half: int = MarketRules.sell_price(PORCELAIN, DEST, ECONOMY, 0.5)
	var nearly_broken: int = MarketRules.sell_price(PORCELAIN, DEST, ECONOMY, 0.0)
	assert_lt(half, intact)
	assert_lt(nearly_broken, half)
	assert_eq(nearly_broken, 54, "내구도 0에 가까우면 30%")


func test_unbreakable_ignores_condition() -> void:
	assert_eq(MarketRules.sell_price(BOWL, DEST, ECONOMY, 0.1), MarketRules.sell_price(BOWL, DEST, ECONOMY, 1.0))


func test_condition_factor_clamped() -> void:
	assert_eq(MarketRules.condition_factor(2.0, ECONOMY), 1.0)
	assert_almost_eq(MarketRules.condition_factor(-1.0, ECONOMY), 0.3, 0.0001)


func test_price_never_below_one() -> void:
	var cheap: Dictionary = { "id": "item_cheap", "base_price": 1 }
	var market: Dictionary = { "id": "market_c", "sells": { "item_cheap": 0.1 }, "buys": { "item_cheap": 0.1 } }
	assert_eq(MarketRules.buy_price(cheap, market), 1)
	assert_eq(MarketRules.sell_price(cheap, market, ECONOMY, 0.0), 1)


func test_stock_count() -> void:
	assert_eq(MarketRules.stock_count("item_white_porcelain", ORIGIN, ECONOMY), 3)
	assert_eq(MarketRules.stock_count("item_salt_sack", ORIGIN, ECONOMY), 1, "stock 에 없으면 기본 개수")
	assert_eq(MarketRules.stock_count("item_brass_bowl", ORIGIN, ECONOMY), 0, "안 파는 상품은 0")


func test_total_buy_price() -> void:
	assert_eq(MarketRules.total_buy_price([PORCELAIN, PORCELAIN, SALT], ORIGIN), 166)
	assert_eq(MarketRules.total_buy_price([], ORIGIN), 0)
	assert_eq(MarketRules.total_buy_price([PORCELAIN, BOWL], ORIGIN), MarketRules.NOT_SOLD)
