extends "res://harbor/station.gd"

const Rig := preload("res://harbor/dock/rig.gd")
const DockView := preload("res://harbor/dock/view.gd")
const TICK := 1.0/100.0
const INTRO_TICKS := 1300
const PULL_SECONDS := .42
const MODE_NAMES := {"single":"单拨近篮","together":"同向放手","opposed":"反向放手","far":"单拨远篮"}

var rig := Rig.new()
var view: Control
var phase := "intro_ready"
var spring := 20
var pattern := "single"
var state := Vector4.ZERO
var bench_time := 0.0
var epoch := 0.0
var run_time := 0.0
var lead := 8.0
var paused := false
var holding := false
var hooked := false
var released := false
var observed_peak := -INF
var observed_t := 0.0
var peak_x := 0.0
var peak_time := -1.0
var trace: Array[Vector3] = []
var stamps := PackedFloat32Array()
var trial_note := ""
var _readout: Label
var _lead_value: Label
var _accum := 0.0
var _draw_tick := 0
var intro_tick := 0
var intro_peak_m := 0.0
var intro_peak_s := 0.0
var intro_results: Dictionary = {}
var intro_history: Dictionary = {}
var guide_job := false
var _intro_series := PackedFloat32Array()
var _intro_pull := 0.0
var _intro_held := false
var _intro_logged := false
var _pause_button: Button

func _begin() -> void:
	view = DockView.new()
	view.station = self
	bind_view(view)
	_return_bench()

func restart_intro() -> void:
	phase = "intro_ready"
	guide_job = false
	spring = 0
	pattern = "single"
	paused = false
	holding = false
	hooked = false
	released = false
	_intro_held = false
	intro_tick = 0
	intro_peak_m = 0.0
	intro_peak_s = 0.0
	intro_results.clear()
	intro_history.clear()
	_intro_series = PackedFloat32Array([0.0])
	state = Vector4.ZERO
	rig.reset(0,state)
	_accum = 0.0
	_readout = null
	set_scene("旧船坞双吊篮", "邮袋在右篮，船钩还差一截。你在码头只够得着左篮。")
	set_tools("够不着的邮袋", "右篮静静挂着。拉动左篮，看看右篮会不会跟着动。")
	add_action("只拉左篮，松手", start_intro_run.bind(0), true)
	set_hint("可以直接点橘色左篮，也可以按确认键放手。")
	view.queue_redraw()

func start_intro_run(k: int, hand_held := false) -> void:
	if k not in [0,20,40] or (k==20 and not intro_results.has(0)) or (k==40 and not intro_results.has(20)):
		return
	phase = "intro_running"
	guide_job = false
	hooked = false
	released = false
	run_time = 0.0
	spring = k
	pattern = "single"
	rig.reset(k,Rig.release_state("single"))
	state = Vector4.ZERO
	paused = false
	_intro_pull = 0.0
	_intro_held = hand_held
	intro_tick = 0
	intro_peak_m = 0.0
	intro_peak_s = 0.0
	_intro_series = PackedFloat32Array([0.0])
	_accum = 0.0
	_readout = null
	set_scene("旧船坞双吊篮", "邮袋在右篮，船钩还差一截。你在码头只够得着左篮。")
	set_tools("看右篮", "两篮从静止开始。左篮每次拉开 %.0f cm，右篮都从中线松手。" % (100.0*Rig.A))
	_pause_button = add_action("暂停观察", _intro_pause, true)
	add_action("直接看这一遍的结果", skip_intro_run)
	add_action("从头重演入门", restart_intro)
	set_hint("留意白色中线和右篮之间的距离。" if k==0 else "弹簧压短会推，拉长会拉。箭头和右篮运动同向时，弹簧对它做正功，右篮获得能量。")
	play_cue("launch")
	view.queue_redraw()

func _intro_pause() -> void:
	if phase == "intro_running":
		paused = not paused
		_pause_button.text = "继续观察" if paused else "暂停观察"
		view.queue_redraw()

func intro_previous_key() -> int:
	return 20 if spring==40 else 0

func intro_previous_peak() -> float:
	var prior: PackedFloat32Array = intro_history.get(intro_previous_key(),PackedFloat32Array())
	return prior[mini(intro_tick,prior.size()-1)] if not prior.is_empty() else 0.0

func _intro_step() -> void:
	intro_tick += 1
	state = rig.sample(intro_tick*TICK)
	if state.y > intro_peak_m:
		intro_peak_m = state.y
		intro_peak_s = intro_tick*TICK
	_intro_series.append(intro_peak_m)
	if intro_tick == INTRO_TICKS:
		_intro_end()

