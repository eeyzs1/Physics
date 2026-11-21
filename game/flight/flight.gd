extends Node3D

signal telemetry(values: Dictionary)
signal moment(kind: String, message: String)
signal finished(result: Dictionary)

const CourseScenery = preload("res://flight/scenery.gd")
const GRAVITY := 9.81
const SOUND_SPEED := 343.0
const LENGTHS := [965.0, 1145.0, 1325.0]
const LAUNCH_HEIGHTS := [82.0, 92.0, 103.0]
const GATE_COUNTS := [8, 9, 10]
const GATE_RADII := [14.0, 12.5, 11.5]
const COMPANION_NAMES := ["橘点", "薄荷", "晚星"]

var _pilot: Node3D
var _camera: Camera3D
var _course: Node3D
var _art
var _rng := RandomNumberGenerator.new()
var _gates: Array[Dictionary] = []
var _thermals: Array[Dictionary] = []
var _seeds: Array[Dictionary] = []
var _solid_islands: Array[Dictionary] = []
var _lesson_keys: Array[String] = []
var _events: Dictionary = {}
var _seed_value := 0
var _leg := 0
var _wing := 0
var _streamline := 0
var _ballast := 0
var _length := 965.0
var _launch_height := 82.0
var _course_phase := 0.0
var _wind_phase := 0.0
var _finish_x := 0.0
var _clock := 0.0
var _visual_clock := 0.0
var _air_speed := 23.5
var _vertical := 0.0
var _ground_speed := 23.5
var _wind := Vector3.ZERO
var _heading := 0.0
var _pitch := 0.0
var _bank := 0.0
var _fold := 0.0
var _fold_order := false
var _distance := 0.0
var _gate_cursor := 0
var _gate_count := 0
var _checkpoint_time := 0.0
var _checkpoint_distance := 0.0
var _checkpoint_speed := 0.0
var _seed_count := 0
var _chain := 0
var _best_chain := 0
var _thermal_index := -1
var _thermal_count := 0
var _companion: Node3D
var _harbour_ray: Node3D
var _recruit_column := -1
var _recruit_time := 0.0
var _companion_age := 0.0
var _companion_origin := Vector3.ZERO
var _companion_side := 1.0
var _companion_cheer := 0.0
var _companion_home := false
var _cross_drift := 0.0
var _dive_start := Vector2.ZERO
var _dive_active := false
var _survey_timer := 0.0
var _echo_due := -1.0
var _echo_target := -1
var _echo_distance := 0.0
var _echo_origin := Vector3.ZERO
var _survey_count := 0
var _last_echo := -1.0
var _hud_left := 0.0
var _max_height := 0.0
var _max_speed := 0.0
var _was_warned := false
var _leg_open := false
var _flying := false
var _previewing := false


func _ready() -> void:
	_ensure_nodes()
	if _course == null:
		preview()


func _ensure_nodes() -> void:
	if _art != null:
		return
	_art = CourseScenery.new()
	_art.name = "SkyAndCraft"
	add_child(_art)
	_art.setup_environment()
	_pilot = Node3D.new()
	_pilot.name = "Pilot"
	add_child(_pilot)
	_art.mount_glider(_pilot)
	_camera = Camera3D.new()
	_camera.name = "ChaseCamera"
	_camera.near = 0.18
	_camera.far = 1700.0
	_camera.fov = 65.0
	add_child(_camera)
	_camera.current = true


func preview() -> void:
	_ensure_nodes()
	_previewing = true
	_leg_open = false
	_flying = false
	_leg = 0
	_wing = 0
	_streamline = 0
	_ballast = 0
	_generate_course(17011, true)
	_clock = 0.0
	_visual_clock = 0.0
	_pilot.position = Vector3(0, _launch_height, 0)
	_pilot.rotation = Vector3(0.02, -0.12, -0.11)
	_camera.fov = 63.0
	_camera.position = _pilot.position + Vector3(4.3, 3.0, 8.4)
	_camera.look_at(_pilot.position + Vector3(-7.9, 0.8, -17.0))
	_art.pose_glider(0.0, 0.0, 0, 0, 0)


