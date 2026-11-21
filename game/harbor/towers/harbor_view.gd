extends Control

signal cell_selected(index: int)
signal tower_selected(side: int)

const ChartUI := preload("res://ui/skin.gd")
const LogModel := preload("res://harbor/towers/pair_log.gd")
const PAPER := Color("#f4ecd7")
const SKY := Color("#183c4d")
const WATER := Color("#16404d")
const DAY := Color("#ffd08c")
const MOON := Color("#a4ddd9")
const MIST := Color("#acc7c6")
const DYE := Color("#091f2a")
const ROSE := Color("#f4a08d")
const VIEW := Vector2(760, 452)
var station
var _face := ChartUI.face()
var _time := 0.0
var _arrival := 0.0
var _scale := 1.0
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func arrival() -> void:
	_arrival = 1.0

func _process(delta: float) -> void:
	_time += minf(delta, 0.12)
	_arrival = maxf(0.0, _arrival - delta * 1.55)
	queue_redraw()

func _write(at: Vector2, value: String, pixels: int, ink: Color = PAPER, width: float = -1, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_face, at, value, align, width, pixels, ink)

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	draw_line(a, b, color, width, true)

func _draw() -> void:
	if station == null: return
	draw_rect(Rect2(Vector2.ZERO, size), DYE)
	_scale = minf(size.x / VIEW.x, size.y / VIEW.y)
	_origin = (size - VIEW * _scale) / 2.0
	draw_set_transform(_origin, 0.0, Vector2(_scale, _scale))
	_skyline()
	var quantum: bool = station.phase in ["quantum","forecast","running","review","audit","signed","pair_compare"]
	var last: Vector3i = station.last
	_tower(155, 0, last.y, last.x >= 0, quantum)
	_tower(605, 1, last.z, last.x >= 0, quantum)
	_source(quantum)
	_keel(_time * 0.54, quantum)
	var proof_mode: bool = station.phase in ["proof", "proved"]
	if station.phase == "pair_compare":
		station.quick.draw_notes(self)
	elif proof_mode:
		_rigging()
	else:
		_log_cards(quantum)
	if last.x >= 0:
		var cell: int = last.x
		_write(Vector2(210, 230), "来信 %d   /   %d" % [cell >> 1, cell & 1], 14, MIST, 340, HORIZONTAL_ALIGNMENT_CENTER)

func _skyline() -> void:
	for band in 18:
		draw_rect(Rect2(0, band * 10, VIEW.x, 11), Color("#142e42").lerp(Color("#54878b"), float(band)/18.0))
	for i in 39:
		var x := fposmod(i * 83.7 + 31, VIEW.x)
		var y := fposmod(i * i * 19.2 + 7, 124)
		draw_circle(Vector2(x, y), 1 if i % 3 else 1.55, Color(0.86, 0.91, 0.82, 0.25 + 0.20 * sin(_time * 0.7 + i)))
	draw_circle(Vector2(106, 99), 32, Color("#e1af733b"))
	draw_circle(Vector2(106, 99), 24.5, Color("#e8bd88"))
	draw_circle(Vector2(106, 99), 32, Color("#e8bd88aa"), false, 1)
	draw_circle(Vector2(677, 68), 19, Color("#c6e4d5"))
	draw_circle(Vector2(684, 60), 18, Color("#244455"))
	for layer in 2:
		var mountain: Array = [Vector2(0, 195)]
		for i in 22:
			var x := i * 38.0
			var y := 165 + layer * 12 + 11 * sin(i * 1.64 + layer) + 6 * cos(i * 2.9 + layer)
			mountain.append(Vector2(x, y))
		mountain.append(Vector2(798, 195))
		_poly(mountain, Color("#41646e") if layer == 0 else Color("#2a515e"))
	draw_rect(Rect2(0, 184, 760, 80), WATER)
	for i in 47:
		var x := fposmod(i * 77.7 + sin(_time * 0.5 + i) * 4.0, 760)
		var y := 188 + fposmod(i * 13.8, 71.0)
		_line(Vector2(x, y), Vector2(x + 6 + (i % 5) * 5, y), Color("#87abaa57"))
	_poly([Vector2(0,207),Vector2(70,194),Vector2(103,183),Vector2(164,181),Vector2(207,195),
		Vector2(248,200),Vector2(224,209),Vector2(139,215),Vector2(66,225),Vector2(0,227)], Color("#223c46"))
	_poly([Vector2(512,198),Vector2(558,191),Vector2(585,178),Vector2(645,180),Vector2(691,195),
		Vector2(760,198),Vector2(760,218),Vector2(665,214),Vector2(583,208)], Color("#223c46"))
	_write(Vector2(20, 28), "昼塔  /  阿照", 19, DAY)
	_write(Vector2(550, 28), "月塔  /  望舒", 19, MOON, 190, HORIZONTAL_ALIGNMENT_RIGHT)

