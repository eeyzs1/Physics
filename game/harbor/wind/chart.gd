extends Control

const Weather := preload("res://harbor/wind/convection.gd")
const PAGE := Vector2(820, 480)
const CORAL := Color("#ff9b76")
const GOLD := Color("#ffd397")
const AQUA := Color("#88ddca")
const PAPER := Color("#e0eee1")
const MUTED := Color("#a0bcb9")
const ROUTES := {
	"outer":[Vector2(61,207),Vector2(122,235),Vector2(166,188),Vector2(237,188)],
	"shoal":[Vector2(237,188),Vector2(300,159),Vector2(350,185),Vector2(421,158)],
	"narrow":[Vector2(421,158),Vector2(490,161),Vector2(596,99),Vector2(735,118)],
	"bay":[Vector2(421,158),Vector2(488,300),Vector2(661,317),Vector2(735,118)],
}
const STRAIT := Rect2(515,75,101,26)
const BAY := Rect2(542,275,116,26)
var station
var dragging := false
var face: Font

func _ready() -> void:
	face = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		if dragging:
			dragging = false
			station.chart_turn(0.0))

func _text(pos: Vector2, value: String, height: int = 15, color: Color = PAPER) -> void:
	draw_string(face,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,height,color)

func _plate(area: Rect2, tint: Color) -> void:
	draw_rect(area,Color("#163740"))
	draw_line(area.position,Vector2(area.position.x,area.end.y),tint,2.0,true)

func _tag(area: Rect2, value: String, tint: Color) -> void:
	_plate(area,tint)
	_text(area.position+Vector2(7,18),value,13,tint)

func _line(points: Array, color: Color, width: float = 1.5) -> void:
	draw_polyline(PackedVector2Array(points),color,width,true)

func _isle(points: PackedVector2Array, green: Color, reef: Color) -> void:
	var base := PackedVector2Array()
	var shoal := PackedVector2Array()
	var centre := Vector2.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	for p in points:
		base.append(p+Vector2(1,6))
		shoal.append(centre+(p-centre)*1.10+Vector2(1,7))
	draw_colored_polygon(shoal,Color("#418b85"))
	draw_colored_polygon(base,reef)
	draw_colored_polygon(points,green)
	var edge := points.duplicate()
	edge.append(edge[0])
	draw_polyline(edge,Color("#a9b78a"),1.1,true)

