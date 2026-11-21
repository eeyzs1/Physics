extends Control

signal home_requested
signal hangar_requested
signal manual_requested
signal departed
signal save_requested
signal cue_requested(kind: String)

const UI := preload("res://ui/skin.gd")
const MapView := preload("res://harbor/map.gd")
const BaseStation := preload("res://harbor/station.gd")
const PortProfile := preload("res://profile.gd")
const ART := preload("res://art/harbor.webp")
const LOCATIONS := {
	"loading": {"name": "货车配载", "detail": "修船厂来了辆平板车。把货装齐，还得让前后两轴各自过磅。", "courses": ["01-8f6205ff", "01-0", "18-1"]},
	"quay": {"name": "货运岸桥", "detail": "船上的机件要去修船厂，平板车就在栈桥上等。", "courses": ["01-0", "01-b789ec3f", "00-1"]},
	"chime": {"name": "五板雾琴", "detail": "同一排琴板，换个节奏，为什么第三块几乎停下，第四块还在敲钟？", "courses": ["01-7591bdc8", "02-08fe1bc8", "02-research"]},
	"towers": {"name": "双灯塔", "detail": "单看一塔，亮暗各约一半。把两份灯志对在一起，转动读头会改变什么？", "courses": ["21-3c117040", "21-b9d7420b", "21-research"]},
	"wind": {"name": "测风邮船", "detail": "同一场雾，探头最初只差一点，过几分钟还能走同一条窄航道吗？你有一枚浮标可以重测。", "courses": ["20-d3ae2b69", "20-7472e05b", "17-research"]},
	"dock": {"name": "旧船坞工棚", "detail": "工棚里有一架双摆，可以摘挂横簧、拨摆、记节拍。", "courses": ["02-08fe1bc8", "02-research", "01-7591bdc8"]}
}
const MAP_LOCATIONS := ["loading", "chime", "towers", "wind"]
const NIGHT_RUN := ["chime", "towers", "wind"]
const LABELS := {"observation": "我看到的现象", "prediction": "动手前的预判", "result": "实际发生了什么", "principle": "背后的规律", "boundary": "规律的适用条件"}

var profile: PortProfile
var screen := "map"
var selected := "loading"
var journal_return := "map"
var note_location := ""
var map: MapView
var route_hint: Label
var route_state: Label
var sail: Button
var journal: Control
var note_list: ItemList
var note_body: VBoxContainer
var note_book: Button
var compare: Button
var note_index := -1
var comparing := false
var rows: Array = []
var stations: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map = MapView.new()
	add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.texture = ART
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	move_child(art, 0)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_map()
	_build_journal()
	show_map()

func _plate(host: Control, anchors: Vector4, edges: Vector4) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color("#102c32f5"), Color("#7c9181"), 8, 17, 9))
	host.add_child(panel)
	UI.place(panel, anchors, edges)
	var box := UI.row(16)
	panel.add_child(box)
	return box

func _build_map() -> void:
	var header := _plate(map, Vector4(0,0,0,0), Vector4(32,25,365,90))
	header.add_child(UI.label("雾港", 38))
	var subtitle := UI.column(0)
	header.add_child(subtitle)
	subtitle.add_child(UI.label("借风群岛", 14, UI.MINT))
	subtitle.add_child(UI.label("货运泊位与飞行码头", 18))
	var menu := _plate(map, Vector4(1,0,1,0), Vector4(-467,25,-32,83))
	menu.add_child(UI.button("工棚试摆台", open_station.bind("dock")))
	menu.add_child(UI.button("航海日志", open_journal))
	menu.add_child(UI.button("返回主港", func() -> void: home_requested.emit()))
	for key: String in MAP_LOCATIONS:
		var spot := UI.button(LOCATIONS[key].name, open_station.bind(key))
		spot.add_theme_stylebox_override("normal", UI.box(Color("#19373df7"), Color("#ddd4a4"), 6, 15, 6))
		spot.custom_minimum_size = Vector2(122, 37)
		spot.add_theme_font_size_override("font_size", 18)
		map.add_child(spot)
		map.buttons[key] = spot
		spot.focus_entered.connect(_point.bind(key))
		spot.mouse_entered.connect(_point.bind(key))
	var footer := _plate(map, Vector4(0,1,1,1), Vector4(32,-96,-32,-19))
	var pitch := UI.column(4)
	pitch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(pitch)
	route_state = UI.label("", 15, UI.AMBER)
	route_hint = UI.label("", 18, UI.INK, true)
	pitch.add_child(route_state)
	pitch.add_child(route_hint)
	sail = UI.button("去飞行机库", _sail, true)
	footer.add_child(sail)
	map.position_labels.call_deferred()

