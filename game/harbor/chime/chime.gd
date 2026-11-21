extends "res://harbor/station.gd"

const Instrument := preload("res://harbor/chime/chime_physics.gd")
const HarborView := preload("res://harbor/chime/chime_view.gd")
const HarborSound := preload("res://harbor/chime/chime_sound.gd")
const BOARD_NAMES := ["一", "二", "三", "四", "五"]
const CALL_TIME := 2.15

var lab := Instrument.new()
var harbor := HarborView.new()
var ear := HarborSound.new()
var phase := "tuning"
var baseline: Dictionary = {}
var logged_first_ferry := false
var prediction := false
var chosen_board := -1
var inspected := 3
var trial_time := 0.0
var trial_duration := CALL_TIME
var trial_ok := false
var departed_at := -1.0
var listening := 0.0
var bell_wait := 0.0
var horn_wait := 0.0
var tapped := false
var meter: Label
var drive_button: Button
var previous_take: Dictionary = {}
var current_take: Dictionary = {}
var compare_row: HBoxContainer
var lens_origin := "tuning"


func _begin() -> void:
	harbor.lab = lab
	bind_view(harbor)
	add_child(ear)
	harbor.note_picked.connect(_tune_to)
	harbor.board_picked.connect(_pick_board)
	harbor.score_picked.connect(_pick_score)
	visibility_changed.connect(_on_visibility)
	_reset_instrument()


func _on_visibility() -> void:
	if not is_visible_in_tree():
		ear.silence()


func _reset_instrument() -> void:
	baseline.clear()
	previous_take.clear()
	current_take.clear()
	lab.configure()
	lab.set_frequency(lab.frequencies[0])
	harbor.ferry = 0
	harbor.moored = false
	harbor.second = false
	harbor.staged_load = -1
	harbor.selected_board = -1
	harbor.bell_flash = 0
	harbor.horn_flash = 0
	harbor.tap_flash = 0
	chosen_board = -1
	listening = 0
	bell_wait = 0
	horn_wait = 0
	tapped = false
	_save_take()
	_open_tuning()
	set_hint("先盯住三号雾哨。按「高一音栓」换个节奏，刚才那一拍的板位和峰值会留在桥上。")


func _save_take() -> void:
	if lab.loaded >= 0:
		return
	if not current_take.is_empty() and absf(float(current_take.hz)-lab.frequency) < .000001:
		return
	previous_take = current_take
	current_take = lab.steady_imprint()
	harbor.before = previous_take
	harbor.now = current_take


func _clear_lens() -> void:
	harbor.lens = {}
	harbor.reading_old = false


func _pair_reading() -> String:
	if previous_take.is_empty():
		return "风箱 %.3f Hz。三号峰值 %.2f cm，四号峰值 %.2f cm。" % [current_take.hz,current_take.peaks[2],current_take.peaks[3]]
	return "同一架五板、同一股推力。%.3f → %.3f Hz，三号峰值 %.2f → %.2f cm，四号 %.2f → %.2f cm。" % [previous_take.hz,current_take.hz,previous_take.peaks[2],current_take.peaks[2],previous_take.peaks[3],current_take.peaks[3]]


func _process(delta: float) -> void:
	if lab.shapes.is_empty() or not is_visible_in_tree():
		return
	harbor.view_time += delta
	harbor.bell_flash = maxf(0,harbor.bell_flash-delta*1.75)
	harbor.horn_flash = maxf(0,harbor.horn_flash-delta*1.9)
	harbor.tap_flash = maxf(0,harbor.tap_flash-delta*2.5)
	bell_wait = maxf(0,bell_wait-delta)
	horn_wait = maxf(0,horn_wait-delta)
	if phase in ["tuning","calling","landed","weighing","report"]:
		var previous := harbor.u
		var phase_from := lab.phase
		lab.advance(delta)
		harbor.u = lab.displacements()
		if phase in ["calling","weighing"]:
			_read_contacts(previous,phase_from,delta,true)
			_animate_call(delta)
		elif phase == "tuning":
			listening = maxf(0,listening-delta)
			_read_contacts(previous,phase_from,delta,false)
	harbor.queue_redraw()


