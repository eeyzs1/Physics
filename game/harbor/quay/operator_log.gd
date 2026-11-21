extends RefCounted

const ReplayView := preload("res://harbor/quay/replay_view.gd")
const COURSE_KEYS := ["01-0", "01-b789ec3f", "00-1"]
const STILL := 0.002
const MOVING_LOAD := 0.10
const TRACE_LIMIT := 16000

var samples: Array[Dictionary] = []
var brake: Dictionary = {}
var after_brake: Dictionary = {}
var first_touch: Dictionary = {}
var settled: Dictionary = {}
var period: Dictionary = {}
var max_swing: Dictionary = {}
var target_x := 0.0
var target_y := 0.0
var source_x := 0.0
var source_y := 0.0
var rail_y := 10.0
var box_width := 2.0
var box_height := 1.35
var job_index := -1
var _last: Dictionary = {}
var _released_in_motion := false
var _follow_stop := false
var _stop_time := -1.0
var _initial_goal := ""
var _sequence := 0
var _contacts := 0
var _gravity := 9.81
var _finished := false
var _stride := 1
var _step_count := 0
var _held: Dictionary = {}
var _turn_before: Dictionary = {}
var _peak_by_side: Dictionary = {}
var _peak_side := 0
var _segment_swing := 0.0

func begin(rig, plan: String = "") -> void:
	samples.clear()
	brake = {}
	after_brake = {}
	first_touch = {}
	settled = {}
	period = {}
	max_swing = {}
	_released_in_motion = false
	_follow_stop = false
	_stop_time = -1.0
	_finished = false
	_step_count = 0
	_stride = 1
	_reset_period_segment()
	_initial_goal = plan.strip_edges()
	_sequence = rig.touch_sequence
	_contacts = rig.contacts
	job_index = rig.job_index
	target_x = rig.target_x
	target_y = rig.target_y
	source_x = rig.source_x
	source_y = rig.source_y
	rail_y = rig.RAIL_Y
	box_width = rig.BOX_WIDTH
	box_height = rig.BOX_HEIGHT
	_gravity = rig.GRAVITY
	_last = _snapshot(rig)
	samples.append(_last)
	_consider_swing(_last)

func _snapshot(rig) -> Dictionary:
	var pos: Vector2 = rig.load_position()
	var velocity: Vector2 = rig.load_velocity()
	return {"t":float(rig.elapsed), "x":float(rig.trolley_x), "box_x":pos.x, "box_y":pos.y,
		"rope":float(rig.rope_length), "cart_vx":float(rig.trolley_speed), "box_vx":velocity.x,
		"box_vy":velocity.y, "relative":velocity.x-float(rig.trolley_speed), "offset":pos.x-float(rig.trolley_x),
		"angle":float(rig.angle), "omega":float(rig.angular_velocity), "grounded":bool(rig.grounded),
		"slack":float(rig.rope_slack)}

func observe(rig, _delta: float) -> void:
	if _last.is_empty() or rig.job_index != job_index or rig.elapsed < float(_last.t)-0.00001:
		begin(rig)
		return
	if _finished or rig.elapsed <= float(_last.t): return
	var row := _snapshot(rig)
	_consider_swing(row)
	_observe_brake(row, rig.drive_input)
	_observe_period(row, rig.hoist_speed, rig.contacts != _contacts or rig.touch_sequence != _sequence)
	_contacts = rig.contacts
	var event_now := false
	if rig.touch_sequence > _sequence:
		_sequence = rig.touch_sequence
		if first_touch.is_empty() and not rig.first_touch.is_empty():
			# The integrator keeps the first event even if several substeps ran.
			# Its velocities are pre-impact, not the clamped post-contact values.
			first_touch = rig.first_touch.duplicate(true)
			event_now = true
	if rig.delivered:
		settled = row.duplicate()
		settled["contacts"] = rig.contacts
		_finished = true
		event_now = true
	_step_count += 1
	if _step_count % _stride == 0 or event_now:
		samples.append(row)
	if samples.size() >= TRACE_LIMIT:
		# Observe every step, but thin old drawing points in unusually long shifts.
		# The contact, stop and peak snapshots above remain at full resolution.
		var reduced: Array[Dictionary] = []
		for i in range(0, samples.size(), 2):
			reduced.append(samples[i])
		if reduced.back().t != samples.back().t: reduced.append(samples.back())
		samples = reduced
		_stride *= 2
	_last = row

func _consider_swing(row: Dictionary) -> void:
	if not row.grounded and (max_swing.is_empty() or absf(row.offset) > absf(max_swing.offset)):
		max_swing = row

