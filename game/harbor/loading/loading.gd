extends "res://harbor/station.gd"

const Truck := preload("res://harbor/loading/load_model.gd")
const LoadingView := preload("res://harbor/loading/loading_view.gd")
const Planner := preload("res://harbor/loading/load_planner.gd")
const Motor := preload("res://harbor/quay/winch_audio.gd")
const TRAVEL_SPEED := 3.2

var model := Truck.new()
var view := LoadingView.new()
var planner := Planner.new()
var motor := Motor.new()
var first_order := 0
var phase := "ready"
var selected := 0
var held := -1
var cursor_x := 2.0
var last_ticket: Dictionary = {}
var radio: Label
var ticket_label: Label
var _title_line: Label
var _manifest: Label
var _marker: Label
var _box_buttons: Array[Button] = []
var _hook_button: Button
var _weigh_button: Button
var _dispatch_button: Button
var _ruler_button: Button
var _next_button: Button
var _work: HBoxContainer
var _receipt: HBoxContainer
var _aims := PackedFloat64Array()
var _drawn_with: Dictionary = {}
var _last_landing: Dictionary = {}
var _pending_drop := false
var _dragging := false
var _drag_origin := Vector2.ZERO
var _drag_moved := false
var _direction := 0
var _repeat_in := 0.0
var _lifts := 0
var _weighings := 0
var _placements := 0
var _ticket_placement := -1

func _build_layout() -> void:
	view.model = model
	add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.focus_mode = Control.FOCUS_ALL
	view.gui_input.connect(_pointer)
	add_child(motor)
	var docket := _plate()
	StationUI.place(docket, Vector4.ZERO, Vector4(18,12,640,82))
	var heading := StationUI.column(1)
	docket.add_child(heading)
	_title_line = StationUI.label("",22,StationUI.INK)
	_manifest = StationUI.label("",16,StationUI.AMBER)
	heading.add_child(_title_line)
	heading.add_child(_manifest)
	var nav := StationUI.row(6)
	add_child(nav)
	StationUI.place(nav,Vector4(1,0,1,0),Vector4(-550,19,-19,62))
	nav.alignment = BoxContainer.ALIGNMENT_END
	_ruler_button = _button("配载尺  F",_toggle_planner)
	nav.add_child(_ruler_button)
	nav.add_child(_button("岸桥驾驶",func() -> void: station_requested.emit("quay")))
	nav.add_child(_button("日志",func() -> void: journal_requested.emit()))
	nav.add_child(_button("码头地图",func() -> void: leave_requested.emit()))
	var foot := _plate()
	StationUI.place(foot,Vector4(0,1,1,1),Vector4(18,-142,-18,-14))
	var desk := StationUI.column(3)
	foot.add_child(desk)
	radio = StationUI.label("",19,StationUI.INK,true)
	desk.add_child(radio)
	ticket_label = StationUI.label("",16,StationUI.AMBER)
	desk.add_child(ticket_label)
	_work = StationUI.row(7)
	desk.add_child(_work)
	for i in 2:
		var box_button := _button("",_choose_box.bind(i))
		_box_buttons.append(box_button)
		_work.add_child(box_button)
	_work.add_child(_button("−",_nudge.bind(-1)))
	_marker = StationUI.label("",17,StationUI.MINT)
	_work.add_child(_marker)
	_work.add_child(_button("＋",_nudge.bind(1)))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_work.add_child(gap)
	_hook_button = _button("挂钩起吊  空格",_hook,true)
	_weigh_button = _button("读吊秤  E",_weigh)
	_dispatch_button = _button("过磅发车  G",_dispatch)
	for button in [_hook_button,_weigh_button,_dispatch_button]:
		_work.add_child(button)
	_receipt = StationUI.row(8)
	desk.add_child(_receipt)
	_next_button = _button("",_next_order,true)
	_receipt.add_child(_next_button)
	_receipt.add_child(_button("重装这辆车",func() -> void: _new_order(model.order_index)))
	_receipt.add_child(_button("看磅票",func() -> void: journal_requested.emit()))
	add_child(planner)
	planner.closed.connect(_close_planner)
	planner.marked.connect(_mark_from_planner)
	visibility_changed.connect(_visibility)

