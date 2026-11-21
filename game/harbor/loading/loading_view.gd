extends Control

const HARBOR := preload("res://harbor/quay/art/tidewater.svg")
const HarborSkin := preload("res://ui/skin.gd")

var model
var selected: int = 0
var held: int = -1
var cursor_x: float = 0.0
var lift_fraction: float = 0.0
var hook_world_x: float = 0.0
var departure: float = 0.0
var active_scale: bool = false
var at_weigh_pad: bool = true

var _face := HarborSkin.face()
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _top() -> float:
	return minf(85.0, size.y * 0.205)


func _height() -> float:
	return maxf(1.0, size.y - _top() - minf(150.0, size.y * 0.32))


func _y(unit: float) -> float:
	return _top() + _height() * unit / 480.0


func _scale() -> float:
	return maxf(0.1, minf(size.x / 1280.0, _height() / 480.0))


func _wheelbase() -> float:
	return float(model.wheelbase) if model != null else 4.0


func _metre() -> float:
	return maxf(1.0, size.x * 0.425 / _wheelbase())


func yard_x(index: int) -> float:
	return pixel_to_x(size.x * (0.118 if index == 0 else 0.248))


func x_to_pixel(x: float) -> float:
	return size.x * 0.39 + x * _metre()


func pixel_to_x(px: float) -> float:
	return (px - size.x * 0.39) / _metre()


func deck_y() -> float:
	return _y(283.0)


func _truck_offset() -> float:
	return size.x * 1.12 * smoothstep(0.0, 1.0, clampf(departure, 0.0, 1.0))


func _valid(index: int) -> bool:
	return model != null and index >= 0 and index < model.cargo.size()


func _at_exit() -> bool:
	return at_weigh_pad and model != null and int(model.order_index) % 2 == 1


func _cargo_rect(index: int) -> Rect2:
	if not _valid(index):
		return Rect2()
	var box: Dictionary = model.cargo[index]
	var long_crate := bool(box.marked)
	var width := float(box.width) * _metre()
	var height := minf(width * (0.76 if long_crate else 0.70), _height() * (0.207 if long_crate else 0.148))
	var px := x_to_pixel(yard_x(index))
	var bottom := deck_y()
	if index == held:
		px = x_to_pixel(hook_world_x)
		bottom -= clampf(lift_fraction, 0.0, 1.0) * _height() * 0.194
	elif bool(box.on_bed):
		px = x_to_pixel(float(box.x)) + _truck_offset()
	return Rect2(px - width / 2.0, bottom - height, width, height)


func cargo_center(index: int) -> Vector2:
	return _cargo_rect(index).get_center()


func cargo_at(local_pixel: Vector2) -> int:
	if model == null or departure > 0.001:
		return -1
	if _valid(held) and _cargo_rect(held).grow(2.0).has_point(local_pixel):
		return held
	for i in range(model.cargo.size() - 1, -1, -1):
		if _at_exit() and not bool(model.cargo[i].on_bed):
			continue
		if _cargo_rect(i).grow(2.0).has_point(local_pixel):
			return i
	return -1


func on_deck(local_pixel: Vector2) -> bool:
	if departure > 0.001:
		return false
	return local_pixel.x >= x_to_pixel(0.0) - 0.5 and local_pixel.x <= x_to_pixel(_wheelbase()) + 0.5 and local_pixel.y >= deck_y() - _height() * 0.24 and local_pixel.y <= deck_y() + _height() * 0.11


func _screen() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _at(point: Vector2, factor: float) -> void:
	draw_set_transform(point, 0.0, Vector2.ONE * factor)


func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _line(x: float, y: float, xx: float, yy: float, color: Color, width: float = 1.0) -> void:
	draw_line(Vector2(x, y), Vector2(xx, yy), color, width, true)


