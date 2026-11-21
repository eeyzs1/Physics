extends SceneTree

var game
var station
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		push_error("Loading check: " + message)
	return condition


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _tap(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(2)


func _mouse_motion(point: Vector2, dragging: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if dragging else 0
	root.push_input(motion, true)
	await _frames(2)


func _mouse_button(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event, true)
	await _frames(2)


func _click(point: Vector2) -> void:
	await _mouse_motion(point)
	await _mouse_button(point, true)
	await _mouse_button(point, false)


func _button(caption: String) -> Button:
	for button: Button in station.find_children("*", "Button", true, false):
		if button.text.begins_with(caption) and button.is_visible_in_tree() and not button.disabled:
			return button
	return null


func _activate(caption: String) -> bool:
	var button := _button(caption)
	if not _expect(button != null, "active control for " + caption):
		return false
	button.grab_focus()
	await _tap(KEY_ENTER)
	return true


func _wait_phase(expected: String) -> bool:
	for frame in 480:
		if station.phase == expected:
			return true
		await process_frame
	return _expect(false, "wait for %s, still in %s" % [expected, station.phase])


func _near(a: float, b: float) -> bool:
	return absf(a - b) < 0.002


func _aim_with_mouse(x: float) -> bool:
	var view: Control = station.view
	var deck_point := Vector2(station.view.x_to_pixel(x), station.view.deck_y())
	await _click(view.get_global_transform_with_canvas() * deck_point)
	return _expect(_near(station.cursor_x, x), "a click on the painted deck aims at %.1f m" % x)


func _aim_with_keys(x: float) -> bool:
	for step in 60:
		var before: float = station.cursor_x
		if _near(before, x):
			return true
		await _tap(KEY_D if x > before else KEY_A)
		if not _expect(not _near(before, station.cursor_x), "a horizontal control moves the landing mark"):
			return false
	return _expect(false, "can reach the requested %.1f m mark one division at a time" % x)


func _lift(index: int, by_mouse: bool = false) -> bool:
	if by_mouse:
		var view: Control = station.view
		var local_point: Vector2 = station.view.cargo_center(index)
		await _click(view.get_global_transform_with_canvas() * local_point)
	else:
		await _tap(KEY_1 if index == 0 else KEY_2)
		await _tap(KEY_SPACE)
	if not _expect(station.selected == index, "the operator can select cargo %d" % (index + 1)):
		return false
	if not await _wait_phase("carrying"):
		return false
	return _expect(station.held == index and station.model.held_index == index and not station.model.cargo[index].on_bed,
		"the hook really takes the selected cargo off its support")


func _land(index: int, x: float, by_mouse: bool = false) -> bool:
	var aimed: bool = await _aim_with_mouse(x) if by_mouse else await _aim_with_keys(x)
	if not aimed:
		return false
	await _tap(KEY_SPACE)
	if not await _wait_phase("ready"):
		return false
	var cargo: Dictionary = station.model.cargo[index]
	return _expect(cargo.on_bed and _near(cargo.x, x) and station.model.held_index == -1,
		"cargo %d rests on its chosen %.1f m mark" % [index + 1, x])


func _drag_first_box() -> bool:
	var view: Control = station.view
	var transform := view.get_global_transform_with_canvas()
	var pickup: Vector2 = transform * station.view.cargo_center(0)
	var midpoint := transform * Vector2(station.view.x_to_pixel(2.0), station.view.deck_y())
	await _mouse_motion(pickup)
	await _mouse_button(pickup, true)
	_expect(station.phase in ["approaching", "lifting", "carrying"], "pressing on the pump sends the crane hook without a second command")
	await _mouse_motion(midpoint, true)
	await _mouse_button(midpoint, false)
	_expect(not station.model.cargo[0].on_bed and station.model.wheel_loads().is_equal_approx(Vector2(18, 16)),
		"releasing the dragged pump only requests the move; the unlanded cargo has not reached the axle scales")
	if not await _wait_phase("ready"):
		return false
	return _expect(station.model.cargo[0].on_bed and _near(station.model.cargo[0].x, 2.0),
		"one complete drag moves the pump to mid-deck and releases it on the flatbed")


func _notes() -> Array:
	return game.profile.harbor_notes.get("loading", [])


func _has_reading(label: String, value: float) -> bool:
	return label.contains(String.num(value, 2)) or label.contains(String.num(value, 1))


func _dispatch(code: String, rear: float, front: float, over: float = 0.0) -> bool:
	var previous := _notes().size()
	await _tap(KEY_G)
	for frame in 600:
		if _notes().size() > previous and station.phase in ["receipt", "ready"]:
			break
		await process_frame
	if not _expect(_notes().size() == previous + 1, "one new exit-scale ticket for a fully loaded vehicle"):
		return false
	var ticket: Dictionary = station.last_ticket
	if not _expect(ticket.get("code") == code, "exit-scale decision " + code):
		return false
	var accepted := code == "ready"
	var note: Dictionary = _notes().back()
	_expect(ticket.ok == accepted and note.resolved == accepted, "only a load within both axle limits is signed")
	_expect(station.phase == ("receipt" if accepted else "ready"), "the operator can collect the receipt or re-lift the rejected cargo")
	_expect(_near(ticket.rear, rear) and _near(ticket.front, front), "measured rear/front %.2f / %.2f kN" % [rear, front])
	var actual_over: float = maxf(ticket.rear_over, ticket.front_over)
	_expect(_near(actual_over, over), "the ticket reports the actual excess of %.2f kN" % over)
	_expect(_has_reading(note.result, rear) and _has_reading(note.result, front), "the saved ticket carries both actual readings")
	if not accepted:
		var notice: String = station.radio.text + " " + station.ticket_label.text
		_expect(_has_reading(notice, rear) and _has_reading(notice, front), "both measured axle loads are visible at rejection")
		_expect(notice.contains("后") and notice.contains("前"), "the red ticket tells the two axles apart")
	print("Order %d  %s  rear %.2f  front %.2f  excess %.2f kN" % [station.model.order_index + 1, code, rear, front, actual_over])
	return true


func _first_order() -> bool:
	var empty: Vector2 = station.model.wheel_loads()
	_expect(_near(station.model.wheelbase, 4.0) and empty.is_equal_approx(Vector2(18, 16)), "first truck's measured tare and wheelbase")
	await _tap(KEY_G)
	_expect(_notes().is_empty() and station.phase == "ready", "an empty truck cannot receive a cargo ticket")
	await _tap(KEY_F)
	_expect(station.planner.visible, "the optional loading ruler opens from the work station")
	await _tap(KEY_ESCAPE)
	_expect(not station.planner.visible and game.harbor.screen == "station", "closing the ruler leaves the live lift on screen")
	await _tap(KEY_TAB)
	_expect(game.mode == "library" and game.book._active_key == "01-8f6205ff", "the working truck links to the actual torque lesson")
	await _tap(KEY_TAB)
	if not await _drag_first_box() or not await _dispatch("rear", 24.0, 22.0, 2.0):
		return false
	if not await _lift(0):
		return false
	await _tap(KEY_E)
	_expect(station.model.cargo[0].weighed and _near(station.model.sling_load(), 12.0), "the hanging pump's measured weight matches its plate")
	_expect(station.model.wheel_loads().is_equal_approx(empty), "lifting the rejected box actually unloads both axles")
	await _tap(KEY_F)
	var share: HSlider = station.planner.share
	_expect(station.planner.visible and _near(share.value, 6.0), "the ruler opens with the actual mid-deck front share")
	share.grab_focus()
	for division in 30:
		if _near(share.value, 8.4):
			break
		await _tap(KEY_RIGHT)
	if not _expect(_near(share.value, 8.4), "the driver can give the front axle a chosen 8.4 kN share on the ruler"):
		return false
	if not await _activate("划到车板"):
		return false
	_expect(_near(station.cursor_x, 2.8) and station.model.held_index == 0,
		"applying 8.4 kN marks 2.8 m on the real deck while the pump stays on the hook")
	if not await _land(0, 2.8) or not await _dispatch("ready", 21.6, 24.4):
		return false
	_expect(_has_reading(_notes().back().prediction, 8.4), "the signed slip preserves the driver's planned front share")
	await _tap(KEY_J)
	_expect(game.harbor.screen == "journal" and game.harbor.compare.visible, "the signed and rejected slips can be compared in the port log")
	game.harbor.compare.grab_focus()
	await _tap(KEY_ENTER)
	var evidence := PackedStringArray()
	for label: Label in game.harbor.note_body.find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			evidence.append(label.text)
	var comparison := " ".join(evidence)
	_expect(game.harbor.comparing and comparison.contains(_notes()[0].result) and comparison.contains(_notes()[1].result),
		"the side-by-side log actually shows the readings from the two different layouts")
	await _tap(KEY_ESCAPE)
	_expect(game.harbor.screen == "station" and station.phase == "receipt", "returning from the log preserves the signed job")
	return true


func _second_order() -> bool:
	if not await _activate("接下一辆车") or not await _wait_phase("ready"):
		return false
	var model = station.model
	_expect(model.order_index == 1 and _near(model.wheelbase, 5.0) and model.wheel_loads().is_equal_approx(Vector2(16, 20)), "the next truck changes both wheelbase and empty axle loads")
	_expect(not station.view.at_weigh_pad, "the second truck loads in the yard, away from the live axle scales")
	_expect(model.cargo.size() == 2 and model.known_weight(1) < 0.0, "the unlabelled toolbox has no measured weight at the dock")
	if not await _lift(0) or not await _land(0, 2.8, true):
		return false
	await _tap(KEY_2)
	await _tap(KEY_E)
	_expect(model.known_weight(1) < 0.0, "an unloaded hook cannot weigh a toolbox resting on the dock")
	await _tap(KEY_F)
	_expect(station.planner.visible and not station.planner.share.editable and station.planner.apply_mark.disabled,
		"the planning ruler cannot calculate with the unknown toolbox weight")
	await _tap(KEY_ESCAPE)
	await _tap(KEY_1)
	if not await _lift(1, true) or not await _aim_with_mouse(2.8):
		return false
	await _tap(KEY_SPACE)
	await _frames(90)
	_expect(station.phase == "carrying" and station.held == 1 and not model.cargo[1].on_bed and _near(model.cargo[0].x, 2.8),
		"an overlapping drop leaves the toolbox on the hook and the original pump on its mark")
	_expect(station.radio.text.contains("压住") or station.radio.text.contains("重叠"), "the driver can read why that spot is occupied")
	if not await _land(1, 0.7, true):
		return false
	_expect(model.known_weight(1) < 0.0, "the driver may place an unweighed box without revealing its weight")
	if not await _dispatch("front", 25.58, 27.42, 1.42):
		return false
	_expect(_notes().back().observation.contains("未单独称重"), "the first exit slip preserves the missing hook measurement")
	if not await _lift(1):
		return false
	await _tap(KEY_E)
	_expect(model.cargo[1].weighed and _near(model.known_weight(1), 5.0) and _near(model.sling_load(), 5.0), "the loaded, stationary sling reveals a real 5 kN reading")
	if not await _land(1, 0.7, true) or not await _lift(0) or not await _land(0, 2.0):
		return false
	if not await _dispatch("ready", 27.5, 25.5):
		return false
	_expect(_has_reading(_notes().back().observation, 5.0), "the later cargo slip preserves the measured toolbox weight")
	if not await _activate("回码头交班"):
		return false
	return _expect(game.harbor.screen == "map", "two signed deliveries return the driver to port")


func _close_game() -> void:
	game.sound.set_enabled(false)
	game.queue_free()
	await _frames(3)
	OS.delay_msec(160)
	await process_frame


func _check_restart() -> bool:
	var tickets := _notes().duplicate(true)
	_expect(tickets.size() == 4 and game.profile.loading_next_order == 2, "two failed checks and two signed shifts advance the order counter twice")
	await _close_game()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	if not _expect(game.mode == "title" and game.profile.harbor_notes.get("loading", []) == tickets and game.profile.loading_next_order == 2,
		"a new instance restores the four original tickets and next order from disk"):
		return false
	_expect(game.profile.harbor_resolved.get("loading", false), "the signed deliveries remain recorded after restart")
	await _tap(KEY_ENTER)
	station = game.harbor.stations.get("loading")
	return _expect(station != null and station.phase == "ready" and station.model.order_index == 2,
		"starting work after relaunch receives a third order with a different truck")


func _run() -> void:
	var scratch := OS.get_environment("WINDSEED_TEST_ROOT").replace("\\", "/").trim_suffix("/")
	var user_path := OS.get_user_data_dir().replace("\\", "/")
	if DisplayServer.get_name() != "headless" or AudioServer.get_driver_name() != "Dummy" or scratch.is_empty() or not user_path.begins_with(scratch + "/"):
		printerr("Run with --headless --audio-driver Dummy and a fresh isolated WINDSEED_TEST_ROOT.")
		quit(2)
		return
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	await _tap(KEY_ENTER)
	station = game.harbor.stations.get("loading")
	var finished := false
	if _expect(station != null and is_instance_valid(station.get("view")) and is_instance_valid(station.get("radio")) and game.mode == "harbor" and game.harbor.screen == "station" and game.harbor.selected == "loading", "one input from the title opens the working loading berth"):
		if await _first_order() and await _second_order():
			finished = await _check_restart()
	_expect(finished, "both trips, the rejected placements, and the fresh restart all ran to completion")
	await _close_game()
	print("Loading checks ", "passed" if failures.is_empty() else "failed")
	quit(0 if failures.is_empty() else 1)
