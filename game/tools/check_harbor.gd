extends SceneTree

var game
var harbor
var issues: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _expect(ok: bool, message: String) -> void:
	if not ok:
		issues.append(message)
		push_error("Harbor check failed: " + message)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _key(keycode: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = down
		root.push_input(event)
		await process_frame

func _pad(button: JoyButton) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = down
		root.push_input(event)
		await process_frame

func _by_text(tree: Control, caption: String) -> Button:
	for node: Button in tree.find_children("*", "Button", true, false):
		if node.text.begins_with(caption) and node.is_visible_in_tree() and not node.disabled:
			return node
	return null

func _press(tree: Control, label: String) -> void:
	var button := _by_text(tree, label)
	_expect(is_instance_valid(button), "button " + label)
	if button != null:
		button.grab_focus()
		await _key(KEY_ENTER)

func _phase(station: Control, target: String, limit: int = 1300) -> void:
	for i in limit:
		if station.phase == target:
			return
		await process_frame
	_expect(false, "wait for " + target + " (reached " + str(station.phase) + ")")

func _board(index: int) -> void:
	var id: String = ["chime", "towers", "wind"][index]
	var button: Button = harbor.map.buttons[id]
	button.grab_focus()
	await _pad(JOY_BUTTON_A)
	_expect(harbor.screen == "station" and harbor.selected == id and harbor.stations.has(id), "enter " + id)

func _notes(key: String) -> Array:
	return game.profile.harbor_notes.get(key, [])

func _first_delivery() -> void:
	var loading = harbor.stations.loading
	_expect(loading.phase == "ready" and loading.model.held_index < 0, "first shift opens directly at the truck")
	await _key(KEY_TAB)
	await _frames(20)
	_expect(game.book._active_key == "01-8f6205ff" and loading.phase == "ready", "the corresponding mechanics lesson preserves the truck's state")
	await _key(KEY_TAB)
	await _pad(JOY_BUTTON_B)
	_expect(harbor.screen == "map" and harbor.selected == "loading", "the player can leave a shift at any time")

func _chime() -> void:
	await _board(0)
	var station = harbor.stations.chime
	await _press(station, "呼叫渡船")
	await _phase(station, "tuning")
	_expect(station.baseline.is_empty(), "two simultaneous bells keep the berth empty")
	await _press(station, "高一音栓")
	await _press(station, "拆看三号两侧")
	_expect(station.phase == "lens" and station.current_take.node and not station.previous_take.node, "the two rhythms produce different patterns")
	_expect(absf(station.current_take.left + station.current_take.right) < .00001 and station.current_take.peaks[2] > 1.0, "ideal modal forces cancel while the driven board retains a measured residual")
	await _press(station, "返回当前调音")
	await _press(station, "呼叫渡船")
	await _frames(6)
	await _key(KEY_TAB)
	var stopped: float = station.trial_time
	await _frames(40)
	_expect(game.mode == "library" and game.book._relevant.has("01-7591bdc8") and station.trial_time == stopped, "read actual normal-mode course with the boat paused")
	await _key(KEY_TAB)
	await _phase(station, "landed")
	_expect(_notes("chime").size() == 1 and not game.profile.harbor_resolved.has("chime"), "first boat is recorded before the second commission")
	await _press(station, "记下返港振型")
	_expect(station.phase == "record" and absf(float(station.harbor.recorded.u[2])) < .00001, "freeze the measured node")
	await _press(station, "选择砝码板位")
	await _press(station, "四")
	_expect(station.phase == "predict" and is_equal_approx(station.lab.masses[3],1.0), "mass still held while forecasting")
	await _press(station, "预测仍会靠港")
	await _phase(station, "report")
	_expect(not station.trial_ok and _notes("chime").size() == 2 and not _notes("chime").back().resolved, "missed prediction is retained")
	await _press(station, "换块板再试")
	await _press(station, "三")
	await _press(station, "预测仍会靠港")
	await _phase(station, "report")
	_expect(station.trial_ok and _notes("chime").size() == 3 and _notes("chime").back().resolved, "a different weight position brings back the ferry")
	await _key(KEY_J)
	_expect(harbor.screen == "journal" and harbor.compare.visible, "journal can compare both experiments")
	await _press(harbor.journal, "对照上一次")
	_expect(harbor.comparing, "side-by-side player predictions")
	await _key(KEY_ESCAPE)
	_expect(harbor.screen == "station" and station.phase == "report", "journal restores experimental state")
	await _pad(JOY_BUTTON_B)
	_expect(harbor.screen == "map" and harbor.map.moored, "ferry visible at the hub")
	print("normal modes: failed at board 4, delivered at the node")

func _towers() -> void:
	await _board(1)
	var tower = harbor.stations.towers
	await _press(tower, "先试两扇灯窗")
	await _press(tower, "两头平行")
	await _frames(75)
	await _press(tower, "月塔转到 90°")
	await _frames(75)
	_expect(tower.quick.batches[0].log.matched[0] == 64 and tower.quick.batches[1].log.matched[0] == 0, "turning one polarizer changes what the two logs show together")
	await _press(tower, "开同号舱")
	await _frames(75)
	_expect(_notes("towers").back().title == "只转月塔的灯窗试航" and not _notes("towers").back().resolved, "fixed-angle comparison stays separate from a four-setting CHSH result")
	await _press(tower, "回到双塔值班")
	# This seed makes the test reproducible. Normal play draws fresh independent inputs.
	tower.rng.seed = 20261120
	await _press(tower, "亲手连起三条同号缆")
	await _press(tower, "扣在亮面")
	_expect(tower.link_count == 0, "an unequal proof link slips")
	for i in 3:
		await _press(tower, "扣在暗面")
	await _press(tower, "押它会被拦")
	_expect(tower.seen.count(1) == 3, "fourth classical boat stays outside")
	await _press(tower, "登塔查")
	for turn in [[1,1],[1,1],[2,1],[3,-1]]:
		tower._select_axis(turn[0])
		var caption := "右转" if int(turn[1]) > 0 else "左转"
		await _press(tower, caption)
	await _press(tower, "报一个胜率")
	_expect(tower._seal.disabled, "departure waits for a player's forecast")
	tower._choose_forecast(8)
	tower._choose_fleet(1)
	await _press(tower, "封存这次预报")
	await _phase(tower, "review")
	_expect(tower.logbook.count == 256 and tower.logbook.interval().x > .75 and not _notes("towers").back().resolved, "256 sampled pairs filed before signing")
	_expect(tower.logbook.chsh_score() > 2 and tower.logbook.chsh_score() < 4, "sampled correlation uses all four equally weighted input groups")
	await _press(tower, "核验船长")
	tower._sign(false)
	_expect(tower.phase == "audit" and not game.profile.harbor_resolved.has("towers"), "unwarranted signature is rejected")
	tower._sign(true)
	_expect(tower.phase == "signed" and _notes("towers").back().resolved, "evidence signature saved")
	await _key(KEY_ESCAPE)
	print("two lighthouses: ", tower.logbook.wins, " of ", tower.logbook.count, " actual pairs won")

func _wind() -> void:
	await _board(2)
	var boat = harbor.stations.wind
	await _press(boat, "并排试两支探头")
	_expect(boat.probe_open and absf(boat.probe_trace.normal[0] / boat.probe_trace.fine[0] - 10.0) < .001, "the two weather probes begin from tenfold different errors on the same reference")
	await _press(boat, "放到")
	_expect(boat.probe_tick > 0 and boat.clock_tick == 0 and boat.buoy_place.is_empty(), "reading the old weather record does not move the real mailboat")
	await _press(boat, "回船选择探头与航线")
	for put_out in [false, true]:
		await _press(boat, "解缆")
		await _phase(boat, "shoal")
		await _press(boat, "穿过浅滩")
		await _phase(boat, "mouth")
		if put_out:
			await _press(boat, "在此投浮标")
		await _press(boat, "入裂帆峡")
		await _phase(boat, "done")
		_expect(boat.delivered == put_out, "actual blow across the boundary depends on our buoy")
		if not put_out:
			await _press(boat, "沿同一场雾再开")
	await _press(boat, "核对两支探头")
	_expect(_notes("wind").size() == 2 and _notes("wind").back().resolved and boat.clock_tick > 0, "weather evidence from loss and delivery")
	await _key(KEY_ESCAPE)
	print("fog route: one missed crossing, one receipt at ", boat.port_minutes(boat.clock_tick), " port minutes")

func _dock() -> void:
	await _press(harbor.map, "工棚试摆台")
	var dock = harbor.stations.dock
	await _press(dock, "脱开 0")
	await _press(dock, "单拨近篮")
	await _frames(90)
	_expect(absf(dock.state.y) < .00001, "disconnected far basket stays still")
	await _press(dock, "软簧 20")
	await _press(dock, "单拨近篮")
	await _frames(100)
	var largest := 0.0
	for sample: Vector3 in dock.trace:
		largest = maxf(largest, absf(sample.z))
	_expect(largest > .01, "reattached spring transfers motion during a swing")
	_expect(_by_text(dock, "叫邮船") == null, "the workshop is freely playable without a delivery contract")
	await _key(KEY_ESCAPE)
	_expect(harbor.screen == "map" and harbor.map.buttons.has(harbor.selected), "return from an unmarked workshop restores a map pin")

func _run() -> void:
	var scratch := OS.get_environment("WINDSEED_TEST_ROOT").replace("\\", "/").trim_suffix("/")
	if scratch.is_empty() or not OS.get_user_data_dir().replace("\\", "/").begins_with(scratch+"/"):
		quit(2)
		return
	var old_save := ConfigFile.new()
	old_save.set_value("port", "version", 1)
	old_save.set_value("port", "generation", 4)
	old_save.set_value("port", "seeds", 2)
	_expect(old_save.save("user://harbour-a.cfg") == OK, "legacy profile fixture")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	harbor = game.harbor
	await _frames(3)
	await _key(KEY_ENTER)
	_expect(game.mode == "harbor" and harbor.screen == "station" and harbor.selected == "loading" and harbor.stations.loading.phase == "ready", "one action from the title puts the operator on shift")
	_expect(game.profile.seeds == 2 and game.profile.harbor_notes.is_empty(), "older profile gains an empty journal")
	await _pad(JOY_BUTTON_BACK)
	_expect(harbor.screen == "journal" and harbor.rows.is_empty(), "empty journal from controller")
	await _pad(JOY_BUTTON_B)
	await _first_delivery()
	await _chime()
	await _towers()
	await _wind()
	_expect(harbor.sail.visible and game.profile.harbor_resolved.size() == 3, "three completed commissions unlock the outbound route")
	await _dock()
	_expect(harbor.sail.visible and not game.profile.harbor_resolved.has("quay"), "both the workshop and cargo shifts are optional for the night route")
	var reloaded = game.Harbour.new()
	reloaded.load_profile()
	_expect(reloaded.seeds == 2 and reloaded.harbor_resolved == game.profile.harbor_resolved and reloaded.harbor_notes == game.profile.harbor_notes, "player observations and existing cargo survive relaunch")
	await _press(harbor.map, "带上三份航测匣出港")
	_expect(game.mode == "hangar" and game.case_plan == PackedStringArray(["01-7591bdc8","21-3c117040","20-d3ae2b69"]), "actual matching courses loaded on outbound glider")
	await _key(KEY_ENTER)
	_expect(game.mode == "flight" and game.sampling._active, "outbound glider uses actual course")
	game.sound.set_enabled(false)
	game.queue_free()
	await _frames(2)
	OS.delay_msec(160)
	await process_frame
	print("Harbor checks ", "passed" if issues.is_empty() else "failed")
	quit(0 if issues.is_empty() else 1)
