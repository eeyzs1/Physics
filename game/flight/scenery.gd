extends Node3D

const SKY_SOURCE = """
shader_type sky;
uniform vec4 zenith : source_color = vec4(0.27,0.60,0.71,1.0);
uniform vec4 rim : source_color = vec4(0.95,0.80,0.62,1.0);
uniform vec4 upper_cloud : source_color = vec4(1.0,0.9,0.73,1.0);
uniform vec4 horizon_haze : source_color;
uniform vec3 sun_dir = vec3(-0.45,0.26,-0.85);
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float noise21(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void sky() {
	vec3 ray = normalize(EYEDIR);
	float level=clamp(ray.y,0.0,1.0);
	vec3 col=mix(rim.rgb,zenith.rgb,smoothstep(0.0,0.68,pow(level,0.57)));
	float sun=distance(ray,normalize(sun_dir));
	col += upper_cloud.rgb * (0.21 * exp(-4.8*sun) + 0.60*(1.0-smoothstep(.045,.050,sun)));
	vec2 uv=ray.xz/max(.09,ray.y+0.09);
	float patches=noise21(uv*vec2(1.6,3.7))+0.34*noise21(uv*vec2(4.0,8.0));
	float wisps=smoothstep(.83,.97,patches)*smoothstep(.015,.16,ray.y)*(1.0-smoothstep(.64,.99,ray.y));
	col=mix(col,upper_cloud.rgb,0.34*wisps);
	COLOR=mix(horizon_haze.rgb,col,smoothstep(-.035,.17,ray.y));
}
"""

const CLOUD_SEA_SOURCE = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 shade : source_color = vec4(0.54,0.71,0.72,1.0);
uniform vec4 light : source_color = vec4(0.96,0.91,0.73,1.0);
varying vec2 field;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){
	vec2 i=floor(p),u=fract(p);u=u*u*(3.0-2.0*u);
	return mix(mix(h(i),h(i+vec2(1,0)),u.x),mix(h(i+vec2(0,1)),h(i+vec2(1)),u.x),u.y);
}
void vertex(){field=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
	vec2 uv=field*vec2(.008,.015);
	uv.x+=.65*n(uv*.41);
	float f=n(uv)*.61+n(uv*2.07)*.28+n(uv*4.17)*.11;
	float tops=smoothstep(.24,.76,f);
	float facing=clamp((f-n(uv+vec2(-.10,.16)))*2.5,-.12,.12);
	ALBEDO=mix(shade.rgb,light.rgb,clamp(.12+.71*tops+facing,0.0,1.0));
}
"""

const CLOUD_BANK_SOURCE = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 shade : source_color;
uniform vec4 light : source_color;
varying float sunlight;
void vertex() {
	// The billows are very wide. Shade their original round profile so each crest has a readable near side.
	vec3 normal=normalize(MODEL_MATRIX[0].xyz)*NORMAL.x+normalize(MODEL_MATRIX[1].xyz)*NORMAL.y+normalize(MODEL_MATRIX[2].xyz)*NORMAL.z;
	sunlight=dot(normalize(normal),normalize(vec3(-.56,.78,-.28)));
}
void fragment() {
	float crest=smoothstep(-.42,.94,sunlight);
	ALBEDO=mix(shade.rgb,light.rgb,.08+.88*crest);
}
"""

const WIND_SOURCE = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color;
varying float across;
void vertex(){across=float(VERTEX_ID%2);}
void fragment() {
	float border=smoothstep(0.0,.13,across)*(1.0-smoothstep(.78,1.0,across));
	float near_fade=mix(.04,1.0,smoothstep(6.0,66.0,length(VERTEX)));
	ALBEDO=tint.rgb;
	ALPHA=tint.a*near_fade*(.22+.78*border);
}
"""

const JUVENILE_SOURCE = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 ink : source_color;
uniform vec4 back_colour : source_color;
uniform vec4 belly : source_color;
void fragment() {
	float value = dot(COLOR.rgb, vec3(.23, .57, .20));
	vec3 base = mix(ink.rgb, back_colour.rgb, smoothstep(.025, .50, value));
	ALBEDO = mix(base, belly.rgb, smoothstep(.53, .91, value));
	ROUGHNESS = .85;
	SPECULAR = .17;
}
"""

