extends "res://harbor/station.gd"

const Weather := preload("res://harbor/wind/convection.gd")
const SeaChart := preload("res://harbor/wind/chart.gd")
const TIDE_NAMES := ["青岬雾", "倒卷雾"]
const TICKS_PER_SECOND := 30.0

var chart: Control
var phase := "dock"
var tide := 0
var fine_probe := false
var clock_tick := 0
var truth := Vector3.ZERO
var estimate := Vector3.ZERO
var members: Array[Vector3] = []
var anchor := Vector3.ZERO
var anchor_tick := 0
var anchor_error := 0.0
var sampled := Vector3.ZERO
var buoy_place := ""
var waited := false
var section := "outer"
var segment_tick := 0
var offset_m := 0.0
var peak_m := 0.0
var outlooks: Dictionary = {}
var predicted: Dictionary = {}
var course_trace: Array[Dictionary] = []
var actual_curve := PackedFloat32Array()
var entered := ""
var outcome := ""
var delivered := false
var filed := false
var comparison := ""
var probe_open := false
var probe_trace: Dictionary = {}
var probe_tick := 0
var probe_marks: Array[int] = []
var buoy_comparison := ""
var _live: Label
var _time_bank := 0.0
var _held_rudder := 0.0
var _pulse := 0.0
var _pulse_ticks := 0

func _begin() -> void:
	set_scene("雾谷末班邮船", "运一袋信到灯塔。潮闸 14.0 港分关闭，船上只有一枚测风浮标。")
	chart = SeaChart.new()
	chart.station = self
	bind_view(chart)
	_reset()

func _reset() -> void:
	phase = "dock"
	clock_tick = 0
	truth = Weather.TIDES[tide]
	buoy_place = ""
	waited = false
	section = "outer"
	segment_tick = 0
	offset_m = 0
	peak_m = 0
	entered = ""
	outcome = ""
	delivered = false
	filed = false
	comparison = ""
	probe_open = false
	buoy_comparison = ""
	_live = null
	_time_bank = 0.0
	_held_rudder = 0
	_pulse_ticks = 0
	course_trace.clear()
	actual_curve = PackedFloat32Array([0.0])
	_measure()
	_show_stop()
	set_hint("想看预报为何会偏，先并排试两支探头。开船后你只有一枚浮标，能在双礁或雾口重新测一次。")

func precision() -> float:
	return .03 if fine_probe else .30

func port_minutes(ticks: int) -> float:
	return ticks*Weather.MINUTES_PER_TICK

func _measure() -> void:
	anchor = truth
	anchor_tick = clock_tick
	estimate = Weather.reading(truth, clock_tick, precision(), tide)
	sampled = estimate
	anchor_error = truth.distance_to(estimate)
	members = Weather.candidates(estimate, precision())

func _advance_wind() -> float:
	var start_residual := Weather.wind(truth)-Weather.wind(estimate)
	truth = Weather.step(truth)
	estimate = Weather.step(estimate)
	for i in members.size():
		members[i] = Weather.step(members[i])
	clock_tick += 1
	return .5*(start_residual+Weather.wind(truth)-Weather.wind(estimate))

func _gear_title() -> String:
	return "精密探头" if fine_probe else "普通探头"