func _tower(x: float, side: int, bit: int, has_result: bool, quantum: bool) -> void:
	var ink := DAY if side == 0 else MOON
	var point := Vector2(x, 102 if side == 0 else 94)
	var sign_x := 1 if side == 0 else -1
	var powered := has_result and bit == 1
	if quantum:
		var setting: int = ((station.last.x >> 1) if side == 0 else (station.last.x & 1)) if has_result else 0
		if station.phase == "quantum" and (station.active_axis >> 1) == side:
			setting = station.active_axis & 1
		var tick: int = station.angles[side * 2 + setting]
		if station.phase == "pair_compare":
			tick = station.quick.angle if side == 1 else 0
		var why := Vector2.from_angle(-tick * PI / 8)
		draw_arc(point, 26, 0, TAU, 40, Color(ink, 0.42), 1.1, true)
		_line(point - why * 26, point + why * 26, ink, 2.3)
	if powered:
		var beam_end := point + Vector2(sign_x * 196, -7 + sin(_time * 2 + side) * 5)
		_poly([point, beam_end + Vector2(0,-9),beam_end + Vector2(0,13)], Color(ink, 0.11 + 0.09 * _arrival))
		draw_circle(point, 17 + _arrival * 8, Color(ink, 0.16))
	var ox := point.x
	var oy := point.y
	_poly([Vector2(ox-19,186),Vector2(ox-9,oy+12),Vector2(ox+9,oy+12),Vector2(ox+19,186)], Color("#d4d9bc"))
	_poly([Vector2(ox+4,186),Vector2(ox+3,oy+12),Vector2(ox+9,oy+12),Vector2(ox+19,186)], Color("#82a59b"))
	var stripe := Color("#b76e57") if side == 0 else Color("#486b83")
	for j in 2:
		var yy := 145.0 + 27 * j
		var half := 12.0 + 3 * j
		_poly([Vector2(ox-half,yy),Vector2(ox+half,yy-7),Vector2(ox+half+1,yy+1),Vector2(ox-half-1,yy+8)], stripe)
	draw_rect(Rect2(ox-6,168,10,18), Color("#33525a"))
	draw_rect(Rect2(ox-12,oy-7,24,19), Color("#16323d"))
	draw_rect(Rect2(ox-8,oy-5,16,13), ink if powered else (Color("#a6b4a2") if not has_result else Color("#627977")))
	_line(Vector2(ox,oy-5),Vector2(ox,oy+8),Color("#42575a"),2)
	_poly([Vector2(ox-17,oy-7),Vector2(ox,oy-20),Vector2(ox+17,oy-7)], stripe)
	_line(Vector2(ox,oy-19), Vector2(ox,oy-31), ink, 1.5)
	_line(Vector2(ox-16,oy+12), Vector2(ox+16,oy+12), Color("#2b4048"), 3)
	var keeper := Vector2(ox + sign_x * 35, 181 + sin(_time * 2 + side))
	draw_circle(keeper-Vector2(0,8), 3.8, Color("#e7c398"))
	_poly([keeper+Vector2(-5,1),keeper+Vector2(-3,-6),keeper+Vector2(3,-6),keeper+Vector2(5,1)], stripe)
	_line(keeper+Vector2(-4,-10),keeper+Vector2(4,-10),ink,2)
	_line(keeper+Vector2(sign_x*3,-3),keeper+Vector2(sign_x*8,-4-_arrival*5),ink,1.5)
	if has_result:
		var input: int = (station.last.x >> 1) if side == 0 else (station.last.x & 1)
		var text := "信 %d  ·  %s" % [input, "亮" if bit else "暗"]
		var px := x - 54
		draw_rect(Rect2(px, 199, 108, 24), Color("#112a35df"))
		_write(Vector2(px,217), text, 15, ink, 108, HORIZONTAL_ALIGNMENT_CENTER)

func _source(quantum: bool) -> void:
	var pos := Vector2(380, 119)
	draw_rect(Rect2(307, 35, 146, 29), Color("#102833cd"))
	_write(Vector2(307, 55), "Φ⁺ 双光子源" if quantum else "两塔之间已封闸", 16, PAPER, 146, HORIZONTAL_ALIGNMENT_CENTER)
	if not quantum: return
	draw_arc(pos, 17, -PI, 0, 18, MIST, 2, true)
	_line(pos - Vector2(23,0), pos + Vector2(23,0), MIST, 2)
	var t := fposmod(_time * 0.62, 1.0)
	for side in 2:
		var end := Vector2(155,102) if side == 0 else Vector2(605,94)
		_line(pos, end, Color("#badada37"))
		var point := pos.lerp(end, t)
		draw_circle(point, 5, Color("#b0e1e444"))
		draw_circle(point, 2.6, MOON if side == 1 else DAY)

