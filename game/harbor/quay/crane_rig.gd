extends RefCounted

const RAIL_Y := 10.0
const TROLLEY_MIN_X := 1.5
const TROLLEY_MAX_X := 20.5
const WORLD_MIN_X := 0.0
const WORLD_MAX_X := 22.0
const SHIP_EDGE_X := 9.2
const SHORE_EDGE_X := 10.1
const SHIP_TOP_Y := 3.5
const SHORE_TOP_Y := 1.0
const TRUCK_TOP_Y := 2.0
const TRUCK_LEFT_X := 14.8
const TRUCK_RIGHT_X := 19.2
const SHIP_BAY_X := 5.0
const TRUCK_BAY_X := 17.0
const BAY_WIDTH := 3.9
const BOX_WIDTH := 2.0
const BOX_HEIGHT := 1.35
const START_CLEARANCE := 0.60
const GRAVITY := 9.81
const ANGULAR_DAMPING := 0.16
const MAX_TRAVEL_SPEED := 2.9
const TRAVEL_ACCEL := 2.15
const TRAVEL_BRAKE := 3.35
const MAX_HOIST_SPEED := 1.40
const HOIST_ACCEL := 3.15
const HOIST_BRAKE := 4.4
const MIN_ROPE_LENGTH := 1.35
const MAX_ROPE_LENGTH := 8.35
const GROUND_FRICTION := 1.55
const SETTLE_SPEED := 0.26
const SETTLE_SECONDS := 0.52
const IMPACT_SPEED := 0.44
const MAX_STEP := 1.0 / 180.0
const CONTACT_EPS := 0.000015

# Each surface is a solid below its top. Contacts use the box's whole footprint.
const SURFACES := [
	{"name":"ship", "left":-1000.0, "right":SHIP_EDGE_X, "top":SHIP_TOP_Y},
	{"name":"shore", "left":SHORE_EDGE_X, "right":1000.0, "top":SHORE_TOP_Y},
	{"name":"truck", "left":TRUCK_LEFT_X, "right":TRUCK_RIGHT_X, "top":TRUCK_TOP_Y}
]

var job_index := 0
var rail_y := RAIL_Y
var trolley_x := SHIP_BAY_X
var trolley_speed := 0.0
var rope_length := 0.0
var hoist_speed := 0.0
var angle := 0.0
var angular_velocity := 0.0
var rope_slack := 0.0
var travel_input := 0.0
var drive_input: float:
	get: return travel_input
var hoist_input := 0.0
var target_x := TRUCK_BAY_X
var target_y := TRUCK_TOP_Y
var source_x := SHIP_BAY_X
var source_y := SHIP_TOP_Y
var delivered := false
var grounded := false
var ground_surface := ""
var elapsed := 0.0
var contacts := 0
var touch_sequence := 0
var first_touch: Dictionary = {}
var last_touch: Dictionary = {}
var last_impact: Dictionary = {}
var settled_time := 0.0

var _hook := Vector2.ZERO
var _velocity := Vector2.ZERO
var _taut := true
var _target_surface := "truck"
var _impact_times: Dictionary = {}


func _init() -> void:
	reset_job(0)


func reset_job(index: int) -> void:
	job_index = index
	var outbound := posmod(index,2) == 0
	source_x = SHIP_BAY_X if outbound else TRUCK_BAY_X
	source_y = SHIP_TOP_Y if outbound else TRUCK_TOP_Y
	target_x = TRUCK_BAY_X if outbound else SHIP_BAY_X
	target_y = TRUCK_TOP_Y if outbound else SHIP_TOP_Y
	_target_surface = "truck" if outbound else "ship"
	trolley_x = source_x
	trolley_speed = 0
	hoist_speed = 0
	travel_input = 0
	hoist_input = 0
	angle = 0
	angular_velocity = 0
	rope_length = RAIL_Y - (source_y + START_CLEARANCE + BOX_HEIGHT)
	_hook = Vector2(source_x,RAIL_Y-rope_length)
	_velocity = Vector2.ZERO
	_taut = true
	rope_slack = 0
	grounded = false
	ground_surface = ""
	delivered = false
	elapsed = 0
	contacts = 0
	touch_sequence = 0
	first_touch = {}
	last_touch = {}
	last_impact = {}
	_impact_times.clear()
	settled_time = 0


func load_position() -> Vector2:
	return _hook - Vector2(0,BOX_HEIGHT/2)


func load_velocity() -> Vector2:
	return _velocity


func hook_position() -> Vector2:
	return _hook


func step(dt: float, travel_axis: float, hoist_axis: float) -> void:
	if delivered or dt<=0 or not is_finite(dt): return
	travel_input = clampf(travel_axis,-1,1)
	hoist_input = clampf(hoist_axis,-1,1)
	var count := maxi(1,ceili(dt/MAX_STEP-1e-10))
	var h := dt/count
	for i in range(count):
		_advance(h)
		if delivered: break