func _plate() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",StationUI.box(Color("#102e35fa"),Color("#697f79"),6,14,7))
	add_child(panel)
	return panel

func _button(caption: String, action: Callable, primary: bool = false) -> Button:
	var button := StationUI.button(caption,action,primary)
	button.add_theme_font_size_override("font_size",16)
	button.custom_minimum_size.y = 37
	return button

func _begin() -> void:
	_new_order(first_order)

func _new_order(index: int) -> void:
	model.reset_order(index)
	selected = 0
	held = -1
	phase = "ready"
	_aims.clear()
	for box in model.cargo:
		_aims.append(snappedf(model.wheelbase*.5,.1))
	cursor_x = _aims[0]
	_drawn_with.clear()
	_last_landing.clear()
	last_ticket = {}
	_pending_drop = false
	_dragging = false
	_direction = 0
	_lifts = 0
	_weighings = 0
	_placements = 0
	_ticket_placement = -1
	view.hook_world_x = view.yard_x(0)
	view.lift_fraction = 0.0
	view.departure = 0.0
	view.at_weigh_pad = _has_local_scales()
	view.active_scale = false
	planner.hide()
	_work.show()
	_receipt.hide()
	_title_line.text = "雾港配载　/　%s　·　第 %d 辆" % ["机修厂提货" if _has_local_scales() else "泵站补给", index+1]
	_manifest.text = "空车　后 %.1f · 前 %.1f kN　　轴限　后 %.1f · 前 %.1f kN　　轴距 %.1f m" % [model.rear_empty,model.front_empty,model.rear_limit,model.front_limit,model.wheelbase]
	radio.text = "司机：%s要送去机修厂。落在哪儿你来定，两根车轴都得过磅。" % model.cargo[0].label if _has_local_scales() else "司机：小箱没铭牌，吊起来可以称。出口才有轴秤，咱们争取一趟过。"
	ticket_label.text = "点住箱子拖到车板刻度，也可用空格起落、A / D 移落点。"
	_refresh()
	_focus_actions.call_deferred()

func _has_local_scales() -> bool:
	return model.order_index % 2 == 0

func _choose_box(index: int) -> void:
	if phase != "ready" or index < 0 or index >= model.cargo.size(): return
	selected = index
	cursor_x = _aims[index]
	_refresh()
	view.grab_focus()

func _aim(x: float) -> void:
	if phase not in ["ready","approaching","lifting","carrying"]: return
	cursor_x = clampf(snappedf(x,.1),0.0,model.wheelbase)
	_aims[selected] = cursor_x
	_drawn_with.erase(selected)
	_pending_drop = false
	_refresh()

func _nudge(direction: int) -> void:
	_aim(cursor_x + direction*.1)
	view.grab_focus()

func _hook() -> void:
	if phase == "ready":
		_start_pick()
	elif phase in ["lifting","carrying","approaching"]:
		_drop()
	view.grab_focus()

func _start_pick() -> void:
	if phase != "ready": return
	_pending_drop = false
	if not _has_local_scales() and view.at_weigh_pad:
		phase = "returning"
		radio.text = "司机：我把原车开回吊机下，再挪这件货。"
	else:
		phase = "approaching"
		view.active_scale = false
	_refresh()

func _pick_x() -> float:
	var box := model.cargo[selected]
	return float(box.x) if box.on_bed else view.yard_x(selected)

func _drop() -> void:
	var issue := model.placement_error(selected,cursor_x)
	if not issue.is_empty():
		_pending_drop = false
		radio.text = issue
		return
	_pending_drop = true
	radio.text = "吊机：收到，送到距后轴 %.1f m 的标记，落稳后松钩。" % cursor_x
	_refresh()

