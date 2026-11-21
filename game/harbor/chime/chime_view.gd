extends Control

signal board_picked(index: int)
signal note_picked(index: int)
signal score_picked(old: bool)

const Instrument := preload("res://harbor/chime/chime_physics.gd")
const W := 820.0
const H := 455.0
const BOARDS := [150.0, 279.0, 410.0, 541.0, 670.0]
const NOTES := [147.0, 278.0, 410.0, 542.0, 674.0]
const GOLD := Color("#f5ca81")
const JADE := Color("#92debb")
const ROSE := Color("#f2a09c")
const IVORY := Color("#f4e8c8")

var lab: Instrument
var view_time := 0.0
var u := PackedFloat64Array([0,0,0,0,0])
var recorded: Dictionary = {}
var selected_board := -1
var staged_load := -1
var note := 0
var ferry := 0.0
var moored := false
var second := false
var bell_flash := 0.0
var horn_flash := 0.0
var tap_flash := 0.0
var tap_board := -1
var tuning_live := true
var show_scores := false
var before: Dictionary = {}
var now: Dictionary = {}
var lens: Dictionary = {}
var reading_old := false
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _scale() -> float:
	return maxf(0.001,minf(size.x/W, size.y/H))


func _origin() -> Vector2:
	return (size - Vector2(W,H)*_scale())*0.5


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var point: Vector2 = (event.position - _origin())/_scale()
	if show_scores and point.y>=7 and point.y<=77:
		var first := point.x>=14 and point.x<=394
		var last := point.x>=426 and point.x<=806 and not before.is_empty()
		if first or last:
			score_picked.emit(first and not before.is_empty())
			accept_event()
			return
	if tuning_live and point.y >= 364.0 and point.y <= 443.0:
		for i in range(5):
			if absf(point.x - NOTES[i]) < 56.0:
				note_picked.emit(i)
				accept_event()
				return
	if point.y >= 203 and point.y <= 341:
		for i in range(5):
			if absf(point.x - BOARDS[i]) <= 46:
				board_picked.emit(i)
				accept_event()
				return


func _poly(points: PackedVector2Array, col: Color) -> void:
	draw_colored_polygon(points, col)


func _ink(x: float, y: float, text: String, col: Color, px: int = 15, span: float = 150.0) -> void:
	draw_string(_font, Vector2(x-span/2,y), text, HORIZONTAL_ALIGNMENT_CENTER, span, px, col)


func _line(a: Vector2, b: Vector2, colour: Color, thickness: float = 1.5) -> void:
	draw_line(a, b, colour, thickness, true)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("#193741"))
	if lab == null or _font == null: return
	draw_set_transform(_origin(), 0.0, Vector2.ONE*_scale())
	_harbour()
	if show_scores and not now.is_empty(): _scores()
	_instrument()
	if lens.is_empty(): _comb()
	else: _force_strip()


func _scores() -> void:
	var extent := 6.0
	for item in [before,now]:
		if item.is_empty(): continue
		for value in item.side_cm:
			extent = maxf(extent,absf(value))
	if before.is_empty():
		_score(14,now,"这次",extent,not lens.is_empty())
	else:
		_score(14,before,"上次",extent,not lens.is_empty() and reading_old)
		_score(426,now,"这次",extent,not lens.is_empty() and not reading_old)
	var caption := "稳态侧影取在一号板最高的一刻　·　数值取整拍峰值"
	draw_rect(Rect2(225,77,370,19),Color("#19323bcb"))
	_ink(410,92,caption,Color("#ced8c5"),13,365)


func _score(x: float, take: Dictionary, label: String, extent: float, selected: bool) -> void:
	var edge := GOLD if selected else Color("#84968a")
	draw_rect(Rect2(x,7,380,67),Color("#18313cf0"))
	draw_rect(Rect2(x,7,380,67),edge,false,1.2)
	_ink(x+89,27,"%s　%.3f Hz" % [label,take.hz],IVORY,15,159)
	var y := 48.0
	var line := PackedVector2Array([Vector2(x+21,y)])
	for j in range(5):
		line.append(Vector2(x+42+j*23,y-13.0*float(take.side_cm[j])/extent))
	line.append(Vector2(x+155,y))
	_line(Vector2(x+18,y),Vector2(x+157,y),Color("#7d9390"),1.0)
	draw_polyline(line,Color("#d1c597"),1.6,true)
	for j in range(5):
		var dot := IVORY
		if j==2: dot=ROSE
		if j==3: dot=JADE
		draw_circle(line[j+1],2.6,dot)
		_ink(line[j+1].x,70,str(j+1),dot,10,14)
	_ink(x+268,33,"三号峰值　%.2f cm" % float(take.peaks[2]),ROSE,16,197)
	_ink(x+268,57,"四号峰值　%.2f cm" % float(take.peaks[3]),JADE,16,197)


