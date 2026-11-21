extends RefCounted

# Positions are measured forward from the rear axle, in metres. Loads are kN.
const EDGE_MARGIN := 0.10
const EPSILON := 0.000001

var order_index := 0
var wheelbase := 4.0
var rear_empty := 18.0
var front_empty := 16.0
var rear_limit := 22.0
var front_limit := 25.0
var cargo: Array[Dictionary] = []
var held_index := -1
var last_error := ""


func _init() -> void:
	reset_order(0)


func reset_order(index: int) -> void:
	order_index = maxi(index,0)
	held_index = -1
	last_error = ""
	cargo = []
	match order_index % 4:
		0:
			_set_truck(4.0,18.0,16.0,22.0,25.0)
			_add_box("泵体",12.0,1.0,true)
		1:
			_set_truck(5.0,16.0,20.0,28.0,26.0)
			_add_box("泵体",12.0,1.0,true)
			_add_box("工具箱",5.0,0.8,false)
		2:
			_set_truck(4.5,18.0,15.0,28.0,20.0)
			_add_box("卷扬电机",13.0,1.05,true)
		3:
			_set_truck(5.0,15.0,17.0,22.0,29.0)
			_add_box("阀组",13.0,1.05,true)
			_add_box("零件箱",4.0,0.8,false)


func _set_truck(length_m: float, rear_base: float, front_base: float, rear_max: float, front_max: float) -> void:
	wheelbase = length_m
	rear_empty = rear_base
	front_empty = front_base
	rear_limit = rear_max
	front_limit = front_max


func _add_box(label: String, weight: float, width: float, marked: bool) -> void:
	cargo.append({"label":label,"weight":weight,"width":width,"marked":marked,"weighed":false,"x":-1.0,"on_bed":false})


func _valid_box(index: int) -> bool:
	return index>=0 and index<cargo.size()


func _reject(message: String) -> bool:
	last_error = message
	return false


func pickup(index: int) -> bool:
	if not _valid_box(index):
		return _reject("工单里没有这件货。")
	if held_index>=0 and held_index!=index:
		return _reject("吊钩上还有%s，先把它放下。" % cargo[held_index].label)
	cargo[index].on_bed = false
	held_index = index
	last_error = ""
	return true


func mark_weighed(index: int) -> bool:
	if not _valid_box(index) or held_index!=index:
		return _reject("先把这件货吊离支承面，让吊秤承受它的全部重量。")
	cargo[index].weighed = true
	last_error = ""
	return true


func known_weight(index: int) -> float:
	if not _valid_box(index):
		return -1.0
	var box := cargo[index]
	return float(box.weight) if box.marked or box.weighed else -1.0


func sling_load() -> float:
	return float(cargo[held_index].weight) if _valid_box(held_index) else 0.0


func placement_error(index: int, x: float) -> String:
	if not _valid_box(index):
		return "工单里没有这件货。"
	if not is_finite(x):
		return "请选择一个车板刻度。"
	var half_width := 0.5*float(cargo[index].width)
	if x-half_width<EDGE_MARGIN-EPSILON or x+half_width>wheelbase-EDGE_MARGIN+EPSILON:
		return "箱底越过留边。箱子两端都要落在离床沿 0.10 m 的线内。"
	for other in range(cargo.size()):
		var parked := cargo[other]
		if other==index or not parked.on_bed: continue
		var spacing := half_width+float(parked.width)*0.5
		if absf(x-float(parked.x))<spacing-EPSILON:
			return "会压住板上的%s，请给两个箱底各留一段车板。" % parked.label
	return ""


func land(index: int, x: float) -> bool:
	if not _valid_box(index) or held_index!=index:
		return _reject("先吊起要放的那件货。")
	var issue := placement_error(index,x)
	if not issue.is_empty():
		return _reject(issue)
	var box := cargo[index]
	box.x = x
	box.on_bed = true
	held_index = -1
	last_error = ""
	return true


func wheel_loads() -> Vector2:
	var front_added := 0.0
	var loaded_weight := 0.0
	for box in cargo:
		if not box.on_bed: continue
		var weight := float(box.weight)
		# Taking moments about the rear axle gives the front reaction.
		front_added += weight*float(box.x)/wheelbase
		loaded_weight += weight
	return Vector2(rear_empty+loaded_weight-front_added, front_empty+front_added)


func dispatch_report() -> Dictionary:
	var reactions := wheel_loads()
	var rear_over := maxf(0.0,reactions.x-rear_limit)
	var front_over := maxf(0.0,reactions.y-front_limit)
	if rear_over<EPSILON: rear_over=0
	if front_over<EPSILON: front_over=0
	var loaded := 0
	for box in cargo:
		if box.on_bed: loaded+=1
	var code := "ready"
	var reasons: Array[String] = []
	if rear_over>0:
		code = "rear"
		reasons.append("后轴超出 %.2f kN" % rear_over)
	if front_over>0:
		code = "both" if rear_over>0 else "front"
		reasons.append("前轴超出 %.2f kN" % front_over)
	if loaded<cargo.size():
		code = "incomplete"
		reasons.append("还有 %d 件货没落到车上" % (cargo.size()-loaded))
	var ready := reasons.is_empty()
	var reason := "货已齐，两轴都在限载以内。" if ready else "，".join(reasons)+"。"
	return {
		"ok":ready, "ready":ready, "code":code, "reason":reason,
		"rear":float(reactions.x), "front":float(reactions.y),
		"rear_over":rear_over, "front_over":front_over, "loaded":loaded, "required":cargo.size(),
		"cargo_weight":float(reactions.x+reactions.y)-rear_empty-front_empty,
		"moment":(float(reactions.y)-front_empty)*wheelbase
	}
