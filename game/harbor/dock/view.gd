extends Control

const Rig := preload("res://harbor/dock/rig.gd")
const PAGE := Vector2(820,480)
const NEAR := Color("#ff9b72")
const FAR := Color("#92ddc7")
const GOLD := Color("#ffdb9d")
const PAPER := Color("#e8ede0")
const INK := Color("#253e44")
const SOFT := Color("#adc5bf")
const MAG := 155.0
var station
var face: Font

func _ready() -> void:
	face = get_theme_default_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void: station.let_go())

func _text(at: Vector2, label: String, px: int = 15, color: Color = PAPER) -> void:
	draw_string(face,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,px,color)

func _poly(points: Array, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),tint)

func _rope(a: Vector2,b: Vector2) -> void:
	draw_line(a+Vector2(1.5,1.5),b+Vector2(1.5,1.5),Color("#416566"),3,true)
	draw_line(a,b,Color("#ddcf9e"),2,true)

func _lantern(at: Vector2, lit: bool) -> void:
	var glass := GOLD if lit else Color("#8fa197")
	if lit:
		draw_circle(at,9,Color("#ffca6e22"),true,-1,true)
	draw_rect(Rect2(at-Vector2(3,4),Vector2(6,8)), glass)
	draw_line(at+Vector2(-4,-4),at+Vector2(4,-4),INK,2)
	draw_line(at+Vector2(-4,4),at+Vector2(4,4),INK,2)

func _water() -> void:
	for row in 14:
		draw_rect(Rect2(0,37+row*15,820,16),Color("#668f99").lerp(Color("#d4b69b"),row/13.0))
	draw_circle(Vector2(694,108),20,Color("#f6d8a2"),true,-1,true)
	draw_circle(Vector2(694,108),28,Color("#f8daaa1e"),true,-1,true)
	_poly([Vector2(0,177),Vector2(35,165),Vector2(91,171),Vector2(150,160),Vector2(199,175),Vector2(271,163),Vector2(336,172),Vector2(411,158),Vector2(478,174),Vector2(552,168),Vector2(603,157),Vector2(674,165),Vector2(718,153),Vector2(761,146),Vector2(820,154),Vector2(820,204),Vector2(0,204)],Color("#739596"))
	draw_rect(Rect2(0,183,820,97),Color("#497980"))
	for i in 55:
		var x := fmod(i*89.0,820)
		var y := 189.0+fmod(i*41.0,88)
		draw_line(Vector2(x,y),Vector2(x+7+i%5*5,y),Color("#a2c3b72c"),1.6,true)
	for i in 12:
		var x := 651.0+fmod(i*19,84)
		var y := 191.0+i*4
		draw_line(Vector2(x,y),Vector2(x+8+i%3*4,y),Color("#e9c49d72"),1.6)
	for i in 9:
		var bx := 609+i*14.5
		var by := 176.0-sin(i*.63)*3
		var h := 8+i%3*3
		draw_rect(Rect2(bx,by-h,10,h),Color("#58777b"))
		_poly([Vector2(bx-2,by-h),Vector2(bx+4,by-h-5),Vector2(bx+12,by-h)],Color("#5c777b"))
		draw_line(Vector2(bx+4,by-5),Vector2(bx+4,by-3),Color("#dac192"),2)
	for at: Vector2 in [Vector2(513,112),Vector2(527,105),Vector2(557,117)]:
		draw_arc(at+Vector2(-3,0),3.5,PI,TAU,8,Color("#507679"),1.2,true)
		draw_arc(at+Vector2(4,0),3.5,PI,TAU,8,Color("#507679"),1.2,true)

