extends Node3D

signal reading(text: String)
signal cargo(amount: int, message: String)
signal recorded(report: Dictionary)

const FlightUI := preload("res://ui/skin.gd")
const ALONG := [0.23, 0.40, 0.57, 0.79]
const HALF_WIDTH := 31.0
const CATCH_RADIUS := 7.3
const HEIGHT_TOLERANCE := 14.0
const PURPLE := Color("#d0a9ff")
const GOLD := Color("#ffe3a0")
var _source: Node3D
var _case: Dictionary
var _order := PackedInt32Array()
var _next := 0
var _active := false
var _done := true
var _length := 0.0
var _previous := Vector3.ZERO
var _marker := Vector3.ZERO
var _low := 0.0
var _high := 1.0
var _mode_note := false
var _cooldown := 0.0
var _reveal := 0.0
var _visual: Node3D
var _sample: MeshInstance3D
var _target_x := 0.0
var _samples: Array = []
var _seed := 0
var _leg := 0
var _material := StandardMaterial3D.new()
var _ring := TorusMesh.new()
var _orb := SphereMesh.new()
var _font: Font

func _ready() -> void:
	_font = FlightUI.face()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = PURPLE
	_ring.inner_radius = 3.8
	_ring.outer_radius = 4.35
	_ring.rings = 20
	_ring.ring_segments = 5
	_orb.radius = 1.5
	_orb.height = 3.0
	_orb.radial_segments = 8
	_orb.rings = 3
	set_physics_process(false)

func start_leg(seed_value: int, leg: int, flight: Node3D, model: Dictionary) -> void:
	clear()
	_source = flight
	_case = model
	_seed = seed_value
	_leg = leg
	_length = flight.call("get_course_length")
	_next = 0
	_done = false
	_mode_note = false
	_cooldown = 0
	_reveal = 0
	_samples = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ str(model.key).hash() ^ (leg * 8971)
	var holdout := rng.randi_range(0, 3)
	_order.clear()
	for n in 4:
		if n != holdout:
			_order.append(n)
	_order.append(holdout)
	var outputs: PackedFloat64Array = model["values"]
	var vmin := outputs[0]
	var vmax := outputs[0]
	for v in outputs:
		vmin = minf(vmin, v)
		vmax = maxf(vmax, v)
	var span := vmax - vmin
	if span <= maxf(absf(vmin), 1e-30) * 1e-9 or span == 0:
		span = absf(vmin) * 0.6 if vmin != 0 else 1.0
	var pad := span * rng.randf_range(0.10, 0.24)
	_low = vmin - pad
	_high = vmax + span * rng.randf_range(0.10, 0.24)
	_previous = flight.call("get_pilot_transform").origin
	_station()
	set_flying(true)

func clear() -> void:
	_active = false
	_done = true
	set_physics_process(false)
	if is_instance_valid(_visual):
		remove_child(_visual)
		_visual.queue_free()
	_visual = null

func set_flying(enabled: bool) -> void:
	_active = enabled and not _done and is_instance_valid(_source)
	set_physics_process(_active)
	if _active:
		_previous = _source.call("get_pilot_transform").origin
	if _visual != null:
		_visual.visible = _active

func tune() -> void:
	if not _active:
		return
	_mode_note = not _mode_note
	_show_reading(_previous)

func format_value(v: float) -> String:
	if v == 0:
		return "0"
	var absolute := absf(v)
	if absolute < 0.001 or absolute >= 100000.0:
		var power := floori(log(absolute) / log(10.0))
		return "%.2f×10^%d" % [v / pow(10.0, power), power]
	return String.num(v, 4)

func _number_at(x: float) -> float:
	return lerpf(_low, _high, clampf((x - _marker.x + HALF_WIDTH) / (2.0 * HALF_WIDTH), 0.0, 1.0))

