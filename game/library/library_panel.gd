extends Control

signal closed

const CATALOG: JSON = preload("res://library/course_library.json")
const BACKGROUND := Color("#071a1c")
const SURFACE := Color("#10292c")
const ACTIVE := Color("#234445")
const BORDER := Color("#385456")
const INK := Color("#f6f0df")
const MUTED := Color("#b5c7bd")
const ACCENT := Color("#91e3c4")

var _search := LineEdit.new()
var _field := OptionButton.new()
var _list := ItemList.new()
var _reader := RichTextLabel.new()
var _back := Button.new()
var _count := Label.new()
var _margin := MarginContainer.new()
var _split := BoxContainer.new()
var _fields: Dictionary = {}
var _entries: Dictionary = {}
var _search_text: Dictionary = {}
var _relevant: Array[String] = []
var _active_key: String = ""
var _previous_focus: WeakRef


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_margin.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := Label.new()
	title.text = "物理手册"
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_back.text = "返回  Esc / B"
	_back.accessibility_name = "关闭物理手册"
	_back.pressed.connect(close_library)
	title_row.add_child(_back)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	column.add_child(filters)
	_search.placeholder_text = "搜索课名、概念或公式"
	_search.accessibility_name = "搜索手册"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_value: String) -> void: _refresh_results())
	_search.text_submitted.connect(func(_value: String) -> void: _focus_list())
	filters.add_child(_search)
	_field.accessibility_name = "筛选学习领域"
	_field.fit_to_longest_item = false
	_field.clip_text = true
	_field.item_selected.connect(func(_index: int) -> void: _refresh_results())
	filters.add_child(_field)

	_count.add_theme_color_override("font_color", MUTED)
	_count.add_theme_font_size_override("font_size", 15)
	column.add_child(_count)
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("separation", 14)
	column.add_child(_split)
	_list.accessibility_name = "课程目录"
	_list.allow_search = false
	_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_open_entry)
	_list.item_activated.connect(func(_index: int) -> void: _reader.grab_focus())
	_list.resized.connect(func() -> void: _list.fixed_column_width = maxi(40, int(_list.size.x) - 36))
	_split.add_child(_list)

	_reader.accessibility_name = "课程正文"
	_reader.focus_mode = Control.FOCUS_ALL
	_reader.selection_enabled = true
	_reader.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reader.size_flags_stretch_ratio = 2.1
	_split.add_child(_reader)
	var hint := Label.new()
	hint.text = "↑ ↓ 选课或翻阅　　→ 阅读　　← 目录"
	hint.add_theme_color_override("font_color", MUTED)
	hint.add_theme_font_size_override("font_size", 14)
	column.add_child(hint)

	var navigation: Array[Control] = [_search, _field, _list, _reader, _back]
	for i in navigation.size():
		var control := navigation[i]
		control.focus_next = control.get_path_to(navigation[(i + 1) % navigation.size()])
		control.focus_previous = control.get_path_to(navigation[posmod(i - 1, navigation.size())])
	_field.focus_neighbor_bottom = _field.get_path_to(_list)
	_search.focus_neighbor_bottom = _search.get_path_to(_list)
	_list.focus_neighbor_right = _list.get_path_to(_reader)
	_reader.focus_neighbor_left = _reader.get_path_to(_list)
	resized.connect(_layout)
	_layout()
	set_process(false)


func show_library(relevant_keys: Array = [], related_caption: String = "本段飞行相关") -> void:
	if not is_node_ready():
		ready.connect(show_library.bind(relevant_keys.duplicate(), related_caption), CONNECT_ONE_SHOT)
		return
	if _entries.is_empty():
		_index_catalog()
	if not visible:
		var owner := get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(owner) if owner != null else null
	_relevant.clear()
	for key in relevant_keys:
		if _entries.has(key) and not _relevant.has(key):
			_relevant.append(key)
	_field.clear()
	if not _relevant.is_empty():
		_add_filter(related_caption, "relevant")
		_active_key = _relevant[0]
	_add_filter("全部领域", "")
	for id in _fields:
		_add_filter(_fields[id], id)
	_search.clear()
	_field.select(0)
	show()
	_refresh_results()
	_focus_list()
	set_process(true)


func close_library() -> void:
	if not visible:
		return
	hide()
	set_process(false)
	var owner: Control = _previous_focus.get_ref() as Control if _previous_focus != null else null
	if is_instance_valid(owner) and owner.is_visible_in_tree():
		owner.grab_focus()
	closed.emit()


func _index_catalog() -> void:
	for field_data in CATALOG.data["fields"]:
		_fields[field_data["id"]] = field_data["name"]
	for entry in CATALOG.data["entries"]:
		var key: String = entry["key"]
		_entries[key] = entry
		var fragments := PackedStringArray([entry["title"], key, entry["stage"], _fields[entry["field"]]])
		for section in entry["sections"]:
			fragments.append(section[1])
		_search_text[key] = "\n".join(fragments).to_lower()


func _add_filter(caption: String, id: String) -> void:
	_field.add_item(caption)
	_field.set_item_metadata(_field.item_count - 1, id)


