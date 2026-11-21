extends Node

const Controls := preload("res://controls.gd")
const FlightUI := preload("res://ui/skin.gd")
const Flight := preload("res://flight/flight.gd")
const SkySurvey := preload("res://survey/sky_survey.gd")
const CaseCatalog := preload("res://survey/case_catalog.gd")
const SamplingLine := preload("res://survey/sampling_line.gd")
const Handbook := preload("res://library/library_panel.gd")
const Hud := preload("res://ui/flight_hud.gd")
const Chart := preload("res://ui/energy_chart.gd")
const SurveyPlot := preload("res://ui/survey_plot.gd")
const Recorder := preload("res://flight_recorder.gd")
const Sound := preload("res://flight_audio.gd")
const Harbour := preload("res://profile.gd")
const FogPort := preload("res://harbor/harbor.gd")

const ISLANDS := ["晴礁湾", "风琴峡", "暮金群岛"]
const SURVEYS := ["偏振灯标", "共振风铃", "量子双灯"]
const KIT := [
	{"key": "wing", "name": "加长布翼", "detail": "想跟云鳐慢一点飞？更长的翼面降低失速门槛，在热柱里展翼时更从容。"},
	{"key": "streamline", "name": "流线整流罩", "detail": "想低飞抢门？减小高速阻力，让一次俯冲的余速带你飞得更远。"},
	{"key": "ballast", "name": "压舱配重", "detail": "更快起飞、高速保速。失速门槛也更高，调头要提早。"},
]
const COLORS := ["海盐青", "落日金", "夜兰紫"]
const DYES_AT := [0, 12, 30]

var profile := Harbour.new()
var flight: Flight
var survey: SkySurvey
var sampling := SamplingLine.new()
var catalog := CaseCatalog.new()
var case_plan := PackedStringArray(["", "", ""])
var case_report: Dictionary = {}
var case_return := "title"
var field_choice: OptionButton
var case_list: ItemList
var case_details: Label
var case_status: Label
var csv_path := ""
var inspect_energy := false
var recorder := Recorder.new()
var sound := Sound.new()
var hud := Hud.new()
var book := Handbook.new()
var harbor := FogPort.new()
var ui := Control.new()
var overlay := Control.new()
var content: VBoxContainer
var mode := "boot"
var leg := 0
var route_seed := 0
var mods := {"wing": 0, "streamline": 0, "ballast": 0}
var selected_part := 0
var kit_buttons: Array[Button] = []
var kit_detail: Label
var leg_result: Dictionary = {}
var values: Dictionary = {}
var discoveries: Array = []
var observations: Array = []
var bonus := 0
var total_score := 0
var cargo_total := 0
var prior_record: Dictionary = {}
var new_record := false
var leg_score := 0
var flight_clock := 0.0
var thermal_seconds := 0.0
var folded_seconds := 0.0
var best_chain := 0
var book_return := ""
var book_focus: Control
var settings_return := "title"
var save_failed := false
var retry_mods: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	Controls.install()
	profile.load_profile()
	rng.randomize()
	get_window().min_size = Vector2i(760, 430)
	if profile.fullscreen and DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_FULLSCREEN
	flight = Flight.new()
	add_child(flight)
	add_child(recorder)
	survey = SkySurvey.new()
	add_child(survey)
	add_child(sampling)
	add_child(sound)
	sound.set_enabled(profile.sound)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = FlightUI.theme()
	ui.add_child(hud)
	ui.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	harbor.profile = profile
	ui.add_child(harbor)
	harbor.set_active(false)
	harbor.home_requested.connect(_home)
	harbor.manual_requested.connect(_open_book)
	harbor.hangar_requested.connect(_new_voyage.bind(false))
	harbor.departed.connect(_mail_route)
	harbor.save_requested.connect(_save)
	harbor.cue_requested.connect(sound.cue)
	ui.add_child(book)
	book.hide()
	book.closed.connect(_close_book)
	flight.telemetry.connect(_telemetry)
	flight.moment.connect(_moment)
	flight.finished.connect(_finish)
	survey.reading.connect(_survey_reading)
	survey.recovered.connect(_survey_recovered)
	sampling.reading.connect(_survey_reading)
	sampling.cargo.connect(_sample_cargo)
	sampling.recorded.connect(_sample_recorded)
	_home()

