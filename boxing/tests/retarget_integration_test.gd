extends SceneTree
var failures = 0
func _initialize(): call_deferred("run")
func run():
	check_layers()
	var fighter = load("res://boxing/characters/fighter.gd").new()
	root.add_child(fighter)
	fighter.set_physics_process(false)
	fighter.fighting = true
	fighter.move_input = Vector2(1,0)
	fighter.velocity = Vector3(.4,0,0)
	fighter.attack("cross")
	fighter._physics_process(.05)
	if fighter.locomotion_blend.length() < .01:
		print("FAIL moving punch loses locomotion")
		failures += 1
	var blend = fighter.animation.tree.tree_root.get_node("UpperBody")
	if not blend.is_path_filtered(NodePath("boxer_rigged/Boxer/Skeleton3D:Hips")):
		print("FAIL punch hip rotation is excluded")
		failures += 1
	for i in 100: fighter._physics_process(.016)
	if fighter.current_punch != "" or fighter.animation.tree.get("parameters/UpperBody/blend_amount") != 0.0:
		print("FAIL punch does not return to locomotion")
		failures += 1
	fighter.free()
	print("RETARGET INTEGRATION FAILURES=",failures)
	quit(1 if failures else 0)

func check_layers():
	for direction in [Vector2.ZERO,Vector2(0,-1),Vector2(0,1),Vector2(-1,0),Vector2(1,0)]:
		var models = []
		for amount in [0.0,1.0]:
			var model = load("res://boxing/characters/boxer_model.tscn").instantiate()
			root.add_child(model)
			models.append(model)
			var tree = model.get_node("AnimationTree")
			tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			tree.active = true
			tree.set("parameters/Locomotion/blend_position",direction)
			tree.set("parameters/UpperBody/blend_amount",amount)
			tree.get("parameters/Action/playback").start("cross",true)
			tree.advance(0)
			tree.advance(.37)
		var a: Skeleton3D = models[0].get_node("boxer_rigged/Boxer/Skeleton3D")
		var b: Skeleton3D = models[1].get_node("boxer_rigged/Boxer/Skeleton3D")
		for name in ["LeftThigh","LeftShin","LeftFoot","RightThigh","RightShin","RightFoot"]:
			var bone = a.find_bone(name)
			if a.get_bone_pose_rotation(bone).angle_to(b.get_bone_pose_rotation(bone)) > .001:
				print("FAIL action overrides locomotion leg ",direction," ",name)
				failures += 1
		if a.get_bone_pose_rotation(0).angle_to(b.get_bone_pose_rotation(0)) < .01:
			print("FAIL action hip does not reach output")
			failures += 1
		for model in models: model.free()

