extends CharacterBody3D
class_name Fighter

signal hit_landed(attacker, victim, info)
signal knocked_down(fighter)
signal state_changed(next)
signal medical_risk(fighter)

enum State { IDLE, MOVING, ATTACKING, BLOCKING, DODGING, HURT, STUNNED, KNOCKDOWN, GET_UP, KO, VICTORY, DEFEAT }
const Punches = preload("res://boxing/combat/punches.gd")
const BodyProfile = preload("res://boxing/characters/body_profile.gd")
const Fatigue = preload("res://boxing/combat/fatigue_model.gd")
const ActiveRagdoll = preload("res://boxing/characters/active_ragdoll.gd")
const DamageAccumulator = preload("res://boxing/combat/damage_accumulator.gd")
const ArmIK = preload("res://boxing/characters/arm_ik.gd")
const InjurySystem = preload("res://boxing/combat/injury_system.gd")
const CombatState = preload("res://boxing/combat/combat_state_machine.gd")
const CombatTypes = preload("res://boxing/combat/combat_types.gd")
@export var is_player = false
@export var boxer_name = "ALONSO"
@export var team_color = Color("d94938")
@export var boxer_data: Resource
var opponent: CharacterBody3D
var state = State.IDLE
var health = 100.0
var stamina = 100.0
var guard = 100.0
var head_damage = 0.0
var body_damage = 0.0
var stun = 0.0
var knockdown_meter = 0.0
var knockdowns = 0
var round_knockdowns = 0
var landed = 0
var thrown = 0
var round_quality = 0.0
var fighting = false
var move_input = Vector2.ZERO
var defense = ""
var current_punch = ""
var attack_time = 0.0
var attack_scale = 1.0
var attack_stamina = 100.0
var attack_id = 0
var recovery = 0.0
var combo_count = 0
var combo_window = 0.0
var state_time = 0.0
var buffered = ""
var buffer_life = 0.0
var hits_received: Dictionary = {}
var model: Node3D
var camera_target: Node3D
var is_stepping: bool = false
var locomotion_blend: Vector2 = Vector2.ZERO
@export var locomotion_blend_speed: float = 5.0
@export var preferred_fight_distance: float = 1.45
@export var distance_deadzone: float = 0.20
@export var circle_speed_multiplier: float = 0.92
@export var close_retreat_bonus: float = 1.12
@export var far_approach_bonus: float = 1.08
@export var pivot_distance: float = 1.65
@export var pivot_boost: float = 1.22
@export var pivot_duration: float = 0.16
var pivot_timer: float = 0.0
var pivot_direction: float = 0.0
@export var acceleration_rate: float = 9.0
@export var braking_rate: float = 13.0
@export var direction_change_rate: float = 6.5
var last_move_direction: Vector3 = Vector3.ZERO
@export var punch_movement_strength: float = 0.38
@export var cross_movement_strength: float = 0.48
@export var hook_movement_strength: float = 0.20
@export var uppercut_movement_strength: float = 0.16
var skeleton: Skeleton3D
var animation: Dictionary
var fist_points: Array[Node3D] = []
var fists: Array[Area3D] = []
var hurts: Array[Area3D] = []
var old_fists: Array[Vector3] = []
var fist_speed = 1.0
var attack_connected = false
var debug_shapes: Array[MeshInstance3D] = []
var body_profile: Dictionary = {}
var fatigue
var active_ragdoll
var damage_accumulator
var injury  # InjurySystem
var last_ik_target := Vector3.ZERO
# Feint system
var is_feinting := false
var feint_timer := 0.0
# Composure reference (set by fight director)
var composure_ref: Callable = func(): return 1.0
var combat_state_machine