func _show_stop() -> void:
	_live = null
	outlooks.clear()
	var keys := ["outer"] if phase == "dock" else (["shoal"] if phase == "shoal" else ["narrow","bay"])
	for key: String in keys:
		outlooks[key] = Weather.outlook(estimate, members, key)
	predicted = outlooks[keys[0]]
	actual_curve = PackedFloat32Array([0.0])
	match phase:
		"dock":
			set_tools("今夜的信袋", "%s · %s ±%.2f 格\n邮船正停在图左，收信人的灯在右岸。" % [TIDE_NAMES[tide], _gear_title(), precision()])
			add_action("解缆 · 开往双礁", sail.bind("outer"), true)
			add_action("并排试两支探头", _open_probes.bind(false))
			add_action("换装%s" % ("普通探头" if fine_probe else "十倍精密探头"), _change_probe)
			add_action("换一场雾 · %s" % TIDE_NAMES[1-tide], _change_tide)
			add_readout("港分是游戏内航时。两支探头可在同一场雾下复航。")
		"shoal":
			set_tools("双礁浮台", "下一程穿过浅滩，安全半宽 32 m。这里与雾口都能投浮标。")
			add_action("穿过浅滩 · 去雾口", sail.bind("shoal"), true)
			_buoy_button()
			add_action("看同雾对照，再决定投不投", _open_probes.bind(false))
			add_readout(_risk_line("shoal"))
		"mouth":
			set_tools("雾口 · 选航道", "裂帆峡近而窄。绕灯笼湾多用 2.1 港分，背风水面较宽。")
			var strait := add_action("入裂帆峡 · 4.35 分", sail.bind("narrow"), true)
			var bay := add_action("绕灯笼湾 · 6.48 分", sail.bind("bay"))
			strait.focus_entered.connect(preview_lane.bind("narrow"))
			bay.focus_entered.connect(preview_lane.bind("bay"))
			strait.mouse_entered.connect(preview_lane.bind("narrow"))
			bay.mouse_entered.connect(preview_lane.bind("bay"))
			_buoy_button()
			add_action("看同雾对照，再决定投不投", _open_probes.bind(false))
			if not waited:
				add_action("系缆候风 · 1.20 分", _wait_tide)
			add_readout(_risk_line("narrow")+"\n"+_risk_line("bay"))
	add_readout("风态 x / y / z　%.2f，%.2f，%.2f\n读于 %.2f 港分　误差半径 %.2f 格" % [sampled.x, sampled.y, sampled.z, port_minutes(anchor_tick), precision()])
	chart.queue_redraw()

func _risk_line(key: String) -> String:
	var r: Dictionary = outlooks[key]
	var marker := "到港" if key in ["narrow","bay"] else "到雾口"
	return "%s　%d/%d 触线 · %s %.2f 分" % [Weather.LEGS[key].name, r.outside, r.total, marker, port_minutes(clock_tick + int(Weather.LEGS[key].ticks))]

func preview_lane(key: String) -> void:
	if phase == "mouth" and outlooks.has(key):
		predicted = outlooks[key]
		chart.queue_redraw()

func _buoy_button() -> void:
	if buoy_place.is_empty():
		add_action("在此投浮标 · 0.72 分", drop_buoy)
	else:
		add_readout("浮标已留在"+buoy_place)

func _change_probe() -> void:
	if phase != "dock":
		return
	fine_probe = not fine_probe
	_reset()

func _change_tide() -> void:
	if phase != "dock":
		return
	tide = 1-tide
	_reset()

func drop_buoy() -> void:
	if not buoy_place.is_empty() or phase not in ["shoal","mouth"]:
		return
	buoy_place = "双礁浮台" if phase == "shoal" else "雾口"
	for i in Weather.BUOY_TICKS:
		_advance_wind()
	var old_error := truth.distance_to(estimate)
	_measure()
	buoy_comparison = "在%s的同一时刻，旧预报离实际风态 %.3f 格，重测后相差 %.3f 格。后半程从新读数起算。" % [
		buoy_place, old_error, truth.distance_to(estimate)]
	play_cue("survey")
	_show_stop()
	set_hint(buoy_comparison)

func _wait_tide() -> void:
	if phase != "mouth" or waited:
		return
	waited = true
	for i in Weather.WAIT_TICKS:
		_advance_wind()
	play_cue("survey")
	_show_stop()
	set_hint("船在缆桩旁等了 1.2 港分。比较新的风轨和靠岸钟点，再决定走哪条水道。")

