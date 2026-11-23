extends GutTest
## 한 구간 짐 상태 기록


func _make() -> HaulState:
	var h: HaulState = HaulState.new()
	h.register(1, "item_white_porcelain")
	h.register(2, "item_salt_sack")
	h.register(3, "item_watermelon")
	h.register(4, "item_ginseng")
	return h


func test_register_starts_carried() -> void:
	var h: HaulState = _make()
	assert_eq(h.carried_count(), 4)
	assert_eq(h.get_status(1), HaulState.Status.CARRIED)
	assert_eq(h.get_status(99), -1)


func test_broken_and_lost() -> void:
	var h: HaulState = _make()
	assert_true(h.mark_broken(1))
	assert_true(h.mark_lost(3))
	assert_eq(h.carried_count(), 2)


func test_final_status_does_not_change() -> void:
	var h: HaulState = _make()
	h.mark_broken(1)
	assert_false(h.mark_lost(1), "깨진 상품은 잃은 상품으로 바뀌지 않음")
	assert_eq(h.get_status(1), HaulState.Status.BROKEN)


func test_unknown_uid_ignored() -> void:
	var h: HaulState = _make()
	assert_false(h.mark_broken(42))


func test_finish_splits_arrived_and_lost() -> void:
	var h: HaulState = _make()
	h.mark_broken(1)
	h.finish([2, 4])
	var s: Dictionary = h.summary()
	assert_eq(s["arrived"].size(), 2)
	assert_true(s["arrived"].has("item_salt_sack"))
	assert_true(s["arrived"].has("item_ginseng"))
	assert_eq(s["broken"], ["item_white_porcelain"])
	assert_eq(s["lost"], ["item_watermelon"], "지게에 없는 상품은 잃은 것으로")
	assert_eq(s["carried"].size(), 0)
	assert_true(h.is_finished())


func test_no_changes_after_finish() -> void:
	var h: HaulState = _make()
	h.finish([1, 2, 3, 4])
	assert_false(h.mark_broken(1))
	assert_eq(h.summary()["arrived"].size(), 4)


func test_same_item_id_counts_each() -> void:
	var h: HaulState = HaulState.new()
	h.register(1, "item_onggi")
	h.register(2, "item_onggi")
	h.finish([1, 2])
	assert_eq(h.summary()["arrived"], ["item_onggi", "item_onggi"])
