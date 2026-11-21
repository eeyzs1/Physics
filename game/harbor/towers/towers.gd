extends "res://harbor/station.gd"

const LightLog := preload("res://harbor/towers/pair_log.gd")
const HarborView := preload("res://harbor/towers/harbor_view.gd")
const PolarizationTrial := preload("res://harbor/towers/polarization_trial.gd")
const ENDS := ["昼 0", "昼 1", "月 0", "月 1"]
const LINKS := [Vector2i(0, 2), Vector2i(0, 3), Vector2i(2, 1)]
const NOISE := [0.0, 0.2, 0.5, 1.0]
const FLEETS := [32, 256, 2048]
const FORECASTS := [15, 25, 40, 50, 65, 75, 80, 85, 95]

var phase := "classic"
var rules := PackedInt32Array([0, 0, 0, 1])
var seen := PackedInt32Array([-1, -1, -1, -1])
var last := Vector3i(-1, 0, 0)
var proof := PackedInt32Array([-1, -1, -1, -1])
var link_count := 0
var angles := PackedInt32Array([0, 0, 0, 0])
var active_axis := 0
var noise_index := 0
var logbook := LightLog.new()
var quick := PolarizationTrial.new()
var status := ""
var rng := RandomNumberGenerator.new()
var _harbor := HarborView.new()
var _switches: Array[Button] = []
var _seal: Button
var _forecast := -1
var _fleet_index := 0
var _sweep := -1
var _sweep_wait := 0.0
var _classic_hint := 0
var _quantum_hint := 0
var _proved_bound := false
var _pending_pair := Vector3i(-1, 0, 0)
var _next_ship := 0
var _batch_end := 0
var _batch_remainder := 0.0
var _batch_speed := 0.0
var _batch_label: Label

func _begin() -> void:
	rng.randomize()
	_harbor.station = self
	quick.host = self
	_harbor.cell_selected.connect(_inspect_cell)
	_harbor.tower_selected.connect(_inspect_tower)
	bind_view(_harbor)
	set_scene("双灯塔的夜班", "昼塔和月塔隔海封闸。船长说，两塔来信各自保密，仍能让约 85% 的船顺利进港。")
	_classic_tools()
	set_hint("来信只有 0 或 1。前三种来信要两塔同亮或同暗，唯独 11 要一亮一暗。")

func _line() -> HBoxContainer:
	var row := StationUI.row(6)
	tools_box.add_child(row)
	return row

func _small(row: HBoxContainer, caption: String, callback: Callable) -> Button:
	var button := StationUI.button(caption, callback)
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	return button

func _chooser(values: Array, selected: int, callback: Callable) -> OptionButton:
	var choice := OptionButton.new()
	choice.add_theme_font_size_override("font_size", 17)
	choice.custom_minimum_size.y = 40
	for value in values:
		choice.add_item(str(value))
	choice.select(selected)
	choice.item_selected.connect(callback)
	tools_box.add_child(choice)
	return choice

func _bit(value: int) -> String:
	return "亮" if value == 1 else "暗"

func _focus_picked(id: int) -> void:
	var item := instance_from_id(id) as Control
	if is_instance_valid(item) and item.is_inside_tree() and item.is_visible_in_tree() and can_process():
		item.grab_focus()

func _classic_tools(clear_trials: bool = true) -> void:
	phase = "classic"
	last.x = -1
	_sweep = -1
	_next_ship = 0
	if clear_trials:
		seen.fill(-1)
	set_tools("关闸前的应答牌", "阿照和望舒只看本塔的来信。点一块应答牌翻面，再让船队入港。")
	add_action("先试两扇灯窗，只转月塔", quick.open)
	_switches.clear()
	for side in 2:
		var row := _line()
		for setting in 2:
			var index := 2 * side + setting
			_switches.append(_small(row, _rule_text(index), _flip_rule.bind(index)))
	add_action("关闸，四艘依次试航", _start_sweep, true)
	var tools := _line()
	_small(tools, "点名一艘", _one_ship)
	_small(tools, "讨个提示", _tip)
	add_action("亲手连起三条同号缆", _start_proof)
	add_action("登塔查 85% 传闻", _enter_quantum)
	status = "潮门开放 · 可以改牌"

func _rule_text(index: int) -> String:
	return "%s 来信　%s" % [ENDS[index], _bit(rules[index])]

func _flip_rule(index: int) -> void:
	if phase != "classic" or _sweep >= 0: return
	rules[index] = 1 - rules[index]
	_switches[index].text = _rule_text(index)
	seen.fill(-1)
	last.x = -1
	status = "改过应答牌 · 等待试船"
	play_cue("echo")