func start_leg(seed_value: int, leg_index: int, mods: Dictionary) -> void:
	_ensure_nodes()
	_leg = clampi(leg_index, 0, LENGTHS.size() - 1)
	_wing = clampi(int(mods.get("wing", 0)), 0, 8)
	_streamline = clampi(int(mods.get("streamline", 0)), 0, 8)
	_ballast = clampi(int(mods.get("ballast", 0)), 0, 8)
	_generate_course(seed_value, false)
	_previewing = false
	_leg_open = true
	_flying = true
	_clock = 0.0
	_visual_clock = 0.0
	_distance = 0.0
	_heading = 0.0
	_bank = 0.0
	_fold = 0.0
	_fold_order = false
	_thermal_index = -1
	_thermal_count = 0
	_cross_drift = 0.0
	_dive_active = false
	_gate_cursor = 0
	_gate_count = 0
	_checkpoint_time = 0.0
	_checkpoint_distance = 0.0
	_checkpoint_speed = 0.0
	_seed_count = 0
	_chain = 0
	_best_chain = 0
	_survey_timer = 0.0
	_echo_due = -1.0
	_echo_target = -1
	_last_echo = -1.0
	_survey_count = 0
	_was_warned = false
	_events.clear()
	_lesson_keys.clear()
	_air_speed = 23.5 * sqrt(_mass_ratio())
	_pitch = _trim_angle()
	_vertical = _air_speed * sin(_pitch)
	_ground_speed = _air_speed
	_wind = Vector3.ZERO
	_max_height = _launch_height
	_max_speed = _air_speed
	_pilot.position = Vector3(0, _launch_height, 0)
	_pilot.rotation = Vector3(_pitch, 0, 0)
	_art.pose_glider(0.0, 0.0, _wing, _streamline, _ballast)
	_camera.fov = 65.0
	_update_camera(1.0, true)
	_hud_left = 0.0
	_emit_telemetry()
	moment.emit("launch", "带一颗风种抵达灯塔岛")


func set_flying(enabled: bool) -> void:
	_flying = enabled and _leg_open


func get_pilot_transform() -> Transform3D:
	return _pilot.transform if _pilot != null else Transform3D.IDENTITY


func get_route_marker(distance_m: float) -> Vector3:
	var d := clampf(distance_m, 0.0, _length)
	return Vector3(_route_x(d), _low_height(d), -d)


func get_course_length() -> float:
	return _length


func add_survey_cargo(amount: int) -> void:
	if _leg_open and amount > 0:
		_seed_count += amount
		_emit_telemetry()


func get_course_keys() -> Array:
	return _lesson_keys.duplicate()


func _route_x(d: float) -> float:
	var envelope := smoothstep(0.0, 150.0, d)
	return envelope * (sin(d / 154.0 + _course_phase) * (8.0 + 4.0 * _leg)
			+ sin(d / 73.0 + _course_phase * 0.73) * (3.0 + 2.8 * _leg))


func _low_height(d: float) -> float:
	var fraction := clampf(d / _length, 0.0, 1.0)
	return _launch_height - 0.060 * d - (5.0 + _leg) * sin(fraction * PI) + 2.1 * sin(d / 111.0)


