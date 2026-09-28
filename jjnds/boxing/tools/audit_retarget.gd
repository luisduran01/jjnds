extends SceneTree
func find_type(n: Node, type: String) -> Node:
	if n.is_class(type): return n
	for c in n.get_children():
		var r = find_type(c,type)
		if r: return r
	return null
func _initialize():
	var model = load("res://boxing/characters/boxer_model.tscn").instantiate()
	var target = find_type(model,"Skeleton3D")
	for b in target.get_bone_count():
		print("TARGET ",target.get_bone_name(b)," parent=",target.get_bone_parent(b)," rest=",target.get_bone_rest(b))
	for name in ["boxing_idle","boxing_cross","boxing_jab","boxing_left_hook","boxing_right_hook","boxing_uppercut"]:
		var n = load("res://boxing/characters/animations/"+name+".fbx").instantiate()
		var s = find_type(n,"Skeleton3D")
		var a = find_type(n,"AnimationPlayer").get_animation("mixamo_com")
		var counts = {}
		for t in a.get_track_count():
			var ty = a.track_get_type(t)
			counts[ty] = counts.get(ty,0)+1
		print("SOURCE ",name," length=",a.length," types=",counts)
		if name in ["boxing_idle","boxing_cross"]:
			for b in s.get_bone_count():
				if b < 25: print(" BONE ",s.get_bone_name(b)," parent=",s.get_bone_parent(b)," rest=",s.get_bone_rest(b))
			for t in a.get_track_count():
				if t<25: print(" TRACK ",a.track_get_path(t)," type=",a.track_get_type(t)," first=",a.track_get_key_value(t,0))
		n.free()
	var a = model.get_node("AnimationPlayer").get_animation("cross")
	for t in a.get_track_count():
		print("SAVED ",a.track_get_path(t)," type=",a.track_get_type(t)," first=",a.track_get_key_value(t,0))
	model.free()
	quit()