func _gantry() -> void:
	_poly([Vector2(38,279),Vector2(47,87),Vector2(65,78),Vector2(64,279)],Color("#394e51"))
	_poly([Vector2(77,268),Vector2(67,91),Vector2(78,78),Vector2(95,268)],Color("#52615a"))
	draw_line(Vector2(63,167),Vector2(142,64),Color("#54625c"),11,true)
	draw_line(Vector2(63,169),Vector2(142,65),Color("#af946e"),2,true)
	_poly([Vector2(27,74),Vector2(56,58),Vector2(640,58),Vector2(653,65),Vector2(642,78),Vector2(37,83)],Color("#714e42"))
	_poly([Vector2(34,72),Vector2(58,58),Vector2(640,58),Vector2(641,64),Vector2(56,73)],Color("#b18b65"))
	draw_line(Vector2(43,80),Vector2(642,73),Color("#cfa675"),2,true)
	for x in [90,123,232,270,485,522,605]:
		draw_line(Vector2(x,62),Vector2(x+1,76),Color("#4a5050"),3)
		draw_circle(Vector2(x+1,68),1.7,GOLD,true,-1,true)
	for x in [25,64,104,147]:
		draw_line(Vector2(x,245),Vector2(x+1,278),Color("#3e5556"),6,true)
	draw_line(Vector2(0,244),Vector2(160,244),Color("#4f534e"),12)
	draw_line(Vector2(0,238),Vector2(163,238),Color("#c19f76"),3)
	_lantern(Vector2(113,98),true)
	draw_line(Vector2(113,76),Vector2(113,92),INK,1.4)

func _basket(far: bool, displacement: float) -> Vector2:
	var centre := 505.0 if far else 234.0
	var down := 126.0*sqrt(maxf(0.2,1.0-pow(displacement/Rig.LENGTH,2)))
	return Vector2(centre+displacement*MAG,74+down)

func _tackle(far: bool,pos: Vector2) -> void:
	var x := 505.0 if far else 234.0
	var pigment := FAR if far else NEAR
	for side in [-1.0,1.0]:
		var source := Vector2(x+side*7,74)
		_rope(source,pos+Vector2(side*27,-4))
		draw_circle(source,5,INK,true,-1,true)
		draw_circle(source,2.5,GOLD,true,-1,true)
	_poly([pos+Vector2(-31,-5),pos+Vector2(31,-5),pos+Vector2(24,14),pos+Vector2(-22,14)],Color("#635447"))
	_poly([pos+Vector2(-28,-4),pos+Vector2(27,-4),pos+Vector2(21,9),pos+Vector2(-20,9)],pigment.darkened(.18))
	for i in 6:
		draw_line(pos+Vector2(-23+i*9,-3),pos+Vector2(-20+i*8,10),Color("#7d7860"),1.5)
	draw_line(pos+Vector2(-29,0),pos+Vector2(30,0),pigment,3,true)
	draw_line(pos+Vector2(-32,-5),pos+Vector2(32,-5),Color("#f1deb0"),3,true)

func _bag(at: Vector2) -> void:
	_poly([at+Vector2(-5,-7),at+Vector2(3,-7),at+Vector2(8,0),at+Vector2(6,6),at+Vector2(-7,6),at+Vector2(-8,1)],Color("#c58958"))
	draw_line(at+Vector2(-5,-5),at+Vector2(4,-5),Color("#f4d9a0"),2)
	draw_rect(Rect2(at-Vector2(3,1),Vector2(7,5)),PAPER)
	draw_line(at+Vector2(-3,-1),at+Vector2(.5,1),Color("#b56b57"),1)
	draw_line(at+Vector2(.5,1),at+Vector2(4,-1),Color("#b56b57"),1)

func _spring(a: Vector2,b: Vector2) -> void:
	var left := a+Vector2(28,-11)
	var right := b+Vector2(-28,-11)
	if station.spring==0:
		draw_dashed_line(left,left.lerp(right,.30),Color("#a0a99b"),2,4,true)
		draw_dashed_line(left.lerp(right,.71),right,Color("#a0a99b"),2,4,true)
		return
	var points := PackedVector2Array([left])
	var teeth := 20 if station.spring==40 else 13
	for i in range(1,teeth*2):
		var t := float(i)/(teeth*2)
		var p := left.lerp(right,t)
		points.append(p+Vector2(0,3.9 if i%2 else -3.9))
	points.append(right)
	draw_polyline(points,Color("#4e5d58"),3.5,true)
	draw_polyline(points,Color("#d4d09e"),1.5,true)

