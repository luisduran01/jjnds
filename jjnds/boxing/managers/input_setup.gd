extends RefCounted

const KEYS={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"jab":KEY_J,"cross":KEY_K,"left_hook":KEY_U,"right_hook":KEY_I,"left_uppercut":KEY_O,"right_uppercut":KEY_L,"guard":KEY_SHIFT,"body":KEY_CTRL,"dodge_left":KEY_Q,"dodge_right":KEY_E,"duck":KEY_SPACE,"weave":KEY_C,"pivot_left":KEY_Z,"pivot_right":KEY_X,"debug":KEY_F3,"pause":KEY_ESCAPE,"restart":KEY_R,"get_up":KEY_SPACE}

static func install() -> void:
	var existing=InputMap.get_actions()
	for action in KEYS:
		var name="box_"+action
		if InputMap.has_action(name): continue
		InputMap.add_action(name,.18)
		var event=InputEventKey.new()
		event.physical_keycode=KEYS[action]
		InputMap.action_add_event(name,event)
	for pair in [["jab",MOUSE_BUTTON_LEFT],["cross",MOUSE_BUTTON_RIGHT]]:
		if "box_"+pair[0] in existing: continue
		var event=InputEventMouseButton.new()
		event.button_index=pair[1]
		InputMap.action_add_event("box_"+pair[0],event)
	var buttons={"jab":JOY_BUTTON_X,"cross":JOY_BUTTON_Y,"left_hook":JOY_BUTTON_A,"right_hook":JOY_BUTTON_B,"guard":JOY_BUTTON_LEFT_SHOULDER,"body":JOY_BUTTON_RIGHT_SHOULDER,"duck":JOY_BUTTON_LEFT_STICK,"get_up":JOY_BUTTON_A,"pause":JOY_BUTTON_START,"left_uppercut":JOY_BUTTON_DPAD_LEFT,"right_uppercut":JOY_BUTTON_DPAD_RIGHT,"weave":JOY_BUTTON_RIGHT_STICK,"dodge_left":JOY_BUTTON_DPAD_DOWN,"dodge_right":JOY_BUTTON_DPAD_UP}
	for action in buttons:
		if "box_"+action in existing: continue
		var event=InputEventJoypadButton.new()
		event.button_index=buttons[action]
		InputMap.action_add_event("box_"+action,event)
	for entry in [["left",JOY_AXIS_LEFT_X,-1],["right",JOY_AXIS_LEFT_X,1],["forward",JOY_AXIS_LEFT_Y,-1],["back",JOY_AXIS_LEFT_Y,1]]:
		if "box_"+entry[0] in existing: continue
		var event=InputEventJoypadMotion.new()
		event.axis=entry[1]
		event.axis_value=entry[2]
		InputMap.action_add_event("box_"+entry[0],event)