func _harbour() -> void:
	var sky_top := Color("#122536")
	var mist := Color("#678d92")
	for i in range(36):
		draw_rect(Rect2(0, i*5, W, 5.5), sky_top.lerp(mist, pow(float(i)/35.0,1.25)))
	for i in range(32):
		var x := fmod(i*83.7+31.0,W)
		var y := fmod(i*43.2+14.0,91.0)
		draw_circle(Vector2(x,y), 0.7 + fmod(i*.6,1), Color("#e9dfb8a0"))
	draw_circle(Vector2(132,48),21,Color("#dfc59b"))
	draw_circle(Vector2(141,40),20,Color("#253c4b"))
	var cloud := Color("#69858c65")
	for i in range(6):
		var x := fmod(174*i + view_time*(1.2+i*.13), W+120.0)-90.0
		var y := 63.0+fmod(i*17.0,58.0)
		_poly(PackedVector2Array([Vector2(x,y),Vector2(x+25,y-3),Vector2(x+73,y-4),Vector2(x+113,y),Vector2(x+59,y+3)]), cloud)
	_poly(PackedVector2Array([Vector2(0,117),Vector2(52,103),Vector2(101,114),Vector2(175,88),Vector2(231,106),Vector2(280,94),Vector2(344,115),Vector2(397,104),Vector2(465,121),Vector2(531,98),Vector2(581,109),Vector2(628,91),Vector2(697,117),Vector2(779,94),Vector2(W,107),Vector2(W,162),Vector2(0,162)]),Color("#425b63"))
	for i in range(18):
		var x := i*47.0-15.0
		var top_y := 123.0-fmod(i*19.0,15.0)
		draw_rect(Rect2(x,top_y,32,40),Color("#344f58"))
		_poly(PackedVector2Array([Vector2(x-4,top_y),Vector2(x+13,top_y-8),Vector2(x+36,top_y)]),Color("#2d4652"))
		for j in range(2):
			draw_rect(Rect2(x+6+j*13,top_y+5,4,4),Color("#ddc18c"))
	draw_rect(Rect2(0,136,W,75),Color("#315763"))
	for i in range(32):
		var x := fmod(i*117.0 + view_time*5.0,W+40)-16.0
		var y := 140.0+fmod(i*17.4,53.0)
		_line(Vector2(x,y),Vector2(x+11+fmod(i*3.1,29.0),y),Color("#83b0afa2"),1.1)
	var l := Vector2(714,135)
	_poly(PackedVector2Array([l+Vector2(-12,0),l+Vector2(-7,-50),l+Vector2(6,-50),l+Vector2(13,0)]),Color("#dbb58f"))
	draw_rect(Rect2(705,96,18,6), Color("#a25e49"))
	draw_rect(Rect2(705,81,18,7),Color("#86765f"))
	draw_rect(Rect2(708,72,12,9),GOLD)
	_poly(PackedVector2Array([Vector2(701,73),Vector2(714,65),Vector2(727,73)]),Color("#773e36"))
	_poly(PackedVector2Array([Vector2(709,76),Vector2(595,83),Vector2(602,100)]),Color("#f4da9730"))
	_line(Vector2(634,155),Vector2(801,155),Color("#392f29"),6)
	for j in range(7):
		var x := 644+j*24.0
		_line(Vector2(x,153),Vector2(x,177),Color("#4f3e32"),4)
	for x in [640.0,789.0]:
		_line(Vector2(x,152),Vector2(x,130),Color("#514b41"),2.5)
		draw_circle(Vector2(x,129),4,Color("#ffc47a") if moored or ferry>.96 else Color("#b5ab84"))
	_line(Vector2(640,134),Vector2(715,140),Color("#a69f81"),1)
	_line(Vector2(715,140),Vector2(789,134),Color("#a69f81"),1)
	for j in range(7):
		var x := 656.0+j*19
		var y := 140.0-absf(x-715.0)*.08
		var gust := 1.6*sin(view_time*2.0+j)
		_poly(PackedVector2Array([Vector2(x,y),Vector2(x+6,y+.4),Vector2(x+3+gust,y+5)]),Color("#d89972") if j%2==0 else Color("#91b7a5"))
	if moored:
		_boat(Vector2(658,150),.65,false)
	var f := smoothstep(0.0,1.0,ferry)
	var at := Vector2(153.0 + 435.0*f, 146.0 + 16.0*f + sin(view_time*2.1)*1.4)
	_boat(at, .69+.23*f, second)
	if not recorded.is_empty():
		draw_rect(Rect2(12,12,433,34), Color("#132f39ed"))
		_ink(220,35,"取出的自由振型　%d 阶　%.3f Hz" % [recorded.mode,recorded.hz],IVORY,17,410)