func _points(numbers: PackedFloat32Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(0, numbers.size(), 2):
		points.append(Vector2(numbers[i], numbers[i + 1]))
	return points


func _shape(numbers: PackedFloat32Array, color: Color) -> void:
	draw_colored_polygon(_points(numbers), color)


func _stroke(numbers: PackedFloat32Array, color: Color, width: float) -> void:
	draw_polyline(_points(numbers), color, width, true)


func _disk(x: float, y: float, radius: float, color: Color) -> void:
	draw_circle(Vector2(x, y), radius, color, true, -1.0, true)


func _word(label: String, x: float, baseline: float, width: float, pixels: int, color: Color) -> void:
	draw_string(_face, Vector2(x, baseline), label, HORIZONTAL_ALIGNMENT_CENTER, width, maxi(8, pixels), color)


func _draw() -> void:
	if size.x < 2 or size.y < 2:
		return
	_screen()
	var exit_lane := _at_exit()
	_harbor(exit_lane)
	if exit_lane:
		_exit_booth()
	else:
		_rail()
		_rack()
	var rear := x_to_pixel(0.0)
	var front := x_to_pixel(_wheelbase())
	if at_weigh_pad:
		_scale_pit(rear, true)
		_scale_pit(front, false)
	_truck(rear + _truck_offset(), front + _truck_offset())
	if model != null:
		if not exit_lane:
			_landing_mark()
		for index in model.cargo.size():
			if index != held and (not exit_lane or bool(model.cargo[index].on_bed)):
				_crate(index)
		if not exit_lane:
			if _valid(held):
				_crate(held)
			_hoist()
	if at_weigh_pad:
		_scale_head(rear, true)
		_scale_head(front, false)
	_screen()


func _harbor(exit_lane: bool) -> void:
	var w := size.x
	var s := _scale()
	var backdrop := Rect2(-w * 0.26, _y(-235), w * 1.38, _height() * 1.92) if exit_lane else Rect2(0, _y(-198), w, _height() * 1.76)
	draw_texture_rect(HARBOR, backdrop, false)
	var lane := _y(365)
	_rect(0, lane - 15 * s, w, size.y - lane + 16 * s, Color("a79d87"))
	_rect(0, lane - 15 * s, w, 5 * s, Color("d9caac"))
	_rect(0, lane - 10 * s, w, 4 * s, Color("857f71"))
	_rect(0, _y(397), w, size.y - _y(397), Color("9c9684"))
	for i in 13:
		var x := fmod(i * 147.0 + 83.0, 1280.0) / 1280.0 * w
		var y := _y(414.0 + fmod(73.0 * i, 87.0))
		_line(x, y, x + (16 + i % 4 * 9) * s, y - 2 * s, Color("888574"), 1.1 * s)
	for i in 11:
		var x := i * w * 0.104
		_line(x, _y(462), x + w * 0.047, _y(462), Color("c0b99d"), maxf(1.2, 3.0 * s))
	# Slow movement on the water contrasts with the fixed marks on the truck.
	for i in 8:
		var x := w * (0.07 + 0.86 * fmod(i * 0.318 + _clock * (0.002 + (i % 3) * 0.0003), 1.0))
		var y := _y(223.0 + fmod(float(i * 19), 74.0))
		_line(x, y, x + (9 + 3 * (i % 4)) * s, y, Color("d9e1c7", 0.54), maxf(1, s))
	# Fence on the far edge of the quay, behind the loading action.
	for i in 11:
		var x := float(i) * w * 0.108
		_rect(x, _y(307), 4 * s, _y(354) - _y(307), Color("7b8980"))
	_line(0, _y(317), w, _y(317), Color("89968b"), maxf(1, 2 * s))
	_line(0, _y(335), w, _y(335), Color("89968b"), maxf(1, 2 * s))


func _exit_booth() -> void:
	var s := _scale()
	var w := size.x
	var ground := _y(392)
	# The weighbridge deck is fixed in the road. The operator has a clear view of both axle pads.
	var start := x_to_pixel(0.0) - 112 * s
	var end := x_to_pixel(_wheelbase()) + 124 * s
	_shape([start-22*s,ground+6*s,start,ground-9*s,end-19*s,ground-9*s,end,ground+6*s],Color("7a8882"))
	_line(start-15*s,ground+4*s,end-4*s,ground+4*s,Color("c8b58a"),2.4*s)
	for px in [start + 17*s, end - 24*s]:
		_line(px,ground-7*s,px-10*s,ground+4*s,Color("515e5c"),2*s)
	var booth_scale := minf(s * 1.2, w * 0.262 / 220.0)
	_at(Vector2(w * 0.051, _y(380)), booth_scale)
	_shape([-24,4,-11,-4,186,-4,204,3,198,11,-22,11],Color("8d8875"))
	_shape([-4,-141,140,-141,166,-118,166,0,-4,0],Color("a6b5a1"))
	_shape([140,-141,166,-118,166,0,140,0],Color("80978b"))
	_rect(-4,-81,144,80,Color("d9c5a2"))
	for h in [-62,-43,-22]:
		_line(-3,h,139,h,Color("c3b59a"),1)
	_rect(2,-4,137,5,Color("6a7972"))
	_shape([-17,-142,-9,-152,144,-152,177,-125,173,-118,140,-139,-16,-136],Color("506c69"))
	_line(-12,-150,143,-150,Color("a9b5a1"),2.3)
	_rect(5,-132,128,35,Color("315855"))
	_rect(8,-129,122,2,Color("96a68b"))
	_word("出口地磅", 8, -106, 122, 23, Color("f2deab"))
	_rect(8,-89,83,52,Color("536c67"))
	_rect(13,-84,72,40,Color("8cafac"))
	_shape([15,-84,40,-84,15,-59],Color("b4c8b8"))
	_rect(47,-83,4,40,Color("586f67"))
	# The attendant and the counter give the second camera a clear destination.
	_shape([54,-44,57,-57,64,-62,72,-59,79,-48,81,-43],Color("a67951"))
	_disk(65,-66,6.2,Color("be8a63"))
	_shape([58,-67,58,-71,62,-74,69,-72,72,-67],Color("516c68"))
	_line(59,-56,62,-45,Color("e1b261"),2.4)
	_line(71,-57,68,-45,Color("e1b261"),2.4)
	_rect(7,-39,88,6,Color("828b79"))
	_rect(99,-90,31,86,Color("728c7e"))
	_rect(103,-85,23,30,Color("91b1a5"))
	_rect(102,-47,8,2,Color("c8c6a7"))
	_rect(-14,-3,152,5,Color("a09982"))
	_screen()
	var gate_x := w * 0.97
	_at(Vector2(gate_x, _y(392)), s)
	_rect(-8,-95,16,95,Color("697973"))
	_rect(-7,-93,5,80,Color("a5af96"))
	_rect(-11,-7,22,8,Color("50625e"))
	_shape([-8,-83,-17,-105,-27,-183,-21,-185,-10,-108,3,-89],Color("e4d3a8"))
	for h in [-115,-142,-164]:
		var bx := -14.0 - (-115.0 - float(h)) * 0.14
		_line(bx-5,h+5,bx+2,h+2,Color("bf755e"),4)
	_disk(-4,-87,7,Color("516966"))
	_disk(-4,-87,3,Color("a7b39c"))
	_rect(4,-105,21,27,Color("395354"))
	_disk(14,-97,4,Color("b3916c"))
	var passed := model != null and bool(model.dispatch_report().ok) and active_scale
	_disk(14,-86,4,Color("a6d6a1") if passed else Color("a77963"))
	_screen()


func _rail() -> void:
	var w := size.x
	var s := _scale()
	var y := _y(26)
	for x in [w * 0.020, w * 0.976]:
		_rect(x - 7 * s, y - 20 * s, 15 * s, _y(361) - y + 20 * s, Color("687f7a"))
		_rect(x - 7 * s, y - 20 * s, 3 * s, _y(361) - y + 20 * s, Color("94a694"))
	_rect(0, y - 14 * s, w, 20 * s, Color("456769"))
	_rect(0, y - 14 * s, w, 4 * s, Color("759389"))
	_rect(0, y + 4 * s, w, 6 * s, Color("344e52"))
	for i in 18:
		var x := i * w / 17.0
		_line(x, y - 9 * s, x + w * 0.022, y + 2 * s, Color("6d857b"), 1.5 * s)
		_disk(x + 6 * s, y - 5 * s, maxf(1, 1.4 * s), Color("a7ab90"))
	for x in [w * 0.065, w * 0.917]:
		_at(Vector2(x, y + 12 * s), s)
		_line(0, 0, 0, 13, Color("526462"), 2)
		_shape([-3,12,3,12,10,19,-10,19], Color("547273"))
		_rect(-7, 19, 14, 2, Color("f2d696"))
	_screen()


func _rack() -> void:
	var s := _scale()
	var end := size.x * 0.316
	var y := deck_y()
	var ground := _y(395)
	_rect(0, y + 8 * s, end - 5 * s, ground - y - 8 * s, Color("596966"))
	for i in 4:
		var x := (float(i) + 0.2) * end / 3.6
		_line(x, y + 24 * s, x + end * 0.19, ground - 4 * s, Color("78877a"), 5 * s)
		_line(x + end * 0.19, y + 24 * s, x, ground - 4 * s, Color("78877a"), 5 * s)
		_rect(x - 2 * s, y + 12 * s, 6 * s, ground - y - 11 * s, Color("3d5554"))
	_rect(0, y, end, 7 * s, Color("d8b48a"))
	_rect(0, y + 7 * s, end, 8 * s, Color("997d61"))
	_rect(0, y + 15 * s, end + 3 * s, 12 * s, Color("446061"))
	_rect(end - 13 * s, y + 1 * s, 13 * s, 25 * s, Color("e3b55e"))
	_line(end - 12 * s, y + 22 * s, end - 2 * s, y + 10 * s, Color("514e43"), 4 * s)
	for i in 8:
		var x := float(i) * end / 8.0
		_line(x, y, x - 3 * s, y + 6 * s, Color("977c60"), s)
	_at(Vector2(end - 28 * s, ground - 1 * s), s)
	_rect(-4, -53, 8, 53, Color("4a625f"))
	for h in [9, 26, 44]:
		_rect(-4, -h - 4, 8, 6, Color("d8996a"))
	_rect(-8, -3, 16, 4, Color("596a62"))
	_screen()


func _scale_pit(x: float, rear: bool) -> void:
	var s := _scale()
	_at(Vector2(x, _y(392)), s)
	_shape([-77,3,-67,-3,59,-3,75,3,73,13,-78,13], Color("756f60"))
	_shape([-70,3,-60,-2,57,-2,69,3,65,9,-67,9], Color("36494a"))
	_rect(-50, 3, 100, 4, Color("769088"))
	# Parallel leaf springs compress a little as this particular axle gets heavier.
	var compression := 0.0
	if model != null and departure < 0.025:
		var loads: Vector2 = model.wheel_loads()
		var base := float(model.rear_empty) if rear else float(model.front_empty)
		compression = clampf(((loads.x if rear else loads.y) - base) * 0.22, 0.0, 3.0)
	for a in [-38, 38]:
		_stroke([a-5,3,a+4,4.7,a-4,6.6-compression*0.30,a+4,8.7-compression*0.6], Color("d0a768"), 2.3)
	_rect(-53,-3,106,6,Color("627f7a"))
	_rect(-51,-3,102,2,Color("e2c782"))
	_screen()


func _scale_head(x: float, rear: bool) -> void:
	var s := _scale()
	var y := _y(449)
	var watching := active_scale and model != null
	var stable := held < 0 and (model == null or int(model.held_index) < 0)
	var number := "—"
	var limit := 0.0
	var actual := 0.0
	if model != null:
		var loads: Vector2 = model.wheel_loads()
		actual = loads.x if rear else loads.y
		limit = float(model.rear_limit) if rear else float(model.front_limit)
		if stable:
			number = "%.2f kN" % actual
	var lamp := Color("b1cdc0")
	if watching and stable:
		lamp = Color("ff9d77") if actual > limit + 0.00001 else Color("a8ebbc")
	var half := minf(92 * s, size.x * 0.102)
	var h := 44 * s
	_at(Vector2(x, y), s)
	_line(-55, -42, -62, -38, Color("5c716c"), 3)
	_screen()
	_rect(x - half + 3 * s, y - 8 * s, 2 * half, h, Color("777462"))
	_rect(x - half, y - 12 * s, 2 * half, h, Color("405b59"))
	_rect(x - half + 2 * s, y - 10 * s, 2 * half - 4 * s, h - 4 * s, Color("233f40"))
	_rect(x - half + 5 * s, y - 8 * s, 2 * half - 10 * s, 2 * s, Color("739489"))
	_disk(x - half + 11 * s, y + 3 * s, maxf(2, 3.3 * s), lamp)
	var first_line := "后轴  ·  0 m" if rear else "前轴  ·  L = %s m" % _metre_label(_wheelbase())
	var first_size := maxi(10, roundi(14 * s))
	var reading_size := maxi(12, roundi(22 * s))
	_word(first_line, x - half + 7 * s, y + 5 * s, 2 * half - 12 * s, first_size, Color("d2e1cc"))
	_word(number if stable else "待稳", x - half, y + 26 * s, 2 * half, reading_size, lamp)
	if departure > 0.03:
		_word("留值", x + half * 0.42, y + 24 * s, half * 0.51, maxi(8, roundi(11 * s)), Color("bfcead"))


func _metre_label(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


func _truck(rear: float, front: float) -> void:
	var s := _scale()
	var top := deck_y()
	var ground := _y(392) - (3 * s if at_weigh_pad else 0.0)
	var wheel_r := 37 * s
	var axle_y := ground - wheel_r
	# Axles stay on their indicated support points. Only the body drives away.
	_rect(rear - 44 * s, ground + 1 * s, front - rear + 147 * s, 5 * s, Color("777668"))
	_rect(rear - 24 * s, top + 31 * s, front - rear + 104 * s, 13 * s, Color("30484b"))
	_rect(rear + 13 * s, top + 45 * s, front - rear - 48 * s, 5 * s, Color("647773"))
	for x in [rear, front]:
		_at(Vector2(x, axle_y), s)
		_stroke([-55,-10,-30,-2,22,-2,45,-11], Color("405557"), 5)
		_stroke([-49,-14,-27,-6,23,-6,39,-13], Color("899287"), 2)
		_rect(-12, -21, 25, 13, Color("4b6564"))
		_screen()
	var tank_x := lerpf(rear, front, 0.71)
	_at(Vector2(tank_x, top + 43 * s), s)
	_shape([-40,-6,35,-6,40,-1,38,19,30,22,-38,22,-43,15,-43,0], Color("677e79"))
	_rect(-31,-4,2,24,Color("a0a99a"))
	_rect(17,-4,3,24,Color("a0a99a"))
	_rect(-37,17,73,3,Color("435954"))
	_screen()
	# Short lips beyond each axle are mechanical trim. The painted 0..L is the usable bed.
	_rect(rear - 38 * s, top, front - rear + 46 * s, 5 * s, Color("dcc39a"))
	_rect(rear - 38 * s, top + 5 * s, front - rear + 46 * s, 5 * s, Color("9c8769"))
	_rect(rear - 41 * s, top + 10 * s, front - rear + 50 * s, 21 * s, Color("365c60"))
	_rect(rear - 40 * s, top + 29 * s, front - rear + 48 * s, 4 * s, Color("9aa995"))
	_rect(rear - 47 * s, top + 9 * s, 8 * s, 17 * s, Color("a54f3d"))
	_rect(rear - 47 * s, top + 10 * s, 8 * s, 5 * s, Color("f6b164"))
	for i in range(1, ceili((front - rear) / (73 * s))):
		var x := rear + i * 73 * s
		_line(x, top + s, x - 4 * s, top + 5 * s, Color("9b8466"), s)
	_cab(front, top)
	_wheel(rear, axle_y, wheel_r)
	_wheel(front, axle_y, wheel_r)
	# Visible unit ticks are positions on the truck, so they travel with it.
	_ruler(rear, front, top)
	if not at_weigh_pad:
		var y := _y(429)
		_axle_stamp(rear, y, "后轴  ·  0 m")
		_axle_stamp(front, y, "前轴  ·  L = %s m" % _metre_label(_wheelbase()))


func _axle_stamp(x: float, y: float, label: String) -> void:
	var s := _scale()
	var width := minf(146 * s, size.x * 0.19)
	_rect(x - width * 0.5, y - 12 * s, width, 22 * s, Color("72776a"))
	_word(label, x - width * 0.5, y + 4 * s, width, maxi(10, roundi(15 * s)), Color("f3e7c8"))


func _wheel(x: float, y: float, radius: float) -> void:
	var unit := radius / 37.0
	_at(Vector2(x, y), unit)
	_disk(0,0,37,Color("253b3f"))
	draw_arc(Vector2.ZERO, 35.0, deg_to_rad(192), deg_to_rad(345), 21, Color("556763"), 2.4, true)
	_disk(0,0,28.4,Color("30464a"))
	_disk(0,0,20.5,Color("88978b"))
	_disk(0,0,17.5,Color("51716d"))
	_disk(0,0,8.5,Color("9aa697"))
	var turns := _truck_offset() / maxf(radius, 1)
	for i in 6:
		var angle := float(i) * TAU / 6.0 + turns
		_disk(cos(angle)*12.8,sin(angle)*12.8,2.1,Color("c2c6af"))
	_screen()


func _cab(front: float, top: float) -> void:
	var s := _scale()
	_at(Vector2(front, top), s)
	# A forward-control harbour truck keeps its whole load bed behind its cab.
	_shape([5,-76,18,-91,82,-93,96,-86,119,-49,137,-36,143,0,139,48,47,51,34,28,9,14],Color("31585c"))
	_shape([11,-74,23,-85,81,-86,91,-81,112,-47,129,-34,133,-12,131,15,45,16,25,1,10,-3],Color("53928e"))
	_shape([7,-81,19,-93,80,-96,95,-90,100,-84,22,-84,11,-73],Color("e6d6af"))
	_shape([20,-70,29,-78,76,-79,88,-76,104,-49,89,-42,20,-44],Color("284e56"))
	_shape([24,-69,32,-75,57,-75,57,-49,24,-49],Color("83afb0"))
	_shape([62,-75,79,-75,86,-71,99,-51,86,-47,62,-48],Color("8bbabb"))
	_shape([25,-66,33,-74,50,-74,26,-54],Color("b4d0c1"))
	_shape([69,-73,80,-73,95,-53,88,-51],Color("c6d5ba"))
	# Driver leans over the wheel under a knitted cap.
	_shape([33,-48,35,-57,43,-59,50,-54,57,-51,57,-47],Color("69736a"))
	_disk(40,-63,5.8,Color("c99265"))
	_shape([33,-64,33,-68,37,-71,42,-70,46,-65,48,-64],Color("ce9352"))
	_line(48,-53,55,-52,Color("d7aa80"),2.3)
	_stroke([48,-48,53,-54,57,-53],Color("344f50"),2)
	_stroke([17,-41,82,-39,83,5,72,11,24,10,18,4,17,-41],Color("3a706f"),2)
	_rect(22,-34,14,4,Color("d5ceb0"))
	_rect(14,-15,114,5,Color("e4c28a"))
	_rect(61,-26,13,1.4,Color("8eb2a5"))
	_rect(61,-23,13,1.4,Color("8eb2a5"))
	_shape([40,17,124,13,134,7,136,32,130,41,56,44],Color("437775"))
	_shape([111,-41,127,-33,132,-16,119,-16],Color("699e94"))
	_rect(120,-10,16,9,Color("e4cf98"))
	_rect(129,-10,7,9,Color("f4b769"))
	_rect(122,3,16,3,Color("36575b"))
	_rect(123,9,15,3,Color("36575b"))
	_shape([115,28,144,24,147,35,143,41,117,44],Color("a8afa0"))
	_rect(17,22,39,8,Color("9ca598"))
	_shape([-39,46,-31,29,-12,19,13,20,29,28,41,45,34,48,23,35,9,30,-9,30,-23,37,-30,47],Color("466b69"))
	_stroke([72,-47,87,-49,99,-58],Color("506a65"),1.5)
	_stroke([102,-63,111,-62,111,-46],Color("344e50"),2)
	_rect(107,-62,9,12,Color("587472"))
	_screen()


func _ruler(rear: float, front: float, top: float) -> void:
	var s := _scale()
	var base := _wheelbase()
	var ticks := roundi(base * 2.0)
	for i in range(ticks + 1):
		var value := float(i) * 0.5
		var x := lerpf(rear, front, value / base)
		var major := i % 2 == 0 or i == ticks
		var color := Color("f3e7bc") if major else Color("cad9be")
		_line(x, top + 9 * s, x, top + (18 if major else 15) * s, color, maxf(1.0, 1.9 * s))
		if major:
			var label := _metre_label(value)
			_word(label, x - 18 * s, top + 28 * s, 36 * s, maxi(10, roundi(13 * s)), color)
	for x in [rear + 0.10 * _metre(), front - 0.10 * _metre()]:
		_line(x, top - s, x, top + 6 * s, Color("bd694c"), maxf(2, 3 * s))


func _crate(index: int) -> void:
	var box: Dictionary = model.cargo[index]
	var rect := _cargo_rect(index)
	if rect.position.x > size.x or rect.end.x < 0:
		return
	var wooden := bool(box.marked)
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	var s := _scale()
	if index == held and lift_fraction > 0.05:
		var floor_y := deck_y()
		if x_to_pixel(hook_world_x) < size.x * 0.316 or (hook_world_x >= 0 and hook_world_x <= _wheelbase()):
			_rect(x + w * 0.05, floor_y - s, w * 0.9, maxf(1.5,2*s), Color("675c4b",0.51))
	draw_set_transform(rect.position, 0.0, Vector2(w / 100, h / 70))
	if wooden:
		_shape([2,4,10,0,95,0,100,5,100,64,94,69,1,69],Color("a66f42"))
		_shape([1,6,9,4,93,4,93,65,1,66],Color("c39257"))
		_shape([93,5,100,1,100,63,93,69],Color("966944"))
		_shape([2,5,10,0,99,0,92,5],Color("e0b67a"))
		for line in [17,31,46,60]:
			_line(1,line,93,line,Color("a47548"),1.1)
			_line(4,line+1.3,88,line+1.3,Color("d0a468"),0.7)
		_shape([5,57,10,58,90,9,84,9],Color("ab7c4e"))
		_rect(8,3,7,63,Color("76877a"))
		_rect(9,3,1.7,63,Color("a4aa8d"))
		_rect(78,3,7,63,Color("76877a"))
		_rect(79,3,1.7,63,Color("a4aa8d"))
		_rect(1,63,92,5,Color("a5784c"))
		_rect(6,67,15,3,Color("6e5943"))
		_rect(75,67,15,3,Color("6e5943"))
		for px in [11,81]:
			for py in [8,57]:
				_disk(px,py,1.1,Color("485855"))
		# The shipping stencil sits on the wood, with the straps still visible.
		_rect(18,14,57,39,Color("ddbd85"))
		_line(22,49,70,49,Color("b99a67"),0.7)
	else:
		_shape([0,13,5,8,95,8,100,12,98,67,92,70,4,69],Color("365a62"))
		_shape([2,17,92,15,91,63,6,65],Color("4f7c83"))
		_shape([92,16,100,12,98,66,91,69],Color("385c63"))
		_shape([0,10,7,4,94,4,100,10,99,19,1,20],Color("73999a"))
		_rect(1,16,97,3,Color("a9baab"))
		_rect(8,19,6,10,Color("ccad76"))
		_rect(79,18,6,10,Color("ccad76"))
		_stroke([34,7,36,2,54,2,58,6],Color("334e53"),2.4)
		_rect(16,25,60,32,Color("749392"))
		_rect(7,63,82,3,Color("769492"))
		_disk(7,58,1.2,Color("b5c1aa"))
		_disk(87,58,1.2,Color("b5c1aa"))
	_screen()
	var font_name := clampi(roundi(minf(22*s, h*0.251)), 10, 26)
	var font_weight := clampi(roundi(minf(16*s, h*0.194)), 9, 20)
	var left := x + w * 0.145
	var space := w * 0.64
	var known: float = model.known_weight(index)
	var label := "%.0f kN" % known if is_equal_approx(known, roundf(known)) else "%.1f kN" % known
	if known < 0:
		label = "待称"
	var name_color := Color("333f3b") if wooden else Color("152f35")
	var details_color := Color("3a473f") if wooden else Color("18383e")
	_word(str(box.label), left, y + h * (0.47 if wooden else 0.57), space, font_name, name_color)
	_word(label, left, y + h * (0.69 if wooden else 0.77), space, font_weight, details_color)
	var cx := rect.get_center().x
	_shape([cx-4*s,rect.end.y-6*s,cx+4*s,rect.end.y-6*s,cx,rect.end.y-s],Color("e9d9aa"))
	if selected == index and departure < 0.001 and not _at_exit():
		var edge := Color("fbe1a0")
		var leg := minf(11*s, h*0.18)
		var gap := 3*s
		for side in [-1, 1]:
			var corner_x := x - gap if side < 0 else rect.end.x + gap
			var cy := y - gap
			_stroke([corner_x,cy+leg,corner_x,cy,corner_x-side*leg,cy],edge,maxf(1.5,2.5*s))


func _landing_mark() -> void:
	var index := held if _valid(held) else selected
	if not _valid(index) or cursor_x < 0.0 or cursor_x > _wheelbase() or departure > 0.001:
		return
	var s := _scale()
	var px := x_to_pixel(cursor_x)
	var y := deck_y()
	var half := float(model.cargo[index].width) * _metre() * 0.5
	var allowed: bool = str(model.placement_error(index, cursor_x)).is_empty()
	var tint := Color("ffe0a2") if allowed else Color("ff997c")
	_line(px-half,y-2*s,px+half,y-2*s,Color("35484a"),maxf(2.5,5*s))
	_line(px-half,y-2*s,px+half,y-2*s,tint,maxf(1.5,2*s))
	for side in [-1,1]:
		var at: float = px + side * half
		_stroke([at-5*s*side,y-2*s,at,y-2*s,at,y-11*s],tint,maxf(1.4,2*s))
	_shape([px-5*s,y-11*s,px+5*s,y-11*s,px,y-4*s],tint)
	_shape([px-5*s,y+8*s,px+5*s,y+8*s,px,y+2*s],tint)


func _hoist() -> void:
	var s := _scale()
	var x := x_to_pixel(hook_world_x)
	var rail_y := _y(26)
	var connected := _valid(held)
	var bottom := _y(123)
	var bounds := Rect2()
	if connected:
		bounds = _cargo_rect(held)
		bottom = bounds.position.y - minf(32 * s, bounds.size.x * 0.26)
	var head := bottom - 12*s
	var top := rail_y + 21*s
	if head > top:
		_line(x-2.5*s,top,x-2.5*s,head,Color("30434a"),maxf(1.1,2.2*s))
		_line(x+2.5*s,top,x+2.5*s,head,Color("586962"),maxf(1.0,1.8*s))
	if connected:
		var spread := bounds.size.x * 0.32
		_stroke([x-spread,bounds.position.y+1.0,x,bottom,x+spread,bounds.position.y+1.0],Color("364849"),maxf(1.7,3.6*s))
		_stroke([x-spread,bounds.position.y,x,bottom-1*s,x+spread,bounds.position.y],Color("d3b575"),maxf(1.0,1.5*s))
		_disk(x-spread,bounds.position.y+1.2*s,maxf(1.5,2.8*s),Color("576961"))
		_disk(x+spread,bounds.position.y+1.2*s,maxf(1.5,2.8*s),Color("576961"))
	_at(Vector2(x, bottom), s)
	_shape([-6,-15,-4,-20,4,-20,7,-16,6,-9,0,-5,-6,-9],Color("394b4a"))
	_shape([-5,-15,-3,-18,4,-18,6,-15,5,-12,-5,-12],Color("d88955"))
	_stroke([0,-8,0,-2,-2,0,-4,-1,-4,-4],Color("384d4e"),2.5)
	_at(Vector2(x, rail_y + 8*s), s)
	_disk(-16,-1,6,Color("304e50"))
	_disk(15,-1,6,Color("304e50"))
	_shape([-26,0,22,0,25,7,18,17,-15,18,-26,12],Color("586964"))
	_shape([-24,1,20,1,21,9,15,13,-15,13,-23,9],Color("d19655"))
	for dx in [-11,1,13]:
		_line(dx-3,2,dx-8,10,Color("846d4c"),2.3)
	_rect(-7,14,15,4,Color("708278"))
	_screen()
