class_name SellPanel
extends CanvasLayer
## 도착한 장터에서 팔기. 상품마다 상태와 값을 보여주고, 하나씩 또는 모두 판다.
## 깨진 상품과 잃은 상품, 이번 구간 손익도 함께 보여준다.

## 이 줄의 상품을 팔겠다 (판 뒤 refresh 로 다시 그린다)
signal sell_requested(uid: int)
signal sell_all_requested
signal retry_pressed

const PANEL_COLOR: Color = Color(0.13, 0.11, 0.09, 0.97)
const PANEL_CORNER_RADIUS: int = 8
const PANEL_SIZE: Vector2 = Vector2(760, 640)
const TITLE_FONT: int = 34
const HEADER_FONT: int = 22
const BODY_FONT: int = 20
const ROW_NAME_WIDTH: int = 220
const ROW_CONDITION_WIDTH: int = 150
const ROW_PRICE_WIDTH: int = 120
const COLOR_SOLD: Color = Color(0.6, 0.95, 0.6)
const COLOR_BAD: Color = Color(1.0, 0.55, 0.45)
const COLOR_PROFIT: Color = Color(1.0, 0.86, 0.4)

var _rows_box: VBoxContainer
var _summary: Label
var _losses: Label
var _title: Label
var _sell_all: Button


func _ready() -> void:
	layer = 10
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_title = _label("", TITLE_FONT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)
	_losses = _label("", BODY_FONT)
	_losses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_losses.add_theme_color_override("font_color", COLOR_BAD)
	box.add_child(_losses)
	_summary = _label("", HEADER_FONT)
	_summary.add_theme_color_override("font_color", COLOR_PROFIT)
	box.add_child(_summary)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)
	_sell_all = _button(tr("ui.sell_all"), func() -> void: sell_all_requested.emit())
	buttons.add_child(_sell_all)
	buttons.add_child(_button(tr("ui.retry"), func() -> void: retry_pressed.emit()))


## rows: [{ uid, name, condition (0~1), price, sold (bool) }]
## losses: [{ name, value }] (깨진 것과 잃은 것), totals: { money, spent, earned, profit }
func refresh(market_name: String, rows: Array, losses: Array, totals: Dictionary) -> void:
	_title.text = Loc.format("ui.sell_title", { "market": market_name })
	for child: Node in _rows_box.get_children():
		child.queue_free()
	var any_unsold: bool = false
	if rows.is_empty():
		_rows_box.add_child(_label(tr("ui.none"), BODY_FONT))
	for row: Dictionary in rows:
		_rows_box.add_child(_make_row(row))
		any_unsold = any_unsold or not row["sold"]
	_sell_all.disabled = not any_unsold
	if losses.is_empty():
		_losses.text = ""
	else:
		var parts: PackedStringArray = PackedStringArray()
		var total_lost: int = 0
		for loss: Dictionary in losses:
			parts.append("%s %s" % [loss["kind"], loss["name"]])
			total_lost += int(loss["value"])
		_losses.text = "%s: %s  (%s)" % [tr("ui.lost_value"), Loc.format("ui.money_unit", { "n": total_lost }), ", ".join(parts)]
	_summary.text = "%s    %s %s    %s %s    %s %s" % [
		Loc.format("ui.money", { "n": totals["money"] }),
		tr("ui.spent"), Loc.format("ui.money_unit", { "n": totals["spent"] }),
		tr("ui.earned"), Loc.format("ui.money_unit", { "n": totals["earned"] }),
		tr("ui.profit"), Loc.format("ui.money_unit", { "n": totals["profit"] }),
	]


func _make_row(row: Dictionary) -> Control:
	var line: HBoxContainer = HBoxContainer.new()
	var name_label: Label = _label(row["name"], BODY_FONT)
	name_label.custom_minimum_size.x = ROW_NAME_WIDTH
	line.add_child(name_label)
	var cond: Label = _label(Loc.format("ui.condition", { "pct": roundi(float(row["condition"]) * 100.0) }), BODY_FONT)
	cond.custom_minimum_size.x = ROW_CONDITION_WIDTH
	line.add_child(cond)
	var price: Label = _label(Loc.format("ui.money_unit", { "n": row["price"] }), BODY_FONT)
	price.custom_minimum_size.x = ROW_PRICE_WIDTH
	line.add_child(price)
	if row["sold"]:
		var sold: Label = _label(tr("ui.sold"), BODY_FONT)
		sold.add_theme_color_override("font_color", COLOR_SOLD)
		line.add_child(sold)
	else:
		var uid: int = row["uid"]
		line.add_child(_button(tr("ui.sell"), func() -> void: sell_requested.emit(uid)))
	return line


func _button(text: String, callback: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", BODY_FONT)
	b.custom_minimum_size = Vector2(120, 40)
	b.pressed.connect(callback)
	return b


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label
