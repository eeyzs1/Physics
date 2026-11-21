extends Node3D

const BRASS := Color("#d4a361")
const FRAME := Color("#254953")
const ENAMEL := Color("#efe6c7")
const MINT := Color("#70ffce")
const AMBER := Color("#ffc777")

var _lens_material: StandardMaterial3D
var _analyzer: Node3D
var _needle: Node3D
var _bit_lamps: Array[StandardMaterial3D] = []
var _counter: Label3D


func build(leg: int) -> void:
	var housing := _material(FRAME)
	var edge := _material(BRASS)
	var inset := _material(ENAMEL)
	# Two open arms frame the collection lane; the instrument hangs above it.
	_rod(self, Vector3(-6.4, -1.0, 0), Vector3(-4.6, -3.6, 0), 0.22, edge)
	_rod(self, Vector3(6.4, -1.0, 0), Vector3(4.6, -3.6, 0), 0.22, edge)
	_rod(self, Vector3(-4.6, -3.6, 0), Vector3(-2.5, -3.6, 0), 0.22, inset)
	_rod(self, Vector3(4.6, -3.6, 0), Vector3(2.5, -3.6, 0), 0.22, inset)
	_cylinder(self, Vector3(0, -5.5, 0), 0.95, 0.38, 2.0, housing)
	var cap := _cylinder(self, Vector3(0, -4.35, 0), 1.15, 1.15, 0.35, edge)
	cap.rotation.y = PI / 6.0
	var gauge := Node3D.new()
	gauge.position.y = 5.2
	add_child(gauge)
	_disc(gauge, Vector3.ZERO, 3.05, 0.55, edge)
	_disc(gauge, Vector3(0, 0, 0.25), 2.76, 0.43, housing)
	match leg:
		0:
			_lens_material = _material(MINT, true)
			_disc(gauge, Vector3(0, 0, 0.52), 2.32, 0.20, _lens_material)
			_analyzer = Node3D.new()
			_analyzer.position.z = 0.70
			gauge.add_child(_analyzer)
			for row in [-1.0, 0.0, 1.0]:
				var half_width := 2.16 if row == 0.0 else 1.91
				_rod(_analyzer, Vector3(-half_width, row, 0), Vector3(half_width, row, 0), 0.07, housing)
		1:
			var pivot := Vector3(0, -1.1, 0.65)
			for tick in 7:
				var angle := deg_to_rad(60.0 - tick * 20.0)
				var ray := Vector3(sin(angle), cos(angle), 0)
				_rod(gauge, pivot + ray * 2.3, pivot + ray * 2.60, 0.068, inset)
			_needle = Node3D.new()
			_needle.position = pivot
			gauge.add_child(_needle)
			_rod(_needle, Vector3.ZERO, Vector3(0, 2.28, 0), 0.14, _material(AMBER, true))
			_disc(gauge, pivot + Vector3(0,0,0.16), 0.25, 0.18, edge)
		2:
			for side in [-1, 1]:
				var lamp := _material(FRAME, true)
				_bit_lamps.append(lamp)
				_disc(gauge, Vector3(side * 1.0, 0.65, 0.58), 0.64, 0.23, lamp)
			_counter = Label3D.new()
			_counter.position = Vector3(0, -0.88, 0.78)
			_counter.pixel_size = 0.041
			_counter.font_size = 28
			_counter.outline_size = 4
			_counter.modulate = ENAMEL
			gauge.add_child(_counter)


func show_polarization(axis_degrees: float, intensity: float) -> void:
	_analyzer.rotation.z = deg_to_rad(axis_degrees)
	_lens_material.albedo_color = Color(MINT.r * intensity, MINT.g * intensity, MINT.b * intensity)


func show_resonance(velocity_amplitude: float) -> void:
	_needle.rotation.z = deg_to_rad(lerpf(60.0, -60.0, velocity_amplitude))


func show_pair(bits: int, same: int, total: int) -> void:
	for index in 2:
		var bit := (bits >> (1 - index)) & 1
		_bit_lamps[index].albedo_color = (AMBER if bit else MINT) if total > 0 else FRAME
	_counter.text = "%d/%d" % [same, total] if total > 0 else "–"


func make_windseed() -> Node3D:
	var seed := Node3D.new()
	var gold := _material(AMBER, true)
	var stem := _material(FRAME)
	_cylinder(seed, Vector3(0, -0.30, 0), 0.37, 0.04, 0.75, gold)
	_cylinder(seed, Vector3(0, 0.20, 0), 0.10, 0.37, 0.26, gold)
	_rod(seed, Vector3(0, 0.25, 0), Vector3(-0.86, 0.70, 0.12), 0.12, stem)
	_rod(seed, Vector3(0, 0.25, 0), Vector3(0.86, 0.70, -0.12), 0.12, gold)
	return seed


func _material(color: Color, luminous: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if luminous:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 0
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	item.position = at
	parent.add_child(item)
	return item


func _disc(parent: Node3D, at: Vector3, radius: float, thickness: float, material: StandardMaterial3D) -> void:
	var item := _cylinder(parent, at, radius, radius, thickness, material)
	item.rotation.x = PI / 2.0


func _rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: StandardMaterial3D) -> void:
	var direction := end - start
	var item := _cylinder(parent, (start + end) * 0.5, radius, radius, direction.length(), material)
	item.quaternion = Quaternion(Vector3.UP, direction.normalized())
