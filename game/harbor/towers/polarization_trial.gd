extends RefCounted

const LogModel := preload("res://harbor/towers/pair_log.gd")
const N := 64
const MINT := Color("#9fe3c7")
const GOLD := Color("#ffd08c")
const LIGHT := Color("#eef3e4")
var host
var angle := 0
var batches: Array[Dictionary] = []
var collecting_same := true
var _previous_page := ""
var _previous_last := Vector3i.ZERO
var _previous_status := ""
var _sampling := false
var _paced := 0.0

func open() -> void:
	_previous_page = host.phase
	_previous_last = host.last
	_previous_status = host.status
	host._sweep = -1
	host.phase = "pair_compare"
	host.last.x = -1
	batches.clear()
	angle = 0
	_sampling = false
	_show_choices()

func _return() -> void:
	_sampling = false
	if _previous_page == "quantum":
		host._enter_quantum()
	else:
		host._classic_tools(false)
	host.last = _previous_last
	host.status = _previous_status
	host.set_hint("两塔的四种来信继续值班。灯窗小试只固定了一组角度，75% 经典界限要合看四班。")

func _transfer_angle() -> int:
	return 3 if batches[1].angle == 2 else 1

func _show_choices() -> void:
	match batches.size():
		0:
			host.set_tools("让两本灯志对上号", "先让两边读头朝同一方向，用同一种理想光子源发 64 对。先看各自亮几次，再把同一对接起来看。")
			host.add_action("两头平行，放 64 对", _start.bind(0), true)
			host.set_hint("每一列是同一对光子的两条记录。实心灯亮，空心灯暗。")
		1:
			host.set_tools("只转月塔，再放一批", "昼塔和光源留在原处。选月塔的新方向，让第二批独立的 64 对光子从同一个源通过。")
			host.add_action("月塔转到 45°，放 64 对", _start.bind(2), true)
			host.add_action("月塔转到 90°，放 64 对", _start.bind(4))
			host.set_hint("看两行亮灯次数，再看两行上下恰好一样的列有多少。")
		2:
			var first = batches[0].log
			var turned = batches[1].log
			host.set_tools("下一箱接哪种灯？", "只转月塔后，64 对里同号从 %d 对变成 %d 对。下一批把月塔调到 %s，让你选的舱门接货。" % [
				first.matched[0], turned.matched[0], LogModel.angle_name(_transfer_angle())])
			host.add_action("开同号舱，接下一批", _dispatch.bind(true), true)
			host.add_action("开异号舱，接下一批", _dispatch.bind(false))
			host.set_hint("平行时一对光子的读数一致，垂直时相反。单看一扇窗，亮和暗仍各有一半机会。")
		3:
			var target = batches[2].log
			var caught: int = target.matched[0] if collecting_same else N - target.matched[0]
			host.set_tools("这箱光子已回港", "你开了%s舱。两轴相差 %s，这批实际收到 %d / %d 对。用相同角度再发一批，计数可能变化。" % [
				"同号" if collecting_same else "异号", LogModel.angle_name(angle), caught, N])
			host.add_action("原角度原舱门，再发 64 对", _repeat, true)
			host.add_action("回到平行，试另一个角度", _restart)
			host.add_readout("这里数一组固定角度的同号次数。经典 75% 上限要另看四班平均过闸率。")
			host.set_hint("动的是月塔读头，变化最明显的是两塔同号的比例。每个塔自己的下一盏灯仍要等光子到了才知道。")
	host.add_action("回到双塔值班", _return)

func _restart() -> void:
	batches.clear()
	angle = 0
	host.last.x = -1
	_show_choices()

func _repeat() -> void:
	batches.pop_back()
	_start(_transfer_angle())

func _dispatch(same: bool) -> void:
	collecting_same = same
	_start(_transfer_angle())