func _boat() -> void:
	if station.phase in ["bench","plan"]:
		_poly([Vector2(694,199),Vector2(738,199),Vector2(733,204),Vector2(700,204)],Color("#557273"))
		draw_rect(Rect2(714,193,12,6),Color("#8e9d8c"))
		draw_line(Vector2(706,199),Vector2(706,182),Color("#647d7a"),1.1)
		draw_line(Vector2(706,183),Vector2(697,193),Color("#8da096"),1.1)
		draw_circle(Vector2(724,195),1.5,GOLD,true,-1,true)
		return
	var pickup := 505.0 + Rig.REACH*MAG
	var fraction := smoothstep(0.0,Rig.DOCK_TIME,station.run_time)
	var x := pickup+69+(1.0-fraction)*251
	var y := 242.0
	_poly([Vector2(x-60,y),Vector2(x+66,y),Vector2(x+49,y+17),Vector2(x-38,y+18)],Color("#364c52"))
	_poly([Vector2(x-62,y),Vector2(x+66,y),Vector2(x+58,y+6),Vector2(x-53,y+7)],Color("#bf7960"))
	draw_line(Vector2(x-61,y),Vector2(x+67,y),Color("#f0d6a5"),2)
	draw_rect(Rect2(x+9,y-17,29,17),Color("#b1c4ae"))
	draw_rect(Rect2(x+13,y-13,7,7),Color("#41686b"))
	draw_rect(Rect2(x+25,y-13,7,7),Color("#41686b"))
	_lantern(Vector2(x+39,y-16),station.hooked)
	draw_line(Vector2(x-9,y-2),Vector2(x-9,175),INK,3,true)
	draw_line(Vector2(x-9,176),Vector2(x-69,193),INK,3,true)
	draw_line(Vector2(x-9,183),Vector2(x-67,192),Color("#ead4a6"),1.2,true)
	var hook_y := lerpf(193.0,207.0,smoothstep(Rig.DOCK_TIME-Rig.HOOK_WINDOW-.28,Rig.DOCK_TIME-Rig.HOOK_WINDOW,station.run_time))
	draw_line(Vector2(x-69,192),Vector2(x-69,hook_y),GOLD,2.3,true)
	draw_arc(Vector2(x-72,hook_y-1),3.0,0,PI,10,GOLD,2,true)
	if station.hooked:
		_bag(Vector2(x-35,y-8))
	if station.phase=="voyage" and fraction<.99:
		draw_line(Vector2(x+55,y+17),Vector2(x+88,y+18),Color("#b7d1c7"),2,true)

func _energy() -> void:
	var e: Vector2 = station.rig.energy(station.state)
	var all := maxf(e.x+e.y,.00001)
	draw_rect(Rect2(0,278,820,38),Color("#244650"))
	_text(Vector2(14,303),"摆动能量",15,PAPER)
	draw_rect(Rect2(121,292,239*e.x/all,6),NEAR)
	draw_rect(Rect2(121+239*e.x/all,292,239*e.y/all,6),FAR)
	_text(Vector2(377,302),"近篮 %.1f J" % e.x,14,NEAR)
	_text(Vector2(493,302),"远篮 %.1f J" % e.y,14,FAR)
	_text(Vector2(643,302),"横向位移放大约 3 倍",12,SOFT)