func _boat(pos: Vector2, z: float, painted: bool) -> void:
	var hull := Color("#893f39") if painted else Color("#3a4e59")
	var sail := Color("#c56a52") if painted else Color("#dac49b")
	var shape := PackedVector2Array()
	for p in [Vector2(-55,-2),Vector2(46,-3),Vector2(60,-10),Vector2(48,6),Vector2(32,11),Vector2(-37,11)]:
		shape.append(pos+p*z)
	_poly(shape, hull)
	_line(pos+Vector2(-47,2)*z,pos+Vector2(48,2)*z,GOLD,2.2*z)
	draw_rect(Rect2(pos+Vector2(-28,-14)*z,Vector2(64,12)*z), Color("#694e40"))
	for i in range(4):
		draw_rect(Rect2(pos+Vector2(-22+i*14,-11)*z,Vector2(7,6)*z),Color("#f4c478"))
	_line(pos+Vector2(-7,-5)*z,pos+Vector2(-7,-58)*z,Color("#493d35"),2.8*z)
	var panel := PackedVector2Array()
	for p in [Vector2(-10,-53),Vector2(-30,-36),Vector2(-40,-18),Vector2(-9,-22)]:
		panel.append(pos+p*z)
	_poly(panel,sail)
	for j in range(3):
		_line(pos+Vector2(-14-j*7,-46+j*10)*z,pos+Vector2(-10,-47+j*10)*z,Color("#977c61"),1.2*z)
	var foresail := Color("#dfa38a") if painted else Color("#e1d4ad")
	_poly(PackedVector2Array([pos+Vector2(-5,-51)*z,pos+Vector2(26,-24)*z,pos+Vector2(-4,-20)*z]),foresail)
	draw_circle(pos+Vector2(41,-11)*z,3.7*z,GOLD)
	_line(pos+Vector2(-52,15)*z,pos+Vector2(46,15)*z,Color("#d0bb914f"),2*z)


func _spring(a: Vector2, b: Vector2, tint: Color = Color("#d0b67c")) -> void:
	var points := PackedVector2Array([a])
	var lag := (b-a).normalized().orthogonal()
	for j in range(1,13):
		var shift := 2.8 if j % 2 == 1 else -2.8
		points.append(a.lerp(b, float(j)/13.0)+lag*shift)
	points.append(b)
	draw_polyline(points,tint,2.1,true)


func _arrow(at: Vector2, length: float, col: Color) -> void:
	if absf(length) < 2.0:
		draw_circle(at,2.5,col)
		return
	var end := at+Vector2(0,-length)
	_line(at,end,col,2.2)
	var tail := 5.0*signf(length)
	_poly(PackedVector2Array([end, end+Vector2(-3.6,tail),end+Vector2(3.6,tail)]),col)


func _bellows(board_y: float) -> void:
	var nose := 65.0 + (4.4*cos(lab.phase) if lab.driving else -3.0)
	var leather := Color("#9a6e58")
	_poly(PackedVector2Array([Vector2(25,232),Vector2(nose,238),Vector2(nose,247),Vector2(25,252)]),leather)
	for j in range(1,6):
		var f := float(j)/6
		var x := lerpf(26.0,nose,f)
		_line(Vector2(x,lerpf(233,238,f)),Vector2(x-2,lerpf(250,246,f)),Color("#d19971"),1.4)
	draw_rect(Rect2(21,230,6,24),Color("#ac8959"))
	draw_rect(Rect2(nose,237,5,12),Color("#d6ac73"))
	_line(Vector2(nose+5,243),Vector2(88,239),Color("#d4b582"),2.4)
	_line(Vector2(88,239),Vector2(119,board_y-4),Color("#b49f7b"),2.2)
	draw_circle(Vector2(88,239),3.7,Color("#604c39"))
	draw_circle(Vector2(88,239),1.9,GOLD)