func _one_ship() -> void:
	if _sweep >= 0: return
	_inspect_cell(_next_ship)
	_next_ship = (_next_ship + 1) % 4

func _inspect_cell(cell: int) -> void:
	if phase == "classic" and _sweep < 0:
		_classical_ship(cell)
	elif phase in ["quantum", "forecast", "running", "review", "audit", "signed"]:
		var n := logbook.visits[cell]
		set_hint("来信 %d%d 需要%s。两港分别只看左、右一位。合表记下 %d 艘，其中 %d 组同号。" % [
			cell >> 1, cell & 1, "同号" if cell < 3 else "异号", n, logbook.matched[cell]])

func _inspect_tower(side: int) -> void:
	if phase == "quantum":
		active_axis = 2 * side + (1 - (active_axis % 2) if active_axis / 2 == side else 0)
		_update_axis_buttons()
		set_hint("已选 %s 读头。用右侧两个转轮微调，刻度以共同的水平线为零。" % ENDS[active_axis])
	elif phase == "classic":
		set_hint("%s 守灯人只能看本塔的来信，亮、暗两面都可以在关闸前改写。" % ("昼塔" if side == 0 else "月塔"))

func _classical_ship(cell: int) -> void:
	last = Vector3i(cell, rules[cell >> 1], rules[2 + (cell & 1)])
	seen[cell] = int(LightLog.pass_classical(rules, cell))
	_harbor.arrival()
	play_cue("seed" if seen[cell] else "echo")
	var tested := 4 - seen.count(-1)
	status = "已验 %d / 4 班　·　顺利进港 %d 班" % [tested, seen.count(1)]
	set_hint("%d%d 班要%s。昼塔%s、月塔%s，这艘%s。" % [
		cell >> 1, cell & 1, "同号" if cell < 3 else "异号", _bit(last.y), _bit(last.z),
		"顺利入港" if seen[cell] else "停在闸外"])

func _start_sweep() -> void:
	if _sweep >= 0: return
	seen.fill(-1)
	_sweep = 0
	_sweep_wait = 0

func _start_proof() -> void:
	_sweep = -1
	phase = "proof"
	proof.fill(-1)
	proof[0] = rules[0]
	link_count = 0
	last.x = -1
	_proof_tools()

func _proof_tools() -> void:
	if link_count < 3:
		var pair: Vector2i = LINKS[link_count]
		set_tools("把同号缆扣上", "已知%s会%s。要让来信 %s 的船通过，你把%s的应答牌扣在哪边？" % [
			ENDS[pair.x], _bit(proof[pair.x]), ["00", "01", "10"][link_count], ENDS[pair.y]])
		var choices := _line()
		var dark := _small(choices, "扣在暗面", _tie.bind(0))
		_small(choices, "扣在亮面", _tie.bind(1))
		add_action("翻转起始的昼 0，重新连", _turn_anchor)
		add_action("返回改应答牌", _classic_tools)
		status = "同号缆　%d / 3" % link_count
		set_hint("亮暗都可作为起点。每接一条，航道上对应的两块牌就被同号条件绑住。")
		_focus_picked.call_deferred(dark.get_instance_id())
	else:
		set_tools("第四艘在叫闸", "它带来 11，要一亮一暗。三条缆已经扣好，先把你的判断封进船袋。")
		add_action("押它能过，开闸", _last_ship.bind(true), true)
		add_action("押它会被拦，开闸", _last_ship.bind(false))
		add_action("换个起点重试", _turn_anchor)
		status = "前三艘已进港 · 等待押最后一艘"
		set_hint("沿绳从昼 1 走到月 1，两端各是什么颜色？")

func _turn_anchor() -> void:
	rules[0] = 1 - rules[0]
	_start_proof()

func _tie(bit: int) -> void:
	if phase != "proof" or link_count >= 3: return
	var pair: Vector2i = LINKS[link_count]
	if proof[pair.x] != bit:
		play_cue("echo")
		set_hint("绳结滑开了。%s现在是%s，而你给%s扣了%s面。这条航道要两端同号。" % [
			ENDS[pair.x], _bit(proof[pair.x]), ENDS[pair.y], _bit(bit)])
		return
	proof[pair.y] = bit
	link_count += 1
	_harbor.arrival()
	play_cue("chain")
	_proof_tools()

