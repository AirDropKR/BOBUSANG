class_name TradeLedger
extends RefCounted
## 엽전 장부. 가진 돈과 이번에 쓴 돈, 번 돈을 기록한다.

var money: int = 0
var spent: int = 0
var earned: int = 0


func _init(starting_money: int = 0) -> void:
	money = starting_money


func can_afford(cost: int) -> bool:
	return cost >= 0 and cost <= money


## 값을 치른다. 돈이 모자라면 아무것도 바꾸지 않고 false
func pay(cost: int) -> bool:
	if not can_afford(cost):
		return false
	money -= cost
	spent += cost
	return true


func receive(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	earned += amount


## 이번 장사 손익 (번 돈 - 쓴 돈)
func profit() -> int:
	return earned - spent