func _advance(h: float) -> void:
	var old_speed := trolley_speed
	var old_length := rope_length
	var old_hook := _hook
	var last_surface := ground_surface
	var travel_goal := travel_input * MAX_TRAVEL_SPEED
	var room := TROLLEY_MAX_X-trolley_x if travel_goal>=0 else trolley_x-TROLLEY_MIN_X
	var safe_speed := sqrt(2.0*TRAVEL_BRAKE*maxf(0,room))
	travel_goal = clampf(travel_goal,-safe_speed,safe_speed)
	var travel_rate := TRAVEL_BRAKE if absf(travel_goal)<absf(trolley_speed) or travel_goal*trolley_speed<0 else TRAVEL_ACCEL
	trolley_speed = move_toward(trolley_speed,travel_goal,travel_rate*h)
	var new_x := trolley_x+(old_speed+trolley_speed)*h*.5
	trolley_x = clampf(new_x,TROLLEY_MIN_X,TROLLEY_MAX_X)
	if trolley_x != new_x: trolley_speed=0
	var old_hoist := hoist_speed
	var hoist_goal := hoist_input*MAX_HOIST_SPEED
	var hoist_rate := HOIST_BRAKE if absf(hoist_goal)<absf(hoist_speed) or hoist_goal*hoist_speed<0 else HOIST_ACCEL
	hoist_speed = move_toward(hoist_speed,hoist_goal,hoist_rate*h)
	var new_length := old_length+(old_hoist+hoist_speed)*h*.5
	rope_length = clampf(new_length,MIN_ROPE_LENGTH,MAX_ROPE_LENGTH)
	if rope_length != new_length: hoist_speed=0
	var pivot := Vector2(trolley_x,RAIL_Y)
	if _taut and not grounded:
		# Prescribed pivot and variable length. The level spreader makes the
		# centre of the box translate exactly with the point at the rope end.
		var length_mid := (old_length+rope_length)*.5
		var pay_rate := (rope_length-old_length)/h
		var cart_accel := (trolley_speed-old_speed)/h
		var turn_accel := -(GRAVITY*sin(angle)+cart_accel*cos(angle))/length_mid
		turn_accel -= (ANGULAR_DAMPING+2.0*pay_rate/length_mid)*angular_velocity
		var old_turn := angular_velocity
		angular_velocity += turn_accel*h
		angle += (old_turn+angular_velocity)*h*.5
		var radial := Vector2(sin(angle),-cos(angle))
		var tangent := Vector2(cos(angle),sin(angle))
		_hook = pivot+rope_length*radial
		_velocity = Vector2(trolley_speed,0)+hoist_speed*radial+rope_length*angular_velocity*tangent
	else:
		if grounded:
			_velocity.x = move_toward(_velocity.x,0,GROUND_FRICTION*h)
			_velocity.y = 0
		else:
			_velocity.y -= GRAVITY*h
		_hook += _velocity*h
		var offset := _hook-pivot
		var radius := offset.length()
		if radius>rope_length:
			var radial := offset/radius
			_hook = pivot+rope_length*radial
			var outward := (_velocity-Vector2(trolley_speed,0)).dot(radial)-hoist_speed
			if outward>0: _velocity -= radial*outward
	var collided := _resolve_sweep(old_hook,_hook,h,last_surface)
	if collided:
		# While a vertical quay edge blocks x, the taut cable can still lift
		# the box along that edge. Satisfy both constraints in the same step.
		var dx := float(_hook.x)-trolley_x
		var drop := sqrt(maxf(0.0,rope_length*rope_length-dx*dx))
		var lowest := RAIL_Y-drop
		if _hook.y<lowest-CONTACT_EPS:
			_hook.y=lowest
			if drop>.01:
				var cable_vy := (dx*(_velocity.x-trolley_speed)-rope_length*hoist_speed)/drop
				_velocity.y=maxf(_velocity.y,cable_vy)
	ground_surface = _support_at(_hook) if _velocity.y<=.015 else ""
	grounded = not ground_surface.is_empty()
	if grounded:
		_velocity.y = 0
		if ground_surface != last_surface:
			_touch(ground_surface,_hook.x,_velocity,elapsed+h)
	var arm := _hook-pivot
	var distance := arm.length()
	rope_slack = maxf(0.0,rope_length-distance)
	var direction := arm/maxf(.001,distance)
	var tangent := Vector2(-direction.y,direction.x)
	var relative := _velocity-Vector2(trolley_speed,0)
	angle = atan2(arm.x,-arm.y)
	angular_velocity = relative.dot(tangent)/maxf(.001,distance)
	_taut = not grounded and rope_slack<CONTACT_EPS and (not collided or relative.dot(direction)>=hoist_speed-.02)
	elapsed += h
	if grounded and _on_target(ground_surface,_hook.x) and absf(_velocity.x)<=SETTLE_SPEED:
		settled_time += h
		if settled_time+1e-8>=SETTLE_SECONDS:
			delivered = true
			_velocity = Vector2.ZERO
	else:
		settled_time = 0