func _last_ship(predicted_pass: bool) -> void:
	if phase != "proof" or link_count != 3: return
	phase = "proved"
	_proved_bound = true
	rules = proof.duplicate()
	for cell in 4:
		seen[cell] = int(LightLog.pass_classical(rules, cell))
	last = Vector3i(3, rules[1], rules[3])
	_harbor.arrival()
	set_tools("第四艘靠在闸外", "三条同号缆把四块应答牌连成一串。无论首灯亮暗，11 来时两端总是相同。")
	if _pending_pair.x >= 0:
		add_action("拿着三格上限，回本批签字", _back_to_audit, true)
	else:
		add_action("登塔查 85% 传闻", _enter_quantum, true)
	add_action("换第一盏灯，再拉一次", _turn_anchor)
	add_action("拆缆，自己重写四块牌", _classic_tools)
	status = "三班过港 · 第四班被拦"
	set_hint("固定的本地应答至多赢三格。提前抽取任何一套应答牌，长期平均仍至多为 75%。")
	complete({
		"title": "三条缆与第四艘船",
		"observation": "我从昼 0 的%s面出发，亲手连上 00、01、10 的三条同号缆。" % _bit(rules[0]),
		"prediction": "我押带 11 来信的船%s。" % ("能过闸" if predicted_pass else "会被拦下"),
		"result": "第四艘要求异号，两侧却都%s。四种来信实际通过 %d 种。" % [_bit(last.y), seen.count(1)],
		"principle": "若前三格同号，便有昼1＝月0＝昼0＝月1，第四格的异号条件必败。",
		"boundary": "两方只能用本地来信，关闸后互不通信，四种输入等概率。共享预先随机数也不能提高经典上限。",
		"resolved": false})

func _enter_quantum() -> void:
	_sweep = -1
	_pending_pair.x = -1
	phase = "quantum"
	last.x = -1
	logbook = LightLog.new()
	_forecast = -1
	status = "双光子就位 · 还没有发船"
	set_tools("调两座塔的读头", "每种本地来信各有一支线偏振读头。选一支转动，同一支轴转过 180° 会回到原位。")
	add_action("先试两扇灯窗，只转月塔", quick.open)
	_switches.clear()
	for side in 2:
		var row := _line()
		for setting in 2:
			var index := side * 2 + setting
			_switches.append(_small(row, "", _select_axis.bind(index)))
	_update_axis_buttons()
	var arrows := _line()
	_small(arrows, "左转 22.5°", _rotate_axis.bind(-1))
	_small(arrows, "右转 22.5°", _rotate_axis.bind(1))
	_chooser(["无白噪声", "白噪声混入 20%", "白噪声混入 50%", "全白噪声 100%"], noise_index, _set_noise)
	add_action("报一个胜率，再放船", _prepare_forecast, true)
	var bottom := _line()
	_small(bottom, "要个线索", _tip)
	_small(bottom, "回到应答牌", _classic_tools)
	_focus_picked.call_deferred(_switches[0].get_instance_id())
	set_hint("每轮收到一对光子。两个输入各自独立随机，关闸后才揭晓本地亮暗，最后合两份灯志。")

func _update_axis_buttons() -> void:
	for i in _switches.size():
		_switches[i].text = "%s%s　%s" % ["● " if i == active_axis else "", ENDS[i], LightLog.angle_name(angles[i])]
		_switches[i].add_theme_color_override("font_color", StationUI.AMBER if i == active_axis else StationUI.INK)

func _select_axis(index: int) -> void:
	active_axis = index
	_update_axis_buttons()

func _rotate_axis(direction: int) -> void:
	angles[active_axis] = posmod(angles[active_axis] + direction, 8)
	_update_axis_buttons()
	play_cue("echo")
	status = "%s 的读头转到 %s" % [ENDS[active_axis], LightLog.angle_name(angles[active_axis])]

func _set_noise(index: int) -> void:
	noise_index = index
	set_hint("有 %d%% 的光子对换成完全混合态。换雾况后会另起一册，样本单独计算。" % roundi(100 * NOISE[index]))

func _prepare_forecast() -> void:
	phase = "forecast"
	logbook = LightLog.new()
	last.x = -1
	_forecast = -1
	set_tools("把预报封进船袋", "报这组读头和当前雾况的长期胜率。放船后才知道这一批的来信和读数。")
	add_readout(_axis_report())
	var options: Array = ["选择我押的过闸率"]
	for p in FORECASTS:
		options.append("我押约 %d%% 过闸" % p)
	var picker := _chooser(options, 0, _choose_forecast)
	picker.set_item_disabled(0, true)
	_chooser(["先派 32 艘", "先派 256 艘", "先派 2048 艘"], _fleet_index, _choose_fleet)
	_seal = add_action("封存这次预报，放船", _launch_fleet, true)
	_seal.disabled = true
	add_action("回去转读头", _enter_quantum)
	_focus_picked.call_deferred(picker.get_instance_id())
	status = "还没开闸 · 可以改预报"
	set_hint("短航次容易被运气左右。结果页可以保持同样的读头、雾况和预报，继续增样。")