func sail(key: String) -> void:
	if (phase == "dock" and key != "outer") or (phase == "shoal" and key != "shoal") or (phase == "mouth" and key not in ["narrow","bay"]):
		return
	if phase not in ["dock", "shoal", "mouth"] or not outlooks.has(key):
		return
	section = key
	predicted = outlooks[key]
	var spec: Dictionary = Weather.LEGS[key]
	var buoy := "留着浮标" if buoy_place.is_empty() else "浮标留在"+buoy_place
	entered = "%.2f 港分驶入%s，%s%s。出发前 %d/%d 条风轨触线，预计最大横偏 %.1f m，半宽 %.0f m，预计到点 %.2f 分。" % [
		port_minutes(clock_tick), spec.name, buoy, "，已候风" if waited else "", predicted.outside, predicted.total,
		predicted.maximum, spec.width, port_minutes(clock_tick+int(spec.ticks))]
	segment_tick = 0
	offset_m = 0.0
	peak_m = 0.0
	actual_curve = PackedFloat32Array([0.0])
	_held_rudder = 0
	_pulse_ticks = 0
	_time_bank = 0
	phase = "sailing"
	course_trace.append({"key":key,"t":0.0,"off":0.0})
	set_tools("驶向"+str(spec.name), "自动舵正在抵消预报横风。按 A / D、左摇杆，或按住船两侧的水面打舵。")
	_live = add_readout("")
	add_action("短打左舵", _nudge.bind(-1.0))
	add_action("短打右舵", _nudge.bind(1.0))
	_sync_live()
	set_hint("图底暖线是船的实测横偏。碰到两侧红线，护邮艇就要来接信袋。")
	play_cue("launch")
	chart.queue_redraw()

func chart_turn(value: float) -> void:
	_held_rudder = value if phase == "sailing" else 0.0

func _nudge(value: float) -> void:
	if phase == "sailing":
		_pulse = value
		_pulse_ticks = 8

func _sync_live() -> void:
	if is_instance_valid(_live):
		_live.text = "横偏　%+.1f m　/　半宽 %.0f m\n船上风带　%+.1f m/s\n港钟　%.2f / 14.00 分" % [offset_m, Weather.LEGS[section].width, Weather.wind(truth), port_minutes(clock_tick)]

func _process(delta: float) -> void:
	if phase != "sailing":
		return
	_time_bank += minf(delta,.13)*TICKS_PER_SECOND
	while _time_bank >= 1.0 and phase == "sailing":
		_time_bank -= 1.0
		var rudder := _held_rudder
		if InputMap.has_action("steer_left"):
			rudder += Input.get_axis("steer_left","steer_right")
		if _pulse_ticks > 0:
			rudder += _pulse
			_pulse_ticks -= 1
		_sail_tick(clampf(rudder,-1,1))
	chart.queue_redraw()

func _sail_tick(rudder: float) -> void:
	var spec: Dictionary = Weather.LEGS[section]
	offset_m = Weather.drift(offset_m, _advance_wind(), spec.exposure, rudder)
	segment_tick += 1
	peak_m = maxf(peak_m, absf(offset_m))
	if segment_tick % 2 == 0 or segment_tick == int(spec.ticks):
		course_trace.append({"key":section,"t":float(segment_tick)/spec.ticks,"off":offset_m})
	actual_curve.append(offset_m)
	if segment_tick % 3 == 0:
		_sync_live()
	if absf(offset_m) >= float(spec.width):
		_finish(false, "护邮艇在%s把船拖回，信袋错过末班。" % spec.name)
	elif port_minutes(clock_tick) > Weather.LOCK_MINUTES:
		_finish(false, "潮闸准时落下，信袋留在外港。")
	elif segment_tick >= int(spec.ticks):
		if section in ["narrow", "bay"]:
			_finish(true, "信袋送上灯塔，值夜人把回信别在你的桅杆上。")
		else:
			phase = "shoal" if section == "outer" else "mouth"
			_show_stop()
			set_hint("系在%s的避风桩。上一程实测最大横偏 %.1f m。" % ["双礁" if phase=="shoal" else "雾口", peak_m])
			play_cue("gate")