func _read_contacts(previous: PackedFloat64Array, phase_from: float, delta: float, calling: bool) -> void:
	var bell := previous[3]*100 < lab.BELL_CM and harbor.u[3]*100 >= lab.BELL_CM
	var horn := previous[2]*100 <= lab.WHISTLE_CM and harbor.u[2]*100 > lab.WHISTLE_CM
	if lab.driving and not tapped:
		bell = lab.crosses_rising(3,lab.BELL_CM,phase_from,delta)
		horn = lab.peaks[2] > lab.WHISTLE_CM and lab.crosses_rising(2,lab.WHISTLE_CM,phase_from,delta)
	if bell:
		if bell_wait <= 0: _actuator("bell",calling or listening>0)
		if calling and trial_ok and departed_at < 0: departed_at=trial_time
	if horn and horn_wait <= 0:
		_actuator("horn",calling or listening>0)


func _tone(kind: String, board: int = 0) -> void:
	if sounds_enabled and is_visible_in_tree():
		ear.sound(kind,lab,board)


func _actuator(kind: String, audible: bool) -> void:
	if kind == "bell":
		harbor.bell_flash = 1
		bell_wait = .46
	else:
		harbor.horn_flash = 1
		horn_wait = .46
	if audible:
		_tone(kind)


func _row_button(row: HBoxContainer, label: String, action: Callable) -> Button:
	var button := StationUI.button(label,action)
	button.add_theme_font_size_override("font_size",16)
	button.custom_minimum_size.y = 36
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	return button


func _row() -> HBoxContainer:
	var row := StationUI.row(5)
	tools_box.add_child(row)
	return row


func _board_row() -> void:
	var row := _row()
	for i in range(5):
		_row_button(row,BOARD_NAMES[i],_pick_board.bind(i))


func _open_tuning() -> void:
	phase = "tuning"
	_clear_lens()
	harbor.recorded = {}
	harbor.show_scores = lab.loaded < 0
	harbor.tuning_live = true
	harbor.u = lab.displacements()
	harbor.selected_board = -1
	harbor.staged_load = -1
	if lab.loaded >= 0:
		set_scene("雾港 · 五板雾琴", "砝码仍在第%s板。找一个新的共鸣，听加重后的琴。" % BOARD_NAMES[lab.loaded])
	else:
		set_scene("雾港 · 五板雾琴", "同一座桥，只换敲击节奏。让四号港钟响起来，三号雾哨安静，渡船才会靠岸。")
	var heading := "配重后的自由调音" if lab.loaded >= 0 else "换个节奏，看看三号"
	set_tools(heading, "每次驱动的力气相同。三号过 1.7 cm 鸣哨，四号到 4.0 cm 敲钟。")
	meter = add_readout("")
	var coarse := _row()
	_row_button(coarse,"低一音栓",_move_stop.bind(-1))
	var faster := _row_button(coarse,"高一音栓",_move_stop.bind(1))
	compare_row = _row()
	_row_button(compare_row,"重听上一拍",_replay_previous)
	_row_button(compare_row,"拆看三号两侧",_open_lens)
	if lab.loaded >= 0:
		add_action("试听这一调音",_listen_to_weighted_signal,true)
	else:
		add_action("呼叫渡船",_call_ferry,true)
	var fine := _row()
	_row_button(fine,"微调 −0.02 Hz",_fine.bind(-1))
	_row_button(fine,"微调 +0.02 Hz",_fine.bind(1))
	var hand := _row()
	drive_button = _row_button(hand,"收起风箱",_toggle_drive)
	_row_button(hand,"定格 · 记录振型",_freeze)
	add_readout("拨板试听")
	_board_row()
	if not baseline.is_empty():
		add_action("重回空载配重对照",_setup_weight)
	if lab.loaded < 0 and previous_take.is_empty():
		_primary_focus = faster
	_update_meter()


func _update_meter() -> void:
	harbor.note = -1
	for n in range(5):
		if absf(lab.frequency-lab.frequencies[n]) < .007:
			harbor.note = n
	if phase == "tuning" and is_instance_valid(meter):
		if lab.driving:
			meter.text = "这次每秒鼓风 %.3f 次\n三号峰值 %.2f cm　四号峰值 %.2f cm" % [lab.frequency, lab.peaks[2], lab.peaks[3]]
		else:
			meter.text = "风箱合起　·　琴板自由衰减\n拨一块板，听振动沿弹簧传开。"
		drive_button.text = "收起风箱" if lab.driving else "重新鼓风"
		compare_row.visible = lab.loaded < 0 and not previous_take.is_empty()
	harbor.queue_redraw()