func _generate_course(seed_value: int, for_preview: bool) -> void:
	_companion = null
	_harbour_ray = null
	_recruit_column = -1
	_recruit_time = 0.0
	_companion_age = 0.0
	_companion_cheer = 0.0
	_companion_home = false
	if _course != null:
		remove_child(_course)
		_course.queue_free()
	_course = Node3D.new()
	_course.name = "Archipelago"
	add_child(_course)
	_seed_value = seed_value
	_rng.seed = seed_value ^ (7369 * (_leg + 1))
	_length = float(LENGTHS[_leg])
	_launch_height = float(LAUNCH_HEIGHTS[_leg])
	_course_phase = _rng.randf_range(-PI, PI)
	_wind_phase = _rng.randf_range(-PI, PI)
	_finish_x = _route_x(_length)
	_gates.clear()
	_thermals.clear()
	_seeds.clear()
	_solid_islands.clear()
	var gate_total := int(GATE_COUNTS[_leg])
	var gate_radius := float(GATE_RADII[_leg])
	var side := -1.0 if _rng.randi_range(0, 1) == 0 else 1.0
	for i in range(gate_total):
		var frac := float(i) / float(gate_total - 1)
		var d := lerpf(74.0, _length - 53.0, frac)
		var gate_x := _route_x(d) + _rng.randf_range(-3.0, 3.0) * smoothstep(0.0, 0.16, frac)
		var pos := Vector3(gate_x, _low_height(d), -d)
		var gate_node: Node3D = _art.make_gate(_course, pos, gate_radius, i == 0)
		_gates.append({"pos": pos, "radius": gate_radius, "node": gate_node})
		_add_seed(pos + Vector3(0, 0, 19), 1, false)
		if i % 2 == 1 and i < gate_total - 1:
			_add_seed(pos + Vector3(_rng.randf_range(-4, 4), -0.7, -18), 1, false)
		if i % 3 == 1:
			var center := pos + Vector3(side * (25.0 + 4.0 * _leg), 0, -24.0)
			var radii := Vector2(24.0 + _leg * 1.8, 69.0 + 3.0 * _leg)
			var lift := 8.0 + _leg + _rng.randf_range(0.0, 1.2)
			var height_cap := _launch_height + 39.0 + frac * 8.0
			var manta: Node3D = _art.make_thermal(_course, center, radii, height_cap, i)
			_thermals.append({"center": center, "radii": radii, "strength": lift, "cap": height_cap,
				"visited": false, "manta": manta, "phase": _rng.randf_range(0.0, TAU)})
			_add_seed(center + Vector3(0, 9.0, 20.0), 2, false)
			_add_seed(center + Vector3(-2.5 * side, 16.0, -13.0), 2, false)
			side *= -1.0
		if i % 3 == 0 and i < gate_total - 1:
			var hidden_pos := pos + Vector3(_rng.randf_range(-8, 8), 2.0, -42.0)
			_add_seed(hidden_pos, 4, true)
	_art.populate(_course, _rng, _length, _launch_height, _finish_x, _leg, _solid_islands, for_preview)
	_art.assign_light(_leg)


func _add_seed(pos: Vector3, value: int, hidden: bool) -> void:
	var item: Node3D = _art.make_seed(_course, pos, value)
	item.visible = not hidden
	_seeds.append({"pos": pos, "node": item, "value": value, "hidden": hidden, "taken": false,
		"spin": _rng.randf_range(0, TAU)})


func _mass_ratio() -> float:
	return 1.0 + 0.10 * _ballast


func _drag(v: float, fold_amount: float, bank_angle: float) -> float:
	var mass := _mass_ratio()
	var speed_squared := maxf(v * v, 49.0)
	var aspect := 1.0 + 0.12 * _wing
	var fairing := 1.0 + 0.125 * _streamline
	var parasite := 0.00072 * speed_squared / (mass * fairing) * lerpf(1.0, 0.68, fold_amount)
	var load_squared := 1.0 / maxf(pow(cos(bank_angle), 2.0), 0.40)
	var induced := 121.0 * mass * load_squared / (speed_squared * aspect) * lerpf(1.0, 1.28, fold_amount)
	return parasite + induced


func _trim_angle() -> float:
	var trim_speed := 23.5 * sqrt(_mass_ratio())
	return -asin(clampf(_drag(trim_speed, 0.0, 0.0) / GRAVITY, 0.0, 0.4))


func _flow_at(pos: Vector3) -> Vector3:
	var d := -pos.z
	var side := 0.55 + 1.12 * _leg
	var prevailing := (1.0 if _wind_phase >= 0.0 else -1.0) * float(_leg) * 1.18
	var cross := prevailing + side * (sin(d / 107.0 + _wind_phase) + 0.56 * sin(d / 251.0 - _wind_phase))
	var tail := 0.45 + (0.35 + 0.3 * _leg) * cos(d / 120.0 + _course_phase)
	var lift := 0.0
	_thermal_index = -1
	for i in range(_thermals.size()):
		var column := _thermals[i]
		var center: Vector3 = column.center
		var r: Vector2 = column.radii
		var relative := Vector2((pos.x - center.x) / r.x, (pos.z - center.z) / r.y)
		var d2 := relative.length_squared()
		if d2 < 1.0:
			var taper := 1.0 - smoothstep(float(column.cap) - 18.0, float(column.cap), pos.y)
			var w := (1.0 - d2) * (1.0 - d2) * float(column.strength) * taper
			if w > lift:
				lift = w
				_thermal_index = i
	return Vector3(cross, lift, -tail)