func _land() -> void:
	if not model.land(selected,cursor_x):
		radio.text = model.last_error
		_pending_drop = false
		phase = "lifting"
		_refresh()
		return
	phase = "ready"
	held = -1
	_placements += 1
	_pending_drop = false
	motor.quiet()
	motor.knock(.8,sounds_enabled)
	var current := model.wheel_loads()
	radio.text = "%s已落在 %.1f m。%s" % [model.cargo[selected].label,cursor_x,
		"可以看轮下两台秤，再决定发车还是挪货。" if _has_local_scales() else "货齐了可以去出口复磅。"]
	if _has_local_scales() and not _last_landing.is_empty():
		var dx := cursor_x - float(_last_landing.x)
		if absf(dx) > .05:
			var df := current.y - float(_last_landing.front)
			radio.text = "同一件货%s挪了 %.1f m。前轴%s %.2f kN，后轴%s %.2f kN。" % ["往车头" if dx>0 else "往车尾",absf(dx),"多承" if df>0 else "少承",absf(df),"少承" if df>0 else "多承",absf(df)]
	_last_landing = {"x":cursor_x,"front":current.y}
	_refresh()

func _weigh() -> void:
	if phase != "carrying" or held < 0:
		radio.text = "吊秤要挂上货。先起吊，让箱底离开支承面。"
		return
	if model.mark_weighed(held):
		radio.text = "吊秤　%.1f kN。%s的重量已抄进本车货单。" % [model.sling_load(),model.cargo[held].label]
		view.active_scale = true
		_refresh()
	view.grab_focus()

func _dispatch() -> void:
	if phase != "ready":
		if phase != "receipt": radio.text = "司机：先把吊着的货放稳、松钩，我才能开去过磅。"
		return
	var ticket := model.dispatch_report()
	if ticket.code == "incomplete":
		radio.text = "司机：%s" % ticket.reason
		return
	if _ticket_placement == _placements and not last_ticket.is_empty():
		radio.text = "还是原来的摆法，%s" % last_ticket.reason
		return
	if not _has_local_scales() and not view.at_weigh_pad:
		phase = "to_scale"
		radio.text = "司机：货已松钩，我开去出口上轴重秤。"
		_refresh()
		return
	_print_ticket(ticket)

func _print_ticket(ticket: Dictionary) -> void:
	_ticket_placement = _placements
	_weighings += 1
	last_ticket = ticket.duplicate()
	view.at_weigh_pad = true
	view.active_scale = true
	ticket_label.text = "第 %d 张实测磅票　后轴 %.2f / %.1f kN　　前轴 %.2f / %.1f kN　　%s" % [_weighings,ticket.rear,model.rear_limit,ticket.front,model.front_limit,"已签收" if ticket.ok else "需调货"]
	complete(_ticket_note(ticket))
	if not ticket.ok:
		phase = "ready"
		radio.text = "%s　可重新挂钩挪货，或打开配载尺重新划线。" % ticket.reason
		view.grab_focus()
		_refresh()
		return
	phase = "receipt"
	play_cue("gate")
	radio.text = "司机：一次放行，可以直送了！　这车吊了 %d 次。" % _lifts if _weighings == 1 else "司机：调好货位，这次两轴都过了。　这车吊了 %d 次，过磅 %d 次。" % [_lifts,_weighings]
	_work.hide()
	_receipt.show()
	_next_button.text = "接下一辆车" if model.order_index%2 == 0 else "回码头交班"
	_focus_actions()
	_refresh()