func _choose_forecast(index: int) -> void:
	_forecast = FORECASTS[index-1] if index > 0 else -1
	_seal.disabled = _forecast < 0

func _choose_fleet(index: int) -> void:
	_fleet_index = index

func _axis_report() -> String:
	return "昼轴 %s / %s　月轴 %s / %s　白噪声 %d%%" % [
		LightLog.angle_name(angles[0]), LightLog.angle_name(angles[1]), LightLog.angle_name(angles[2]),
		LightLog.angle_name(angles[3]), roundi(100 * NOISE[noise_index])]

func _launch_fleet() -> void:
	if phase != "forecast" or _forecast < 0: return
	logbook = LightLog.new()
	_send_more(FLEETS[_fleet_index])

func _send_more(amount: int) -> void:
	if phase not in ["forecast", "review", "signed"]: return
	phase = "running"
	_batch_end = logbook.count + amount
	_batch_speed = amount / 2.4
	_batch_remainder = 0.0
	set_tools("潮门已经锁上", "船袋已封。昼塔只看左边来信，月塔只看右边来信。船回港后两册才核对。")
	_batch_label = add_readout("")
	status = "两港正在收信"
	play_cue("echo")

func _tip() -> void:
	if phase == "classic":
		var tips := ["先固定昼 0。00、01 两艘若都想过，月塔的两块牌该怎样？",
			"再看 10 班。它把昼 1 绑到月 0，最后的 11 班却要求昼 1 与月 1 不同。",
			"进「亲手连起三条同号缆」，任选首灯颜色，一条一条扣上便可自己验到结局。"]
		set_hint(tips[mini(_classic_hint, tips.size() - 1)])
		_classic_hint += 1
	else:
		var tips := ["在理想 Φ⁺ 源上，平行轴给同号，垂直轴给异号。哪三班希望两支轴更接近？",
			"试着让昼塔两轴相隔 45°，让月 0 夹在它们之间。月 1 要靠昼 0、离昼 1 更远。",
			"对照四班的角差。22.5° 与 67.5° 的同号率互补。看换月 1 到昼 0 的另一侧后哪格受益。"]
		set_hint(tips[mini(_quantum_hint, tips.size() - 1)])
		_quantum_hint += 1

func _process(delta: float) -> void:
	if phase == "pair_compare":
		quick.tick(delta)
		return
	if _sweep >= 0:
		_sweep_wait -= delta
		if _sweep_wait <= 0:
			_classical_ship(_sweep)
			_sweep += 1
			_sweep_wait = 0.48
			if _sweep == 4:
				_sweep = -1
				set_hint("四班全部回报，过了 %d 班。翻任意一面再试，或亲手扣上前三格的缆绳。" % seen.count(1))
	if phase != "running": return
	_batch_remainder += _batch_speed * delta
	var step := mini(floori(_batch_remainder), _batch_end - logbook.count)
	if step <= 0: return
	_batch_remainder -= step
	for i in step:
		last = logbook.sample(rng, angles, NOISE[noise_index])
	_harbor.arrival()
	_batch_label.text = "回来 %d / %d 艘　·　已通过 %d 班" % [logbook.count, _batch_end, logbook.wins]
	if logbook.count >= _batch_end:
		_review()

func _review(save_partial: bool = true) -> void:
	phase = "review"
	var rate := logbook.percent(logbook.wins)
	var bound := logbook.interval() * 100.0
	var theory := 100.0 * LightLog.long_run(angles, NOISE[noise_index])
	status = "船袋开封 · 两份灯志已经合表"
	set_tools("回港船袋已开封", "你押 %d%%。这批 %d / %d 艘通过，实测 %.1f%%。本设置的模型长期率为 %.2f%%。" % [
		_forecast, logbook.wins, logbook.count, rate, theory])
	add_readout("本批 95%% Wilson 区间　%.2f%% 至 %.2f%%" % [bound.x, bound.y])
	add_action("核验船长的证据回执", _open_audit, true)
	add_action("原样再派 256 艘", _send_more.bind(256))
	add_action("改押新预报，重开一批", _prepare_forecast)
	add_action("调读头或换雾重试", _enter_quantum)
	add_action("回到应答牌", _classic_tools)
	add_readout(logbook.chsh_readout())
	set_hint("单看一塔，亮率趋近一半。两册合起来才显出角差规律。航道卡写着每班同号数／总数。")
	if save_partial:
		_file_report(false, "这批两塔灯志已合表，尚待我签回执。")
		play_cue("finish")

