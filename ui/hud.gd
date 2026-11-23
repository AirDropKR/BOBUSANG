class_name Hud
extends CanvasLayer
## 화면 위 안내, 출발 버튼, 남은 거리, 짧은 알림(깨짐, 잃음).

signal start_pressed

const TOAST_TIME: float = 1.8
const TOAST_FADE: float = 0.4
const MARGIN: int = 16
const FONT_SIZE_HINT: int = 20
const FONT_SIZE_TOAST: int = 30
const FONT_SIZE_INFO: int = 22
const START_BUTTON_SIZE: Vector2 = Vector2(180, 64)
const TOAST_COLOR: Color = Color(1.0, 0.86, 0.4)

var _hint: Label
var _info: Label
var _debug_hint: Label
var _start_button: Button
var _toast_box: VBoxContainer


func _ready() -> void:
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_hint = _label(FONT_SIZE_HINT)
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = MARGIN
	_hint.offset_left = MARGIN
	_hint.offset_right = -MARGIN
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_hint)

	_info = _label(FONT_SIZE_INFO)
	_info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_info.offset_left = MARGIN
	_info.offset_top = -80
	_info.offset_bottom = -MARGIN
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(_info)

	_debug_hint = _label(16)
	_debug_hint.text = tr("ui.debug_hint")
	_debug_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_debug_hint.offset_left = -220
	_debug_hint.offset_right = -MARGIN
	_debug_hint.offset_top = -40
	_debug_hint.offset_bottom = -MARGIN
	_debug_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_debug_hint)

	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_top = 90
	_toast_box.offset_left = -300
	_toast_box.offset_right = 300
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)

	_start_button = Button.new()
	_start_button.text = tr("ui.start")
	_start_button.add_theme_font_size_override("font_size", 30)
	_start_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_start_button.offset_left = -START_BUTTON_SIZE.x * 0.5
	_start_button.offset_right = START_BUTTON_SIZE.x * 0.5
	_start_button.offset_top = -START_BUTTON_SIZE.y - MARGIN * 2
	_start_button.offset_bottom = -MARGIN * 2
	_start_button.pressed.connect(_on_start_pressed)
	root.add_child(_start_button)
	show_stacking()


func show_stacking() -> void:
	_hint.text = tr("ui.hint_stack")
	_start_button.visible = true


func show_walking() -> void:
	_hint.text = tr("ui.hint_walk")
	_start_button.visible = false


func set_info(carried: int, remaining_m: float, slowed: bool) -> void:
	var text: String = Loc.format("ui.carried", { "n": carried })
	if remaining_m >= 0.0:
		text += "    " + Loc.format("ui.progress", { "m": int(ceil(remaining_m)) })
	if slowed:
		text += "    [" + tr("ui.slow") + "]"
	_info.text = text


func toast(text: String) -> void:
	var label: Label = _label(FONT_SIZE_TOAST)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", TOAST_COLOR)
	_toast_box.add_child(label)
	var tween: Tween = label.create_tween()
	tween.tween_interval(TOAST_TIME)
	tween.tween_property(label, "modulate:a", 0.0, TOAST_FADE)
	tween.tween_callback(label.queue_free)


func _on_start_pressed() -> void:
	start_pressed.emit()


func _label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