func _ticket_note(ticket: Dictionary) -> Dictionary:
	var marks := PackedStringArray()
	var weights := PackedStringArray()
	for i in model.cargo.size():
		var box := model.cargo[i]
		var mark := "%s %.1f m" % [box.label,box.x]
		if _drawn_with.has(i): mark += "（打算分给前轴 %.1f kN）" % _drawn_with[i]
		marks.append(mark)
		var w := model.known_weight(i)
		weights.append("%s %.1f kN" % [box.label,w] if w>0 else "%s未单独称重" % box.label)
	return {
		"title":"第 %d 辆配载磅票 · %s" % [model.order_index+1,"放行" if ticket.ok else "复装"],
		"observation":"轴距 %.1f m，空车后 %.2f kN、前 %.2f kN。%s。" % [model.wheelbase,model.rear_empty,model.front_empty,"，".join(weights)],
		"prediction":"从后轴向车头量，实放前划下的箱心刻度为%s。" % "、".join(marks),
		"result":"后轴 %.2f / %.1f kN，前轴 %.2f / %.1f kN。%s 至此起吊 %d 次、过磅 %d 次。" % [ticket.rear,model.rear_limit,ticket.front,model.front_limit,ticket.reason,_lifts,_weighings],
		"principle":"箱子向车头挪，前轴多承重，后轴等量减轻。对后轴取力矩，各箱重量乘箱心距离之和，等于前轴新增载荷乘轴距。",
		"boundary":"车停在水平面上，箱心标记代表重心的水平位置。这里计算静态轴荷，行驶和制动时的载荷另计。",
		"resolved":ticket.ok, "next_order":model.order_index+1}

func _next_order() -> void:
	var index := model.order_index+1
	if index%2 == 0: leave_requested.emit()
	_new_order(index)

func _toggle_planner() -> void:
	if planner.visible:
		_close_planner()
	elif phase in ["ready","carrying"]:
		_pending_drop = false
		_dragging = false
		_direction = 0
		motor.quiet()
		planner.open_for(model,selected,cursor_x)

func _close_planner() -> void:
	planner.hide()
	_focus_actions()

func _mark_from_planner(x: float, front_share: float) -> void:
	_aim(x)
	_drawn_with[selected] = front_share
	radio.text = "已在后轴前方 %.1f m 划线。这一箱分给前轴的计划值为 %.1f kN，落稳后可用磅票核对。" % [x,front_share]
	_close_planner()

func _refresh() -> void:
	view.selected = selected
	view.held = held
	view.cursor_x = cursor_x
	_marker.text = "落点 %.1f m" % cursor_x
	for i in _box_buttons.size():
		var button := _box_buttons[i]
		button.visible = i < model.cargo.size()
		if not button.visible: continue
		var w := model.known_weight(i)
		button.text = "%d　%s · %s" % [i+1,model.cargo[i].label,"%.1f kN" % w if w>0 else "待称"]
		button.modulate = Color.WHITE if i == selected else Color("#bccdc7")
		button.disabled = phase != "ready"
	_hook_button.disabled = phase not in ["ready","carrying"]
	_hook_button.text = "挂钩起吊  空格" if phase == "ready" else ("落箱  空格" if not _pending_drop else "正在落箱")
	_weigh_button.disabled = phase != "carrying"
	_dispatch_button.disabled = phase != "ready"
	_ruler_button.disabled = phase not in ["ready","carrying"]
	view.queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_visible_in_tree() or planner.visible: return
	_drive_keys(delta)
	match phase:
		"to_scale","returning":
			view.departure = move_toward(view.departure,1.0,delta*1.1)
			if view.departure >= 1.0:
				view.departure = 0.0
				if phase == "to_scale":
					_print_ticket(model.dispatch_report())
				else:
					view.at_weigh_pad = false
					view.active_scale = false
					phase = "approaching"
					_refresh()
		"approaching":
			view.hook_world_x = move_toward(view.hook_world_x,_pick_x(),TRAVEL_SPEED*delta*1.4)
			if is_equal_approx(view.hook_world_x,_pick_x()) and model.pickup(selected):
				held = selected
				_lifts += 1
				phase = "lifting"
				_refresh()
		"lifting":
			view.lift_fraction = move_toward(view.lift_fraction,1.0,delta*2)
			if view.lift_fraction >= 1.0:
				phase = "carrying"
				if not _pending_drop:
					radio.text = "吊索承重。点车板或按 A / D 选落点，再落箱。" if model.known_weight(selected)>0 else "这箱没铭牌。按 E 读吊秤，配载尺就能用上它的重量。"
				_refresh()
		"carrying":
			view.hook_world_x = move_toward(view.hook_world_x,cursor_x,TRAVEL_SPEED*delta)
			if _pending_drop and is_equal_approx(view.hook_world_x,cursor_x):
				phase = "lowering"
				_refresh()
		"lowering":
			view.lift_fraction = move_toward(view.lift_fraction,0,delta*1.7)
			if view.lift_fraction <= 0: _land()
		"receipt":
			view.departure = move_toward(view.departure,1,delta*.44)
	motor.drive(TRAVEL_SPEED if phase=="approaching" or (phase=="carrying" and absf(view.hook_world_x-cursor_x)>.02) else 0.0,1.0 if phase in ["lifting","lowering"] else 0.0,sounds_enabled,delta)
	if phase != "ready": view.queue_redraw()