func skip_intro_run() -> void:
	if phase != "intro_running":
		return
	_intro_held = false
	_intro_pull = PULL_SECONDS
	while phase=="intro_running":
		_intro_step()

func _intro_end() -> void:
	phase = "intro_result"
	paused = false
	_intro_held = false
	intro_results[spring] = {"peak_m":intro_peak_m,"peak_s":intro_peak_s,"duration_s":INTRO_TICKS*TICK}
	intro_history[spring] = _intro_series
	if spring==0:
		set_tools("右篮一直停在中线", "%.0f 秒里，右篮最远向右 %.0f cm。把两篮复位，这次在中间接一根软弹簧。" % [INTRO_TICKS*TICK,100.0*intro_peak_m])
		add_action("接上软弹簧，再拉左篮", start_intro_run.bind(20), true)
		add_action("回放无弹簧的一遍", start_intro_run.bind(0))
		set_hint("两遍都只拉左篮 36 cm。接下来只改变两篮之间的连接。")
	else:
		set_tools("这叫耦合振动", "弹簧反复推拉右篮，对它做功，左篮的一部分摆动能量就传到了右篮。")
		add_action("约邮船，试着挂袋" if spring==20 else "用新时刻再挂一袋", _guide_plan, true)
		add_readout("亲眼量到的线索\n放手后 %.2f 秒，右篮向右达到 %.1f cm。船钩只需 %.1f cm。" % [intro_peak_s,intro_peak_m*100,Rig.REACH*100])
		add_action("再看一次这一遍", start_intro_run.bind(spring))
		set_hint("两栏都记松手后 13 秒内的最大向右位移，篮子现在的位置由白色中线旁的刻度显示。")
		if spring==20 and not _intro_logged:
			_intro_logged = true
			var first: Dictionary = intro_results[0]
			complete({"title":"两次只拉左篮","observation":"两遍都把左篮拉开 36 cm，右篮从中线静止开始，同时松手观察 13 秒。",
				"prediction":"第一遍让两篮分开，第二遍只接上软弹簧，检验左篮能否带动右篮。",
				"result":"右篮最大向右位移从 %.1f cm 变为 %.1f cm，接簧后的峰出现在 %.2f 秒。" % [float(first.peak_m)*100,intro_peak_m*100,intro_peak_s],
				"principle":"耦合振动。弹簧的推拉对右篮做功，左篮的一部分摆动能量传到右篮。","boundary":"相同的两个小角度吊篮，弹簧在线性范围内，忽略阻尼。","resolved":false})
	add_action("自由试摆", _return_bench)
	if spring!=0:
		add_action("从头重演入门", restart_intro)
	play_cue("gate")
	view.queue_redraw()

func _intro_observation() -> String:
	var result: Dictionary = intro_results[spring]
	return "从相同静止起点只拉左篮 36 cm，%s下右篮在前 13 秒最远向右 %.1f cm，时刻 %.2f 秒。" % [
		"软弹簧" if spring==20 else "硬弹簧", float(result.peak_m)*100, result.peak_s]

func _guide_plan() -> void:
	if not intro_results.has(spring):
		return
	guide_job = true
	phase = "plan"
	hooked = false
	released = false
	pattern = "single"
	trial_note = _intro_observation()
	var result: Dictionary = intro_results[spring]
	intro_tick = INTRO_TICKS
	intro_peak_m = result.peak_m
	intro_peak_s = result.peak_s
	rig.reset(spring,Rig.release_state("single"))
	state = rig.sample(INTRO_TICKS*TICK)
	set_scene("旧船坞双吊篮", "邮船会在右篮旁探一下钩。你来告诉水手，提前多久松开左篮。")
	set_tools("靠岸前几秒松手？", "刚才的%s试摆里，右篮在第 %.2f 秒到达 %.1f cm。超过 %.1f cm，船钩就够得着邮袋。" % [
		"软簧" if spring==20 else "硬簧", result.peak_s, float(result.peak_m)*100, Rig.REACH*100])
	add_action("提前 6.5 秒松手", _send_guide.bind(6.5))
	add_action("提前 12.5 秒松手", _send_guide.bind(12.5))
	add_action("自己调放手时间", _custom_guide_plan)
	add_action("回放刚才的试摆", start_intro_run.bind(spring))
	add_action("从头重演入门", restart_intro)
	set_hint("水手照你的时机放手。船钩只在抵岸前后各开 0.65 秒。")
	view.queue_redraw()

func _send_guide(seconds: float) -> void:
	if phase=="plan":
		lead = seconds
		launch()

func _custom_guide_plan() -> void:
	_plan_controls()

