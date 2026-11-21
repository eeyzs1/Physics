extends Node3D

const SAMPLE_SECONDS := 0.25
const STRIDE := 8
const RIBBON_COLORS := [Color("#adebd6"), Color("#ffc486"), Color("#debbff")]
var track := PackedFloat32Array()
var samples := PackedVector3Array()
var echo_track := PackedFloat32Array()
var echo_index := 0
var echo_ship := MeshInstance3D.new()
var ribbon_mesh := ImmediateMesh.new()
var ribbon_stock := StandardMaterial3D.new()
var left_path := PackedVector3Array()
var right_path := PackedVector3Array()
var ribbon_time := 0.0
var latest_sample := -1.0
var ink := RIBBON_COLORS[0] as Color

func _ready() -> void:
	ribbon_stock.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ribbon_stock.vertex_color_use_as_albedo = true
	ribbon_stock.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon_stock.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trail := MeshInstance3D.new()
	trail.mesh = ribbon_mesh
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	var ghost_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.63, 0.94, 0.95, 0.48)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var outline := PackedVector3Array([
		Vector3(0, 0, -2), Vector3(-3, 0, 1.3), Vector3(-3, 0, 1.3), Vector3(0, 0.2, 0.5),
		Vector3(0, 0.2, 0.5), Vector3(3, 0, 1.3), Vector3(3, 0, 1.3), Vector3(0, 0, -2),
		Vector3(0, 0, -2), Vector3(0, 0.35, 2.2)])
	for vertex in outline:
		ghost_mesh.surface_add_vertex(vertex)
	ghost_mesh.surface_end()
	echo_ship.mesh = ghost_mesh
	echo_ship.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(echo_ship)
	echo_ship.hide()

func begin(record: Dictionary, show_echo: bool, ribbon_index: int) -> void:
	track.clear()
	samples.clear()
	left_path.clear()
	right_path.clear()
	latest_sample = -1.0
	ribbon_time = 0
	echo_index = 0
	echo_track = PackedFloat32Array()
	var saved = record.get("track", null)
	if show_echo and saved is PackedFloat32Array and saved.size() >= STRIDE * 2 and saved.size() % STRIDE == 0:
		echo_track = saved
	ink = RIBBON_COLORS[clampi(ribbon_index, 0, RIBBON_COLORS.size() - 1)]
	clear_visuals()
	show()

func clear_visuals() -> void:
	echo_ship.hide()
	ribbon_mesh.clear_surfaces()

func sample_pose(pose: Transform3D, elapsed: float, height: float, speed: float, force_sample: bool = false) -> void:
	if elapsed <= latest_sample or (not force_sample and elapsed - latest_sample < SAMPLE_SECONDS):
		return
	latest_sample = elapsed
	var pos := pose.origin
	var q := pose.basis.orthonormalized().get_rotation_quaternion()
	track.append_array(PackedFloat32Array([elapsed, pos.x, pos.y, pos.z, q.x, q.y, q.z, q.w]))
	samples.append(Vector3(elapsed, maxf(0, height), maxf(0, speed)))

func fly(pose: Transform3D, elapsed: float, delta: float, folded: bool) -> void:
	_update_echo(elapsed)
	ribbon_time += delta
	if ribbon_time < 0.045:
		return
	ribbon_time = 0.0
	var span := 1.95 if folded else 2.8
	var frame := pose.orthonormalized()
	left_path.append(frame * Vector3(-span, 0.0, 1.0))
	right_path.append(frame * Vector3(span, 0.0, 1.0))
	if left_path.size() > 23:
		left_path.remove_at(0)
		right_path.remove_at(0)
	ribbon_mesh.clear_surfaces()
	if left_path.size() > 1:
		_draw_ribbon(left_path)
		_draw_ribbon(right_path)

func _draw_ribbon(path: PackedVector3Array) -> void:
	ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, ribbon_stock)
	for i in path.size():
		var relative := float(i) / (path.size() - 1)
		var thickness := 0.014 + 0.072 * relative
		ribbon_mesh.surface_set_color(Color(ink, relative * 0.73))
		ribbon_mesh.surface_add_vertex(path[i] - Vector3.UP * thickness)
		ribbon_mesh.surface_set_color(Color(ink, relative * 0.73))
		ribbon_mesh.surface_add_vertex(path[i] + Vector3.UP * thickness)
	ribbon_mesh.surface_end()

func _update_echo(elapsed: float) -> void:
	if echo_track.is_empty() or elapsed < 0.5 or elapsed >= echo_track[echo_track.size() - STRIDE]:
		echo_ship.hide()
		return
	while echo_index + STRIDE * 2 < echo_track.size() and echo_track[echo_index + STRIDE] <= elapsed:
		echo_index += STRIDE
	var i := echo_index
	var j := i + STRIDE
	var t := clampf((elapsed - echo_track[i]) / maxf(echo_track[j] - echo_track[i], 0.001), 0, 1)
	var a := Vector3(echo_track[i + 1], echo_track[i + 2], echo_track[i + 3])
	var b := Vector3(echo_track[j + 1], echo_track[j + 2], echo_track[j + 3])
	var qa := Quaternion(echo_track[i + 4], echo_track[i + 5], echo_track[i + 6], echo_track[i + 7]).normalized()
	var qb := Quaternion(echo_track[j + 4], echo_track[j + 5], echo_track[j + 6], echo_track[j + 7]).normalized()
	echo_ship.transform = Transform3D(Basis(qa.slerp(qb, t)), a.lerp(b, t))
	echo_ship.show()