func _physics_process(delta: float) -> void:
	if not _flying:
		return
	var last_pos := _pilot.position
	var steer := Input.get_axis("steer_left", "steer_right")
	var pitch_input := Input.get_axis("dive", "climb")
	var folding := Input.is_action_pressed("fold")
	_clock += delta
	_fold = move_toward(_fold, 1.0 if folding else 0.0, delta * 2.7)
	_fold_order = folding
	var yaw_target := steer * deg_to_rad(37.0 - 7.0 * _fold)
	_heading = move_toward(_heading, yaw_target, delta * (0.74 + 0.048 * _wing) / sqrt(_mass_ratio()))
	var bank_target := -steer * deg_to_rad(38.0) * (1.0 - 0.16 * _fold)
	_bank = lerpf(_bank, bank_target, 1.0 - exp(-4.2 * delta))
	var stall_speed := 11.5 * sqrt(_mass_ratio() / (1.0 + 0.095 * _wing)) + 2.1 * _fold
	var authority := smoothstep(stall_speed, stall_speed + 7.2, _air_speed)
	var base_pitch := _trim_angle() - 0.108 * _fold
	var target_pitch := base_pitch + pitch_input * (0.36 if pitch_input > 0.0 else 0.45)
	var recovery_pitch := -0.31 - 0.08 * _fold
	target_pitch = lerpf(recovery_pitch, target_pitch, authority)
	_pitch = move_toward(_pitch, target_pitch, delta * (0.62 + 0.04 * _wing) / sqrt(_mass_ratio()))
	_wind = _flow_at(last_pos)
	# Air-relative flight-path angle redirects velocity. Gravity exchanges altitude and speed.
	var acceleration := -GRAVITY * sin(_pitch) - _drag(_air_speed, _fold, _bank)
	_air_speed = maxf(1.0, _air_speed + acceleration * delta)
	var flat := cos(_pitch) * _air_speed
	var air_velocity := Vector3(sin(_heading) * flat, sin(_pitch) * _air_speed, -cos(_heading) * flat)
	var ground_velocity := air_velocity + _wind
	_pilot.position = last_pos + ground_velocity * delta
	_pilot.rotation = Vector3(_pitch, -_heading, _bank)
	_vertical = ground_velocity.y
	_ground_speed = ground_velocity.length()
	_distance = maxf(0.0, -_pilot.position.z)
	_max_height = maxf(_max_height, _pilot.position.y)
	_max_speed = maxf(_max_speed, _air_speed)
	_read_flight_conditions(pitch_input, delta)
	_handle_echo(delta)
	_collect_seeds(last_pos, _pilot.position)
	_cross_gates(last_pos, _pilot.position, delta)
	_advance_companion(delta)
	_update_camera(delta, false)
	if _pilot.position.y <= 2.0:
		_end_leg(false, "翼尖触到了云海，救援艇接住了你。")
	elif _touches_rock(_pilot.position):
		_end_leg(false, "触到岛岸，救援艇接住了你。")
	elif absf(_pilot.position.x - _route_x(_distance)) > 154.0:
		_end_leg(false, "偏出了群岛航道，向导带你返航。")
	elif _distance >= _length:
		if absf(_pilot.position.x - _finish_x) > 89.0:
			_end_leg(false, "错过了灯塔岛的接引范围。")
		elif _seed_count == 0:
			_end_leg(false, "抵达灯塔岛，种囊仍是空的。")
		else:
			_end_leg(true, "风种已经送达灯塔岛。")
	else:
		_hud_left -= delta
		if _hud_left <= 0.0:
			_hud_left = 0.08
			_emit_telemetry()