func _instrument() -> void:
	draw_rect(Rect2(0,182,W,176),Color("#233a3c"))
	for i in range(6):
		draw_rect(Rect2(0,187+i*32,W,2),Color("#304748"))
	draw_rect(Rect2(0,186,W,8),Color("#826144"))
	_line(Vector2(0,186),Vector2(W,186),Color("#b99260"),2)
	for i in range(8):
		var x := 12.0+i*112
		draw_circle(Vector2(x,190),1.8,Color("#38342b"))
	var base := 278.0
	draw_dashed_line(Vector2(63,base),Vector2(756,base),Color("#7faaa36e"),1.0,5.0,true)
	var max_displacement := .18
	for value in u: max_displacement = maxf(max_displacement,absf(value))
	var px_per_m := 45.0/max_displacement
	var lift := PackedFloat64Array()
	var previous := Vector2(51,base)
	for i in range(5):
		var pos := Vector2(BOARDS[i],base-u[i]*px_per_m)
		lift.append(pos.y)
		var tint := Color("#d0b67c")
		if not lens.is_empty() and i==2: tint=GOLD
		if not lens.is_empty() and i==3: tint=JADE
		_spring(previous,pos-Vector2(37,0),tint)
		previous=pos+Vector2(37,0)
	_spring(previous,Vector2(769,base))
	if recorded.is_empty() and lens.is_empty():
		_bellows(lift[0])
	for x in [44,776]:
		draw_rect(Rect2(x-5,244,10,56),Color("#a77c50"))
		_line(Vector2(x-5,245),Vector2(x+5,245),GOLD,2.0)
	var arrow_gain := 0.0
	if not recorded.is_empty():
		for v in recorded.ku: arrow_gain=maxf(arrow_gain,absf(v))
	for i in range(5):
		var x := float(BOARDS[i])
		var y := float(lift[i])
		var g := Color("#cba46a") if i%2==0 else Color("#b88d5c")
		if tap_flash>0 and tap_board==i: g=g.lerp(IVORY,0.45*tap_flash)
		_poly(PackedVector2Array([Vector2(x-39,y-4),Vector2(x-30,y-13),Vector2(x+32,y-13),Vector2(x+39,y-5),Vector2(x+39,y+5),Vector2(x-39,y+5)]),g)
		draw_rect(Rect2(x-39,y+4,78,9),Color("#795437"))
		_line(Vector2(x-34,y-8),Vector2(x+31,y-9),Color("#e6c48a"),1.6)
		_line(Vector2(x-18,y+7),Vector2(x+26,y+7),Color("#a88154"),1.1)
		for bolt in [-31,31]: draw_circle(Vector2(x+bolt,y),2.2,Color("#5c4c38"))
		if not recorded.is_empty():
			_arrow(Vector2(x-19,base),u[i]*px_per_m,GOLD)
			var scale_f := 39.0/maxf(.0001,arrow_gain)
			_arrow(Vector2(x+15,base),-float(recorded.ku[i])*scale_f,JADE)
			_arrow(Vector2(x+26,base),-float(recorded.inertia[i])*scale_f,ROSE)
		elif not lens.is_empty():
			if i==2:
				var scale_f := 37.0/maxf(.01,maxf(absf(lens.left),absf(lens.right)))
				_arrow(Vector2(x-18,y),float(lens.left)*scale_f,GOLD)
				_arrow(Vector2(x+18,y),float(lens.right)*scale_f,JADE)
			elif i==1 or i==3:
				_arrow(Vector2(x-18,base),u[i]*px_per_m,IVORY)
		if lab.loaded==i or staged_load==i:
			var solid := lab.loaded==i
			var c := Color("#d8af7a") if solid else Color("#9eafb2")
			var h_y := y-15 if solid else y-27.0
			draw_rect(Rect2(x-11,h_y-10,22,10),c,solid,-1 if solid else 2)
			draw_arc(Vector2(x,h_y-9),5.5,PI,TAU,13,c,2,true)
		var label_col := IVORY
		if i == 2: label_col=ROSE
		if i == 3: label_col=JADE
		var plate_name := ["一","二","三 · 雾哨","四 · 港钟","五"][i] as String
		_ink(x,337,plate_name,label_col,16,110)
		if selected_board == i:
			_line(Vector2(x-27,344),Vector2(x+27,344),GOLD,2.4)
	_bell(Vector2(541,211),bell_flash)
	_horn(Vector2(410,211),horn_flash)
	if not lens.is_empty():
		_ink(145,215,"白箭头　琴板离开中线的方向",IVORY,14,240)
	elif recorded.is_empty():
		_ink(130,215,"左端风箱驱动",Color("#b8c5b2"),14,155)
	else:
		_ink(100,213,"金  位移 u",GOLD,14,120)
		_ink(210,213,"绿  回复力 −Ku",JADE,14,142)
		_ink(330,213,"粉  质量 × 加速度",ROSE,13,145)


