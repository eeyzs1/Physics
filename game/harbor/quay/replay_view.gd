extends Control

signal time_selected(time: float)

const ChartUI := preload("res://ui/skin.gd")
const PAGE := Vector2(820, 480)
const GRAPH := Rect2(65, 249, 705, 112)
const SHIFT_BAR := Rect2(128,390,642,12)
const PAPER := Color("#edf1df")
const SOFT := Color("#adc9c7")
const MINT := Color("#98dfc9")
const AMBER := Color("#ffd091")
const GRID := Color("#406068")
var recording
var selected_time := 0.0
var _font := ChartUI.face()
var _dragging := false
var _drag_whole := false
var _start := 0.0
var _end := 0.0
var _plot_start := 0.0
var _plot_end := 0.0
var _center_time := 0.0
var _cache_center := -1.0
var _low := 0.0
var _high := 1.0
var _cart_curve := PackedVector2Array()
var _box_curve := PackedVector2Array()
var _cache_size := -1
var _cache_time := -1.0
var _pixel_scale := 1.0
var _origin := Vector2.ZERO

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(queue_redraw)

func select_time(time: float) -> void:
	if recording == null or recording.samples.is_empty(): return
	var a: float = recording.samples[0].t
	var b: float = recording._last.t
	selected_time = clampf(time,a,b)
	_center_time = selected_time
	queue_redraw()

func _choose(time: float, recenter: bool = true) -> void:
	if recenter:
		select_time(time)
	else:
		selected_time = clampf(time,_start,_end)
		queue_redraw()
	time_selected.emit(selected_time)

func _point(time: float, x: float) -> Vector2:
	return Vector2(GRAPH.position.x + GRAPH.size.x * (time-_plot_start) / maxf(_plot_end-_plot_start,0.001),
		GRAPH.end.y - GRAPH.size.y*(x-_low)/maxf(_high-_low,0.01))

func _cache() -> void:
	var rows: Array = recording.samples
	var end_time: float = recording._last.t
	if _cache_size == rows.size() and _cache_time == end_time and _cache_center == _center_time: return
	_cache_size = rows.size()
	_cache_time = end_time
	_cache_center = _center_time
	_start = rows.front().t
	_end = end_time
	var span := minf(5.0,_end-_start)
	_plot_start = clampf(_center_time-span*0.4,_start,maxf(_start,_end-span))
	_plot_end = _plot_start+span
	var here: Dictionary = recording.sample_at(_center_time)
	_low = minf(here.x,here.box_x)
	_high = maxf(here.x,here.box_x)
	for row: Dictionary in rows:
		if row.t < _plot_start or row.t > _plot_end: continue
		_low = minf(_low,minf(row.x,row.box_x))
		_high = maxf(_high,maxf(row.x,row.box_x))
	_low = floorf((_low-0.06)*5)/5
	_high = ceilf((_high+0.06)*5)/5
	_cart_curve.clear()
	_box_curve.clear()
	for row: Dictionary in rows:
		if row.t < _plot_start or row.t > _plot_end: continue
		_cart_curve.append(_point(row.t,row.x))
		_box_curve.append(_point(row.t,row.box_x))
	if rows.back().t != end_time and end_time <= _plot_end:
		_cart_curve.append(_point(end_time,recording._last.x))
		_box_curve.append(_point(end_time,recording._last.box_x))