func _land() -> void:
	_isle(PackedVector2Array([Vector2(0,41),Vector2(201,41),Vector2(173,55),Vector2(151,62),Vector2(130,64),Vector2(108,84),Vector2(81,86),Vector2(62,115),Vector2(32,120),Vector2(0,142)]),Color("#738e73"),Color("#9d8466"))
	_isle(PackedVector2Array([Vector2(325,41),Vector2(456,41),Vector2(444,57),Vector2(416,60),Vector2(395,76),Vector2(371,69),Vector2(348,73),Vector2(332,65)]),Color("#6e8874"),Color("#917b62"))
	_isle(PackedVector2Array([Vector2(465,118),Vector2(489,103),Vector2(507,102),Vector2(525,95),Vector2(544,101),Vector2(538,111),Vector2(518,115),Vector2(505,125),Vector2(478,126)]),Color("#708c73"),Color("#b19068"))
	_isle(PackedVector2Array([Vector2(498,185),Vector2(526,167),Vector2(547,163),Vector2(572,153),Vector2(602,151),Vector2(629,157),Vector2(618,174),Vector2(600,179),Vector2(580,201),Vector2(535,204)]),Color("#769575"),Color("#ab8966"))
	_isle(PackedVector2Array([Vector2(728,88),Vector2(751,68),Vector2(775,55),Vector2(790,57),Vector2(820,43),Vector2(820,173),Vector2(796,167),Vector2(776,151),Vector2(759,146),Vector2(749,128),Vector2(732,120)]),Color("#829a76"),Color("#a88b68"))
	_isle(PackedVector2Array([Vector2(0,189),Vector2(19,178),Vector2(36,185),Vector2(49,202),Vector2(50,218),Vector2(35,225),Vector2(22,242),Vector2(0,244)]),Color("#729070"),Color("#967d63"))
	_isle(PackedVector2Array([Vector2(0,328),Vector2(0,306),Vector2(43,284),Vector2(82,285),Vector2(99,266),Vector2(127,266),Vector2(145,250),Vector2(169,246),Vector2(186,263),Vector2(177,277),Vector2(149,291),Vector2(129,312),Vector2(103,328)]),Color("#648774"),Color("#947c67"))
	for loc: Vector2 in [Vector2(292,137),Vector2(308,141),Vector2(345,210),Vector2(359,207),Vector2(637,199),Vector2(640,195)]:
		draw_colored_polygon(PackedVector2Array([loc+Vector2(-5,4),loc+Vector2(0,-3),loc+Vector2(6,2),loc+Vector2(3,5)]),Color("#b4a18a"))
	for loc: Vector2 in [Vector2(103,68),Vector2(113,66),Vector2(91,76),Vector2(553,183),Vector2(559,178),Vector2(583,170),Vector2(758,102),Vector2(765,102),Vector2(143,274),Vector2(156,268)]:
		draw_colored_polygon(PackedVector2Array([loc+Vector2(-4,2),loc+Vector2(1,-5),loc+Vector2(4,1)]),Color("#4b7664"))
	for k in 7:
		var base := Vector2(43.0+3*k,204.0-1.2*k)
		draw_line(base,base+Vector2(3,7),Color("#c39a6d"),2.5,true)
	draw_circle(Vector2(747,115),7,Color("#f8d096"),true,-1,true)
	draw_colored_polygon(PackedVector2Array([Vector2(740,119),Vector2(744,94),Vector2(750,94),Vector2(753,119)]),Color("#ead7ab"))
	draw_line(Vector2(743,105),Vector2(752,105),Color("#d87055"),5,true)
	draw_rect(Rect2(742,90,10,6),Color("#ffc77e"))
	draw_colored_polygon(PackedVector2Array([Vector2(738,90),Vector2(747,83),Vector2(756,90)]),Color("#b75d4d"))
	for base: Vector2 in [Vector2(26,201),Vector2(34,197),Vector2(21,206),Vector2(768,117),Vector2(777,119),Vector2(774,111)]:
		draw_rect(Rect2(base,Vector2(5,4)),Color("#d9bb86"))
		draw_colored_polygon(PackedVector2Array([base+Vector2(-1,0),base+Vector2(2,-3),base+Vector2(6,0)]),Color("#ab6551"))
		draw_line(base+Vector2(2,1),base+Vector2(2,3),GOLD,1.0)

func _fog_bank(pos: Vector2, span: Vector2, shift: float) -> void:
	# Translucent contours leave lights, reefs and the narrow sill readable through the bank.
	for layer in 3:
		var outline := PackedVector2Array()
		for i in 32:
			var a := TAU*float(i)/32.0
			var fringe := 1.0+.11*sin(3*a+shift)+.065*cos(7*a-shift)
			outline.append(pos+Vector2(cos(a)*span.x,sin(a)*span.y)*(1.0-layer*.15)*fringe+Vector2(layer*4,-layer*2))
		draw_colored_polygon(outline,Color("#c4e4dc0e"))

func point_at(key: String, t: float) -> Vector2:
	var pts: Array = ROUTES[key]
	return (pts[0] as Vector2).bezier_interpolate(pts[1],pts[2],pts[3],clampf(t,0.0,1.0))

func tangent(key: String, t: float) -> Vector2:
	return (point_at(key,t+.01)-point_at(key,t-.01)).normalized()

func at_offset(key: String, t: float, amount: float) -> Vector2:
	var dir := tangent(key,t)
	return point_at(key,t)+Vector2(-dir.y,dir.x)*amount*.78

func _lane(key: String, active: bool) -> void:
	var spec: Dictionary = Weather.LEGS[key]
	var color := GOLD if key=="narrow" else AQUA
	var band := PackedVector2Array()
	var points := PackedVector2Array()
	for i in 32:
		var t := i/31.0
		band.append(at_offset(key,t,spec.width))
		points.append(point_at(key,t))
	for i in range(31,-1,-1):
		band.append(at_offset(key,i/31.0,-float(spec.width)))
	color.a = .075 if active else .025
	draw_colored_polygon(band,color)
	color.a = .94 if active else .51
	for i in range(0,31,2):
		draw_line(points[i],points[i+1],color,2.0 if active else 1.3,true)

