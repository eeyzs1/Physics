extends "res://harbor/station.gd"

const CraneRig := preload("res://harbor/quay/crane_rig.gd")
const QuayView := preload("res://harbor/quay/quay_view.gd")
const OperatorLog := preload("res://harbor/quay/operator_log.gd")
const WinchAudio := preload("res://harbor/quay/winch_audio.gd")

var rig := CraneRig.new()
var logbook := OperatorLog.new()
var view: Control
var winch := WinchAudio.new()
var phase := "driving"
var order_line: Label
var radio: Label
var desk: PanelContainer
var review: PanelContainer
var replay: Control
var next_button: Button
var drive_focus: Control
var review_focus: Button
var radio_call: Button
var travel_buttons: Array[Button] = []
var hoist_buttons: Array[Button] = []
var controls_row: HBoxContainer
var receipt_row: HBoxContainer
var receipt_title: Label
var message_until := 0.0
var last_contacts := 0
var last_touch := 0
var saw_brake := false
var receipt_age := 0.0
var working := false

func _build_layout() -> void:
	view = QuayView.new()
	view.rig = rig
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(winch)
	drive_focus = Control.new()
	drive_focus.focus_mode = Control.FOCUS_ALL
	drive_focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drive_focus)
	var order := _plate(self)
	StationUI.place(order, Vector4.ZERO, Vector4(22, 17, 536, 89))
	var order_stack := StationUI.column(1)
	order.add_child(order_stack)
	order_stack.add_child(StationUI.label("雾港  /  岸桥驾驶室", 15, StationUI.AMBER))
	order_line = StationUI.label("", 22)
	order_stack.add_child(order_line)
	var menu := StationUI.row(7)
	add_child(menu)
	StationUI.place(menu, Vector4(1,0,1,0), Vector4(-434,20,-22,64))
	menu.alignment = BoxContainer.ALIGNMENT_END
	radio_call = _small_button("问问指挥员  Q", _call_foreman)
	menu.add_child(radio_call)
	menu.add_child(_small_button("航海日志", func() -> void: journal_requested.emit()))
	menu.add_child(_small_button("码头地图", func() -> void: leave_requested.emit()))
	desk = _plate(self)
	StationUI.place(desk, Vector4(0,1,1,1), Vector4(22,-100,-22,-16))
	controls_row = StationUI.row(12)
	desk.add_child(controls_row)
	var comms := StationUI.column(2)
	comms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls_row.add_child(comms)
	comms.add_child(StationUI.label("对讲机", 14, StationUI.AMBER))
	radio = StationUI.label("", 19, StationUI.INK, true)
	comms.add_child(radio)
	_add_keys("小车 · 长按移动", ["A  左移","D  右移"], travel_buttons)
	_add_keys("吊索 · 长按升降", ["W  起升","S  下降"], hoist_buttons)
	receipt_row = StationUI.row(12)
	desk.add_child(receipt_row)
	receipt_title = StationUI.label("", 21, StationUI.INK, true)
	receipt_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	receipt_row.add_child(receipt_title)
	receipt_row.add_child(_small_button("再吊一次", func() -> void: _start_order(rig.job_index)))
	receipt_row.add_child(_small_button("回看这一吊", open_replay))
	next_button = StationUI.button("", _next, true)
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	receipt_row.add_child(next_button)
	visibility_changed.connect(_on_visibility)

func _plate(host: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StationUI.box(Color("#102e34f8"), Color("#698387"), 6, 15, 7))
	host.add_child(panel)
	return panel

func _small_button(caption: String, callback: Callable) -> Button:
	var button := StationUI.button(caption, callback)
	button.add_theme_font_size_override("font_size", 17)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button