func _ready() -> void:
	combat_state_machine=CombatState.new()
	collision_layer = 2
	collision_mask = 3
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .23
	capsule.height = 1.72
	shape.shape = capsule
	shape.position.y = .86
	add_child(shape)
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	camera_target = Node3D.new()
	camera_target.name = "CameraTarget"
	camera_target.position = Vector3(0, 1.15, 0)
	add_child(camera_target)
	# The fighter consumes the authored scene: its clips and BlendSpace are baked
	# assets, never tracks built at runtime by Fighter.
	var packed = load("res://boxing/characters/boxer_model.tscn") as PackedScene
	if packed == null:
		push_error("Boxer model scene was not imported")
		return
	var visual = packed.instantiate()
	model.add_child(visual)
	skeleton = find_skeleton(visual)
	var player = visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var tree = visual.get_node_or_null("AnimationTree") as AnimationTree
	if skeleton == null or player == null or tree == null:
		push_error("Boxer model requires Skeleton3D, AnimationPlayer and AnimationTree")
		return
	tree.active = true
	tree.set("parameters/UpperBody/blend_amount",0.0)
	var playback = tree.get("parameters/Action/playback") as AnimationNodeStateMachinePlayback
	if playback == null:
		push_error("Boxer AnimationTree is missing the Action state machine")
		return
	animation = {"player": player, "tree": tree, "playback": playback}
	playback.start("guard", true)
	body_profile=BodyProfile.from_stats(profile_value("height",180.0),profile_value("reach",182.0),profile_value("weight",147.0))
	apply_body_profile()
	fatigue=Fatigue.new()
	fatigue.configure(profile_value("stamina_max",100.0),profile_value("recovery",60.0))
	stamina=fatigue.energy
	active_ragdoll=ActiveRagdoll.new()
	damage_accumulator=DamageAccumulator.new()
	injury=InjurySystem.new()
	injury.medical_stoppage_risk.connect(_on_medical_risk)
	for side in ["Left","Right"]:
		var attach = BoneAttachment3D.new()
		attach.name = side+"FistAttachment"
		skeleton.add_child(attach)
		attach.bone_name = side+"Hand"
		var point = Node3D.new()
		point.position.x = .065 if side == "Left" else -.065
		attach.add_child(point)
		fist_points.append(point)
		var fist = make_area(side+"FistHitbox",.13,4,8)
		add_child(fist)
		fists.append(fist)
		old_fists.append(Vector3.ZERO)
	for zone in ["head","body"]:
		var area = make_area(zone,.19 if zone=="head" else .245,8,0)
		area.set_meta("fighter",self)
		area.set_meta("zone",zone)
		add_child(area)
		hurts.append(area)
	# Each fighter gets an independent dynamic skin material and damage atlas.
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		var skin_material=ShaderMaterial.new()
		skin_material.shader=load("res://boxing/characters/opponent.gdshader")
		skin_material.set_shader_parameter("damage_map",damage_accumulator.texture)
		skin_material.set_shader_parameter("damage_strength",1.0)
		mesh.material_override=skin_material
	if not is_player:
		_add_opponent_identity()

func _add_opponent_identity() -> void:
	# The rival shares the combat rig but no longer reads as the same boxer.
	var head_bone=skeleton.find_bone("Head")
	if head_bone < 0: return
	var attachment=BoneAttachment3D.new()
	attachment.bone_name="Head"
	skeleton.add_child(attachment)
	var hair=MeshInstance3D.new()
	var cap=SphereMesh.new()
	cap.radius=.15; cap.height=.13; cap.radial_segments=12
	hair.mesh=cap; hair.position=Vector3(0,.13,0); hair.scale=Vector3(1.05,.55,1.05)
	hair.material_override=_kit_material(Color("15120f"),.82)
	attachment.add_child(hair)
	var beard=MeshInstance3D.new()
	var beard_mesh=BoxMesh.new()
	beard_mesh.size=Vector3(.12,.10,.035)
	beard.mesh=beard_mesh; beard.position=Vector3(0,-.10,.135)
	beard.material_override=_kit_material(Color("211712"),.9)
	attachment.add_child(beard)

func _kit_material(color: Color, roughness: float, metallic: float=0.0) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=roughness
	mat.metallic=metallic
	return mat

func profile_value(field: String, fallback: float) -> float:
	if boxer_data and field in boxer_data: return float(boxer_data.get(field))
	return fallback

func apply_body_profile() -> void:
	if not skeleton or body_profile.is_empty(): return
	model.scale=Vector3.ONE*body_profile.height_scale
	for bone_name in ["LeftUpperArm","LeftForeArm","RightUpperArm","RightForeArm"]:
		var bone=skeleton.find_bone(bone_name)
		if bone>=0: skeleton.set_bone_pose_scale(bone,Vector3(body_profile.arm_scale,1,1))
	for bone_name in ["LeftThigh","LeftShin","RightThigh","RightShin"]:
		var bone=skeleton.find_bone(bone_name)
		if bone>=0: skeleton.set_bone_pose_scale(bone,Vector3(1,body_profile.leg_scale,1))
	for bone_name in ["Spine","Chest"]:
		var bone=skeleton.find_bone(bone_name)
		if bone>=0: skeleton.set_bone_pose_scale(bone,Vector3(body_profile.torso_width,1,body_profile.torso_depth))

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var result = find_skeleton(child)
		if result: return result
	return null

