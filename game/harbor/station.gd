extends Control

signal leave_requested
signal station_requested(key: String)
signal manual_requested
signal journal_requested
signal cue_requested(kind: String)
signal discovery(record: Dictionary)

const StationUI := preload("res://ui/skin.gd")

var tools_box: VBoxContainer
var stage: Control
var sounds_enabled := true
var _title: Label
var _objective: Label
var _tools_heading: Label
var _tools_detail: Label
var _hint: Label
var _scroll: ScrollContainer
var _journal: Button
var _primary_focus: Control
var _first_action: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if theme == null:
		theme = StationUI.theme()
	_build_layout()
	_begin()

func _build_layout() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#0c222b")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shell := StationUI.column(12)
	add_child(shell)
	StationUI.place(shell, Vector4(0, 0, 1, 1), Vector4(32, 21, -32, -17))
	var header := StationUI.row(17)
	shell.add_child(header)
	_title = StationUI.label("", 34, StationUI.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(StationUI.button("查课件", func() -> void: manual_requested.emit()))
	_journal = StationUI.button("航海日志", func() -> void: journal_requested.emit())
	header.add_child(_journal)
	header.add_child(StationUI.button("返回码头", func() -> void: leave_requested.emit()))
	_objective = StationUI.label("", 19, Color("#c7dcd7"), true)
	shell.add_child(_objective)
	var middle := StationUI.row(18)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(middle)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", StationUI.box(Color("#132e37"), Color("#507075"), 7, 2, 2))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_stretch_ratio = 2.17
	middle.add_child(frame)
	stage = Control.new()
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stage)
	var instrument := PanelContainer.new()
	instrument.add_theme_stylebox_override("panel", StationUI.box(Color("#17333c"), Color("#506c70"), 7, 18, 13))
	instrument.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(instrument)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	instrument.add_child(_scroll)
	var stack := StationUI.column(9)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(stack)
	_tools_heading = StationUI.label("", 23, StationUI.AMBER, true)
	stack.add_child(_tools_heading)
	_tools_detail = StationUI.label("", 17, StationUI.SOFT, true)
	stack.add_child(_tools_detail)
	tools_box = StationUI.column(7)
	stack.add_child(tools_box)
	_hint = StationUI.label("", 17, StationUI.MINT, true)
	_hint.custom_minimum_size.y = 48
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shell.add_child(_hint)

func _begin() -> void:
	pass

func handle_back() -> bool:
	return false

func set_scene(title: String, objective: String) -> void:
	_title.text = title
	_objective.text = objective

func bind_view(view: Control) -> void:
	stage.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_tools(heading: String, detail: String = "") -> void:
	_tools_heading.text = heading
	_tools_detail.text = detail
	_tools_detail.visible = not detail.is_empty()
	for child in tools_box.get_children():
		tools_box.remove_child(child)
		child.queue_free()
	_first_action = null
	_primary_focus = null
	_scroll.scroll_vertical = 0
	_focus_actions.call_deferred()

func add_action(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := StationUI.button(text, callback, primary)
	button.add_theme_font_size_override("font_size", 17)
	tools_box.add_child(button)
	if _first_action == null:
		_first_action = button
	if primary:
		_primary_focus = button
	return button

func add_readout(text: String) -> Label:
	var label := StationUI.label(text, 16, StationUI.INK, true)
	tools_box.add_child(label)
	return label

func set_hint(text: String) -> void:
	_hint.text = text

func play_cue(kind: String) -> void:
	if sounds_enabled:
		cue_requested.emit(kind)

func complete(record: Dictionary) -> void:
	discovery.emit(record.duplicate(true))

func _focus_actions() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or process_mode == Node.PROCESS_MODE_DISABLED:
		return
	for target in [_primary_focus, _first_action]:
		if is_instance_valid(target) and target.is_visible_in_tree() and not target.disabled:
			target.grab_focus()
			return
	for node in tools_box.find_children("*", "Control", true, false):
		if node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree():
			node.grab_focus()
			return
	_journal.grab_focus()