func _finish(won: bool, message: String) -> void:
	phase = "done"
	delivered = won
	outcome = message
	_held_rudder = 0
	_live = null
	_show_outcome()
	if not won:
		_file(false)
	set_hint("留下这一程的风迹，核对十倍精度能多看清多少港分。")
	play_cue("finish" if won else "impact")
	chart.queue_redraw()

func _show_outcome() -> void:
	var account := outcome
	if not delivered:
		if absf(offset_m) >= float(Weather.LEGS[section].width):
			account += "触线时船偏了 %.1f m，航道只容 %.1f m。当时实况横风与预报相差 %+.2f m/s，偏航还受你打舵的影响。" % [
				absf(offset_m), Weather.LEGS[section].width, Weather.wind(truth) - Weather.wind(estimate)]
		else:
			account += "靠港钟点已到 %.2f 港分，潮闸在 %.2f 分关闭。" % [port_minutes(clock_tick), Weather.LOCK_MINUTES]
	set_tools("灯塔收到信了" if delivered else "末班未到", account)
	add_action("核对两支探头", _compare, true)
	add_action("沿同一场雾再开", _replay)
	add_readout("%s · %.2f 港分\n实测最大横偏 %.1f m，安全半宽 %.0f m。" % [Weather.LEGS[section].name, port_minutes(clock_tick), peak_m, Weather.LEGS[section].width])

func _window(value: float) -> String:
	return "至少 24" if value < 0.0 else "%.2f" % value

func _compare() -> void:
	if phase != "done":
		return
	var first_reading := comparison.is_empty()
	_open_probes(true)
	var crossed: Vector2i = probe_trace.crossed
	comparison = "同一观测点回放，状态误差首次达到 1 格。普通探头用时 %s 港分，十倍精密探头用时 %s 港分。" % [
		_window(port_minutes(crossed.x)), _window(port_minutes(crossed.y))]
	if delivered:
		_file(true)
	elif first_reading:
		# A failed delivery already filed the raw crossing. Keep its matched
		# hindcast as a second, unresolved observation when the player opens it.
		filed = false
		_file(false)
	play_cue("survey")

func _open_probes(own_voyage: bool) -> void:
	# The old training tape is separate from the live route. After docking, its
	# replacement is the player's exact last observation, including a deployed buoy.
	var start := anchor if own_voyage else Vector3(-7.1, -4.0, 29.6)
	probe_trace = Weather.probe_trace(start, anchor_tick if own_voyage else 0, tide if own_voyage else 0)
	probe_marks = [0, 100, 200, 400, 600, 800]
	var crossed: Vector2i = probe_trace.crossed
	for tick_value in [crossed.x, crossed.y]:
		if tick_value >= 0 and not probe_marks.has(tick_value): probe_marks.append(tick_value)
	probe_marks.sort()
	probe_open = true
	_set_probe_tick(0)

