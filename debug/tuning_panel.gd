class_name TuningPanel
extends CanvasLayer
## 조정 패널 (F1). 수치를 실시간으로 바꾸고, 이름 붙여 저장/불러오기, 기본값 되돌리기.
## 길 고르기와 구간 순서 바꾸기도 여기서 한다.

signal road_rebuild_requested(road_id: String, order_text: String)
signal restart_requested
signal info_toggled(show_info: bool)

const PANEL_WIDTH: int = 480
const SLIDER_MIN_WIDTH: int = 120
const ROW_LABEL_WIDTH: int = 170
const SPIN_WIDTH: int = 90
const FONT_SIZE: int = 14
const HEADER_FONT_SIZE: int = 16
const HEADER_COLOR: Color = Color(1.0, 0.85, 0.5)
const DEFAULT_PRESET_NAME: String = "my_tuning"

var _rows: Dictionary = {}  ## key -> { slider, spin }
var _updating: bool = false
var _status: Label
var _preset_name: LineEdit
var _preset_list: OptionButton
var _road_select: OptionButton
var _order_edit: LineEdit
var _road_ids: Array[String] = []
var _panel: PanelContainer


func _ready() -> void:
	layer = 20
	_build()
	visible = false
	GameInput.debug_toggled.connect(func() -> void: visible = not visible)
	Tuning.reloaded.connect(_refresh_all)


## 길 목록 채우기. roads: id -> 정의
func set_roads(roads: Dictionary, selected_id: String, order_text: String) -> void:
	_road_ids.clear()
	_road_select.clear()
	var ids: Array = roads.keys()
	ids.sort()
	for road_id: String in ids:
		_road_ids.append(road_id)
		_road_select.add_item(Loc.name_of(roads[road_id]))
		if road_id == selected_id:
			_road_select.select(_road_ids.size() - 1)
	_order_edit.text = order_text


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -PANEL_WIDTH
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.06, 0.88)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var title: Label = _small_label(tr("debug.title"), 20)
	box.add_child(title)
	_build_preset_controls(box)
	_build_road_controls(box)

	var info_check: CheckBox = CheckBox.new()
	info_check.text = tr("debug.show_info")
	info_check.add_theme_font_size_override("font_size", FONT_SIZE)
	info_check.toggled.connect(func(on: bool) -> void: info_toggled.emit(on))
	box.add_child(info_check)

	var current_group: String = ""
	for key: String in Tuning.store.keys():
		var spec: Dictionary = Tuning.store.get_spec(key)
		if spec["group"] != current_group:
			current_group = spec["group"]
			box.add_child(HSeparator.new())
			var header: Label = _small_label(tr("debug.group." + current_group), HEADER_FONT_SIZE)
			header.add_theme_color_override("font_color", HEADER_COLOR)
			box.add_child(header)
		box.add_child(_make_row(key, spec))

	_status = _small_label("", FONT_SIZE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)


func _build_preset_controls(box: VBoxContainer) -> void:
	var row1: HBoxContainer = HBoxContainer.new()
	row1.add_child(_small_label(tr("debug.preset_name"), FONT_SIZE))
	_preset_name = LineEdit.new()
	_preset_name.text = DEFAULT_PRESET_NAME
	_preset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_preset_name)
	row1.add_child(_button(tr("debug.save"), _on_save))
	box.add_child(row1)
	var row2: HBoxContainer = HBoxContainer.new()
	_preset_list = OptionButton.new()
	_preset_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_list.pressed.connect(_refresh_preset_list)
	row2.add_child(_preset_list)
	row2.add_child(_button(tr("debug.load"), _on_load))
	row2.add_child(_button(tr("debug.reset"), _on_reset))
	box.add_child(row2)
	if OS.has_feature("editor"):
		box.add_child(_button(tr("debug.save_default"), _on_save_default))
	_refresh_preset_list()


func _build_road_controls(box: VBoxContainer) -> void:
	box.add_child(HSeparator.new())
	var header: Label = _small_label(tr("debug.road"), HEADER_FONT_SIZE)
	header.add_theme_color_override("font_color", HEADER_COLOR)
	box.add_child(header)
	_road_select = OptionButton.new()
	_road_select.item_selected.connect(_on_road_selected)
	box.add_child(_road_select)
	box.add_child(_small_label(tr("debug.segments") + "  (" + tr("debug.segments_help") + ")", FONT_SIZE - 2))
	_order_edit = LineEdit.new()
	box.add_child(_order_edit)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_child(_button(tr("debug.apply_road"), _on_apply_road))
	row.add_child(_button(tr("debug.restart"), func() -> void: restart_requested.emit()))
	box.add_child(row)


func _make_row(key: String, spec: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = _small_label(Loc.name_of(spec), FONT_SIZE)
	label.custom_minimum_size.x = ROW_LABEL_WIDTH
	label.clip_text = true
	label.tooltip_text = key
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = float(spec["min"])
	slider.max_value = float(spec["max"])
	slider.step = float(spec["step"])
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = SLIDER_MIN_WIDTH
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = slider.min_value
	spin.max_value = slider.max_value
	spin.step = slider.step
	spin.custom_minimum_size.x = SPIN_WIDTH
	spin.select_all_on_focus = true
	row.add_child(spin)
	slider.value = Tuning.v(key)
	spin.value = Tuning.v(key)
	slider.value_changed.connect(_on_value_changed.bind(key))
	spin.value_changed.connect(_on_value_changed.bind(key))
	_rows[key] = { "slider": slider, "spin": spin }
	return row


func _on_value_changed(value: float, key: String) -> void:
	if _updating:
		return
	Tuning.set_value(key, value)
	_sync_row(key)


func _sync_row(key: String) -> void:
	_updating = true
	var row: Dictionary = _rows[key]
	(row["slider"] as HSlider).value = Tuning.v(key)
	(row["spin"] as SpinBox).value = Tuning.v(key)
	_updating = false


func _refresh_all() -> void:
	for key: String in _rows.keys():
		_sync_row(key)


func _refresh_preset_list() -> void:
	var current: String = _preset_list.get_item_text(_preset_list.selected) if _preset_list.selected >= 0 else ""
	_preset_list.clear()
	for preset: String in Tuning.list_presets():
		_preset_list.add_item(preset)
		if preset == current:
			_preset_list.select(_preset_list.item_count - 1)


func _on_save() -> void:
	var path: String = Tuning.save_preset(_preset_name.text)
	_status.text = Loc.format("debug.saved", { "path": ProjectSettings.globalize_path(path) }) if path != "" else tr("debug.load_failed")
	_refresh_preset_list()


func _on_load() -> void:
	if _preset_list.selected < 0:
		_status.text = tr("debug.load_failed")
		return
	var n: int = Tuning.load_preset(_preset_list.get_item_text(_preset_list.selected))
	_status.text = Loc.format("debug.loaded", { "n": n }) if n >= 0 else tr("debug.load_failed")


func _on_reset() -> void:
	Tuning.reset_to_defaults()


func _on_save_default() -> void:
	var path: String = Tuning.save_as_project_default()
	_status.text = Loc.format("debug.saved", { "path": path }) if path != "" else tr("debug.load_failed")


func _on_road_selected(index: int) -> void:
	_order_edit.text = ""
	road_rebuild_requested.emit(_road_ids[index], "")


func _on_apply_road() -> void:
	var index: int = _road_select.selected
	if index < 0:
		return
	road_rebuild_requested.emit(_road_ids[index], _order_edit.text)


func _button(text: String, callback: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", FONT_SIZE)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


func _small_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label
