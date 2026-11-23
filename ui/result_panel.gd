class_name ResultPanel
extends CanvasLayer
## 도착 결과: 도착한 상품, 깨진 상품, 잃은 상품 목록과 다시 하기 버튼.

signal retry_pressed

const PANEL_SIZE: Vector2 = Vector2(720, 520)
const TITLE_FONT: int = 40
const HEADER_FONT: int = 26
const BODY_FONT: int = 22
const HEADER_COLORS: Dictionary = {
	"arrived": Color(0.6, 0.95, 0.6),
	"broken": Color(1.0, 0.55, 0.45),
	"lost": Color(0.75, 0.75, 0.85),
}


## summary: HaulState.summary(), item_defs: id -> 정의
func show_result(summary: Dictionary, item_defs: Dictionary) -> void:
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
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = tr("ui.result_title")
	title.add_theme_font_size_override("font_size", TITLE_FONT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	for key: String in ["arrived", "broken", "lost"]:
		var names: Array = summary.get(key, [])
		var header: Label = Label.new()
		header.text = "%s (%d)" % [tr("ui." + key), names.size()]
		header.add_theme_font_size_override("font_size", HEADER_FONT)
		header.add_theme_color_override("font_color", HEADER_COLORS[key])
		box.add_child(header)
		var body: Label = Label.new()
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", BODY_FONT)
		body.text = _join_names(names, item_defs)
		box.add_child(body)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var retry: Button = Button.new()
	retry.text = tr("ui.retry")
	retry.add_theme_font_size_override("font_size", 28)
	retry.custom_minimum_size = Vector2(220, 60)
	retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	box.add_child(retry)


func _join_names(ids: Array, item_defs: Dictionary) -> String:
	if ids.is_empty():
		return tr("ui.none")
	var parts: PackedStringArray = PackedStringArray()
	for item_id: String in ids:
		parts.append(Loc.name_of(item_defs.get(item_id, { "id": item_id })))
	return ", ".join(parts)