func _set_probe_tick(value: int) -> void:
	probe_tick = clampi(value, 0, 800)
	var next := 800
	var previous := 0
	for spot in probe_marks:
		if spot < probe_tick: previous = spot
		if spot > probe_tick:
			next = spot
			break
	var source := "本航次 %.2f 港分的观测点" % port_minutes(anchor_tick) if phase == "done" else "训练船封存的旧风录"
	set_tools("两支探头看同一阵雾", "%s。只换探头，两份略有差异的初读数用同一模型往前推。拨到同一时刻，看谁先离实况 1 格。" % source)
	if probe_tick < 800:
		add_action("放到 %.2f 港分" % port_minutes(next), _set_probe_tick.bind(next), true)
	if probe_tick > 0:
		add_action("回拨到 %.2f 港分" % port_minutes(previous), _set_probe_tick.bind(previous))
	if probe_tick < 800:
		add_action("展开整段风录", _set_probe_tick.bind(800))
	if phase in ["shoal","mouth"] and buoy_place.is_empty():
		add_action("现在投浮标重测 · 0.72 分", _place_from_trace)
		add_action("留着浮标，回到海图", _close_probes)
	elif phase == "done":
		add_action("同雾复航 · 换用%s" % ("普通探头" if fine_probe else "精密探头"), _swap_replay)
		add_action("原仪器再开", _replay)
		add_action("回到航次结果", _close_probes)
		add_readout(_growth())
	else:
		add_action("回船选择探头与航线", _close_probes)
	if probe_tick == 0:
		set_hint("两份读数都在同一时刻和同一实际风态比较。误差越小越贴近实况，金线是船上约定的可用上限。")
	else:
		var reached: Vector2i = probe_trace.crossed
		if reached.x >= 0 and reached.x <= probe_tick and reached.y >= 0 and reached.y <= probe_tick:
			var shift := reached.y - reached.x
			set_hint("同一阵雾里，换精密探头使首次越线%s %.2f 港分。初始读数的偏差会被气流放大，晚些投浮标能让后程从新的测量起算。" % [
				"推迟" if shift >= 0 else "提前", port_minutes(absi(shift))])
		elif reached.x >= 0 and reached.x <= probe_tick:
			set_hint("普通探头在 %.2f 港分首次越线。精密探头在眼前这一段始终留在线内。若把旧读数一直用到雾口，还剩多长能信的时间？" % port_minutes(reached.x))
		else:
			set_hint("预报从有偏差的读数出发，风态演化会把偏差拉开，也可能暂时拉近。投浮标能用此刻的实测重新起算。")
	chart.queue_redraw()

func _close_probes() -> void:
	probe_open = false
	if phase == "done":
		_show_outcome()
	else:
		_show_stop()
	set_hint("对照已收好。预报从上次观测开始计时，手里的浮标可以留到需要新读数的地方。")
	chart.queue_redraw()

func _place_from_trace() -> void:
	probe_open = false
	drop_buoy()
	chart.queue_redraw()

func _growth() -> String:
	var error := truth.distance_to(estimate)
	var elapsed := port_minutes(clock_tick-anchor_tick)
	var rate := log(maxf(error, .000001)/maxf(anchor_error,.000001))/maxf(elapsed,.00001)
	return "从上次测量起 %.2f 港分，三维状态误差 %.3f→%.3f 格。沿这次扰动方向，有限时李雅普诺夫增长率估计 λ＝ln(末误差/初误差)/时长＝%+.2f /港分。" % [elapsed, anchor_error, error, rate]

func _file(resolved: bool) -> void:
	if filed:
		return
	filed = true
	var buoy := "浮标未用" if buoy_place.is_empty() else "单枚浮标已投在"+buoy_place
	complete({"title":"雾谷末班邮船 · "+("信袋送达" if delivered else "护邮记录"),
		"observation":"%s，%s ±%.2f 格，%s。最后读数在 %.2f 港分测得。%s" % [TIDE_NAMES[tide], _gear_title(), precision(), buoy, port_minutes(anchor_tick), _growth()],
		"prediction":entered, "result":"%s 港钟 %.2f 分，实测横偏峰值 %.1f m。%s%s" % [outcome, port_minutes(clock_tick), peak_m, buoy_comparison, comparison],
		"principle":"非线性对流能放大相邻初态的误差。正增长近似稳定时，十倍精度带来的可预报时长增量约为 ln(10)/λ。这个局部估计随风态和扰动方向变化。",
		"boundary":"三变量 Lorenz 模型把风态投影为横风。14 条扰动轨迹是仪表误差球上的样本。航道宽度、遮风和港分换算属于本港设定。", "resolved":resolved})

func _replay() -> void:
	if phase != "done":
		return
	if delivered and not filed:
		_compare()
	_reset()

func _swap_replay() -> void:
	if phase == "done":
		fine_probe = not fine_probe
		_replay()