func _mark(pos: Vector2, label: String, shift: Vector2) -> void:
	draw_circle(pos,4,Color("#28464a"),true,-1,true)
	draw_arc(pos,7,0,TAU,20,GOLD,1.3,true)
	_text(pos+shift,label,14,PAPER)

func _boat(pos: Vector2, facing: Vector2) -> void:
	var side := Vector2(-facing.y,facing.x)
	draw_line(pos-facing*12+side*3,pos-facing*23+side*6,Color("#a4ccc2"),1.7,true)
	draw_line(pos-facing*12-side*3,pos-facing*27-side*7,Color("#a4ccc2"),1.7,true)
	draw_colored_polygon(PackedVector2Array([pos+facing*14,pos+facing*3+side*6,pos-facing*10+side*4,pos-facing*10-side*4,pos+facing*3-side*6]),Color("#e98c64"))
	draw_line(pos-facing*8,pos+facing*8,Color("#523e36"),2.4,true)
	draw_line(pos+facing*2,pos+facing*2+Vector2(-2,-17),Color("#ebd9b9"),1.6,true)
	draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-16),pos+Vector2(-9,-7),pos+Vector2(0,-5)]),PAPER)

func _graph() -> void:
	draw_rect(Rect2(0,328,820,152),Color("#17343d"))
	draw_line(Vector2(0,328),Vector2(820,328),Color("#517c7b"),1.0)
	if station.predicted.is_empty():
		return
	var r: Dictionary = station.predicted
	var spec: Dictionary = Weather.LEGS[r.key]
	_text(Vector2(16,352),"%s · 横向偏移" % spec.name,16,PAPER)
	draw_line(Vector2(317,347),Vector2(337,347),AQUA,2)
	_text(Vector2(343,351),"14 条预报",13,MUTED)
	draw_line(Vector2(447,347),Vector2(469,347),CORAL,2.4)
	_text(Vector2(475,351),"邮船实迹",13,MUTED)
	_text(Vector2(613,351),"虚线为航道边界",13,MUTED)
	var plot := Rect2(53,367,741,81)
	var limit := maxf(float(spec.width)*1.30,minf(float(spec.width)*2.15, float(r.maximum)*1.05))
	var mid := plot.get_center().y
	var factor := plot.size.y*.48/limit
	for side in [-1.0,1.0]:
		var y := mid+float(side)*float(spec.width)*factor
		draw_dashed_line(Vector2(plot.position.x,y),Vector2(plot.end.x,y),Color("#aa7e74"),1,7,true)
	draw_line(Vector2(plot.position.x,mid),Vector2(plot.end.x,mid),Color("#456467"),1)
	_text(Vector2(7,mid+4),"0 m",12,MUTED)
	_text(Vector2(8,mid-float(spec.width)*factor+3),"%d" % int(spec.width),12,Color("#dca599"))
	for sample in r.curves:
		var points := PackedVector2Array()
		for i in sample.size():
			points.append(Vector2(plot.position.x+plot.size.x*minf(i*3.0/float(spec.ticks),1.0),mid-clampf(sample[i],-limit,limit)*factor))
		draw_polyline(points,Color("#74c6b099"),1.0,true)
	if station.actual_curve.size() >= 2 and station.section==str(r.key):
		var actual := PackedVector2Array()
		for i in station.actual_curve.size():
			actual.append(Vector2(plot.position.x+plot.size.x*i/float(spec.ticks),mid-clampf(station.actual_curve[i],-limit,limit)*factor))
		draw_polyline(actual,CORAL,2.4,true)
		draw_circle(actual[actual.size()-1],3.0,GOLD,true,-1,true)
	_text(Vector2(52,466),"解缆",12,MUTED)
	_text(Vector2(688,466),"航段 %.2f 港分" % (int(spec.ticks)*Weather.MINUTES_PER_TICK),12,MUTED)