var _models: Dictionary = {}
var _prepared_paints: Dictionary = {}
var _materials: Dictionary = {}
var _box := BoxMesh.new()
var _ball := SphereMesh.new()
var _rod := CylinderMesh.new()
var _spike := CylinderMesh.new()
var _environment: Environment
var _sky_mat: ShaderMaterial
var _sea_mat: ShaderMaterial
var _bank_mat: ShaderMaterial
var _wind_mat: ShaderMaterial
var _wind_glint: ShaderMaterial
var _sun: DirectionalLight3D
var _craft: Node3D
var _wing_left: Node3D
var _wing_right: Node3D
var _fairing: Node3D
var _weights: Node3D
var _ring_meshes: Dictionary = {}
var _juvenile_shader: Shader
var _juvenile_materials: Dictionary = {}


func setup_environment() -> void:
	_box.size = Vector3.ONE
	_ball.radial_segments = 10
	_ball.rings = 4
	_ball.radius = 0.5
	_ball.height = 1.0
	_rod.radial_segments = 8
	_rod.rings = 1
	_rod.top_radius = 1.0
	_rod.bottom_radius = 1.0
	_rod.height = 1.0
	_spike.radial_segments = 8
	_spike.rings = 1
	_spike.top_radius = 0.0
	_spike.bottom_radius = 1.0
	_spike.height = 1.0
	for key in ["glider", "manta", "island", "beacon"]:
		var path := "res://art/%s.glb" % key
		if ResourceLoader.exists(path):
			var model := ResourceLoader.load(path, "PackedScene")
			if model is PackedScene:
				_models[key] = model
	var sky_shader := Shader.new()
	sky_shader.code = SKY_SOURCE
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = sky_shader
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.sky_material = _sky_mat
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_energy = 0.46
	_environment.ambient_light_sky_contribution = 0.22
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.fog_enabled = true
	_environment.fog_density = 0.00155
	_environment.fog_light_energy = 0.88
	_environment.fog_sky_affect = 0.07
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_exposure = 0.89
	_environment.tonemap_white = 2.5
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.name = "LateLight"
	_sun.rotation_degrees = Vector3(-38, -38, 0)
	_sun.light_energy = 0.82
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 120.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(_sun)
	var bounce := DirectionalLight3D.new()
	bounce.rotation_degrees = Vector3(-22, 148, 0)
	bounce.light_color = Color("#a7d9e2")
	bounce.light_energy = 0.16
	add_child(bounce)
	var sea_shader := Shader.new()
	sea_shader.code = CLOUD_SEA_SOURCE
	_sea_mat = ShaderMaterial.new()
	_sea_mat.shader = sea_shader
	var bank_shader := Shader.new()
	bank_shader.code = CLOUD_BANK_SOURCE
	_bank_mat = ShaderMaterial.new()
	_bank_mat.shader = bank_shader
	var wind_shader := Shader.new()
	wind_shader.code = WIND_SOURCE
	_wind_mat = ShaderMaterial.new()
	_wind_mat.shader = wind_shader
	_wind_mat.set_shader_parameter("tint", Color("#248e91a1"))
	_wind_glint = ShaderMaterial.new()
	_wind_glint.shader = wind_shader
	_wind_glint.set_shader_parameter("tint", Color("#73cdb4a8"))
	assign_light(0)


