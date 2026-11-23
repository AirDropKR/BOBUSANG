class_name HaulState
extends RefCounted
## 한 번의 이동(한 구간) 동안 짐의 상태를 기록한다. 물리 쪽은 "깨졌다, 잃었다, 도착했다"만 알려준다.
## M1에서는 돈 계산 없이 상품 목록만 다룬다.

enum Status { CARRIED, BROKEN, LOST, ARRIVED }

## key: 물체 고유 번호(int), value: { "item_id": String, "status": Status }
var _entries: Dictionary = {}
var _finished: bool = false


## 출발할 때 지게에 실린 상품을 등록한다.
func register(uid: int, item_id: String) -> void:
	_entries[uid] = { "item_id": item_id, "status": Status.CARRIED }


func has(uid: int) -> bool:
	return _entries.has(uid)


func get_status(uid: int) -> int:
	if not _entries.has(uid):
		return -1
	return _entries[uid]["status"]


func is_finished() -> bool:
	return _finished


func carried_count() -> int:
	return _count_status(Status.CARRIED)


## 깨짐. 이미 결과가 정해진 상품은 바꾸지 않는다. 바뀌었으면 true.
func mark_broken(uid: int) -> bool:
	return _set_final(uid, Status.BROKEN)


## 잃어버림 (화면 밖으로 사라짐, 줍지 못함).
func mark_lost(uid: int) -> bool:
	return _set_final(uid, Status.LOST)


## 도착 처리. on_carrier_uids 에 든 상품은 도착, 나머지 아직 운반 중인 상품은 잃은 것으로 친다.
func finish(on_carrier_uids: Array) -> void:
	if _finished:
		return
	for uid: int in _entries.keys():
		if _entries[uid]["status"] != Status.CARRIED:
			continue
		if on_carrier_uids.has(uid):
			_entries[uid]["status"] = Status.ARRIVED
		else:
			_entries[uid]["status"] = Status.LOST
	_finished = true


## 결과 목록. 각 값은 상품 id 배열 (같은 상품이 여러 개면 여러 번 들어간다).
func summary() -> Dictionary:
	var result: Dictionary = { "arrived": [], "broken": [], "lost": [], "carried": [] }
	var keys: Dictionary = {
		Status.ARRIVED: "arrived", Status.BROKEN: "broken", Status.LOST: "lost", Status.CARRIED: "carried",
	}
	for uid: int in _entries.keys():
		var entry: Dictionary = _entries[uid]
		(result[keys[entry["status"]]] as Array).append(entry["item_id"])
	return result


func _set_final(uid: int, status: Status) -> bool:
	if _finished or not _entries.has(uid):
		return false
	if _entries[uid]["status"] != Status.CARRIED:
		return false
	_entries[uid]["status"] = status
	return true


func _count_status(status: Status) -> int:
	var n: int = 0
	for uid: int in _entries.keys():
		if _entries[uid]["status"] == status:
			n += 1
	return n