func _read_flight_conditions(pitch_input: float, delta: float) -> void:
	if _fold >= 0.78:
		_first_event("fold", "翼面收拢，航迹变陡", ["01-0"])
	if (pitch_input < -0.3 or _fold_order) and _vertical < -1.2:
		if not _dive_active:
			_dive_active = true
			_dive_start = Vector2(_pilot.position.y, _air_speed)
		elif _dive_start.x - _pilot.position.y > 2.2 and _air_speed - _dive_start.y > 0.8:
			_first_event("dive_gain", "俯冲加速 · 高度换回了空速", ["01-1"])
	else:
		_dive_active = false
	_cross_drift += absf(_wind.x) * delta
	if absf(_wind.x) > 1.0 and _cross_drift > 7.0:
		_first_event("drift", "侧风正把航迹推向" + ("右" if _wind.x > 0.0 else "左"), ["00-0", "01-0"])
	if _thermal_index >= 0 and _wind.y > 2.5 and _vertical > 0.15:
		var thermal := _thermals[_thermal_index]
		if not bool(thermal.visited):
			thermal.visited = true
			_thermal_count += 1
			_seed_count += 2
			_remember(["24-536648fc", "01-1"])
			moment.emit("thermal", "热流上托  +2 风种" if _companion != null else "热流上托  +2 · 展翼爬升，小云鳐会跟来")
	if not _was_warned and _pilot.position.y < 12.0 and _vertical < -0.7:
		_was_warned = true
		moment.emit("low", "靠近云面，拉升或借青色热柱")


func _advance_companion(delta: float) -> void:
	if _companion == null:
		var rising := _thermal_index >= 0 and _wind.y > 2.5 and _vertical > 0.25
		if not rising or _fold_order or _fold > 0.15:
			_recruit_time = 0.0
			_recruit_column = -1
			return
		if _recruit_column != _thermal_index:
			_recruit_column = _thermal_index
			_recruit_time = 0.0
		_recruit_time += delta
		if _recruit_time < 1.0:
			return
		var adult: Node3D = _thermals[_thermal_index].manta
		_companion_side = 1.0 if adult.position.x >= _pilot.position.x else -1.0
		_companion_origin = adult.position + Vector3(2.8 * _companion_side, -0.9, 1.9)
		_companion = _art.make_ray(_course, _companion_origin, 0.45 + 0.045 * _leg, _leg)
		_companion.rotation = adult.rotation
		_harbour_ray = _art.make_ray(_course, Vector3(_finish_x, 22.0, -_length - 13), 0.95)
		_harbour_ray.hide()
		moment.emit("companion", "小云鳐「%s」追上来了，陪它飞回灯塔岛" % COMPANION_NAMES[_leg])
	_companion_age += delta
	_companion_cheer = maxf(0.0, _companion_cheer - delta)
	var t := _companion_age
	var forward := Vector3(sin(_heading), 0, -cos(_heading))
	var right := Vector3(cos(_heading), 0, sin(_heading)) * _companion_side
	var hop := sin(PI * _companion_cheer / 0.85)
	var formation := _pilot.position + right * (4.55 + 0.35 * sin(t * 0.8))
	formation += forward * (1.6 + 0.55 * sin(t * 0.56)) + Vector3.UP * (0.60 + 0.30 * sin(t * 1.8) + 0.7 * hop)
	var point := formation
	if t < 2.6:
		# The pup crosses from the adult's orbit to a station just outside the pilot's wingtip.
		point = _companion_origin.bezier_interpolate(
			_companion_origin + right * 2.0 + Vector3.UP * 2.2 + forward * 5.0,
			formation + right * 3.0 + Vector3.UP * 1.3, formation, t / 2.6)
	var remaining := maxf(0.0, _length - _distance)
	if remaining < 110.0 and absf(_pilot.position.x - _finish_x) < 110.0 and _seed_count > 0:
		# The harbour adult leaves the beacon and meets both flyers, even on the high approach.
		var welcome := 1.0 - smoothstep(0.0, 110.0, remaining)
		var shore := Vector3(_finish_x + 9.0 * _companion_side, 24.0, -_length - 13.0)
		var escort := _pilot.position + forward * 13.0 + right * 3.7 + Vector3.UP * 2.0
		var circle := Vector3(2.6 * cos(t * 1.27), 0.7 * sin(t * 1.32), 2.4 * sin(t * 1.27))
		_harbour_ray.show()
		_harbour_ray.position = shore.lerp(escort, welcome) + circle
		_harbour_ray.rotation = Vector3(0.06 * sin(t), -_heading - 0.20 * sin(t * 1.27), 0.17 * cos(t * 1.27))
		_art.pose_ray(_harbour_ray, 0.20 * sin(t * 2.0))
		var reunion := 1.0 - smoothstep(0.0, 53.0, remaining)
		var alongside := _harbour_ray.position + right * (3.7 * cos(t * 1.65)) + forward * (4.3 * sin(t * 1.65))
		alongside.y += 1.35 + 0.6 * sin(t * 1.45)
		point = point.lerp(alongside, reunion)
	else:
		_harbour_ray.hide()
	var travel := point - _companion.position
	if travel.length_squared() > 0.00001:
		var flat := Vector2(travel.x, travel.z).length()
		var weight := 1.0 - exp(-5.0 * delta)
		_companion.rotation.y = lerp_angle(_companion.rotation.y, atan2(-travel.x, -travel.z), weight)
		_companion.rotation.x = lerp_angle(_companion.rotation.x, clampf(atan2(travel.y, flat), -0.6, 0.6), weight)
	_companion.position = point
	_companion.rotation.z = _bank * 0.54 + 0.10 * sin(t * 1.8) + 0.27 * hop * _companion_side
	var flapping := 1.0 if t < 2.6 else 0.12 + 0.88 * smoothstep(-0.15, 0.78, sin(t * 1.13))
	_art.pose_ray(_companion, (0.31 + 0.12 * hop) * flapping * sin(t * 5.6))


