extends Node3D

signal reading(text: String)
signal recovered(seed_bonus: int, course_keys: Array, message: String)

const SurveyBeacon = preload("res://survey/beacon.gd")
const STATION_DISTANCES := [415.0, 492.0, 570.0]
const LANE_OFFSET := 16.0
const OBSERVATION_RANGE := 315.0
const COLLECTION_WIDTH := 10.5
const COLLECTION_HEIGHT := 14.5
const ANALYZER_ANGLES := [45.0, 0.0, 90.0]
const RECEIVER_HZ := [320.0, 256.0, 400.0]
const SOURCE_HZ := [256.0, 400.0]
const DAMPING_RATIO := 0.10
const ARCHIVE_SIZE := 48
const PAIR_INTERVAL := 0.22
const COURSE_KEYS := [["05-55fe988d"], ["02-616b4509"], ["21-b9d7420b", "21-research"]]

var _flight: Node3D
var _rig: Node3D
var _beacons: Array[SurveyBeacon] = []
var _station := Vector3.ZERO
var _previous := Vector3.ZERO
var _leg := 0
var _setting := 0
var _cargo_side := 0
var _cargo_type := 0
var _flying := false
var _in_range := false
var _resolved := false
var _message_time := 0.0
var _prize: Node3D
var _prize_offset := Vector3.ZERO
var _prize_time := 0.0
var _pair_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _archive: Array[PackedByteArray] = []
var _seen: Array[int] = [0, 0]
var _same: Array[PackedInt32Array] = []


func start_leg(seed_value: int, leg: int, flight: Node3D) -> void:
	set_physics_process(false)
	_flying = false
	if is_instance_valid(_prize):
		_prize.queue_free()
		_prize = null
	if is_instance_valid(_rig):
		remove_child(_rig)
		_rig.queue_free()
	_beacons.clear()
	_flight = flight
	_leg = clampi(leg, 0, 2)
	_setting = 0
	_in_range = false
	_resolved = false
	_message_time = 0.0
	_pair_timer = 0.0
	_rng.seed = seed_value ^ (51913 * (_leg + 1))
	_cargo_side = _rng.randi_range(0, 1)
	_cargo_type = _rng.randi_range(0, 1)
	_archive.clear()
	_seen = [0, 0]
	_same = [PackedInt32Array([0, 0]), PackedInt32Array([0, 0])]
	if _leg == 2:
		_prepare_archive()

	_station = _flight.call("get_route_marker", STATION_DISTANCES[_leg])
	_station.y += 4.5
	_rig = Node3D.new()
	_rig.name = "SignalFork"
	add_child(_rig)
	_rig.global_transform = _flight.global_transform * Transform3D(Basis.IDENTITY, _station)
	for side in 2:
		var beacon := SurveyBeacon.new()
		beacon.position.x = _offset(side)
		_rig.add_child(beacon)
		beacon.build(_leg)
		_beacons.append(beacon)
	_previous = _pilot_position()
	_update_instruments()
	set_flying(true)
	reading.emit("")


func set_flying(enabled: bool) -> void:
	var was_flying := _flying
	_flying = enabled and is_instance_valid(_flight) and is_instance_valid(_rig)
	if is_instance_valid(_rig):
		_rig.visible = _flying and _in_range and not _resolved
	if is_instance_valid(_prize):
		_prize.visible = _flying
	if _flying and not was_flying:
		_previous = _pilot_position()
	set_physics_process(_flying and (not _resolved or _message_time > 0.0))


func get_course_keys() -> Array:
	return COURSE_KEYS[_leg].duplicate()


func tune() -> void:
	if not _flying or _resolved:
		return
	_setting = (_setting + 1) % (2 if _leg == 2 else 3)
	_pair_timer = 0.0
	_update_instruments()
	reading.emit(_readout())


func _physics_process(delta: float) -> void:
	if not _flying or not is_instance_valid(_flight):
		return
	if _resolved:
		if is_instance_valid(_prize):
			_animate_pickup(delta)
		_message_time -= delta
		if _message_time <= 0.0:
			reading.emit("")
			set_physics_process(false)
		return

	var current := _pilot_position()
	var distance_ahead := current.z - _station.z
	if not _in_range and distance_ahead <= OBSERVATION_RANGE:
		_in_range = true
		_rig.visible = true
		reading.emit(_readout())
	if _in_range and _leg == 2 and _seen[_setting] < ARCHIVE_SIZE:
		_pair_timer += delta
		while _pair_timer >= PAIR_INTERVAL and _seen[_setting] < ARCHIVE_SIZE:
			_pair_timer -= PAIR_INTERVAL
			_read_pair()
	# Test the crossing point, so a fast glide cannot skip a pickup between frames.
	if _previous.z >= _station.z and current.z <= _station.z and current.z < _previous.z:
		var t := (_station.z - _previous.z) / (current.z - _previous.z)
		_resolve(_previous.lerp(current, t))
	_previous = current


func _pilot_position() -> Vector3:
	var transform_value: Transform3D = _flight.call("get_pilot_transform")
	return transform_value.origin


func _offset(side: int) -> float:
	return -LANE_OFFSET if side == 0 else LANE_OFFSET


func _source_type(side: int) -> int:
	return _cargo_type if side == _cargo_side else 1 - _cargo_type