func _add_keys(title: String, names: Array, group: Array[Button]) -> void:
	var column := StationUI.column(1)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	controls_row.add_child(column)
	column.add_child(StationUI.label(title, 14, StationUI.SOFT))
	var pair := StationUI.row(4)
	column.add_child(pair)
	for caption: String in names:
		var key := Button.new()
		key.text = caption
		key.add_theme_font_size_override("font_size", 16)
		key.custom_minimum_size = Vector2(80,34)
		key.add_theme_stylebox_override("normal", StationUI.box(Color("#1b3e44"), StationUI.LINE, 4, 7, 3))
		key.add_theme_stylebox_override("pressed", StationUI.box(Color("#397269"), StationUI.MINT, 4, 7, 3))
		key.add_theme_stylebox_override("hover", StationUI.box(Color("#29555a"), StationUI.MINT, 4, 7, 3))
		key.focus_mode = Control.FOCUS_NONE
		key.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pair.add_child(key)
		group.append(key)

func _begin() -> void:
	_start_order(0)

func _start_order(index: int) -> void:
	if is_instance_valid(review):
		_close_replay()
	rig.reset_job(index)
	var unload := index % 2 == 0
	order_line.text = "卸船　/　把船上的机件箱放上右侧平板车" if unload else "装船　/　把车上的补给箱放到左侧甲板"
	logbook.begin(rig, "把机件箱放上前往修船厂的平板车。" if unload else "把岸上送来的补给箱装进船上的货位。")
	phase = "driving"
	message_until = 0.0
	last_contacts = 0
	last_touch = 0
	saw_brake = false
	radio_call.hide()
	working = false
	receipt_age = 0.0
	radio.text = "司机：车停好了，可以往右移。松开方向键，小车会刹住。" if unload else "水手：补给到了。甲板比车板高，先把箱子提起来。"
	controls_row.show()
	receipt_row.hide()
	view.queue_redraw()
	_focus_actions.call_deferred()

func _next() -> void:
	if rig.job_index % 2 == 0:
		_start_order(rig.job_index + 1)
	else:
		leave_requested.emit()
		_start_order(rig.job_index + 1)

func _held(group: Array[Button], negative: StringName, positive: StringName) -> float:
	var mouse_axis := float(group[1].button_pressed) - float(group[0].button_pressed)
	return clampf(Input.get_axis(negative, positive) + mouse_axis, -1, 1)

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if phase == "receipt":
		receipt_age += delta
		if next_button.disabled and receipt_age >= 1.2:
			next_button.disabled = false
			_focus_actions()
		return
	if phase != "driving":
		return
	var travel := _held(travel_buttons, &"steer_left", &"steer_right")
	var hoist := _held(hoist_buttons, &"climb", &"dive")
	working = working or not is_zero_approx(travel) or not is_zero_approx(hoist)
	if not working:
		return
	rig.step(delta, travel, hoist)
	logbook.observe(rig, delta)
	winch.drive(rig.trolley_speed, rig.hoist_speed, sounds_enabled, delta)
	if rig.contacts > last_contacts:
		last_contacts = rig.contacts
		view.impact(clampf(rig.last_impact.speed * .4, .15, 1.0))
		winch.knock(rig.last_impact.speed, sounds_enabled)
		if rig.last_impact.face == "side":
			_say("水手：箱子碰到边了。提起来一点，就能越过去。", 4.5)
	if rig.touch_sequence > last_touch:
		last_touch = rig.touch_sequence
		if not rig.last_touch.target:
			_say(_landing_help(rig.last_touch.surface), 4.0)
	if not saw_brake and not logbook.brake.is_empty():
		saw_brake = true
		radio_call.show()
		if rig.elapsed >= message_until:
			_say("指挥员：小车刚停，箱子还在往%s走。" % ("右" if logbook.brake.speed > 0 else "左"), 4.5)
	if rig.delivered:
		_finish()
	elif rig.elapsed >= message_until and rig.elapsed > 2.0:
		var near_target := absf(rig.trolley_x - rig.target_x) < 1.8
		if rig.grounded and rig.settled_time == 0.0 and absf(rig.load_velocity().x) <= CraneRig.SETTLE_SPEED:
			radio.text = _landing_help(rig.ground_surface)
		elif near_target:
			radio.text = "指挥员：看箱底。对准货位就可以往下放。"
		elif rig.job_index % 2 == 1 and rig.load_position().y - CraneRig.BOX_HEIGHT * .5 < CraneRig.SHIP_TOP_Y:
			radio.text = "水手：船的甲板高，得先把箱子提过船边。"
		else:
			radio.text = "司机：右边这辆平板车，装好就往修船厂走。" if rig.job_index % 2 == 0 else "水手：补给装在左边甲板的漆线里。"