func _move_stop(direction: int) -> void:
	var nearest := 0
	for i in range(1,5):
		if absf(lab.frequencies[i]-lab.frequency) < absf(lab.frequencies[nearest]-lab.frequency):
			nearest=i
	_tune_to(posmod(nearest+direction,5))


func _fine(direction: int) -> void:
	_change_frequency(lab.frequency+direction*.02)


func _tune_to(index: int) -> void:
	if phase == "tuning":
		_change_frequency(lab.frequencies[index])


func _replay_previous() -> void:
	if phase == "tuning" and not previous_take.is_empty() and lab.loaded<0:
		_change_frequency(previous_take.hz)


func _change_frequency(hz: float) -> void:
	lab.set_frequency(hz)
	_save_take()
	tapped = false
	listening = 1.65
	harbor.u = lab.displacements()
	_tone("tune")
	_update_meter()
	if lab.loaded < 0 and not previous_take.is_empty():
		set_hint("两张侧影都取一号板最高的一刻。看二号和四号在平线的哪一边，再按「拆看三号两侧」听听为什么。")
	else:
		set_hint("听三号的低雾哨和四号的亮港钟。觉得这声能叫船，就把它送到海上。")


func _toggle_drive() -> void:
	if lab.driving:
		lab.release_bellows()
		set_hint("风箱停下了。此刻的位移和速度留在琴板上，能量会被阻尼慢慢带走。")
	else:
		_change_frequency(lab.frequency)
	listening = 1.65
	_update_meter()


func _pick_board(index: int) -> void:
	match phase:
		"tuning":
			lab.tap(index)
			tapped = true
			harbor.tap_flash = 1
			harbor.tap_board = index
			listening = 1.65
			_tone("wood",index)
			set_hint("第%s板挨了一拨。等它往回弹，看看隔着两根弹簧的板有没有跟上。" % BOARD_NAMES[index])
		"record":
			inspected = index
			harbor.selected_board = index
			_update_equation()
		"site", "predict":
			chosen_board = index
			harbor.staged_load = index
			harbor.selected_board = index
			_prediction_menu()


func _call_ferry() -> void:
	if phase != "tuning" or lab.loaded >= 0: return
	lab.set_frequency(lab.frequency)
	tapped = false
	phase = "calling"
	_begin_trial()
	set_tools("渡船正在听", "风箱正朝海面鼓动。港钟引船，雾哨会让船在外港等候。")
	add_readout(_amplitudes())
	set_hint("船头的灯在雾里。听它收到哪一种声音。")


func _listen_to_weighted_signal() -> void:
	lab.set_frequency(lab.frequency)
	tapped = false
	listening = 1.1/lab.frequency+.1
	harbor.u = lab.displacements()
	_update_meter()
	var sounds: Array[String] = []
	if lab.peaks[3] >= lab.BELL_CM: sounds.append("港钟")
	if lab.peaks[2] > lab.WHISTLE_CM: sounds.append("雾哨")
	var audible := "铃哨都安静" if sounds.is_empty() else "、".join(sounds)+"响起"
	set_hint("第%s板带着砝码，%.3f Hz 试听时%s。可回到空载，对下一次配重重新做预测。" % [BOARD_NAMES[lab.loaded],lab.frequency,audible])


func _begin_trial() -> void:
	harbor.recorded = {}
	harbor.tuning_live = false
	harbor.ferry = 0
	harbor.bell_flash = 0
	harbor.horn_flash = 0
	bell_wait = 0
	horn_wait = 0
	trial_time = 0
	trial_duration = maxf(CALL_TIME,1.0/lab.frequency+.9)
	departed_at = -1
	trial_ok = lab.answers_call()
	harbor.u = lab.displacements()


func _animate_call(delta: float) -> void:
	trial_time += delta
	var fraction := minf(1.0,trial_time/trial_duration)
	if trial_ok:
		harbor.ferry = clampf((trial_time-departed_at)/(trial_duration-departed_at),0,1) if departed_at>=0 else 0.0
	else:
		harbor.ferry = .15*sin(fraction*PI)
	if fraction >= 1.0:
		if phase == "weighing":
			_weight_report()
		else:
			_return_from_call()