func _row(labels: Array, actions: Array, selected: int = -1) -> void:
	var row := StationUI.row(5)
	tools_box.add_child(row)
	for i in labels.size():
		var button := StationUI.button(labels[i], actions[i],i==selected)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 34
		button.add_theme_font_size_override("font_size",15)
		for style in ["normal","hover","pressed","focus"]:
			var box := button.get_theme_stylebox(style).duplicate() as StyleBoxFlat
			if box != null:
				box.content_margin_left = 4
				box.content_margin_right = 4
				button.add_theme_stylebox_override(style, box)
		row.add_child(button)

func _bench_panel() -> void:
	set_tools("试摆架", "想只拨一个，还是两个一起放？横簧的插销也可以摘下来。")
	add_readout("横簧刚度 κ（N/m）")
	_row(["脱开 0","软簧 20","硬簧 40"],[change_spring.bind(0), change_spring.bind(20), change_spring.bind(40)], [0,20,40].find(spring))
	_row(["单拨近篮","同向","反向"],[release_trial.bind("single"), release_trial.bind("together"), release_trial.bind("opposed")], ["single","together","opposed"].find(pattern))
	_row(["继续试摆" if paused else "暂停试摆","打节拍记号"],[_pause_trial, stamp])
	_readout = add_readout("")
	_update_readout()

func release_trial(mode: String) -> void:
	if phase != "bench":
		return
	pattern = mode
	state = Rig.release_state(mode)
	rig.reset(spring,state)
	paused = false
	holding = false
	bench_time = 0
	epoch = 0
	_accum = 0
	peak_x = 0
	peak_time = -1
	stamps.clear()
	trace = [Vector3(0,state.x,state.y)]
	_bench_panel()
	var tips := {
		"single":"近篮从静止放开。可以在远篮摆得最远时打个记号。",
		"together":"两篮同向放开。看摆动时横簧两端的距离怎样变化。",
		"opposed":"两篮从相反方向放开。把这个节拍与刚才的同向摆比较。",
		"far":"远篮已经放开。看这次摆幅向哪边传递。"}
	set_hint(tips.get(mode,""))
	view.queue_redraw()

func grab_basket(far: bool) -> void:
	if phase != "bench":
		return
	release_trial("far" if far else "single")
	holding = true
	set_hint("篮子已拉到 0.36 m。松开鼠标，另一篮会按当前弹簧设置应答。")

func let_go() -> void:
	if phase=="intro_running" and _intro_held:
		_intro_held = false
		return
	if holding:
		holding = false
		play_cue("launch")

func change_spring(value: int) -> void:
	if phase != "bench" or value not in [0,20,40]:
		return
	if spring == value:
		return
	spring = value
	# A latch changes spring potential energy. Displacement and velocity stay continuous.
	rig.reset(spring,state)
	epoch = bench_time
	peak_time = -1
	peak_x = 0
	stamps.clear()
	_bench_panel()
	set_hint("插销拨到 %d N/m。此刻的位置和速度连续，重新单拨可作同一起点的对照。" % spring)
	play_cue("survey")
	view.queue_redraw()

func _pause_trial() -> void:
	if phase != "bench":
		return
	paused = not paused
	_bench_panel()

func stamp() -> void:
	if phase != "bench":
		return
	if stamps.is_empty() or absf(bench_time-stamps[-1])>.02:
		stamps.append(bench_time)
	if stamps.size()>2:
		stamps.remove_at(0)
	_update_readout()
	set_hint("已在双篮轨迹上留下刻度。再打一次可以量两个位置相隔多久。")
	view.queue_redraw()

func _snapshot_note() -> String:
	var observed := "观察了 %.2f s" % bench_time
	if peak_time >= 0:
		observed += "，最近一次向右波峰在 %.2f s，远篮位移 %+.3f m" % [peak_time,peak_x]
	if stamps.size()==2:
		observed += "，两个手记节拍相隔 %.2f s" % (stamps[1]-stamps[0])
	return "%d N/m、%s，%s。" % [spring, MODE_NAMES[pattern], observed]

func _update_readout() -> void:
	if not is_instance_valid(_readout):
		return
	var stamp_text := ""
	if stamps.size()==1:
		stamp_text = "\n记号 %.2f s" % stamps[0]
	elif stamps.size()==2:
		stamp_text = "\n记号间隔 %.2f s" % (stamps[1]-stamps[0])
	var peak_text := "等待远篮右峰" if peak_time<0 else "右峰 %.2f s / %+.3f m" % [peak_time,peak_x]
	_readout.text = "试摆 %.2f s · %s%s" % [bench_time, peak_text, stamp_text]

