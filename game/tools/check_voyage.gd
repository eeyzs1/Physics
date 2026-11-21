extends SceneTree

# Run against the editable project or a mounted release PCK in a temporary profile.
var game
var issues: Array[String] = []

class InstrumentProbe extends Node3D:
	var course: Node3D

	func get_pilot_transform() -> Transform3D:
		return transform

	func get_course_length() -> float:
		return course.get_course_length()

	func get_route_marker(meters: float) -> Vector3:
		return course.get_route_marker(meters)

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, label: String) -> void:
	if not condition:
		issues.append(label)
		push_error("Voyage check failed: " + label)

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _axis(negative: StringName, positive: StringName, strength: float) -> void:
	Input.action_release(negative)
	Input.action_release(positive)
	if absf(strength) > 0.015:
		Input.action_press(negative if strength < 0 else positive, clampf(absf(strength), 0, 1))

func _steer(sampling: bool, miss_last: bool, befriend: bool) -> void:
	var pose: Vector3 = game.flight.get_pilot_transform().origin
	var target: Vector3 = game.flight.get_route_marker(-pose.z + 22.0)
	if sampling and game.sampling._next < 4:
		var marker: Vector3 = game.sampling._marker
		if pose.z - marker.z < 162:
			target = marker + Vector3.RIGHT * float(game.sampling._target_x)
			if miss_last and game.sampling._next == 3:
				target.x += 23 if game.sampling._target_x < 0.0 else -23
	var rising := false
	if befriend and game.flight._companion == null:
		for column: Dictionary in game.flight._thermals:
			var center: Vector3 = column.center
			if pose.z - center.z > -32 and pose.z - center.z < 128:
				target.x = center.x
				target.y = center.y + 12.0
				rising = true
				break
	var drift: Vector3 = game.values.get("wind", Vector3.ZERO)
	_axis("steer_left", "steer_right", (target.x - pose.x) * 0.055 - drift.x * 0.065)
	_axis("dive", "climb", maxf((target.y - pose.y) * 0.05, 0.0) if rising else (target.y - pose.y) * 0.065 - drift.y * 0.12)

func _fly_to_port(sampling: bool, miss_last: bool = false, befriend: bool = false) -> void:
	for step in 7500:
		if game.mode != "flight":
			break
		_steer(sampling, miss_last, befriend)
		await physics_frame
	_axis("steer_left", "steer_right", 0)
	_axis("dive", "climb", 0)
	await process_frame
	_expect(game.mode == "result" and game.leg_result.get("success", false), "arrived with cargo on leg " + str(game.leg))

func _check_instruments() -> void:
	var probe := InstrumentProbe.new()
	probe.course = game.flight
	root.add_child(probe)
	var line = game.SamplingLine.new()
	root.add_child(line)
	var reports: Array = []
	line.recorded.connect(func(report: Dictionary) -> void: reports.append(report))
	var checked := 0
	for key: String in game.catalog.by_key:
		var model: Dictionary = game.catalog.by_key[key]
		probe.position = Vector3.ZERO
		line.start_leg(361072 + checked, checked % 3, probe, model)
		for station in 4:
			var center: Vector3 = line._marker + Vector3.RIGHT * float(line._target_x)
			probe.position = center + Vector3.BACK
			line._physics_process(1.0 / 60.0)
			probe.position = center + Vector3.FORWARD
			line._physics_process(1.0 / 60.0)
		_expect(reports.size() == 1, "four physical stations for " + key)
		if not reports.is_empty():
			var report: Dictionary = reports.pop_back()
			_expect(report.key == key and report.samples.size() == 4, "four samples for " + key)
			var seen := {}
			for sample: Dictionary in report.samples:
				var index: int = model.tags.find(sample.condition)
				seen[sample.condition] = true
				_expect(index >= 0 and is_equal_approx(sample.model, model["values"][index]), "condition and model for " + key)
				_expect(sample.caught and absf(sample.estimate - sample.model) <= 0.00001 * (report.high - report.low), "physical scale for " + key)
			_expect(seen.size() == 4 and report.hit, "distinct conditions and held-out pickup for " + key)
		line.clear()
		checked += 1
		if checked % 12 == 0:
			await process_frame
	probe.queue_free()
	line.queue_free()
	await process_frame
	print("instrument crossings ", checked, " sets / ", checked * 4, " model points")

