extends Control

const BACKDROP := preload("res://harbor/quay/art/tidewater.svg")
const Rig := preload("res://harbor/quay/crane_rig.gd")
const UNIT := 50.0
const SHIP_EDGE := Rig.SHIP_EDGE_X
const SHORE_EDGE := Rig.SHORE_EDGE_X
const TRUCK_LEFT := Rig.TRUCK_LEFT_X
const TRUCK_RIGHT := Rig.TRUCK_RIGHT_X
const SHIP_BAY := Rig.SHIP_BAY_X
const TRUCK_BAY := Rig.TRUCK_BAY_X
const SHIP_DECK := Rig.SHIP_TOP_Y
const SHORE_DECK := Rig.SHORE_TOP_Y
const TRUCK_DECK := Rig.TRUCK_TOP_Y
const RAIL := Rig.RAIL_Y
const LOAD_W := Rig.BOX_WIDTH
const LOAD_H := Rig.BOX_HEIGHT
const BAY_W := Rig.BAY_WIDTH

var rig
var _clock := 0.0
var _handoff := -1.0
var _impact_age := 9.0
var _impact_strength := 0.0
var _impact_spot := Vector2.ZERO
var _job := -1
var _last_elapsed := -1.0
var _was_delivered := false
var _was_grounded := false
var _m := 44.0
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	var bounds := size if size.x>1 and size.y>1 else Vector2(1280,720)
	var headroom := clampf(bounds.y*.124,42.0,100.0)
	var footroom := clampf(bounds.y*.158,62.0,130.0)
	_m = maxf(1.0,minf(bounds.x/23.9,(bounds.y-headroom-footroom)/11.85))
	_origin = Vector2(bounds.x*.49-11.0*_m,bounds.y-footroom-.18*_m)
	queue_redraw()

func ground_to_screen(world_point: Vector2) -> Vector2:
	return _origin+Vector2(world_point.x,-world_point.y)*_m

func screen_to_ground(pixel: Vector2) -> Vector2:
	var q := (pixel-_origin)/_m
	return Vector2(q.x,-q.y)

func impact(strength: float = 1.0) -> void:
	if rig==null:
		return
	_impact_age = 0.0
	_impact_strength = clampf(strength,.05,2.0)
	var p: Vector2 = rig.load_position()
	_impact_spot = p-Vector2(0,LOAD_H*.5)

func _process(delta: float) -> void:
	_clock += delta
	_impact_age += delta
	if rig!=null:
		var done := bool(rig.delivered)
		var grounded := bool(rig.grounded)
		var reset := int(rig.job_index)!=_job or float(rig.elapsed)<_last_elapsed-.01 or (_was_delivered and not done)
		if reset:
			_handoff=-1.0
			_was_grounded=grounded
			_was_delivered=false
			_impact_age=9.0
		if grounded and not _was_grounded:
			impact(.45)
		if done and not _was_delivered:
			_handoff=0.0
		elif _handoff>=0:
			_handoff+=delta
		_job=int(rig.job_index)
		_last_elapsed=float(rig.elapsed)
		_was_delivered=done
		_was_grounded=grounded
	queue_redraw()

func _departure() -> float:
	if rig==null or _handoff<.42 or float(rig.target_x)<SHORE_EDGE:
		return 0.0
	return minf(18.0,1.40*pow(_handoff-.42,1.64))

func _at(x: float, y: float) -> void:
	draw_set_transform(ground_to_screen(Vector2(x,y)),0,Vector2.ONE*_m/UNIT)