func _handle_echo(delta: float) -> void:
	_survey_timer = maxf(0.0, _survey_timer - delta)
	if _echo_due >= 0.0 and _clock >= _echo_due:
		_echo_due = -1.0
		if _echo_target >= 0:
			var hidden := _seeds[_echo_target]
			hidden.hidden = false
			hidden.node.visible = true
			_last_echo = _echo_distance
			_remember(["02-1", "02-4e6d6cc9"])
			moment.emit("echo", "浮标收到回声 · 云种距发射点 %d 米" % roundi(_echo_distance))
		_echo_target = -1
	if _survey_timer > 0.0 or not InputMap.has_action("survey") or not Input.is_action_just_pressed("survey"):
		return
	_survey_timer = 3.8
	_survey_count += 1
	_echo_origin = _pilot.position
	_echo_target = -1
	_echo_distance = 188.0
	for i in range(_seeds.size()):
		var seed_item := _seeds[i]
		if not bool(seed_item.hidden) or bool(seed_item.taken):
			continue
		var target: Vector3 = seed_item.pos
		var distance := target.distance_to(_echo_origin)
		if target.z < _echo_origin.z - 4.0 and distance < _echo_distance:
			_echo_target = i
			_echo_distance = distance
	_art.survey_ripple(_course, _echo_origin)
	if _echo_target >= 0:
		_echo_due = _clock + 2.0 * _echo_distance / SOUND_SPEED
		moment.emit("survey", "浮标发出声脉冲…")
	else:
		moment.emit("survey", "前方探测范围内没有新的云种")


func _collect_seeds(from: Vector3, to: Vector3) -> void:
	var segment := to - from
	var sq := maxf(segment.length_squared(), 0.00001)
	for item in _seeds:
		if bool(item.taken) or bool(item.hidden):
			continue
		var pos: Vector3 = item.pos
		if absf(pos.z - to.z) > 10.0:
			continue
		var s := clampf((pos - from).dot(segment) / sq, 0.0, 1.0)
		if pos.distance_squared_to(from + s * segment) <= 42.25:
			item.taken = true
			var value := int(item.value)
			_seed_count += value
			_art.pick_seed(item.node)
			moment.emit("seed", ("回声云种" if value >= 4 else "风种入袋") + "  +%d" % value)