func make_area(label: String,radius: float,layer: int,mask: int) -> Area3D:
	var area = Area3D.new()
	area.name = label
	area.collision_layer = layer
	area.collision_mask = mask
	area.monitoring = false
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	area.add_child(collision)
	var mesh = MeshInstance3D.new()
	var ball = SphereMesh.new()
	ball.radius = radius
	ball.height = radius*2
	mesh.mesh = ball
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1,.3,.1,.28) if layer==4 else Color(.1,1,.4,.24)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	mesh.visible = false
	area.add_child(mesh)
	debug_shapes.append(mesh)
	return area

func set_state(next: State,duration: float=0.0,clip: String="") -> void:
	if combat_state_machine:
		combat_state_machine.request(next,duration,StringName(clip))
	if state==State.ATTACKING and next!=State.ATTACKING:
		current_punch=""
		if not animation.is_empty():
			animation.tree.set("parameters/UpperBody/blend_amount",0.0)
		if next!=State.IDLE:
			buffered=""
			buffer_life=0
	state = next
	state_time = duration
	if not animation.is_empty():
		var desired = clip if clip!="" else "guard"
		animation.playback.start(desired,true)
	state_changed.emit(next)

func can_act() -> bool:
	return fighting and state in [State.IDLE,State.MOVING,State.BLOCKING]

func attack(punch: String) -> bool:
	if not Punches.DATA.has(punch): return false
	if state==State.ATTACKING:
		update_punch_ik()
		if combat_state_machine:
			combat_state_machine.buffer({"kind":CombatTypes.ActionKind.ATTACK,"name":StringName(punch)},.20)
		buffered = punch
		buffer_life = .20
		return false
	if not can_act(): return false
	var data = Punches.DATA[punch]
	var cost: float = data[4]*(1.0+minf(combo_count,4)*.08)
	if stamina<cost: return false
	attack_stamina = stamina
	stamina -= cost
	fatigue.spend(cost,1.0+minf(combo_count,4)*.12)
	stamina=fatigue.energy
	combo_count = combo_count+1 if combo_window>0 else 1
	combo_window = 1.05
	attack_scale = fatigue.animation_factor()
	attack_id += 1
	attack_time = 0
	attack_connected = false
	current_punch = punch
	if opponent:
		last_ik_target=opponent.global_position+Vector3(0,1.18 if punch.begins_with("body") else 1.66,0)
	thrown += 1
	defense = ""
	if not animation.is_empty():
		animation.tree.set("parameters/UpperBody/blend_amount",1.0)
	set_state(State.ATTACKING,0,punch)
	return true

func dodge(kind: String) -> void:
	if not can_act() or stamina<9: return
	stamina -= 9
	defense = kind
	set_state(State.DODGING,.5,kind)

func feint(kind: String) -> void:
	# Amago: inicia la animación de un golpe pero la cancela a mitad
	if not can_act() or stamina < 3: return
	if not Punches.DATA.has(kind): return
	is_feinting = true
	feint_timer = Punches.DATA[kind][1] * 0.8  # Hasta justo antes del activo
	stamina -= 2.5
	set_state(State.ATTACKING, 0, kind)  # Usa la misma anim del golpe
	current_punch = "feint_" + kind  # Marcado como feint, no conecta


func _on_medical_risk() -> void:
	medical_risk.emit(self)