func assign_light(leg: int) -> void:
	var palettes := [
		["#2f829d", "#efd5ab", "#ffedcc", "#356a77", "#97bbaf", "#bdd2d0", "#ffebcf", "#abc5c2", "#4a8089", "#bdd4c0"],
		["#30799b", "#c5dace", "#e6eacb", "#336c80", "#8ab6b6", "#c0d1d5", "#f6e5cb", "#a3bcc6", "#467a8d", "#b2d1c6"],
		["#676c99", "#e8bb9d", "#ffe3bd", "#526381", "#aba9a7", "#cfc7ca", "#ffdabd", "#b9b0bb", "#707a96", "#cbbfbc"]
	]
	var p: Array = palettes[clampi(leg, 0, 2)]
	_sky_mat.set_shader_parameter("zenith", Color(p[0]))
	_sky_mat.set_shader_parameter("rim", Color(p[1]))
	_sky_mat.set_shader_parameter("upper_cloud", Color(p[2]))
	_sky_mat.set_shader_parameter("horizon_haze", Color(p[7]))
	_sky_mat.set_shader_parameter("sun_dir", Vector3(-0.48 + 0.14 * leg, 0.26 - 0.045 * leg, -0.84).normalized())
	_sea_mat.set_shader_parameter("shade", Color(p[3]))
	_sea_mat.set_shader_parameter("light", Color(p[4]))
	_bank_mat.set_shader_parameter("shade", Color(p[8]))
	_bank_mat.set_shader_parameter("light", Color(p[9]))
	_environment.ambient_light_color = Color(p[5])
	_environment.fog_light_color = Color(p[7])
	_sun.light_color = Color(p[6])