func _optical_signal(side: int) -> float:
	var difference := float(ANALYZER_ANGLES[_setting]) - _source_type(side) * 90.0
	return pow(cos(deg_to_rad(difference)), 2)


func _acoustic_signal(side: int) -> float:
	# Normalized steady-state velocity amplitude of a driven, damped oscillator.
	# The geometric-mean receiver frequency gives equal response to both bells.
	var ratio := float(SOURCE_HZ[_source_type(side)]) / float(RECEIVER_HZ[_setting])
	var damping := 2.0 * DAMPING_RATIO * ratio
	return damping / sqrt(pow(1.0 - ratio * ratio, 2) + damping * damping)


func _prepare_archive() -> void:
	# Each row comes from a fresh pair measured at both ends in the chosen basis.
	# Tuning resumes the corresponding record, rather than resampling old pairs.
	for basis in 2:
		for side in 2:
			var records := PackedByteArray()
			for sample in ARCHIVE_SIZE:
				var a := _rng.randi_range(0, 1)
				var b := a
				if basis == 1 and side != _cargo_side:
					b = _rng.randi_range(0, 1)
				records.append(2 * a + b)
			_archive.append(records)


func _read_pair() -> void:
	var index := _seen[_setting]
	for side in 2:
		var bits := int(_archive[2 * _setting + side][index])
		if bits == 0 or bits == 3:
			_same[_setting][side] += 1
	_seen[_setting] += 1
	_update_instruments()
	reading.emit(_readout())


func _update_instruments() -> void:
	for side in _beacons.size():
		match _leg:
			0:
				_beacons[side].show_polarization(ANALYZER_ANGLES[_setting], _optical_signal(side))
			1:
				_beacons[side].show_resonance(_acoustic_signal(side))
			2:
				var count := _seen[_setting]
				var bits := int(_archive[2 * _setting + side][count - 1]) if count > 0 else 0
				_beacons[side].show_pair(bits, _same[_setting][side], count)


func _readout() -> String:
	if not _in_range:
		var preset: String = ["检偏 %d°" % ANALYZER_ANGLES[_setting],
				"接收 %d Hz" % RECEIVER_HZ[_setting], "Z/Z" if _setting == 0 else "X/X"][_leg]
		return "双标在前方　读头预设 %s，接近时显示左右读数" % preset
	if _leg == 0:
		return "风种灯 %d°　检偏 %d°　左 %d%% / 右 %d%%　Q / LB 对轴，掠过亮灯" % [
			_cargo_type * 90, ANALYZER_ANGLES[_setting],
			roundi(100 * _optical_signal(0)), roundi(100 * _optical_signal(1))]
	if _leg == 1:
		return "风铃 %d Hz　接收 %d Hz　振速 左 %d%% / 右 %d%%　Q / LB 对频，掠过强铃" % [
			SOURCE_HZ[_cargo_type], RECEIVER_HZ[_setting],
			roundi(100 * _acoustic_signal(0)), roundi(100 * _acoustic_signal(1))]
	var count := _seen[_setting]
	var left := "%d/%d" % [_same[_setting][0], count] if count > 0 else "—"
	var right := "%d/%d" % [_same[_setting][1], count] if count > 0 else "—"
	var basis := "Z/Z" if _setting == 0 else "X/X"
	return "回放 · 寻 X/X 持续同号的源　%s 同号 左 %s / 右 %s　Q / LB 换基" % [basis, left, right]


func _resolve(crossing: Vector3) -> void:
	_resolved = true
	_rig.hide()
	_message_time = 6.0
	var chosen := -1
	for side in 2:
		var dx := (crossing.x - _station.x - _offset(side)) / COLLECTION_WIDTH
		var dy := (crossing.y - _station.y) / COLLECTION_HEIGHT
		if dx * dx + dy * dy <= 1.0:
			chosen = side
			break
	var explanation: String = [
		"两轴平行时全亮，夹角 45° 时半亮，垂直时熄灭。",
		"接收频率对准风铃时振速最大，偏离共振后指针下降。",
		"Z/Z 两源都同号。X/X 中理想贝尔态同号率为 100%，经典混合预期为 50%，样本会波动。",
	][_leg]
	if chosen == _cargo_side:
		var bonus := 3 + _leg
		_prize = _beacons[chosen].make_windseed()
		add_child(_prize)
		_prize_time = 0.0
		_prize_offset = _station + Vector3(_offset(chosen), -3.8, -1.5) - crossing
		_animate_pickup(0.0)
		reading.emit(explanation)
		recovered.emit(bonus, get_course_keys(), "双标风种  +%d" % bonus)
	elif chosen >= 0:
		reading.emit("捞到空匣。%s" % explanation)
	else:
		reading.emit("掠过双标。%s" % explanation)


func _animate_pickup(delta: float) -> void:
	_prize_time += delta
	var progress := minf(1.0, _prize_time / 0.65)
	var offset := _prize_offset.lerp(Vector3(0, 1, -0.6), smoothstep(0.0, 1.0, progress))
	offset += Vector3(0, 2.0, -2.0) * sin(progress * PI)
	_prize.global_position = _flight.to_global(_pilot_position() + offset)
	_prize.rotation.y = progress * TAU
	_prize.scale = Vector3.ONE * (1.0 - 0.94 * smoothstep(0.7, 1.0, progress))
	if progress >= 1.0:
		_prize.queue_free()
		_prize = null