func _point(key: String) -> void:
	selected = key
	map.last_selected = key
	route_hint.text = LOCATIONS[key].detail
	if key == "loading":
		route_state.text = "早班泊位  /  修船厂提货"
	else:
		route_state.text = "港口航测委托　%d / 3" % _survey_receipts()
	map.queue_redraw()

func _sail() -> void:
	if _survey_receipts() == NIGHT_RUN.size():
		departed.emit()
	else:
		hangar_requested.emit()

func _survey_receipts() -> int:
	var count := 0
	for key: String in NIGHT_RUN:
		if profile.harbor_resolved.get(key, false):
			count += 1
	return count

func _update_map() -> void:
	map.moored = not profile.harbor_notes.get("chime", []).is_empty()
	map.beacon_lit = bool(profile.harbor_resolved.get("towers", false))
	for key: String in map.buttons:
		var button: Button = map.buttons[key]
		button.text = LOCATIONS[key].name + ("  ✓" if profile.harbor_resolved.get(key, false) else "")
	sail.text = "带上三份航测匣出港" if _survey_receipts() == NIGHT_RUN.size() else "去飞行机库"
	_point(selected)
	map.position_labels.call_deferred()

func _build_journal() -> void:
	journal = ColorRect.new()
	journal.color = UI.DEEP
	add_child(journal)
	journal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page := UI.column(18)
	journal.add_child(page)
	UI.place(page, Vector4(0,0,1,1), Vector4(44,30,-44,-28))
	var head := UI.row()
	page.add_child(head)
	var title := UI.label("航海日志", 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UI.button("合上日志", go_back))
	var shelf := UI.row(23)
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(shelf)
	note_list = ItemList.new()
	note_list.custom_minimum_size.x = 335
	note_list.add_theme_font_size_override("font_size", 18)
	note_list.add_theme_constant_override("v_separation", 12)
	note_list.item_selected.connect(_select_note)
	note_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	note_list.resized.connect(func() -> void: note_list.fixed_column_width = maxi(80, int(note_list.size.x)-27))
	shelf.add_child(note_list)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	panel.add_child(scroll)
	note_body = UI.column(9)
	note_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(note_body)
	var actions := UI.row()
	page.add_child(actions)
	compare = UI.button("对照上一次", _toggle_comparison)
	actions.add_child(compare)
	note_book = UI.button("翻到相关课件", func() -> void: manual_requested.emit())
	actions.add_child(note_book)

func _station_active(active: bool) -> void:
	for key: String in stations:
		var station: BaseStation = stations[key]
		var here := active and key == selected
		station.visible = here
		station.process_mode = Node.PROCESS_MODE_INHERIT if here else Node.PROCESS_MODE_DISABLED
		station.sounds_enabled = profile.sound and here

func show_map() -> void:
	screen = "map"
	_station_active(false)
	if not map.buttons.has(selected):
		selected = "loading"
	journal.hide()
	map.show()
	map.set_process(true)
	_update_map()
	restore_focus.call_deferred()

func open_station(key: String) -> void:
	if not LOCATIONS.has(key):
		return
	selected = key
	var instance: BaseStation = stations.get(key)
	if instance == null:
		var script: Script = load("res://harbor/{id}/{id}.gd".format({"id": key}))
		if script == null or not script.can_instantiate():
			return
		instance = script.new()
		if key == "loading":
			instance.set("first_order", profile.loading_next_order)
		instance.leave_requested.connect(show_map)
		instance.station_requested.connect(open_station)
		instance.manual_requested.connect(func() -> void: manual_requested.emit())
		instance.journal_requested.connect(open_journal)
		instance.cue_requested.connect(func(kind: String) -> void: cue_requested.emit(kind))
		instance.discovery.connect(_record.bind(key))
		instance.sounds_enabled = profile.sound
		stations[key] = instance
		add_child(instance)
	screen = "station"
	map.hide()
	map.set_process(false)
	journal.hide()
	_station_active(true)
	restore_focus.call_deferred()

