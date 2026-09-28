extends SceneTree
func _initialize():
	var before = load("res://backups/retarget-20260928/boxer_model.tscn").instantiate()
	var after = load("res://boxing/characters/boxer_model.tscn").instantiate()
	var failures = 0
	for name in ["boxing_idle","forward","backward","left","right"]:
		var a: Animation = before.get_node("AnimationPlayer").get_animation(name)
		var b: Animation = after.get_node("AnimationPlayer").get_animation(name)
		var equal = a.length == b.length and a.loop_mode == b.loop_mode and a.get_track_count() == b.get_track_count()
		for t in a.get_track_count():
			equal = equal and a.track_get_path(t) == b.track_get_path(t) and a.track_get_type(t) == b.track_get_type(t) and a.track_get_key_count(t) == b.track_get_key_count(t)
			for k in a.track_get_key_count(t):
				equal = equal and a.track_get_key_time(t,k) == b.track_get_key_time(t,k) and a.track_get_key_value(t,k) == b.track_get_key_value(t,k)
		print(name," unchanged=",equal)
		if not equal: failures += 1
	before.free(); after.free()
	print("LOCOMOTION REGRESSION FAILURES=",failures)
	quit(1 if failures else 0)
