extends SceneTree
## 화면 없이 한 구간을 돌려 보는 점검용 스크립트 (손맛 판단용이 아니라 오류와 큰 이상 확인용).
## 상품 몇 개를 지게 위에 쌓아 놓고 출발시킨 뒤, 손상과 결과를 출력한다. 손은 쓰지 않는다.
## 실행: godot --headless --path . -s res://tools/smoke_walk.gd -- [m1|m2] [길 id 또는 -] [상품 id,...] [최대 초]
## m2 는 도착 후 모두 팔고 손익까지 출력한다.

const SCENES: Dictionary = {
	"m1": "res://debug/m1_sandbox.tscn",
	"m2": "res://game/leg_scene.tscn",
}
const DEFAULT_STACK: Dictionary = {
	"m1": ["item_salt_sack", "item_onggi", "item_white_porcelain"],
	"m2": ["item_salt_sack", "item_onggi", "item_white_porcelain"],
}
## 장면 단계 번호: 0 = 쌓기, 3 = 결과/팔기
const PHASE_STACKING: int = 0
const PHASE_DONE: int = 3
const DEFAULT_MAX_SECONDS: float = 200.0
const SETTLE_SECONDS: float = 1.5
const STACK_GAP: float = 0.02
const REPORT_INTERVAL: float = 10.0

var _mode: String = "m1"
var _scene: Node
var _elapsed: float = 0.0
var _stacked: bool = false
var _max_seconds: float = DEFAULT_MAX_SECONDS
var _next_report: float = REPORT_INTERVAL
var _stack_ids: Array = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and SCENES.has(args[0]):
		_mode = args[0]
	var script: GDScript = load(SCENES[_mode].replace(".tscn", ".gd"))
	if args.size() > 1 and args[1] != "-":
		script.set("selected_road_id" if _mode == "m1" else "road_override_id", args[1])
	_stack_ids = DEFAULT_STACK[_mode].duplicate()
	if args.size() > 2:
		_stack_ids = Array(args[2].split(",", false))
	if args.size() > 3:
		_max_seconds = float(args[3])
	_scene = (load(SCENES[_mode]) as PackedScene).instantiate()
	root.add_child(_scene)


func _physics_process(delta: float) -> bool:
	_elapsed += delta
	var world: Node = _scene.world
	if not _stacked and _elapsed > 0.2:
		_stack_items(world)
	if _stacked and _elapsed > SETTLE_SECONDS + 0.2 and _scene.phase == PHASE_STACKING:
		_scene._on_start_pressed()
		if _scene.phase == PHASE_STACKING:
			printerr("출발 실패 (돈 부족?)")
			quit(1)
			return false
		print("출발: 지게 위 %d개" % world.items_on_carrier().size())
		for item: Node in world.items:
			item.damaged.connect(_on_damaged)
	if _scene.phase != PHASE_STACKING and _elapsed >= _next_report:
		_next_report += REPORT_INTERVAL
		print("%5.1f초 x=%.1f / %.1f  지게 위 %d" % [_elapsed, world.porter.distance_x, world.profile.finish_x,
			world.items_on_carrier().size()])
	if _scene.phase == PHASE_DONE:
		_report()
		quit(0)
	elif _elapsed > _max_seconds:
		printerr("시간 초과. 위치 x=%.1f" % world.porter.distance_x)
		quit(1)
	return false


func _report() -> void:
	if _mode == "m1":
		print("결과: ", _scene.haul.summary())
		return
	var trade: RefCounted = _scene.trade
	print("도착 결과: ", trade.haul.summary())
	_scene._on_sell_all()
	print("판매 후: 돈 %d, 산 값 %d, 판 값 %d, 손익 %d" % [trade.ledger.money, trade.ledger.spent,
		trade.ledger.earned, trade.ledger.profit()])


## 지정한 상품들을 지게 위에 차례로 쌓는다 (바닥부터)
func _stack_items(world: Node) -> void:
	_stacked = true
	var carrier: Node3D = world.porter.carrier
	var y: float = 0.0
	for id: String in _stack_ids:
		for item: Node in world.items:
			if item.item_id == id and not item.get_meta("stacked", false):
				var half: Vector2 = item.half_extents_2d()
				item.global_position = carrier.global_position + Vector3(0.0, y + half.y + STACK_GAP, 0.0)
				item.rotation = Vector3.ZERO
				item.linear_velocity = Vector3.ZERO
				item.set_meta("stacked", true)
				y += half.y * 2.0 + STACK_GAP
				break


func _on_damaged(item: Node, amount: float) -> void:
	var world: Node = _scene.world
	var x: float = world.porter.distance_x
	print("  손상 %s -%.1f (충격 %.2f, 남은 %.0f) x=%.1f 구간=%s" % [item.item_id, amount, item.last_impact,
		item.durability, x, world.profile.segment_type_at(x)])
