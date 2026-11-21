extends SceneTree

const Equation := preload("res://harbor/chime/chime_physics.gd")
const Station := preload("res://harbor/chime/chime.gd")
var failures := 0
var checks := 0
var entries: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _expect(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)


func _test_equation() -> void:
	var lab := Equation.new()
	for weight in range(-1,5):
		lab.configure(weight)
		for n in range(5):
			if weight == -1:
				_expect(absf(lab.frequencies[n]-2.0*sin((n+1)*PI/12.0))<1e-9, "uniform fixed-chain frequency")
			var ku := lab.stiffness_times(lab.shapes[n])
			for i in range(5):
				_expect(absf(ku[i]-lab.eigenvalues[n]*lab.masses[i]*lab.shapes[n][i])<1e-8, "generalised eigenvector residual")
			for j in range(5):
				var inner := 0.0
				for i in range(5):
					inner += lab.shapes[n][i]*lab.masses[i]*lab.shapes[j][i]
				_expect(absf(inner-float(n==j))<1e-9,"mass orthonormality")
		for hz in [.372,1.0,1.281,1.732,2.08]:
			lab.set_frequency(hz)
			var take := lab.steady_imprint()
			var c := PackedFloat64Array([0,0,0,0,0])
			var s := c.duplicate()
			for i in range(5):
				for n in range(5):
					c[i] += lab.shapes[n][i]*lab.cosine[n]
					s[i] += lab.shapes[n][i]*lab.sine[n]
			var kc := lab.stiffness_times(c)
			var ks := lab.stiffness_times(s)
			var omega: float = TAU*hz
			for i in range(5):
				var m := lab.masses[i]
				_expect(absf(kc[i]-omega**2*m*c[i]+lab.DAMP_RATE*omega*m*s[i]-float(i==0)*lab.DRIVE_NEWTON)<1e-8, "forced cosine residual")
				_expect(absf(ks[i]-omega**2*m*s[i]-lab.DAMP_RATE*omega*m*c[i])<1e-8,"forced sine residual")
				_expect(absf(sqrt(c[i]**2+s[i]**2)*100-lab.peaks[i])<1e-9,"settled peak")
			lab.advance(fposmod(lab.peak_phase[0],TAU)/(TAU*hz))
			var side := lab.displacements()
			for i in range(5):
				_expect(absf(100.0*side[i]-take.side_cm[i])<1e-9,"printed boards shown at one simultaneous sampled instant")
			_expect(absf(take.side_cm[0]-take.peaks[0])<1e-9,"common board-one phase")
			_expect(absf(take.left+take.right+take.primary.ku[2])<1e-9,"two separate springs give the marked middle board's net restoring force")
			var idx: int = take.primary.mode-1
			_expect(absf(absf(take.primary.u[3])*100-take.fourth_by_mode_cm[idx])<1e-9,"fourth-board modal amplitude kept distinct from observed total")
	lab.configure()
	for i in range(5):
		lab.set_frequency(lab.frequencies[i])
		_expect(lab.answers_call() == (i==1 or i==3),"two actual eigenstops pass")
	lab.set_frequency(1.0)
	var observed := PackedInt32Array([0,0])
	for step in range(240):
		var phase_from := lab.phase
		var initial := lab.displacements()
		lab.advance(1.0/240)
		var final := lab.displacements()
		for j in range(2):
			var board := 2+j
			var limit := lab.WHISTLE_CM if j==0 else lab.BELL_CM
			var crossing := lab.crosses_rising(board,limit,phase_from,1.0/240)
			_expect(crossing == (initial[board]*100<limit and final[board]*100>=limit),"actuator at actual rising displacement")
			if crossing: observed[j]+=1
	_expect(observed[0]==0 and observed[1]==1,"one real bell contact and no horn per cycle")
	lab.advance(0.31)
	var before := lab.displacements()
	lab.release_bellows()
	for i in range(5):
		_expect(absf(lab.displacements()[i]-before[i])<1e-12,"bellows release continuity")
	var untouched := Equation.new()
	untouched.configure(3)
	untouched.set_frequency(1.0)
	lab.configure(3)
	lab.set_frequency(1.0)
	lab.tap(3)
	lab.advance(.00001)
	untouched.advance(.00001)
	var impulse := (lab.displacements()[3]-untouched.displacements()[3])/.00001
	_expect(absf(impulse-.43/2.8)<.00001,"true impulse on weighted plate")