func _traces() -> void:
	draw_rect(Rect2(0,316,820,164),Color("#193640"))
	_text(Vector2(14,341),"篮心位移",16,PAPER)
	draw_line(Vector2(168,335),Vector2(189,335),NEAR,2.1)
	_text(Vector2(197,340),"近篮",14,NEAR)
	draw_line(Vector2(263,335),Vector2(284,335),FAR,2.1)
	_text(Vector2(292,340),"远篮",14,FAR)
	_text(Vector2(590,340),"向右为正 · 刻度按放手计时",13,SOFT)
	var plot := Rect2(43,355,751,86)
	var last: float = station.bench_time if station.phase in ["bench","plan"] else maxf(0,station.run_time-(Rig.DOCK_TIME-station.lead))
	var end_t := maxf(18.0,last)
	var begin_t := end_t-18.0
	var limit := .42
	for p: Vector3 in station.trace:
		if p.x>=begin_t:
			limit=maxf(limit,maxf(absf(p.y),absf(p.z))*1.06)
	var mid := plot.get_center().y
	var pitch := plot.size.y*.49/limit
	draw_line(Vector2(plot.position.x,mid),Vector2(plot.end.x,mid),Color("#49666c"),1)
	_text(Vector2(8,mid+3),"0",12,SOFT)
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for p: Vector3 in station.trace:
		if p.x<begin_t:
			continue
		var x := plot.position.x+(p.x-begin_t)*plot.size.x/18
		a.append(Vector2(x,mid-p.y*pitch))
		b.append(Vector2(x,mid-p.z*pitch))
	if a.size()>1:
		draw_polyline(a,NEAR,2,true)
		draw_polyline(b,FAR,2.3,true)
		draw_circle(b[-1],3,FAR,true,-1,true)
	if station.phase in ["bench","plan"]:
		for t: float in station.stamps:
			if t>=begin_t:
				var mark := plot.position.x+(t-begin_t)*plot.size.x/18
				draw_dashed_line(Vector2(mark,plot.position.y),Vector2(mark,plot.end.y),GOLD,1.3,4,true)
	if station.phase in ["voyage","done"] and station.released:
		var s1: float = plot.position.x+(station.lead-Rig.HOOK_WINDOW-begin_t)*plot.size.x/18
		var s2: float = plot.position.x+(station.lead+Rig.HOOK_WINDOW-begin_t)*plot.size.x/18
		draw_rect(Rect2(Vector2(s1,plot.position.y),Vector2(s2-s1,plot.size.y)),Color("#ffc79321"))
	for i in 4:
		var t := begin_t+float(i)*6
		_text(Vector2(plot.position.x+float(i)*plot.size.x/3-4,464),"%.0f s" % t,12,SOFT)

const GUIDE_LEFT := 219.0
const GUIDE_RIGHT := 534.0
const GUIDE_MAG := 230.0

func _guide_basket(far: bool, dx: float) -> Vector2:
	var x := GUIDE_RIGHT if far else GUIDE_LEFT
	return Vector2(x+dx*GUIDE_MAG,72+147*sqrt(maxf(.25,1.0-pow(dx/Rig.LENGTH,2))))

func _guide_tackle(far: bool, p: Vector2) -> void:
	var pivot := GUIDE_RIGHT if far else GUIDE_LEFT
	var color := FAR if far else NEAR
	for sign_x in [-1.0,1.0]:
		var anchor := Vector2(pivot+8*sign_x,73)
		var tie := p+Vector2(38*sign_x,-5)
		draw_line(anchor+Vector2(2,1),tie+Vector2(2,1),Color("#536665"),4.1,true)
		draw_line(anchor,tie,Color("#e8d4aa"),2.4,true)
		draw_circle(anchor,6,INK,true,-1,true)
		draw_circle(anchor,2.8,GOLD,true,-1,true)
	_poly([p+Vector2(-44,-5),p+Vector2(44,-5),p+Vector2(34,20),p+Vector2(-33,20)],Color("#4c4940"))
	_poly([p+Vector2(-40,-5),p+Vector2(40,-5),p+Vector2(32,14),p+Vector2(-30,14)],color.darkened(.17))
	for i in range(7):
		draw_line(p+Vector2(-33+11*i,-4),p+Vector2(-26+9*i,13),color.darkened(.48),2)
	draw_line(p+Vector2(-44,-5),p+Vector2(44,-5),Color("#fae7b9"),4,true)
	draw_line(p+Vector2(-36,10),p+Vector2(36,10),color,3,true)

func _arrow(start: Vector2, signed_length: float, color: Color) -> void:
	if absf(signed_length)<3:
		return
	var direction := signf(signed_length)
	var end := start+Vector2(signed_length,0)
	draw_line(start,end-Vector2(direction*5,0),Color("#29494a"),7,true)
	draw_line(start,end-Vector2(direction*5,0),color,4.2,true)
	_poly([end,end+Vector2(-direction*9,-6),end+Vector2(-direction*9,6)],color)