func _amplitudes() -> String:
	return "%.3f Hz　·　三板 %.2f cm　·　四板 %.2f cm" % [lab.frequency, lab.peaks[2], lab.peaks[3]]


func _signal_result() -> String:
	if trial_ok: return "港钟单独响起，渡船靠港。"
	if lab.peaks[2] > lab.WHISTLE_CM:
		return "雾哨也响了，渡船留在外港。" if lab.peaks[3] >= lab.BELL_CM else "只有雾哨响，渡船留在外港。"
	return "港钟还够不着铃槌，渡船留在外港。"


func _spring_reason(take: Dictionary) -> String:
	var left: float = take.left
	var right: float = take.right
	if take.node:
		var second := "上" if float(take.primary.u[1])>0 else "下"
		var fourth := "下" if second=="上" else "上"
		return "这一种摆法里，二板在%s、四板在%s。两侧弹簧一个往上拉，一个往下拉，两股力一样大，三板停在中线。" % [second,fourth]
	if left*right > 0:
		return "这一种摆法里，三板离开中线，两侧弹簧在这一刻都把它往%s拉。两股力加在一起，三板会跟着整组来回摆。" % ("上" if left>0 else "下")
	return "这一种摆法里，两侧的拉力没能抵消。它们的合力让三板随着整组来回摆。"


func _open_lens() -> void:
	if current_take.is_empty() or lab.loaded >= 0:
		return
	lens_origin = phase
	_inspect_take(false)


func _pick_score(old: bool) -> void:
	if phase == "tuning" or phase == "landed":
		lens_origin=phase
	elif phase != "lens":
		return
	_inspect_take(old)


func _inspect_take(old: bool) -> void:
	var take := previous_take if old else current_take
	if take.is_empty(): return
	phase = "lens"
	harbor.lens = take
	harbor.reading_old = old
	harbor.recorded = {}
	harbor.tuning_live = false
	harbor.u = take.primary.u
	harbor.selected_board = 2
	var heading := "拆开上一拍的三号板" if old else "拆开当前一拍的三号板"
	set_tools(heading,_spring_reason(take))
	var actual := "风箱还会带起别的摆法，三号实测峰值仍有 %.2f cm。" % take.peaks[2] if take.node else "连续鼓风时，三号的实测峰值是 %.2f cm。" % take.peaks[2]
	actual += "四号实测 %.2f cm，%s。" % [take.peaks[3],"够到铃槌" if float(take.peaks[3])>=lab.BELL_CM else "够不到铃槌"]
	add_readout(actual)
	var other := current_take if old else previous_take
	if not other.is_empty():
		var n := int(take.primary.mode)-1
		add_readout("只看第%d种摆法在四号上的分量，%.3f Hz 时 %.2f cm，%.3f Hz 时 %.2f cm。" % [n+1,other.hz,other.fourth_by_mode_cm[n],take.hz,take.fourth_by_mode_cm[n]])
		add_action("看当前一拍" if old else "看上一拍",_inspect_take.bind(not old))
	if lens_origin == "landed":
		add_action("选择砝码板位",_setup_weight,true)
		add_action("记下返港振型",_freeze)
	else:
		add_action("用这张谱呼叫渡船",_call_from_lens,true)
	add_action("返回当前调音",_open_tuning)
	set_hint("整组按固定比例起伏，叫简正振型。其中一直不动的板位叫节点。敲击接近一组的固有节奏会把它放大，叫共振。")
	harbor.queue_redraw()


func _call_from_lens() -> void:
	var hz := float(harbor.lens.hz)
	_open_tuning()
	if absf(lab.frequency-hz)>.000001:
		_change_frequency(hz)
	_call_ferry()