func _record(evidence: Dictionary, location: String) -> void:
	if profile.record_investigation(location, evidence):
		save_requested.emit()

func open_journal() -> void:
	if screen == "journal":
		return
	journal_return = screen
	screen = "journal"
	_station_active(false)
	map.hide()
	map.set_process(false)
	journal.show()
	rows.clear()
	note_list.clear()
	var current_rows := 0
	for key: String in LOCATIONS:
		var notes: Array = profile.harbor_notes.get(key, [])
		if key == selected:
			current_rows = rows.size()
		for i in range(notes.size() - 1, -1, -1):
			rows.append([key, notes[i]])
			note_list.add_item("%s　·　%s" % [LOCATIONS[key].name, str(notes[i].title)])
			note_list.set_item_tooltip(rows.size()-1, str(notes[i].title))
	note_list.visible = not rows.is_empty()
	note_book.visible = not rows.is_empty()
	compare.hide()
	if rows.is_empty():
		_clear_note()
		note_location = ""
		note_body.add_child(UI.label("船上的第一本空日志", 28, UI.AMBER))
		note_body.add_child(UI.label("平板车过磅后，来这里翻磅票。港里的航测记录也收在这里。", 21, UI.INK, true))
	else:
		var index := current_rows if not profile.harbor_notes.get(selected, []).is_empty() else 0
		note_list.select(index)
		_select_note(index)
	restore_focus.call_deferred()

func _clear_note() -> void:
	for child in note_body.get_children():
		note_body.remove_child(child)
		child.queue_free()
	var scroll := note_body.get_parent() as ScrollContainer
	scroll.scroll_vertical = 0

func _select_note(index: int) -> void:
	note_index = index
	comparing = false
	_show_note()

func _toggle_comparison() -> void:
	comparing = not comparing
	_show_note()

func _show_note() -> void:
	var index := note_index
	if index < 0 or index >= rows.size():
		return
	_clear_note()
	note_location = rows[index][0]
	var note: Dictionary = rows[index][1]
	note_body.add_child(UI.label(LOCATIONS[note_location].name, 16, UI.MINT))
	note_body.add_child(UI.label(note.title, 28, UI.AMBER, true))
	compare.visible = index + 1 < rows.size() and rows[index + 1][0] == note_location
	compare.text = "返回本次记录" if comparing else "对照上一次"
	if comparing and compare.visible:
		var pair := UI.row(18)
		note_body.add_child(pair)
		for offset in 2:
			var entry: Dictionary = rows[index + offset][1]
			var column := UI.column(8)
			column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(column)
			column.add_child(UI.label("这一次" if offset == 0 else "上一次", 21, UI.AMBER))
			for field: String in ["observation", "prediction", "result"]:
				column.add_child(UI.label(_field_name(field), 16, UI.MINT))
				column.add_child(UI.label(entry[field], 17, UI.INK, true))
		return
	for field: String in LABELS:
		note_body.add_child(UI.label(_field_name(field), 16, UI.MINT))
		note_body.add_child(UI.label(note[field], 19, UI.INK, true))

func _field_name(field: String) -> String:
	if field == "prediction":
		if note_location == "loading": return "过磅前划的货位"
		if note_location == "quay": return "开工时的货单"
	return LABELS[field]

func related_courses() -> Array:
	var key := note_location if screen == "journal" and not note_location.is_empty() else selected
	return LOCATIONS[key].courses.duplicate()

func go_back() -> void:
	match screen:
		"station":
			if not stations[selected].handle_back():
				show_map()
		"journal":
			if journal_return == "station":
				open_station(selected)
			else:
				show_map()
		_: home_requested.emit()

func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if screen == "station":
		_station_active(active)
	if active:
		restore_focus.call_deferred()

func restore_focus() -> void:
	if not is_visible_in_tree():
		return
	match screen:
		"map": map.buttons[selected].grab_focus()
		"station": stations[selected]._focus_actions()
		"journal":
			if note_list.visible:
				note_list.grab_focus()
			else:
				journal.find_children("*", "Button", true, false)[0].grab_focus()