func _keel(clock: float, quantum: bool) -> void:
	var x := 270.0 + fposmod(clock * 27.0, 215.0)
	var y := 204.0 + sin(clock * 2.2) * 1.8
	var sail := Vector2(x,y)
	_poly([sail+Vector2(-14,0),sail+Vector2(14,0),sail+Vector2(8,5),sail+Vector2(-8,5)], Color("#e3a778"))
	_line(sail+Vector2(0,-16), sail, PAPER, 1.6)
	_poly([sail+Vector2(-1,-15),sail+Vector2(-1,-2),sail+Vector2(-11,-3)], MOON if quantum else DAY)
	_line(sail+Vector2(-24,6),sail+Vector2(-10,6),MIST)

func _log_cards(quantum: bool) -> void:
	draw_rect(Rect2(0, 262, 760, 190), Color("#102b34"))
	_line(Vector2(18,262),Vector2(742,262),Color("#698d8c"))
	_write(Vector2(22,288), station.status, 19, PAPER)
	if quantum:
		var logs = station.logbook
		if logs.count > 0:
			_write(Vector2(22,316), "进港 %.1f%%　　昼亮 %.1f%%　 月亮 %.1f%%　　已回 %d 艘" % [
				logs.percent(logs.wins),logs.percent(logs.bright[0]),logs.percent(logs.bright[1]),logs.count],18,MOON)
		else:
			_write(Vector2(22,316), "本地读头　 昼 %s / %s　　 月 %s / %s" % [
				LogModel.angle_name(station.angles[0]),LogModel.angle_name(station.angles[1]),
				LogModel.angle_name(station.angles[2]),LogModel.angle_name(station.angles[3])],17,MOON)
	else:
		_write(Vector2(22,316), "同号是一起亮或一起暗。异号是一亮一暗。", 16, MIST)
	for index in 4:
		var x := 20.0 + index * 182.0
		var rect := Rect2(x,331,172,77)
		var accent := DAY if index == 3 else MOON
		var active: bool = station.last.x == index
		draw_rect(rect, Color("#284650") if active else Color("#183640"))
		draw_rect(rect, Color(accent, 0.85) if active else Color("#355761"), false, 2 if active else 1)
		_write(Vector2(x+11,355), "%d%d 班" % [index>>1,index&1],18,PAPER)
		_write(Vector2(x+74,355), "要异号" if index==3 else "要同号",15,accent,88,HORIZONTAL_ALIGNMENT_RIGHT)
		var label: String
		if quantum:
			var n: int = station.logbook.visits[index]
			label = "同号 %d / %d" % [station.logbook.matched[index],n] if n else "尚无回报"
		else:
			label = ["待试航", "闸外停泊", "顺利进港"][station.seen[index]+1]
		_write(Vector2(x+11,388),label,17,accent if active else MIST)
	_write(Vector2(22,434), "两塔日志分开写，靠岸才能对表。" if quantum else "点任一航道可单独放船。也可以在右侧点名或让四艘依次试航。", 15, MIST)

func _rigging() -> void:
	draw_rect(Rect2(0,262,760,190),Color("#102b34"))
	_write(Vector2(22,289),station.status,19,PAPER)
	var nodes := [Vector2(191,324),Vector2(191,393),Vector2(568,324),Vector2(568,393)]
	var links := [Vector2i(0,2),Vector2i(0,3),Vector2i(2,1),Vector2i(1,3)]
	for i in 4:
		var a: Vector2 = nodes[links[i].x]
		var b: Vector2 = nodes[links[i].y]
		if a.x > b.x:
			var swap := a
			a = b
			b = swap
		var tied: bool = i < station.link_count
		if tied:
			var rope := PackedVector2Array()
			for k in 27:
				var t := k / 26.0
				rope.append(a.lerp(b,t) + Vector2(0, sin(t*PI)*(5+1.1*sin(_time*2+i))))
			draw_polyline(rope,MOON,2.5,true)
		else:
			var tint := ROSE if i == 3 and station.phase == "proved" else Color("#4b6a72")
			draw_dashed_line(a,b,tint,1.4,8)
	for i in 4:
		var p: Vector2 = nodes[i]
		var bit: int = station.proof[i]
		draw_circle(p,12,Color("#102b34"))
		draw_circle(p,10, DAY if bit==1 else Color("#718882") if bit==0 else Color("#34515a"))
		draw_circle(p,11, MOON,false,1.3,true)
		var caption := "%s   %s" % [station.ENDS[i], "待扣" if bit<0 else "亮" if bit==1 else "暗"]
		_write(p+Vector2(-149 if i<2 else 24,5),caption,16,PAPER)
	_write(Vector2(22,436), "三道同号缆都是实线时，再沿它们从昼 1 走到月 1。",15,MIST)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed): return
	var point: Vector2 = (event.position - _origin) / maxf(_scale, 0.01)
	if point.y >= 331 and point.y <= 408 and point.x >= 20 and point.x < 738 and station.phase not in ["proof","proved"]:
		cell_selected.emit(clampi(floori((point.x-20)/182.0),0,3))
		accept_event()
	elif point.y > 72 and point.y < 187:
		for side in 2:
			if absf(point.x - (155 if side == 0 else 605)) < 47:
				tower_selected.emit(side)
				accept_event()
