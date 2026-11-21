extends RefCounted

const INK := Color("#eff5e8")
const SOFT := Color("#bed3cf")
const SEA := Color("#112c35")
const DEEP := Color("#0b2028")
const LINE := Color("#46656a")
const MINT := Color("#9fe3c7")
const AMBER := Color("#ffc991")
const CORAL := Color("#ff9370")

static func box(fill: Color, border: Color = Color.TRANSPARENT, radius: int = 9, pad_x: int = 16, pad_y: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style

static func face() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "DejaVu Sans"])
	return font

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = face()
	result.default_font_size = 19
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "Button", INK)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_focus_color", "Button", Color.WHITE)
	result.set_stylebox("normal", "Button", box(SEA, LINE))
	result.set_stylebox("hover", "Button", box(Color("#23515a"), MINT))
	result.set_stylebox("pressed", "Button", box(Color("#35666a"), MINT))
	result.set_stylebox("disabled", "Button", box(DEEP, LINE))
	var focus := box(Color.TRANSPARENT, AMBER)
	focus.draw_center = false
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("panel", "PanelContainer", box(DEEP, LINE, 12, 18, 15))
	result.set_stylebox("background", "ProgressBar", box(Color("#2e4b54"), Color.TRANSPARENT, 3, 0, 0))
	result.set_stylebox("fill", "ProgressBar", box(MINT, Color.TRANSPARENT, 3, 0, 0))
	return result

static func label(text_value: String, font_size: int = 19, color: Color = INK, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text_value
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func button(text_value: String, callback: Callable, main: bool = false) -> Button:
	var node := Button.new()
	node.text = text_value
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.custom_minimum_size.y = 42
	if main:
		for state in ["normal", "hover", "pressed"]:
			var fill := MINT if state == "normal" else Color("#c8f2d5")
			node.add_theme_stylebox_override(state, box(fill))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			node.add_theme_color_override(state, DEEP)
	node.pressed.connect(callback)
	return node

static func column(gap: int = 10) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return node

static func row(gap: int = 10) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", gap)
	return node

static func place(control: Control, anchor: Vector4, edges: Vector4) -> void:
	control.anchor_left = anchor.x
	control.anchor_top = anchor.y
	control.anchor_right = anchor.z
	control.anchor_bottom = anchor.w
	control.offset_left = edges.x
	control.offset_top = edges.y
	control.offset_right = edges.z
	control.offset_bottom = edges.w