func _observe_brake(row: Dictionary, drive: float) -> void:
	if not brake.is_empty():
		if _follow_stop:
			if absf(drive)>0.01 or absf(row.cart_vx)>STILL or row.grounded:
				_follow_stop = false
			else:
				after_brake = row
				_follow_stop = row.t-brake.time < 0.50
		return
	if absf(drive)>0.01:
		_released_in_motion = false
		_stop_time = -1
		return
	if maxf(absf(row.cart_vx),absf(_last.cart_vx)) > 0.05:
		_released_in_motion = true
	if absf(row.cart_vx) > STILL:
		_stop_time = -1
		return
	if not _released_in_motion: return
	if _stop_time < 0.0: _stop_time = row.t
	if row.t - _stop_time > 0.45:
		_released_in_motion = false
		return
	if row.grounded or absf(row.box_vx) < MOVING_LOAD: return
	brake = row.duplicate()
	brake["time"] = row.t
	brake["stop_time"] = _stop_time
	brake["speed"] = row.box_vx
	brake["relative_speed"] = row.relative
	brake["cart_x"] = row.x
	_follow_stop = true

func _reset_period_segment() -> void:
	_held = {}
	_turn_before = {}
	_peak_by_side.clear()
	_peak_side = 0
	_segment_swing = 0.0

func _observe_period(row: Dictionary, hoist_speed: float, impact: bool) -> void:
	if not period.is_empty() or row.grounded or row.slack>0.001 or impact or absf(row.cart_vx) > STILL or absf(hoist_speed) > STILL:
		if not _held.is_empty(): _reset_period_segment()
		return
	if not _held.is_empty() and (absf(row.x-_held.x)>0.002 or absf(row.rope-_held.rope)>0.002):
		_reset_period_segment()
	if _held.is_empty(): _held = row
	_segment_swing = maxf(_segment_swing, absf(row.angle))
	if absf(row.omega) < 0.00001: return
	if not _turn_before.is_empty() and signf(row.omega) != signf(_turn_before.omega):
		var side := int(signf(_turn_before.omega))
		var fraction := absf(_turn_before.omega) / (absf(_turn_before.omega) + absf(row.omega))
		var theta := lerpf(_turn_before.angle, row.angle, fraction)
		if side != _peak_side and side*theta >= deg_to_rad(0.2):
			var peak_time := lerpf(_turn_before.t, row.t, fraction)
			if _peak_by_side.has(side):
				var prior: float = _peak_by_side[side]
				period = {"first":prior, "second":peak_time, "seconds":peak_time-prior,
					"model":TAU*sqrt(float(_held.rope)/_gravity), "rope":_held.rope,
					"side":side, "angle_deg":rad_to_deg(_segment_swing)}
			_peak_by_side[side] = peak_time
			_peak_side = side
	_turn_before = row

func sample_at(seconds: float) -> Dictionary:
	if samples.is_empty(): return {}
	var low := 0
	var high := samples.size()-1
	while low < high:
		var middle := (low+high) >> 1
		if samples[middle].t < seconds: low = middle+1
		else: high = middle
	var nearest := samples[low]
	if low > 0 and absf(seconds-samples[low-1].t) < absf(seconds-nearest.t): nearest = samples[low-1]
	if absf(seconds-_last.t) < absf(seconds-nearest.t): nearest = _last
	for exact: Dictionary in [brake, max_swing, settled]:
		if not exact.is_empty() and absf(seconds-exact.t) < absf(seconds-nearest.t): nearest = exact
	return nearest

func review_points() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	if samples.is_empty(): return points
	points.append({"id":"begin", "label":"开工", "time":samples[0].t})
	if _last.t == samples[0].t: return points
	if not brake.is_empty():
		points.append({"id":"brake", "label":"车停、箱在走", "time":brake.time})
	elif not max_swing.is_empty() and absf(max_swing.offset) > 0.03:
		points.append({"id":"swing", "label":"最偏的一刻", "time":max_swing.t})
	if not first_touch.is_empty():
		points.append({"id":"touch", "label":"第一次着板", "time":first_touch.time})
	if not period.is_empty():
		points.append({"id":"peak1", "label":"第一个同侧峰", "time":period.first})
		points.append({"id":"peak2", "label":"再回到同侧", "time":period.second})
	points.append({"id":"end", "label":"落稳" if not settled.is_empty() else "最近一刻", "time":_last.t})
	points.sort_custom(func(a:Dictionary,b:Dictionary) -> bool: return a.time < b.time)
	return points

func _direction(value: float) -> String:
	return "右" if value >= 0 else "左"

func _surface(touch: Dictionary) -> String:
	return str({"ship":"船面", "truck":"汽车平板", "shore":"码头面"}.get(touch.get("surface",""), "台面"))

func _where(offset: float) -> String:
	return "就在铅垂线下" if absf(offset)<0.01 else "在铅垂线%s方 %.2f m" % [_direction(offset),absf(offset)]

func brake_line() -> String:
	if brake.is_empty(): return ""
	return "%.2f s，小车停在 %.2f m。箱心%s，仍向%s走 %.2f m/s。" % [
		brake.time,brake.x,_where(brake.offset),_direction(brake.speed),absf(brake.speed)]

