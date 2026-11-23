extends SceneTree
## 화면 없이 샌드박스를 한 번 돌려 보는 점검용 스크립트 (손맛 판단용이 아니라 오류와 큰 이상 확인용).
## 상품 몇 개를 지게 위에 쌓아 놓고 출발시킨 뒤, 도착 결과를 출력한다. 손은 쓰지 않는다.
## 실행: godot --headless --path . -s res://tools/smoke_walk.gd -- [길 id] [상품 id,상품 id,...] [최대 초]

const SANDBOX_SCENE: String = "res://debug/m1_sandbox.tscn"
const DEFAULT_STACK: Array[String] = ["item_salt_sack", "item_onggi", "item_white_porcelain"]
const DEFAULT_MAX_SECONDS: float = 200.0
const SETTLE_SECONDS: float = 1.5
const STACK_GAP: float = 0.02
const REPORT_INTERVAL: float = 10.0

var _sandbox: Node
var _elapsed: float = 0.0
var _started: bool = false
var _max_seconds: float = DEFAULT_MAX_SECONDS
var _next_report: float = REPORT_INTERVAL
var _stack_ids: Array[String] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].is_empty():
		var script: GDScript = load("res://debug/m1_sandbox.gd")
		script.set("selected_road_id", args[0])
	_stack_ids = DEFAULT_STACK.duplicate()
	if args.size() > 1:
		_stack_ids.clear()
		for id: String in args[1].split(",", false):
			_stack_ids.append(id.strip_edges())
	if args.size() > 2:
		_max_seconds = float(args[2])
	_sandbox = (load(SANDBOX_SCENE) as PackedScene).instantiate()
	root.add_child(_sandbox)


func _physics_process(delta: float) -> bool:
	_elapsed += delta
	if not _started and _elapsed > 0.2:
		_stack_items()
	if _started and _elapsed > SETTLE_SECONDS + 0.2 and _sandbox.phase == 0:
		_sandbox._on_start_pressed()
		print("출발: 실은 상품 %d개" % _sandbox.haul.carried_count())
		for item: Node in _sandbox.items:
			item.damaged.connect(_on_damaged)
	if _sandbox.phase != 0 and _elapsed >= _next_report:
		_next_report += REPORT_INTERVAL
		print("%5.1f초 x=%.1f / %.1f  지게 위 %d" % [_elapsed, _sandbox._porter.distance_x,
			_sandbox.profile.finish_x, _sandbox._count_on_carrier()])
	if _sandbox.phase == 3:
		print("결과: ", _sandbox.haul.summary())
		quit(0)
	elif _elapsed > _max_seconds:
		printerr("시간 초과. 위치 x=%.1f" % _sandbox._porter.distance_x)
		quit(1)
	return false


## 지정한 상품들을 지게 위에 차례로 쌓는다 (바닥부터)
func _stack_items() -> void:
	_started = true
	var carrier: Node3D = _sandbox._porter.carrier
	var y: float = 0.0
	for id: String in _stack_ids:
		for item: Node in _sandbox.items:
			if item.item_id == id and not item.get_meta("stacked", false):
				var half: Vector2 = item.half_extents_2d()
				item.global_position = carrier.global_position + Vector3(0.0, y + half.y + STACK_GAP, 0.0)
				item.rotation = Vector3.ZERO
				item.linear_velocity = Vector3.ZERO
				item.set_meta("stacked", true)
				y += half.y * 2.0 + STACK_GAP
				break


func _on_damaged(item: Node, amount: float) -> void:
	var x: float = _sandbox._porter.distance_x
	print("  손상 %s -%.1f (충격 %.2f, 남은 %.0f) x=%.1f 구간=%s 지게위=%s" % [item.item_id, amount, item.last_impact,
		item.durability, x, _sandbox.profile.segment_type_at(x), _sandbox._porter.carrier.is_in_load_zone(item.global_position)])