func _cross_gates(from: Vector3, to: Vector3, delta: float) -> void:
	while _gate_cursor < _gates.size():
		var gate := _gates[_gate_cursor]
		var pos: Vector3 = gate.pos
		if to.z > pos.z:
			return
		_gate_cursor += 1
		var fraction := clampf((pos.z - from.z) / minf(to.z - from.z, -0.001), 0.0, 1.0)
		var cross := from.lerp(to, fraction)
		var crossed_at := _clock - (1.0 - fraction) * delta
		var offset := Vector2(cross.x - pos.x, cross.y - pos.y)
		if offset.length() <= float(gate.radius) + 0.8:
			_checkpoint_speed = (-pos.z - _checkpoint_distance) / maxf(0.001, crossed_at - _checkpoint_time)
			_checkpoint_distance = -pos.z
			_checkpoint_time = crossed_at
			_remember(["00-0"])
			_gate_count += 1
			if _companion != null:
				_companion_cheer = 0.85
			_chain += 1
			_best_chain = maxi(_best_chain, _chain)
			var bonus := 3 if _chain % 3 == 0 else 1
			_seed_count += bonus
			_art.gate_response(gate.node, true)
			if bonus > 1:
				moment.emit("chain", "连续穿过 %d 道风门  +%d 风种" % [_chain, bonus])
			elif _gate_count == 1:
				moment.emit("gate", "首门入账  +1 · 沿航道均速 %d m/s" % roundi(_checkpoint_speed))
			else:
				moment.emit("gate", "穿过风门  +1 风种")
		else:
			var had_chain := _chain >= 2
			_chain = 0
			_art.gate_response(gate.node, false)
			if had_chain:
				moment.emit("miss", "这道风门擦身而过")


func _touches_rock(pos: Vector3) -> bool:
	for island in _solid_islands:
		var center: Vector3 = island.center
		var r := float(island.radius)
		var below := center.y + 0.55 - pos.y
		if below < 0.0 or below > r * 1.05 or absf(pos.z - center.z) > r:
			continue
		var cross_section := r * 0.71 * (1.0 - 0.72 * below / (r * 1.05))
		if Vector2(pos.x - center.x, pos.z - center.z).length_squared() < cross_section * cross_section:
			return true
	return false


func _first_event(kind: String, message: String, keys: Array) -> void:
	if _events.has(kind):
		return
	_events[kind] = true
	_remember(keys)
	moment.emit(kind, message)


func _remember(keys: Array) -> void:
	for key in keys:
		if not _lesson_keys.has(str(key)):
			_lesson_keys.append(str(key))


func _end_leg(success: bool, reason: String) -> void:
	_flying = false
	_leg_open = false
	_companion_home = success and _companion != null
	if _companion_home:
		reason += " 小云鳐「%s」和港里的鳐群汇合了。" % COMPANION_NAMES[_leg]
		moment.emit("companion_home", "「%s」回到鳐群了" % COMPANION_NAMES[_leg])
	_emit_telemetry()
	finished.emit({"success": success, "seeds": _seed_count, "gates": _gate_count,
		"time": _clock, "distance": minf(_distance, _length), "relevant_keys": _lesson_keys.duplicate(),
		"reason": reason, "seed_value": _seed_value, "leg_index": _leg, "total_gates": _gates.size(),
		"best_chain": _best_chain, "thermals": _thermal_count, "surveys": _survey_count,
		"max_height": _max_height, "max_speed": _max_speed, "companion": _companion_home,
		"companion_name": COMPANION_NAMES[_leg] if _companion_home else ""})