func _guide_cable(a: Vector2, b: Vector2) -> void:
	if station.spring==0:
		return
	var left := a+Vector2(43,-3)
	var right := b+Vector2(-43,-3)
	var points := PackedVector2Array([left,left+Vector2(9,0)])
	var teeth := 16 if station.spring==40 else 11
	for i in range(1,teeth*2):
		points.append((left+Vector2(9,0)).lerp(right-Vector2(9,0),float(i)/(2*teeth))+Vector2(0,5.7 if i%2 else -5.7))
	points.append(right-Vector2(9,0))
	points.append(right)
	draw_polyline(points,Color("#42524b"),5.4,true)
	draw_polyline(points,Color("#f2cf88"),2.6,true)
	if station.phase=="intro_running" and station.intro_tick>0:
		var force: float = station.rig.spring_force_on_far(station.state)
		var arrow := clampf(force*6.5,-56,56)
		_arrow(a+Vector2(0,-30),-arrow,NEAR)
		_arrow(b+Vector2(0,-30),arrow,GOLD)
		if absf(force)>.6:
			_text(Vector2(321,144),"弹簧推开两篮" if force>0 else "弹簧拉近两篮",16,Color("#244346"))

func _guide_ferry() -> void:
	var sailing: bool = station.guide_job and station.phase in ["voyage","done"]
	var arrival := smoothstep(0.0,Rig.DOCK_TIME,station.run_time) if sailing else 0.0
	var threshold := GUIDE_RIGHT+Rig.REACH*GUIDE_MAG
	var x := threshold+68+(1.0-arrival)*124
	var deck := 272.0
	_poly([Vector2(x-62,deck),Vector2(x+81,deck),Vector2(x+57,deck+20),Vector2(x-39,deck+20)],Color("#314e51"))
	_poly([Vector2(x-64,deck),Vector2(x+81,deck),Vector2(x+70,deck+7),Vector2(x-51,deck+8)],Color("#b97962"))
	draw_line(Vector2(x-62,deck),Vector2(x+81,deck),GOLD,2.6)
	draw_rect(Rect2(x+16,deck-24,35,23),Color("#bbcab5"))
	draw_rect(Rect2(x+22,deck-20,8,7),Color("#446a6c"))
	draw_rect(Rect2(x+35,deck-20,8,7),Color("#446a6c"))
	_lantern(Vector2(x+8,deck-23),station.hooked)
	draw_line(Vector2(x-10,deck),Vector2(x-10,191),INK,3.7,true)
	draw_line(Vector2(x-10,192),Vector2(x-68,210),INK,3.3,true)
	draw_line(Vector2(x-10,200),Vector2(x-68,210),GOLD,1.7,true)
	var hook_y := lerpf(225.0,240.0,smoothstep(Rig.DOCK_TIME-Rig.HOOK_WINDOW-.25,Rig.DOCK_TIME-Rig.HOOK_WINDOW,station.run_time)) if sailing else 224.0
	draw_line(Vector2(x-68,209),Vector2(x-68,hook_y),GOLD,2.6,true)
	draw_arc(Vector2(x-72,hook_y-1),4,0,PI,10,GOLD,2.5,true)
	if station.hooked:
		_bag(Vector2(x-32,deck-9))

