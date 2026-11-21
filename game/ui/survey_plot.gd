extends Control

const FlightUI := preload("res://ui/skin.gd")
const MODEL := Color("#d0a9ff")
var report: Dictionary
var left_label: String
var right_label: String

func _ready() -> void:
	custom_minimum_size.y = 112
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if report.is_empty():
		return
	var font := get_theme_default_font()
	var start := minf(size.x * 0.33, 188)
	var end := size.x - 19.0
	draw_style_box(FlightUI.box(Color("#17343e"), Color.TRANSPARENT, 6), Rect2(Vector2.ZERO, size))
	for i: int in report.samples.size():
		var sample: Dictionary = report.samples[i]
		var y := 15.0 + i * 21.0
		var tag := ("盲接　" if i == 3 else "采样　") + str(sample.condition)
		draw_string(font, Vector2(10, y + 5), tag, HORIZONTAL_ALIGNMENT_LEFT, start - 18,
			14, FlightUI.INK if i == 3 else FlightUI.SOFT)
		draw_line(Vector2(start, y), Vector2(end, y), FlightUI.LINE)
		var model := lerpf(start, end, inverse_lerp(report.low, report.high, sample.model))
		var flown := lerpf(start, end, inverse_lerp(report.low, report.high, sample.estimate))
		draw_line(Vector2(model, y), Vector2(flown, y), FlightUI.AMBER, 1.5, true)
		draw_circle(Vector2(model, y), 3.5, MODEL, true, -1.0, true)
		draw_arc(Vector2(flown, y), 6, 0, TAU, 20, FlightUI.AMBER, 1.6, true)
	draw_string(font, Vector2(start, 105), left_label, HORIZONTAL_ALIGNMENT_LEFT, 130, 13, FlightUI.SOFT)
	draw_string(font, Vector2(end - 130, 105), right_label, HORIZONTAL_ALIGNMENT_RIGHT, 130, 13, FlightUI.SOFT)
