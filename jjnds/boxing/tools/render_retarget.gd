extends SceneTree
const CLIPS = {"jab":"boxing_jab","cross":"boxing_cross","left_hook":"boxing_left_hook","right_hook":"boxing_right_hook","left_uppercut":"boxing_uppercut","right_uppercut":"boxing_uppercut"}
func find_type(n: Node, type: String) -> Node:
	if n.is_class(type): return n
	for c in n.get_children():
		var r = find_type(c,type)
		if r: return r
	return null
func _initialize(): call_deferred("run")
func run():
	var moving = OS.get_cmdline_user_args().has("--moving")
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1400,2100)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world = Node3D.new()
	viewport.add_child(world)
	var camera = Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 19.2
	camera.position = Vector3(5.2,8.3,30)
	var light = DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-30,-25,0)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.055,.065,.085)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .35
	world.add_child(env)
	var row = 0
	for name in CLIPS:
		for col in 3:
			var group = Node3D.new()
			world.add_child(group)
			group.position = Vector3(col*3.7,(5-row)*2.8,0)
			var model = load("res://boxing/characters/boxer_model.tscn").instantiate()
			group.add_child(model)
			model.rotation.y = -.6
			model.get_node("AnimationTree").active = false
			var player = model.get_node("AnimationPlayer")
			var time = player.get_animation(name).length * [0.0,.5,.95][col]
			player.play(name); player.seek(time,true); player.pause()
			if moving:
				var tree = model.get_node("AnimationTree")
				tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				tree.active = true
				tree.set("parameters/Locomotion/blend_position",[Vector2(0,-1),Vector2(-1,0),Vector2(1,0)][col])
				tree.set("parameters/UpperBody/blend_amount",1.0)
				tree.get("parameters/Action/playback").start(name,true)
				tree.advance(0)
				tree.advance(time)
			var source = load("res://boxing/characters/animations/"+CLIPS[name]+".fbx").instantiate()
			group.add_child(source)
			var sp = find_type(source,"AnimationPlayer")
			sp.play("mixamo_com"); sp.seek(time,true); sp.pause()
			var sk = find_type(source,"Skeleton3D")
			var lines = ImmediateMesh.new()
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(.2,.9,1)
			lines.surface_begin(Mesh.PRIMITIVE_LINES,mat)
			for bone in sk.get_bone_count():
				var parent = sk.get_bone_parent(bone)
				if parent < 0: continue
				var a = sk.get_bone_global_pose(parent).origin
				var b = sk.get_bone_global_pose(bone).origin
				if name == "right_uppercut": a.x = -a.x; b.x = -b.x
				lines.surface_add_vertex(a)
				lines.surface_add_vertex(b)
			lines.surface_end()
			var mesh = MeshInstance3D.new()
			mesh.mesh = lines
			group.add_child(mesh)
			mesh.position.x = 1.5
			mesh.rotation.y = -.6
			source.free()
			var label = Label3D.new()
			label.text = name + "  " + str(int([0,50,95][col])) + "%"
			if moving: label.text += " " + ["forward","left","right"][col]
			label.font_size = 32
			label.pixel_size = .008
			label.position = Vector3(.7,2.35,0)
			group.add_child(label)
		row += 1
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://boxing/tests/retarget_moving_comparison.png" if moving else "res://boxing/tests/retarget_comparison.png")
	print("RETARGET VISUAL CAPTURE SAVED")
	quit()