func _plan() -> void:
	if phase != "bench":
		return
	holding = false
	trial_note = _snapshot_note()
	phase = "plan"
	guide_job = false
	_plan_controls()

func _plan_controls() -> void:
	if phase!="plan":
		return
	_readout = null
	set_tools("和船长约好", "收货船将从右岸进港。值班人只能单拨近篮，放手幅度固定 0.36 m。")
	_lead_value = add_readout("")
	var slider := HSlider.new()
	slider.min_value = 1.0
	slider.max_value = Rig.DOCK_TIME
	slider.step = .5
	slider.value = lead
	slider.custom_minimum_size.y = 34
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "提前放手秒数"
	tools_box.add_child(slider)
	slider.value_changed.connect(func(v: float) -> void:
		lead = v
		_update_lead())
	_row(["提前量 −0.5 s","提前量 +0.5 s"],[
		func() -> void: slider.value = maxf(slider.min_value,slider.value-.5),
		func() -> void: slider.value = minf(slider.max_value,slider.value+.5)])
	add_action("锁定时机 · 让邮船进港", launch, true)
	add_action("回试摆台", _return_bench)
	add_action("从头重演入门", restart_intro)
	add_readout("船钩在抵岸前后各 0.65 s 探出，远篮需向右伸到 %.3f m。" % Rig.REACH)
	_update_lead()
	set_hint("决定提前多少秒放手。确认后，邮船按这张靠泊单进港。")

func _update_lead() -> void:
	if is_instance_valid(_lead_value):
		_lead_value.text = "横簧 %d N/m　·　提前 %.1f 秒放手" % [spring,lead]
	view.queue_redraw()

func launch() -> void:
	if phase != "plan":
		return
	phase = "voyage"
	run_time = 0
	_accum = 0
	hooked = false
	released = false
	observed_peak = -INF
	observed_t = 0.0
	state = Rig.release_state("single")
	rig.reset(spring,state)
	trace = [Vector3(0,state.x,state.y)]
	set_tools("邮船进港", "靠泊单已锁定。船钩到远篮右侧时会自动接袋。")
	_readout = add_readout("")
	add_action("从头重演入门",restart_intro)
	_voyage_readout()
	set_hint("棕色邮袋挂在远篮下沿。虚线标出了船钩能取件的最左位置。")
	play_cue("launch")
	view.queue_redraw()

func _voyage_readout() -> void:
	if is_instance_valid(_readout):
		var motion := "已放手" if released else "近篮仍扣在插销上"
		_readout.text = "已约提前 %.1f s · %s\n距抵岸 %.2f s　远篮 %+.3f m" % [lead,motion,maxf(0,Rig.DOCK_TIME-run_time),state.y]

func _return_bench() -> void:
	if phase.begins_with("intro_") and spring==0 and not intro_results.has(20):
		spring = 20
	phase = "bench"
	guide_job = false
	released = false
	hooked = false
	set_scene("工棚里的双摆", "两只摆，一根可以摘挂的横簧。拉开其中一只，然后松手。")
	release_trial("single")

func _process(delta: float) -> void:
	if phase=="intro_running":
		if paused:
			return
		if _intro_pull < PULL_SECONDS:
			_intro_pull = minf(_intro_pull+delta, PULL_SECONDS)
			var pull := smoothstep(0.0,PULL_SECONDS,_intro_pull)
			state = Vector4(Rig.A*pull,0,0,0)
			view.queue_redraw()
			return
		if _intro_held:
			return
		_accum += minf(delta,.15)*(2.0 if spring==0 else 1.65)
		while _accum>=TICK and phase=="intro_running":
			_accum -= TICK
			_intro_step()
		view.queue_redraw()
		return
	if phase not in ["bench","voyage"] or (phase=="bench" and (paused or holding)):
		return
	_accum += minf(delta,.15)*1.8
	while _accum >= TICK and phase in ["bench","voyage"]:
		_accum -= TICK
		if phase=="bench":
			_trial_tick()
		else:
			_voyage_tick()
	view.queue_redraw()

func _trial_tick() -> void:
	var prior_velocity := state.w
	bench_time += TICK
	state = rig.sample(bench_time-epoch)
	if prior_velocity > 0.0 and state.w <= 0.0 and absf(state.y)>.0001:
		var since := TICK*prior_velocity/(prior_velocity-state.w)
		peak_time = bench_time-TICK+since
		peak_x = rig.sample(peak_time-epoch).y
	_take_trace(bench_time)
	if _draw_tick%10==0:
		_update_readout()

func _take_trace(t: float) -> void:
	_draw_tick += 1
	if _draw_tick%4==0:
		trace.append(Vector3(t,state.x,state.y))
		if trace.size()>680:
			trace.pop_front()