func _mat(key: String, code: String, unlit := false, glow := 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	var color := Color(code)
	material.albedo_color = color
	material.roughness = 0.88
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unlit:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = glow
	_materials[key] = material
	return material


func _mesh(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, size: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	part.scale = size
	parent.add_child(part)
	return part


func _root_at(parent: Node3D, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	parent.add_child(node)
	return node


func _model(key: String, parent: Node3D, pos: Vector3) -> Node3D:
	var packed := _models.get(key) as PackedScene
	if packed == null:
		return _root_at(parent, pos)
	var item := packed.instantiate() as Node3D
	if not _prepared_paints.has(key):
		# Some imported surfaces retain COLOR_0 but leave its material switch off.
		# Their mesh resources are shared by every instance of this model.
		for part in item.find_children("*", "MeshInstance3D", true, false):
			var mesh := (part as MeshInstance3D).mesh as ArrayMesh
			if mesh == null:
				continue
			for surface in range(mesh.get_surface_count()):
				var paint := mesh.surface_get_material(surface) as StandardMaterial3D
				if paint != null and (mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR) != 0:
					paint.vertex_color_use_as_albedo = true
		_prepared_paints[key] = true
	parent.add_child(item)
	item.position = pos
	return item


func _ribbon(parent: Node3D, edge_a: PackedVector3Array, edge_b: PackedVector3Array, material: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	for i in range(edge_a.size()):
		vertices.append(edge_a[i])
		vertices.append(edge_b[i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	var strip := _mesh(parent, mesh, material, Vector3.ZERO)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return strip


func mount_glider(pilot: Node3D) -> void:
	_craft = _model("glider", pilot, Vector3.ZERO)
	if not _models.has("glider"):
		var hull_mat := _mat("hull", "#774a3d")
		var sail := _mat("linen", "#f0d995", true)
		var orange := _mat("coral", "#e1784d", true)
		_mesh(_craft, _ball, hull_mat, Vector3(0, -0.13, -0.08), Vector3(0.75, 0.65, 3.15))
		for sign_value in [-1, 1]:
			var side := float(sign_value)
			var wing := _root_at(_craft, Vector3(0.34 * side, 0.19, -0.14))
			wing.name = "WingL" if side < 0 else "WingR"
			_ribbon(wing, PackedVector3Array([Vector3(0,0,-0.6),Vector3(1.4*side,0.10,-0.25),Vector3(2.9*side,0.28,0.30)]),
				PackedVector3Array([Vector3(0,0,0.85),Vector3(1.4*side,0.06,0.85),Vector3(2.9*side,0.28,0.46)]), sail)
			_mesh(wing, _box, orange, Vector3(1.45 * side, 0.13, 0), Vector3(2.8, 0.08, 0.11))
		_mesh(_craft, _box, orange, Vector3(0,0.1,1.3), Vector3(1.6,0.07,0.42))
	_wing_left = _craft.find_child("WingL", true, false) as Node3D
	_wing_right = _craft.find_child("WingR", true, false) as Node3D
	_fairing = _mesh(_craft, _ball, _mat("upgrade_teal", "#497e81"), Vector3(0,-0.09,-0.88), Vector3(.46,.35,.95))
	_weights = _root_at(_craft, Vector3(0,-0.30,0.34))
	for side in [-1, 1]:
		var weight := _mesh(_weights, _ball, _mat("copper", "#aa754c"), Vector3(0.23*float(side),0,0), Vector3(.27,.34,.60))
		weight.rotation.z = float(side)*.15
	pose_glider(0.0, 0.0, 0, 0, 0)


func pose_glider(fold: float, bank: float, wing: int, fairing: int, ballast: int) -> void:
	if _wing_left != null and _wing_right != null:
		var extension := 1.0 + 0.075 * minf(wing, 5)
		var sweep := 0.80 * fold
		_wing_left.rotation.y = sweep
		_wing_right.rotation.y = -sweep
		_wing_left.rotation.z = -0.16 * fold - bank * 0.032
		_wing_right.rotation.z = 0.16 * fold - bank * 0.032
		_wing_left.scale.x = extension
		_wing_right.scale.x = extension
	else:
		_craft.scale.x = (1.0 + 0.06 * wing) * lerpf(1.0, 0.64, fold)
	_fairing.visible = fairing > 0
	_weights.visible = ballast > 0


func _ring(radius: float, thickness: float) -> TorusMesh:
	var key := Vector2(radius, thickness)
	if _ring_meshes.has(key):
		return _ring_meshes[key]
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	_ring_meshes[key] = mesh
	return mesh


func make_gate(parent: Node3D, pos: Vector3, radius: float, first: bool) -> Node3D:
	var frame := _root_at(parent, pos)
	var amber := _mat("gold_gate", "#b96335", true)
	var ivory := _mat("sign_white", "#ffecb3", true)
	var iron := _mat("dark_brass", "#694b45")
	var hoop := _mesh(frame, _ring(radius, 0.50), amber, Vector3.ZERO)
	hoop.rotation.x = PI * 0.5
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var bracket := _mesh(frame, _box, ivory if i % 2 == 0 else iron,
			Vector3(radius * cos(a), radius * sin(a), 0), Vector3(0.75, 1.38, 0.9))
		bracket.rotation.z = a
	for side in [-1.0, 1.0]:
		var x := radius * float(side)
		var tail := _mat("flag_brick", "#c25f40", true)
		var flap := 3.4 if first else 2.8
		_ribbon(frame, PackedVector3Array([Vector3(x, 0, 0),Vector3(x+.8*side,-1.4,-2),Vector3(x+.4*side,-2.8,-flap)]),
			PackedVector3Array([Vector3(x, -2.1, .2),Vector3(x+.9*side,-3,-2),Vector3(x+.35*side,-3.2,-flap)]), tail)
	return frame


func gate_response(gate: Node3D, hit: bool) -> void:
	if hit:
		var tw := gate.create_tween()
		tw.tween_property(gate, "scale", Vector3.ONE * 1.10, 0.17).set_trans(Tween.TRANS_SINE)
		tw.tween_property(gate, "scale", Vector3.ONE, 0.28)


func make_seed(parent: Node3D, pos: Vector3, amount: int) -> Node3D:
	var root := _root_at(parent, pos)
	var shell := _mat("seed_gold", "#f8bb51", false, .14)
	var leaf := _mat("seed_leaf", "#698d70", false, .10)
	if amount >= 4:
		shell = _mat("pearl", "#efc7ff", false, .42)
		leaf = _mat("pearl_leaf", "#9974ac", false, .1)
	elif amount == 2:
		shell = _mat("thermal_seed", "#cafaaf", false, .26)
	var kernel := _mesh(root, _ball, shell, Vector3.ZERO, Vector3(1.22, 1.95, 1.22))
	kernel.rotation.z = -.21
	for side in [-1.0, 1.0]:
		var plume := _mesh(root, _ball, leaf, Vector3(.56*side,.79,0), Vector3(.52,1.7,.35))
		plume.rotation.z = -side * .72
	return root


func pick_seed(item: Node3D) -> void:
	var tw := item.create_tween()
	tw.tween_property(item, "scale", Vector3.ONE*1.48, .07)
	tw.tween_property(item, "scale", Vector3.ONE*.02, .13)
	tw.tween_callback(item.queue_free)


func make_thermal(parent: Node3D, center: Vector3, radii: Vector2, cap: float, number: int) -> Node3D:
	var spool := _root_at(parent, Vector3(center.x, 0, center.z))
	for arm in range(3):
		var edge_a := PackedVector3Array()
		var edge_b := PackedVector3Array()
		for i in range(57):
			var u := float(i) / 56.0
			var a := u*TAU*1.65 + arm*TAU/3.0 + number*.57
			var radial := .58 + .13 * sin(u*PI)
			var p := Vector3(cos(a)*radii.x*radial, 3.0+u*(cap-8.0), sin(a)*radii.y*radial)
			var w := 0.12 + sin(PI*u)*1.22
			edge_a.append(p)
			edge_b.append(p + Vector3(.4*cos(a),w,.4*sin(a)))
		_ribbon(spool, edge_a, edge_b, _wind_glint if arm == 0 else _wind_mat)
	return make_ray(parent, center + Vector3.UP * 15, 1.22)


func make_ray(parent: Node3D, pos: Vector3, size: float, juvenile: int = -1) -> Node3D:
	var ray := _model("manta", parent, pos)
	if not _models.has("manta"):
		var colours := ["#d67d4f", "#50a6a0", "#9272b6"]
		var manta_mat := _mat("manta_back", "#387c86", true) if juvenile < 0 else _mat(
			"juvenile_fallback_%d" % juvenile, colours[juvenile], true)
		_mesh(ray, _ball, manta_mat, Vector3.ZERO, Vector3(2.5,.67,3))
		for side in [-1.0, 1.0]:
			var fin := _root_at(ray, Vector3.ZERO)
			fin.name = "FinL" if side < 0 else "FinR"
			_ribbon(fin, PackedVector3Array([Vector3(0,0,-1),Vector3(2.0*side,.15,-.35),Vector3(4.2*side,.1,.8)]),
				PackedVector3Array([Vector3(0,0,1),Vector3(2.0*side,-.2,1.1),Vector3(4.2*side,.1,.8)]), manta_mat)
		_mesh(ray, _ball, manta_mat, Vector3(0,0,2.1), Vector3(.25,.20,3.6))
	elif juvenile >= 0:
		_colour_juvenile(ray, juvenile)
	var fin_l := ray.find_child("FinL", true, false) as Node3D
	var fin_r := ray.find_child("FinR", true, false) as Node3D
	if fin_l != null and fin_r != null:
		ray.set_meta("left_fin", fin_l)
		ray.set_meta("right_fin", fin_r)
	ray.scale *= size
	return ray


func _colour_juvenile(ray: Node3D, index: int) -> void:
	var palettes := [["#693d33", "#dc8252", "#ffe2ad", "#fff19c"],
		["#275267", "#51aa9b", "#deefcc", "#d0ffbe"],
		["#4c426b", "#9a7eb8", "#f4ddd1", "#ffdd92"]]
	var palette: Array = palettes[index]
	if not _juvenile_materials.has(index):
		if _juvenile_shader == null:
			_juvenile_shader = Shader.new()
			_juvenile_shader.code = JUVENILE_SOURCE
		var coat := ShaderMaterial.new()
		coat.shader = _juvenile_shader
		coat.set_shader_parameter("ink", Color(palette[0]))
		coat.set_shader_parameter("back_colour", Color(palette[1]))
		coat.set_shader_parameter("belly", Color(palette[2]))
		_juvenile_materials[index] = coat
	var spots := _mat("juvenile_spots_%d" % index, palette[3], true)
	for child in ray.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		for surface in range(mesh_node.mesh.get_surface_count()):
			var original := mesh_node.get_active_material(surface)
			var is_spot := original != null and "phosphor" in original.resource_name.to_lower()
			mesh_node.set_surface_override_material(surface, spots if is_spot else _juvenile_materials[index])


func pose_ray(ray: Node3D, beat: float) -> void:
	if ray.has_meta("left_fin"):
		var left: Node3D = ray.get_meta("left_fin")
		var right: Node3D = ray.get_meta("right_fin")
		left.rotation.z = -beat
		right.rotation.z = beat


func survey_ripple(parent: Node3D, pos: Vector3) -> void:
	var ring := _mesh(parent, _ring(1.0,0.007), _mat("sonar", "#b4f1fa8a", true), pos, Vector3.ONE*2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(180,1,180), .53)
	tw.tween_callback(ring.queue_free)


func _island(parent: Node3D, pos: Vector3, radius: float, angle: float, high: float = 1.0) -> Node3D:
	var island := _model("island", parent, pos)
	if not _models.has("island"):
		var turf := _mat("turf", "#96a774")
		var shale := _mat("shale", "#6c6060")
		_mesh(island, _rod, turf, Vector3(0,-.35,0), Vector3(5.8,.7,5.7))
		var rocks := _mesh(island, _spike, shale, Vector3(0,-3.7,0), Vector3(5.8,7.2,5.6))
		rocks.rotation.x = PI
	island.rotation.y = angle
	island.scale = Vector3(radius/6.0, radius*high/6.0, radius/6.0)
	return island


func _beacon(parent: Node3D, pos: Vector3, size: float) -> Node3D:
	var station := _model("beacon", parent, pos)
	if not _models.has("beacon"):
		_mesh(station, _rod, _mat("tower", "#77675c"), Vector3.UP*2.0, Vector3(.50,4.0,.50))
		_mesh(station, _ball, _mat("lamp", "#ffe79a", true), Vector3.UP*4.4, Vector3(1.9,1.8,1.9))
		_mesh(station, _spike, _mat("tower_cap", "#ad6d4e"), Vector3.UP*5.7, Vector3(1.3,1.6,1.3))
	station.scale *= size
	return station


func _cloud_bank(parent: Node3D, rng: RandomNumberGenerator, length: float) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(2800, length+2450.0)
	var sea := _mesh(parent, mesh, _sea_mat, Vector3(0,-19,-length*.47))
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for layer in range(3):
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = _ball
		instances.instance_count = 60
		var cloud := MultiMeshInstance3D.new()
		cloud.multimesh = instances
		cloud.material_override = _bank_mat
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(cloud)
		for n in range(instances.instance_count):
			var d := rng.randf_range(-230,length+530.0)
			var x := rng.randf_range(-450,450)
			var y := rng.randf_range(-19,-10) + layer*.8
			var scale_3d := Vector3(rng.randf_range(43,123),rng.randf_range(10,20),rng.randf_range(30,99))
			var basis := Basis(Vector3.UP, rng.randf_range(-.55,.55)).scaled_local(scale_3d)
			instances.set_instance_transform(n, Transform3D(basis, Vector3(x,y,-d)))


func _standing_rock(parent: Node3D, at: Vector3, radius: float, h: float, twist: float) -> void:
	# Wind-cut fins rise above the cloud bank. Unequal ledges cast readable, faceted shadows.
	var rings: Array[PackedVector3Array] = []
	var ring_heights := [0.0, 0.49, 0.78, 0.92, 1.0]
	var ring_widths := [1.0, 0.87, 0.69, 0.66, 0.38]
	for level in range(ring_heights.size()):
		var loop := PackedVector3Array()
		var v := float(ring_heights[level])
		for j in range(7):
			var a := TAU * float(j)/7.0 + twist + v*.12
			var irregular := 1.0 + .10*sin(3.0*a + twist)
			var r := radius * float(ring_widths[level]) * irregular
			loop.append(Vector3(cos(a)*r + v*radius*.13, v*h + sin(a)*v*radius*.20, sin(a)*r*.74))
		rings.append(loop)
	var builders: Array[SurfaceTool] = []
	var faces := [_mat("spire_warm", "#896955"), _mat("spire_mid", "#596972"), _mat("spire_rim", "#ac7957"), _mat("spire_cap", "#75866e")]
	for material in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(material)
		st.set_smooth_group(-1)
		builders.append(st)
	for j in range(7):
		var k := (j+1)%7
		for level in range(4):
			var texture := 2 if level == 2 else (j + int(twist*9.0)) % 2
			var st := builders[absi(texture)]
			var a := rings[level][j]
			var b := rings[level][k]
			var c := rings[level+1][j]
			var d := rings[level+1][k]
			for point in [a,b,c, b,d,c]: st.add_vertex(point)
		for point in [rings[4][j],rings[4][k],Vector3(radius*.13,h,0)]: builders[3].add_vertex(point)
	var out := ArrayMesh.new()
	for st in builders:
		st.generate_normals()
		st.commit(out)
	_mesh(parent, out, null, at)


func _landmarks(parent: Node3D, near_length: float, launch_y: float, rng: RandomNumberGenerator) -> void:
	var d := 184.0
	var side := 1.0
	while d < near_length + 340.0:
		var h := rng.randf_range(76.0,110.0) + launch_y*.47
		var x := side * rng.randf_range(169.0,205.0)
		var at := Vector3(x, -15.0, -d)
		_standing_rock(parent, at, rng.randf_range(20.0,31.0), h, rng.randf_range(0,PI))
		_standing_rock(parent, at + Vector3(22.0*side,0,-26.0), 18.0, h*.72, rng.randf_range(0,PI))
		_standing_rock(parent, at + Vector3(-14.0*side,0,27.0), 13.0, h*.52, rng.randf_range(0,PI))
		d += rng.randf_range(258.0,338.0)
		side *= -1.0


func populate(parent: Node3D, rng: RandomNumberGenerator, length: float, launch_y: float, finish_x: float,
		leg: int, rocks: Array[Dictionary], for_preview: bool) -> void:
	_cloud_bank(parent, rng, length)
	var near_length := minf(length, 510.0) if for_preview else length
	_landmarks(parent, near_length, launch_y, rng)
	var launch := Vector3(-3, launch_y - 5.4, 17)
	_island(parent, launch, 15, -.28)
	rocks.append({"center":launch,"radius":15.0})
	_beacon(parent, launch+Vector3(-8,0,1), .88)
	var d := 61.0
	while d < near_length + 100.0:
		for side in [-1.0, 1.0]:
			var radius := rng.randf_range(13.0, 31.0)
			var offset := rng.randf_range(0.0, 28.0)
			var x := float(side) * (45.0 + radius + rng.randf_range(0.0,24.0))
			var roof_y := lerpf(launch_y - 16.0, 23.0, clampf(d / length,0,1)) + rng.randf_range(-19.0,10.0)
			var center := Vector3(x,roof_y,-d-offset)
			_island(parent,center,radius,rng.randf_range(-PI,PI),rng.randf_range(0.82,1.30))
			rocks.append({"center":center,"radius":radius})
			if rng.randf() < .57:
				_beacon(parent,center+Vector3(radius*.09,0,-radius*.15),rng.randf_range(.70,1.1))
		d += rng.randf_range(96.0,133.0)
	var far_d := -55.0
	while far_d < near_length + 410.0:
		for side in [-1.0,1.0]:
			var x := float(side)*rng.randf_range(175,360)
			var center := Vector3(x,rng.randf_range(5.0,52.0),-far_d-rng.randf_range(-47,47))
			_island(parent,center,rng.randf_range(30,72),rng.randf_range(-PI,PI),rng.randf_range(.60,1.12))
		far_d += rng.randf_range(172,228)
	if for_preview:
		return
	var landing := Vector3(finish_x, 10.5, -length-23.0)
	_island(parent, landing, 36.0, 0.4)
	rocks.append({"center": landing,"radius":36.0})
	_beacon(parent, landing+Vector3(-11,0,-1), 2.4)
	_beacon(parent, landing+Vector3(15,0,2), 1.3)
	var sail := _mat("arrival_flag", "#edba70", true)
	for side in [-1.0,1.0]:
		var base := landing + Vector3(26*side,0,15)
		_mesh(parent, _rod, _mat("dock_pole", "#78634f"), base+Vector3.UP*7,Vector3(.24,14,.24))
		_ribbon(parent, PackedVector3Array([base+Vector3(0,13.5,0),base+Vector3(2.5*side,13.0,-2),base+Vector3(5*side,11.6,-4)]),
			PackedVector3Array([base+Vector3(0,10.1,0),base+Vector3(2.5*side,10.8,-2),base+Vector3(5*side,11.6,-4)]), sail)
