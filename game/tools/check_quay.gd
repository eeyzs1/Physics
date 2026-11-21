extends SceneTree

const Model := preload("res://harbor/quay/crane_rig.gd")
const TICK := 1.0 / 60.0
var game
var station
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("Cargo shift: " + message)

func _frames(count: int) -> void:
	for index in count:
		await process_frame

func _button(caption: String) -> Button:
	for node: Button in station.find_children("*", "Button", true, false):
		if node.is_visible_in_tree() and node.text.begins_with(caption):
			return node
	return null

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await _frames(2)

func _tap(code: Key) -> void:
	await _key(code, true)
	await _key(code, false)

func _press(caption: String) -> void:
	var button := _button(caption)
	_check(is_instance_valid(button), "action exists: " + caption)
	if button != null:
		button.grab_focus()
		await _tap(KEY_ENTER)

func _travel(direction: int, stop_x: float) -> void:
	var key := KEY_D if direction > 0 else KEY_A
	await _key(key, true)
	for index in 680:
		if direction * (station.rig.trolley_x - stop_x) >= 0:
			break
		await process_frame
	await _key(key, false)
	_check(absf(station.rig.trolley_x-stop_x) < .4, "trolley follows the held travel key")

func _mouse_hoist(down: bool) -> void:
	var button: Button = station.hoist_buttons[1]
	var point := button.get_global_rect().get_center()
	var cursor := InputEventMouseMotion.new()
	cursor.position = point
	cursor.global_position = point
	root.push_input(cursor, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	root.push_input(event, true)
	await _frames(2)
	if down:
		_check(button.button_pressed, "the mouse can hold the on-screen hoist control")

func _lower(by_mouse: bool = false) -> void:
	if by_mouse:
		await _mouse_hoist(true)
	else:
		await _key(KEY_S, true)
	for index in 420:
		if station.rig.delivered:
			break
		await process_frame
	if by_mouse:
		await _mouse_hoist(false)
	else:
		await _key(KEY_S, false)
	_check(station.rig.delivered and station.phase == "receipt", "an actual landing completes the job")

func _attempt(release_x: float) -> Model:
	var rig := Model.new()
	for index in 600:
		if rig.trolley_x >= release_x:
			break
		rig.step(TICK, 1.0, 0.0)
	for index in 75:
		rig.step(TICK, 0.0, 0.0)
	for index in 300:
		if rig.touch_sequence > 0:
			break
		rig.step(TICK, 0.0, 1.0)
	for index in 210:
		rig.step(TICK, 0.0, 0.0)
	return rig

func _late_stop_and_recovery() -> void:
	var late := _attempt(17.0)
	var early := _attempt(16.0)
	_check(late.ground_surface == "truck" and not late.delivered, "a steady crate resting across the truck's edge line needs repositioning")
	_check(early.delivered and absf(early.load_position().x-early.target_x)<.15, "earlier braking on an otherwise identical run fits the load on the flatbed")
	for index in 180:
		if late.load_position().y - Model.BOX_HEIGHT*.5 >= Model.TRUCK_TOP_Y+.6:
			break
		late.step(TICK, 0.0, -1.0)
	for index in 42:
		late.step(TICK, -1.0, 0.0)
	for index in 90:
		late.step(TICK, 0.0, 0.0)
	var touches := late.touch_sequence
	for index in 300:
		if late.touch_sequence > touches:
			break
		late.step(TICK, 0.0, 1.0)
	for index in 160:
		late.step(TICK, 0.0, 0.0)
	_check(late.delivered and late.last_touch.target and not late.first_touch.target, "the original drifting load can be raised and landed again without a restart")
	print("First contact %.2f m, corrected contact %.2f m, opposite case %.2f m." % [late.first_touch.x,late.last_touch.x,early.first_touch.x])

func _run() -> void:
	var scratch := OS.get_environment("WINDSEED_TEST_ROOT").replace("\\","/").trim_suffix("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(scratch+"/"):
		quit(2)
		return
	_late_stop_and_recovery()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	await _tap(KEY_ENTER)
	station = game.harbor.stations.get("loading")
	if station != null:
		await _press("岸桥驾驶")
	station = game.harbor.stations.get("quay")
	if station == null:
		_check(false,"the loading berth opens the crane driving station")
		quit(1)
		return
	var source: Vector2 = station.rig.load_position()
	await _frames(30)
	_check(station.rig.elapsed == 0.0 and source.is_equal_approx(station.rig.load_position()), "waiting in the cab keeps the load still")
	await _travel(1,15.75)
	await _frames(66)
	_check(not station.logbook.brake.is_empty() and station.radio_call.visible, "a measured stop with a still-moving load opens the radio")
	await _tap(KEY_Q)
	_check(station.radio.text.contains("惯性"),"the operator can ask about the stop while still driving")
	var before_book: float = station.rig.elapsed
	await _tap(KEY_TAB)
	await _frames(30)
	_check(game.mode == "library" and game.book._active_key == "01-0" and station.rig.elapsed-before_book < .1, "the matching lesson pauses the crane")
	await _tap(KEY_TAB)
	await _lower(true)
	if not station.rig.delivered:
		quit(1)
		return
	var receipt: Dictionary = game.profile.harbor_notes.quay.back()
	_check(receipt.resolved and receipt.observation.contains("m/s") and receipt.result.contains("汽车平板"),"first delivery records real brake and contact observations")
	await _frames(78)
	await _press("回看这一吊")
	_check(station.phase=="replay" and absf(station.replay.selected_time-station.logbook.brake.time)<.02,"optional replay opens on the player's observed braking event")
	await _press("第一次着板")
	_check(absf(station.replay.selected_time-station.logbook.first_touch.time)<.01,"the contact marker selects the actual first touch")
	await _tap(KEY_TAB)
	await _tap(KEY_TAB)
	await _tap(KEY_ESCAPE)
	_check(game.harbor.screen=="station" and station.phase=="receipt","closing replay restores the completed shift")
	print("Unloaded ship: ",receipt.observation," ",receipt.result)
	await _press("接返程")
	_check(station.rig.job_index==1 and station.rig.target_y>station.rig.source_y,"the return job loads from the lower truck onto the higher ship")
	await _key(KEY_W,true)
	await _frames(75)
	await _key(KEY_W,false)
	await _frames(32)
	await _travel(-1,6.25)
	await _frames(65)
	await _lower()
	if not station.rig.delivered:
		quit(1)
		return
	_check(station.logbook.first_touch.surface=="ship" and game.profile.harbor_notes.quay.size()==2,"both receipts persist independently")
	await _frames(76)
	await _press("回码头交班")
	_check(game.harbor.screen=="map" and station.rig.job_index==2,"handoff returns to port with a fresh shift available")
	var loaded = game.Harbour.new()
	loaded.load_profile()
	_check(loaded.harbor_notes.quay.size()==2,"completed shift survives relaunch")
	game.harbor.sail.grab_focus()
	await _tap(KEY_ENTER)
	_check(game.mode=="hangar","ordinary voyages leave independently of research commissions")
	game.sound.set_enabled(false)
	game.queue_free()
	await _frames(3)
	OS.delay_msec(160)
	await process_frame
	print("Quay checks ", "passed" if failures.is_empty() else "failed")
	quit(0 if failures.is_empty() else 1)