func _draw() -> void:
	if station == null or face == null:
		return
	draw_set_transform(Vector2.ZERO,0,size/PAGE)
	if station.probe_open:
		_draw_probes()
		return
	for row in 24:
		draw_rect(Rect2(0,row*14,820,15),Color("#265966").lerp(Color("#2f7076"),row/23.0))
	var mist := Color("#bce7cf10")
	for i in 17:
		var pos := Vector2(fmod(45+i*137.0,810),62+fmod(i*43,235))
		draw_line(pos,pos+Vector2(18+i%4*6,-2),mist,1.4,true)
	_land()
	var passage := float(station.clock_tick)*.013
	var fog_shift := Vector2(8.0*sin(passage),3.0*cos(passage*.63))
	_fog_bank(Vector2(333,116)+fog_shift,Vector2(70,12),passage)
	_fog_bank(Vector2(576,138)-fog_shift,Vector2(89,15),passage*.7)
	_fog_bank(Vector2(633,236)+fog_shift,Vector2(73,11),passage*.8+.9)
	for key: String in ROUTES:
		_lane(key,not station.predicted.is_empty() and key==str(station.predicted.key))
	for row in 3:
		for col in 4:
			var start := Vector2(270+104*col+13*row,79+55*row)
			var points := PackedVector2Array()
			for k in 15:
				points.append(start+Vector2(k*4,3*sin(.38*k+.83*row)))
			draw_polyline(points,Color("#c6e5d816"),2.8,true)
	var last_key := ""
	var trace := PackedVector2Array()
	for sample in station.course_trace:
		if sample.key != last_key and trace.size()>1:
			draw_polyline(trace,CORAL,2.2,true)
			trace.clear()
		trace.append(at_offset(sample.key,sample.t,sample.off))
		last_key = sample.key
	if trace.size()>1:
		draw_polyline(trace,CORAL,2.2,true)
	_mark(Vector2(61,207),"邮局",Vector2(-20,27))
	_mark(Vector2(237,188),"双礁浮台",Vector2(-42,33))
	_mark(Vector2(421,158),"雾口",Vector2(-24,-18))
	_tag(STRAIT, "裂帆峡  15 m",GOLD)
	_tag(BAY, "灯笼湾  60 m",AQUA)
	_text(Vector2(707,68),"灯塔潮闸",16,GOLD)
	if not station.buoy_place.is_empty():
		var buoy := Vector2(237,188) if station.buoy_place=="双礁浮台" else Vector2(421,158)
		draw_line(buoy+Vector2(0,7),buoy+Vector2(0,-11),GOLD,2,true)
		draw_circle(buoy+Vector2(0,-12),4,CORAL,true,-1,true)
	var boat_key := str(station.section)
	var t := clampf(float(station.segment_tick)/float(Weather.LEGS[boat_key].ticks),0,1)
	var boat_pos := at_offset(boat_key,t,station.offset_m)
	if station.phase in ["shoal","mouth"]:
		boat_pos = point_at(boat_key,1)
	_boat(boat_pos,tangent(boat_key,t))
	draw_rect(Rect2(0,0,820,40),Color("#16373f"))
	_text(Vector2(15,27),"雾谷海图",20,PAPER)
	_text(Vector2(129,26),station.TIDE_NAMES[station.tide],15,AQUA)
	_text(Vector2(481,26),"港钟  %.2f / 14.00" % station.port_minutes(station.clock_tick),16,GOLD)
	_text(Vector2(679,26),"浮标  %d / 1" % int(station.buoy_place.is_empty()),15,PAPER)
	_graph()

func _trace_point(tick: int, error: float) -> Vector2:
	var lift := 84.0 * error if error <= 1.0 else 84.0 + 86.0 * log(minf(error,64.0)) / log(64.0)
	return Vector2(62.0 + 710.0 * tick / 800.0, 293.0 - lift)