func _points(values: PackedFloat32Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	result.resize(values.size()/2)
	for i in result.size():
		result[i]=Vector2(values[i*2],values[i*2+1])
	return result

func _poly(values: PackedFloat32Array, tint: String) -> void:
	draw_colored_polygon(_points(values),Color(tint))

func _path(values: PackedFloat32Array, tint: String, width: float=1.4) -> void:
	draw_polyline(_points(values),Color(tint),width,true)

func _line(x1: float,y1: float,x2: float,y2: float,tint: String,width: float=1.4) -> void:
	draw_line(Vector2(x1,y1),Vector2(x2,y2),Color(tint),width,true)

func _rect(x: float,y: float,width: float,height: float,tint: String) -> void:
	draw_rect(Rect2(x,y,width,height),Color(tint))

func _circle(x: float,y: float,r: float,tint: String) -> void:
	draw_circle(Vector2(x,y),r,Color(tint),true,-1,true)

func _arch(x: float,y: float,r: float,from: float,to: float,tint: String,width: float=1.4) -> void:
	draw_arc(Vector2(x,y),r,from,to,24,Color(tint),width,true)

func _beacon(x: float,y: float,on: bool) -> void:
	_rect(x-3,y,6,3,"#394d4f")
	_rect(x-2,y-4,4,5,"#c6ca99" if not on else "#ffe291")
	if on:
		_circle(x,y-2,7,"#ffe39127")
		_circle(x,y-2,2,"#fff1b9")

func _birds() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	for i in 4:
		var slide := fmod(_clock*(3.0+i*.44)+183.0*i,size.x+90.0)-40.0
		var root_pos := Vector2(slide, size.y*(.35+.034*sin(i*1.85)) + 5.0*sin(_clock*.19+i))
		var amp := (1.0+2.0*sin(_clock*3.2+i))*(size.y/720)
		var span := (4.8+i%2*1.4)*(size.y/720)
		draw_polyline(PackedVector2Array([root_pos+Vector2(-span,-amp),root_pos+Vector2(-span*.46,-amp*.6-1),root_pos,root_pos+Vector2(span*.42,-amp*.63-1),root_pos+Vector2(span,-amp)]),Color("#5d7f80a0"),maxf(1.0,size.y/720*1.15),true)

func _water_light() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	var horizon := size.y*.57
	for i in 46:
		var base := fmod(67.0+i*143.7+_clock*(2.1+i%5),size.x+74)-45
		var level := horizon+fmod(i*31.73,maxf(1.0,size.y-horizon))
		var alpha := .22+.14*sin(_clock*.7+i*1.7)
		draw_line(Vector2(base,level),Vector2(base+9+(i%5)*8,level+.6),Color(.81,.88,.75,alpha),1.35,true)

func _far_pier() -> void:
	_at(20.7,SHORE_DECK+.06)
	_poly([-189,-17,-181,-25,-105,-26,-92,-17,-90,8,-187,8],"#78918b")
	_poly([-196,-19,-183,-29,-103,-29,-87,-19,-92,-15,-105,-24,-179,-23,-189,-14],"#899d94")
	for i in 9:
		_line(-180+i*9,-19,-180+i*9,3,"#9daea0",1)
	_poly([-82,5,-82,-57,-61,-72,40,-72,63,-56,63,6],"#81918a")
	_poly([-87,-55,-65,-75,42,-75,67,-56,60,-53,39,-68,-60,-68,-81,-51],"#6c817e")
	_rect(-71,-42,26,44,"#718682")
	for i in 4:
		_rect(-36+i*20,-49,13,11,"#b4bb9e")
		_line(-30+i*20,-49,-30+i*20,-38,"#83958c",1.2)
		_line(-36+i*20,-44,-23+i*20,-44,"#83958c",1)
	for i in 7:
		_line(-37+i*14,-32,-37+i*14,2,"#8e9b8f",1.1)
	_rect(89,-28,110,36,"#8b9b90")
	_poly([83,-27,97,-43,188,-43,204,-27],"#7c9089")
	_line(-310,-4,190,-4,"#9da593",2)
	for x in [-199.0,62,154]:
		_line(x,2,x,-56,"#667f7c",2.3)
		_path([x,-54,x+4,-60,x+10,-60],"#667f7c",1.7)
		_line(x+8,-59,x+14,-59,"#b8b79b",2.3)

func _tower(foot: float, lean: float, near: bool) -> void:
	_at(foot,SHORE_DECK)
	var rise := (RAIL-SHORE_DECK)*UNIT
	var x_top := lean*UNIT
	var shade := "#66868a" if near else "#8ba4a1"
	var face := "#84a3a1" if near else "#a9bab0"
	_poly([-12,7,-8,-26,x_top-8,-rise-32,x_top+10,-rise-32,13,-24,17,7],shade)
	_poly([-12,6,-9,-22,x_top-8,-rise-31,x_top-3,-rise-31,0,-22,-1,7],face)
	_line(x_top+9,-rise-25,13,-20,"#698789",2)
	for i in range(1,6):
		var t := i/6.0
		var x := lerpf(0,x_top,t)
		var y := lerpf(0,-rise-26,t)
		_line(x-7,y,x+10,y,"#647e7f",1.3)
	_rect(-17,-7,34,12,"#6c7f78")
	_rect(-22,-1,44,7,"#96a094")
	_rect(-23,5,46,4,"#596d69")

func _girder_support() -> void:
	_tower(13.0,-1.25,false)
	_tower(22.5,-1.55,false)
	_at(11.28,SHORE_DECK)
	_line(10,-15,76,-220,"#819c98",8)
	_line(10,-15,76,-220,"#a5b4a5",2)
	_line(77,-220,31,-427,"#819b96",7)
	_tower(11.28,.12,true)
	_tower(21.6,-.04,true)
	_at(11.40,5.9)
	_rect(-10,-4,52,5,"#627e7c")
	_line(-8,-18,41,-18,"#a5a88a",1.5)
	for x in [-7,9,25,40]:
		_line(x,-18,x,-4,"#8c9c89",1.4)
	_at(11.76,1.2)
	var height := (RAIL-1.5)*UNIT
	_line(-4,0,-4,-height,"#566e70",2)
	_line(7,0,7,-height,"#566e70",2)
	for i in 32:
		_line(-4,-i*13.1,7,-i*13.1,"#85938b",1.5)

func _rail() -> void:
	_at(0,RAIL)
	var start := -220.0
	var end := 1250.0
	_poly([start,-17,start+21,-46,end-7,-49,end+8,-25,end-5,-10,start+5,-7],"#79918f")
	_poly([start,-14,start+24,-42,end-10,-45,end,-35,start+27,-31,start+10,-12],"#c2c3a6")
	_rect(start+10,-12,end-start-12,5,"#35555c")
	_rect(start+11,-7,end-start-13,6,"#809192")
	for i in 28:
		var x := start+22+i*51
		_path([x,-12,x+24,-40,x+48,-13],"#516e72",3.4)
		_path([x+1,-13,x+24,-38,x+46,-13],"#a6b2a3",1.1)
		_circle(x+24,-39,1.8,"#596f70")
	_rect(start+22,-49,end-start-42,4,"#9d9b7f")
	_line(start+22,-58,end-23,-58,"#b5aa88",1.8)
	for i in 39:
		var x := start+25+i*37
		_line(x,-58,x,-47,"#9e9e82",1.5)
	_rect(956,-40,129,24,"#748b87")
	for i in 6:
		_line(967+i*17,-35,978+i*17,-35,"#a2ada0",1.5)
		_line(967+i*17,-31,978+i*17,-31,"#a2ada0",1.5)
	_at(11.3,RAIL)
	_poly([-17,-47,-13,-71,18,-71,21,-48],"#677f7d")
	_rect(-16,-72,37,4,"#a9ac91")
	_line(-7,-68,-7,-55,"#8b9e95",2)
	_line(7,-68,7,-55,"#8b9e95",2)

func _quay_wall() -> void:
	_at(SHORE_EDGE,SHORE_DECK)
	_poly([0,0,890,0,890,188,0,188],"#8b8472")
	_poly([0,0,890,0,890,12,0,12],"#c5b99a")
	_rect(0,10,890,7,"#a89e85")
	_rect(0,17,890,4,"#756f61")
	_rect(0,37,890,2,"#797866")
	_rect(0,55,890,2,"#727160")
	for i in 12:
		var x := 5.0+i*85
		_line(x,20,x+2,37,"#757464",1.1)
		_line(x+35,39,x+36,54,"#727261",1.4)
		_line(x+9,22,x+5,31,"#9b957e",1.0)
	for i in 8:
		var x := 10.0+i*29
		_poly([x,1,x+12,1,x+4,10,x-4,10],"#564f45" if i%2==0 else "#cfac6a")
	_line(0,12,0,155,"#506b67",4)
	for y in [34,44,54,64,74]:
		_line(0,y,7,y,"#d5c4a1",1.6)
	for x in [14.0,108,293,449,645]:
		_line(x,10,x+4,23,"#5e6258",2.1)
		_circle(x+6,29,9,"#455654")
		_circle(x+6,29,4.8,"#777768")
		_arch(x+6,29,7,3.35,5.2,"#68736a",1.4)
	# Far edge of the quay and inset wheel tracks keep the vehicle's road legible.
	_rect(0,-4,910,7,"#c6b99d")
	_line(4,-4,896,-4,"#e2d2ae",2)
	for i in 9:
		_line(20+i*94,-2,35+i*94,-2,"#a69d87",1.0)

func _bollard(x: float,y: float) -> void:
	_at(x,y)
	_poly([-9,0,-7,-4,-5,-5,-5,-10,-7,-12,-6,-15,4,-15,7,-12,5,-10,4,-4,9,-1,9,1],"#475b59")
	_line(-5,-13,4,-13,"#b89b71",2.3)

func _worker(x: float,y: float,look: float,wave: bool,coat: String) -> void:
	# Feet are on the supplied deck. A hard hat and bright vest remain readable at a distance.
	_line(x-3,y-11,x-5,y-1,"#394b50",3.4)
	_line(x+2,y-11,x+3,y-1,"#394b50",3.4)
	_poly([x-5,y-22,x+3,y-23,x+5,y-10,x-4,y-10],coat)
	_line(x-4,y-15,x+4,y-15,"#e2ca90",1.7)
	_circle(x,y-26,3.6,"#c99875")
	_arch(x,y-27,4.2,PI,TAU,"#e8c078",3)
	_line(x-4,y-27,x+look*5,y-27,"#f0d497",1.6)
	var lift := -32.0+2.5*sin(_clock*6.0) if wave else -17.0
	_path([x+look*3,y-21,x+look*7,y-19,x+look*10,y+lift],coat,2.6)
	_circle(x+look*10,y+lift,1.5,"#d9aa81")

func _ship() -> void:
	# Starboard side. The forward deck edge is exactly the collision surface at SHIP_EDGE.
	_at(SHIP_EDGE,SHIP_DECK)
	_poly([-975,-2,-140,-2,-64,-7,-7,-13,0,-8,-4,19,-14,74,-42,124,-84,152,-157,172,-866,172,-942,98],"#344e57")
	_poly([-970,14,-123,14,-34,4,-5,-2,-10,29,-28,79,-56,113,-113,146,-921,146,-956,94],"#48666c")
	_poly([-962,71,-534,82,-254,81,-100,70,-29,49,-19,43,-35,92,-57,124,-104,153,-167,170,-868,170,-943,104],"#3b5a62")
	_poly([-957,109,-766,122,-476,124,-231,122,-111,106,-51,86,-30,72,-43,107,-64,135,-95,155,-156,175,-863,175,-936,137],"#a8624f")
	_poly([-949,140,-690,147,-381,147,-198,141,-105,127,-56,107,-46,99,-60,128,-86,151,-151,176,-876,176,-930,154],"#904f43")
	_poly([-878,166,-769,167,-702,165,-615,167,-510,166,-393,168,-332,166,-244,167,-173,166,-139,161,-117,158,-135,168,-152,176,-876,176],"#6b7467")
	_poly([-860,176,-728,175,-625,176,-541,174,-430,177,-306,174,-194,176,-150,174,-138,172,-159,178,-215,182,-349,181,-501,185,-692,180,-855,184],"#427d79b5")
	for i in 15:
		var wave_x := -849.0+float(i)*47+2.4*sin(_clock*.85+i)
		var wave_y := 175.5+float(i%3)*.84
		_path([wave_x,wave_y,wave_x+9,wave_y-.7,wave_x+17+(i%3)*2,wave_y+.1],"#c3d1b68c",1.7)
	_path([-192,175,-174,175,-159,172,-147,173,-139,170],"#d0d5bb",1.8)
	_path([-967,95,-727,108,-461,109,-227,106,-112,93,-51,72,-23,55],"#d1aa7d",2.5)
	_path([-966,6,-334,6,-103,5,-34,-2,-6,-8],"#d0bb91",3.2)
	_path([-820,44,-443,48,-200,45,-101,36,-43,25,-13,14],"#65807e",1.25)
	for i in 25:
		var x := -565.0+i*21
		var y := 58.0-8.0*smoothstep(-160.0,-34.0,x)
		_circle(x,y,1.2,"#78908a")
	for x in [-490.0,-433,-366,-302,-242,-179,-131,-97]:
		_line(x,17,x+1,38,"#836e59",1.3)
		_line(x+5,17,x+6,27,"#a08163",.85)
	for i in 7:
		_line(-42-i*.7,53+i*7,-35-i*.7,53+i*7,"#d6c5a2",1.5)
	_arch(-58,15,8,0,TAU,"#c5b792",2.7)
	_circle(-58,15,5,"#314d53")
	# Painted bow crest and two modest registration bars.
	_path([-141,29,-132,27,-124,30,-116,24,-109,23],"#d0d2b8",2.5)
	_line(-141,37,-115,35,"#abbeb0",1.2)
	_line(-138,41,-120,40,"#abbeb0",1.2)
	for x in [-391.0,-365,-339]:
		_circle(x,32,5.7,"#a9b39f")
		_circle(x,32,4.3,"#2f474e")
		_arch(x,32,4.7,3.55,5.75,"#d4c39d",1.0)
	# Cabin and wheelhouse are kept aft of the active bay.
	_at(SHIP_EDGE+3.7,SHIP_DECK)
	_poly([-776,0,-775,-78,-523,-80,-498,-40,-493,0],"#d5cfad")
	_poly([-631,0,-631,-73,-523,-80,-499,-38,-493,0],"#bcbfa5")
	_poly([-753,-79,-746,-104,-575,-109,-532,-99,-524,-79],"#e7dcc0")
	_poly([-730,-104,-721,-144,-590,-146,-565,-113,-577,-106],"#ded6ba")
	_poly([-600,-146,-560,-142,-544,-114,-567,-111],"#b4bcab")
	_poly([-736,-144,-724,-153,-590,-153,-557,-146,-557,-141,-591,-145,-724,-143],"#6c8179")
	_poly([-714,-139,-694,-139,-696,-118,-718,-118],"#5b7980")
	_poly([-689,-139,-669,-140,-670,-118,-691,-118],"#53757c")
	_poly([-664,-140,-645,-140,-643,-118,-666,-118],"#5a7e84")
	_poly([-640,-140,-618,-140,-613,-119,-639,-118],"#65858a")
	_poly([-612,-140,-593,-141,-582,-120,-608,-119],"#46686e")
	_poly([-589,-140,-569,-137,-557,-119,-577,-119],"#61808a")
	_line(-718,-116,-575,-118,"#9b9d87",2)
	_rect(-587,-61,32,59,"#a9b39d")
	_rect(-581,-53,19,22,"#6a8785")
	_line(-580,-24,-574,-24,"#d7ccab",1.8)
	for i in 6:
		_rect(-735+i*22,-52,13,16,"#778d88")
		_line(-735+i*22,-53,-722+i*22,-53,"#b0b49a",1.8)
	_rect(-766,-10,260,6,"#c18a62")
	_rect(-747,-176,22,59,"#546d6e")
	_rect(-747,-174,22,12,"#bd7e60")
	_rect(-751,-178,29,5,"#364f54")
	# Antenna, halyards, aerial and lifering make the ship distinct from shore buildings.
	_line(-656,-146,-660,-206,"#6a7972",3.3)
	_line(-684,-189,-635,-191,"#8d9685",1.9)
	_line(-705,-146,-658,-198,"#84948a",1.1)
	_line(-637,-148,-658,-198,"#84948a",1.1)
	_line(-665,-207,-655,-208,"#b8b497",1.3)
	_circle(-548,-36,10,"#c96c53")
	_circle(-548,-36,5.6,"#b8baa2")
	for i in 4:
		_arch(-548,-36,8,i*PI/2+.20,i*PI/2+.65,"#edddae",3.5)
	# Railings frame the work deck but leave the cargo visible.
	_at(SHIP_EDGE,SHIP_DECK)
	for x in [-485.0,-466,-447,-428,-68,-45,-22]:
		_line(x,0,x,-17,"#829187",1.8)
	_line(-485,-17,-426,-17,"#d1d0b3",2)
	_path([-71,-17,-42,-19,-19,-23],"#cfd0b2",2)
	_rect(-421,-6,119,6,"#988c72")
	_rect(-418,-6,111,2,"#d2bc91")
	_worker(-347,-6,1.0,rig!=null and rig.delivered and float(rig.target_x)<SHORE_EDGE,"#c0825a")
	# Deck paint follows the exact top of the physics deck.
	_rect(-424,-1,400,3,"#b8aa86")
	_line(-426,-2,-17,-2,"#ded0a3",1.2)
	# Bow line is slack between the fairlead and a shore bollard.
	var mooring := PackedVector2Array()
	for i in 19:
		var f := i/18.0
		mooring.append(Vector2(lerpf(-27,69,f),lerpf(-2,117,f)+19*sin(PI*f)))
	draw_polyline(mooring,Color("#53605a"),3,true)
	draw_polyline(mooring,Color("#baab80"),1.1,true)
	_bollard(10.58,SHORE_DECK)
	_at(SHIP_BAY,SHIP_DECK)
	_poly([-106,0,-98,-6,97,-6,106,0],"#c6b799")
	_line(-93,-5,95,-5,"#d9c9a5",1.1)
	var arrival := rig!=null and float(rig.target_x)<SHORE_EDGE
	_landing_paint(arrival,rig!=null and rig.delivered and arrival)
	if arrival and _handoff>=0:
		_at(2.1,SHIP_DECK)
		_line(0,-5,0,-62,"#65766e",2)
		var flutter := 2*sin(_clock*7)
		_poly([0,-61,14,-62+flutter,24,-56,13,-52+flutter,0,-53],"#e8bc72")

func _landing_paint(target: bool, complete: bool) -> void:
	var half := BAY_W*.5*UNIT
	var guide := "#f0d89d" if target else "#b3ac92"
	var anchor := "#d98a57" if target else "#879181"
	if target:
		_line(-half+8,-1,half-8,-1,"#efd18d",2.7)
		for i in range(1,8):
			var stripe := -half+i*half*.25
			_line(stripe-3,2,stripe+2,2,"#fee5a7",1.4)
		_path([-8,4,0,8,8,4],"#f3d697",2)
	for sign_x in [-1.0,1.0]:
		var x: float=sign_x*half
		_poly([x,-1,x-sign_x*18,-1,x-sign_x*19,-4,x-sign_x*4,-4,x-sign_x*8,-8,x-sign_x*3,-8],guide)
		_rect(x-3,-5,6,5,anchor)
		if target:
			_beacon(x,-8,complete or sin(_clock*3.35)>.23)

func _tire(x: float,y: float,r: float,rotation: float) -> void:
	_circle(x,y,r+1.1,"#25383c")
	_circle(x,y,r-2.6,"#3a4647")
	_arch(x,y,r-1,3.3,5.75,"#4b5450",1.4)
	_circle(x,y,r*.58,"#778681")
	_circle(x,y,r*.43,"#556661")
	for i in 6:
		var a := rotation+i*TAU/6
		_circle(x+cos(a)*r*.32,y+sin(a)*r*.32,1.7,"#bac1a9")
	_circle(x,y,r*.19,"#adb4a1")

func _truck(shift: float) -> void:
	_at(TRUCK_LEFT+shift,TRUCK_DECK)
	var bed := (TRUCK_RIGHT-TRUCK_LEFT)*UNIT
	var tire_turn := shift*UNIT/18.0
	# Wheel undersides meet the road at SHORE_DECK, exactly 50 art units below the bed.
	_rect(15,15,263,13,"#384c4d")
	_poly([7,20,251,20,282,14,289,24,275,29,17,31],"#465954")
	_rect(65,22,65,20,"#68756b")
	_rect(70,26,55,4,"#8b9180")
	_rect(130,25,36,16,"#756e59")
	_line(135,23,135,41,"#b19c72",2.0)
	_line(157,23,157,41,"#b19c72",2.0)
	_rect(4,22,7,18,"#3e4a45")
	_tire(31,32.0,18.0,tire_turn)
	_tire(177,32.0,18.0,tire_turn)
	_tire(263,32.0,18.0,tire_turn)
	_arch(31,31,21.2,PI+.08,TAU-.08,"#536960",4)
	_arch(177,31,21.2,PI+.08,TAU-.08,"#566d63",4)
	_rect(0,0,bed,7,"#a39474")
	_poly([0,6,bed,6,bed-3,16,0,15],"#466d68")
	_rect(3,8,bed-7,2,"#88a092")
	for i in 10:
		_rect(7+i*21,10,5,2,"#daba7e")
		_circle(10+i*21,13,1.1,"#364d4d")
	_rect(0,-2,bed,3,"#ddc7a0")
	_poly([0,0,7,-5,bed-5,-5,bed,0],"#c7b38d")
	for i in 5:
		_line(12+i*43,0,21+i*43,0,"#927d63",1)
	# The rear of the cab stays outside the physical flatbed.
	_poly([bed+4,10,bed+4,-31,bed+12,-45,bed+48,-47,bed+63,-36,bed+75,-11,bed+83,-8,bed+85,16,bed+72,21,bed+66,19,bed+61,9,bed+53,6,bed+34,7,bed+25,15,bed+23,22,bed+5,21],"#386e68")
	_poly([bed+9,-28,bed+17,-42,bed+48,-43,bed+59,-34,bed+67,-15,bed+12,-14],"#92afaa")
	_poly([bed+18,-38,bed+40,-39,bed+40,-17,bed+13,-16],"#496d73")
	_poly([bed+45,-39,bed+54,-34,bed+62,-17,bed+45,-17],"#557a7f")
	# Driver leans by the open window and turns toward the sling.
	_poly([bed+17,-16,bed+18,-24,bed+26,-29,bed+34,-25,bed+36,-17],"#344f52")
	_circle(bed+26,-30,4.9,"#c79671")
	_poly([bed+20,-31,bed+22,-36,bed+30,-35,bed+33,-32],"#d5b27b")
	_line(bed+21,-31,bed+29,-32,"#846b52",1.2)
	var wave: bool = rig!=null and rig.delivered and shift<3
	_path([bed+28,-22,bed+18,-19,bed+12,-26 if wave else -18],"#d0a77f",2.8)
	_line(bed+41,-40,bed+42,-15,"#d2d2b4",2.5)
	_line(bed+9,-13,bed+65,-14,"#c4bf9f",2.5)
	_poly([bed+8,-1,bed+80,-3,bed+82,1,bed+8,4],"#daab79")
	_poly([bed+6,-32,bed+13,-48,bed+47,-50,bed+57,-45,bed+60,-42,bed+15,-42,bed+10,-32],"#dad2af")
	_path([bed+12,-10,bed+12,10,bed+25,11,bed+39,4,bed+40,-12],"#568077",1.1)
	_rect(bed+15,-9,8,2,"#cbbd99")
	_rect(bed+70,1,11,4,"#e0c68e")
	_rect(bed+79,8,6,6,"#5e736e")
	_rect(bed+75,15,13,4,"#a4aa93")
	_line(bed+61,-26,bed+67,-29,"#43575a",1.8)
	_rect(bed+66,-32,3,7,"#637979")
	_line(bed+13,21,bed+23,21,"#b4ab8c",3)
	_at(TRUCK_BAY+shift,TRUCK_DECK)
	var target := rig==null or float(rig.target_x)>SHORE_EDGE
	_landing_paint(target,rig!=null and rig.delivered and target)

func _cast_shadow(p: Vector2,shift: float) -> void:
	var deck := -0.14
	var left := -1000.0
	var right := 1000.0
	if p.x<=SHIP_EDGE:
		deck=SHIP_DECK
		right=SHIP_EDGE
	elif p.x>=SHORE_EDGE:
		deck=SHORE_DECK
		left=SHORE_EDGE
		if p.x>=TRUCK_LEFT+shift and p.x<=TRUCK_RIGHT+shift:
			deck=TRUCK_DECK
			left=TRUCK_LEFT+shift
			right=TRUCK_RIGHT+shift
	var clearance := maxf(0,p.y-LOAD_H*.5-deck)
	var width := LOAD_W*.5*(1+.055*clearance)
	var centre := p.x+.074*clearance
	var x1 := maxf(left,centre-width)
	var x2 := minf(right,centre+width)
	if x2<=x1:
		return
	_at(0,deck)
	var fade := clampf(.60-clearance*.051,.20,.60)
	var a := x1*UNIT
	var b := x2*UNIT
	var length := b-a
	var part := _points([a,-.7,a+length*.10,-4.5,a+length*.87,-4.5,b,-.7,b-length*.08,1.4,a+length*.10,1.4])
	draw_colored_polygon(part,Color(.18,.24,.22,fade))
	draw_line(Vector2(a+length*.15,-1.2),Vector2(b-length*.14,-1.2),Color(.14,.20,.19,fade*.76),1.9,true)

func _box(p: Vector2) -> void:
	_at(p.x,p.y)
	var hw := LOAD_W*UNIT*.5
	var hh := LOAD_H*UNIT*.5
	# All faces stay within the level collision box. Slivers of end grain define its volume.
	_poly([-hw,-hh,hw-7,-hh,hw,-hh+4,hw,hh,-hw+2,hh,-hw,hh-3],"#725538")
	_poly([-hw+1,-hh+2,hw-7,-hh+2,hw-7,hh-3,-hw+2,hh-3],"#bc8b51")
	_poly([hw-7,-hh+2,hw,-hh+5,hw,hh-1,hw-7,hh-3],"#936b43")
	var planks := ["#c69a5d","#c3985d","#bf9055","#cba36a","#bd8e55","#c59b60","#bd905a"]
	var panel_w := (2*hw-10)/7.0
	for i in 7:
		var x := -hw+2+i*panel_w
		_rect(x,-hh+3,panel_w-1,hh*2-7,planks[i])
		_line(x,-hh+4,x,hh-5,"#a47949",1)
		_line(x+3+(i%3),-hh+7+(i%2)*11,x+3+(i%3),-hh+18+(i%2)*11,"#dab47a",.9)
		_line(x+panel_w-3,hh-23+i%4*3,x+panel_w-3,hh-12+i%4*3,"#ac7e4b",1)
	_poly([-hw+1,hh-12,hw-10,-hh+6,hw-7,-hh+6,hw-7,-hh+14,-hw+1,hh-2],"#a77e4c")
	_line(-hw+3,hh-12,hw-8,-hh+9,"#daba80",1.4)
	_rect(-hw+1,-hh+2,hw*2-8,5,"#deb779")
	_rect(-hw+2,hh-6,hw*2-9,5,"#aa7a48")
	for x in [-hw+11,hw-22]:
		_rect(x,-hh+2,4.6,hh*2-3,"#5f6255")
		_line(x+1,-hh+3,x+1,hh-3,"#99937a",1)
		for y in [-hh+8,hh-9]:
			_circle(x+2.3,y,1.2,"#d1bd8e")
	# Two miniature upright arrows and a folded shipping label are stencilled on the timber.
	for x in [-4.0,3]:
		_path([x-2.2,-15,x,-18,x+2.2,-15],"#59675c",1.4)
		_line(x,-17,x,-10,"#59675c",1.5)
	_rect(10,8,12,9,"#e5d7b2")
	_path([11,9,15,12,21,9],"#9b8464",1)
	_line(13,14,18,14,"#b6976f",.8)
	_rect(-hw+1,-hh,hw*2-8,2,"#eac895")
	_line(-hw+2,hh-1,hw-2,hh-1,"#614c38",1.5)

func _wire_point(pivot: Vector2,hook: Vector2,t: float,slack: float) -> Vector2:
	var straight := pivot.lerp(hook,t)
	var along := (hook-pivot).normalized()
	var normal := Vector2(-along.y,along.x)
	var arc := sin(PI*t)
	return straight+normal*minf(slack*.75,1.1)*arc-Vector2(0,.27*slack*arc)

func _rope(trolley: float,hook: Vector2,slack: float) -> void:
	var pivot := Vector2(trolley,RAIL)
	var distance := maxf(.01,pivot.distance_to(hook))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	var scale_px := _m/UNIT
	if absf(hook.x-trolley)>.13 and _handoff<0:
		var top := ground_to_screen(pivot-Vector2(0,.22))
		var bottom := ground_to_screen(Vector2(trolley,hook.y-.55))
		var opacity := clampf(absf(hook.x-trolley)*.27,.22,.50)
		draw_dashed_line(top,bottom,Color(.16,.30,.32,opacity),maxf(1.35,1.7*scale_px),maxf(5,8*scale_px),true)
		draw_line(bottom+Vector2(-4,-2),bottom,Color(.15,.27,.28,opacity+.1),1.5,true)
		draw_line(bottom,bottom+Vector2(4,-2),Color(.15,.27,.28,opacity+.1),1.5,true)
	var cable := PackedVector2Array()
	for i in 23:
		cable.append(ground_to_screen(_wire_point(pivot,hook,i/22.0,slack)))
	draw_polyline(cable,Color("#263e45"),maxf(3.0,4.8*scale_px),true)
	var glint := PackedVector2Array()
	for p in cable:
		glint.append(p-Vector2(.75*scale_px,0))
	draw_polyline(glint,Color("#bcbdab"),maxf(1.0,1.4*scale_px),true)
	var marked := minf(1.01,distance-.04)
	var end_t := 1.0-.04/distance
	var start_t := maxf(.02,1.0-marked/distance)
	for i in 6:
		var a := lerpf(start_t,end_t,float(i)/6.0)
		var b := lerpf(start_t,end_t,float(i+1)/6.0)
		draw_line(ground_to_screen(_wire_point(pivot,hook,a,slack)),ground_to_screen(_wire_point(pivot,hook,b,slack)),
			Color("#e8d8b3") if i%2==0 else Color("#b65e4b"),maxf(3.4,5.0*scale_px),true)

func _spreader(hook: Vector2) -> void:
	_at(hook.x,hook.y)
	_circle(0,-3.5,5.8,"#35474a")
	_arch(0,-4,3.3,PI,TAU,"#b7b9a2",1.3)
	_poly([-6,-5,5,-5,8,0,24,-1,29,3,-31,3,-27,-1,-8,-1],"#566258")
	_rect(-26,0,52,3,"#d9b36e")
	for x in [-24.0,20]:
		_rect(x,1,4.5,5,"#4c514a")
		_line(x+1,0,x+1,3,"#b3a886",1.3)

func _trolley(x: float) -> void:
	_at(x,RAIL)
	var speed := float(rig.trolley_speed) if rig!=null else 0.0
	# The axle is at the same world point used by the pendulum solver.
	_poly([-36,-20,-29,-26,19,-26,32,-19,30,-4,19,2,-24,2,-32,-5],"#805d43")
	_poly([-34,-20,-27,-23,21,-23,30,-18,26,-7,-26,-6,-32,-9],"#c48756")
	_rect(-26,-23,47,5,"#d8a574")
	for xx in [-22.0,20]:
		_circle(xx,-7,7.3,"#34464b")
		_circle(xx,-7,4.6,"#72817b")
		var angle := x*UNIT/5
		_line(xx-3*cos(angle),-7-3*sin(angle),xx+3*cos(angle),-7+3*sin(angle),"#b0b39e",1.3)
	_poly([-21,-6,-12,-4,-7,2,8,2,14,-6,23,-6,22,-1,9,8,-8,8,-21,0],"#4c5d5c")
	_circle(0,1,6.4,"#33464a")
	_circle(0,1,3.8,"#87928a")
	_line(-1,2,2,-1,"#d7c59d",1.4)
	_rect(-33,-17,13,6,"#ead3a1")
	for i in 3:
		_line(-30+i*5,-17,-33+i*5,-11,"#536361",2.4)
	_rect(8,-39,16,15,"#829995")
	_rect(7,-41,19,3,"#536d6f")
	_rect(11,-36,10,6,"#9db5ac")
	_line(-22,-25,-22,-36,"#716e59",1.5)
	_line(-22,-36,-2,-36,"#a79974",1.5)
	_line(-4,-36,-4,-26,"#827d66",1.5)
	_beacon(-23,-26,absf(speed)>.12 and sin(_clock*7.5)>.12)

func _contact_particles() -> void:
	if _impact_age>.53:
		return
	_at(_impact_spot.x,_impact_spot.y)
	var t := _impact_age
	for i in 8:
		var direction := -1.0 if i%2==0 else 1.0
		var velocity := (26.0+i*5.0)*(_impact_strength*.65+.65)
		var x := direction*(17+i%3*8+velocity*t)
		var y := -(21+i%4*5)*t+56*t*t
		var fade := (1.0-t/.53)*(.20+.09*(i%2))
		draw_circle(Vector2(x,y-2),1.2+(i%3)*.4+t,Color(.83,.72,.54,fade),true,-1,true)

func _draw() -> void:
	if size.x<2 or size.y<2:
		return
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	draw_texture_rect(BACKDROP,Rect2(Vector2.ZERO,size),false)
	_birds()
	_water_light()
	_far_pier()
	_girder_support()
	_quay_wall()
	_ship()
	var shift := _departure()
	_truck(shift)
	var trolley := float(rig.trolley_x) if rig!=null else SHIP_BAY
	var cargo: Vector2 = rig.load_position() if rig!=null else Vector2(SHIP_BAY,SHIP_DECK+.60+LOAD_H*.5)
	var hook: Vector2 = rig.hook_position() if rig!=null else cargo+Vector2(0,LOAD_H*.5)
	var slack := float(rig.rope_slack) if rig!=null else 0.0
	if _handoff>=0:
		var lift := smoothstep(.20,1.34,_handoff)
		hook = hook.lerp(Vector2(trolley,minf(RAIL-1.05,hook.y+2.35)),lift)
		slack *= 1.0-lift
	cargo.x += shift
	_cast_shadow(cargo,shift)
	_rail()
	_rope(trolley,hook,slack)
	_box(cargo)
	_spreader(hook)
	_trolley(trolley)
	_contact_particles()
