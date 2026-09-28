extends RefCounted

const Punches = preload("res://boxing/combat/punches.gd")
const ReachProfile = preload("res://boxing/characters/reach_profile.gd")
const EXTRA = ["idle","guard","forward","backward","left","right","pivot_left","pivot_right","block_high","block_body","dodge_left","dodge_right","slip","duck","weave","hurt_head","hurt_body","stagger","knockdown","fall","get_up","ko","victory","defeat"]

<<<<<<< HEAD
static func d(degrees: float) -> float:
	return deg_to_rad(degrees)

static func q_axis(axis: Vector3, angle: float) -> Quaternion:
	return Quaternion(axis.normalized(),angle)

static func gait_legs(input: Vector2, phase: float, amount: float) -> Dictionary:
	var swing=sin(phase*TAU)*amount*d(18.0)
	return {"LeftThigh":q_axis(Vector3.RIGHT,swing),"RightThigh":q_axis(Vector3.RIGHT,-swing),"LeftShin":q_axis(Vector3.RIGHT,-swing*.55),"RightShin":q_axis(Vector3.RIGHT,swing*.55)}

static func build(model: Node3D, skeleton: Skeleton3D) -> Dictionary:
=======
# Fallback geometry when no measured reach is supplied; keeps the builder usable
# on its own while the fighter always passes the resolved rig numbers.
const DEFAULT_REACH := {
	"upper": 0.25, "lower": 0.23, "total": 0.48, "shoulder_x": 0.21,
}

static func build(model: Node3D, skeleton: Skeleton3D, reach: Dictionary = {}) -> Dictionary:
	var geometry := reach if not reach.is_empty() else DEFAULT_REACH
>>>>>>> 7ad7f168236b6a7959ebed9c467b837a461db449
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
			var pose = pose_for(clip,t,geometry)
			for b in skeleton.get_bone_count():
				anim.rotation_track_insert_key(tracks[b],t*duration,pose.get(skeleton.get_bone_name(b),Quaternion.IDENTITY))
		library.add_animation(clip,anim)
	player.add_animation_library("",library)
	var tree = AnimationTree.new()
	tree.name = "AnimationTree"
	model.add_child(tree)
	# MANUAL: the mixer rewrites the whole pose on every automatic pass, which
	# erased every procedural reaction (measured 0.000 deg on a clean cross).
	# The fighter advances the mixer itself and then applies its procedural layers
	# in a known order, so impacts survive instead of being overwritten.
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
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

static func pose_for(clip: String,t: float,geometry: Dictionary = {}) -> Dictionary:
	var measured: Dictionary = geometry if not geometry.is_empty() else DEFAULT_REACH
	var upper_length: float = measured.get("upper", 0.25)
	var lower_length: float = measured.get("lower", 0.23)
	var total_length: float = measured.get("total", upper_length + lower_length)
	var shoulder_x: float = measured.get("shoulder_x", 0.21)
	var pose = {}
	var wave = sin(t*TAU)
	var fist = [Vector3(.18,1.57,.33),Vector3(-.19,1.56,.27)]
	var torso = Vector3(0,0.13,0)
	var chest = Vector3.ZERO
	if clip in ["forward","backward","left","right"]:
		pose["LeftThigh"] = Quaternion(Vector3.RIGHT,wave*.19)
		pose["RightThigh"] = Quaternion(Vector3.RIGHT,-wave*.19)
		pose["LeftShin"] = Quaternion(Vector3.RIGHT,maxf(0,-wave)*.22)
		pose["RightShin"] = Quaternion(Vector3.RIGHT,maxf(0,wave)*.22)
	var budget := total_length
	if Punches.DATA.has(clip):
		var d = Punches.DATA[clip]
		var chain := ReachProfile.chain_for(clip)
		var peak: float = (d[1]+d[2])*.5/d[0]
		var extension = smoothstep(0,peak,t) if t<peak else 1.0-smoothstep(peak,1,t)
		var side: int = d[5]
		var sign_side = 1.0 if side==0 else -1.0
		var end = Vector3(sign_side*.04,1.76,.64)
		if clip.begins_with("body"):
			end.y = 1.16
		if d[6] == "hook":
			end.x = -sign_side*.12
			fist[side].x += sign_side*sin(t*PI)*.18
			torso.y = -sign_side * extension * .34
			pose["Hips"] = Quaternion.from_euler(Vector3(0.0, -sign_side * extension * .22, 0.0))
		if d[6] == "upper":