func _save() -> void:
	save_failed = not profile.persist()

func _freeze() -> void:
	flight.set_flying(false)
	survey.set_flying(false)
	sampling.set_flying(false)
	sound.set_flight(false)

func _page(id: String, wide: bool = false) -> void:
	mode = id
	get_viewport().disable_3d = id == "title"
	harbor.set_active(false)
	hud.hide()
	overlay.show()
	for child in overlay.get_children():
		overlay.remove_child(child)
		child.queue_free()
	var shade := TextureRect.new()
	var tint := Gradient.new()
	tint.offsets = PackedFloat32Array([0, 0.35 if not wide else 0.5, 0.69 if not wide else 0.78, 1])
	tint.colors = PackedColorArray([Color("#0b2028f7"), Color("#0c2731ef"), Color("#102f3847"), Color("#102f3814")])
	var texture := GradientTexture2D.new()
	texture.gradient = tint
	texture.width = 320
	texture.height = 4
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	overlay.add_child(margin)
	FlightUI.place(margin, Vector4(0, 0, 0, 1), Vector4(53, 24, 790 if wide else 585, -24))
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center)
	content = FlightUI.column(10)
	center.add_child(content)

func _heading(title: String, subtitle: String = "", big: bool = false) -> void:
	var label := FlightUI.label(title, 70 if big else 36)
	var font := FontVariation.new()
	font.base_font = ui.theme.default_font
	font.variation_embolden = 0.5
	label.add_theme_font_override("font", font)
	content.add_child(label)
	if not subtitle.is_empty():
		content.add_child(FlightUI.label(subtitle, 19, FlightUI.SOFT, true))

func _gap(amount: float = 8) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = amount
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(space)

func _action(title: String, callback: Callable, main: bool = false) -> Button:
	var button := FlightUI.button(title, callback, main)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(button)
	return button

func _add_row() -> HBoxContainer:
	var row := FlightUI.row()
	content.add_child(row)
	return row

func _focus(button: Control) -> void:
	var after_layout := func() -> void:
		if is_instance_valid(button) and button.is_inside_tree() and button.is_visible_in_tree():
			button.grab_focus()
	after_layout.call_deferred()

