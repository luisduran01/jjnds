extends RefCounted

const Punches = preload("res://boxing/combat/punches.gd")
const EXTRA = ["idle","guard","forward","backward","left","right","pivot_left","pivot_right","block_high","block_body","dodge_left","dodge_right","slip","duck","weave","hurt_head","hurt_body","stagger","knockdown","fall","get_up","ko","victory","defeat"]

static func build(model: Node3D, skeleton: Skeleton3D) -> Dictionary:
	var player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	model.add_child(player)
	var library = AnimationLibrary.new()
	var names: Array = EXTRA.duplicate()
	names.append_array(Punches.DATA.keys())
	for clip in names:
		var anim = Animation.new()
		var duration: float = Punches.DATA[clip][0] if Punches.DATA.has(clip) else 1.0
		anim.length = duration
		if clip in ["idle","guard","forward","backward","left","right","block_high","block_body","victory"]:
			anim.loop_mode = Animation.LOOP_LINEAR
		var tracks = []
		for b in skeleton.get_bone_count():
			var track = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(track,NodePath(str(model.get_path_to(skeleton))+":"+skeleton.get_bone_name(b)))
			tracks.append(track)
		for k in 31:
			var t = float(k)/30.0
			var pose = pose_for(clip,t)
			for b in skeleton.get_bone_count():
				anim.rotation_track_insert_key(tracks[b],t*duration,pose.get(skeleton.get_bone_name(b),Quaternion.IDENTITY))
		library.add_animation(clip,anim)
	player.add_animation_library("",library)
	var tree = AnimationTree.new()
	tree.name = "AnimationTree"
	model.add_child(tree)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	tree.anim_player = tree.get_path_to(player)
	var blend = AnimationNodeBlendTree.new()
	var locomotion = AnimationNodeBlendSpace2D.new()
	locomotion.min_space = Vector2(-1,-1)
	locomotion.max_space = Vector2(1,1)
	var directions = {"idle":Vector2.ZERO,"forward":Vector2(0,-1),"backward":Vector2(0,1),"left":Vector2(-1,0),"right":Vector2(1,0)}
	for clip in directions:
		var node = AnimationNodeAnimation.new()
		node.animation = clip
		locomotion.add_blend_point(node,directions[clip],-1,clip)
	blend.add_node("Footwork",locomotion)
	var machine = AnimationNodeStateMachine.new()
	for clip in names:
		var node = AnimationNodeAnimation.new()
		node.animation = clip
		machine.add_node(clip,node)
	for clip in names:
		if clip == "guard": continue
		var to = AnimationNodeStateMachineTransition.new()
		to.xfade_time = 0.07
		machine.add_transition("guard",clip,to)
		var back = AnimationNodeStateMachineTransition.new()
		back.xfade_time = 0.10
		machine.add_transition(clip,"guard",back)
	blend.add_node("Action",machine)
	blend.add_node("ActionSpeed",AnimationNodeTimeScale.new())
	blend.connect_node("ActionSpeed",0,"Action")
	var mix = AnimationNodeBlend2.new()
	mix.filter_enabled = true
	for b in skeleton.get_bone_count():
		var bone = skeleton.get_bone_name(b)
		if not ("Thigh" in bone or "Shin" in bone or "Foot" in bone or bone == "Hips"):
			mix.set_filter_path(NodePath(str(model.get_path_to(skeleton))+":"+bone),true)
	blend.add_node("UpperBody",mix)
	blend.connect_node("UpperBody",0,"Footwork")
	blend.connect_node("UpperBody",1,"ActionSpeed")
	blend.connect_node("output",0,"UpperBody")
	tree.tree_root = blend
	tree.set("parameters/UpperBody/blend_amount",1.0)
	tree.active = true
	var playback = tree.get("parameters/Action/playback")
	playback.start("guard")
	return {"tree":tree,"player":player,"playback":playback}

