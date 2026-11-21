extends Control

const FlightUI := preload("res://ui/skin.gd")
var heading: Label
var gates: Label
var route_note: Label
var speed: Label
var height_label: Label
var loot: Label
var task: Label
var hint: Label
var toast: Label
var survey_panel: PanelContainer
var survey_label: Label
var progress := ProgressBar.new()
var toast_time := 0.0
var hint_time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _plate()
	FlightUI.place(top, Vector4(0, 0, 0, 0), Vector4(22, 18, 340, 135))
	var column := FlightUI.column(4)
	top.add_child(column)
	heading = FlightUI.label("", 22)
	column.add_child(heading)
	gates = FlightUI.label("", 16, FlightUI.SOFT)
	column.add_child(gates)
	route_note = FlightUI.label("", 15, FlightUI.MINT)
	column.add_child(route_note)
	progress.show_percentage = false
	progress.custom_minimum_size.y = 4
	progress.max_value = 1
	column.add_child(progress)
	var stats := _plate()
	FlightUI.place(stats, Vector4(1, 0, 1, 0), Vector4(-250, 18, -22, 104))
	var metrics := FlightUI.column(2)
	stats.add_child(metrics)
	speed = FlightUI.label("", 24, FlightUI.AMBER)
	height_label = FlightUI.label("", 18)
	metrics.add_child(speed)
	metrics.add_child(height_label)
	var bottom := _plate()
	FlightUI.place(bottom, Vector4(0, 1, 0, 1), Vector4(22, -90, 342, -18))
	var harvest := FlightUI.column(1)
	bottom.add_child(harvest)
	loot = FlightUI.label("", 20, FlightUI.MINT)
	task = FlightUI.label("", 15, FlightUI.SOFT)
	harvest.add_child(loot)
	harvest.add_child(task)
	toast = FlightUI.label("", 25)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 7)
	toast.add_theme_color_override("font_outline_color", Color("#17323bcf"))
	add_child(toast)
	FlightUI.place(toast, Vector4(0.12, 0, 0.88, 0), Vector4(0, 125, 0, 173))
	survey_panel = _plate()
	FlightUI.place(survey_panel, Vector4(0.5, 1, 0.5, 1), Vector4(-388, -156, 388, -99))
	survey_label = FlightUI.label("", 17, FlightUI.INK, true)
	survey_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survey_panel.add_child(survey_label)
	survey_panel.hide()
	hint = FlightUI.label("", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_constant_override("outline_size", 5)
	hint.add_theme_color_override("font_outline_color", FlightUI.DEEP)
	add_child(hint)
	FlightUI.place(hint, Vector4(0.35, 1, 1, 1), Vector4(0, -73, -24, -14))

func _plate() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", FlightUI.box(Color("#0c2732e6"), Color("#899c9a77"), 9, 14, 8))
	add_child(p)
	return p

func start_leg(leg: int, name_of_island: String, goal: String) -> void:
	heading.text = "%02d / 03　%s" % [leg + 1, name_of_island]
	task.text = goal
	hint_time = 13 if leg == 0 else 4
	toast_time = 0
	toast.text = ""
	gates.text = "穿过航门，沿风向前"
	route_note.text = "带一枚风种抵达港灯"
	progress.value = 0
	survey_panel.hide()
	show()

func instrument(text: String) -> void:
	survey_label.text = text
	survey_panel.visible = not text.is_empty()

func telemetry(v: Dictionary, contract_text: String) -> void:
	speed.text = "空速　%.1f m/s" % float(v.get("speed", 0))
	height_label.text = "高度　%.0f m" % float(v.get("height", 0))
	var wind_state := "乘上热流" if v.get("in_thermal", false) else ("收翼" if v.get("folded", false) else "展翼")
	gates.text = "%s　·　航门 %d / %d" % [wind_state, v.get("gates", 0), v.get("total_gates", 0)]
	route_note.text = "归港需 1 风种　·　%s %s %.0f m" % [v.get("guide", ""), v.get("marker", "航门"), v.get("marker_m", 0.0)]
	loot.text = "风种 %d　·　连门 %d" % [v.get("seeds", 0), v.get("chain", 0)]
	if v.get("companion", false):
		loot.text += "　·　" + str(v.get("companion_name", ""))
	task.text = contract_text
	progress.value = clampf(float(v.get("progress", 0)), 0, 1)

func flash(message: String, kind: String) -> void:
	if message.is_empty():
		return
	toast.text = message
	toast.add_theme_color_override("font_color", FlightUI.AMBER if kind in ["chain", "seed", "echo"] else FlightUI.INK)
	toast.modulate.a = 1
	toast_time = 2.4

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	toast_time = maxf(0, toast_time - delta)
	toast.modulate.a = clampf(toast_time * 2.5, 0, 1)
	hint_time = maxf(0, hint_time - delta)
	var pad := not Input.get_connected_joypads().is_empty()
	if hint_time > 0:
		hint.text = "左摇杆　转向 / 俯仰　　RT 或 A　收翼\nX　测距浮标　　菜单键　暂停" if pad else "A / D 转向　 W 拉升　 S 俯冲　 空格收翼\nE 测距浮标　 Tab 手册　 Esc 暂停"
	else:
		hint.text = "X 测距　·　菜单键 暂停" if pad else "E 测距　·　Esc 暂停"