<<<<<<< HEAD
			# Uppercuts now begin below the guard and rise through the target,
			# instead of tracing the same horizontal line as a straight.
			fist[side].y = 1.20
			fist[side].z = .18
			end.y = 1.92
			end.z = .42
			torso.x = -.16 * extension
			torso.y = -sign_side * extension * .18
			pose["Hips"] = Quaternion.from_euler(Vector3(-extension * .16, -sign_side * extension * .14, 0.0))
			pose["LeftThigh"] = Quaternion.from_euler(Vector3(extension * .16 if side==0 else extension * .05,0,0))
			pose["RightThigh"] = Quaternion.from_euler(Vector3(extension * .16 if side==1 else extension * .05,0,0))
			pose["LeftShin"] = Quaternion.from_euler(Vector3(-extension * .11 if side==0 else 0,0,0))
			pose["RightShin"] = Quaternion.from_euler(Vector3(-extension * .11 if side==1 else 0,0,0))
		if d[6] == "straight":
			# Jabs stay light and quick; crosses load the rear leg then rotate through.
			if clip in ["jab", "body_jab"]:
				torso.y = extension * .10
				pose["Hips"] = Quaternion.from_euler(Vector3(0.0, extension * .06, 0.0))
				pose["LeftThigh"] = Quaternion.from_euler(Vector3(extension * .08,0,0))
			else:
				torso.y = -extension * .30
				pose["Hips"] = Quaternion.from_euler(Vector3(-extension * .07, -extension * .20, 0.0))
				pose["RightThigh"] = Quaternion.from_euler(Vector3(extension * .17,0,0))
				pose["RightShin"] = Quaternion.from_euler(Vector3(-extension * .10,0,0))
=======
			fist[side].y -= sin(t*PI)*.28
			end.y = 1.7
			end.z = .48
		# Each punch may only spend the share of the arm its mechanics allow, so a
		# hook cannot reach like a cross and an uppercut cannot reach like a jab.
		budget = ReachProfile.extension_for(measured,clip)
		# Kinetic chain, fired in order and not all at once:
		# step/weight are paid by the legs and pelvis (Fighter + ActiveRagdoll);
		# torso -> shoulder -> extension are paid here, in that order.
		# The chain lands together: torso and shoulder arrive WITH the arm, so the
		# punch's furthest, deepest and lowest point is one moment instead of the
		# torso carrying the fist forward after the arm has already retracted.
		# The pelvis (weight) and the footwork still lead, driven from the attack
		# phase by ActiveRagdoll.set_punch_drive and Fighter.plan_punch_step.
		var torso_ramp := clampf(extension*1.12,0.0,1.0)
		var shoulder_ramp := clampf((extension-0.12)/0.88,0.0,1.0)
		torso.y -= sign_side*float(chain["torso"])*0.42*torso_ramp
		torso.x += float(chain["lean"])*0.34*extension
		chest.y = -sign_side*float(chain["shoulder"])*0.26*shoulder_ramp
		chest.x = float(chain["lean"])*0.10*extension
		# rise: how much the punch climbs (uppercut) or drops (body shot). Scaled
		# by the target height, which is what makes a body hook arrive low.
		end.y += float(chain["rise"])*0.22*extension
>>>>>>> 7ad7f168236b6a7959ebed9c467b837a461db449
		fist[side] = fist[side].lerp(end,extension)
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
	pose["Chest"] = Quaternion.from_euler(chest)
	pose["Head"] = Quaternion.from_euler(Vector3(.07,0,-torso.z*.3))
	var tightest := absf(upper_length-lower_length)+0.001
	# Never aim past the bone chain itself, otherwise the elbow locks straight
	# while the wrist falls short of the requested target.
	var longest := maxf(tightest,minf(budget,total_length-0.002))
	for side in 2:
		var s = 1.0 if side==0 else -1.0
		var shoulder = Vector3(s*shoulder_x,1.48,0)
		var offset: Vector3 = fist[side]-shoulder
		var distance = clampf(offset.length(),tightest,longest)
		var direction = offset.normalized()
		var along = (upper_length*upper_length-lower_length*lower_length+distance*distance)/(2*distance)
		var height = sqrt(maxf(.0001,upper_length*upper_length-along*along))
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