func _drive_keys(delta: float) -> void:
	if not view.has_focus() or phase not in ["ready","approaching","lifting","carrying"]:
		_direction = 0
		return
	var axis := Input.get_axis(&"steer_left",&"steer_right")
	var direction := int(signf(axis)) if absf(axis)>.32 else 0
	if direction == 0:
		_direction = 0
	elif direction != _direction:
		_direction = direction
		_repeat_in = .30
		_nudge(direction)
	else:
		_repeat_in -= delta
		if _repeat_in <= 0:
			_nudge(direction)
			_repeat_in += .075

func _pointer(event: InputEvent) -> void:
	if planner.visible or phase not in ["ready","approaching","lifting","carrying","returning"]: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		view.grab_focus()
		if event.pressed:
			var box := view.cargo_at(event.position)
			_dragging = false
			_drag_moved = false
			if box >= 0 and (phase=="ready" or box==held):
				_dragging = true
				_drag_origin = event.position
				if phase == "ready":
					_choose_box(box)
					_start_pick()
			elif view.on_deck(event.position):
				_aim(view.pixel_to_x(event.position.x))
		elif _dragging:
			_dragging = false
			if (_drag_moved or event.position.distance_to(_drag_origin)>6) and view.on_deck(event.position):
				_aim(view.pixel_to_x(event.position.x))
				_drop()
		view.accept_event()
	elif event is InputEventMouseMotion and _dragging and view.on_deck(event.position):
		if event.position.distance_to(_drag_origin)>6:
			_drag_moved = true
			_aim(view.pixel_to_x(event.position.x))
			view.accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo(): return
	var code: Key = event.physical_keycode if event is InputEventKey else KEY_NONE
	var joy: int = event.button_index if event is InputEventJoypadButton else -1
	if event.is_pressed() and (code==KEY_F or joy==JOY_BUTTON_LEFT_SHOULDER):
		_toggle_planner()
	elif planner.visible or phase=="receipt":
		return
	elif view.has_focus() and (event.is_action("steer_left") or event.is_action("steer_right")):
		pass # Motion is polled in physics time, independent of OS key repeat.
	elif not event.is_pressed():
		return
	elif code==KEY_SPACE or (view.has_focus() and (code==KEY_ENTER or joy==JOY_BUTTON_A)): _hook()
	elif code==KEY_E or joy==JOY_BUTTON_X: _weigh()
	elif code==KEY_G or joy==JOY_BUTTON_START: _dispatch()
	elif code in [KEY_1,KEY_2]: _choose_box(0 if code==KEY_1 else 1)
	elif joy==JOY_BUTTON_RIGHT_SHOULDER: _choose_box((selected+1)%model.cargo.size())
	else: return
	get_viewport().set_input_as_handled()

func handle_back() -> bool:
	if planner.visible:
		_close_planner()
		return true
	return false

func _focus_actions() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or not can_process(): return
	if planner.visible:
		if planner.share.editable: planner.share.grab_focus()
		else: planner.close_button.grab_focus()
	elif phase=="receipt": _next_button.grab_focus()
	else: view.grab_focus()

func _visibility() -> void:
	if not is_visible_in_tree():
		_dragging = false
		_direction = 0
		motor.quiet()