func _press(station,caption: String) -> void:
	var found: Button
	for child in station.tools_box.find_children("*","Button",true,false):
		if child.text == caption:
			found = child
			break
	_expect(found != null,"missing visible button "+caption)
	if found == null: return
	found.grab_focus()
	_expect(root.gui_get_focus_owner()==found,"UI focus "+caption)
	var down := InputEventAction.new()
	down.action = &"ui_accept"
	down.pressed = true
	var up := InputEventAction.new()
	up.action = &"ui_accept"
	root.push_input(down,true)
	root.push_input(up,true)


func _settle(station) -> void:
	for i in range(270): station._process(1.0/60)


func _click_art(view,local: Vector2) -> void:
	var world: Vector2 = view.get_global_transform_with_canvas()*(view._origin()+local*view._scale())
	var motion := InputEventMouseMotion.new()
	motion.position = world
	motion.global_position = world
	root.push_input(motion,true)
	for down in [true,false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = world
		click.global_position = world
		click.pressed = down
		root.push_input(click,true)


func _run() -> void:
	_test_equation()
	var station := Station.new()
	station.sounds_enabled = false
	root.add_child(station)
	await process_frame
	station.process_mode = Node.PROCESS_MODE_DISABLED
	var held := station.lab.phase
	await process_frame
	await process_frame
	_expect(station.lab.phase==held,"paused station holds the mechanism")
	station.process_mode = Node.PROCESS_MODE_INHERIT
	station.set_process(false)
	station.discovery.connect(func(entry: Dictionary) -> void: entries.append(entry))
	_expect(station.previous_take.is_empty() and station.current_take.primary.mode==1,"opening shows only the actual running slow beat")
	_press(station,"高一音栓")
	_expect(station.current_take.primary.mode==2 and station.previous_take.primary.mode==1,"changing only rhythm retains both experiments")
	_expect(station.previous_take.side_cm[1]>0 and station.previous_take.side_cm[3]>0 and station.current_take.side_cm[1]>0 and station.current_take.side_cm[3]<0,"players see the two neighbours change relative direction")
	_expect(absf(station.current_take.peaks[2]-1.25996)<.001 and station.current_take.peaks[3]>10.70,"current steady horn retains an observable residual")
	_press(station,"拆看三号两侧")
	_expect(station.phase=="lens" and station.harbor.lens.node and not station.harbor.reading_old,"native control opens the physical magnifier")
	_expect(absf(station.harbor.lens.left-4.2454)<.001 and absf(station.harbor.lens.right+4.2454)<.001,"equal opposite components of the extracted second mode")
	_expect(station.current_take.fourth_by_mode_cm[1]>10.7 and station.previous_take.fourth_by_mode_cm[1]<.87,"same mode is strengthened by retuning the same force")
	_press(station,"看上一拍")
	_expect(station.harbor.reading_old and not station.harbor.lens.node and station.harbor.lens.left<-.73 and station.harbor.lens.right<-.73,"alternate rhythm genuinely changes middle-plate forces")
	_press(station,"看当前一拍")
	_click_art(station.harbor,Vector2(190,40))
	_expect(station.harbor.reading_old,"clicking the earlier imprint selects that genuine stored reading")
	_click_art(station.harbor,Vector2(610,40))
	_press(station,"返回当前调音")
	_press(station,"重听上一拍")
	_expect(absf(station.lab.frequency-0.517638)<.000001 and absf(station.previous_take.hz-1.0)<.000001,"replay actually switches the drive and exchanges comparison")
	_press(station,"重听上一拍")
	_press(station,"拆看三号两侧")
	_press(station,"看上一拍")
	_press(station,"用这张谱呼叫渡船")
	_settle(station)
	_expect(station.phase=="tuning" and not station.trial_ok and entries.is_empty(),"calling with the chosen previous score uses its actual unsuitable rhythm")
	_click_art(station.harbor,Vector2(674,391))
	_expect(station.harbor.note==4,"brass tuning stop by mouse")
	_click_art(station.harbor,Vector2(147,391))
	_click_art(station.harbor,Vector2(541,269))
	_expect(station.harbor.tap_board==3,"wooden board by mouse")
	_press(station,"三")
	_expect(station.tapped,"a board tap reaches the physical model")
	_press(station,"收起风箱")
	_expect(not station.lab.driving,"drive releases to free motion")
	_press(station,"重新鼓风")
	_press(station,"呼叫渡船")
	_settle(station)
	_expect(station.phase=="tuning" and station.baseline.is_empty() and entries.is_empty(),"unsuitable call returns to play")
	_press(station,"高一音栓")
	_press(station,"呼叫渡船")
	_expect(station.harbor.ferry==0.0 and station.harbor.bell_flash==0.0,"ferry waits for the bell contact")
	for step in range(60):
		station._process(1.0/60)
		if station.harbor.bell_flash>.99: break
	_expect(station.harbor.bell_flash>.99 and station.harbor.horn_flash==0.0,"only physical fourth contact rings")
	_settle(station)
	_expect(station.phase=="landed" and station.harbor.ferry==1.0,"the first ferry physically arrives")
	_expect(entries.size()==1 and entries[0].title=="第一班夜渡靠港" and not entries[0].resolved,"first ferry independently enters the log")
	if entries.size()==1:
		_expect(entries[0].prediction.contains("1.000 Hz") and entries[0].result.contains("10.71 cm"),"first ferry saves real input and amplitudes")
		_expect(entries[0].observation.contains("13.85") and entries[0].observation.contains("1.26") and entries[0].principle.contains("两股力一样大"),"the journal contains the player's paired evidence and reason")
	_press(station,"拆看三号两侧")
	_expect(station.lens_origin=="landed" and station.harbor.lens.node,"landing leads to plain-language spring evidence before formal equations")
	_press(station,"记下返港振型")
	if station.phase!="record":
		push_error("Interrupted after UI selection")
		quit(1)
		return
	_expect(station.harbor.recorded.mode==2,"selected primary mode")
	var snapshot: PackedFloat64Array=station.harbor.u.duplicate()
	_settle(station)
	_expect(station.harbor.u==snapshot,"modal record stays frozen")
	_press(station,"三")
	_expect(absf(snapshot[2])<1e-10 and station.meter.text.contains("+0.000 N"),"node arrows and numerical display")
	_press(station,"四")
	_expect(absf(snapshot[3])>.04,"fourth board really moves")
	_press(station,"选择砝码板位")
	_press(station,"三")
	_expect(station.lab.loaded==-1 and station.harbor.staged_load==2 and entries.size()==1,"player chooses before mass is applied")
	_press(station,"预测这次会失效")
	_expect(station.lab.loaded==2,"prediction applies weight")
	_settle(station)
	_expect(entries.size()==2 and station.harbor.ferry==1.0,"node load preserves this call")
	if entries.size()==2:
		_expect(entries[1].resolved and entries[1].prediction.contains("会失效") and entries[1].result.contains("改写"),"wrong prediction preserved against evidence")
		print("NODE ",entries[1].observation," | ",entries[1].result)
	_press(station,"换块板再试")
	_press(station,"四")
	_press(station,"预测这次会失效")
	_settle(station)
	_expect(entries.size()==3 and station.harbor.ferry<.001,"antinode load loses the same call")
	if entries.size()==3:
		_expect(not entries[2].resolved and entries[2].result.contains("留在外港") and entries[2].result.contains("相符"),"counterexample recorded without passage")
		for k in ["title","observation","prediction","result","principle","boundary"]:
			_expect(not str(entries[2].get(k,"")).is_empty(),"evidence field "+k)
		print("ANTINODE ",entries[2].result," | ",entries[2].principle)
	_press(station,"带砝码自由调音")
	_expect(not station.harbor.show_scores and not station.compare_row.visible,"weighted tuning never compares against stale unloaded prints")
	_press(station,"微调 +0.02 Hz")
	_expect(station.lab.loaded==3 and absf(station.lab.frequency-1.02)<1e-9,"loaded free play and tuning")
	_press(station,"试听这一调音")
	_expect(entries.size()==3 and absf(station.baseline.hz-1.0)<1e-9 and station.phase=="tuning","weighted free play keeps the genuine unloaded baseline")
	_press(station,"定格 · 记录振型")
	_expect(station.harbor.recorded.has("inertia"),"free experiment may be recorded")
	_press(station,"选择砝码板位")
	_press(station,"三")
	_press(station,"预测仍会靠港")
	_settle(station)
	_press(station,"重置空载重新开航")
	_press(station,"高一音栓")
	_press(station,"呼叫渡船")
	_settle(station)
	_expect(entries.size()==4 and station.phase=="landed","replaying an unloaded arrival does not duplicate its journal observation")
	for voice in ["bell","horn","wood","tune"]:
		var stream: AudioStreamWAV = station.ear._sample(voice,station.lab,3)
		_expect(stream.data.size()>6000 and stream.get_length()>.20,"sound sample "+voice)
	print("CHIME CHECK ",checks," checks; ",failures," failures")
	quit(int(failures!=0))