func _say(line: String, seconds: float) -> void:
	radio.text = line
	message_until = rig.elapsed + seconds

func _landing_help(surface: String) -> String:
	var receiving := "truck" if rig.job_index % 2 == 0 else "ship"
	if surface != receiving:
		match surface:
			"ship": return "指挥员：箱子还在船上。先提离甲板，平板车在右边。"
			"truck": return "水手：先提离车板，甲板的货位在左边。"
			_: return "指挥员：箱子搁在栈桥上了。先把箱底提过货位边缘。"
	var offset := rig.load_position().x - rig.target_x
	var side := "右" if offset > 0 else "左"
	var toward := "左" if offset > 0 else "右"
	return "指挥员：箱子压住%s边的漆线了。先把它提离板面，再往%s挪一点。" % [side, toward]

func _call_foreman() -> void:
	if phase == "driving" and saw_brake:
		_say("指挥员：小车刹住了，箱子靠惯性还往前走。绳子斜了会把它拉回来。等摆幅小些，再下钩。", 9)
		drive_focus.grab_focus()

func _finish() -> void:
	phase = "receipt"
	radio_call.hide()
	winch.quiet()
	play_cue("gate")
	complete(logbook.make_note(rig))
	controls_row.hide()
	receipt_row.show()
	receipt_title.text = "司机：绑牢了！我把机件送去修船厂。" if rig.job_index % 2 == 0 else "水手：补给收到，可以解缆了。辛苦！"
	next_button.text = "接返程的补给箱" if rig.job_index % 2 == 0 else "回码头交班"
	next_button.disabled = true
	_focus_actions()

func open_replay() -> void:
	if phase != "receipt":
		return
	phase = "replay"
	winch.quiet()
	desk.hide()
	review = _plate(self)
	StationUI.place(review, Vector4(0,0,1,1), Vector4(76,94,-76,-26))
	var column := StationUI.column(8)
	review.add_child(column)
	var head := StationUI.row(8)
	column.add_child(head)
	var title := StationUI.label("回看这一吊", 25)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_small_button("翻到相关课件", func() -> void: manual_requested.emit()))
	head.add_child(_small_button("回驾驶室", _close_replay))
	replay = logbook.make_view()
	replay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(replay)
	var points := StationUI.row(6)
	column.add_child(points)
	review_focus = null
	for point: Dictionary in logbook.review_points():
		var jump := _small_button(point.label, replay.select_time.bind(point.time))
		points.add_child(jump)
		if point.id == "brake" or review_focus == null:
			review_focus = jump
	_focus_actions.call_deferred()

func _close_replay() -> void:
	if not is_instance_valid(review):
		return
	remove_child(review)
	review.queue_free()
	review = null
	replay = null
	phase = "receipt"
	desk.show()
	_focus_actions.call_deferred()

func handle_back() -> bool:
	if phase == "replay":
		_close_replay()
		return true
	return false

func _focus_actions() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or not can_process():
		return
	if phase == "replay" and is_instance_valid(review_focus):
		review_focus.grab_focus()
	elif phase == "receipt" and not next_button.disabled:
		next_button.grab_focus()
	else:
		drive_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if phase != "driving" or not is_visible_in_tree():
		return
	if saw_brake and event.is_action_pressed(&"tune"):
		_call_foreman()
		get_viewport().set_input_as_handled()
		return
	for action in [&"steer_left", &"steer_right", &"climb", &"dive"]:
		if event.is_action(action):
			get_viewport().set_input_as_handled()
			return

func _on_visibility() -> void:
	if not is_visible_in_tree():
		winch.quiet()
		for group in [travel_buttons, hoist_buttons]:
			for button: Button in group:
				button.set_pressed_no_signal(false)