func _station() -> void:
	if is_instance_valid(_visual):
		remove_child(_visual)
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	_marker = _source.call("get_route_marker", _length * float(ALONG[_next]))
	_marker.y += 3.5
	_visual.position = _marker
	var output: float = _case["values"][_order[_next]]
	_target_x = lerpf(-HALF_WIDTH, HALF_WIDTH, inverse_lerp(_low, _high, output))
	var ruler := ImmediateMesh.new()
	ruler.surface_begin(Mesh.PRIMITIVE_LINES, _material)
	ruler.surface_add_vertex(Vector3(-HALF_WIDTH, -5, 0))
	ruler.surface_add_vertex(Vector3(HALF_WIDTH, -5, 0))
	for i in 9:
		var x := lerpf(-HALF_WIDTH, HALF_WIDTH, i / 8.0)
		ruler.surface_add_vertex(Vector3(x, -5, 0))
		ruler.surface_add_vertex(Vector3(x, -3 if i % 2 == 0 else -4, 0))
	ruler.surface_end()
	_add_mesh(ruler, Vector3.ZERO)
	for side in [-1, 1]:
		var post := _add_mesh(_ring, Vector3(side * HALF_WIDTH, -3.4, 0))
		post.rotation.x = PI / 2
		post.scale = Vector3.ONE * 0.38
		_mark(format_value(_low if side < 0 else _high), Vector3(side * HALF_WIDTH, 1.2, 0))
	_sample = _add_mesh(_ring, Vector3(_target_x, 0, 0))
	_sample.rotation.x = PI / 2
	var gem := MeshInstance3D.new()
	gem.mesh = _orb
	gem.material_override = _material
	_sample.add_child(gem)
	_sample.visible = _next < 3
	_mark("采样 %d" % (_next + 1) if _next < 3 else "盲接", Vector3(0, 9, 0))

func _add_mesh(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(node)
	return node

func _mark(value: String, at: Vector3) -> void:
	var tag := Label3D.new()
	tag.text = value
	tag.font = _font
	tag.font_size = 42
	tag.pixel_size = 0.055
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 8
	tag.modulate = GOLD
	tag.position = at
	_visual.add_child(tag)

func _show_reading(p: Vector3) -> void:
	if _next >= 4:
		return
	var index := _order[_next]
	if _mode_note:
		var observed := PackedStringArray()
		for row: Dictionary in _samples:
			observed.append(str(row.condition) + "→" + format_value(float(row.model)))
		reading.emit(str(_case.rule) + ("　已取 " + " / ".join(observed) if not observed.is_empty() else ""))
		return
	var display := format_value(_case["values"][index]) if _next < 3 else "？"
	reading.emit("%s %s　→　%s %s　｜　你所对的刻度 %s　·　Q / LB 匣签" % [
		_case.input, _case.tags[index], _case.output, display, format_value(_number_at(p.x))])

func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _next == 4:
		_reveal -= delta
		if _reveal <= 0:
			reading.emit("")
			clear()
		return
	var current: Vector3 = _source.call("get_pilot_transform").origin
	var ahead := current.z - _marker.z
	_visual.visible = ahead < 235.0
	_cooldown -= delta
	if _cooldown <= 0:
		_cooldown = 0.16
		if _visual.visible or _mode_note:
			_show_reading(current)
		else:
			reading.emit("")
	if _previous.z >= _marker.z and current.z <= _marker.z and current.z < _previous.z:
		var crossing := _previous.lerp(current, (_marker.z - _previous.z) / (current.z - _previous.z))
		_cross(crossing)
	_previous = current

func _cross(crossing: Vector3) -> void:
	var index := _order[_next]
	var actual: float = _case["values"][index]
	var estimate := _number_at(crossing.x)
	var lateral := crossing.x - _marker.x - _target_x
	var altitude := crossing.y - _marker.y
	var hit := absf(lateral) <= CATCH_RADIUS and absf(altitude) <= HEIGHT_TOLERANCE
	_samples.append({"condition": _case.tags[index], "model": actual, "estimate": estimate, "caught": hit,
		"lateral_m": lateral, "altitude_m": altitude})
	if _next < 3:
		if hit:
			cargo.emit(1, "采回模型样本　+1 风种")
		_next += 1
		_station()
		_mode_note = false
		_cooldown = 0
		return
	_next = 4
	_reveal = 4.0
	_sample.visible = true
	var note := "盲接命中" if hit else "擦过货点"
	if not hit:
		var difference := PackedStringArray()
		if absf(lateral) > CATCH_RADIUS:
			difference.append(("偏右" if lateral > 0 else "偏左") + " %.0f m" % absf(lateral))
		if absf(altitude) > HEIGHT_TOLERANCE:
			difference.append(("偏高" if altitude > 0 else "偏低") + " %.0f m" % absf(altitude))
		note += "，" + "、".join(difference)
	var result := "%s　预判 %s，模型 %s" % [note, format_value(estimate), format_value(actual)]
	cargo.emit(5 if hit else 0, result + ("　+5 风种" if hit else ""))
	reading.emit("%s　%s" % [_case.output, result])
	recorded.emit({"key": _case.key, "title": _case.title, "input": _case.input, "output": _case.output,
		"rule": _case.rule, "seed": _seed, "leg": _leg, "samples": _samples.duplicate(true),
		"hit": hit, "feedback": note, "low": _low, "high": _high,
		"error_fraction": absf(estimate - actual) / (_high - _low)})