func _refresh_results() -> void:
	if _field.selected < 0:
		return
	var scope: String = _field.get_selected_metadata()
	var words := _search.text.to_lower().strip_edges().split(" ", false)
	var keys: Array = _relevant if scope == "relevant" else _entries.keys()
	_list.clear()
	var selection := 0
	for key in keys:
		var entry: Dictionary = _entries[key]
		if scope != "" and scope != "relevant" and entry["field"] != scope:
			continue
		var matched := true
		for word in words:
			if not _search_text[key].contains(word):
				matched = false
				break
		if not matched:
			continue
		var row := _list.add_item(entry["title"])
		_list.set_item_metadata(row, key)
		_list.set_item_tooltip(row, "%s · %s\n%s" % [_fields[entry["field"]], entry["stage"], entry["title"]])
		if key == _active_key:
			selection = row
	_count.text = "%s　·　%d 项" % [_field.get_item_text(_field.selected), _list.item_count]
	if _list.item_count == 0:
		_reader.clear()
		_reader.add_text("没有匹配的条目。可以缩短搜索词或换一个领域。")
		return
	_list.select(selection)
	_list.ensure_current_is_visible()
	_open_entry(selection)


func _open_entry(row: int) -> void:
	_active_key = _list.get_item_metadata(row)
	var entry: Dictionary = _entries[_active_key]
	_reader.clear()
	_text("%s  /  %s\n" % [_fields[entry["field"]], entry["stage"]], ACCENT, 15)
	_text("%s\n\n" % entry["title"], INK, 26)
	for section in entry["sections"]:
		_text("%s\n" % section[0], ACCENT, 16)
		_text("%s\n\n" % section[1], INK, 18)
	_reader.scroll_to_line(0)


func _text(content: String, color: Color, font_size: int) -> void:
	_reader.push_color(color)
	_reader.push_font_size(font_size)
	_reader.add_text(content)
	_reader.pop()
	_reader.pop()


func _focus_list() -> void:
	if _list.item_count:
		_list.grab_focus()
	else:
		_search.grab_focus()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var owner := get_viewport().gui_get_focus_owner()
	var keyboard_back: bool = event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_B and owner != _search
	var pad_back: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
	if event.is_action_pressed("ui_cancel") or keyboard_back or pad_back:
		get_viewport().set_input_as_handled()
		if _field.get_popup().visible:
			_field.get_popup().hide()
		else:
			close_library()
		return
	if owner == _reader:
		if event.is_action_pressed("ui_left"):
			_focus_list()
		elif event.is_action_pressed("ui_page_up", true):
			_reader.get_v_scroll_bar().value -= _reader.size.y * 0.8
		elif event.is_action_pressed("ui_page_down", true):
			_reader.get_v_scroll_bar().value += _reader.size.y * 0.8
		elif event.is_action_pressed("ui_down"):
			_reader.get_v_scroll_bar().value += 26
		elif event.is_action_pressed("ui_up"):
			_reader.get_v_scroll_bar().value -= 26
		else:
			return
	elif owner == _list and (event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept")):
		_reader.grab_focus()
	elif owner == _list and _list.item_count > 0 and event.is_action_pressed("ui_up") and _list.is_selected(0):
		_field.grab_focus()
	elif owner == _search and event.is_action_pressed("ui_down"):
		_focus_list()
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _reader.has_focus():
		var direction := Input.get_axis("ui_up", "ui_down")
		_reader.get_v_scroll_bar().value += direction * 320.0 * delta


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)


func _layout() -> void:
	var narrow := size.x < 720
	_split.vertical = narrow
	_list.custom_minimum_size = Vector2(0, 90) if narrow else Vector2(225, 0)
	_field.custom_minimum_size.x = 142 if narrow else 204
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 16 if narrow else 32)


func _make_theme() -> Theme:
	var style := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC",
			"Noto Sans CJK SC", "Source Han Sans SC", "WenQuanYi Micro Hei", "DejaVu Sans"])
	font.allow_system_fallback = true
	style.default_font = font
	style.default_font_size = 17
	var surface := _box(SURFACE, BORDER)
	var hover := _box(ACTIVE, BORDER)
	var focus := _box(Color.TRANSPARENT, ACCENT)
	focus.draw_center = false
	focus.set_border_width_all(2)
	for type in ["Button", "OptionButton", "LineEdit", "ItemList", "RichTextLabel"]:
		style.set_stylebox("normal" if type != "ItemList" else "panel", type, surface)
		style.set_stylebox("focus", type, focus)
		style.set_color("font_color", type, INK)
	style.set_color("font_color", "Label", INK)
	style.set_color("font_placeholder_color", "LineEdit", MUTED)
	for type in ["Button", "OptionButton"]:
		style.set_stylebox("hover", type, hover)
		style.set_stylebox("pressed", type, hover)
		style.set_color("font_hover_color", type, INK)
	style.set_stylebox("selected", "ItemList", hover)
	style.set_stylebox("selected_focus", "ItemList", hover)
	style.set_color("font_selected_color", "ItemList", ACCENT)
	style.set_constant("v_separation", "ItemList", 10)
	style.set_stylebox("panel", "PopupMenu", surface)
	style.set_stylebox("hover", "PopupMenu", hover)
	style.set_color("font_color", "PopupMenu", INK)
	style.set_constant("line_separation", "RichTextLabel", 4)
	return style


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