func touch_line() -> String:
	if first_touch.is_empty(): return ""
	return "%.2f s 第一次着%s，箱心 x＝%.2f m，%s。触板前水平速度 %+.2f m/s，竖直速度 %+.2f m/s。" % [
		first_touch.time,_surface(first_touch),first_touch.x,"已落进卸位标记" if first_touch.target else "还在工单卸位之外",first_touch.vx,first_touch.vy]

func after_brake_line() -> String:
	if brake.is_empty() or after_brake.is_empty() or after_brake.t-brake.time < 0.10: return ""
	var shift: float = after_brake.box_x-brake.box_x
	if absf(after_brake.x-brake.x)<0.005 and absf(shift)>=0.01:
		return "停后 %.2f s，小车位置没变，箱心向%s移了 %.2f m。" % [
			after_brake.t-brake.time,_direction(shift),absf(shift)]
	return "停后 %.2f s，小车横移 %+.2f m，箱心横移 %+.2f m。" % [
		after_brake.t-brake.time,after_brake.x-brake.x,shift]

func takeaway() -> String:
	if not brake.is_empty():
		return "刹车停住了小车，箱子凭惯性还往%s走。绳子一斜，重力会拉它回摆。" % _direction(brake.speed)
	if not first_touch.is_empty() and absf(first_touch.vx)<0.10:
		return "第一次着板时箱子横向已很慢。下次仍可提早收速，等箱心靠近卸位再落绳。"
	if not first_touch.is_empty():
		return "箱子碰到台面时还带着横向速度。下次可分段收速，等箱心横移变慢再下放。"
	return "看小车线和箱心线各自怎么走。车停后先看箱子，留一段位置给它减速。"

func period_line() -> String:
	if period.is_empty(): return ""
	return "固定 %.2f m 绳长时，两次%s侧峰隔 %.2f s。小角近似 T≈2π√(L/g) 给出 %.2f s，本段最大摆角 %.1f°。" % [
		period.rope,_direction(period.side),period.seconds,period.model,period.angle_deg]

func brief(_rig = null) -> String:
	if not brake.is_empty(): return brake_line()
	if not first_touch.is_empty(): return touch_line()
	if not max_swing.is_empty():
		return "%.2f s，悬箱最远偏离小车铅垂线 %.2f m。" % [max_swing.t,absf(max_swing.offset)]
	return "小车与箱心的横向位置从开工开始同表记录。"

func make_note(rig) -> Dictionary:
	if rig != null and (_last.is_empty() or rig.elapsed > float(_last.t)): observe(rig,0.0)
	if _last.is_empty():
		return {"title":"岸桥吊装回看", "observation":"尚无本吊的采样记录。", "prediction":"尚未记录工单卸位。",
			"result":"着板与落稳都没有观测记录。", "principle":"开工后可把小车与箱心的同一时刻位置配对。",
			"boundary":"判断依赖实际吊装轨迹。", "resolved":false}
	var measured := brake_line()
	if measured.is_empty():
		var first: Dictionary = samples[0]
		measured = "小车从 %.2f m 到 %.2f m，箱心从 %.2f m 到 %.2f m。" % [first.x,_last.x,first.box_x,_last.box_x]
	if not after_brake_line().is_empty(): measured += " " + after_brake_line()
	if not max_swing.is_empty():
		measured += " 悬箱最大水平偏离 %.2f m。" % absf(max_swing.offset)
	var result := touch_line()
	if not settled.is_empty():
		result += " %.2f s 箱在目标落稳，箱心距卸位中心 %.2f m。" % [settled.t,absf(settled.box_x-target_x)]
	elif not first_touch.is_empty():
		result += " 截至 %.2f s，目标落稳仍待确认。" % _last.t
	else:
		result = "截至 %.2f s 已记录小车与箱心，尚无本吊首次着板事件。" % _last.get("t",0)
	if not period.is_empty(): measured += " " + period_line()
	var goal := _initial_goal if not _initial_goal.is_empty() else "开工时的卸位目标在 x＝%.2f m，台面高 %.2f m。" % [target_x,target_y]
	return {"title":"岸桥第 %d 吊%s" % [job_index+1," · 箱已落稳" if not settled.is_empty() else " · 操作回看"],
		"observation":measured, "prediction":goal, "result":result.strip_edges(),
		"principle":"小车刹住时，箱子会因惯性继续走。悬绳倾斜后，重力沿摆动方向的分量把箱子拉回铅垂线附近。下吊前可提早收速，车停后再看箱子往哪边走。",
		"boundary":"轨迹来自本吊的平面模型，水平向右与竖直向上为正。周期比较只取小车静止、绳长固定、悬箱经历两个同侧峰的一段。",
		"resolved":not settled.is_empty()}

func make_view() -> Control:
	var view := ReplayView.new()
	view.recording = self
	var initial_time: float = brake.get("time", first_touch.get("time", _last.get("t",0.0)))
	view.select_time(initial_time)
	return view