func _text(x: float, y: float, value: String, px: int = 16, ink: Color = PAPER) -> void:
	draw_string(_font,Vector2(x,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,px,ink)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#112e37"))
	_pixel_scale = minf(size.x/PAGE.x,size.y/PAGE.y)
	_origin = (size-PAGE*_pixel_scale)*0.5
	draw_set_transform(_origin,0.0,Vector2.ONE*_pixel_scale)
	if recording == null or recording.samples.is_empty():
		_text(24,46,"等待第一条吊装记录",22)
		return
	_cache()
	var row: Dictionary = recording.sample_at(selected_time)
	if row.is_empty(): return
	var label := "轨迹读数"
	if not recording.first_touch.is_empty() and absf(selected_time-recording.first_touch.time)<0.012:
		label = "第一次着板"
	elif not recording.brake.is_empty() and absf(selected_time-recording.brake.time)<0.012:
		label = "车停之后"
	elif not recording.settled.is_empty() and absf(selected_time-recording.settled.t)<0.012:
		label = "落稳"
	elif not recording.period.is_empty() and minf(absf(selected_time-recording.period.first),absf(selected_time-recording.period.second))<0.012:
		label = "同侧摆峰"
	var title := "同一时刻的车和箱"
	if label=="车停之后" and not recording.after_brake_line().is_empty(): title = recording.after_brake_line()
	if label=="同侧摆峰": title = "两个同侧峰隔 %.2f s，绳长 %.2f m" % [recording.period.seconds,recording.period.rope]
	if label=="落稳" and not recording.max_swing.is_empty():
		title = "悬箱最远偏离铅垂线 %.2f m" % absf(recording.max_swing.offset)
	_text(24,38,title,18 if label=="车停之后" else 24)
	_text(557,39,"%s　%.2f s" % [label,selected_time],21,AMBER)
	_draw_crane(row)
	_draw_values(row,label)
	_text(24,230,"横向位置（m）",18)
	draw_line(Vector2(245,224),Vector2(275,224),AMBER,2.5)
	_text(284,230,"小车",16,AMBER)
	draw_line(Vector2(380,224),Vector2(410,224),MINT,2.5)
	_text(420,230,"箱心",16,MINT)
	_text(568,230,"当前这一小段",15,SOFT)
	for tick in 3:
		var position_x := lerpf(_low,_high,tick*0.5)
		var yy := _point(_plot_start,position_x).y
		draw_line(Vector2(GRAPH.position.x,yy),Vector2(GRAPH.end.x,yy),GRID)
		_text(17,yy+5,"%.1f" % position_x,14,SOFT)
	for tick in 3:
		var when := lerpf(_plot_start,_plot_end,tick*0.5)
		var xx := _point(when,_low).x
		draw_line(Vector2(xx,GRAPH.position.y),Vector2(xx,GRAPH.end.y),Color("#385860"))
		_text(xx-10,381,"%.1f s" % when,14,SOFT)
	if _cart_curve.size()>1:
		draw_polyline(_cart_curve,AMBER,2.5,true)
		draw_polyline(_box_curve,MINT,2.2,true)
	var indicator := _point(selected_time,_low).x
	draw_dashed_line(Vector2(indicator,GRAPH.position.y-7),Vector2(indicator,GRAPH.end.y),PAPER,1.2,5)
	draw_circle(_point(row.t,row.x),5.0,AMBER,true,-1,true)
	draw_circle(_point(row.t,row.box_x),4.5,MINT,false,1.7,true)
	_text(24,404,"整吊时间",14,SOFT)
	draw_rect(SHIFT_BAR,GRID)
	var fraction := clampf((selected_time-_start)/maxf(0.001,_end-_start),0,1)
	draw_circle(Vector2(SHIFT_BAR.position.x+SHIFT_BAR.size.x*fraction,SHIFT_BAR.get_center().y),6,MINT,true,-1,true)
	if label=="同侧摆峰":
		_text(24,433,"同侧峰实测间隔 %.2f s。按这段的绳长，小角近似 T≈2π√(L/g) 给出 %.2f s。" % [
			recording.period.seconds,recording.period.model],16,PAPER)
		_text(24,461,"这段里小车静止，绳长固定，最大摆角 %.1f°。角度大时，小角估算会偏。" % recording.period.angle_deg,15,MINT)
	else:
		_text(24,433,recording.takeaway(),16,PAPER)
		var action := "下次可提早收速，车停后等箱心慢下来，再下放。"
		if recording.brake.is_empty(): action = "拖动曲线可细看这一段，拖动整吊时间可换到别处。"
		_text(24,461,action,15,MINT)
	if has_focus():
		draw_rect(Rect2(2,2,PAGE.x-4,PAGE.y-4),AMBER,false,1.2)

func _draw_crane(row: Dictionary) -> void:
	var zone := Rect2(22,61,389,147)
	draw_rect(zone,Color("#173943"))
	var min_x := minf(_low,minf(recording.source_x,recording.target_x))-1.2
	var max_x := maxf(_high,maxf(recording.source_x,recording.target_x))+1.2
	var min_y := minf(row.box_y-recording.box_height*0.5,minf(recording.source_y,recording.target_y))-0.7
	var ratio := minf((zone.size.x-24)/(max_x-min_x),(zone.size.y-14)/(recording.rail_y-min_y))
	var base := Vector2(zone.get_center().x-(max_x+min_x)*0.5*ratio,zone.position.y+8+recording.rail_y*ratio)
	var rail: Vector2 = base+Vector2(row.x,-recording.rail_y)*ratio
	var box: Vector2 = base+Vector2(row.box_x,-row.box_y)*ratio
	var box_size := Vector2(recording.box_width,recording.box_height)*ratio
	draw_line(Vector2(zone.position.x+13,rail.y),Vector2(zone.end.x-13,rail.y),SOFT,2.4)
	for p: Vector2 in [Vector2(recording.source_x,recording.source_y),Vector2(recording.target_x,recording.target_y)]:
		var deck := base+Vector2(p.x,-p.y)*ratio
		draw_line(deck-Vector2(22,0),deck+Vector2(22,0),GRID,3)
	draw_dashed_line(rail,Vector2(rail.x,zone.end.y-8),Color("#8da7a580"),1.1,4)
	draw_line(rail,box-Vector2(0,box_size.y*0.5),PAPER,1.6,true)
	draw_rect(Rect2(rail-Vector2(7,3),Vector2(14,7)),AMBER)
	draw_rect(Rect2(box-box_size*0.5,box_size),MINT)
	for i in 3:
		var xx := box.x+(i-1)*box_size.x*.22
		draw_line(Vector2(xx,box.y-box_size.y*.28),Vector2(xx,box.y+box_size.y*.28),Color("#477b73"))

func _velocity(value: float) -> String:
	if absf(value)<0.01: return "约 0 m/s"
	return "向%s %.2f m/s" % ["右" if value>0.0 else "左",absf(value)]

func _draw_values(row: Dictionary, label: String) -> void:
	var x := 437.0
	_text(x,82,"小车　x %.2f m" % row.x,18,AMBER)
	if label == "第一次着板":
		var touch: Dictionary = recording.first_touch
		_text(x,112,"着板箱心　x %.2f m" % touch.x,18,MINT)
		_text(x,144,"触板前　水平%s" % _velocity(touch.vx),15)
		_text(x,173,"竖直 %+.2f m/s（向上为正）" % touch.vy,15,SOFT)
	else:
		var offset := "铅垂线下" if absf(row.offset)<0.01 else "偏%s %.2f m" % ["右" if row.offset>0 else "左",absf(row.offset)]
		_text(x,112,"箱心　x %.2f m　%s" % [row.box_x,offset],18,MINT)
		_text(x,140,"小车对地%s" % _velocity(row.cart_vx),15)
		_text(x,165,"箱心对地%s" % _velocity(row.box_vx),15)
		_text(x,190,"箱心相对小车%s" % _velocity(row.relative),15,SOFT)

func _scrub_position(local_pos: Vector2) -> void:
	var at := (local_pos-_origin)/maxf(_pixel_scale,0.001)
	if _drag_whole:
		_choose(lerpf(_start,_end,clampf((at.x-SHIFT_BAR.position.x)/SHIFT_BAR.size.x,0,1)))
	else:
		_choose(lerpf(_plot_start,_plot_end,clampf((at.x-GRAPH.position.x)/GRAPH.size.x,0,1)),false)

func _gui_input(event: InputEvent) -> void:
	if recording == null or recording.samples.is_empty(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = (event.position-_origin)/maxf(_pixel_scale,0.001)
		if event.pressed and (GRAPH.grow(9).has_point(at) or SHIFT_BAR.grow(8).has_point(at)):
			grab_focus()
			_dragging = true
			_drag_whole = SHIFT_BAR.grow(8).has_point(at)
			_scrub_position(event.position)
			accept_event()
		elif not event.pressed and _dragging:
			_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_scrub_position(event.position)
		accept_event()
	elif has_focus() and (event.is_action_pressed("ui_left",true) or event.is_action_pressed("ui_right",true)):
		var direction := -1.0 if event.is_action_pressed("ui_left",true) else 1.0
		_choose(selected_time+direction*maxf(0.1,(_end-_start)/180.0))
		accept_event()
	elif has_focus() and event.is_action_pressed("ui_accept"):
		var neighbor := find_valid_focus_neighbor(SIDE_RIGHT)
		if neighbor != null and neighbor != self: neighbor.grab_focus()
		accept_event()