func _guide_scene() -> void:
	_water()
	draw_rect(Rect2(0,278,820,48),Color("#497980"))
	for i in 10:
		var x := 15.0+i*83.0
		draw_line(Vector2(x,294+i%3*8),Vector2(x+24,294+i%3*8),Color("#b6d3bc38"),1.5,true)
	draw_line(Vector2(44,292),Vector2(47,65),Color("#4c5c56"),16,true)
	draw_line(Vector2(48,147),Vector2(122,62),Color("#7e775e"),10,true)
	_poly([Vector2(27,62),Vector2(51,49),Vector2(698,49),Vector2(708,57),Vector2(699,70),Vector2(28,75)],Color("#745346"))
	draw_line(Vector2(43,59),Vector2(698,54),Color("#bd996c"),5,true)
	draw_line(Vector2(28,73),Vector2(699,68),Color("#e8c28e"),2,true)
	for x in [71,121,210,228,525,544,668]:
		draw_line(Vector2(x,52),Vector2(x+1,69),INK,3)
	draw_line(Vector2(0,280),Vector2(144,280),Color("#8c785e"),10,true)
	draw_line(Vector2(0,275),Vector2(145,275),GOLD,2)
	for xx in [25,63,109]:
		draw_line(Vector2(xx,284),Vector2(xx+1,325),Color("#475c58"),7)
	var a := _guide_basket(false,station.state.x)
	var b := _guide_basket(true,station.state.y)
	draw_dashed_line(Vector2(GUIDE_RIGHT,102),Vector2(GUIDE_RIGHT,283),Color("#eef0d7aa"),1.8,6,true)
	if station.phase=="intro_result" and station.spring>0:
		var peak_x: float = GUIDE_RIGHT+station.intro_peak_m*GUIDE_MAG
		draw_dashed_line(Vector2(peak_x,143),Vector2(peak_x,264),Color("#c8f3dbaa"),1.5,5,true)
		_poly([Vector2(peak_x-4,150),Vector2(peak_x+4,150),Vector2(peak_x,157)],FAR)
		draw_rect(Rect2(peak_x-48,124,100,23),Color("#3e6668"))
		_text(Vector2(peak_x-42,141),"最远到过这里",13,PAPER)
	var threshold := GUIDE_RIGHT+Rig.REACH*GUIDE_MAG
	if station.guide_job:
		draw_dashed_line(Vector2(threshold,103),Vector2(threshold,279),GOLD,2,6,true)
		_text(Vector2(threshold+7,129),"船钩线",15,Color("#344e4e"))
	_guide_ferry()
	_guide_cable(a,b)
	_guide_tackle(false,a)
	_guide_tackle(true,b)
	if not station.hooked:
		var bag_at := b+Vector2(2,26)
		_poly([bag_at+Vector2(-9,-12),bag_at+Vector2(7,-12),bag_at+Vector2(13,0),bag_at+Vector2(9,11),bag_at+Vector2(-11,11),bag_at+Vector2(-13,-2)],Color("#b37d52"))
		draw_line(bag_at+Vector2(-7,-7),bag_at+Vector2(7,-7),Color("#f4dbac"),2)
		draw_rect(Rect2(bag_at-Vector2(6,2),Vector2(13,8)),PAPER)
		draw_line(bag_at+Vector2(-6,-2),bag_at+Vector2(0,2),Color("#b8624d"),1.3)
		draw_line(bag_at+Vector2(0,2),bag_at+Vector2(7,-2),Color("#b8624d"),1.3)
	draw_rect(Rect2(GUIDE_LEFT-42,81,84,28),Color("#34575a"))
	draw_rect(Rect2(GUIDE_RIGHT-65,81,130,28),Color("#34575a"))
	_text(Vector2(GUIDE_LEFT-26,101),"左篮",19,NEAR)
	_text(Vector2(GUIDE_RIGHT-52,101),"右篮 · 邮袋",19,FAR)
	if not station.guide_job:
		var direction := "中线" if absf(station.state.y)<.0005 else ("右" if station.state.y>0 else "左")
		var where := "此刻在"+direction+(" %.1f cm" % (absf(station.state.y)*100) if direction!="中线" else "")
		if station.phase=="intro_running" and absf(station.state.w)>.025:
			where += "　正向右摆" if station.state.w>0 else "　正向左摆"
		_text(Vector2(GUIDE_RIGHT-52,305),where,15,PAPER)
	elif station.phase=="voyage":
		_text(Vector2(GUIDE_RIGHT-52,305),"已松手" if station.released else "等水手放手",16,GOLD)
	draw_rect(Rect2(0,0,820,38),Color("#173741"))
	var hardware := "两篮之间没有弹簧" if station.spring==0 else ("已接上硬弹簧" if station.spring==40 else "已接上软弹簧")
	_text(Vector2(17,26),hardware,19,PAPER)
	var info := "两篮静止" if station.phase=="intro_ready" else "放手后 %.2f 秒" % (station.intro_tick*station.TICK)
	if station.guide_job and station.phase in ["voyage","done"]:
		info = "距靠岸 %.1f 秒" % maxf(0,Rig.DOCK_TIME-station.run_time)
	_text(Vector2(641,26),info,16,GOLD)