func _physics_process(delta: float) -> void:
	if not skeleton: return
	fatigue.tick(delta,state==State.BLOCKING)
	stamina=fatigue.energy
	active_ragdoll.step(delta,fatigue.drive_factor())
	apply_ragdoll_pose()
	state_time = maxf(0,state_time-delta)
	buffer_life = maxf(0,buffer_life-delta)
	combo_window = maxf(0,combo_window-delta)
	if combo_window<=0: combo_count=0
	if buffer_life<=0: buffered=""
	if is_feinting:
		feint_timer -= delta
		if feint_timer <= 0.0:
			is_feinting = false
			current_punch = ""
			set_state(State.IDLE)
		return
	if is_player and fighting: read_input()
	if opponent and state not in [State.KNOCKDOWN,State.KO,State.GET_UP]:
		var flat = opponent.global_position-global_position
		flat.y=0
		if flat.length()>.1:
			rotation.y = lerp_angle(rotation.y,atan2(flat.x,flat.z),minf(1,delta*9))
	if state==State.ATTACKING:
		attack_time += delta*attack_scale
		var d = Punches.DATA[current_punch]
		var action_clip: Animation = animation.player.get_animation(current_punch)
		var clip_speed := action_clip.length/maxf(d[0],.001) if action_clip else 1.0
		animation.tree.set("parameters/ActionSpeed/scale",attack_scale*clip_speed)
		# Transfer of body weight uses the punch's early drive, then fades during
		# recovery. Straight punches advance more than hooks and uppercuts.
		var punch_progress := clampf(attack_time/maxf(d[0],.001),0.0,1.0)
		var drive_curve := sin(punch_progress*PI)
		var punch_drive := 0.0
		if current_punch in ["jab","body_jab"]:
			punch_drive=punch_movement_strength
		elif current_punch in ["cross","body_cross"]:
			punch_drive=cross_movement_strength
		elif d[6]=="hook":
			punch_drive=hook_movement_strength
		elif d[6]=="upper":
			punch_drive=uppercut_movement_strength
		if punch_drive>.0 and opponent:
			var punch_forward := opponent.global_position-global_position
			punch_forward.y=0.0
			if punch_forward.length_squared()>.001:
				punch_forward=punch_forward.normalized()
				velocity.x+=punch_forward.x*punch_drive*drive_curve*delta
				velocity.z+=punch_forward.z*punch_drive*drive_curve*delta
		if attack_time>=d[0]:
			recovery = .15 if not attack_connected else .02
			animation.tree.set("parameters/UpperBody/blend_amount",0.0)
			set_state(State.IDLE)
			current_punch=""
			if buffered!="":
				var next=buffered
				buffered=""
				attack(next)
	elif state in [State.DODGING,State.HURT,State.STUNNED,State.GET_UP] and state_time<=0:
		defense=""
		set_state(State.IDLE)
	if state!=State.ATTACKING: animation.tree.set("parameters/ActionSpeed/scale",1.0)
	pivot_timer=maxf(0.0,pivot_timer-delta)
	if state not in [State.KNOCKDOWN,State.KO,State.VICTORY,State.DEFEAT]:
		var speed = lerpf(1.1,2.1,health/100.0)*lerpf(.65,1.0,stamina/100.0)
		if state==State.ATTACKING: speed*=.48
		if state==State.BLOCKING: speed*=.56
		if state in [State.HURT,State.STUNNED,State.GET_UP]: speed*=.12
		var can_footwork = fighting and state in [State.IDLE, State.MOVING]

		# Follow the actual local velocity. This preserves the forward/strafe clip
		# during physical deceleration instead of snapping toward Idle on key-up.
		var target_blend := Vector2.ZERO
		if fighting and (can_footwork or state==State.ATTACKING) and speed>.01:
			var local_velocity := global_basis.inverse()*Vector3(velocity.x,0.0,velocity.z)
			target_blend=Vector2(local_velocity.x/speed,local_velocity.z/speed)
			target_blend.x=clampf(target_blend.x,-1.0,1.0)
			target_blend.y=clampf(target_blend.y,-1.0,1.0)
		var blend_weight := 1.0-exp(-locomotion_blend_speed*delta)
		locomotion_blend = locomotion_blend.lerp(target_blend,blend_weight)
		if not animation.is_empty():
			animation.tree.set("parameters/Locomotion/blend_position",locomotion_blend)
			var horizontal_speed := Vector2(velocity.x,velocity.z).length()
			var locomotion_speed_scale := 1.0
			if horizontal_speed>.05:
				locomotion_speed_scale=clampf(horizontal_speed/1.6,.75,1.30)
			animation.tree.set("parameters/LocomotionSpeed/scale",locomotion_speed_scale)

		var direction := Vector3.ZERO
		if opponent:
			var to_opponent := opponent.global_position-global_position
			to_opponent.y=0.0
			if to_opponent.length_squared()>.001:
				var forward := to_opponent.normalized()
				var right := Vector3.UP.cross(forward).normalized()
				# Input.get_vector returns -1 for box_forward, so negate Y to
				# make W approach and S retreat in the opponent-relative frame.
				direction=right*move_input.x+forward*(-move_input.y)
		else:
			direction=global_basis*Vector3(move_input.x,0.0,-move_input.y)
		if direction.length_squared()>.001:
			direction=direction.normalized()
		var distance_to_opponent := preferred_fight_distance
		if opponent:
			var separation := opponent.global_position-global_position
			separation.y=0.0
			distance_to_opponent=separation.length()
		# Exit on an angle: S+A/S+D while close to the opponent.
		if can_footwork and opponent:
			var wants_retreat: bool = move_input.y>.35
			var wants_angle: bool = abs(move_input.x)>.35
			if wants_retreat and wants_angle and distance_to_opponent<=pivot_distance and pivot_timer<=0.0:
				pivot_direction=sign(move_input.x)
				pivot_timer=pivot_duration
		var movement_multiplier := 1.0
		if abs(move_input.x)>abs(move_input.y):
			movement_multiplier=circle_speed_multiplier
		# W maps to -Y (approach) and S maps to +Y (retreat).
		if distance_to_opponent<preferred_fight_distance-distance_deadzone:
			if move_input.y>.1:
				movement_multiplier*=close_retreat_bonus
		elif distance_to_opponent>preferred_fight_distance+distance_deadzone:
			if move_input.y<-.1:
				movement_multiplier*=far_approach_bonus
		if opponent and distance_to_opponent<.72 and move_input.y<-.1:
			movement_multiplier*=.35
		var desired := Vector3.ZERO
		if direction.length()>.1 and can_footwork:
			desired=direction*speed*movement_multiplier
		elif state==State.ATTACKING:
			desired=direction*speed*.30
		if pivot_timer>0.0 and opponent:
			var pivot_to_opponent := opponent.global_position-global_position
			pivot_to_opponent.y=0.0
			if pivot_to_opponent.length_squared()>.001:
				var fight_right := Vector3.UP.cross(pivot_to_opponent.normalized()).normalized()
				desired+=fight_right*pivot_direction*speed*pivot_boost

		var current_horizontal := Vector3(velocity.x,0.0,velocity.z)
		var target_horizontal := Vector3(desired.x,0.0,desired.z)
		var movement_rate := acceleration_rate
		if target_horizontal.length_squared()<.001:
			movement_rate=braking_rate
		elif current_horizontal.length_squared()>.01:
			var current_dir := current_horizontal.normalized()
			var target_dir := target_horizontal.normalized()
			if current_dir.dot(target_dir)<.25:
				movement_rate=direction_change_rate
		var new_horizontal := current_horizontal.move_toward(target_horizontal,speed*movement_rate*delta)
		velocity.x=new_horizontal.x
		velocity.z=new_horizontal.z
		if target_horizontal.length_squared()>.001:
			last_move_direction=target_horizontal.normalized()
		is_stepping = can_footwork and velocity.length_squared() > .025
				
		velocity.y -= 9.8*delta
		move_and_slide()
		if state in [State.IDLE,State.MOVING]:
			state = State.MOVING if is_stepping else State.IDLE
	else:
		velocity=Vector3.ZERO
		locomotion_blend=locomotion_blend.lerp(Vector2.ZERO,1.0-exp(-locomotion_blend_speed*delta))
		if not animation.is_empty():
			animation.tree.set("parameters/Locomotion/blend_position",locomotion_blend)
	if camera_target:
		camera_target.global_position = global_position + Vector3(0, 1.15, 0)
	var down = state in [State.KNOCKDOWN,State.KO,State.DEFEAT]
	var target_roll = -1.5 if down else 0.0
	model.rotation.x = lerp_angle(model.rotation.x,target_roll,minf(1,delta*5))
	model.position.y = lerpf(model.position.y,.17 if down else (-.20*sin((.5-state_time)*PI/.5) if state==State.DODGING and defense=="duck" else 0.0),minf(1,delta*10))
	if state!=State.ATTACKING and state not in [State.KNOCKDOWN,State.KO]:
		guard = minf(100,guard+delta*6)
	stun=maxf(0,stun-delta*8)
	knockdown_meter=maxf(0,knockdown_meter-delta*2.5)
	recovery=maxf(0,recovery-delta)
	update_hitboxes(delta)