func _start(ticks: int) -> void:
	if _sampling: return
	angle = ticks
	batches.append({"angle":ticks, "settings":PackedInt32Array([0,0,ticks,ticks]),
		"log":LogModel.new(), "recent":PackedInt32Array()})
	_sampling = true
	_paced = 0
	host.set_tools("两塔各自收光", "昼塔 0°，月塔 %s。日志正逐对归档，灯色来自本批模拟。" % LogModel.angle_name(ticks))
	host.play_cue("echo")

func tick(delta: float) -> void:
	if not _sampling: return
	var row: Dictionary = batches.back()
	var logbook = row.log
	_paced += delta * 74.0
	var take := mini(floori(_paced), N - int(logbook.count))
	_paced -= take
	for i in take:
		var pair: Vector3i = logbook.sample_setting(host.rng, row.settings, 0.0, 0)
		host.last = pair
		row.recent.append(2 * pair.y + pair.z)
		if row.recent.size() > 12:
			row.recent.remove_at(0)
	if take > 0:
		host._harbor.arrival()
	if logbook.count >= N:
		_sampling = false
		_show_choices()
		if batches.size() == 3:
			_save_receipt()

func _save_receipt() -> void:
	var initial = batches[0].log
	var changed = batches[1].log
	var trial = batches[2].log
	host.complete({"title":"只转月塔的灯窗试航",
		"observation":"月塔从 0° 转到 %s，昼塔两批分别亮 %d、%d 次，月塔亮 %d、%d 次。每批 64 对，同号从 %d 对变为 %d 对。" % [
			LogModel.angle_name(batches[1].angle),initial.bright[0],changed.bright[0],initial.bright[1],changed.bright[1],initial.matched[0],changed.matched[0]],
		"prediction":"下一批角差 %s，我先打开%s舱。" % [LogModel.angle_name(angle),"同号" if collecting_same else "异号"],
		"result":"两本灯志合表，新一批实际有 %d 对同号、%d 对异号。" % [trial.matched[0],N-trial.matched[0]],
		"principle":"只转一支读头会改变两塔一起亮或一起暗的机会。单看任一塔，每次亮暗仍各有一半机会。",
		"boundary":"理想 Φ⁺ 偏振对的独立模拟，每批 64 对。此处固定角度，经典 75% 界限属于四种来信等概率的过闸游戏。",
		"resolved":false})

func draw_notes(view: Control) -> void:
	view.draw_rect(Rect2(0,262,760,190),Color("#102b34"))
	view._write(Vector2(20,287),"把同一对光子上下对齐",19,LIGHT)
	for column in 2:
		var index := maxi(0, batches.size()-2) + column
		var x := 18.0 + 368.0 * column
		view.draw_rect(Rect2(x,299,356,124),Color("#193a43"))
		if index >= batches.size():
			view._write(Vector2(x+15,359),"下一批的两本灯志" if column else "等第一批光子",17,Color("#9fb9b7"))
			continue
		var row := batches[index]
		var logbook = row.log
		view._write(Vector2(x+12,320),"第 %d 批　角差 %s" % [index+1, LogModel.angle_name(row.angle)],16,LIGHT)
		for side in 2:
			var yy := 342.0+24.0*side
			var tint := GOLD if side==0 else MINT
			view._write(Vector2(x+12,yy+4),"%s亮 %d/%d" % ["昼" if side==0 else "月",logbook.bright[side],logbook.count],14,tint)
			for k in row.recent.size():
				var both: int = row.recent[k]
				var bit := (both>>1) if side==0 else (both&1)
				view.draw_circle(Vector2(x+131+17*k,yy),5.1,tint,bool(bit),-1.0 if bit else 1.1,true)
		view._write(Vector2(x+12,404),"两塔同号　%d / %d 对" % [logbook.matched[0],logbook.count],19,MINT)
	view._write(Vector2(20,444),"灯窗显示最近 12 对，数字统计整批。每批都从同一类型的源重新取样。",14,Color("#b3cbc6"))