static func pose_for(clip: String,t: float) -> Dictionary:
	var pose = {}
	var wave = sin(t*TAU)
	var fist = [Vector3(.18,1.57,.33),Vector3(-.19,1.56,.27)]
	var torso = Vector3(0,0.13,0)
	if clip in ["forward","backward","left","right"]:
		pose["LeftThigh"] = Quaternion(Vector3.RIGHT,wave*.19)
		pose["RightThigh"] = Quaternion(Vector3.RIGHT,-wave*.19)
		pose["LeftShin"] = Quaternion(Vector3.RIGHT,maxf(0,-wave)*.22)
		pose["RightShin"] = Quaternion(Vector3.RIGHT,maxf(0,wave)*.22)
	if Punches.DATA.has(clip):
		var d = Punches.DATA[clip]
		var peak: float = (d[1]+d[2])*.5/d[0]
		var extension = smoothstep(0,peak,t) if t<peak else 1.0-smoothstep(peak,1,t)
		var side: int = d[5]
		var sign_side = 1.0 if side==0 else -1.0
		var end = Vector3(sign_side*.04,1.76,.64)
		if clip.begins_with("body"):
			end.y = 1.16
			torso.x = .16*extension
		if d[6] == "hook":
			end.x = -sign_side*.12
			fist[side].x += sign_side*sin(t*PI)*.18
		if d[6] == "upper":
			fist[side].y -= sin(t*PI)*.28
			end.y = 1.7
			end.z = .48
		fist[side] = fist[side].lerp(end,extension)
		torso.y -= sign_side*extension*.26
		torso.x += extension*.12
	elif clip == "block_high":
		fist = [Vector3(.12,1.68,.28),Vector3(-.12,1.68,.28)]
	elif clip == "block_body":
		fist = [Vector3(.15,1.27,.31),Vector3(-.15,1.27,.31)]
	elif clip in ["dodge_left","dodge_right","slip","weave","pivot_left","pivot_right"]:
		torso.z = sin(t*PI)*(.34 if clip in ["dodge_left","slip","pivot_left"] else -.34)
		torso.y += wave*.2
	elif clip == "duck":
		torso.x = sin(t*PI)*.48
	elif clip in ["hurt_head","hurt_body","stagger"]:
		torso.x = sin(t*PI)*(-.32 if clip != "hurt_body" else .38)
		torso.z = sin(t*PI)*.17
	elif clip in ["knockdown","fall","ko","defeat"]:
		fist = [Vector3(.32,1.17,.12),Vector3(-.32,1.17,.12)]
	elif clip == "victory":
		fist = [Vector3(.27,1.9,.08),Vector3(-.27,1.9,.08)]
	pose["Spine"] = Quaternion.from_euler(torso)
	pose["Head"] = Quaternion.from_euler(Vector3(.07,0,-torso.z*.3))
	for side in 2:
		var s = 1.0 if side==0 else -1.0
		var shoulder = Vector3(s*.21,1.48,0)
		var offset: Vector3 = fist[side]-shoulder
		var distance = clampf(offset.length(),.06,.475)
		var direction = offset.normalized()
		var along = (.25*.25-.23*.23+distance*distance)/(2*distance)
		var height = sqrt(maxf(.0001,.25*.25-along*along))
		var pole = Vector3(s*.5,-1,0)
		pole = (pole-direction*direction.dot(pole)).normalized()
		var elbow = shoulder+direction*along+pole*height
		var upper = Quaternion(Vector3(s,0,0),(elbow-shoulder).normalized())
		var fore = Quaternion(Vector3(s,0,0),(shoulder+direction*distance-elbow).normalized())
		var prefix = "Left" if side==0 else "Right"
		pose[prefix+"UpperArm"] = upper
		pose[prefix+"ForeArm"] = upper.inverse()*fore
		pose[prefix+"Hand"] = Quaternion.IDENTITY
	return pose