func _return_from_call() -> void:
	if not trial_ok:
		_open_tuning()
		set_hint(_signal_result() + "  按「高一音栓」或「低一音栓」，对照换拍前后三、四号的峰值。")
		return
	baseline = {"hz":lab.frequency,"third":lab.peaks[2],"fourth":lab.peaks[3],"record":lab.modal_record()}
	play_cue("home")
	phase = "landed"
	set_tools("灯亮了，渡船靠港", _pair_reading())
	add_action("拆看三号两侧",_open_lens,true)
	add_action("记下返港振型",_freeze)
	add_action("继续调音",_open_tuning)
	set_hint("船系好缆绳了。拆看三号板，把左右两根弹簧的拉力分别画出来，再用你的峰值检验。")
	if not logged_first_ferry:
		logged_first_ferry = true
		complete({
			"title":"第一班夜渡靠港",
			"observation":_pair_reading(),
			"prediction":"我选了 %.3f Hz 风箱并按下「呼叫渡船」，预判这一声能指引夜渡靠岸。" % lab.frequency,
			"result":"三板振幅 %.2f cm，四板 %.2f cm。只有港钟响，第一班夜渡在码头系缆。" % [lab.peaks[2],lab.peaks[3]],
			"principle":_spring_reason(current_take)+" 整组的固定摆法叫简正振型，其中静止处叫节点。持续鼓风还会带起其他振型，三号仍有小幅运动。四号够到 4.0 cm 铃槌。",
			"boundary":"这次读数取自两端固定、每板 1 kg 的线性琴架，在一号板受到周期驱动力后的稳态。",
			"resolved":false
		})


func _freeze() -> void:
	phase = "record"
	_clear_lens()
	harbor.show_scores = false
	harbor.recorded = lab.modal_record(tapped)
	harbor.tuning_live = false
	harbor.u = harbor.recorded.u
	harbor.selected_board = inspected
	set_tools("把主振型定在峰值", "从声音中取出能量最大的一阶，按同一相位画五板的位移 u。点选一块板查它的箭头。")
	_board_row()
	meter = add_readout("")
	_update_equation()
	if not baseline.is_empty():
		add_action("选择砝码板位",_setup_weight,true)
	add_action("松开定格",_open_tuning,baseline.is_empty())
	set_hint("金箭头是位移。绿箭头由两侧弹簧算，粉箭头由这块板的质量和加速度算。比较它们的方向和长度。")


func _update_equation() -> void:
	var r := harbor.recorded
	var i := inspected
	var u_cm := float(r.u[i])*100.0
	var force := -float(r.ku[i])
	var ma := -float(r.inertia[i])
	if absf(u_cm)<.0005: u_cm = 0
	if absf(force)<.0005: force = 0
	if absf(ma)<.0005: ma = 0
	var place := "振型节点" if absf(lab.shapes[int(r.mode)-1][i])<.00000001 else "振动板位"
	meter.text = "第%s板 · %s　u = %+.2f cm\n绿　k(左位移 + 右位移 − 2uᵢ) = %+.3f N\n粉　mᵢaᵢ = −ω²mᵢuᵢ = %+.3f N\nω = 2πf。绿箭头是 −Ku，五板逐项相等，得到 Ku = ω²Mu。" % [BOARD_NAMES[i],place,u_cm,force,ma]


func _setup_weight() -> void:
	lab.configure()
	lab.set_frequency(baseline.hz)
	tapped = false
	phase = "site"
	_clear_lens()
	harbor.show_scores = false
	chosen_board = -1
	harbor.tuning_live = false
	harbor.recorded = baseline.record
	harbor.u = harbor.recorded.u
	harbor.staged_load = -1
	harbor.selected_board = -1
	harbor.moored = true
	harbor.second = true
	harbor.ferry = 0
	set_scene("雾港 · 五板雾琴", "红帆船到了外港。选一块板加重，预判原来的调音能否把它叫回码头。")
	_update_meter()
	set_tools("把砝码吊在哪块板", "再来一条红帆船。每板质量 1 kg，黄铜砝码 1.8 kg。先在刚才的振型上选落点。")
	_board_row()
	add_readout("旧调音 %.3f Hz　·　三板 %.2f cm　·　四板 %.2f cm" % [baseline.hz,baseline.third,baseline.fourth])
	set_hint("若砝码要跟一块板大幅来回摆，它会改变这组节奏。哪块板在刚才那种摆法里几乎不用带动砝码？")