func apply_ragdoll_pose() -> void:
	for bone_name in ActiveRagdoll.BONES:
		var bone=skeleton.find_bone(bone_name)
		if bone<0: continue
		var offset: Vector3=active_ragdoll.offset_for(bone_name)
		if offset.length_squared()>.000001:
			skeleton.set_bone_pose_rotation(bone,Quaternion.from_euler(offset)*skeleton.get_bone_pose_rotation(bone))

func update_punch_ik() -> void:
	if not opponent or current_punch=="": return
	var zone="body" if current_punch.begins_with("body") else "head"
	var target=opponent.global_position+Vector3(0,1.18 if zone=="body" else 1.66,0)
	var side=Punches.DATA[current_punch][5]
	var shoulder_name="LeftUpperArm" if side==0 else "RightUpperArm"
	var shoulder=skeleton.global_transform*(skeleton.get_bone_global_pose(skeleton.find_bone(shoulder_name)).origin)
	var solution=ArmIK.solve(shoulder,.25,.23,target)
	last_ik_target=solution.target

func read_input() -> void:
	move_input=Input.get_vector("box_left","box_right","box_forward","box_back")
	if Input.is_action_pressed("box_guard") and can_act():
		var kind="block_body" if Input.is_action_pressed("box_body") else "block_high"
		if state!=State.BLOCKING or defense!=kind: set_state(State.BLOCKING,0,kind)
		defense=kind
	elif state==State.BLOCKING:
		defense=""
		set_state(State.IDLE)
	var body=Input.is_action_pressed("box_body")
	for name in ["jab","cross","left_hook","right_hook","left_uppercut","right_uppercut"]:
		if Input.is_action_just_pressed("box_"+name):
			attack(("body_jab" if name=="jab" else "body_cross" if name=="cross" else "body_hook") if body else name)
	for name in ["dodge_left","dodge_right","duck","weave","pivot_left","pivot_right"]:
		if Input.is_action_just_pressed("box_"+name): dodge(name)
	if state==State.DODGING and defense.begins_with("pivot"):
		move_input.x=-1 if defense=="pivot_left" else 1

