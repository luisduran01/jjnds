extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for key in ProjectSettings.get_property_list():
		var name := String(key.name)
		if not name.begins_with("autoload/"):
			continue
		var configured := String(ProjectSettings.get_setting(name, ""))
		var path := configured.trim_prefix("*")
		if path.begins_with("uid://"):
			path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
		if path.is_empty() or not ResourceLoader.exists(path):
			failures += 1
			push_error("TEST FAILED: stale autoload %s -> %s" % [name, configured])
	var scene = load("res://boxing/main.tscn").instantiate()
	root.add_child(scene)
	if not scene.find_children("*", "TouchScreenButton", true, false).is_empty():
		failures += 1
		push_error("TEST FAILED: PC build must not create mobile controls")
	scene.brain.set_physics_process(false)
	scene.fight.set_process(false)
	scene.fight.begin()
	if scene.fight.corner_panel == null or scene.fight.corner_panel.get_parent() == null:
		failures += 1
		push_error("TEST FAILED: fight-owned UI must attach without current_scene")
	scene.queue_free()
	await process_frame
	print("BOOTSTRAP TEST FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
