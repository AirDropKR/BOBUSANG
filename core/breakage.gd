class_name Breakage
extends RefCounted
## 상품 파손 규칙. 물리를 모르고, 충격 세기(충격량) 숫자만 받아 내구도를 계산한다.
##
## 규칙
## - 충격 < 손상 기준(damage_threshold): 내구도 그대로
## - 손상 기준 <= 충격 < 즉시 파손 기준(break_impulse): (충격 - 기준) * 손상 배율 만큼 내구도 감소
## - 충격 >= 즉시 파손 기준: 바로 깨짐
## - 내구도가 0 이하가 되면 깨짐

## 파손 판정 결과
class Result:
	extends RefCounted
	var durability: float
	var damage: float
	var broken: bool
	var instant: bool

	func _init(p_durability: float, p_damage: float, p_broken: bool, p_instant: bool) -> void:
		durability = p_durability
		damage = p_damage
		broken = p_broken
		instant = p_instant


## 충격 하나를 적용한 결과를 돌려준다.
## unbreakable 이면 어떤 충격에도 깨지지 않는다 (놋그릇 같은 금속).
static func apply_impact(
		current_durability: float,
		impact: float,
		damage_threshold: float,
		break_impulse: float,
		damage_scale: float,
		unbreakable: bool = false) -> Result:
	if unbreakable:
		return Result.new(current_durability, 0.0, false, false)
	if current_durability <= 0.0:
		return Result.new(0.0, 0.0, true, false)
	if impact < damage_threshold:
		return Result.new(current_durability, 0.0, false, false)
	if impact >= break_impulse:
		return Result.new(0.0, current_durability, true, true)
	var damage: float = (impact - damage_threshold) * damage_scale
	var remaining: float = maxf(current_durability - damage, 0.0)
	return Result.new(remaining, current_durability - remaining, remaining <= 0.0, false)


## 남은 내구도 비율 (0~1). 연출(금 간 색)에 쓴다.
static func durability_ratio(current_durability: float, max_durability: float) -> float:
	if max_durability <= 0.0:
		return 0.0
	return clampf(current_durability / max_durability, 0.0, 1.0)


## 두 물체가 부딪힐 때의 충격량 추정값 (N·s).
## 다가오던 상대 속도(접촉면 방향 성분)와 환산 질량으로 계산한다. 다른 쪽이 움직이지 않는 물체(땅, 지게)면
## other_mass 에 0 이하를 넘긴다. 이렇게 하면 물리 틱 속도와 상관없이 같은 낙하는 같은 충격이 된다.
static func impact_impulse(approach_speed: float, own_mass: float, other_mass: float) -> float:
	if approach_speed <= 0.0 or own_mass <= 0.0:
		return 0.0
	var reduced_mass: float = own_mass
	if other_mass > 0.0:
		reduced_mass = own_mass * other_mass / (own_mass + other_mass)
	return approach_speed * reduced_mass
