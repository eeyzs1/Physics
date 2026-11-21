extends Control

const MapSize := Vector2(1600, 900)
const MARKS: JSON = preload("res://art/harbor_marks.json")
var moored := false
var beacon_lit := false
var last_selected := "loading"
var buttons: Dictionary = {}
var phase := 0.0
var dock_fraction := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(position_labels)

func project(key: String) -> Vector2:
	var uv: Array = MARKS.data[key]
	var scale_factor := maxf(size.x / MapSize.x, size.y / MapSize.y)
	var display_size := MapSize * scale_factor
	return (size - display_size) * 0.5 + Vector2(uv[0], uv[1]) * display_size

func position_labels() -> void:
	for key: String in buttons:
		var button: Button = buttons[key]
		var offset_y := 48 if key == "towers" else 28
		button.position = project(key) + Vector2(-button.size.x / 2.0, offset_y)
	queue_redraw()

func _process(delta: float) -> void:
	phase = fmod(phase + delta, TAU * 10)
	dock_fraction = move_toward(dock_fraction, 1.0 if moored else 0.0, delta * 0.29)
	queue_redraw()

func _draw() -> void:
	if size.x <= 0:
		return
	var sea := project("offshore")
	var dock := project("berth")
	var boat := sea.lerp(dock, smoothstep(0.0, 1.0, dock_fraction))
	boat.y += sin(phase * 1.6) * 2.0
	for i in range(2, 18, 2):
		var start := sea.lerp(dock, i / 19.0)
		draw_line(start, sea.lerp(dock, (i + 0.8) / 19.0), Color("#d8eee899"), 1.7, true)
	var wake := Color("#e0f1d4a0")
	for i in 3:
		var tail := boat + Vector2(18 + i * 6, 4 - i * 1.5)
		draw_line(tail, tail + Vector2(6, -2), wake, 1.2, true)
	draw_set_transform(boat, -0.20, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-21, 0),Vector2(-11,-6),Vector2(15,-6),Vector2(19,0),Vector2(12,6),Vector2(-11,6)]),Color("#213e46"))
	draw_colored_polygon(PackedVector2Array([Vector2(-20,-2),Vector2(-9,-8),Vector2(14,-8),Vector2(18,-3),Vector2(12,2),Vector2(-10,2)]),Color("#f1dfb0"))
	draw_rect(Rect2(-6,-13,14,9),Color("#a45139"))
	draw_rect(Rect2(-9,-15,19,4),Color("#e39558"))
	draw_rect(Rect2(-4,-10,4,4),Color("#23464d"))
	draw_line(Vector2(10,-7), Vector2(10,-19), Color("#433e38"), 1.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for key: String in buttons:
		var p := project(key)
		var color := Color("#f9dc9d") if key == last_selected else Color("#e1ebca")
		draw_line(p+Vector2(0,9), Vector2(p.x, buttons[key].position.y), Color("#334642"), 3, true)
		draw_line(p+Vector2(0,9), Vector2(p.x, buttons[key].position.y), color, 1.3, true)
		draw_circle(p, 7, Color("#214044"))
		draw_arc(p, 7, 0, TAU, 24, color, 2, true)
		if key == last_selected:
			draw_arc(p, 10.5 + sin(phase * 2.5), 0, TAU, 30, Color("#fff3c3af"), 1.2, true)
	if beacon_lit:
		var lights := project("towers")
		var beam := Color("#ffdf94")
		beam.a = 0.11 + 0.08 * sin(phase)
		draw_colored_polygon(PackedVector2Array([lights + Vector2(-50,-33),lights + Vector2(-151,-52),lights + Vector2(-160,-28)]),beam)