func update_hitboxes(delta: float) -> void:
	skeleton.force_update_all_bone_transforms()
	var head = skeleton.find_bone("Head")
	var chest = skeleton.find_bone("Chest")
	hurts[0].global_position = skeleton.global_transform*(skeleton.get_bone_global_pose(head).origin+Vector3(0,.07,.015))
	hurts[1].global_position = skeleton.global_transform*(skeleton.get_bone_global_pose(chest).origin+Vector3(0,-.10,0))
	for hand in 2:
		var point = fist_points[hand].global_position
		var aim_error=(1.0-fatigue.accuracy_factor())*.055
		point+=global_basis.x*sin(float(attack_id)*9.17+attack_time*31.0)*aim_error
		fists[hand].global_position=point
		var effective: bool = false
		if fighting and state==State.ATTACKING:
			var d=Punches.DATA[current_punch]
			# The imported Mixamo actions have different lead-ins. The swept fist
			# volume is the authoritative visual contact test, so keep the complete
			# action available instead of retaining timing windows from old clips.
			var active_start: float=0.0
			var active_end: float=d[0]
			effective=fighting and state==State.ATTACKING and hand==d[5] and attack_time>=active_start and attack_time<=active_end and not attack_connected
		if effective:
			var distance=point.distance_to(old_fists[hand])
			fist_speed=clampf(distance/maxf(delta,.001)/3.0,.65,1.25)
			# Sweep actual fist volume between sampled poses. No distance-only hit test.
			var samples=clampi(ceili(distance/.055),1,12)
			for step in range(samples+1):
				var query=PhysicsShapeQueryParameters3D.new()
				query.shape=fists[hand].get_child(0).shape
				query.transform=Transform3D(Basis.IDENTITY,old_fists[hand].lerp(point,float(step)/samples))
				query.collision_mask=8
				query.collide_with_areas=true
				query.collide_with_bodies=false
				for result in get_world_3d().direct_space_state.intersect_shape(query,8):
					var area=result.collider
					if area.has_meta("fighter") and area.get_meta("fighter")!=self:
						var victim=area.get_meta("fighter")
						var contact_distance: float = point.distance_to(area.global_position)
						var accuracy := clampf(1.0-(contact_distance/.55),.35,1.0)
						var contact_position=old_fists[hand].lerp(point,float(step)/samples)
						var contact={"position":contact_position,"velocity":(point-old_fists[hand])/maxf(delta,.001),"hand":hand}
						if victim.receive_hit(self,current_punch,area.get_meta("zone"),fist_speed,accuracy,attack_id,contact):
							attack_connected=true
							break
				if attack_connected: break
		old_fists[hand]=point