func _comparison_bar(y: float, title: String, available: bool, magnitude: float, color: Color) -> void:
	_text(Vector2(29,y+6),title,18,PAPER if available else SOFT.darkened(.18))
	var begin := Vector2(234,y)
	draw_line(begin, Vector2(641,y),Color("#3e6369"),5,true)
	if available:
		var end := begin+Vector2(407.0*clampf(magnitude/Rig.A,0,1),0)
		draw_line(begin,end,color,5.5,true)
		draw_circle(end,5.5,color,true,-1,true)
		_text(Vector2(664,y+8),"%.1f cm" % (100*magnitude),22,color)
	else:
		_text(Vector2(664,y+6),"待观察",16,SOFT)

func _guide_board() -> void:
	draw_rect(Rect2(0,325,820,155),Color("#193640"))
	if station.guide_job and station.phase in ["voyage","done"]:
		_text(Vector2(24,356),"这班邮船",21,PAPER)
		_text(Vector2(380,355),"约好在抵岸前 %.1f 秒松手" % station.lead,17,GOLD)
		_comparison_bar(397,"船钩够到的位置",true,Rig.REACH,GOLD)
		var measured: bool = is_finite(station.observed_peak)
		_comparison_bar(444,"开钩时最远向右",measured,maxf(0,station.observed_peak) if measured else 0.0,FAR)
		return
	var t: float = station.intro_tick*station.TICK
	_text(Vector2(24,356),"右篮最远向右",23,PAPER)
	_text(Vector2(416,355),"从松手到第 %.2f 秒" % t if station.phase!="intro_ready" else "两遍都观察 13 秒",17,SOFT)
	var previous_key: int = station.intro_previous_key()
	var first_real: bool = station.phase!="intro_ready"
	var second_real: bool = first_real and station.spring!=0
	var first: float = station.intro_previous_peak() if second_real else station.intro_peak_m
	_comparison_bar(397,"接软弹簧" if previous_key==20 else "无弹簧",first_real,first,SOFT)
	_comparison_bar(444,"接硬弹簧" if station.spring==40 else "接软弹簧",second_real,station.intro_peak_m,FAR)

func _draw() -> void:
	if station==null or face==null:
		return
	draw_set_transform(Vector2.ZERO,0,size/PAGE)
	if station.phase.begins_with("intro_") or station.guide_job:
		_guide_scene()
		_guide_board()
		return
	_water()
	_gantry()
	var a := _basket(false,station.state.x)
	var b := _basket(true,station.state.y)
	_spring(a,b)
	_tackle(false,a)
	_tackle(true,b)
	_text(Vector2(178,104),"A · 近篮",15,Color("#334d50"))
	_text(Vector2(450,104),"B · 远篮",15,Color("#334d50"))
	draw_rect(Rect2(0,0,820,38),Color("#173741"))
	_text(Vector2(14,26),"工棚试摆架",19,PAPER)
	_text(Vector2(148,25),"横簧 %d N/m" % station.spring,15,GOLD)
	var label := str(station.MODE_NAMES[station.pattern]) if station.phase in ["bench","plan"] else "单拨近篮 · 提前 %.1f s" % station.lead
	_text(Vector2(450,25),label,14,SOFT)
	var timer := "试摆 %.1f s" % station.bench_time if station.phase in ["bench","plan"] else "抵岸倒计时 %.1f s" % maxf(0,Rig.DOCK_TIME-station.run_time)
	_text(Vector2(651,25),timer,14,PAPER)
	_energy()
	_traces()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index!=MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		station.let_go()
		return
	if station.phase in ["intro_ready","intro_result"]:
		var location: Vector2 = event.position*PAGE/size
		if location.distance_to(_guide_basket(false,station.state.x))<57:
			if station.phase=="intro_ready":
				station.start_intro_run(0,true)
			elif station.spring==0:
				station.start_intro_run(20,true)
			else:
				station.start_intro_run(station.spring,true)
			accept_event()
		return
	if station.phase!="bench":
		return
	var p: Vector2=event.position*PAGE/size
	var a := _basket(false,station.state.x)
	var b := _basket(true,station.state.y)
	if p.distance_to(a)<38:
		station.grab_basket(false)
	elif p.distance_to(b)<38:
		station.grab_basket(true)
	elif absf(p.y-a.y+9)<13 and p.x>a.x+31 and p.x<b.x-31:
		station.change_spring(20 if station.spring==0 else (40 if station.spring==20 else 0))
	accept_event()
