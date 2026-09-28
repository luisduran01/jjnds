extends SceneTree

const InputSetup = preload("res://boxing/managers/input_setup.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TEST FAILED: " + message)

func has_ps3_button(action: StringName, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button and event.device == -1:
			return true
	return false

func _initialize() -> void:
	InputSetup.install()
	check(has_ps3_button(&"box_jab", JOY_BUTTON_X), "Square is available for jab on every controller device")
	check(has_ps3_button(&"box_cross", JOY_BUTTON_Y), "Triangle is available for cross on every controller device")
	check(has_ps3_button(&"box_left_hook", JOY_BUTTON_A), "Cross is available for left hook on every controller device")
	check(has_ps3_button(&"box_right_hook", JOY_BUTTON_B), "Circle is available for right hook on every controller device")
	check(has_ps3_button(&"box_guard", JOY_BUTTON_LEFT_SHOULDER), "L1 is available for guard on every controller device")
	check(has_ps3_button(&"box_body", JOY_BUTTON_RIGHT_SHOULDER), "R1 is available for body modifier on every controller device")
	check(has_ps3_button(&"box_pause", JOY_BUTTON_START), "Start is available for pause on every controller device")
	print("PS3 INPUT TEST FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
