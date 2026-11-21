extends RefCounted

static func _key(action: StringName, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func _button(action: StringName, index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func _axis(action: StringName, axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

static func install() -> void:
	var bindings := {
		"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT],
		"climb": [KEY_W, KEY_UP], "dive": [KEY_S, KEY_DOWN],
		"fold": [KEY_SPACE], "survey": [KEY_E], "tune": [KEY_Q], "open_log": [KEY_TAB],
		"flight_pause": [KEY_ESCAPE], "full_screen": [KEY_F11],
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.18)
		for code: Key in bindings[action]:
			_key(action, code)
	_axis(&"steer_left", JOY_AXIS_LEFT_X, -1)
	_axis(&"steer_right", JOY_AXIS_LEFT_X, 1)
	_axis(&"climb", JOY_AXIS_LEFT_Y, -1)
	_axis(&"dive", JOY_AXIS_LEFT_Y, 1)
	_button(&"steer_left", JOY_BUTTON_DPAD_LEFT)
	_button(&"steer_right", JOY_BUTTON_DPAD_RIGHT)
	_button(&"climb", JOY_BUTTON_DPAD_UP)
	_button(&"dive", JOY_BUTTON_DPAD_DOWN)
	_button(&"fold", JOY_BUTTON_A)
	_axis(&"fold", JOY_AXIS_TRIGGER_RIGHT, 1)
	_button(&"survey", JOY_BUTTON_X)
	_button(&"tune", JOY_BUTTON_LEFT_SHOULDER)
	_button(&"flight_pause", JOY_BUTTON_START)
	_button(&"open_log", JOY_BUTTON_Y)
	_button(&"ui_accept", JOY_BUTTON_A)
	_button(&"ui_cancel", JOY_BUTTON_B)
	_button(&"ui_up", JOY_BUTTON_DPAD_UP)
	_button(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_button(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