func _bell(p: Vector2, flash: float) -> void:
	_line(p-Vector2(0,14),p-Vector2(0,6),Color("#9d886a"),2)
	var at := p+Vector2(sin(view_time*19)*flash*4,0)
	_poly(PackedVector2Array([at+Vector2(-3,-7),at+Vector2(3,-7),at+Vector2(6,-4),at+Vector2(7,4),at+Vector2(11,8),at+Vector2(-11,8),at+Vector2(-7,4),at+Vector2(-6,-4)]),GOLD.lerp(IVORY,flash*.6))
	draw_circle(at+Vector2(0,9),2.7,GOLD)
	if flash>.03: draw_arc(at,15.0+12.0*(1-flash),-.95,.95,18,Color(JADE,flash),2,true)


func _horn(p: Vector2, flash: float) -> void:
	var at := p+Vector2(0,sin(view_time*17)*flash*2)
	_line(at+Vector2(-12,5),at+Vector2(-2,5),Color("#cb9c6f"),3)
	_poly(PackedVector2Array([at+Vector2(-2,2),at+Vector2(11,-4),at+Vector2(11,8),at+Vector2(-2,7)]),ROSE)
	if flash>.03: draw_arc(at+Vector2(6,1),12.0+14.0*(1-flash),-.75,.75,16,Color(ROSE,flash),2,true)


func _force_strip() -> void:
	draw_rect(Rect2(0,355,W,100),Color("#363e38"))
	draw_rect(Rect2(0,355,W,5),Color("#aa8155"))
	_ink(410,383,"拆出第 %d 种摆法　·　定格在这一种摆法的峰值" % int(lens.primary.mode),IVORY,16,540)
	var total := float(lens.left)+float(lens.right)
	_force_label(146,"左簧",lens.left,GOLD)
	_force_label(410,"右簧",lens.right,JADE)
	_force_label(672,"三板合力",total,IVORY)
	_ink(410,448,"金、绿两箭头是同一时刻作用在三号板上的力",Color("#c6cabb"),14,530)


func _force_label(x: float, label: String, value: float, tint: Color) -> void:
	var orientation := "向上" if value>0 else "向下"
	if absf(value)<.0001:
		value=0
		orientation="抵消"
	var length := 19.0*signf(value)
	_arrow(Vector2(x-88,412.0+length*.5),length,tint)
	_ink(x+13,421,"%s%s　%.2f N" % [label,orientation,absf(value)],tint,17,191)


func _comb() -> void:
	draw_rect(Rect2(0,355,W,100),Color("#3b3d36"))
	draw_rect(Rect2(0,355,W,5),Color("#aa8155"))
	for i in range(5):
		var x := float(NOTES[i])
		var col := Color("#c1945f") if i==note else Color("#79664b")
		_poly(PackedVector2Array([Vector2(x-48,383),Vector2(x-38,376),Vector2(x+40,376),Vector2(x+49,384),Vector2(x+45,422),Vector2(x-45,422)]),col)
		_poly(PackedVector2Array([Vector2(x-45,422),Vector2(x+45,422),Vector2(x+42,428),Vector2(x-43,428)]),Color("#504637"))
		var shape: PackedFloat64Array=lab.shapes[i]
		var poly := PackedVector2Array()
		var m := 0.001
		for v in shape: m=maxf(m,absf(v))
		for j in range(7):
			var v := float(shape[j-1])/m if j>0 and j<6 else 0.0
			poly.append(Vector2(x-33+j*11.0,390-v*7.0))
		_line(Vector2(x-35,390),Vector2(x+35,390),Color("#7c704f"),1)
		draw_polyline(poly, Color("#233c3b"),1.8,true)
		for j in range(1,6):
			var dot := Color("#243f3c")
			if j==3: dot = Color("#ecab8b")
			if j==4: dot = Color("#bddbb0")
			draw_circle(poly[j],1.9,dot)
		_ink(x,415,"%.2f Hz" % float(lab.frequencies[i]),IVORY,15,88)
		if i==note:
			_poly(PackedVector2Array([Vector2(x-5,432),Vector2(x+5,432),Vector2(x,427)]),GOLD)
	_ink(410,449,"铜音栓  ·  曲线刻着五块板的自由振型",Color("#cfceb2"),14,565)