func _emit_telemetry() -> void:
	var next_pos := Vector3(_finish_x, 17.0, -_length)
	if _gate_cursor < _gates.size():
		next_pos = _gates[_gate_cursor].pos
	var ahead := -(_camera.to_local(next_pos).z)
	var screen := _camera.unproject_position(next_pos)
	var frame := get_viewport().get_visible_rect()
	var offset := screen - frame.get_center()
	if ahead <= 0:
		offset = -offset
	var guide := ""
	if ahead < 0 or not frame.grow(-30).has_point(screen):
		if absf(offset.x) >= absf(offset.y):
			guide = "←" if offset.x < 0 else "→"
		else:
			guide = "↑" if offset.y < 0 else "↓"
	var specific_energy := GRAVITY * maxf(0, _pilot.position.y - 2.0) + 0.5 * _air_speed * _air_speed
	var escorting := _companion != null and (_leg_open or _companion_home)
	telemetry.emit({"speed": _air_speed, "height": _pilot.position.y,
		"energy": clampf(specific_energy / (GRAVITY * (_launch_height + 14.0) + 350.0), 0.0, 1.0),
		"seeds": _seed_count, "gates": _gate_count, "total_gates": _gates.size(),
		"progress": clampf(_distance / _length, 0, 1), "in_thermal": _wind.y > 1.0, "folded": _fold > 0.60,
		"vertical": _vertical, "elapsed": _clock, "wind": _wind, "wind_x": _wind.x, "ground_speed": _ground_speed,
		"chain": _chain, "best_chain": _best_chain, "thermals": _thermal_count, "survey_cooldown": _survey_timer,
		"echo_range": _last_echo, "distance": _distance, "length": _length, "gate_dx": next_pos.x - _pilot.position.x,
		"gate_dy": next_pos.y - _pilot.position.y, "gate_ahead": _pilot.position.z - next_pos.z,
		"required_seeds": 1, "checkpoint_speed": _checkpoint_speed, "guide": guide,
		"marker": "航门" if _gate_cursor < _gates.size() else "港灯", "marker_m": _pilot.position.distance_to(next_pos),
		"companion": escorting, "companion_name": COMPANION_NAMES[_leg] if escorting else ""})


func _update_camera(delta: float, snap: bool) -> void:
	var look_heading := _heading * 0.60
	var ahead := Vector3(sin(look_heading), 0, -cos(look_heading))
	var desired := _pilot.position - ahead * 7.5 + Vector3.UP * (2.8 - 0.10 * _fold)
	var weight := 1.0 if snap else 1.0 - exp(-7.8 * delta)
	_camera.position = _camera.position.lerp(desired, weight)
	var look_point := _pilot.position + ahead * 12.0 + Vector3.UP * (0.8 + sin(_pitch) * 5.0)
	_camera.look_at(look_point)
	_camera.rotation.z = _bank * 0.055
	_camera.fov = lerpf(_camera.fov, 64.0 + clampf((_air_speed - 19.0) * 0.44, 0.0, 13.0),
		1.0 if snap else 1.0 - exp(-1.8 * delta))


func _process(delta: float) -> void:
	if _course == null or (not _previewing and not _flying):
		return
	_visual_clock += delta
	if _previewing:
		_pilot.position.y = _launch_height + 0.25 * sin(_visual_clock * 0.72)
		_pilot.rotation.z = -0.10 + 0.035 * sin(_visual_clock * 0.43)
	else:
		_art.pose_glider(_fold, _bank, _wing, _streamline, _ballast)
	for item in _seeds:
		if not bool(item.taken) and not bool(item.hidden) and absf(float(item.pos.z) - _pilot.position.z) < 215.0:
			var node: Node3D = item.node
			node.rotation.y = float(item.spin) + 1.42 * _visual_clock
			node.position.y = float(item.pos.y) + sin(_visual_clock * 2.2 + float(item.spin)) * 0.24
	for column in _thermals:
		var center: Vector3 = column.center
		if absf(center.z - _pilot.position.z) > 340.0:
			continue
		var manta: Node3D = column.manta
		var t := _visual_clock * 0.27 + float(column.phase)
		manta.position = center + Vector3(cos(t) * 9.0, 14.0 + 1.8 * sin(t * 1.4), sin(t) * 15.0)
		manta.rotation = Vector3(0.06 * cos(t * 1.4), atan2(9.0 * sin(t), -15.0 * cos(t)), -0.19)
		_art.pose_ray(manta, 0.15 * sin(_visual_clock * 1.7 + float(column.phase)))