func _home() -> void:
	_freeze()
	recorder.clear_visuals()
	recorder.hide()
	flight.preview()
	_page("title")
	var cover := TextureRect.new()
	cover.texture = FogPort.ART
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(cover)
	overlay.move_child(cover, 0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_heading("借风群岛", "雾港来车提货了。重件放哪一头，由你指挥。两根车轴都过磅，司机就能发车。", true)
	_gap(15)
	var opening := "给下一辆车配载" if profile.loading_next_order > 0 else "给第一辆车配载"
	if harbor.stations.has("loading"):
		opening = "回到配载泊位"
	var launch := _action(opening, _enter_harbor.bind(true), true)
	_action("前往雾港地图", _enter_harbor)
	_action("开始新的远航", _new_voyage.bind(false))
	_action("领取航测匣", _open_cases)
	if profile.last_seed > 0:
		_action("重飞航线  %06d" % profile.last_seed, _new_voyage.bind(true))
	var row := _add_row()
	row.add_child(FlightUI.button("随船手册", _open_book))
	row.add_child(FlightUI.button("设置与操作", _open_settings))
	row.add_child(FlightUI.button("退出", _quit))
	if profile.seeds > 0 or profile.voyages > 0:
		content.add_child(FlightUI.label("已送达 %d 枚风种　·　三岛远航完成 %d 次" % [profile.seeds, profile.voyages], 16, FlightUI.MINT))
	if not profile.companions.is_empty():
		content.add_child(FlightUI.label("跟你回过港的云鳐　" + "　·　".join(profile.companions.keys()), 16, FlightUI.AMBER, true))
	if save_failed:
		content.add_child(FlightUI.label("本次进度暂存在内存中。", 16, FlightUI.AMBER))
	_focus(launch)

func _enter_harbor(start_at_loading: bool = false) -> void:
	_freeze()
	mode = "harbor"
	get_viewport().disable_3d = true
	overlay.hide()
	hud.hide()
	harbor.set_active(true)
	if start_at_loading:
		harbor.open_station("loading")
	else:
		harbor.show_map()
	sound.cue("dock")

func _mail_route() -> void:
	_prepare_voyage(false)
	case_plan = PackedStringArray(["01-7591bdc8", "21-3c117040", "20-d3ae2b69"])
	_store_itinerary()

func _new_voyage(replay: bool) -> void:
	_prepare_voyage(replay)
	_store_itinerary()

func _prepare_voyage(replay: bool) -> void:
	if replay and profile.last_seed > 0:
		route_seed = profile.last_seed
	else:
		route_seed = 361072 if profile.last_seed == 0 else rng.randi_range(1, 999999)
		if route_seed == profile.last_seed:
			route_seed = route_seed % 999999 + 1
	leg = 0
	total_score = 0
	cargo_total = 0
	mods = {"wing": 0, "streamline": 0, "ballast": 0}
	selected_part = 0
	case_plan = profile.last_cases.duplicate() if replay else PackedStringArray(["", "", ""])
	for i in case_plan.size():
		if not catalog.by_key.has(case_plan[i]):
			case_plan[i] = ""
	profile.last_seed = route_seed

func _hangar() -> void:
	_page("hangar")
	_heading(ISLANDS[leg] + "　·　机库", "航线 %06d　/　第 %d 段，共 3 段" % [route_seed, leg + 1])
	content.add_child(FlightUI.label("这一段带上哪件改装？", 22, FlightUI.MINT))
	var row := _add_row()
	kit_buttons.clear()
	for i in KIT.size():
		var button := FlightUI.button(KIT[i].name, _choose_kit.bind(i))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		kit_buttons.append(button)
	kit_detail = FlightUI.label("", 19, FlightUI.INK, true)
	kit_detail.custom_minimum_size.y = 60
	content.add_child(kit_detail)
	_choose_kit(selected_part)
	content.add_child(FlightUI.label("带一枚风种到灯塔。穿门可采种。跟着大鳐进入热柱，松开收翼键上升一会儿，小鳐就会赶来。", 17, FlightUI.SOFT, true))
	if case_plan[leg].is_empty():
		content.add_child(FlightUI.label("沿途可寻　" + SURVEYS[leg] + "　·　Q / LB 切换读头", 17, FlightUI.AMBER, true))
	else:
		content.add_child(FlightUI.label("已装匣　" + str(catalog.by_key[case_plan[leg]].title) + "　·　循紫环采样，第四站提前选线。", 17, FlightUI.AMBER, true))
	_gap()
	var launch := _action("放飞布翼艇", _launch.bind(false), true)
	var tools := _add_row()
	tools.add_child(FlightUI.button("更换航测匣", _open_cases))
	tools.add_child(FlightUI.button("操纵说明", _open_settings))
	tools.add_child(FlightUI.button("返回主港", _home))
	_focus(launch)

func _choose_kit(index: int) -> void:
	selected_part = index
	for i in kit_buttons.size():
		kit_buttons[i].set_pressed_no_signal(index == i)
		kit_buttons[i].add_theme_stylebox_override("normal", FlightUI.box(FlightUI.SEA, FlightUI.MINT if i == index else FlightUI.LINE))
	kit_detail.text = KIT[index].detail

func _open_cases() -> void:
	case_return = mode
	var current := case_plan[leg] if mode == "hangar" else ""
	_page("cases", true)
	_heading("领取航测匣", "前三站会亮起紫环，告诉你货物落在哪个刻度。第四站雾起，只剩输入条件和两端刻度。选对飞线，可以再带五枚风种回港。")
	field_choice = OptionButton.new()
	for field: Dictionary in catalog.fields:
		field_choice.add_item(str(field.name))
		field_choice.set_item_metadata(field_choice.item_count - 1, field.id)
		if catalog.by_key.has(current) and catalog.by_key[current].field == field.id:
			field_choice.select(field_choice.item_count - 1)
	field_choice.item_selected.connect(_list_cases)
	content.add_child(field_choice)
	case_list = ItemList.new()
	case_list.custom_minimum_size.y = 170
	case_list.add_theme_font_size_override("font_size", 18)
	case_list.add_theme_color_override("font_color", FlightUI.INK)
	case_list.add_theme_stylebox_override("panel", FlightUI.box(FlightUI.DEEP, FlightUI.LINE, 8, 10, 5))
	case_list.item_selected.connect(_describe_case)
	case_list.item_activated.connect(func(index: int) -> void: _load_case(str(case_list.get_item_metadata(index))))
	content.add_child(case_list)
	case_details = FlightUI.label("", 17, FlightUI.INK, true)
	case_details.custom_minimum_size.y = 74
	content.add_child(case_details)
	case_status = FlightUI.label("", 15, FlightUI.MINT, true)
	content.add_child(case_status)
	var row := _add_row()
	row.add_child(FlightUI.button("装入机库", _load_selected_case, true))
	row.add_child(FlightUI.button("派一张未飞匣", _pick_unflown))
	if case_return == "hangar" and not current.is_empty():
		row.add_child(FlightUI.button("卸下航测匣", _unload_cases))
	row.add_child(FlightUI.button("返回", _back_from_cases))
	_list_cases(field_choice.selected)
	if catalog.by_key.has(current):
		for index in case_list.item_count:
			if case_list.get_item_metadata(index) == current:
				case_list.select(index)
				_describe_case(index)
				case_list.ensure_current_is_visible()
				break
	_focus(field_choice)

func _list_cases(index: int) -> void:
	case_list.clear()
	for key in catalog.by_field.get(field_choice.get_item_metadata(index), []):
		var card: Dictionary = catalog.by_key[key]
		var marked := "　✓" if int(profile.case_records.get(key, {}).get("hits", 0)) > 0 else ""
		case_list.add_item(str(card.title) + marked)
		case_list.set_item_metadata(case_list.item_count - 1, key)
	if case_list.item_count > 0:
		case_list.select(0)
		_describe_case(0)

func _describe_case(index: int) -> void:
	var key := str(case_list.get_item_metadata(index))
	var card: Dictionary = catalog.by_key[key]
	case_details.text = "%s　→　%s\n%s" % [card.input, card.output, card.rule]
	var history: Dictionary = profile.case_records.get(key, {})
	case_status.text = "已飞 %d / %d 张　·　本匣盲接 %d / %d 次命中　·　后续岛屿顺接本领域的下一张" % [
		profile.case_records.size(), catalog.by_key.size(), history.get("hits", 0), history.get("attempts", 0)]

func _load_selected_case() -> void:
	var selected := case_list.get_selected_items()
	if not selected.is_empty():
		_load_case(str(case_list.get_item_metadata(selected[0])))

func _pick_unflown() -> void:
	var free: Array = []
	for key in catalog.by_key:
		if not profile.case_records.has(key):
			free.append(key)
	if free.is_empty():
		free = catalog.by_key.keys()
	if not free.is_empty():
		_load_case(free[rng.randi_range(0, free.size() - 1)])

func _load_case(key: String) -> void:
	if not catalog.by_key.has(key):
		return
	if case_return == "title":
		_prepare_voyage(false)
	var selection := catalog.next_cases(key, 3 - leg)
	for i in selection.size():
		case_plan[leg + i] = selection[i]
	_store_itinerary()

func _unload_cases() -> void:
	for i in range(leg, 3):
		case_plan[i] = ""
	_store_itinerary()

func _store_itinerary() -> void:
	profile.last_cases = case_plan.duplicate()
	_save()
	_hangar()

func _back_from_cases() -> void:
	if case_return == "hangar":
		_hangar()
	else:
		_home()

func _launch(retry: bool) -> void:
	if not retry:
		retry_mods = mods.duplicate()
		var key: String = KIT[selected_part].key
		mods[key] = int(mods[key]) + 1
	bonus = 0
	case_report = {}
	csv_path = ""
	inspect_energy = false
	leg_result.clear()
	values.clear()
	discoveries.clear()
	observations.clear()
	flight_clock = 0
	thermal_seconds = 0
	folded_seconds = 0
	best_chain = 0
	prior_record = profile.record_for(route_seed, leg, case_plan[leg])
	recorder.begin(prior_record, profile.ghost, profile.ribbon)
	mode = "flight"
	overlay.hide()
	hud.start_leg(leg, ISLANDS[leg], "带一枚风种抵港")
	flight.start_leg(route_seed, leg, mods.duplicate())
	sampling.clear()
	if case_plan[leg].is_empty():
		survey.start_leg(route_seed, leg, flight)
	else:
		survey.set_flying(false)
		discoveries.append(case_plan[leg])
		sampling.start_leg(route_seed, leg, flight, catalog.by_key[case_plan[leg]])
	flight.set_flying(true)
	sound.set_flight(true)

func _telemetry(data: Dictionary) -> void:
	if mode != "flight":
		return
	values = data.duplicate()
	best_chain = maxi(best_chain, int(data.get("chain", 0)))
	hud.telemetry(data, "%s　·　Q / LB 换档" % SURVEYS[leg] if case_plan[leg].is_empty() else "紫环航测　·　Q / LB 查看匣签")
	sound.wind_speed(float(data.get("speed", 0)), bool(data.get("folded", false)))

func _moment(kind: String, message: String) -> void:
	if mode != "flight":
		return
	hud.flash(message, kind)
	sound.cue(kind)

func _survey_reading(message: String) -> void:
	if mode == "flight":
		hud.instrument(message)

func _sample_cargo(amount: int, message: String) -> void:
	if mode == "flight":
		bonus += amount
		flight.add_survey_cargo(amount)
		hud.flash(message, "seed")
		sound.cue("chain" if amount > 0 else "survey")

func _sample_recorded(report: Dictionary) -> void:
	if mode != "flight" or not case_report.is_empty():
		return
	case_report = report.duplicate(true)
	profile.log_instrument(report)
	_save()

func _survey_recovered(amount: int, course_keys: Array, message: String) -> void:
	if mode != "flight":
		return
	bonus += amount
	flight.add_survey_cargo(amount)
	for key in course_keys:
		if key not in discoveries:
			discoveries.append(key)
	if not message.is_empty():
		observations.append(message)
	hud.flash(message, "seed")
	sound.cue("chain" if amount > 0 else "survey")

func _physics_process(delta: float) -> void:
	if mode != "flight":
		return
	flight_clock += delta
	if values.is_empty():
		return
	if values.get("in_thermal", false):
		thermal_seconds += delta
	if values.get("folded", false):
		folded_seconds += delta
	var pose := flight.get_pilot_transform()
	recorder.sample_pose(pose, flight_clock, float(values.get("height", 0)), float(values.get("speed", 0)))
	recorder.fly(pose, flight_clock, delta, bool(values.get("folded", false)))

func _finish(result: Dictionary) -> void:
	if mode != "flight":
		return
	leg_result = result.duplicate(true)
	# Survey cargo is a real delivery. Flight owns the physical arrival conditions.
	if not values.is_empty():
		recorder.sample_pose(flight.get_pilot_transform(), flight_clock, float(values.get("height", 0)), float(values.get("speed", 0)), true)
	for key in result.get("relevant_keys", []):
		if key not in discoveries:
			discoveries.append(key)
	var delivered := int(result.get("seeds", 0))
	var duration := float(result.get("time", flight_clock))
	leg_score = delivered * 100 + int(result.get("gates", 0)) * 65 + best_chain * 25
	new_record = false
	if result.get("success", false):
		cargo_total += delivered
		total_score += leg_score
		profile.seeds += delivered
		if result.get("companion", false):
			var name_of_ray := str(result.get("companion_name", ""))
			profile.companions[name_of_ray] = int(profile.companions.get(name_of_ray, 0)) + 1
		new_record = profile.store_record(route_seed, leg, leg_score, duration, recorder.track.duplicate(), case_plan[leg])
		if leg == 2:
			profile.voyages += 1
			profile.best_total = maxi(profile.best_total, total_score)
		_save()
	_freeze()
	recorder.clear_visuals()
	sound.cue("home" if result.get("success", false) else "land")
	_results()

func _results() -> void:
	_page("result", true)
	var won := bool(leg_result.get("success", false))
	var headline := "风种抵港" if won else "布翼艇返修"
	if won and leg == 2:
		headline = "三岛亮灯了"
	_heading(headline, "%s　·　航线 %06d　·　%.1f 秒" % [ISLANDS[leg], route_seed, float(leg_result.get("time", flight_clock))])
	if not won:
		var reason := str(leg_result.get("reason", ""))
		content.add_child(FlightUI.label(reason if not reason.is_empty() else "带上一枚风种，保持到终岛接引区的高度。可以重飞同一片风场。", 18, FlightUI.AMBER, true))
	var result_line := "风种 %d　·　航门 %d　·　最长连门 %d" % [int(leg_result.get("seeds", 0)), int(leg_result.get("gates", 0)), best_chain]
	content.add_child(FlightUI.label(result_line, 23, FlightUI.MINT))
	if won:
		var comparison := "　·　本航段个人纪录" if new_record else "　·　个人最好 %d" % int(prior_record.get("score", 0))
		content.add_child(FlightUI.label("航段得分 %d%s　·　远航累计 %d" % [leg_score, comparison, total_score], 17, FlightUI.SOFT))
		if leg_result.get("companion", false):
			content.add_child(FlightUI.label("「%s」跟你飞进了港湾，在灯塔旁等到了它的鳐群。" % leg_result.companion_name, 17, FlightUI.AMBER, true))
	if not case_report.is_empty() and not inspect_energy:
		content.add_child(FlightUI.label("四站航测　·　紫点为模型，金圈是你飞过的位置　·　" + str(case_report.output), 16, FlightUI.SOFT, true))
		var plot := SurveyPlot.new()
		plot.report = case_report
		plot.left_label = sampling.format_value(case_report.low)
		plot.right_label = sampling.format_value(case_report.high)
		content.add_child(plot)
	elif recorder.samples.size() > 1:
		content.add_child(FlightUI.label("实测航迹　·　青线为高度，金线为空速折合的高度 v²/(2g)，单位 m", 16, FlightUI.SOFT, true))
		var chart := Chart.new()
		chart.samples = recorder.samples
		content.add_child(chart)
	content.add_child(FlightUI.label("上升气流中 %.1f 秒　·　收翼 %.1f 秒　·　观测风种 %d" % [thermal_seconds, folded_seconds, bonus], 17, FlightUI.INK))
	if not observations.is_empty():
		content.add_child(FlightUI.label(str(observations[-1]), 16, FlightUI.AMBER, true))
	if not case_report.is_empty():
		var last: Dictionary = case_report.samples.back()
		content.add_child(FlightUI.label("%s　·　%s　·　%s\n%s　你的刻度 %s　/　模型 %s" % [
			case_report.title, last.condition, case_report.feedback, case_report.output,
			sampling.format_value(last.estimate), sampling.format_value(last.model)], 16, FlightUI.AMBER, true))
	if won and leg == 2:
		content.add_child(FlightUI.label("这一趟带回 %d 枚风种。回到同一航线，会看到自己的最佳航迹。" % cargo_total, 18, FlightUI.INK, true))
	var first: Button
	if won and leg < 2:
		first = _action("前往" + ISLANDS[leg + 1] + "，改装下一段", _next_leg, true)
	elif won:
		first = _action("换一片风场，再飞一趟", _new_voyage.bind(false), true)
	else:
		first = _action("重飞这一段", _launch.bind(true), true)
	var row := _add_row()
	if not won:
		row.add_child(FlightUI.button("换件改装", _refit))
	elif leg == 2:
		row.add_child(FlightUI.button("挑战同一航线", _new_voyage.bind(true)))
	row.add_child(FlightUI.button("查本段物理", _open_book))
	if not case_report.is_empty():
		row.add_child(FlightUI.button("航测图" if inspect_energy else "能量图", _swap_chart))
		row.add_child(FlightUI.button("保存航测 CSV" if csv_path.is_empty() else "打开航测目录", _export_case))
	row.add_child(FlightUI.button("返回主港", _home))
	_focus(first)

func _swap_chart() -> void:
	inspect_energy = not inspect_energy
	_results()

func _export_case() -> void:
	if not csv_path.is_empty():
		OS.shell_open(csv_path.get_base_dir())
		return
	csv_path = profile.export_samples(case_report)
	if csv_path.is_empty():
		content.add_child(FlightUI.label("未能写入航测目录。", 15, FlightUI.AMBER))
	else:
		_results()

func _refit() -> void:
	mods = retry_mods.duplicate()
	_hangar()

func _next_leg() -> void:
	leg += 1
	selected_part = 0
	_hangar()

func _pause() -> void:
	_freeze()
	_page("pause")
	_heading("在风中歇一会", ISLANDS[leg] + "　·　航线 %06d" % route_seed)
	var resume := _action("继续飞行", _resume, true)
	_action("随船手册", _open_book)
	_action("设置与操作", _open_settings)
	_action("从本段起点重飞", _launch.bind(true))
	_action("结束这趟远航", _home)
	_focus(resume)

func _resume() -> void:
	mode = "flight"
	overlay.hide()
	hud.show()
	flight.set_flying(true)
	survey.set_flying(case_plan[leg].is_empty())
	sampling.set_flying(not case_plan[leg].is_empty())
	sound.set_flight(true)

func _open_book() -> void:
	book_return = mode
	book_focus = get_viewport().gui_get_focus_owner()
	if mode == "flight":
		_freeze()
	if mode == "harbor":
		harbor.set_active(false)
	hud.hide()
	overlay.hide()
	mode = "library"
	var related: Array = []
	if book_return == "harbor":
		related = harbor.related_courses()
	if book_return in ["flight", "pause", "result"]:
		related = discoveries.duplicate()
		for key in flight.get_course_keys():
			if key not in related:
				related.append(key)
		if not values.is_empty() and "00-1" not in related:
			related.append("00-1")
	book.show_library(related, "此处的物理课件" if book_return == "harbor" else "本段飞行相关")

func _close_book() -> void:
	if mode != "library":
		return
	if book_return == "flight":
		_resume()
	elif book_return == "harbor":
		mode = "harbor"
		harbor.set_active(true)
		if is_instance_valid(book_focus):
			_focus(book_focus)
	else:
		mode = book_return
		overlay.show()
		if is_instance_valid(book_focus) and book_focus.is_visible_in_tree():
			_focus(book_focus)

func _open_settings() -> void:
	settings_return = mode
	_settings()

func _settings() -> void:
	_page("settings", true)
	_heading("机库设置", "键盘、方向键和手柄都可驾驶。菜单中用方向键或十字键选择，回车或 A 确认。")
	content.add_child(FlightUI.label("A / D 转向，W 拉升，S 俯冲　·　左摇杆或十字键操纵\n按住空格 / RT / A 收翼　·　E / X 放测距浮标　·　Q / LB 换观测档\nTab / Y 打开手册　·　Esc / 菜单键 暂停　·　F11 全屏", 18, FlightUI.SOFT, true))
	var buttons := _add_row()
	var audio_toggle := FlightUI.button("声音　" + ("开" if profile.sound else "关"), _toggle_sound)
	buttons.add_child(audio_toggle)
	buttons.add_child(FlightUI.button("全屏　" + ("开" if profile.fullscreen else "关"), _toggle_fullscreen))
	buttons.add_child(FlightUI.button("个人航迹　" + ("开" if profile.ghost else "关"), _toggle_ghost))
	_gap(1)
	content.add_child(FlightUI.label("翼尖烟带　·　已送达 %d 枚风种" % profile.seeds, 18, FlightUI.MINT))
	var dyes := _add_row()
	for i in COLORS.size():
		var owned: bool = profile.seeds >= DYES_AT[i]
		var caption: String = COLORS[i] + ("　✓" if i == profile.ribbon else "")
		if not owned:
			caption += "　%d 枚" % DYES_AT[i]
		var dye := FlightUI.button(caption, _set_ribbon.bind(i))
		dye.disabled = not owned
		dyes.add_child(dye)
	var tools := _add_row()
	tools.add_child(FlightUI.button("制作与许可", _credits))
	var back := FlightUI.button("返回", _settings_back, true)
	tools.add_child(back)
	_focus(back)

func _toggle_sound() -> void:
	profile.sound = not profile.sound
	sound.set_enabled(profile.sound)
	sound.cue("seed")
	_save()
	_settings()

func _toggle_ghost() -> void:
	profile.ghost = not profile.ghost
	_save()
	_settings()

func _toggle_fullscreen() -> void:
	profile.fullscreen = not profile.fullscreen
	if DisplayServer.get_name() != "headless":
		get_window().mode = Window.MODE_FULLSCREEN if profile.fullscreen else Window.MODE_WINDOWED
	_save()
	if mode == "settings":
		_settings()

func _set_ribbon(index: int) -> void:
	if profile.seeds < DYES_AT[index]:
		return
	profile.ribbon = index
	_save()
	_settings()

func _settings_back() -> void:
	match settings_return:
		"hangar": _hangar()
		"pause": _pause()
		_: _home()

func _credits() -> void:
	_page("credits", true)
	_heading("制作与许可", "借风群岛　·　原创 Blender 模型、程序生成音效与本仓库物理课程")
	var credits := RichTextLabel.new()
	credits.custom_minimum_size.y = 325
	credits.focus_mode = Control.FOCUS_ALL
	credits.selection_enabled = true
	var blocks := PackedStringArray(["Godot Engine", Engine.get_license_text()])
	for component in Engine.get_copyright_info():
		blocks.append(str(component.get("name", "")))
		for part in component.get("parts", []):
			blocks.append("\n".join(part.get("copyright", [])) + "\n" + str(part.get("license", "")))
	var licenses := Engine.get_license_info()
	for code in licenses:
		blocks.append(str(code) + "\n" + str(licenses[code]))
	credits.text = "\n\n".join(blocks)
	content.add_child(credits)
	var back := _action("返回设置", _settings, true)
	_focus(back)

func _quit() -> void:
	sound.set_enabled(false)
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("full_screen"):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif mode == "library":
		if event.is_action_pressed("open_log"):
			book.close_library()
			get_viewport().set_input_as_handled()
	elif mode == "harbor":
		if event.is_action_pressed("ui_cancel"):
			harbor.go_back()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("open_log"):
			_open_book()
			get_viewport().set_input_as_handled()
		elif (event is InputEventKey and event.keycode == KEY_J and event.pressed) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK and event.pressed):
			if harbor.screen == "journal":
				harbor.go_back()
			else:
				harbor.open_journal()
			get_viewport().set_input_as_handled()
	elif mode == "flight":
		if event.is_action_pressed("flight_pause") or event.is_action_pressed("ui_cancel"):
			_pause()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("open_log"):
			_open_book()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("tune"):
			if case_plan[leg].is_empty():
				survey.tune()
			else:
				sampling.tune()
			get_viewport().set_input_as_handled()
	elif mode == "pause" and (event.is_action_pressed("flight_pause") or event.is_action_pressed("ui_cancel")):
		_resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		match mode:
			"cases":
				if field_choice.get_popup().visible:
					field_choice.get_popup().hide()
				else:
					_back_from_cases()
			"settings": _settings_back()
			"credits": _settings()
			"hangar", "result": _home()
			_: return
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "flight":
		_pause()