func _open_audit() -> void:
	phase = "audit"
	if not _proved_bound:
		set_tools("两塔的经典线在哪？", "领航员替你保存了这批回报。补上三条同号缆，找出两座塔只靠本地应答时最多能护送几班。")
		add_action("保管船袋，去扣三条缆", _proof_for_audit, true)
		add_action("返回合表", _review.bind(false))
		set_hint("这一批的读头、船数、预报和回信都在原地等你。")
		return
	var bounds := logbook.interval() * 100.0
	set_tools("领航员等你签字", "本批估计区间 %.3f%% ～ %.3f%%。船长要一句经得起核对的话。本批的区间整体超过经典 75%% 线了吗？" % [bounds.x, bounds.y])
	add_action("签字：区间已全过线", _sign.bind(true), true)
	add_action("签字：证据还不能这么说", _sign.bind(false))
	add_action("返回合表", _review.bind(false))
	set_hint("两种回执都能如实交差。区间跨着 75% 时，较高的单次过闸率也可能来自这批船的运气。")

func _proof_for_audit() -> void:
	_pending_pair = last
	_start_proof()

func _back_to_audit() -> void:
	last = _pending_pair
	_pending_pair.x = -1
	_open_audit()

func _sign(claims_above: bool) -> void:
	if phase != "audit" or not _proved_bound: return
	var bounds := logbook.interval()
	var fully_above := bounds.x > 0.75
	if claims_above != fully_above:
		set_hint("再看区间两端。下端约 %.3f%%，经典线为 75%%。要签「全过线」，下端也需要严格高过 75%%。" % [bounds.x * 100.0])
		play_cue("echo")
		return
	phase = "signed"
	var words := "本批的区间整体超过 75% 经典线。" if fully_above else "本批的区间不足以支持超过 75% 经典线。"
	status = "领航员已收下你的回执"
	set_tools("封蜡回执已归档", words + "两塔继续值班，你可以用同一份预报等更多船，也能换雾重做。")
	add_action("原样再派 256 艘", _send_more.bind(256), true)
	add_action("调读头或换雾重试", _enter_quantum)
	add_action("改押新预报，重开一批", _prepare_forecast)
	add_action("回到应答牌", _classic_tools)
	set_hint("日志已保存原始计数、封存的预报和你签的判断。85.36% 是适当无噪声读头的长期极限。")
	_file_report(true, "我签下回执：" + words)
	play_cue("finish")

func _file_report(resolved: bool, judgment: String) -> void:
	var rate := logbook.percent(logbook.wins)
	var bound := logbook.interval() * 100.0
	var theory := 100.0 * LightLog.long_run(angles, NOISE[noise_index])
	var audit := "昼亮 %d / %d，月亮 %d / %d。四班同号数／总数依次为 " % [
		logbook.bright[0], logbook.count, logbook.bright[1], logbook.count]
	var rows := PackedStringArray()
	for cell in 4:
		rows.append("%d/%d" % [logbook.matched[cell], logbook.visits[cell]])
	complete({
		"title": "双灯塔的过闸传闻",
		"observation": _axis_report() + "。" + audit + "、".join(rows) + "。",
		"prediction": "开闸前，我押这组读头的长期通过率约为 %d%%。" % _forecast,
		"result": "%d 艘中通过 %d 艘（%.1f%%），模型长期值 %.2f%%，本批的 95%% Wilson 区间为 %.1f%% 至 %.1f%%。%s" % [
			logbook.count, logbook.wins, rate, theory, bound.x, bound.y, judgment],
		"principle": logbook.chsh_readout() + "四班等概率时，长期胜率＝½＋S/8。Φ⁺ 偏振对的同号概率为 (1＋V cos 2θ)/2，合适的理想读头可达 S＝2√2，单看一塔仍是随机的。",
		"boundary": "独立等概率输入、理想双端探测、白噪声使 V＝1－混入比例。有限样本会波动，这是模型模拟。Wilson 区间按固定样本数解释，边看边决定何时停船会改变覆盖性质。",
		"resolved": resolved})