func receive_hit(attacker: Node,punch: String,zone: String,speed: float,accuracy: float,id: int,contact: Dictionary={}) -> bool:
	if not fighting or state in [State.KNOCKDOWN,State.KO,State.GET_UP]: return false
	var key=str(attacker.get_instance_id())+":"+str(id)
	if hits_received.has(key): return false
	hits_received[key]=true
	if hits_received.size()>64: hits_received.erase(hits_received.keys()[0])
	var counter=state==State.ATTACKING or recovery>.03
	var blocked=state==State.BLOCKING and guard>0 and defense==("block_high" if zone=="head" else "block_body")
	var base: float=Punches.DATA[punch][3]
	# Golpes parcialmente conectados: rozar, impactar guante, conexión parcial
	var glance_factor = 1.0
	if accuracy < 0.72:
		# Swept contacts can have accuracy below 0.6. Clamp the interpolation
		# weight so a grazing hit reduces damage instead of healing the victim.
		glance_factor = lerpf(0.35, 0.85, clampf((accuracy - 0.6) / 0.12, 0.0, 1.0))
	var amount=Punches.damage(base,attacker.attack_stamina,speed,accuracy,counter,zone=="body",blocked)
	amount *= glance_factor
	amount*=attacker.fatigue.damage_factor()
	health=maxf(0,health-amount)
	if zone=="head": head_damage+=amount
	else:
		body_damage+=amount
		stamina=maxf(0,stamina-amount*1.1)
	if blocked:
		guard=maxf(0,guard-base*1.5)
		stamina=maxf(0,stamina-base*.35)
	else:
		stun+=amount*(1.45 if counter else 1.0)
		knockdown_meter+=amount*(1.0+head_damage/140.0)
		set_state(State.STUNNED if stun>32 else State.HURT,.20+base*.013,"stagger" if stun>32 else "hurt_"+zone)
		velocity += (global_position-attacker.global_position).normalized()*minf(1.5,amount*.09)
	var cam = get_viewport().get_camera_3d()
	if cam and "shake" in cam:
		cam.shake = minf(cam.shake + amount * 0.005, 0.18)
	var contact_position: Vector3=contact.get("position",global_position)
	var local=to_local(contact_position)
	# Registrar lesión
	if injury:
		injury.receive_damage(zone, punch, amount, local)
	var glove_velocity: Vector3=contact.get("velocity",(global_position-attacker.global_position).normalized()*speed*3.0)
	var guard_absorption=.70 if blocked else 0.0
	var attacker_mass=80.0*float(attacker.body_profile.get("muscle_mass",1.0))
	active_ragdoll.apply_contact(zone,contact_position,glove_velocity,attacker_mass,guard_absorption,fatigue.drive_factor())
	local=to_local(contact_position)
	var uv=Vector2(clampf(.5+local.x*.65,.08,.92),clampf(.28-local.y*.20+(0.30 if zone=="body" else 0.0),.08,.92))
	var region=("head_left" if local.x<-.08 else "head_right" if local.x>.08 else "head_center") if zone=="head" else ("body_left" if local.x<0 else "body_right")
	damage_accumulator.stamp(region,uv,amount/18.0,.055+amount*.002,.35 if not blocked else .05)
	attacker.landed+=1
	attacker.round_quality+=amount*(.4 if blocked else 1.0)
	var info={"damage":amount,"blocked":blocked,"counter":counter,"zone":zone,"punch":punch}
	attacker.hit_landed.emit(attacker,self,info)
	if health<=0 or knockdown_meter>42 or (stamina<3 and body_damage>65):
		knockdowns+=1
		round_knockdowns+=1
		set_state(State.KNOCKDOWN,0,"knockdown" if zone=="head" else "fall")
		knocked_down.emit(self)
	return true

func recover_from_down() -> void:
	health=maxf(health,22.0-knockdowns*3.0)
	stamina=maxf(stamina,38)
	knockdown_meter=0
	stun=0
	set_state(State.GET_UP,1.5,"get_up")

func debug_visible(enabled: bool) -> void:
	for mesh in debug_shapes: mesh.visible=enabled
