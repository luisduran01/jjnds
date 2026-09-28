extends SceneTree
const UPPER = ["Spine","Chest","Neck","Head","LeftUpperArm","LeftForeArm","LeftHand","RightUpperArm","RightForeArm","RightHand"]
const LOCO = ["boxing_idle","forward","backward","left","right"]
func _initialize():
	var before = load("res://backups/locomotion-arms-20260928/boxer_model.tscn").instantiate()
	var after = load("res://boxing/characters/boxer_model.tscn").instantiate()
	var old_player = before.get_node("AnimationPlayer")
	var new_player = after.get_node("AnimationPlayer")
	var failures = 0
	for name in old_player.get_animation_list():
		var a: Animation = old_player.get_animation(name)
		var b: Animation = new_player.get_animation(name)
		var equal = a.length == b.length and a.loop_mode == b.loop_mode
		for t in a.get_track_count():
			if name in LOCO and String(a.track_get_path(t).get_concatenated_subnames()) in UPPER: continue
			var other = b.find_track(a.track_get_path(t),a.track_get_type(t))
			if other < 0:
				equal = false
				continue
			equal = equal and a.track_get_key_count(t) == b.track_get_key_count(other)
			for k in a.track_get_key_count(t):
				equal = equal and a.track_get_key_time(t,k) == b.track_get_key_time(other,k) and a.track_get_key_value(t,k) == b.track_get_key_value(other,k)
		if not equal:
			print("FAIL unintended change ",name)
			failures += 1
	before.free(); after.free()
	print("LOWER BODY / OTHER CLIPS FAILURES=",failures)
	quit(1 if failures else 0)