func _prediction_menu() -> void:
	phase = "predict"
	set_tools("砝码悬在第%s板" % BOARD_NAMES[chosen_board], "先选你的预判。随后放下砝码，保持刚才的风箱频率，听第二班船的回音。")
	add_readout("第%s板从 1.0 kg 加到 2.8 kg　·　风箱 %.3f Hz" % [BOARD_NAMES[chosen_board],baseline.hz])
	add_readout("拆出的第%d种摆法里，这块板的峰值是 %.2f cm。想想砝码会不会被它来回带动。" % [baseline.record.mode,100*absf(baseline.record.u[chosen_board])])
	add_action("预测仍会靠港",_predict.bind(true),true)
	add_action("预测这次会失效",_predict.bind(false))
	add_action("改选板位",_setup_weight)
	set_hint("悬起的砝码还没有接触琴板。你按下预测时，绳索才会放开。")


func _predict(will_return: bool) -> void:
	if phase != "predict": return
	prediction = will_return
	lab.configure(chosen_board)
	lab.set_frequency(baseline.hz)
	phase = "weighing"
	harbor.staged_load = -1
	harbor.selected_board = chosen_board
	_update_meter()
	_begin_trial()
	set_tools("第二班船正在听", "砝码已经落下。风箱仍以 %.3f Hz 鼓动一号板。" % lab.frequency)
	add_readout(_amplitudes())
	set_hint("听这一次，或看港钟和雾哨两侧的声纹。")


func _weight_report() -> void:
	phase = "report"
	var arrived := trial_ok
	var board: String = BOARD_NAMES[chosen_board]
	var isolated: Dictionary = baseline.record
	var before_u: float = isolated.u[chosen_board]*100.0
	if absf(before_u)<.0005: before_u=0
	var mode_i: int = isolated.mode-1
	var shift: float = lab.frequencies[mode_i]-float(isolated.hz)
	if absf(shift)<.0005: shift=0
	var forecast := "旧调音仍会叫回船" if prediction else "旧调音这次会失效"
	var outcome := _signal_result()
	var comparison := "你的预测和实测相符。" if prediction==arrived else "这一次实测改写了预测。"
	var at_node := absf(isolated.u[chosen_board])<.00000001
	var why := "原来的这组摆法在这里有节点，砝码也无须随板起伏，因此这一阶能保留原频率。持续鼓风仍会带动其他摆法。" if at_node else "原来的这组摆法会带动这块板。挂上砝码，同样的回复力要带动更大的质量，这一阶的固有节奏随之改变。"
	set_tools("红帆船也到港了" if arrived else "红帆船停在雾外", outcome+comparison)
	add_readout("空载　三板 %.2f cm　四板 %.2f cm\n配重　三板 %.2f cm　四板 %.2f cm\n第%d阶固有频率　%.3f → %.3f Hz" % [baseline.third,baseline.fourth,lab.peaks[2],lab.peaks[3],isolated.mode,isolated.hz,lab.frequencies[mode_i]])
	add_readout(why)
	add_action("换块板再试",_setup_weight,true)
	add_action("带砝码自由调音",_open_tuning)
	add_action("重置空载重新开航",_reset_instrument)
	var lesson := "旧振型的第%s板位移为 %+.2f cm。配重后，第%d阶频率变化 %+.3f Hz。弹簧给 −Ku，单一自由振型给 a = −ω²u，两者依牛顿定律满足 Ku = ω²Mu。" % [board,before_u,isolated.mode,shift]
	var record := {
		"title":"雾港五板琴 · 第%s板配重" % board,
		"observation":"空载时风箱 %.3f Hz，三板 %.2f cm，四板 %.2f cm，第一班渡船靠港。" % [baseline.hz,baseline.third,baseline.fourth],
		"prediction":"加 1.8 kg 到第%s板，保持 %.3f Hz，出手前我选了「%s」。" % [board,baseline.hz,forecast],
		"result":"配重后三板 %.2f cm、四板 %.2f cm。%s%s" % [lab.peaks[2],lab.peaks[3],outcome,comparison],
		"principle":lesson+why,
		"boundary":"五板两端固定，六段预紧联簧在静平衡附近取线性近似，阻尼与质量成正比。换音栓直接取一号板受力的稳态。箭头取自无阻尼自由振型，琴板试听升频 220 倍。",
		"resolved":arrived
	}
	complete(record)
	play_cue("home" if arrived else "seed")
	var next_place := "明显起伏" if at_node else "几乎不动"
	set_hint("这块板原来在该振型里的峰值是 %.2f cm。换到原本%s的一块，再预测旧节奏还能不能叫船。" % [absf(before_u),next_place])
