extends ColorRect

signal closed
signal marked(position_m: float, front_share: float)

const UI := preload("res://ui/skin.gd")
const Truck := preload("res://harbor/loading/load_model.gd")

var share := HSlider.new()
var manifest: Label
var capacity: Label
var reading: Label
var equation: Label
var apply_mark: Button
var close_button: Button
var model: Truck
var box_index := 0
var weight := 0.0
var mark_x := 0.0

func _ready() -> void:
	color = Color("#091d24cb")
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", UI.box(Color("#15363d"), Color("#ac9580"), 7, 27, 17))
	add_child(paper)
	UI.place(paper, Vector4(.5,.5,.5,.5),Vector4(-390,-215,390,215))
	var column := UI.column(9)
	paper.add_child(column)
	var heading := UI.row()
	column.add_child(heading)
	var title := UI.label("配载尺", 29, UI.AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	close_button = UI.button("收起", func() -> void: closed.emit())
	heading.add_child(close_button)
	manifest = UI.label("", 19, UI.INK, true)
	column.add_child(manifest)
	capacity = UI.label("", 17, UI.SOFT, true)
	column.add_child(capacity)
	column.add_child(HSeparator.new())
	column.add_child(UI.label("这箱货打算让前轴分担多少？", 20, UI.INK))
	share.step = .1
	share.custom_minimum_size.y = 27
	column.add_child(share)
	share.value_changed.connect(func(_value: float) -> void: _calculate())
	reading = UI.label("", 19, UI.MINT, true)
	column.add_child(reading)
	equation = UI.label("", 17, UI.SOFT, true)
	column.add_child(equation)
	var actions := UI.row()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	apply_mark = UI.button("划到车板", func() -> void: marked.emit(mark_x, share.value),true)
	actions.add_child(apply_mark)
	hide()

func open_for(truck: Truck, index: int, current_x: float) -> void:
	model = truck
	box_index = index
	weight = truck.known_weight(index)
	manifest.text = "%s　·　轴距 %.1f m　·　后轴在 0 m，前轴在 %.1f m。" % [truck.cargo[index].label, truck.wheelbase, truck.wheelbase]
	var rear := truck.rear_empty
	var front := truck.front_empty
	var known := true
	for other in truck.cargo.size():
		if other == index or not truck.cargo[other].on_bed: continue
		var w := truck.known_weight(other)
		if w < 0:
			known = false
			break
		var forward := w * float(truck.cargo[other].x) / truck.wheelbase
		rear += w-forward
		front += forward
	if known:
		capacity.text = "扣除空车和其余已放的货，还能给后轴 %.2f kN、前轴 %.2f kN。" % [truck.rear_limit - rear,truck.front_limit - front]
	else:
		capacity.text = "板上还有一件未称的货。可重新吊起读秤，再核对两轴余量。"
	share.editable = weight > 0
	share.max_value = maxf(.1, weight)
	share.set_value_no_signal(weight*current_x/truck.wheelbase if weight>0 else 0.0)
	_calculate()
	show()
	if share.editable: share.grab_focus()
	else: close_button.grab_focus()

func _calculate() -> void:
	if model == null: return
	if weight <= 0:
		reading.text = "货单缺重量。吊起这只箱，按 E 读吊秤。"
		equation.text = "货越靠车头，前轴分担越多。在两轴正中落箱，前后各分一半。"
		apply_mark.disabled = true
		return
	var calculated := model.wheelbase * share.value / weight
	mark_x = snappedf(calculated, .1)
	reading.text = "这箱重 %.1f kN。前轴分 %.1f kN，余下 %.1f kN 由后轴分担。" % [weight,share.value,weight-share.value]
	equation.text = "绕后轴取力矩，前轴分担 × 轴距 ＝ 箱重 × 落点距后轴。\n%.1f m × %.1f ÷ %.1f ＝ %.2f m，车板按 0.1 m 划线，落在 %.1f m。" % [model.wheelbase,share.value,weight,calculated,mark_x]
	apply_mark.disabled = false
