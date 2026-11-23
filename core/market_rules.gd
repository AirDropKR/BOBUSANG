class_name MarketRules
extends RefCounted
## 장터 시세 규칙. 물리를 모르고 데이터(상품, 장터, 경제 설정)와 상품 상태 숫자만 받는다.
##
## - 사는 값 = 기본값 x 그 장터의 파는 배율(sells). 그 장터에서 안 파는 상품이면 -1
## - 파는 값 = 기본값 x 그 장터의 사들이는 배율(buys, 없으면 경제 설정의 기본 배율) x 상태 배율
## - 상태 배율: 내구도 비율이 1이면 1, 0에 가까울수록 min_condition_factor 까지 내려간다
## - 값은 엽전 단위 정수로 반올림하고, 1냥 아래로는 내려가지 않는다

const MIN_PRICE: int = 1
const NOT_SOLD: int = -1


## 이 장터에서 이 상품을 살 수 있으면 값, 없으면 NOT_SOLD
static func buy_price(item_def: Dictionary, market_def: Dictionary) -> int:
	var sells: Dictionary = market_def.get("sells", {})
	var item_id: String = item_def["id"]
	if not sells.has(item_id):
		return NOT_SOLD
	return _round_price(float(item_def["base_price"]) * float(sells[item_id]))


## 이 장터에 이 상품을 팔 때 값. condition_ratio 는 남은 내구도 비율 (0~1)
static func sell_price(item_def: Dictionary, market_def: Dictionary, economy: Dictionary,
		condition_ratio: float) -> int:
	var buys: Dictionary = market_def.get("buys", {})
	var multiplier: float = float(buys.get(item_def["id"], economy["default_sell_multiplier"]))
	var condition: float = condition_factor(condition_ratio, economy)
	if bool(item_def.get("unbreakable", false)):
		condition = 1.0
	return _round_price(float(item_def["base_price"]) * multiplier * condition)


static func condition_factor(condition_ratio: float, economy: Dictionary) -> float:
	var floor_factor: float = clampf(float(economy["min_condition_factor"]), 0.0, 1.0)
	return lerpf(floor_factor, 1.0, clampf(condition_ratio, 0.0, 1.0))


## 이 장터 좌판에 놓이는 개수 (stock 에 없으면 경제 설정의 기본 개수)
static func stock_count(item_id: String, market_def: Dictionary, economy: Dictionary) -> int:
	if not (market_def.get("sells", {}) as Dictionary).has(item_id):
		return 0
	var stock: Dictionary = market_def.get("stock", {})
	return int(stock.get(item_id, economy["default_stock"]))


## 상품 여러 개를 산 값의 합. 안 파는 상품이 섞여 있으면 NOT_SOLD
static func total_buy_price(item_defs: Array, market_def: Dictionary) -> int:
	var total: int = 0
	for item_def: Dictionary in item_defs:
		var price: int = buy_price(item_def, market_def)
		if price == NOT_SOLD:
			return NOT_SOLD
		total += price
	return total


static func _round_price(value: float) -> int:
	return maxi(roundi(value), MIN_PRICE)
