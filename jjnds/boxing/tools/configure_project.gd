extends SceneTree

func _initialize() -> void:
	preload("res://boxing/managers/input_setup.gd").install()
	for action in InputMap.get_actions():
		if action.begins_with("box_"):
			ProjectSettings.set_setting("input/"+action,{"deadzone":InputMap.action_get_deadzone(action),"events":InputMap.action_get_events(action)})
	ProjectSettings.set_setting("application/run/main_scene","res://boxing/main.tscn")
	ProjectSettings.set_setting("application/config/name","Corner Club — Boxing")
	ProjectSettings.set_setting("rendering/renderer/rendering_method","gl_compatibility")
	ProjectSettings.set_setting("rendering/renderer/rendering_method.mobile","gl_compatibility")
	ProjectSettings.set_setting("display/window/size/window_width_override",1280)
	ProjectSettings.set_setting("display/window/size/window_height_override",720)
	ProjectSettings.set_setting("display/window/size/min_width",960)
	ProjectSettings.set_setting("display/window/size/min_height",640)
	var error=ProjectSettings.save()
	print("Project + Input Map saved: ",error)
	quit(error)