func _run() -> void:
	var scratch := OS.get_environment("WINDSEED_TEST_ROOT").replace("\\", "/").trim_suffix("/")
	var data_dir := OS.get_user_data_dir().replace("\\", "/")
	if scratch.is_empty() or not data_dir.begins_with(scratch + "/"):
		printerr("Use a new temporary WINDSEED_TEST_ROOT and redirect APPDATA or XDG_DATA_HOME into it.")
		quit(2)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_expect(game.mode == "title", "title screen")
	_expect(game.catalog.fields.size() == 26 and game.catalog.by_key.size() == 344, "344 flyable instruments")
	_expect(game.profile.last_seed == 0, "empty test profile")
	if not issues.is_empty():
		quit(1)
		return
	await _check_instruments()
	await _key(KEY_ENTER)
	_expect(game.mode == "harbor" and game.harbor.screen == "station" and game.harbor.selected == "loading", "keyboard starts a shift at the loading berth")
	await _key(KEY_ESCAPE)
	_expect(game.harbor.screen == "map", "the other stations are available immediately")
	await _key(KEY_ESCAPE)
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_expect(game.mode == "hangar", "keyboard launch from title")
	var seed_value: int = game.route_seed
	await _key(KEY_ENTER)
	_expect(game.mode == "flight" and game.mods.wing == 1, "keyboard launch from hangar")
	await _key(KEY_ESCAPE)
	var paused_at: float = game.flight_clock
	for frame in 12:
		await physics_frame
	_expect(game.mode == "pause" and game.flight_clock == paused_at, "pause freezes time")
	await _key(KEY_ESCAPE)
	await _key(KEY_TAB)
	_expect(game.mode == "library" and game.book.visible, "handbook opens in flight")
	await _key(KEY_TAB)
	_expect(game.mode == "flight" and not game.book.visible, "handbook restores flight")
	Input.action_press("dive")
	Input.action_press("fold")
	for frame in 2000:
		if game.mode != "flight":
			break
		await physics_frame
	Input.action_release("dive")
	Input.action_release("fold")
	_expect(game.mode == "result" and not game.leg_result.get("success", true), "dive into the sea offers a retry")
	await process_frame
	await _key(KEY_ENTER)
	_expect(game.mode == "flight" and game.mods.wing == 1, "retry keeps single upgrade")
	for leg in 3:
		if leg > 0:
			await _key(KEY_ENTER)
			_expect(game.mode == "hangar" and game.leg == leg, "next island")
			game._choose_kit(leg)
			await _key(KEY_ENTER)
		await _fly_to_port(false, false, leg == 1)
		print("port ", leg + 1, " gates ", game.leg_result.get("gates", 0), " cargo ", game.leg_result.get("seeds", 0))
	_expect(game.profile.voyages == 1 and game.profile.seeds > 0, "banked three-leg delivery")
	_expect(game.profile.companions.get("薄荷", 0) == 1, "thermal companion reunited and saved")
	game._home()
	await process_frame
	game._new_voyage(true)
	await process_frame
	await _key(KEY_ENTER)
	_expect(game.route_seed == seed_value and game.recorder.echo_track.size() > 16, "same route loads personal ghost")
	game._pause()
	await process_frame
	game._home()
	await process_frame
	game._open_cases()
	await process_frame
	_expect(game.mode == "cases" and game.case_list.item_count == 10, "instrument picker")
	game._load_selected_case()
	await process_frame
	_expect(game.mode == "hangar" and game.case_plan[0] == "00-0", "equips selected instrument")
	await _key(KEY_ENTER)
	_expect(game.sampling._active and not game.survey._flying and game.recorder.echo_track.is_empty(), "physical sampling fork and separate ghost")
	await _key(KEY_Q)
	_expect(game.sampling._mode_note, "instrument lookup in flight")
	await _key(KEY_TAB)
	_expect(game.book._relevant.has("00-0"), "equipped topic in handbook")
	await _key(KEY_TAB)
	await _fly_to_port(true)
	var report: Dictionary = game.case_report
	_expect(report.get("samples", []).size() == 4 and report.get("hit", false), "caught a held-out prediction by steering")
	if not report.is_empty():
		var stats: Dictionary = game.profile.case_records.get("00-0", {})
		_expect(stats.get("attempts", 0) == 1 and stats.get("hits", 0) == 1, "one recorded outcome")
		game._swap_chart()
		_expect(game.inspect_energy, "debrief toggles between model and flight energy")
		game._export_case()
		_expect(FileAccess.file_exists(game.csv_path), "saved flight CSV")
		var file := FileAccess.open(game.csv_path, FileAccess.READ)
		if file != null:
			var rows := 0
			while not file.eof_reached():
				if file.get_csv_line().size() == 14:
					rows += 1
			_expect(rows == 5, "CSV header and four player samples")
		var profile = game.Harbour.new()
		profile.load_profile()
		_expect(profile.case_records.has("00-0") and profile.last_cases == game.case_plan and profile.voyages == 1, "profile survives relaunch")
		print("blind pickup ", report.hit, " four model/flight samples; saved ", game.csv_path)
		game._home()
		await process_frame
		game._new_voyage(true)
		await process_frame
		await _key(KEY_ENTER)
		await _fly_to_port(true, true)
		var miss: Dictionary = game.case_report
		_expect(not miss.get("hit", true) and absf(miss.samples[3].lateral_m) > 7.3, "missed prediction reports lateral offset")
		_expect(game.profile.case_records["00-0"].hits == 1 and game.profile.case_records["00-0"].attempts == 2, "independent catch and miss statistics")
	game.sound.set_enabled(false)
	game.queue_free()
	await process_frame
	# The dummy mixer releases stopped voices on its separate audio thread.
	OS.delay_msec(140)
	await process_frame
	print("Voyage checks ", "passed" if issues.is_empty() else "failed")
	quit(0 if issues.is_empty() else 1)