func _draw_probes() -> void:
	var now: int = station.probe_tick
	var tape: Dictionary = station.probe_trace
	draw_rect(Rect2(Vector2.ZERO,PAGE),Color("#163640"))
	_text(Vector2(28,40),"同一时刻，两份预报离实况多远？",26,PAPER)
	_text(Vector2(28,71),"普通探头",17,CORAL)
	_text(Vector2(138,71),"十倍精密探头",17,AQUA)
	_text(Vector2(311,71),"状态误差，单位为格",16,MUTED)
	_text(Vector2(560,71),"金线 1 格 = 可用上限",16,GOLD)
	for grid: float in [0.0,0.5,1.0,4.0,16.0,64.0]:
		var y := _trace_point(0,grid).y
		var marking := "0.5" if grid==0.5 else str(int(grid))
		_text(Vector2(28,y+5),marking,13,GOLD if grid==1.0 else MUTED)
		draw_line(Vector2(62,y),Vector2(772,y), GOLD if grid==1.0 else Color("#386067"), 1.6 if grid==1.0 else 1.0)
	for minute in [0,6,12,18,24]:
		var x := _trace_point(roundi(minute / Weather.MINUTES_PER_TICK),0).x
		_text(Vector2(x-6,316),str(minute),14,MUTED)
		draw_line(Vector2(x,120),Vector2(x,293),Color("#3f606255"))
	for instrument in 2:
		var series: PackedFloat32Array = tape.normal if instrument==0 else tape.fine
		var tint := CORAL if instrument==0 else AQUA
		var line := PackedVector2Array()
		for i in range(0,now,2):
			line.append(_trace_point(i,series[i]))
		line.append(_trace_point(now,series[now]))
		if line.size()>1: draw_polyline(line,tint,2.2,true)
		draw_circle(line[-1],4.2,tint,true,-1,true)
	var current_x := _trace_point(now,0).x
	draw_dashed_line(Vector2(current_x,102),Vector2(current_x,293),Color("#e0ecdc80"),1,6)
	_text(Vector2(28,344),"读带 %.2f 港分　　金线以上每一档代表 4 倍误差。" % station.port_minutes(now),15,MUTED)
	var crossed: Vector2i = tape.crossed
	for side in 2:
		var first := crossed.x if side==0 else crossed.y
		var msg := "尚未到 1 格"
		if first >= 0 and first <= now:
			msg = "首次到 1 格　%.2f 港分" % station.port_minutes(first)
			draw_circle(_trace_point(first,1.0),5.5,CORAL if side==0 else AQUA,false,2,true)
		elif now == 800:
			msg = "24 港分内未到 1 格"
		var left := 27+390*side
		var color := CORAL if side==0 else AQUA
		var error: float = tape.normal[now] if side==0 else tape.fine[now]
		_plate(Rect2(left,359,376,92),color)
		_text(Vector2(left+13,390),"%s　%.3f 格" % ["普通探头" if side==0 else "十倍精密探头",error],21,color)
		_text(Vector2(left+13,429),msg,17,PAPER)
	_text(Vector2(29,472),"点图中任一时刻可回听，右侧按钮会停在两个探头的首次越线处。",14,MUTED)

func _gui_input(event: InputEvent) -> void:
	if station == null:
		return
	if station.probe_open:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var p: Vector2 = event.position*PAGE/size
			if Rect2(50,98,736,225).has_point(p):
				station._set_probe_tick(roundi(clampf((p.x-62)/710.0,0,1)*800))
				accept_event()
		return
	if event is InputEventMouseMotion and dragging:
		_set_helm(event.position*PAGE/size)
	elif event is InputEventMouseMotion and station.phase == "mouth":
		var p: Vector2 = event.position*PAGE/size
		if STRAIT.grow(5).has_point(p):
			station.preview_lane("narrow")
		elif BAY.grow(5).has_point(p):
			station.preview_lane("bay")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position*PAGE/size
		if not event.pressed:
			dragging = false
			station.chart_turn(0.0)
			return
		if p.y < 40 or p.y > 328:
			return
		if station.phase == "sailing":
			dragging = true
			_set_helm(p)
		elif station.phase == "mouth" and STRAIT.grow(5).has_point(p):
			station.sail("narrow")
		elif station.phase == "mouth" and BAY.grow(5).has_point(p):
			station.sail("bay")
		elif station.phase == "dock" and p.distance_to(Vector2(61,207))<32:
			station.sail("outer")
		elif station.phase == "shoal" and p.distance_to(Vector2(237,188))<32:
			station.sail("shoal")
		accept_event()

func _set_helm(p: Vector2) -> void:
	var key := str(station.section)
	var t := float(station.segment_tick)/float(Weather.LEGS[key].ticks)
	var dir := tangent(key,t)
	var amount := (p-at_offset(key,t,station.offset_m)).dot(Vector2(-dir.y,dir.x))
	station.chart_turn(clampf(amount/34.0,-1,1))
