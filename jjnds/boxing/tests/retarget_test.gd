extends SceneTree
const PAIRS = {"jab":"boxing_jab","cross":"boxing_cross","left_hook":"boxing_left_hook","right_hook":"boxing_right_hook","left_uppercut":"boxing_uppercut","right_uppercut":"boxing_uppercut"}
var failures = 0
func find_type(n: Node, type: String) -> Node:
	if n.is_class(type): return n
	for c in n.get_children():
		var r = find_type(c,type)
		if r: return r
	return null
func _initialize(): call_deferred("run")
func run():
	var model = load("res://boxing/characters/boxer_model.tscn").instantiate()
	root.add_child(model)
	model.get_node("AnimationTree").active = false
	var target: Skeleton3D = find_type(model,"Skeleton3D")
	var player: AnimationPlayer = model.get_node("AnimationPlayer")
	for name in PAIRS:
		var n = load("res://boxing/characters/animations/"+PAIRS[name]+".fbx").instantiate()
		root.add_child(n)
		var s: Skeleton3D = find_type(n,"Skeleton3D")
		var p: AnimationPlayer = find_type(n,"AnimationPlayer")
		var a = p.get_animation("mixamo_com")
		var max_error = 0.0
		var height_ranges = {"Left":Vector2(100,-100),"Right":Vector2(100,-100)}
		for k in 61:
			var time = a.length*k/60.0
			s.reset_bone_poses()
			target.reset_bone_poses()
			p.play("mixamo_com"); p.seek(time,true); p.pause()
			player.play(name); player.seek(time,true); player.pause()
			for side in ["Left","Right"]:
				var h = s.get_bone_global_pose(s.find_bone(side+"Hand")).origin.y
				height_ranges[side] = Vector2(minf(height_ranges[side].x,h),maxf(height_ranges[side].y,h))
				var source_side = ("Right" if side == "Left" else "Left") if name == "right_uppercut" else side
				for names in [["UpperArm","LowerArm","UpperArm","ForeArm"],["LowerArm","Hand","ForeArm","Hand"]]:
					var source_direction = (s.get_bone_global_pose(s.find_bone(source_side+names[1])).origin-s.get_bone_global_pose(s.find_bone(source_side+names[0])).origin).normalized()
					if name == "right_uppercut": source_direction.x = -source_direction.x
					var target_direction = (target.get_bone_global_pose(target.find_bone(side+names[3])).origin-target.get_bone_global_pose(target.find_bone(side+names[2])).origin).normalized()
					max_error = maxf(max_error,rad_to_deg(source_direction.angle_to(target_direction)))
				var shoulder = target.get_bone_global_pose(target.find_bone(side+"UpperArm")).origin
				var hand = target.get_bone_global_pose(target.find_bone(side+"Hand")).origin
				if shoulder.distance_to(hand) > 0.4801: failures += 1
			if not target.get_bone_pose_position(0).is_equal_approx(target.get_bone_rest(0).origin): failures += 1
		print(name," maximum arm direction error degrees=",max_error)
		print("HAND HEIGHT RANGES ",name," ",height_ranges)
		if max_error > 3.0: failures += 1
		n.free()
	model.free()
	print("RETARGET FAILURES=",failures)
	quit(1 if failures else 0)