func _offer(best: Dictionary, t: float, normal: Vector2, surface: String) -> void:
	if t>=-1e-6 and t<=1.000001 and t<float(best.t):
		best.t = clampf(t,0,1)
		best.normal = normal
		best.surface = surface


func _first_hit(a: Vector2, b: Vector2) -> Dictionary:
	var hit := {"t":2.0,"normal":Vector2.ZERO,"surface":""}
	var d := b-a
	var half := BOX_WIDTH*.5
	for surface in SURFACES:
		var left := float(surface.left)-half
		var right := float(surface.right)+half
		var crest := float(surface.top)+BOX_HEIGHT
		if d.y < -1e-8:
			var t := 0.0 if absf(crest-a.y)<=CONTACT_EPS else (crest-a.y)/d.y
			var x := a.x+t*d.x
			if x>=left-CONTACT_EPS and x<=right+CONTACT_EPS:
				_offer(hit,t,Vector2(0,1),surface.name)
		if absf(d.x)>1e-8:
			var wall := left if d.x>0 else right
			var t := 0.0 if absf(wall-a.x)<=CONTACT_EPS else (wall-a.x)/d.x
			if a.y+t*d.y < crest-CONTACT_EPS:
				_offer(hit,t,Vector2(-signf(d.x),0),surface.name)
	if absf(d.x)>1e-8:
		var wall := WORLD_MAX_X-half if d.x>0 else WORLD_MIN_X+half
		var t := 0.0 if absf(wall-a.x)<=CONTACT_EPS else (wall-a.x)/d.x
		_offer(hit,t,Vector2(-signf(d.x),0),"boundary")
	return hit


func _resolve_sweep(a: Vector2, b: Vector2, h: float, last_surface: String) -> bool:
	var contact := false
	var begin := a
	var end := b
	var remaining := h
	for i in range(3):
		var hit := _first_hit(begin,end)
		if float(hit.t)>1: break
		var normal: Vector2=hit.normal
		var at := begin.lerp(end,float(hit.t))
		var rest := end-at
		var incoming := _velocity
		var time := elapsed+h-remaining*(1.0-float(hit.t))
		contact = true
		remaining *= 1.0-float(hit.t)
		if normal.y>0.5:
			if hit.surface!=last_surface: _touch(hit.surface,at.x,incoming,time)
			_impact(hit.surface,"top",at,incoming,maxf(-incoming.y,absf(incoming.x)*.56),time)
			_velocity.y = 0
			end = at+Vector2(rest.x,0)
		else:
			var speed := maxf(0,-incoming.dot(normal))
			_impact(hit.surface,"side",at,incoming,speed,time)
			_velocity.x = normal.x*speed*.14 if speed>.32 else 0.0
			end = at+Vector2(_velocity.x*remaining,rest.y)
		begin = at
	_hook = end
	return contact


func _support_at(point: Vector2) -> String:
	var half := BOX_WIDTH*.5
	for surface in SURFACES:
		if absf(point.y-(float(surface.top)+BOX_HEIGHT))>CONTACT_EPS: continue
		if point.x+half>float(surface.left)+CONTACT_EPS and point.x-half<float(surface.right)-CONTACT_EPS:
			return surface.name
	return ""


func _on_target(surface: String, x: float) -> bool:
	return surface==_target_surface and absf(x-target_x)+BOX_WIDTH*.5<=BAY_WIDTH*.5+CONTACT_EPS


func _touch(surface: String, x: float, velocity: Vector2, time: float) -> void:
	if not last_touch.is_empty() and last_touch.surface==surface and absf(float(last_touch.time)-time)<=MAX_STEP+.000001: return
	var top := SHIP_TOP_Y if surface=="ship" else (TRUCK_TOP_Y if surface=="truck" else SHORE_TOP_Y)
	touch_sequence += 1
	last_touch = {"time":time,"x":x,"y":top,"vx":velocity.x,"vy":velocity.y,
		"surface":surface,"target":_on_target(surface,x),"settle_speed":absf(velocity.x)<=SETTLE_SPEED}
	if first_touch.is_empty(): first_touch=last_touch.duplicate()


func _impact(surface: String, face: String, at: Vector2, velocity: Vector2, speed: float, time: float) -> void:
	var key := surface+"/"+face
	if speed<IMPACT_SPEED or time-float(_impact_times.get(key,-1000.0))<.32: return
	_impact_times[key] = time
	contacts += 1
	last_impact = {"time":time,"surface":surface,"face":face,"x":at.x,"y":at.y-BOX_HEIGHT*.5,
		"vx":velocity.x,"vy":velocity.y,"speed":speed}