func _voyage_tick() -> void:
	run_time += TICK
	var since := run_time - (Rig.DOCK_TIME-lead)
	if since>=-.000001:
		if not released:
			released=true
			play_cue("gate")
		state=rig.sample(maxf(0,since))
		_take_trace(maxf(0,since))
	if absf(run_time-Rig.DOCK_TIME)<=Rig.HOOK_WINDOW+.000001:
		if state.y>observed_peak:
			observed_peak=state.y
			observed_t=maxf(0,since)
		if not hooked and state.y>=Rig.REACH:
			hooked=true
			play_cue("seed")
	if _draw_tick%10==0 or not released:
		_voyage_readout()
	if run_time>=Rig.DOCK_TIME+Rig.HOOK_WINDOW-.000001:
		_finish()

func _finish() -> void:
	phase = "done"
	var ending := "邮船钩到了邮袋，甲板上的回信灯亮了。" if hooked else "船钩空着离岸，邮袋仍在远篮上。"
	var result := "开钩窗口内，放手后 %.2f s 达到最大右移 %+.3f m。取袋线 %.3f m。" % [observed_t,observed_peak,Rig.REACH]
	if observed_peak<0.0:
		result = "开钩窗口内，右篮一直在中线左边。放手后 %.2f s 最接近中线，仍偏左 %.1f cm。" % [observed_t,-observed_peak*100]
	set_tools("邮袋上船了" if hooked else "船钩落了空", ending)
	if guide_job:
		var baseline: Dictionary = intro_results[spring] if intro_results.has(spring) else intro_results[20]
		var where := "这段时间右篮最远向右 %.1f cm，取袋线在 %.1f cm。" % [observed_peak*100,Rig.REACH*100]
		if observed_peak<0.0:
			where = "这段时间右篮一直在中线左边，船钩够不到它。"
		add_readout("船钩等在放手后 %.2f–%.2f 秒。%s" % [lead-Rig.HOOK_WINDOW,lead+Rig.HOOK_WINDOW,where])
		if hooked and spring==20:
			add_action("换硬弹簧，用刚才的时机",_dispatch_hard,true)
			add_action("用软弹簧再寄一袋",_guide_plan)
		elif spring==40 and not intro_results.has(40):
			add_action("试摆硬弹簧，重找时机",start_intro_run.bind(40),true)
			add_readout("原来那条 %.2f 秒的线索来自软弹簧。" % baseline.peak_s)
		else:
			add_action("照刚才的右峰，再约一班",_guide_plan,true)
			add_readout("刚才试摆的右峰在 %.2f 秒，达到 %.1f cm。" % [baseline.peak_s,float(baseline.peak_m)*100])
		add_action("回试摆台 · 自由实验",_return_bench)
	else:
		add_action("回试摆台 · 再叫一班", _return_bench, true)
		add_readout(result)
	add_action("从头重演入门",restart_intro)
	var w0 := Rig.omega_common()
	var w1 := Rig.omega_opposed(spring)
	var beat := "断开后两种角频率相同，单拨近篮时远篮静止。"
	if spring>0:
		beat = "两种频率叠加。第一次能量交换包络峰约在 π/|ω₁−ω₀|＝%.2f s，船钩还要等到远篮向右。" % (PI/absf(w1-w0))
	if not guide_job:
		add_readout(beat)
	set_hint("换一根弹簧再用相同的提前量，看船钩能否接到第二封信。" if hooked else "船会照常再来。比较开钩时间和试摆的右峰，再发一班。")
	complete({"title":"旧船坞双吊篮 · "+("挂邮成功" if hooked else "空钩记录"), "observation":trial_note,
		"prediction":"确认靠泊单时选用 κ＝%d N/m，提前 %.1f s，从静止单拨近篮 +0.36 m。预计远篮在船钩窗口向右达到 %.3f m。" % [spring,lead,Rig.REACH],
		"result":ending+result, "principle":beat+" 同向模态不拉伸横簧，反向模态受横簧回复力。两篮显示的能量各计一半簧能。",
		"boundary":"两只等质量 40 kg 的篮子各悬 2.5 m，采用无阻尼小角摆与线性横簧。强摆动、摩擦和真实船钩误差会改变时机。", "resolved":hooked})
	play_cue("finish" if hooked else "impact")
	view.queue_redraw()

func _dispatch_hard() -> void:
	if phase!="done" or not guide_job or spring!=20:
		return
	spring = 40
	phase = "plan"
	trial_note += " 这次换硬弹簧，保留上一班的放手提前量，检验原时机。"
	launch()
