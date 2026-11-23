extends GutTest
## 파손 계산: 기준 미만 충격은 내구도 그대로, 기준 이상은 감소, 아주 센 충격은 즉시 파손

const THRESHOLD: float = 1.2
const BREAK: float = 4.0
const SCALE: float = 10.0
const DURABILITY: float = 30.0


func test_below_threshold_keeps_durability() -> void:
	var r: Breakage.Result = Breakage.apply_impact(DURABILITY, THRESHOLD - 0.01, THRESHOLD, BREAK, SCALE)
	assert_eq(r.durability, DURABILITY)
	assert_eq(r.damage, 0.0)
	assert_false(r.broken)


func test_zero_impact_keeps_durability() -> void:
	var r: Breakage.Result = Breakage.apply_impact(DURABILITY, 0.0, THRESHOLD, BREAK, SCALE)
	assert_eq(r.durability, DURABILITY)


func test_above_threshold_reduces_durability() -> void:
	var r: Breakage.Result = Breakage.apply_impact(DURABILITY, 2.0, THRESHOLD, BREAK, SCALE)
	assert_almost_eq(r.durability, DURABILITY - (2.0 - THRESHOLD) * SCALE, 0.0001)
	assert_false(r.broken)
	assert_false(r.instant)


func test_bigger_impact_more_damage() -> void:
	var small: Breakage.Result = Breakage.apply_impact(DURABILITY, 1.5, THRESHOLD, BREAK, SCALE)
	var big: Breakage.Result = Breakage.apply_impact(DURABILITY, 3.5, THRESHOLD, BREAK, SCALE)
	assert_gt(big.damage, small.damage)


func test_very_strong_impact_breaks_instantly() -> void:
	var r: Breakage.Result = Breakage.apply_impact(DURABILITY, BREAK, THRESHOLD, BREAK, SCALE)
	assert_true(r.broken)
	assert_true(r.instant)
	assert_eq(r.durability, 0.0)


func test_accumulated_damage_breaks() -> void:
	var durability: float = DURABILITY
	var broken: bool = false
	var hits: int = 0
	while not broken and hits < 100:
		var r: Breakage.Result = Breakage.apply_impact(durability, 3.0, THRESHOLD, BREAK, SCALE)
		durability = r.durability
		broken = r.broken
		hits += 1
	assert_true(broken, "약한 충격이 쌓이면 깨진다")
	assert_gt(hits, 1, "한 번에 깨지지 않는 충격")
	assert_eq(durability, 0.0)


func test_unbreakable_never_breaks() -> void:
	var r: Breakage.Result = Breakage.apply_impact(DURABILITY, 9999.0, THRESHOLD, BREAK, SCALE, true)
	assert_false(r.broken)
	assert_eq(r.durability, DURABILITY)


func test_damage_scale_zero_means_no_damage_below_break() -> void:
	var r: Breakage.Result = Breakage.apply_impact(DURABILITY, 3.0, THRESHOLD, BREAK, 0.0)
	assert_eq(r.durability, DURABILITY)
	assert_false(r.broken)


func test_impact_impulse_static_other_uses_own_mass() -> void:
	assert_almost_eq(Breakage.impact_impulse(3.0, 1.2, 0.0), 3.6, 0.0001)


func test_impact_impulse_reduced_mass() -> void:
	# 1kg 와 1kg 가 부딪히면 환산 질량 0.5
	assert_almost_eq(Breakage.impact_impulse(2.0, 1.0, 1.0), 1.0, 0.0001)


func test_impact_impulse_non_positive_speed() -> void:
	assert_eq(Breakage.impact_impulse(0.0, 1.0, 0.0), 0.0)
	assert_eq(Breakage.impact_impulse(-1.0, 1.0, 0.0), 0.0)


func test_durability_ratio() -> void:
	assert_almost_eq(Breakage.durability_ratio(15.0, 30.0), 0.5, 0.0001)
	assert_eq(Breakage.durability_ratio(50.0, 30.0), 1.0)
	assert_eq(Breakage.durability_ratio(5.0, 0.0), 0.0)
